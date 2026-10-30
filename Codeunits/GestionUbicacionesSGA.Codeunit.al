namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Warehouse.Structure;

/// <summary>
/// Codeunit Gestion Ubicaciones SGA (ID 51101).
/// Ciclo de vida de ubicaciones: creación desde topología, sincronización, recálculo de estados.
///
/// NOTA: Fase 1 con Bin estándar. Los métodos GenerarUbicaciones y otros que dependían
/// de la topología personalizada (UbicacionAlmacen nave-estantería-columna-altura)
/// están documentados pero no implementados hasta Fase 2.
/// </summary>
codeunit 51101 "Gestion Ubicaciones SGA"
{
    Access = Public;

    /// <summary>
    /// Sincroniza la topología estándar (tabla Bin) con SGA, creando filas en
    /// "Ubicacion SGA" para los Bins que aún no las tienen.
    /// </summary>
    /// <summary>
    /// Obtiene o crea una ubicación SGA para un Bin dado.
    /// </summary>
    procedure ObtenerOCrear(prm_Almacen: Code[10]; prm_Bin: Code[20]): Code[20]
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        if rUbicacionSGA.Get(prm_Almacen, prm_Bin) then
            exit(prm_Bin);

        SincronizarTopologia(prm_Almacen);
        exit(prm_Bin);
    end;

    procedure SincronizarTopologia(prm_Almacen: Code[10])
    var
        rBin: Record Bin;
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        if prm_Almacen <> '' then
            rBin.SetRange("Location Code", prm_Almacen);

        if not rBin.FindSet() then
            exit;

        repeat
            if not rUbicacionSGA.Get(rBin."Location Code", rBin.Code) then begin
                rUbicacionSGA.Init();
                rUbicacionSGA."Cod. Almacen" := rBin."Location Code";
                rUbicacionSGA."Cod. Bin" := rBin.Code;
                rUbicacionSGA.Descripcion := CopyStr(rBin.Code, 1, MaxStrLen(rUbicacionSGA.Descripcion));
                if rBin.Dedicated then
                    rUbicacionSGA."Permite Mezcla Producto" := false
                else
                    rUbicacionSGA."Permite Mezcla Producto" := true;
                rUbicacionSGA."Permite Mezcla Lote" := true;
                rUbicacionSGA.GenerarDigitoControl();
                rUbicacionSGA.Insert();
            end;
        until rBin.Next() = 0;
    end;

    /// <summary>
    /// Recalcula el estado y el porcentaje de ocupación de las ubicaciones del almacén.
    /// Devuelve cuántas filas ha actualizado.
    /// </summary>
    procedure RecalcularEstados(prm_Almacen: Code[10]) actualizadas: Integer
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        estadoAnterior: Enum "Estado Ubicacion SGA";
        ocupacionAnterior: Decimal;
    begin
        if prm_Almacen <> '' then
            rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);

        if not rUbicacionSGA.FindSet() then
            exit(0);

        repeat
            estadoAnterior := rUbicacionSGA."Estado SGA";
            ocupacionAnterior := rUbicacionSGA."% Ocupacion";

            rUbicacionSGA.RecalcularOcupacion();

            if (estadoAnterior <> rUbicacionSGA."Estado SGA") or (ocupacionAnterior <> rUbicacionSGA."% Ocupacion") then begin
                rUbicacionSGA.Modify();
                actualizadas += 1;
            end;
        until rUbicacionSGA.Next() = 0;
    end;

    /// <summary>
    /// Genera ubicaciones en masa recorriendo los rangos de estantería, columna y altura.
    /// Crea el Bin estándar si no existe y su fila de datos SGA, en ese orden.
    /// Es idempotente: lo que ya existe no se toca, así que se puede reejecutar para ampliar.
    /// </summary>
    procedure GenerarUbicaciones(prm_Almacen: Code[10]; prm_Nave: Code[1]; prm_EstanteriaDesde: Integer; prm_EstanteriaHasta: Integer; prm_ColumnaDesde: Integer; prm_ColumnaHasta: Integer; prm_AlturaDesde: Integer; prm_AlturaHasta: Integer; prm_Zona: Code[10]; prm_Tipo: Enum "Tipo Ubicacion SGA"; prm_Capacidad: Decimal) creadas: Integer
    var
        rBin: Record Bin;
        rUbicacionSGA: Record "Ubicacion SGA";
        rConfigGen: Record "Config. SGA";
        estanteria: Integer;
        columna: Integer;
        altura: Integer;
        codBin: Code[20];
    begin
        rConfigGen.ObtenerConfig();
        for estanteria := prm_EstanteriaDesde to prm_EstanteriaHasta do
            for columna := prm_ColumnaDesde to prm_ColumnaHasta do
                for altura := prm_AlturaDesde to prm_AlturaHasta do begin
                    codBin := ComponerCodigoUbicacion(prm_Nave, estanteria, columna, altura);

                    if not rBin.Get(prm_Almacen, codBin) then begin
                        rBin.Init();
                        rBin."Location Code" := prm_Almacen;
                        rBin.Code := codBin;
                        rBin.Description := CopyStr(codBin, 1, MaxStrLen(rBin.Description));
                        rBin.Insert(true);
                    end;

                    if not rUbicacionSGA.Get(prm_Almacen, codBin) then begin
                        rUbicacionSGA.Init();
                        rUbicacionSGA."Cod. Almacen" := prm_Almacen;
                        rUbicacionSGA."Cod. Bin" := codBin;
                        rUbicacionSGA.Descripcion := CopyStr(codBin, 1, MaxStrLen(rUbicacionSGA.Descripcion));
                        rUbicacionSGA."Cod. Zona SGA" := prm_Zona;
                        rUbicacionSGA."Tipo Ubicacion" := prm_Tipo;
                        rUbicacionSGA."Capacidad Uds." := prm_Capacidad;
                        rUbicacionSGA."Secuencia Picking" := SecuenciaDesde(estanteria, columna, altura);
                        // Las ubicaciones nacen con el tipo de la configuración (el palé) y, si
                        // no son de caja, dedicadas a un solo producto. Las mixtas de caja se
                        // marcan después, ubicación a ubicación.
                        rUbicacionSGA."Tipo UM Admitida" := rConfigGen."Tipo Ubic. Nuevas";
                        rUbicacionSGA."Permite Mezcla Producto" := rUbicacionSGA.EsUmMixta();
                        rUbicacionSGA."Permite Mezcla Lote" := true;
                        rUbicacionSGA.GenerarDigitoControl();
                        rUbicacionSGA.Insert();
                        creadas += 1;
                    end;
                end;
    end;

    /// <summary>
    /// Compone el código de ubicación con el formato nave-estantería-columna-altura (A-01-15-3).
    /// </summary>
    local procedure ComponerCodigoUbicacion(prm_Nave: Code[1]; prm_Estanteria: Integer; prm_Columna: Integer; prm_Altura: Integer): Code[20]
    begin
        exit(CopyStr(prm_Nave + '-' + DosDigitos(prm_Estanteria) + '-' + DosDigitos(prm_Columna) + '-' + Format(prm_Altura), 1, 20));
    end;

    /// <summary>
    /// Formatea un entero a dos dígitos con cero a la izquierda. No se usa PadStr porque
    /// en AL rellena por la derecha: PadStr('5', 2, '0') devuelve '50', no '05'.
    /// </summary>
    local procedure DosDigitos(prm_Valor: Integer): Text
    var
        texto: Text;
    begin
        texto := Format(prm_Valor);
        if StrLen(texto) < 2 then
            exit('0' + texto);
        exit(texto);
    end;

    /// <summary>
    /// Orden de recorrido físico: primero la estantería, luego la columna y luego la altura.
    /// </summary>
    local procedure SecuenciaDesde(prm_Estanteria: Integer; prm_Columna: Integer; prm_Altura: Integer): Integer
    begin
        exit(prm_Estanteria * 10000 + prm_Columna * 100 + prm_Altura);
    end;

    /// <summary>
    /// Consulta ubicaciones de un producto. Abre la página de búsqueda "Consulta Ubic. Producto SGA".
    /// </summary>
    procedure ConsultarUbicacionesProducto(prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Almacen: Code[10]; prm_Lote: Code[50])
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        // La página recoge estos filtros en su OnOpenPage, así que se le pasan puestos.
        if prm_Producto <> '' then
            rContenido.SetRange("No. Producto", prm_Producto);
        if prm_Variante <> '' then
            rContenido.SetRange("Cod. Variante", prm_Variante);
        if prm_Almacen <> '' then
            rContenido.SetRange("Cod. Almacen", prm_Almacen);
        if prm_Lote <> '' then
            rContenido.SetRange("No. Lote", prm_Lote);

        Page.Run(Page::"Consulta Ubic. Producto SGA", rContenido);
    end;

    /// <summary>
    /// Única puerta para proponer en qué ubicación dejar un producto. La estrategia la elige
    /// quien llama, normalmente la que diga "Config. SGA" para su caso. Devuelve '' si no hay
    /// ninguna que lo admita.
    ///
    /// En prm_Motivo sale el porqué: con hueco, si le mandan a la casa del producto, a
    /// consolidar o a un hueco libre; sin hueco, la causa y qué hacer (ExplicarSinHuecoLote).
    ///
    /// prm_Excluidas es un filtro de AL ya montado sobre "Cod. Bin" (por ejemplo
    /// '&lt;&gt;A-01-01-1&amp;&lt;&gt;A-01-02-1', ver AnadirExclusion). Sirve para dos cosas: que el
    /// operario pueda pedir "otra ubicación" descartando la que se le acaba de ofrecer, y que al
    /// proponer en bloque no se asigne el mismo hueco vacío a dos cosas distintas.
    /// </summary>
    procedure ProponerUbicacionCon(prm_Estrategia: Enum "Estrategia Ubicacion SGA"; prm_Excluidas: Text; prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; var prm_Motivo: Text): Code[20]
    var
        codigo: Code[20];
        MotivoFijaTxt: Label 'Ubicación fija del producto.';
        MotivoConsolidacionTxt: Label 'Ya hay este producto ahí: se consolida.';
        MotivoPrimeraLibreTxt: Label 'Primer hueco con sitio en el orden de recorrido (pasillo, hueco y nivel, según la "Secuencia picking" de cada ubicación).';
        MotivoPrimeraVaciaTxt: Label 'Primer hueco vacío en el orden de recorrido (pasillo, hueco y nivel, según la "Secuencia picking" de cada ubicación).';
    begin
        prm_Motivo := '';

        case prm_Estrategia of
            prm_Estrategia::"Solo Ubicacion Fija":
                begin
                    codigo := BuscarFija(prm_Almacen, prm_Producto, prm_Lote, prm_UM, prm_Cantidad, prm_Excluidas);
                    if codigo <> '' then
                        prm_Motivo := MotivoFijaTxt;
                end;
            prm_Estrategia::"Solo Hueco Vacio":
                begin
                    codigo := BuscarVacia(prm_Almacen, prm_Producto, prm_Lote, prm_UM, prm_Cantidad, prm_Excluidas);
                    if codigo <> '' then
                        prm_Motivo := MotivoPrimeraVaciaTxt;
                end;
            prm_Estrategia::"Priorizar Consolidacion":
                begin
                    codigo := BuscarConsolidacion(prm_Almacen, prm_Producto, prm_Variante, prm_Lote, prm_UM, prm_Cantidad, prm_Excluidas);
                    if codigo <> '' then
                        prm_Motivo := MotivoConsolidacionTxt
                    else begin
                        codigo := BuscarLibre(prm_Almacen, prm_Producto, prm_Lote, prm_UM, prm_Cantidad, prm_Excluidas);
                        if codigo <> '' then
                            prm_Motivo := MotivoPrimeraLibreTxt;
                    end;
                end;
            prm_Estrategia::"Primera Libre por Ruta":
                begin
                    codigo := BuscarLibre(prm_Almacen, prm_Producto, prm_Lote, prm_UM, prm_Cantidad, prm_Excluidas);
                    if codigo <> '' then
                        prm_Motivo := MotivoPrimeraLibreTxt;
                end;
            else begin
                // Estándar: su casa, si no consolidar, si no el primer hueco por ruta.
                codigo := BuscarFija(prm_Almacen, prm_Producto, prm_Lote, prm_UM, prm_Cantidad, prm_Excluidas);
                if codigo <> '' then
                    prm_Motivo := MotivoFijaTxt
                else begin
                    codigo := BuscarConsolidacion(prm_Almacen, prm_Producto, prm_Variante, prm_Lote, prm_UM, prm_Cantidad, prm_Excluidas);
                    if codigo <> '' then
                        prm_Motivo := MotivoConsolidacionTxt
                    else begin
                        codigo := BuscarLibre(prm_Almacen, prm_Producto, prm_Lote, prm_UM, prm_Cantidad, prm_Excluidas);
                        if codigo <> '' then
                            prm_Motivo := MotivoPrimeraLibreTxt;
                    end;
                end;
            end;
        end;

        if codigo = '' then
            prm_Motivo := ExplicarSinHuecoLote(prm_Almacen, prm_Producto, prm_Lote, prm_UM, prm_Cantidad);

        exit(codigo);
    end;

    /// <summary>
    /// Una cantidad en unidad base repartida en palés, cajas y botellas sueltas, las tres
    /// unidades de la ficha del producto: "2 PALE, 5 CAJA12, 6 BOTELLA". Vacío si es cero.
    /// </summary>
    procedure DesgloseCantidad(prm_Producto: Code[20]; prm_CantidadBase: Decimal): Text
    var
        resto: Decimal;
        texto: Text;
    begin
        if prm_CantidadBase <= 0 then
            exit('');
        resto := prm_CantidadBase;
        AnadirAlDesglose(prm_Producto, cUM.UMProductoDeTipo(prm_Producto, "Tipo UM SGA"::Pale), resto, texto);
        AnadirAlDesglose(prm_Producto, cUM.UMProductoDeTipo(prm_Producto, "Tipo UM SGA"::Caja), resto, texto);
        AnadirAlDesglose(prm_Producto, cUM.UMProductoDeTipo(prm_Producto, "Tipo UM SGA"::Unidad), resto, texto);
        exit(texto);
    end;

    local procedure AnadirAlDesglose(prm_Producto: Code[20]; prm_UM: Code[10]; var prm_Resto: Decimal; var prm_Texto: Text)
    var
        factor: Decimal;
        cuantos: Decimal;
    begin
        if (prm_UM = '') or (prm_Resto <= 0) then
            exit;
        factor := cUM.FactorUM(prm_Producto, prm_UM);
        if factor = 1 then
            cuantos := prm_Resto
        else
            cuantos := Round(prm_Resto / factor, 1, '<');
        if cuantos <= 0 then
            exit;
        if prm_Texto <> '' then
            prm_Texto += ', ';
        prm_Texto += Format(cuantos) + ' ' + prm_UM;
        prm_Resto := Round(prm_Resto - cuantos * factor, 0.00001);
    end;

    /// <summary>
    /// Explica por qué no se ha podido proponer ningún hueco y qué hacer. La primera frase es
    /// siempre la causa, para poder agrupar por ella (resultado de la carga inicial):
    ///   - la unidad no es palé, caja ni unidad del producto;
    ///   - no hay ninguna ubicación de esa clase configurada (o son de otro uso);
    ///   - las hay, pero ninguna sirve: cuántas por cada motivo (bloqueadas, sin sitio,
    ///     reservadas a otro producto, con otro producto, con otro lote, o con sitio pero ya
    ///     propuestas a otras líneas del mismo reparto). Si casi todas están sin sitio, se dice
    ///     claramente que no queda espacio de esa clase.
    /// Clasifica cada ubicación con MotivoRechazo, la misma regla que la propuesta.
    /// </summary>
    procedure ExplicarSinHuecoLote(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal): Text
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        tipo: Enum "Tipo UM SGA";
        um: Code[10];
        deUso: Integer;
        otrosUsos: Integer;
        motivo: Integer;
        cuenta: array[6] of Integer;
        detalle: Text;
        UMSinClaseTxt: Label 'La unidad %1 no es el palé, la caja ni la unidad del producto. Ubique en el "Cód. palé por defecto", la "Unidad de medida de venta" o la unidad base, o revise la ficha del producto.', Comment = '%1 = unidad';
        SinUbicacionClaseTxt: Label 'No hay ninguna ubicación de %1 en el almacén %2. Configure alguna: ficha de una ubicación de tipo Picking o Reserva, "Admite" = %1 y su "Capacidad".', Comment = '%1 = clase (Palé/Caja/Unidad), %2 = almacén';
        UbicacionesOtroUsoTxt: Label 'Las %1 ubicaciones de %2 del almacén %3 son de muelle, cuarentena, ajustes u otro uso, y solo se proponen las de Picking o Reserva. Cambie el "Tipo ubicación" de alguna.', Comment = '%1 = número, %2 = clase, %3 = almacén';
        SinEspacioTxt: Label 'No queda espacio en ubicaciones de %1 (almacén %2): %3 de %4 están llenas o sin sitio para %5 %6.%7 Libere ubicaciones o configure más de %1.', Comment = '%1 = clase, %2 = almacén, %3 = sin sitio, %4 = total, %5 = cantidad, %6 = unidad, %7 = resto del detalle';
        NingunaSirveTxt: Label 'Ninguna de las %1 ubicaciones de %2 del almacén %3 sirve para %4 %5:%6', Comment = '%1 = total, %2 = clase, %3 = almacén, %4 = cantidad, %5 = unidad, %6 = detalle por motivo';
        BloqueadasTxt: Label ' %1 bloqueadas;', Comment = '%1 = número';
        ReservadasTxt: Label ' %1 reservadas a otro producto ("Producto fijo");', Comment = '%1 = número';
        SinSitioTxt: Label ' %1 llenas o sin sitio;', Comment = '%1 = número';
        OtroProductoTxt: Label ' %1 con otro producto (no aceptan mezcla);', Comment = '%1 = número';
        OtroLoteTxt: Label ' %1 con otro lote (no aceptan mezcla de lotes);', Comment = '%1 = número';
        YaPropuestasTxt: Label ' %1 con sitio, pero ya propuestas a otras líneas de este reparto;', Comment = '%1 = número';
        DelRestoTxt: Label ' Del resto:';
    begin
        um := prm_UM;
        if um = '' then
            um := cUM.UMBase(prm_Producto);

        // La misma clase de hueco que se propone: las cajas, a caja o a palé según cuántas sean.
        // Los huecos sin configurar no cuentan: no se proponen nunca.
        tipo := cUM.TipoHuecoDestino(prm_Producto, um, prm_Cantidad);
        if tipo = tipo::" " then
            exit(StrSubstNo(UMSinClaseTxt, um));

        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        rUbicacionSGA.SetRange("Tipo UM Admitida", tipo);
        rUbicacionSGA.FiltrarDeAlmacenaje();
        deUso := rUbicacionSGA.Count();

        if deUso = 0 then begin
            rUbicacionSGA.SetRange("Tipo Ubicacion");
            otrosUsos := rUbicacionSGA.Count();
            if otrosUsos > 0 then
                exit(StrSubstNo(UbicacionesOtroUsoTxt, otrosUsos, tipo, prm_Almacen));
            exit(StrSubstNo(SinUbicacionClaseTxt, tipo, prm_Almacen));
        end;

        if rUbicacionSGA.FindSet() then
            repeat
                motivo := MotivoRechazo(rUbicacionSGA, prm_Producto, prm_Lote, um, prm_Cantidad);
                case motivo of
                    0:
                        cuenta[6] += 1;
                    1, 2, 4, 5:
                        cuenta[motivo] += 1;
                    6:
                        cuenta[3] += 1;
                end;
            until rUbicacionSGA.Next() = 0;

        // cuenta: 1 bloqueadas, 2 reservadas, 3 otro lote, 4 sin sitio, 5 otro producto, 6 ya propuestas.
        if cuenta[1] > 0 then
            detalle += StrSubstNo(BloqueadasTxt, cuenta[1]);
        if cuenta[2] > 0 then
            detalle += StrSubstNo(ReservadasTxt, cuenta[2]);
        if cuenta[5] > 0 then
            detalle += StrSubstNo(OtroProductoTxt, cuenta[5]);
        if cuenta[3] > 0 then
            detalle += StrSubstNo(OtroLoteTxt, cuenta[3]);
        if cuenta[6] > 0 then
            detalle += StrSubstNo(YaPropuestasTxt, cuenta[6]);

        // Si la mayoría están sin sitio, lo que falta es espacio: se dice primero.
        if cuenta[4] * 2 >= deUso then begin
            if detalle <> '' then
                detalle := DelRestoTxt + detalle;
            exit(StrSubstNo(SinEspacioTxt, tipo, prm_Almacen, cuenta[4], deUso, prm_Cantidad, um, detalle));
        end;

        if cuenta[4] > 0 then
            detalle += StrSubstNo(SinSitioTxt, cuenta[4]);
        exit(StrSubstNo(NingunaSirveTxt, deUso, tipo, prm_Almacen, prm_Cantidad, um, detalle));
    end;

    /// <summary>
    /// Casa del producto, si la tiene y sigue admitiéndolo.
    /// </summary>
    local procedure BuscarFija(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Excluidas: Text): Code[20]
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        codigo: Code[20];
    begin
        codigo := UbicacionFijaProducto(prm_Producto);
        if codigo = '' then
            exit('');

        if not rUbicacionSGA.Get(prm_Almacen, codigo) then
            exit('');

        if EstaExcluida(prm_Almacen, codigo, prm_Excluidas) then
            exit('');

        if not UbicacionAdmite(rUbicacionSGA, prm_Producto, prm_Lote, prm_UM, prm_Cantidad) then
            exit('');

        exit(codigo);
    end;

    /// <summary>
    /// Primer hueco completamente vacío siguiendo la ruta de picking. Es la estrategia que
    /// usan los ensamblados: lo que sale de producción va a un hueco limpio, no se mezcla.
    /// </summary>
    local procedure BuscarVacia(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Excluidas: Text): Code[20]
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        rUbicacionSGA.SetCurrentKey("Cod. Almacen", "Secuencia Picking", "Cod. Bin");
        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        rUbicacionSGA.SetRange(Bloqueada, false);
        rUbicacionSGA.FiltrarDeAlmacenaje();
        if prm_Excluidas <> '' then
            rUbicacionSGA.SetFilter("Cod. Bin", prm_Excluidas);
        if not rUbicacionSGA.FindSet() then
            exit('');

        repeat
            rUbicacionSGA.CalcFields("Lineas Contenido");
            if rUbicacionSGA."Lineas Contenido" = 0 then
                if UbicacionAdmite(rUbicacionSGA, prm_Producto, prm_Lote, prm_UM, prm_Cantidad) then
                    exit(rUbicacionSGA."Cod. Bin");
        until rUbicacionSGA.Next() = 0;

        exit('');
    end;

    /// <summary>
    /// Comprueba si una ubicación cae fuera por el filtro de exclusiones. Se resuelve con un
    /// Record filtrado porque prm_Excluidas es un filtro de AL, no una lista que se pueda comparar.
    ///
    /// Los dos filtros sobre "Cod. Bin" van en grupos distintos a propósito: dentro del mismo
    /// grupo el segundo SetFilter sustituiría al primero en lugar de sumarse.
    /// </summary>
    local procedure EstaExcluida(prm_Almacen: Code[10]; prm_Codigo: Code[20]; prm_Excluidas: Text): Boolean
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        if prm_Excluidas = '' then
            exit(false);

        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        rUbicacionSGA.SetRange("Cod. Bin", prm_Codigo);
        rUbicacionSGA.FilterGroup(10);
        rUbicacionSGA.SetFilter("Cod. Bin", prm_Excluidas);
        rUbicacionSGA.FilterGroup(0);

        exit(rUbicacionSGA.IsEmpty());
    end;

    /// <summary>
    /// Suma un hueco al filtro de exclusiones que recibe ProponerUbicacionCon, en el formato que
    /// entiende SetFilter ('&lt;&gt;A&amp;&lt;&gt;B'). Un código en blanco no añade nada. Es la pareja de
    /// EstaExcluida: quien reparte varias cosas a la vez lo usa para no dar el mismo hueco a dos.
    /// </summary>
    procedure AnadirExclusion(prm_Filtro: Text; prm_Codigo: Code[20]): Text
    begin
        if prm_Codigo = '' then
            exit(prm_Filtro);

        if prm_Filtro = '' then
            exit('<>' + prm_Codigo);

        exit(prm_Filtro + '&<>' + prm_Codigo);
    end;

    /// <summary>
    /// Error si la ubicación no existe en el almacén. No comprueba nada si el almacén o la
    /// ubicación van en blanco: eso lo decide quien llama.
    /// </summary>
    procedure ComprobarUbicacionExiste(prm_Almacen: Code[10]; prm_Ubicacion: Code[20])
    var
        rBin: Record Bin;
        UbicacionNoExisteErr: Label 'La ubicación %1 no existe en el almacén %2.', Comment = '%1 = ubicación, %2 = almacén';
    begin
        if (prm_Almacen = '') or (prm_Ubicacion = '') then
            exit;

        rBin.SetRange("Location Code", prm_Almacen);
        rBin.SetRange(Code, prm_Ubicacion);
        if rBin.IsEmpty() then
            Error(UbicacionNoExisteErr, prm_Ubicacion, prm_Almacen);
    end;

    /// <summary>
    /// Ubicación que ya tiene ese producto y aún admite más: agrupar antes que dispersar.
    /// Se recorre por secuencia de picking para quedarse con la más cercana en la ruta.
    /// </summary>
    local procedure BuscarConsolidacion(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Excluidas: Text): Code[20]
    var
        rContenido: Record "Contenido Ubicacion SGA";
        rUbicacionSGA: Record "Ubicacion SGA";
        mejorSecuencia: Integer;
        mejorCodigo: Code[20];
    begin
        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetRange("No. Producto", prm_Producto);
        rContenido.SetRange("Cod. Variante", prm_Variante);
        if not rContenido.FindSet() then
            exit('');

        mejorCodigo := '';
        mejorSecuencia := 0;
        repeat
            if not EstaExcluida(prm_Almacen, rContenido."Cod. Bin", prm_Excluidas) then
                if rUbicacionSGA.Get(prm_Almacen, rContenido."Cod. Bin") then
                    if UbicacionAdmite(rUbicacionSGA, prm_Producto, prm_Lote, prm_UM, prm_Cantidad) then
                    if (mejorCodigo = '') or (rUbicacionSGA."Secuencia Picking" < mejorSecuencia) then begin
                        mejorSecuencia := rUbicacionSGA."Secuencia Picking";
                        mejorCodigo := rUbicacionSGA."Cod. Bin";
                    end;
        until rContenido.Next() = 0;

        exit(mejorCodigo);
    end;

    /// <summary>
    /// Primer hueco de picking o reserva que admita el producto, siguiendo la ruta física.
    /// </summary>
    local procedure BuscarLibre(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Excluidas: Text): Code[20]
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        rUbicacionSGA.SetCurrentKey("Cod. Almacen", "Secuencia Picking", "Cod. Bin");
        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        rUbicacionSGA.SetRange(Bloqueada, false);
        rUbicacionSGA.FiltrarDeAlmacenaje();
        if prm_Excluidas <> '' then
            rUbicacionSGA.SetFilter("Cod. Bin", prm_Excluidas);
        if not rUbicacionSGA.FindSet() then
            exit('');

        repeat
            if UbicacionAdmite(rUbicacionSGA, prm_Producto, prm_Lote, prm_UM, prm_Cantidad) then
                exit(rUbicacionSGA."Cod. Bin");
        until rUbicacionSGA.Next() = 0;

        exit('');
    end;

    /// <summary>
    /// Comprobación de si una ubicación puede recibir el producto. Es la criba para
    /// proponer; la validación que manda es la de Cod. "Gestion Contenido SGA" al registrar.
    /// </summary>
    local procedure UbicacionAdmite(var prm_Ubicacion: Record "Ubicacion SGA"; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal): Boolean
    begin
        exit(MotivoRechazo(prm_Ubicacion, prm_Producto, prm_Lote, prm_UM, prm_Cantidad) = 0);
    end;

    /// <summary>
    /// Por qué una ubicación no puede recibir el producto, en el orden en que se comprueba:
    ///   0 = sí puede; 1 = bloqueada (ella o su zona); 2 = reservada a otro producto;
    ///   3 = no es de la clase que toca (o no está configurada); 4 = sin sitio suficiente;
    ///   5 = tiene otro producto y no acepta mezcla; 6 = tiene otro lote y no acepta mezcla.
    /// Es la única regla: la usan la propuesta (UbicacionAdmite) y la explicación de por qué no
    /// hay hueco (ExplicarSinHuecoLote), para que digan siempre lo mismo.
    /// </summary>
    local procedure MotivoRechazo(var prm_Ubicacion: Record "Ubicacion SGA"; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal): Integer
    var
        cantidadBase: Decimal;
    begin
        if not prm_Ubicacion.EsUtilizable() then
            exit(1);

        if (prm_Ubicacion."Producto Fijo" <> '') and (prm_Ubicacion."Producto Fijo" <> prm_Producto) then
            exit(2);

        // Solo se propone la clase de hueco que toca (palé, caja según cuántas sean, o unidad),
        // y nunca un hueco sin configurar ("Admite" en blanco). Al confirmar se valida con
        // UMAdmitida, que es más amplia: deja que el operario use otro hueco que también sirva.
        if prm_Ubicacion."Tipo UM Admitida" = prm_Ubicacion."Tipo UM Admitida"::" " then
            exit(3);
        if prm_Ubicacion."Tipo UM Admitida" <> cUM.TipoHuecoDestino(prm_Producto, prm_UM, prm_Cantidad) then
            exit(3);

        // La capacidad está en la clase del hueco (palés, cajas): lo que hay y lo que entra se
        // cuentan en esa clase, con el palé o la caja de cada producto.
        if prm_Ubicacion."Capacidad Uds." > 0 then begin
            cantidadBase := prm_Cantidad * cUM.FactorUM(prm_Producto, prm_UM);
            if prm_Ubicacion.OcupadoEnUMHueco() + prm_Ubicacion.EnUMHueco(prm_Producto, cantidadBase) > prm_Ubicacion."Capacidad Uds." then
                exit(4);
        end;

        // 5 = otro producto, 6 = otro lote; 0 si nada impide la mezcla.
        exit(prm_Ubicacion.ContenidoQueImpideMezcla(prm_Producto, prm_Lote));
    end;

    /// <summary>
    /// Total de unidades de un producto+variante+lote ubicadas.
    /// </summary>
    /// <summary>
    /// Cantidad ya repartida en ubicaciones, en unidad de medida base.
    /// El almacen, la variante y el lote solo filtran si vienen informados, de modo que con
    /// solo el producto se obtiene el total de todo el almacen.
    /// </summary>
    procedure TotalUbicadoProducto(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]): Decimal
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        rContenido.SetRange("No. Producto", prm_Producto);
        if prm_Almacen <> '' then
            rContenido.SetRange("Cod. Almacen", prm_Almacen);
        if prm_Variante <> '' then
            rContenido.SetRange("Cod. Variante", prm_Variante);
        if prm_Lote <> '' then
            rContenido.SetRange("No. Lote", prm_Lote);
        rContenido.CalcSums("Cantidad Base");
        exit(rContenido."Cantidad Base");
    end;

    /// <summary>
    /// Lo que queda por ubicar de un producto: las existencias que BC dice que hay en el
    /// almacen menos lo que SGA ya tiene repartido en ubicaciones. En unidad de medida base.
    ///
    /// Devuelve tambien el stock y lo ya ubicado por referencia, porque un pendiente a cero
    /// no dice si es que no hay stock o si es que ya esta todo colocado.
    /// </summary>
    procedure PendienteDeUbicar(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; var prm_StockBase: Decimal; var prm_UbicadoBase: Decimal): Decimal
    var
        rItem: Record Item;
    begin
        prm_StockBase := 0;
        prm_UbicadoBase := 0;

        if prm_Producto = '' then
            exit(0);

        if not rItem.Get(prm_Producto) then
            exit(0);

        if prm_Almacen <> '' then
            rItem.SetRange("Location Filter", prm_Almacen);
        if prm_Variante <> '' then
            rItem.SetRange("Variant Filter", prm_Variante);
        if prm_Lote <> '' then
            rItem.SetRange("Lot No. Filter", prm_Lote);
        rItem.CalcFields(Inventory);

        prm_StockBase := rItem.Inventory;
        prm_UbicadoBase := TotalUbicadoProducto(prm_Almacen, prm_Producto, prm_Variante, prm_Lote);

        exit(prm_StockBase - prm_UbicadoBase);
    end;

    /// <summary>
    /// Ubicación fija de un producto: primero comprueba el campo "Producto Fijo" en UbicacionSGA,
    /// luego el "Shelf No." en la ficha de Item.
    /// </summary>
    procedure UbicacionFijaProducto(prm_Producto: Code[20]): Code[20]
    var
        rItem: Record Item;
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        rUbicacionSGA.SetRange("Producto Fijo", prm_Producto);
        if rUbicacionSGA.FindFirst() then
            exit(rUbicacionSGA."Cod. Bin");

        if rItem.Get(prm_Producto) then
            if rItem."Shelf No." <> '' then
                exit(rItem."Shelf No.");

        exit('');
    end;

    /// <summary>
    /// Calcula la secuencia (orden de recorrido) a partir de los tramos de la topología.
    /// Un tramo no numérico cuenta como 0 en lugar de abortar: la secuencia es orden de
    /// recorrido, no un dato contable, y una nave puede tener códigos no numéricos.
    /// </summary>
    procedure SecuenciaDesdeTopologia(prm_Nave: Code[1]; prm_Estanteria: Code[2]; prm_Columna: Code[2]; prm_Altura: Code[1]): Integer
    var
        estanteria: Integer;
        columna: Integer;
        altura: Integer;
    begin
        if not Evaluate(estanteria, prm_Estanteria) then
            estanteria := 0;
        if not Evaluate(columna, prm_Columna) then
            columna := 0;
        if not Evaluate(altura, prm_Altura) then
            altura := 0;

        exit(SecuenciaDesde(estanteria, columna, altura));
    end;

    /// <summary>
    /// Contadores de ubicaciones por estado.
    /// </summary>
    procedure ContarUbicaciones(prm_Almacen: Code[10]; prm_Estado: Enum "Estado Ubicacion SGA"): Integer
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        rUbicacionSGA.SetRange("Estado SGA", prm_Estado);
        exit(rUbicacionSGA.Count());
    end;

    var
        cUM: Codeunit "Unidades Producto SGA";
}
