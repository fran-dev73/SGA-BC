namespace AntonioNadal.SGA;

using AntonioNadal.Produccion;
using Microsoft.Assembly.Document;
using Microsoft.Assembly.History;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Purchases.Vendor;

/// <summary>
/// Codeunit Gestion Entradas SGA (ID 51105).
/// Lleva lo que entra en el almacén hasta su hueco: reúne lo que ha entrado en una fecha
/// (ensamblados registrados o recepciones de compra), propone dónde dejar cada cosa y registra
/// la entrada cuando el operario confirma.
///
/// No se engancha al registro de BC a propósito: las validaciones de SGA (capacidad, mezcla,
/// tipo de unidad admitido) lanzan error, y dentro del registro harían fallar el albarán. BC registra como
/// siempre y SGA va detrás, leyendo lo registrado.
///
/// Lo que ya está colocado no se guarda en ninguna marca propia: se deduce del diario de
/// movimientos, que es la verdad del módulo. Así la pantalla se puede cerrar y volver a abrir
/// sin perder el hilo y sin arrastrar un estado paralelo que se desincronice.
///
/// Quien escribe sigue siendo Cod. "Gestion Contenido SGA": aquí solo se decide.
/// </summary>
codeunit 51105 "Gestion Entradas SGA"
{
    Access = Public;

    /// <summary>
    /// Rellena el buffer con lo que ha entrado por el origen indicado (Producción para los
    /// ensamblados, Compra para las recepciones) entre dos fechas de registro. Cualquiera de las
    /// dos fechas puede ir en blanco: sin fechas se mira todo.
    /// prm_Clase filtra por la "Clase de articulo" de la ficha del producto (su valor de opción);
    /// -1 = todas. prm_Producto deja solo ese producto; en blanco, todos.
    /// Devuelve cuántas filas ha cargado.
    /// </summary>
    procedure CargarEntradas(var prm_Buffer: Record "Buffer Ubicar Entrada SGA"; prm_Origen: Enum "Origen Mov. SGA"; prm_FechaDesde: Date; prm_FechaHasta: Date; prm_Almacen: Code[10]; prm_SoloPendientes: Boolean; prm_Clase: Integer; prm_Producto: Code[20]): Integer
    var
        OrigenNoUbicableErr: Label 'Solo se pueden ubicar entradas de compra o de producción.';
    begin
        FechaDesde := prm_FechaDesde;
        FechaHasta := prm_FechaHasta;
        ClaseFiltro := prm_Clase;
        ProductoFiltro := prm_Producto;

        case prm_Origen of
            prm_Origen::Produccion:
                exit(CargarEnsamblados(prm_Buffer, prm_Almacen, prm_SoloPendientes));
            prm_Origen::Compra:
                exit(CargarRecepciones(prm_Buffer, prm_Almacen, prm_SoloPendientes));
            else
                Error(OrigenNoUbicableErr);
        end;
    end;

    /// <summary>
    /// Aplica el rango de fechas al campo de fecha de registro. Con las dos en blanco no filtra.
    /// </summary>
    local procedure FiltroFechas(prm_Desde: Date; prm_Hasta: Date): Text
    begin
        case true of
            (prm_Desde = 0D) and (prm_Hasta = 0D):
                exit('');
            prm_Desde = 0D:
                exit(StrSubstNo('..%1', prm_Hasta));
            prm_Hasta = 0D:
                exit(StrSubstNo('%1..', prm_Desde));
            else
                exit(StrSubstNo('%1..%2', prm_Desde, prm_Hasta));
        end;
    end;

    /// <summary>
    /// Si el producto es de la clase pedida en pantalla (o no se filtra por clase).
    /// </summary>
    local procedure ClaseAdmitida(var prm_Item: Record Item): Boolean
    begin
        if ClaseFiltro < 0 then
            exit(true);

        exit(prm_Item."Clase de articulo" = ClaseFiltro);
    end;

    /// <summary>
    /// Ensamblados de tipo Embotellado registrados en una fecha. Una fila por ensamblado. Las
    /// elaboraciones quedan fuera: su salida es granel a depósito, no va a hueco.
    /// </summary>
    local procedure CargarEnsamblados(var prm_Buffer: Record "Buffer Ubicar Entrada SGA"; prm_Almacen: Code[10]; prm_SoloPendientes: Boolean): Integer
    var
        rCabEns: Record "Posted Assembly Header";
        rItem: Record Item;
        rConfig: Record "Config. SGA";
        almacenFila: Code[10];
        cargadas: Integer;
    begin
        prm_Buffer.Reset();
        prm_Buffer.DeleteAll();

        rConfig.ObtenerConfig();

        if FiltroFechas(FechaDesde, FechaHasta) <> '' then
            rCabEns.SetFilter("Posting Date", FiltroFechas(FechaDesde, FechaHasta));
        // Solo embotellados: las elaboraciones sacan granel a depósito, que no va a hueco.
        rCabEns.SetRange("Tipo documento", rCabEns."Tipo documento"::Embotellado);
        if ProductoFiltro <> '' then
            rCabEns.SetRange("Item No.", ProductoFiltro);
        // El almacén no se filtra en la consulta: está oculto en el pedido de ensamblado
        // (Pag-Ext50105), así que casi todos se registran en blanco y filtrar por él dejaba la
        // lista siempre vacía. Se compara más abajo, ya con el almacén de la fila resuelto.
        if not rCabEns.FindSet() then
            exit(0);

        repeat
            if not rItem.Get(rCabEns."Item No.") then
                Clear(rItem);
            if (rCabEns."Item No." <> '') and (rCabEns.Quantity > 0) and ClaseAdmitida(rItem) then begin
                // El ensamblado puede no llevar almacén; en ese caso manda el filtro de la
                // pantalla y, si tampoco lo hay, el almacén por defecto de la configuración.
                almacenFila := rCabEns."Location Code";
                if almacenFila = '' then
                    almacenFila := prm_Almacen;
                if almacenFila = '' then
                    almacenFila := rConfig."Almacen por Defecto";

                prm_Buffer.Init();
                prm_Buffer.Origen := prm_Buffer.Origen::Produccion;
                prm_Buffer."No. Documento" := rCabEns."No.";
                prm_Buffer."Fecha Registro" := rCabEns."Posting Date";
                prm_Buffer."Cod. Almacen" := almacenFila;
                prm_Buffer."No. Producto" := rCabEns."Item No.";
                prm_Buffer."Cod. Variante" := rCabEns."Variant Code";
                prm_Buffer."No. Lote" := rCabEns.Lote;
                prm_Buffer."Cod. Unidad Medida" := rCabEns."Unit of Measure Code";
                prm_Buffer."Cantidad Entrada" := rCabEns.Quantity;
                prm_Buffer."Documento Relacionado" := rCabEns."Order No.";

                prm_Buffer."Descripcion Producto" := CopyStr(rItem.Description, 1, MaxStrLen(prm_Buffer."Descripcion Producto"));

                CalcularPendiente(prm_Buffer);

                // Si la pantalla pide un almacén concreto, el ensamblado registrado en otro no
                // es de esta lista; los que vienen en blanco ya han heredado el del filtro.
                if ((prm_Almacen = '') or (almacenFila = prm_Almacen)) and
                   ((not prm_SoloPendientes) or (not prm_Buffer.Ubicado)) then
                    if prm_Buffer.Insert() then
                        cargadas += 1;
            end;
        until rCabEns.Next() = 0;

        exit(cargadas);
    end;

    /// <summary>
    /// Recepciones de compra registradas en una fecha. Una fila por albarán, producto, variante,
    /// lote y unidad de medida.
    ///
    /// Se leen los movimientos de producto y no las líneas del albarán porque el lote y la
    /// caducidad solo están en el movimiento: la línea no los lleva. Además, deshacer una
    /// recepción genera un movimiento negativo en el mismo albarán, y al sumar por documento
    /// lo deshecho se descuenta solo.
    /// </summary>
    local procedure CargarRecepciones(var prm_Buffer: Record "Buffer Ubicar Entrada SGA"; prm_Almacen: Code[10]; prm_SoloPendientes: Boolean): Integer
    var
        rItemLedgEntry: Record "Item Ledger Entry";
        rItem: Record Item;
        rVendor: Record Vendor;
        TempFila: Record "Buffer Ubicar Entrada SGA";
        um: Code[10];
        factor: Decimal;
        cargadas: Integer;
    begin
        prm_Buffer.Reset();
        prm_Buffer.DeleteAll();

        rItemLedgEntry.SetRange("Entry Type", rItemLedgEntry."Entry Type"::Purchase);
        rItemLedgEntry.SetRange("Document Type", rItemLedgEntry."Document Type"::"Purchase Receipt");
        if FiltroFechas(FechaDesde, FechaHasta) <> '' then
            rItemLedgEntry.SetFilter("Posting Date", FiltroFechas(FechaDesde, FechaHasta));
        // Sin fecha de inicio se mirarían todas las compras de la historia. Se acota a las
        // recepciones que aún tienen stock (movimiento abierto): lo ya consumido o deshecho no
        // tiene nada que colocar en un hueco.
        if FechaDesde = 0D then
            rItemLedgEntry.SetRange(Open, true);
        if prm_Almacen <> '' then
            rItemLedgEntry.SetRange("Location Code", prm_Almacen);
        if ProductoFiltro <> '' then
            rItemLedgEntry.SetRange("Item No.", ProductoFiltro);
        if not rItemLedgEntry.FindSet() then
            exit(0);

        // Primera pasada: acumular por fila. Las cantidades se llevan a la UM del albarán, que
        // es en la que se ha recibido y en la que se deja en el hueco.
        repeat
            if not rItem.Get(rItemLedgEntry."Item No.") then
                Clear(rItem);
            if (rItem."No." <> '') and ClaseAdmitida(rItem) then begin
                um := rItemLedgEntry."Unit of Measure Code";
                if um = '' then
                    um := rItem."Base Unit of Measure";
                factor := rItemLedgEntry."Qty. per Unit of Measure";
                if factor <= 0 then
                    factor := 1;

                if prm_Buffer.Get(prm_Buffer.Origen::Compra, rItemLedgEntry."Document No.", rItemLedgEntry."Item No.",
                                  rItemLedgEntry."Variant Code", rItemLedgEntry."Lot No.", um) then begin
                    prm_Buffer."Cantidad Entrada" += Round(rItemLedgEntry.Quantity / factor, 0.00001);
                    prm_Buffer.Modify();
                end else begin
                    prm_Buffer.Init();
                    prm_Buffer.Origen := prm_Buffer.Origen::Compra;
                    prm_Buffer."No. Documento" := rItemLedgEntry."Document No.";
                    prm_Buffer."Fecha Registro" := rItemLedgEntry."Posting Date";
                    prm_Buffer."Cod. Almacen" := rItemLedgEntry."Location Code";
                    prm_Buffer."No. Producto" := rItemLedgEntry."Item No.";
                    prm_Buffer."Cod. Variante" := rItemLedgEntry."Variant Code";
                    prm_Buffer."No. Lote" := rItemLedgEntry."Lot No.";
                    prm_Buffer."Cod. Unidad Medida" := um;
                    prm_Buffer."Cantidad Entrada" := Round(rItemLedgEntry.Quantity / factor, 0.00001);
                    prm_Buffer."Descripcion Producto" := CopyStr(rItem.Description, 1, MaxStrLen(prm_Buffer."Descripcion Producto"));
                    if (rItemLedgEntry."Source Type" = rItemLedgEntry."Source Type"::Vendor) and
                       rVendor.Get(rItemLedgEntry."Source No.")
                    then
                        prm_Buffer."Descripcion Origen" := CopyStr(rVendor.Name, 1, MaxStrLen(prm_Buffer."Descripcion Origen"));
                    prm_Buffer.Insert();
                end;
            end;
        until rItemLedgEntry.Next() = 0;

        // Segunda pasada: con la cantidad neta ya sumada, ver cuánto falta y quitar lo que no
        // se tiene que enseñar (recepciones deshechas del todo, o ya ubicadas si se pide).
        TempFila.Copy(prm_Buffer, true);
        TempFila.Reset();
        if TempFila.FindSet() then
            repeat
                if TempFila."Cantidad Entrada" <= 0 then
                    TempFila.Delete()
                else begin
                    CalcularPendiente(TempFila);
                    if prm_SoloPendientes and TempFila.Ubicado then
                        TempFila.Delete()
                    else begin
                        TempFila.Modify();
                        cargadas += 1;
                    end;
                end;
            until TempFila.Next() = 0;

        exit(cargadas);
    end;

    /// <summary>
    /// Propone hueco para todas las filas que aún no lo tienen. Va reservando lo que asigna,
    /// para no mandar dos entradas distintas al mismo hueco vacío.
    /// </summary>
    procedure ProponerParaTodos(var prm_Buffer: Record "Buffer Ubicar Entrada SGA"): Integer
    var
        TempFila: Record "Buffer Ubicar Entrada SGA";
        asignadas: Text;
        motivo: Text;
        codigo: Code[20];
        propuestas: Integer;
    begin
        TempFila.Copy(prm_Buffer, true);
        TempFila.Reset();
        // Se recorre por la clave primaria a propósito: dentro del bucle se modifica
        // "Ubicacion Propuesta", y si el orden viniera de esa columna (porque el operario
        // haya ordenado por ella) el recorrido se saltaría filas o las repetiría.
        TempFila.SetCurrentKey(Origen, "No. Documento", "No. Producto", "Cod. Variante", "No. Lote", "Cod. Unidad Medida");
        if not TempFila.FindSet() then
            exit(0);

        repeat
            if (not TempFila.Ubicado) and (TempFila."Ubicacion Propuesta" = '') then begin
                codigo := ProponerParaFila(TempFila, asignadas, motivo);
                TempFila."Ubicacion Propuesta" := codigo;
                TempFila."Motivo Propuesta" := CopyStr(motivo, 1, MaxStrLen(TempFila."Motivo Propuesta"));
                TempFila."Ubicacion Confirmada" := codigo;
                TempFila.Modify();

                if codigo <> '' then begin
                    asignadas := cUbicaciones.AnadirExclusion(asignadas, codigo);
                    propuestas += 1;
                end;
            end else
                if TempFila."Ubicacion Propuesta" <> '' then
                    asignadas := cUbicaciones.AnadirExclusion(asignadas, TempFila."Ubicacion Propuesta");
        until TempFila.Next() = 0;

        exit(propuestas);
    end;

    /// <summary>
    /// Busca una alternativa para una fila, descartando la que ya se le había ofrecido y las
    /// que están reservadas por las demás filas.
    /// </summary>
    procedure ProponerOtra(var prm_Fila: Record "Buffer Ubicar Entrada SGA")
    var
        excluidas: Text;
        motivo: Text;
        codigo: Code[20];
        SinOtraUbicacionMsg: Label 'No hay otra ubicación disponible para %1. Se mantiene la propuesta anterior.', Comment = '%1 = producto';
    begin
        excluidas := ExclusionesDeOtrasFilas(prm_Fila);
        if prm_Fila."Ubicacion Propuesta" <> '' then
            excluidas := cUbicaciones.AnadirExclusion(excluidas, prm_Fila."Ubicacion Propuesta");

        codigo := ProponerParaFila(prm_Fila, excluidas, motivo);

        if codigo = '' then begin
            Message(SinOtraUbicacionMsg, prm_Fila."No. Producto");
            exit;
        end;

        prm_Fila."Ubicacion Propuesta" := codigo;
        prm_Fila."Motivo Propuesta" := CopyStr(motivo, 1, MaxStrLen(prm_Fila."Motivo Propuesta"));
        prm_Fila."Ubicacion Confirmada" := codigo;
        prm_Fila.Modify();
    end;

    /// <summary>
    /// Registra la entrada de una fila en la ubicación confirmada.
    /// </summary>
    procedure ConfirmarFila(var prm_Fila: Record "Buffer Ubicar Entrada SGA")
    var
        cContenido: Codeunit "Gestion Contenido SGA";
        descripcion: Text;
        UbicacionNoIndicadaErr: Label 'Indique la ubicación en la que ha dejado %1.', Comment = '%1 = producto';
        CantidadNoPositivaErr: Label 'La cantidad a ubicar de %1 debe ser mayor que cero.', Comment = '%1 = producto';
        CantidadExcedePendienteErr: Label 'Solo quedan %1 por ubicar de %2.', Comment = '%1 = pendiente, %2 = producto';
        EnsambladoLbl: Label 'Ensamblado %1', Comment = '%1 = nº ensamblado';
        RecepcionLbl: Label 'Recepción %1', Comment = '%1 = nº albarán de compra';
    begin
        if prm_Fila.Ubicado then
            exit;

        if prm_Fila."Ubicacion Confirmada" = '' then
            Error(UbicacionNoIndicadaErr, prm_Fila."No. Producto");

        if prm_Fila."Cantidad a Ubicar" <= 0 then
            Error(CantidadNoPositivaErr, prm_Fila."No. Producto");

        if prm_Fila."Cantidad a Ubicar" > prm_Fila.Pendiente() then
            Error(CantidadExcedePendienteErr, prm_Fila.Pendiente(), prm_Fila."No. Producto");

        if prm_Fila.Origen = prm_Fila.Origen::Compra then
            descripcion := StrSubstNo(RecepcionLbl, prm_Fila."No. Documento")
        else
            descripcion := StrSubstNo(EnsambladoLbl, prm_Fila."No. Documento");

        cContenido.RegistrarEntrada(prm_Fila."Cod. Almacen", prm_Fila."Ubicacion Confirmada",
                                    prm_Fila."No. Producto", prm_Fila."Cod. Variante", prm_Fila."No. Lote",
                                    prm_Fila."Cod. Unidad Medida", prm_Fila."Cantidad a Ubicar",
                                    prm_Fila.Origen, prm_Fila."No. Documento", 0, descripcion);

        CalcularPendiente(prm_Fila);
        prm_Fila.Modify();
    end;

    /// <summary>
    /// Registra todas las filas pendientes que ya tengan ubicación confirmada.
    /// Devuelve cuántas se han ubicado.
    /// </summary>
    procedure ConfirmarTodas(var prm_Buffer: Record "Buffer Ubicar Entrada SGA"): Integer
    var
        TempFila: Record "Buffer Ubicar Entrada SGA";
        hechas: Integer;
    begin
        TempFila.Copy(prm_Buffer, true);
        TempFila.Reset();
        // Por la clave primaria: dentro del bucle se marca "Ubicado", que forma parte de la
        // clave secundaria, y recorrer por ella mientras se modifica rompería el barrido.
        TempFila.SetCurrentKey(Origen, "No. Documento", "No. Producto", "Cod. Variante", "No. Lote", "Cod. Unidad Medida");
        if not TempFila.FindSet() then
            exit(0);

        repeat
            if (not TempFila.Ubicado) and (TempFila."Ubicacion Confirmada" <> '') and (TempFila."Cantidad a Ubicar" > 0) then begin
                ConfirmarFila(TempFila);
                hechas += 1;
            end;
        until TempFila.Next() = 0;

        exit(hechas);
    end;

    /// <summary>
    /// Prepara el palé que sale de una tarea de embotellado, para ubicarlo en cuanto se imprime
    /// su etiqueta. Deja en prm_Fila una sola fila, ya con hueco propuesto.
    ///
    /// La entrada se apunta al pedido de ensamblado enlazado a la tarea, con el nº del pedido:
    /// cuando se registre, "Ubicar entradas" suma lo ubicado con ese número y no lo pide otra
    /// vez. Si el pedido ya está registrado se sigue usando su nº de pedido, y lo que se haya
    /// ubicado con el del registrado también cuenta.
    ///
    /// Si el palé es completo o no lo dice la tarea: cada etiqueta es un palé de "Cod. Pale
    /// Defecto" y la tarea planifica NumBotellas (en la unidad base). La etiqueta n es completa
    /// si a lo planificado le queda al menos un palé después de las n-1 anteriores; si no, es el
    /// último palé, incompleto, con lo que queda. Tampoco se ubica nunca más de lo que falta
    /// del ensamblado.
    ///
    /// El palé completo se ubica en la unidad de palé. El incompleto, en cajas (la unidad de
    /// venta), que van a un hueco de caja o de palé según cuántas sean (ver TipoHuecoDestino en
    /// "Unidades Producto SGA"); las botellas que no lleguen a una caja quedan pendientes y se avisa. Si
    /// no llega a una caja, se ubica en unidades sueltas.
    ///
    /// Devuelve false, con el porqué en prm_Aviso, si no hay palé que ubicar. Con true, en
    /// prm_Aviso puede venir un aviso que no impide ubicar.
    /// </summary>
    procedure PrepararPaleTarea(prm_Tarea: Record "Tareas Produccion"; var prm_Fila: Record "Buffer Ubicar Entrada SGA"; var prm_Aviso: Text): Boolean
    var
        rCabEns: Record "Assembly Header";
        rCabEnsReg: Record "Posted Assembly Header";
        rItem: Record Item;
        rUMPale: Record "Item Unit of Measure";
        rConfig: Record "Config. SGA";
        TempTrozo: Record "Linea Ubicacion SGA" temporary;
        qtyPorUM: Decimal;
        factorPale: Decimal;
        factorDestino: Decimal;
        pendienteBase: Decimal;
        restantePlanBase: Decimal;
        paleBase: Decimal;
        sueltasBase: Decimal;
        entradaBase: Decimal;
        yaUbicadoBase: Decimal;
        umDestino: Code[10];
        cantidadDestino: Decimal;
        SueltasPendientesLbl: Label 'Palé incompleto: %1 %2 no llegan a una caja y quedan pendientes; ubíquelas desde "Ubicar producto".', Comment = '%1 = cantidad, %2 = unidad base';
        TareaSinEnsambladoLbl: Label 'La tarea %1 no tiene pedido de ensamblado enlazado: no se sabe a qué entrada apuntar el palé.', Comment = '%1 = nº tarea';
        SinUnidadPaleLbl: Label 'El producto %1 no tiene la unidad de palé %2 definida.', Comment = '%1 = producto, %2 = unidad de palé';
        EnsambladoYaUbicadoLbl: Label 'Ya está ubicado todo lo del ensamblado %1.', Comment = '%1 = nº pedido de ensamblado';
        SinAlmacenLbl: Label 'No hay almacén: ni el ensamblado lo lleva ni hay uno por defecto en la configuración SGA.';
        SinUbicacionLibreLbl: Label 'No hay ninguna ubicación libre que admita este palé.';
    begin
        prm_Fila.Reset();
        prm_Fila.DeleteAll();
        prm_Aviso := '';

        prm_Fila.Init();
        prm_Fila.Origen := prm_Fila.Origen::Produccion;

        rCabEns.SetRange("Document Type", rCabEns."Document Type"::Order);
        rCabEns.SetRange("Linked Tarea", prm_Tarea.Linea);
        if rCabEns.FindFirst() then begin
            prm_Fila."No. Documento" := rCabEns."No.";
            prm_Fila."Cod. Almacen" := rCabEns."Location Code";
            prm_Fila."No. Producto" := rCabEns."Item No.";
            prm_Fila."Cod. Variante" := rCabEns."Variant Code";
            prm_Fila."No. Lote" := rCabEns.Lote;
            prm_Fila."Cod. Unidad Medida" := rCabEns."Unit of Measure Code";
            prm_Fila."Cantidad Entrada" := rCabEns.Quantity;
            qtyPorUM := rCabEns."Qty. per Unit of Measure";
        end else begin
            rCabEnsReg.SetRange("Linked Tarea", prm_Tarea.Linea);
            if not rCabEnsReg.FindLast() then begin
                prm_Aviso := StrSubstNo(TareaSinEnsambladoLbl, prm_Tarea.Linea);
                exit(false);
            end;
            prm_Fila."No. Documento" := rCabEnsReg."Order No.";
            prm_Fila."Documento Relacionado" := rCabEnsReg."No.";
            prm_Fila."Fecha Registro" := rCabEnsReg."Posting Date";
            prm_Fila."Cod. Almacen" := rCabEnsReg."Location Code";
            prm_Fila."No. Producto" := rCabEnsReg."Item No.";
            prm_Fila."Cod. Variante" := rCabEnsReg."Variant Code";
            prm_Fila."No. Lote" := rCabEnsReg.Lote;
            prm_Fila."Cod. Unidad Medida" := rCabEnsReg."Unit of Measure Code";
            prm_Fila."Cantidad Entrada" := rCabEnsReg.Quantity;
            qtyPorUM := rCabEnsReg."Qty. per Unit of Measure";
        end;

        // Mismo criterio que CargarEnsamblados: el almacén suele ir en blanco en el ensamblado.
        if prm_Fila."Cod. Almacen" = '' then begin
            rConfig.ObtenerConfig();
            prm_Fila."Cod. Almacen" := rConfig."Almacen por Defecto";
        end;
        if prm_Fila."Cod. Almacen" = '' then begin
            prm_Aviso := SinAlmacenLbl;
            exit(false);
        end;

        if rItem.Get(prm_Fila."No. Producto") then
            prm_Fila."Descripcion Producto" := CopyStr(rItem.Description, 1, MaxStrLen(prm_Fila."Descripcion Producto"));

        if not rUMPale.Get(prm_Fila."No. Producto", prm_Tarea."Cod. Pale Defecto") or
           (rUMPale."Qty. per Unit of Measure" <= 0)
        then begin
            prm_Aviso := StrSubstNo(SinUnidadPaleLbl, prm_Fila."No. Producto", prm_Tarea."Cod. Pale Defecto");
            exit(false);
        end;
        if qtyPorUM <= 0 then
            qtyPorUM := 1;
        factorPale := rUMPale."Qty. per Unit of Measure";

        CalcularPendiente(prm_Fila);
        if prm_Fila.Ubicado then begin
            prm_Aviso := StrSubstNo(EnsambladoYaUbicadoLbl, prm_Fila."No. Documento");
            exit(false);
        end;

        // Cuánto lleva este palé, en unidad base: completo, salvo que sea el último de la tarea.
        paleBase := factorPale;
        if prm_Tarea.NumBotellas > 0 then begin
            restantePlanBase := prm_Tarea.NumBotellas - prm_Tarea."Etiquetas Impresas" * factorPale;
            if (restantePlanBase > 0) and (restantePlanBase < factorPale) then
                paleBase := restantePlanBase;
        end;
        pendienteBase := Round(prm_Fila.Pendiente() * qtyPorUM, 0.00001);
        if paleBase > pendienteBase then
            paleBase := pendienteBase;

        // Unidad en la que se ubica: palé completo, cajas o, si no llega a una caja, unidades. Es
        // el primer trozo del reparto con el palé de la tarea; las sueltas que sobren de las
        // cajas quedan pendientes.
        cUM.Repartir(prm_Fila."No. Producto", paleBase, rUMPale.Code, TempTrozo);
        if not TempTrozo.FindFirst() then begin
            prm_Aviso := StrSubstNo(EnsambladoYaUbicadoLbl, prm_Fila."No. Documento");
            exit(false);
        end;
        umDestino := TempTrozo."Cod. Unidad Medida";
        cantidadDestino := TempTrozo.Cantidad;
        if umDestino <> rItem."Base Unit of Measure" then begin
            TempTrozo.SetRange("Cod. Unidad Medida", rItem."Base Unit of Measure");
            if TempTrozo.FindFirst() then
                sueltasBase := TempTrozo."Cantidad Base";
        end;

        // La fila pasa entera a esa unidad, para que el pendiente y lo ya ubicado se comparen
        // en la misma unidad que se va a registrar.
        factorDestino := cUM.FactorUM(prm_Fila."No. Producto", umDestino);
        entradaBase := prm_Fila."Cantidad Entrada" * qtyPorUM;
        yaUbicadoBase := prm_Fila."Cantidad Ya Ubicada" * qtyPorUM;
        prm_Fila."Cod. Unidad Medida" := umDestino;
        prm_Fila."Cantidad Entrada" := Round(entradaBase / factorDestino, 0.00001);
        prm_Fila."Cantidad Ya Ubicada" := Round(yaUbicadoBase / factorDestino, 0.00001);
        prm_Fila."Cantidad a Ubicar" := cantidadDestino;
        prm_Fila.Insert();

        if ProponerParaTodos(prm_Fila) = 0 then
            prm_Aviso := SinUbicacionLibreLbl
        else
            if sueltasBase > 0 then
                prm_Aviso := StrSubstNo(SueltasPendientesLbl, sueltasBase, rItem."Base Unit of Measure");
        // La propuesta se ha guardado desde otra variable: se relee para traerla.
        prm_Fila.FindFirst();

        exit(true);
    end;

    /// <summary>
    /// Propuesta para una fila concreta, con la estrategia que diga la configuración para
    /// su origen.
    /// </summary>
    local procedure ProponerParaFila(var prm_Fila: Record "Buffer Ubicar Entrada SGA"; prm_Excluidas: Text; var prm_Motivo: Text): Code[20]
    var
        rConfig: Record "Config. SGA";
        estrategia: Enum "Estrategia Ubicacion SGA";
        cantidad: Decimal;
    begin
        rConfig.ObtenerConfig();

        if prm_Fila.Origen = prm_Fila.Origen::Compra then
            estrategia := rConfig."Estrategia Ubic. Compras"
        else
            estrategia := rConfig."Estrategia Ubic. Ensamblados";

        cantidad := prm_Fila."Cantidad a Ubicar";
        if cantidad <= 0 then
            cantidad := prm_Fila.Pendiente();

        // Sin hueco, el motivo dice por qué: sin ubicaciones de esa clase, sin espacio, etc.
        exit(cUbicaciones.ProponerUbicacionCon(estrategia, prm_Excluidas,
                                               prm_Fila."Cod. Almacen", prm_Fila."No. Producto",
                                               prm_Fila."Cod. Variante", prm_Fila."No. Lote",
                                               prm_Fila."Cod. Unidad Medida", cantidad, prm_Motivo));
    end;

    /// <summary>
    /// Rellena lo ya ubicado, lo que queda y la marca de terminado de una fila.
    /// </summary>
    local procedure CalcularPendiente(var prm_Fila: Record "Buffer Ubicar Entrada SGA")
    begin
        prm_Fila."Cantidad Ya Ubicada" := CantidadYaUbicada(prm_Fila.Origen, prm_Fila."No. Documento", prm_Fila."No. Producto",
                                                            prm_Fila."Cod. Variante", prm_Fila."No. Lote", prm_Fila."Cod. Unidad Medida");
        // Los palés ubicados al imprimir su etiqueta (Ubicar Palets Linea SGA) van con el nº del
        // pedido de ensamblado, que no es el del registrado: sin sumarlos se ubicarían dos veces.
        if (prm_Fila."Documento Relacionado" <> '') and (prm_Fila."Documento Relacionado" <> prm_Fila."No. Documento") then
            prm_Fila."Cantidad Ya Ubicada" += CantidadYaUbicada(prm_Fila.Origen, prm_Fila."Documento Relacionado", prm_Fila."No. Producto",
                                                                prm_Fila."Cod. Variante", prm_Fila."No. Lote", prm_Fila."Cod. Unidad Medida");
        prm_Fila."Cantidad a Ubicar" := prm_Fila.Pendiente();
        prm_Fila.Ubicado := prm_Fila.Pendiente() <= 0;
    end;

    /// <summary>
    /// Cantidad de una entrada que SGA ya tiene colocada, leída del diario de movimientos.
    ///
    /// Se suma recorriendo en vez de con CalcSums porque la única clave que cubre este filtro
    /// (Origen + documento) no lleva sumatorios, y son unos pocos movimientos por documento.
    /// En las recepciones se filtra por unidad de medida: un albarán puede traer el mismo lote
    /// en cajas y en palés, en filas distintas, y no hay que mezclarlas.
    /// En producción hay una sola fila por ensamblado, pero sus palés pueden haberse ubicado en
    /// otra unidad al imprimir la etiqueta (palé, cajas o unidades, ver PrepararPaleTarea). Ahí
    /// se suma todo en unidad base y se devuelve en la unidad pedida, para no ubicarlo dos veces.
    /// </summary>
    local procedure CantidadYaUbicada(prm_Origen: Enum "Origen Mov. SGA"; prm_NoDocumento: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_UM: Code[10]): Decimal
    var
        rMov: Record "Movimiento Ubicacion SGA";
        total: Decimal;
        totalBase: Decimal;
        todasLasUM: Boolean;
    begin
        if prm_NoDocumento = '' then
            exit(0);

        todasLasUM := prm_Origen = prm_Origen::Produccion;

        rMov.SetCurrentKey(Origen, "No. Documento Origen", "No. Linea Origen");
        rMov.SetRange(Origen, prm_Origen);
        rMov.SetRange("No. Documento Origen", prm_NoDocumento);
        rMov.SetRange("No. Producto", prm_Producto);
        rMov.SetRange("Cod. Variante", prm_Variante);
        rMov.SetRange("No. Lote", prm_Lote);
        if not todasLasUM then
            rMov.SetRange("Cod. Unidad Medida", prm_UM);
        rMov.SetRange("Tipo Movimiento", rMov."Tipo Movimiento"::Entrada);
        if not rMov.FindSet() then
            exit(0);

        repeat
            total += rMov.Cantidad;
            totalBase += rMov."Cantidad Base";
        until rMov.Next() = 0;

        if todasLasUM then
            exit(Round(totalBase / cUM.FactorUM(prm_Producto, prm_UM), 0.00001));
        exit(total);
    end;

    /// <summary>
    /// Filtro de exclusión con los huecos que ya tienen reservadas las demás filas.
    /// </summary>
    local procedure ExclusionesDeOtrasFilas(var prm_Fila: Record "Buffer Ubicar Entrada SGA"): Text
    var
        TempOtra: Record "Buffer Ubicar Entrada SGA";
        excluidas: Text;
    begin
        // Copia del conjunto temporal completo: recorrerla no mueve el cursor de la fila
        // sobre la que está el operario.
        TempOtra.Copy(prm_Fila, true);
        TempOtra.Reset();
        if not TempOtra.FindSet() then
            exit('');

        // Se compara la fila entera y no solo el documento: un albarán trae varias filas y
        // cada una necesita su propio hueco.
        repeat
            if TempOtra.GetPosition() <> prm_Fila.GetPosition() then
                if TempOtra."Ubicacion Propuesta" <> '' then
                    excluidas := cUbicaciones.AnadirExclusion(excluidas, TempOtra."Ubicacion Propuesta");
        until TempOtra.Next() = 0;

        exit(excluidas);
    end;

    var
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        cUM: Codeunit "Unidades Producto SGA";
        FechaDesde: Date;
        FechaHasta: Date;
        ClaseFiltro: Integer;
        ProductoFiltro: Code[20];
}
