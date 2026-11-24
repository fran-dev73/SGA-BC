namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;

/// <summary>
/// Codeunit Carga Inicial SGA (ID 51106).
/// Da de alta en las ubicaciones el stock que ya tiene BC, para arrancar SGA cuadrado.
/// No toca el stock de BC: escribe contenido y movimientos de "Carga inicial" a través de
/// Cod. "Gestion Contenido SGA". En "Ubicar seleccionadas" (ConfigurarPendientes) los
/// movimientos son entradas a mano, con SSCC nuevo, como en "Ubicar producto".
///
/// Tres formas de elegir el destino:
/// - Ubicación fija del producto: su casa (Shelf No.) o, si no tiene, la ubicación indicada.
/// - Ubicación indicada: todo a una ubicación de paso, para repartir después a mano.
/// - Huecos libres: cada palé completo a un hueco vacío siguiendo la ruta; el resto junto,
///   consolidando con el mismo producto o en el primer hueco con sitio; y lo que no cabe, sin
///   cargar. La ubicación indicada no se usa. En la carga inicial se llena primero picking y
///   luego almacenamiento, para arrancar con los huecos de picking servidos, pero cada
///   producto ocupa como mucho el máximo de ubicaciones de picking de Configurar, para que
///   picking no se llene de palés de unos pocos; en "Ubicar seleccionadas", almacenamiento y
///   luego picking, como cualquier entrada.
///
/// Se lanza con Run y el resultado se enseña con MostrarResultado. La simulación hace la carga
/// de verdad y al final la deshace con un error marcado: así cada propuesta ve los huecos que
/// han ocupado las anteriores, y lo único que sobrevive es el resultado, que va en una tabla
/// temporal.
/// </summary>
codeunit 51106 "Carga Inicial SGA"
{
    Access = Public;

    trigger OnRun()
    begin
        Procesar();

        if Simular then
            Error(MarcaSimulacionTxt);
    end;

    var
        TempResultado: Record "Linea Ubicacion SGA" temporary;
        // Lo que se reparte, lote a lote ("A Ubicar"): lo calcula Run para la carga entera, o lo
        // fija ConfigurarPendientes con las líneas elegidas en Pendiente Ubicar SGA.
        TempPendientes: Record "Buffer Conciliacion SGA" temporary;
        cContenido: Codeunit "Gestion Contenido SGA";
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        cStock: Codeunit "Consulta Stock SGA";
        cUM: Codeunit "Unidades Producto SGA";
        // Una instancia para toda la carga: lee las series de SSCC una vez.
        cLectura: Codeunit "Codigos Barras SGA";
        Almacen: Code[10];
        UbicacionIndicada: Code[20];
        VistaProductos: Text;
        Destino: Option "Ubicacion Fija del Producto","Ubicacion Indicada","Huecos Libres";
        Simular: Boolean;
        MotivoSinHuecoPale: Text[500];
        ProductoMotivoSinHueco: Code[20];
        SoloPendientes: Boolean;
        MaxPickingProducto: Integer;
        UnidadesCargadas: Decimal;
        UnidadesNoCargadas: Decimal;
        MarcaSimulacionTxt: Label 'SGA_SIMULACION_CARGA_INICIAL', Locked = true;

    /// <summary>
    /// Fija los parámetros de la carga inicial. prm_VistaProductos es el GetView del filtro de
    /// productos del informe. prm_MaxPickingProducto: cuántas ubicaciones de picking puede
    /// ocupar cada producto con "Huecos libres" (lo que pase va a almacenamiento); 0, sin
    /// límite. Con "Huecos libres" la ubicación indicada no se usa.
    /// </summary>
    procedure Configurar(prm_Almacen: Code[10]; prm_Destino: Option "Ubicacion Fija del Producto","Ubicacion Indicada","Huecos Libres"; prm_UbicacionIndicada: Code[20]; prm_Simular: Boolean; prm_VistaProductos: Text; prm_MaxPickingProducto: Integer)
    begin
        Almacen := prm_Almacen;
        Destino := prm_Destino;
        UbicacionIndicada := prm_UbicacionIndicada;
        if Destino = Destino::"Huecos Libres" then
            UbicacionIndicada := '';
        Simular := prm_Simular;
        VistaProductos := prm_VistaProductos;
        MaxPickingProducto := prm_MaxPickingProducto;
    end;

    /// <summary>
    /// Modo "solo pendientes" de "Ubicar seleccionadas" (Pendiente Ubicar SGA): reparte por
    /// huecos libres el "A Ubicar" de las líneas recibidas (lo sin ubicar que no tiene documento
    /// pendiente), como entradas a mano.
    /// </summary>
    procedure ConfigurarPendientes(prm_Almacen: Code[10]; prm_Simular: Boolean; var prm_Pendientes: Record "Buffer Conciliacion SGA" temporary)
    begin
        Configurar(prm_Almacen, Destino::"Huecos Libres", '', prm_Simular, '', 0);
        TempPendientes.Copy(prm_Pendientes, true);
        SoloPendientes := true;
    end;

    /// <summary>
    /// Tras Run (prm_RunOk es lo que ha devuelto): relanza el error si es uno real y no el fin
    /// de la simulación, avisa de las unidades cargadas y sin sitio y abre el resultado, una
    /// línea por palé o resto con su ubicación o su motivo.
    /// </summary>
    procedure MostrarResultado(prm_RunOk: Boolean)
    var
        pResultado: Page "Resultado Carga Inicial SGA";
        textoError: Text;
        TerminadoMsg: Label 'Terminado.\Unidades ubicadas: %1.\Unidades sin sitio: %2 (el motivo de cada una está en el detalle).', Comment = '%1 = ubicadas, %2 = sin sitio';
        SimuladoMsg: Label 'Simulación (no se ha guardado nada).\Unidades que se ubicarían: %1.\Unidades sin sitio: %2 (el motivo de cada una está en el detalle).', Comment = '%1 = ubicadas, %2 = sin sitio';
    begin
        // El fin de la simulación llega como error para que la base de datos deshaga lo escrito.
        if not prm_RunOk then begin
            textoError := GetLastErrorText();
            if textoError <> MarcaSimulacionTxt then
                Error(textoError);
        end;

        if not GuiAllowed() then
            exit;
        if Simular then
            Message(SimuladoMsg, UnidadesCargadas, UnidadesNoCargadas)
        else
            Message(TerminadoMsg, UnidadesCargadas, UnidadesNoCargadas);
        if not TempResultado.IsEmpty() then begin
            pResultado.Rellenar(TempResultado);
            pResultado.RunModal();
        end;
    end;

    local procedure Procesar()
    var
        rProducto: Record Item;
        rConfig: Record "Config. SGA";
        cVentana: Codeunit "Ventana Progreso SGA";
        AlmacenObligatorioErr: Label 'Debe indicar el almacén que se va a cargar.';
        UbicacionDestinoObligatoriaErr: Label 'Debe indicar la ubicación de destino.';
        FechaInicioObligatoriaErr: Label 'Ponga la "Fecha inicio SGA" en la configuración antes de la carga inicial: las recepciones y ensamblados desde esa fecha se ubican desde sus pantallas y no los coge la carga.';
        ProductoBloqueadoLbl: Label 'Producto bloqueado.';
        TituloLbl: Label 'Carga inicial de contenido…';
        ProductoLbl: Label 'Producto %1', Comment = '%1 = nº de producto';
    begin
        if Almacen = '' then
            Error(AlmacenObligatorioErr);
        if (Destino = Destino::"Ubicacion Indicada") and (UbicacionIndicada = '') then
            Error(UbicacionDestinoObligatoriaErr);

        // Se carga, lote a lote, lo mismo que "Pendiente de ubicar" tiene "A ubicar": el stock de
        // BC menos lo ya ubicado y menos lo que espera en recepciones o ensamblados, solo de los
        // productos que SGA ubica. Así la carga se puede repetir sin duplicar y no coge lo que
        // tiene su propio documento.
        if not SoloPendientes then begin
            rConfig.ObtenerConfig();
            if rConfig."Fecha Inicio SGA" = 0D then
                Error(FechaInicioObligatoriaErr);
            cStock.CargarPendienteUbicar(Almacen, VistaProductos, 0D, TempPendientes);
        end;

        TempResultado.Reset();
        TempResultado.DeleteAll();
        // Instancia nueva: los cursores de huecos vacíos (ProponerHuecoPaleRuta) empiezan de cero.
        Clear(cUbicaciones);
        cUbicaciones.FijarPickingPrimero(not SoloPendientes, MaxPickingProducto);
        MotivoSinHuecoPale := '';
        ProductoMotivoSinHueco := '';

        // Por la clave primaria, que agrupa por producto (las líneas son de un almacén).
        TempPendientes.Reset();
        TempPendientes.SetFilter("A Ubicar", '>0');
        if not TempPendientes.FindSet() then
            exit;
        rProducto.SetLoadFields(Blocked);
        cVentana.Abrir(TituloLbl, TempPendientes.Count());
        repeat
            cVentana.Avanzar(StrSubstNo(ProductoLbl, TempPendientes."No. Producto"));
            if rProducto."No." <> TempPendientes."No. Producto" then
                rProducto.Get(TempPendientes."No. Producto");
            // La puerta de escritura rechaza los productos bloqueados y pararía toda la carga.
            if rProducto.Blocked then
                AnotarNoCargado(rProducto, TempPendientes, TempPendientes."Unidad Medida Base", TempPendientes."A Ubicar", TempPendientes."A Ubicar", ProductoBloqueadoLbl)
            else
                if Destino = Destino::"Huecos Libres" then
                    RepartirPorHuecos(rProducto, TempPendientes)
                else
                    CargarEnDestinoFijo(rProducto, TempPendientes);
        until TempPendientes.Next() = 0;
        cVentana.Cerrar();
        TempPendientes.Reset();
    end;

    /// <summary>
    /// Modos clásicos: casa del producto o ubicación indicada, todo el lote junto.
    /// </summary>
    local procedure CargarEnDestinoFijo(var prm_Producto: Record Item; var prm_Stock: Record "Buffer Conciliacion SGA")
    var
        destinoLinea: Code[20];
        motivo: Text;
        MotivoUbicacionFijaLbl: Label 'Ubicación fija del producto.';
        MotivoUbicacionIndicadaLbl: Label 'Ubicación indicada.';
        MotivoSinUbicacionLbl: Label 'Sin ubicación fija ni ubicación indicada.';
    begin
        if Destino = Destino::"Ubicacion Fija del Producto" then begin
            destinoLinea := cUbicaciones.UbicacionFijaProducto(Almacen, prm_Producto."No.");
            motivo := MotivoUbicacionFijaLbl;
        end;
        if destinoLinea = '' then begin
            destinoLinea := UbicacionIndicada;
            motivo := MotivoUbicacionIndicadaLbl;
        end;

        if destinoLinea = '' then
            AnotarNoCargado(prm_Producto, prm_Stock, prm_Stock."Unidad Medida Base", prm_Stock."A Ubicar", prm_Stock."A Ubicar", MotivoSinUbicacionLbl)
        else
            Cargar(prm_Producto, prm_Stock, destinoLinea, prm_Stock."Unidad Medida Base", prm_Stock."A Ubicar", prm_Stock."A Ubicar", motivo);
    end;

    /// <summary>
    /// Huecos libres: palés completos a huecos vacíos, el resto junto a un hueco con sitio.
    /// </summary>
    local procedure RepartirPorHuecos(var prm_Producto: Record Item; var prm_Stock: Record "Buffer Conciliacion SGA")
    var
        TempTrozo: Record "Linea Ubicacion SGA" temporary;
        umPale: Code[10];
        pales: Integer;
        i: Integer;
        hueco: Code[20];
        motivo: Text;
        SinPaleLbl: Label 'El producto no tiene palé por defecto en su ficha, así que no se puede repartir por huecos. Rellene su "Cód. palé por defecto" y vuelva a lanzar la carga.';
    begin
        // El palé de cada producto sale de su ficha (palé por defecto), se llame como se llame
        // (PALE200, EUROPALE…), si lo tiene y lleva más de una unidad base.
        umPale := cUM.UMPale(prm_Producto."No.");
        if umPale = '' then begin
            AnotarNoCargado(prm_Producto, prm_Stock, prm_Stock."Unidad Medida Base", prm_Stock."A Ubicar", prm_Stock."A Ubicar", SinPaleLbl);
            exit;
        end;
        // El reparto (cada palé y el resto) es el mismo que en "Ubicar producto"; aquí solo cambia
        // cómo se busca el hueco de los palés.
        cUM.Repartir(prm_Producto."No.", prm_Stock."A Ubicar", '', 0, TempTrozo);

        // Palés completos: uno por hueco vacío, siguiendo la ruta (en la carga inicial, picking y
        // luego almacenamiento; en solo pendientes, al revés).
        TempTrozo.SetRange("Cod. Unidad Medida", umPale);
        pales := TempTrozo.Count();
        i := 0;
        if TempTrozo.FindSet() then
            repeat
                hueco := cUbicaciones.ProponerHuecoPaleRuta(Almacen, prm_Producto."No.", motivo);
                if hueco = '' then begin
                    // Sin hueco para este palé no lo habrá para los siguientes: se anotan juntos.
                    // El motivo recorre todos los huecos y depende del producto (su palé, su
                    // picking): se calcula una vez por producto, no en cada lote.
                    if ProductoMotivoSinHueco <> prm_Producto."No." then begin
                        MotivoSinHuecoPale := CopyStr(cUbicaciones.ExplicarSinHuecoLote(Almacen, prm_Producto."No.", prm_Stock."No. Lote", umPale, 1, true), 1, MaxStrLen(MotivoSinHuecoPale));
                        ProductoMotivoSinHueco := prm_Producto."No.";
                    end;
                    AnotarNoCargado(prm_Producto, prm_Stock, umPale, pales - i, (pales - i) * TempTrozo."Cantidad Base", MotivoSinHuecoPale);
                    i := pales;
                end else begin
                    Cargar(prm_Producto, prm_Stock, hueco, umPale, 1, TempTrozo."Cantidad Base", motivo);
                    i += 1;
                end;
            until (i >= pales) or (TempTrozo.Next() = 0);

        // El resto (una sola línea, en cajas o en unidades): consolidando con lo que ya haya del
        // producto o en el primer hueco con sitio, con el mismo orden de tipos que los palés.
        TempTrozo.SetFilter("Cod. Unidad Medida", '<>%1', umPale);
        if not TempTrozo.FindFirst() then
            exit;

        hueco := cUbicaciones.ProponerUbicacionCon("Estrategia Ubicacion SGA"::"Priorizar Consolidacion", '', Almacen,
                                                   prm_Producto."No.", prm_Stock."No. Lote",
                                                   TempTrozo."Cod. Unidad Medida", TempTrozo.Cantidad, motivo);
        // Sin hueco, el motivo ya trae la causa.
        if hueco = '' then
            AnotarNoCargado(prm_Producto, prm_Stock, TempTrozo."Cod. Unidad Medida", TempTrozo.Cantidad, TempTrozo."Cantidad Base", motivo)
        else
            Cargar(prm_Producto, prm_Stock, hueco, TempTrozo."Cod. Unidad Medida", TempTrozo.Cantidad, TempTrozo."Cantidad Base", motivo);
    end;

    /// <summary>
    /// Registra un trozo en su hueco. En la carga inicial, como carga inicial. En "Ubicar
    /// seleccionadas", como cualquier entrada a mano (lo mismo que "Ubicar producto"): con un
    /// SSCC nuevo y comprobando que el hueco la admite.
    /// </summary>
    local procedure Cargar(var prm_Producto: Record Item; var prm_Stock: Record "Buffer Conciliacion SGA"; prm_Bin: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_CantidadBase: Decimal; prm_Motivo: Text)
    var
        DescripcionCargaInicialLbl: Label 'Carga inicial SGA';
        UbicacionPendientesLbl: Label 'Ubicación de stock pendiente SGA';
    begin
        if SoloPendientes then
            cContenido.RegistrarEntrada(Almacen, prm_Bin, prm_Producto."No.", prm_Stock."No. Lote", cLectura.NuevoSSCC(),
                                        prm_UM, prm_Cantidad, "Origen Mov. SGA"::Manual, '', UbicacionPendientesLbl)
        else
            cContenido.RegistrarAjuste("Tipo Mov. Ubicacion SGA"::"Carga Inicial", Almacen, prm_Bin, prm_Producto."No.",
                                       prm_Stock."No. Lote", prm_UM, prm_Cantidad, DescripcionCargaInicialLbl);

        Anotar(prm_Producto, prm_Stock, prm_Bin, prm_UM, prm_Cantidad, prm_CantidadBase, true, prm_Motivo);
        UnidadesCargadas += prm_CantidadBase;
    end;

    local procedure AnotarNoCargado(var prm_Producto: Record Item; var prm_Stock: Record "Buffer Conciliacion SGA"; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_CantidadBase: Decimal; prm_Motivo: Text)
    begin
        Anotar(prm_Producto, prm_Stock, '', prm_UM, prm_Cantidad, prm_CantidadBase, false, prm_Motivo);
        UnidadesNoCargadas += prm_CantidadBase;
    end;

    local procedure Anotar(var prm_Producto: Record Item; var prm_Stock: Record "Buffer Conciliacion SGA"; prm_Bin: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_CantidadBase: Decimal; prm_Cargado: Boolean; prm_Motivo: Text)
    var
        siguiente: Integer;
    begin
        TempResultado.Reset();
        if TempResultado.FindLast() then
            siguiente := TempResultado.Linea;

        TempResultado.Init();
        TempResultado.Linea := siguiente + 1;
        TempResultado.Origen := TempResultado.Origen::"Carga Inicial";
        TempResultado."Cod. Almacen" := Almacen;
        TempResultado."No. Producto" := prm_Producto."No.";
        TempResultado."No. Lote" := prm_Stock."No. Lote";
        TempResultado."Ubicacion Propuesta" := prm_Bin;
        TempResultado."Ubicacion Confirmada" := prm_Bin;
        TempResultado."Cod. Unidad Medida" := prm_UM;
        TempResultado.Cantidad := prm_Cantidad;
        TempResultado."Cantidad Base" := prm_CantidadBase;
        if prm_Cargado then
            TempResultado.Estado := TempResultado.Estado::Ubicado
        else
            TempResultado.Estado := TempResultado.Estado::"Sin Sitio";
        TempResultado.Motivo := CopyStr(prm_Motivo, 1, MaxStrLen(TempResultado.Motivo));
        TempResultado.Insert();
    end;
}
