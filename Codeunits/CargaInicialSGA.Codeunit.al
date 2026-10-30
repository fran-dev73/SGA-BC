namespace AntonioNadal.SGA;

using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;

/// <summary>
/// Codeunit Carga Inicial SGA (ID 51106).
/// Da de alta en las ubicaciones el stock que ya tiene BC, para arrancar SGA cuadrado.
/// No toca el stock de BC: escribe contenido y movimientos de "Carga inicial" a través de
/// Cod. "Gestion Contenido SGA".
///
/// Tres formas de elegir el destino:
/// - Ubicación fija del producto: su casa (Shelf No.) o, si no tiene, la ubicación indicada.
/// - Ubicación indicada: todo a una ubicación de paso, para repartir después a mano.
/// - Huecos libres: cada palé completo a un hueco de palé vacío siguiendo la ruta; el resto en
///   cajas a un hueco mixto de caja (consolidando con el mismo producto); un producto sin
///   unidad de palé, a la ubicación indicada; y lo que no cabe, sin cargar.
///
/// Se lanza con Run. La simulación hace la carga de verdad y al final la deshace con un error
/// marcado: así cada propuesta ve los huecos que han ocupado las anteriores, y lo único que
/// sobrevive es el resultado, que va en una tabla temporal.
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
        TempResultado: Record "Resultado Carga Inicial SGA" temporary;
        // Modo "solo pendientes" (página Pendiente Ubicar SGA): en vez de todo el stock, se reparte
        // la cantidad indicada de cada lote.
        TempPendientes: Record "Pendiente Ubicar SGA" temporary;
        rHueco: Record "Ubicacion SGA";
        rConfig: Record "Config. SGA";
        cContenido: Codeunit "Gestion Contenido SGA";
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        cStock: Codeunit "Consulta Stock SGA";
        Almacen: Code[10];
        UbicacionIndicada: Code[20];
        VistaProductos: Text;
        Destino: Option "Ubicacion Fija del Producto","Ubicacion Indicada","Huecos Libres";
        OmitirConContenido: Boolean;
        Simular: Boolean;
        HuecoPosicionado: Boolean;
        HuecosAgotados: Boolean;
        MotivoSinHuecoPale: Text[500];
        SoloPendientes: Boolean;
        DescripcionMovimiento: Text;
        ProductosConStock: Integer;
        UnidadesCargadas: Decimal;
        UnidadesNoCargadas: Decimal;
        MarcaSimulacionTxt: Label 'SGA_SIMULACION_CARGA_INICIAL', Locked = true;

    /// <summary>
    /// Fija los parámetros. prm_VistaProductos es el GetView del filtro de productos del informe.
    /// </summary>
    procedure Configurar(prm_Almacen: Code[10]; prm_Destino: Option "Ubicacion Fija del Producto","Ubicacion Indicada","Huecos Libres"; prm_UbicacionIndicada: Code[20]; prm_OmitirConContenido: Boolean; prm_Simular: Boolean; prm_VistaProductos: Text)
    begin
        Almacen := prm_Almacen;
        Destino := prm_Destino;
        UbicacionIndicada := prm_UbicacionIndicada;
        OmitirConContenido := prm_OmitirConContenido;
        Simular := prm_Simular;
        VistaProductos := prm_VistaProductos;
    end;

    /// <summary>
    /// Cambia a modo "solo pendientes": reparte por huecos libres el "A Ubicar" de cada línea
    /// (lo sin ubicar que no tiene documento pendiente), no todo el stock. Se llama después de
    /// Configurar. Es lo que usa "Ubicar seleccionadas" de la página Pendiente Ubicar SGA.
    /// </summary>
    procedure FijarPendientes(var prm_Pendientes: Record "Pendiente Ubicar SGA" temporary)
    var
        UbicacionPendientesLbl: Label 'Ubicación de stock pendiente SGA';
    begin
        TempPendientes.Copy(prm_Pendientes, true);
        SoloPendientes := true;
        Destino := Destino::"Huecos Libres";
        OmitirConContenido := false;
        DescripcionMovimiento := UbicacionPendientesLbl;
    end;

    /// <summary>
    /// Indica si el error con el que ha terminado Run es el de fin de simulación y no uno real.
    /// </summary>
    procedure EsFinSimulacion(prm_TextoError: Text): Boolean
    begin
        exit(prm_TextoError = MarcaSimulacionTxt);
    end;

    procedure ObtenerResultado(var prm_Resultado: Record "Resultado Carga Inicial SGA")
    begin
        prm_Resultado.Copy(TempResultado, true);
    end;

    procedure ObtenerTotales(var prm_Productos: Integer; var prm_UnidadesCargadas: Decimal; var prm_UnidadesNoCargadas: Decimal)
    begin
        prm_Productos := ProductosConStock;
        prm_UnidadesCargadas := UnidadesCargadas;
        prm_UnidadesNoCargadas := UnidadesNoCargadas;
    end;

    local procedure Procesar()
    var
        rProducto: Record Item;
        AlmacenObligatorioErr: Label 'Debe indicar el almacén que se va a cargar.';
        UbicacionDestinoObligatoriaErr: Label 'Debe indicar la ubicación de destino.';
    begin
        if Almacen = '' then
            Error(AlmacenObligatorioErr);
        if (Destino = Destino::"Ubicacion Indicada") and (UbicacionIndicada = '') then
            Error(UbicacionDestinoObligatoriaErr);

        rConfig.ObtenerConfig();

        TempResultado.Reset();
        TempResultado.DeleteAll();
        HuecoPosicionado := false;
        HuecosAgotados := false;
        MotivoSinHuecoPale := '';
        cContenido.FijarModoSilencioso(true);

        if SoloPendientes then begin
            ProcesarPendientes();
            exit;
        end;

        if VistaProductos <> '' then
            rProducto.SetView(VistaProductos);
        rProducto.SetRange(Type, rProducto.Type::Inventory);
        if rProducto.FindSet() then
            repeat
                ProcesarProducto(rProducto);
            until rProducto.Next() = 0;
    end;

    /// <summary>
    /// Modo solo pendientes: un producto cada vez, los de las líneas recibidas.
    /// </summary>
    local procedure ProcesarPendientes()
    var
        rProducto: Record Item;
        ultimo: Code[20];
    begin
        ultimo := '';
        TempPendientes.Reset();
        TempPendientes.SetCurrentKey("Cod. Almacen", "No. Producto", "Cod. Variante", "No. Lote");
        TempPendientes.SetFilter("A Ubicar", '>0');
        if TempPendientes.FindSet() then
            repeat
                if TempPendientes."No. Producto" <> ultimo then begin
                    ultimo := TempPendientes."No. Producto";
                    if rProducto.Get(ultimo) then
                        ProcesarProducto(rProducto);
                end;
            until TempPendientes.Next() = 0;
        TempPendientes.Reset();
    end;

    /// <summary>
    /// Pasa al buffer de stock las líneas pendientes de un producto, con el "A Ubicar" como
    /// cantidad a repartir.
    /// </summary>
    local procedure CopiarPendientes(prm_Producto: Code[20]; var prm_Stock: Record "Buffer Conciliacion SGA" temporary)
    var
        TempLineas: Record "Pendiente Ubicar SGA" temporary;
    begin
        TempLineas.Copy(TempPendientes, true);
        TempLineas.Reset();
        TempLineas.SetRange("Cod. Almacen", Almacen);
        TempLineas.SetRange("No. Producto", prm_Producto);
        TempLineas.SetFilter("A Ubicar", '>0');
        if TempLineas.FindSet() then
            repeat
                prm_Stock.Init();
                prm_Stock."Cod. Usuario" := CopyStr(UserId(), 1, MaxStrLen(prm_Stock."Cod. Usuario"));
                prm_Stock."No. Producto" := prm_Producto;
                prm_Stock."Cod. Variante" := TempLineas."Cod. Variante";
                prm_Stock."Cod. Almacen" := TempLineas."Cod. Almacen";
                prm_Stock."No. Lote" := TempLineas."No. Lote";
                prm_Stock."Unidad Medida Base" := TempLineas."Unidad Medida Base";
                prm_Stock."Stock BC" := TempLineas."A Ubicar";
                prm_Stock.Insert();
            until TempLineas.Next() = 0;
    end;

    local procedure ProcesarProducto(var prm_Producto: Record Item)
    var
        TempStock: Record "Buffer Conciliacion SGA" temporary;
        ProductoBloqueadoLbl: Label 'Producto bloqueado.';
    begin
        if SoloPendientes then
            CopiarPendientes(prm_Producto."No.", TempStock)
        else
            cStock.AcumularStockPorLote(prm_Producto."No.", Almacen, TempStock);

        TempStock.Reset();
        TempStock.SetFilter("Stock BC", '>%1', 0);
        if not TempStock.FindSet() then
            exit;

        if OmitirConContenido and YaTieneContenido(prm_Producto."No.") then
            exit;

        ProductosConStock += 1;

        repeat
            // La puerta de escritura rechaza los productos bloqueados y pararía toda la carga.
            if prm_Producto.Blocked then
                AnotarNoCargado(prm_Producto, TempStock, TempStock."Unidad Medida Base", TempStock."Stock BC", TempStock."Stock BC", ProductoBloqueadoLbl)
            else
                case Destino of
                    Destino::"Huecos Libres":
                        RepartirPorHuecos(prm_Producto, TempStock);
                    else
                        CargarEnDestinoFijo(prm_Producto, TempStock);
                end;
        until TempStock.Next() = 0;
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
            destinoLinea := cUbicaciones.UbicacionFijaProducto(prm_Producto."No.");
            motivo := MotivoUbicacionFijaLbl;
        end;
        if destinoLinea = '' then begin
            destinoLinea := UbicacionIndicada;
            motivo := MotivoUbicacionIndicadaLbl;
        end;

        if destinoLinea = '' then
            AnotarNoCargado(prm_Producto, prm_Stock, prm_Stock."Unidad Medida Base", prm_Stock."Stock BC", prm_Stock."Stock BC", MotivoSinUbicacionLbl)
        else
            Cargar(prm_Producto, prm_Stock, destinoLinea, prm_Stock."Unidad Medida Base", prm_Stock."Stock BC", prm_Stock."Stock BC", motivo);
    end;

    /// <summary>
    /// Huecos libres: palés completos a huecos de palé vacíos, el resto en cajas a huecos mixtos.
    /// </summary>
    local procedure RepartirPorHuecos(var prm_Producto: Record Item; var prm_Stock: Record "Buffer Conciliacion SGA")
    var
        umPale: Code[10];
        umCaja: Code[10];
        factorPale: Decimal;
        factorCaja: Decimal;
        pales: Integer;
        cajas: Decimal;
        restoBase: Decimal;
        sueltasBase: Decimal;
        i: Integer;
        hueco: Code[20];
        motivo: Text;
        SinPaleUbicacionIndicadaLbl: Label 'El producto no tiene palé por defecto en su ficha: se deja en la ubicación indicada.';
        SinPaleSinUbicacionLbl: Label 'El producto no tiene palé por defecto en su ficha, así que no se puede repartir por huecos. Rellene su "Cód. palé por defecto" y vuelva a lanzar la carga.';
        SinCajaLbl: Label 'El producto no tiene caja: su unidad de venta está vacía, es la unidad base o es tan grande como el palé.';
    begin
        // El palé y la caja de cada producto salen de su ficha: el palé por defecto y la unidad
        // de venta, se llamen como se llamen (PALE200, EUROPALE, CAJA6…).
        umPale := rConfig.UMProductoDeTipo(prm_Producto."No.", "Tipo UM SGA"::Pale);
        umCaja := rConfig.UMProductoDeTipo(prm_Producto."No.", "Tipo UM SGA"::Caja);

        factorPale := FactorUM(prm_Producto."No.", umPale);
        if factorPale <= 0 then begin
            if UbicacionIndicada <> '' then
                Cargar(prm_Producto, prm_Stock, UbicacionIndicada, prm_Stock."Unidad Medida Base", prm_Stock."Stock BC", prm_Stock."Stock BC", SinPaleUbicacionIndicadaLbl)
            else
                AnotarNoCargado(prm_Producto, prm_Stock, prm_Stock."Unidad Medida Base", prm_Stock."Stock BC", prm_Stock."Stock BC", SinPaleSinUbicacionLbl);
            exit;
        end;

        // Palés completos: uno por hueco.
        pales := Round(prm_Stock."Stock BC" / factorPale, 1, '<');
        i := 0;
        while i < pales do begin
            hueco := BuscarHuecoPale(prm_Producto."No.", motivo);
            if hueco = '' then begin
                // Sin hueco para este palé no lo habrá para los siguientes: se anotan juntos.
                // Agotados los huecos de palé, el motivo es el mismo para todos los productos: se
                // calcula una vez, porque recorre todos los huecos.
                if MotivoSinHuecoPale = '' then
                    MotivoSinHuecoPale := CopyStr(cUbicaciones.ExplicarSinHuecoLote(Almacen, prm_Producto."No.", prm_Stock."No. Lote", umPale, 1), 1, MaxStrLen(MotivoSinHuecoPale));
                AnotarNoCargado(prm_Producto, prm_Stock, umPale, pales - i, (pales - i) * factorPale, MotivoSinHuecoPale);
                i := pales;
            end else begin
                Cargar(prm_Producto, prm_Stock, hueco, umPale, 1, factorPale, motivo);
                i += 1;
            end;
        end;

        restoBase := prm_Stock."Stock BC" - pales * factorPale;
        if restoBase <= 0 then
            exit;

        // El resto, en cajas, a un hueco mixto.
        factorCaja := FactorUM(prm_Producto."No.", umCaja);
        if (umCaja = '') or (factorCaja <= 0) then begin
            AnotarNoCargado(prm_Producto, prm_Stock, prm_Stock."Unidad Medida Base", restoBase, restoBase, SinCajaLbl);
            exit;
        end;

        cajas := Round(restoBase / factorCaja, 1, '<');
        sueltasBase := restoBase - cajas * factorCaja;

        if cajas > 0 then begin
            hueco := cUbicaciones.ProponerUbicacionCon("Estrategia Ubicacion SGA"::"Priorizar Consolidacion", '', Almacen,
                                                       prm_Producto."No.", prm_Stock."Cod. Variante", prm_Stock."No. Lote",
                                                       umCaja, cajas, motivo);
            if hueco = '' then
                AnotarNoCargado(prm_Producto, prm_Stock, umCaja, cajas, cajas * factorCaja,
                                cUbicaciones.ExplicarSinHuecoLote(Almacen, prm_Producto."No.", prm_Stock."No. Lote", umCaja, cajas))
            else
                Cargar(prm_Producto, prm_Stock, hueco, umCaja, cajas, cajas * factorCaja, motivo);
        end;

        // Lo que no llega a una caja, a una ubicación de unidades sueltas.
        if sueltasBase > 0 then begin
            hueco := cUbicaciones.ProponerUbicacionCon("Estrategia Ubicacion SGA"::"Priorizar Consolidacion", '', Almacen, prm_Producto."No.",
                                                       prm_Stock."Cod. Variante", prm_Stock."No. Lote", prm_Stock."Unidad Medida Base", sueltasBase, motivo);
            if hueco = '' then
                AnotarNoCargado(prm_Producto, prm_Stock, prm_Stock."Unidad Medida Base", sueltasBase, sueltasBase,
                                cUbicaciones.ExplicarSinHuecoLote(Almacen, prm_Producto."No.", prm_Stock."No. Lote", prm_Stock."Unidad Medida Base", sueltasBase))
            else
                Cargar(prm_Producto, prm_Stock, hueco, prm_Stock."Unidad Medida Base", sueltasBase, sueltasBase, motivo);
        end;
    end;

    /// <summary>
    /// Hueco de palé vacío para un producto: primero los reservados a ese producto y luego el
    /// siguiente libre de la ruta.
    ///
    /// Los huecos sin producto fijo se recorren con un cursor que solo avanza. Vale porque, vacío
    /// y sin producto fijo, un hueco admite cualquier producto: el que se salta una vez no le
    /// sirve a nadie después. Así se evita volver a recorrer la nave entera por cada palé.
    /// </summary>
    local procedure BuscarHuecoPale(prm_Producto: Code[20]; var prm_Motivo: Text): Code[20]
    var
        rFijo: Record "Ubicacion SGA";
        HuecoReservadoLbl: Label 'Hueco reservado al producto.';
        HuecoRutaLbl: Label 'Hueco de palé vacío siguiendo la ruta.';
    begin
        rFijo.SetCurrentKey("Cod. Almacen", "Secuencia Picking", "Cod. Bin");
        FiltrarHuecosPale(rFijo);
        rFijo.SetRange("Producto Fijo", prm_Producto);
        if rFijo.FindSet() then
            repeat
                if HuecoPaleLibre(rFijo) then begin
                    prm_Motivo := HuecoReservadoLbl;
                    exit(rFijo."Cod. Bin");
                end;
            until rFijo.Next() = 0;

        if HuecosAgotados then
            exit('');

        if not HuecoPosicionado then begin
            rHueco.Reset();
            rHueco.SetCurrentKey("Cod. Almacen", "Secuencia Picking", "Cod. Bin");
            FiltrarHuecosPale(rHueco);
            rHueco.SetRange("Producto Fijo", '');
            HuecoPosicionado := true;
            if not rHueco.FindSet() then begin
                HuecosAgotados := true;
                exit('');
            end;
        end;

        repeat
            if HuecoPaleLibre(rHueco) then begin
                prm_Motivo := HuecoRutaLbl;
                exit(rHueco."Cod. Bin");
            end;
        until rHueco.Next() = 0;

        HuecosAgotados := true;
        exit('');
    end;

    local procedure FiltrarHuecosPale(var prm_Hueco: Record "Ubicacion SGA")
    begin
        prm_Hueco.SetRange("Cod. Almacen", Almacen);
        prm_Hueco.SetRange(Bloqueada, false);
        prm_Hueco.SetFilter("Tipo Ubicacion", '%1|%2', prm_Hueco."Tipo Ubicacion"::Picking, prm_Hueco."Tipo Ubicacion"::Reserva);
        // Solo huecos de palé: los que no tienen "Admite" configurado no se proponen. No depende
        // del producto: un hueco de palé admite cualquier palé, y eso es lo que permite que el
        // cursor de huecos libres solo avance.
        prm_Hueco.SetRange("Tipo UM Admitida", prm_Hueco."Tipo UM Admitida"::Pale);
    end;

    /// <summary>
    /// Vacío, utilizable y con sitio para un palé. Con capacidad 0 no hay límite declarado.
    /// </summary>
    local procedure HuecoPaleLibre(var prm_Hueco: Record "Ubicacion SGA"): Boolean
    begin
        if not prm_Hueco.EsUtilizable() then
            exit(false);

        if (prm_Hueco."Capacidad Uds." > 0) and (prm_Hueco."Capacidad Uds." < 1) then
            exit(false);

        prm_Hueco.CalcFields("Lineas Contenido");
        exit(prm_Hueco."Lineas Contenido" = 0);
    end;

    local procedure Cargar(var prm_Producto: Record Item; var prm_Stock: Record "Buffer Conciliacion SGA"; prm_Bin: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_CantidadBase: Decimal; prm_Motivo: Text)
    var
        DescripcionCargaInicialLbl: Label 'Carga inicial SGA';
        descripcion: Text;
    begin
        descripcion := DescripcionMovimiento;
        if descripcion = '' then
            descripcion := DescripcionCargaInicialLbl;
        cContenido.RegistrarCargaInicial(Almacen, prm_Bin, prm_Producto."No.", prm_Stock."Cod. Variante", prm_Stock."No. Lote",
                                         prm_UM, prm_Cantidad, descripcion);

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
            siguiente := TempResultado."No. Entrada";

        TempResultado.Init();
        TempResultado."No. Entrada" := siguiente + 1;
        TempResultado."No. Producto" := prm_Producto."No.";
        TempResultado."Descripcion Producto" := CopyStr(prm_Producto.Description, 1, MaxStrLen(TempResultado."Descripcion Producto"));
        TempResultado."Cod. Variante" := prm_Stock."Cod. Variante";
        TempResultado."No. Lote" := prm_Stock."No. Lote";
        TempResultado."Cod. Bin" := prm_Bin;
        TempResultado."Cod. Unidad Medida" := prm_UM;
        TempResultado.Cantidad := prm_Cantidad;
        TempResultado."Cantidad Base" := prm_CantidadBase;
        TempResultado.Cargado := prm_Cargado;
        TempResultado.Motivo := CopyStr(prm_Motivo, 1, MaxStrLen(TempResultado.Motivo));
        TempResultado.Insert();
    end;

    /// <summary>
    /// Unidades base de una UM del producto. 0 si el producto no tiene esa unidad.
    /// </summary>
    local procedure FactorUM(prm_Producto: Code[20]; prm_UM: Code[10]): Decimal
    var
        rItemUM: Record "Item Unit of Measure";
    begin
        if prm_UM = '' then
            exit(0);

        if not rItemUM.Get(prm_Producto, prm_UM) then
            exit(0);

        exit(rItemUM."Qty. per Unit of Measure");
    end;

    local procedure YaTieneContenido(prm_Producto: Code[20]): Boolean
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        rContenido.SetCurrentKey("No. Producto", "Cod. Variante", "Cod. Almacen", "No. Lote");
        rContenido.SetRange("No. Producto", prm_Producto);
        rContenido.SetRange("Cod. Almacen", Almacen);

        exit(not rContenido.IsEmpty());
    end;
}
