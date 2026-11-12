namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;

/// <summary>
/// Codeunit Consulta Stock SGA (ID 51103).
/// Responde a "cuánto hay en BC y cuánto en SGA". Único sitio que traduce los movimientos de
/// producto de BC a "cuánto stock hay de este producto, en este almacén, de cada lote", sobre
/// la tabla "Buffer Conciliacion SGA". Lo usan la carga inicial, la conciliación y la página
/// "Pendiente Ubicar SGA" (con la tabla en temporal), para que todas midan exactamente lo mismo.
/// También da lo ya ubicado y lo pendiente de un producto, la caducidad de un lote, si el
/// producto lleva lotes estándar (LoteEstandar) y la consulta de dónde está un producto, y
/// regulariza una fila de la conciliación en la ubicación de ajustes (RegularizarConciliacion).
///
/// El stock por lote se obtiene de la cantidad pendiente de los movimientos abiertos, que
/// es la forma en que BC representa las existencias vivas de cada lote.
/// </summary>
codeunit 51103 "Consulta Stock SGA"
{
    /// <summary>
    /// Acumula en el buffer el stock de BC de un producto en un almacén, desglosado por
    /// variante y lote. No borra el buffer: suma sobre lo que ya haya, de modo que se puede
    /// llamar en bucle para varios productos. Con el producto en blanco, todos los del almacén
    /// en una sola lectura (Pendiente de ubicar).
    /// </summary>
    procedure AcumularStockPorLote(prm_Producto: Code[20]; prm_Almacen: Code[10]; var rStock: Record "Buffer Conciliacion SGA")
    var
        rItemLedgEntry: Record "Item Ledger Entry";
        cUM: Codeunit "Unidades Producto SGA";
        umBase: Code[10];
    begin
        rItemLedgEntry.SetCurrentKey("Item No.", Open, "Variant Code", Positive, "Location Code", "Posting Date");
        if prm_Producto <> '' then
            rItemLedgEntry.SetRange("Item No.", prm_Producto);
        rItemLedgEntry.SetRange(Open, true);
        if prm_Almacen <> '' then
            rItemLedgEntry.SetRange("Location Code", prm_Almacen);
        rItemLedgEntry.SetLoadFields("Item No.", "Variant Code", "Location Code", "Lot No.", "Remaining Quantity");
        if not rItemLedgEntry.FindSet() then
            exit;

        repeat
            // Los movimientos de un producto que ya no existe no se acumulan.
            if rItemLedgEntry."Remaining Quantity" <> 0 then
                if cUM.LeerUMBase(rItemLedgEntry."Item No.", umBase) then
                    AcumularFila(rStock, rItemLedgEntry."Item No.", rItemLedgEntry."Variant Code", rItemLedgEntry."Location Code",
                                 rItemLedgEntry."Lot No.", umBase, rItemLedgEntry."Remaining Quantity", 0);
        until rItemLedgEntry.Next() = 0;
    end;

    /// <summary>
    /// Acumula en el buffer el contenido que SGA tiene ubicado de un producto,
    /// desglosado por variante y lote. Con el producto en blanco, todos los del almacén.
    /// </summary>
    procedure AcumularContenidoUbicado(prm_Producto: Code[20]; prm_Almacen: Code[10]; var rStock: Record "Buffer Conciliacion SGA")
    var
        rContenido: Record "Contenido Ubicacion SGA";
        cUM: Codeunit "Unidades Producto SGA";
        umBase: Code[10];
    begin
        rContenido.SetCurrentKey("No. Producto", "Cod. Variante", "Cod. Almacen", "No. Lote");
        if prm_Producto <> '' then
            rContenido.SetRange("No. Producto", prm_Producto);
        if prm_Almacen <> '' then
            rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetLoadFields("No. Producto", "Cod. Variante", "Cod. Almacen", "No. Lote", "Cantidad Base");
        if not rContenido.FindSet() then
            exit;

        repeat
            if cUM.LeerUMBase(rContenido."No. Producto", umBase) then
                AcumularFila(rStock, rContenido."No. Producto", rContenido."Cod. Variante", rContenido."Cod. Almacen",
                             rContenido."No. Lote", umBase, 0, rContenido."Cantidad Base");
        until rContenido.Next() = 0;
    end;

    /// <summary>
    /// Deja en el buffer solo las filas con diferencia, y clasifica todas las que quedan.
    /// </summary>
    procedure ClasificarYFiltrar(var rStock: Record "Buffer Conciliacion SGA"; prm_SoloDiferencias: Boolean)
    begin
        // Siempre acotado al usuario: el buffer es compartido y dos personas pueden
        // estar conciliando a la vez.
        rStock.Reset();
        rStock.FiltrarUsuarioActual();

        if rStock.FindSet() then
            repeat
                rStock.ActualizarEstado();
                rStock.Modify();
            until rStock.Next() = 0;

        if not prm_SoloDiferencias then
            exit;

        rStock.SetRange(Diferencia, 0);
        rStock.DeleteAll();
        rStock.SetRange(Diferencia);
    end;

    /// <summary>
    /// Borra los resultados de la conciliación anterior de este usuario.
    /// </summary>
    procedure LimpiarBuffer(var rStock: Record "Buffer Conciliacion SGA")
    begin
        rStock.Reset();
        rStock.FiltrarUsuarioActual();
        rStock.DeleteAll();
        rStock.Reset();
    end;

    /// <summary>
    /// Cuadra una fila de la conciliación con stock de BC sin ubicar: coloca la diferencia en
    /// la ubicación de ajustes, tras confirmarlo el usuario, y deja la fila cuadrada. Solo
    /// toca la capa de ubicaciones; el stock de BC no cambia. Si en la fila sobra contenido en
    /// las ubicaciones no regulariza nada, porque no se sabe de qué hueco sale el exceso.
    /// Devuelve true si ha registrado el ajuste.
    /// </summary>
    procedure RegularizarConciliacion(var prm_Fila: Record "Buffer Conciliacion SGA"): Boolean
    var
        rConfig: Record "Config. SGA";
        rBuffer: Record "Buffer Conciliacion SGA";
        cContenido: Codeunit "Gestion Contenido SGA";
        LineaYaCuadraMsg: Label 'Esta línea ya cuadra.';
        UbicAjustesSinConfigurarErr: Label 'Debe configurar la ubicación de ajustes en la configuración de SGA.';
        ColocarEnAjustesQst: Label 'Se van a colocar %1 unidades de %2 en la ubicación de ajustes %3, para que dejen de estar sin ubicar. El stock de BC no cambia. ¿Desea continuar?', Comment = '%1 = diferencia, %2 = producto, %3 = ubicación de ajustes';
        RegularizacionConciliacionLbl: Label 'Regularización conciliación';
        SobraContenidoMsg: Label 'En esta línea sobra contenido en las ubicaciones (%1 unidades de más). No se puede regularizar automáticamente, porque hay que decidir de qué ubicación sale el exceso: recuente las ubicaciones que contienen el producto.', Comment = '%1 = exceso';
    begin
        if prm_Fila.Diferencia = 0 then begin
            Message(LineaYaCuadraMsg);
            exit(false);
        end;

        // El exceso en ubicaciones no se puede cuadrar solo: no sabemos de qué hueco sale.
        if prm_Fila.Diferencia < 0 then begin
            Message(SobraContenidoMsg, -prm_Fila.Diferencia);
            exit(false);
        end;

        rConfig.ObtenerConfig();
        if rConfig."Ubic. Ajustes" = '' then
            Error(UbicAjustesSinConfigurarErr);

        if not Confirm(ColocarEnAjustesQst, false, prm_Fila.Diferencia, prm_Fila."No. Producto", rConfig."Ubic. Ajustes") then
            exit(false);

        // El stock que BC tiene y SGA no aparece en la ubicación de ajustes hasta que
        // alguien lo coloque físicamente donde le corresponde.
        if cContenido.RegistrarAjuste(prm_Fila."Cod. Almacen", rConfig."Ubic. Ajustes", prm_Fila."No. Producto",
                                      prm_Fila."Cod. Variante", prm_Fila."No. Lote", prm_Fila."Unidad Medida Base",
                                      prm_Fila.Diferencia, RegularizacionConciliacionLbl) = 0
        then
            exit(false);

        if rBuffer.Get(prm_Fila."Cod. Usuario", prm_Fila."No. Producto", prm_Fila."Cod. Variante", prm_Fila."Cod. Almacen", prm_Fila."No. Lote") then begin
            rBuffer."Stock SGA" := rBuffer."Stock BC";
            rBuffer.ActualizarEstado();
            rBuffer.Modify();
        end;

        exit(true);
    end;

    local procedure AcumularFila(var rStock: Record "Buffer Conciliacion SGA"; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Almacen: Code[10]; prm_Lote: Code[50]; prm_UMBase: Code[10]; prm_StockBC: Decimal; prm_StockSGA: Decimal)
    var
        usuario: Code[50];
    begin
        usuario := CopyStr(UserId(), 1, MaxStrLen(rStock."Cod. Usuario"));

        if rStock.Get(usuario, prm_Producto, prm_Variante, prm_Almacen, prm_Lote) then begin
            rStock."Stock BC" := rStock."Stock BC" + prm_StockBC;
            rStock."Stock SGA" := rStock."Stock SGA" + prm_StockSGA;
            rStock.Modify();
            exit;
        end;

        rStock.Init();
        rStock."Cod. Usuario" := usuario;
        rStock."No. Producto" := prm_Producto;
        rStock."Cod. Variante" := prm_Variante;
        rStock."Cod. Almacen" := prm_Almacen;
        rStock."No. Lote" := prm_Lote;
        rStock."Unidad Medida Base" := prm_UMBase;
        rStock."Stock BC" := prm_StockBC;
        rStock."Stock SGA" := prm_StockSGA;
        rStock.Insert();
    end;

    /// <summary>
    /// Lo que hay en stock y no está en ninguna ubicación, por producto, variante y lote, en un
    /// almacén. Deja en prm_Pendiente una línea por cada lote con algo sin ubicar (Diferencia,
    /// en unidad base) y devuelve cuántas. prm_Pendiente tiene que ser temporal: se vacía entero,
    /// sin mirar el usuario, y la tabla real guarda la conciliación de todos.
    ///
    /// De lo sin ubicar se separa lo que está pendiente en "Ubicar recepciones" o "Ubicar
    /// ensamblados" (En Documentos): eso se ubica desde esas pantallas, que lo cuentan por su
    /// documento; si se ubicara por otro lado, lo volverían a pedir. Lo que queda (A Ubicar)
    /// no tiene documento que lo reclame: restos de una carga inicial, ajustes, etc.
    ///
    /// Solo cuenta los productos de tipo Inventario con existencias en el almacén, y solo mira los
    /// documentos de los lotes que tienen algo sin ubicar.
    ///
    /// El stock y el contenido de todo el almacén se leen de una vez (dos consultas, no dos por
    /// producto). Las existencias de un producto son la suma de sus lotes: lo que queda en los
    /// movimientos abiertos suma lo mismo que su Inventory.
    /// </summary>
    procedure CargarPendienteUbicar(prm_Almacen: Code[10]; var prm_Pendiente: Record "Buffer Conciliacion SGA" temporary): Integer
    var
        rItem: Record Item;
        TempStock: Record "Buffer Conciliacion SGA" temporary;
        TempEntradas: Record "Linea Ubicacion SGA" temporary;
        cEntradas: Codeunit "Gestion Entradas SGA";
        cUM: Codeunit "Unidades Producto SGA";
        cVentana: Codeunit "Ventana Progreso SGA";
        existencias: Dictionary of [Code[20], Decimal];
        producto: Code[20];
        productoCuenta: Boolean;
        suma: Decimal;
        cantidadDoc: Decimal;
        lineas: Integer;
        PendienteNoTemporalErr: Label 'El pendiente de ubicar solo se calcula sobre una tabla temporal.';
        TituloLbl: Label 'Calculando lo pendiente de ubicar…';
        LeyendoStockLbl: Label 'Leyendo el stock y las ubicaciones del almacén';
        ProductoLbl: Label 'Producto %1', Comment = '%1 = nº de producto';
    begin
        if not prm_Pendiente.IsTemporary() then
            Error(PendienteNoTemporalErr);
        prm_Pendiente.Reset();
        prm_Pendiente.DeleteAll();

        // Se enseña en qué va: las dos lecturas del almacén y luego lote a lote.
        cVentana.Abrir(TituloLbl, 0);
        cVentana.Fase(LeyendoStockLbl);

        AcumularStockPorLote('', prm_Almacen, TempStock);
        AcumularContenidoUbicado('', prm_Almacen, TempStock);

        if TempStock.FindSet() then
            repeat
                suma := 0;
                if existencias.Get(TempStock."No. Producto", suma) then;
                existencias.Set(TempStock."No. Producto", suma + TempStock."Stock BC");
            until TempStock.Next() = 0;

        // Por la clave primaria, que agrupa por producto (el buffer es de un solo usuario).
        TempStock.SetFilter("Stock BC", '>0');
        if not TempStock.FindSet() then begin
            cVentana.Cerrar();
            exit(0);
        end;
        cVentana.FijarTotal(TempStock.Count());

        rItem.SetLoadFields(Type);
        producto := '';
        repeat
            cVentana.Avanzar(StrSubstNo(ProductoLbl, TempStock."No. Producto"));
            if TempStock."No. Producto" <> producto then begin
                producto := TempStock."No. Producto";
                productoCuenta := false;
                if existencias.Get(producto) > 0 then
                    if rItem.Get(producto) then
                        productoCuenta := rItem.Type = rItem.Type::Inventory;
            end;

            if productoCuenta then begin
                prm_Pendiente := TempStock;
                prm_Pendiente.ActualizarEstado();
                if prm_Pendiente.Diferencia > 0 then begin
                    prm_Pendiente."Fecha Caducidad" := CaducidadLote(producto, TempStock."Cod. Variante", TempStock."No. Lote");

                    cantidadDoc := PendienteEnDocumentos(cEntradas, TempEntradas, "Origen Mov. SGA"::Compra, prm_Almacen, TempStock) +
                                   PendienteEnDocumentos(cEntradas, TempEntradas, "Origen Mov. SGA"::Produccion, prm_Almacen, TempStock);
                    if cantidadDoc > prm_Pendiente.Diferencia then
                        cantidadDoc := prm_Pendiente.Diferencia;
                    prm_Pendiente."En Documentos" := cantidadDoc;
                    prm_Pendiente."A Ubicar" := prm_Pendiente.Diferencia - cantidadDoc;
                    prm_Pendiente.Desglose := CopyStr(cUM.Desglose(producto, prm_Pendiente."A Ubicar"), 1, MaxStrLen(prm_Pendiente.Desglose));
                    prm_Pendiente.Insert();
                    lineas += 1;
                end;
            end;
        until TempStock.Next() = 0;

        cVentana.Cerrar();
        exit(lineas);
    end;

    /// <summary>
    /// De dónde sale el "En Documentos" de una línea de Pendiente de ubicar: abre Ubicar
    /// recepciones o Ubicar ensamblados con lo pendiente del producto en el almacén. Si el lote
    /// está pendiente en los dos, pregunta cuál.
    /// </summary>
    procedure MostrarEnDocumentos(var prm_Linea: Record "Buffer Conciliacion SGA" temporary)
    var
        TempEntradas: Record "Linea Ubicacion SGA" temporary;
        cEntradas: Codeunit "Gestion Entradas SGA";
        pEntradas: Page "Ubicar Entradas SGA";
        origen: Enum "Origen Mov. SGA";
        enCompra: Decimal;
        enProduccion: Decimal;
        NadaEnDocumentosMsg: Label 'Este lote no tiene nada pendiente en recepciones ni en ensamblados.';
        OrigenesTxt: Label 'Recepciones de compra,Ensamblados';
        ElegirOrigenLbl: Label 'El lote está pendiente en recepciones y en ensamblados. ¿Cuál quiere ver?';
    begin
        enCompra := PendienteEnDocumentos(cEntradas, TempEntradas, "Origen Mov. SGA"::Compra, prm_Linea."Cod. Almacen", prm_Linea);
        enProduccion := PendienteEnDocumentos(cEntradas, TempEntradas, "Origen Mov. SGA"::Produccion, prm_Linea."Cod. Almacen", prm_Linea);
        case true of
            (enCompra > 0) and (enProduccion > 0):
                case StrMenu(OrigenesTxt, 1, ElegirOrigenLbl) of
                    1:
                        origen := origen::Compra;
                    2:
                        origen := origen::Produccion;
                    else
                        exit;
                end;
            enCompra > 0:
                origen := origen::Compra;
            enProduccion > 0:
                origen := origen::Produccion;
            else begin
                Message(NadaEnDocumentosMsg);
                exit;
            end;
        end;

        pEntradas.Preparar(origen, prm_Linea."Cod. Almacen", prm_Linea."No. Producto");
        pEntradas.RunModal();
    end;

    /// <summary>
    /// De dónde sale el "Stock BC" de una línea de la conciliación o de Pendiente de ubicar: los
    /// movimientos de producto abiertos de ese producto, variante y lote en el almacén, que son
    /// los que suma AcumularStockPorLote.
    /// </summary>
    procedure MostrarStockBC(var prm_Linea: Record "Buffer Conciliacion SGA")
    var
        rItemLedgEntry: Record "Item Ledger Entry";
    begin
        rItemLedgEntry.SetRange("Item No.", prm_Linea."No. Producto");
        rItemLedgEntry.SetRange("Variant Code", prm_Linea."Cod. Variante");
        rItemLedgEntry.SetRange("Location Code", prm_Linea."Cod. Almacen");
        rItemLedgEntry.SetRange("Lot No.", prm_Linea."No. Lote");
        rItemLedgEntry.SetRange(Open, true);
        Page.Run(Page::"Item Ledger Entries", rItemLedgEntry);
    end;

    /// <summary>
    /// Lo que queda por ubicar de un lote (producto, variante y lote de prm_Lote), en unidad
    /// base, en las pantallas de entradas de ese origen (recepciones o ensamblados), desde la
    /// fecha de inicio de SGA. Lo de documentos anteriores queda en "A Ubicar": ya es stock de BC.
    /// </summary>
    local procedure PendienteEnDocumentos(var prm_Entradas: Codeunit "Gestion Entradas SGA"; var prm_Buffer: Record "Linea Ubicacion SGA" temporary; prm_Origen: Enum "Origen Mov. SGA"; prm_Almacen: Code[10]; var prm_Lote: Record "Buffer Conciliacion SGA" temporary): Decimal
    var
        cUM: Codeunit "Unidades Producto SGA";
        total: Decimal;
    begin
        prm_Entradas.CargarEntradasLote(prm_Buffer, prm_Origen, prm_Almacen, prm_Lote."No. Producto", prm_Lote."Cod. Variante", prm_Lote."No. Lote");
        prm_Buffer.Reset();
        if prm_Buffer.FindSet() then
            repeat
                total += prm_Buffer.Pendiente() * cUM.FactorUM(prm_Buffer."No. Producto", prm_Buffer."Cod. Unidad Medida");
            until prm_Buffer.Next() = 0;
        exit(total);
    end;

    /// <summary>
    /// Cantidad ya repartida en ubicaciones, en unidad de medida base.
    /// El almacén, la variante y el lote solo filtran si vienen informados, de modo que con
    /// solo el producto se obtiene el total de todo el almacén.
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
    /// almacén menos lo que SGA ya tiene repartido en ubicaciones. En unidad de medida base.
    ///
    /// Devuelve también el stock y lo ya ubicado por referencia, porque un pendiente a cero
    /// no dice si es que no hay stock o si es que ya está todo colocado.
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
    /// Dónde está un producto: abre "Consulta Ubic. Producto SGA" con los filtros que vengan
    /// informados.
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
    /// Caducidad de un lote: la del último movimiento de producto del lote que la lleva, en
    /// cualquier almacén. La variante solo filtra si viene informada. Es la fecha que se guarda
    /// en el contenido y en los movimientos al ubicar, y la que enseña "Pendiente de ubicar".
    /// </summary>
    procedure CaducidadLote(prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]): Date
    var
        rItemLedgEntry: Record "Item Ledger Entry";
    begin
        if prm_Lote = '' then
            exit(0D);

        // La caducidad se toma de los movimientos de producto del lote, que es donde ya
        // la registran los flujos de compra y de fabricación.
        rItemLedgEntry.SetRange("Item No.", prm_Producto);
        rItemLedgEntry.SetRange("Lot No.", prm_Lote);
        if prm_Variante <> '' then
            rItemLedgEntry.SetRange("Variant Code", prm_Variante);
        rItemLedgEntry.SetFilter("Expiration Date", '<>%1', 0D);
        rItemLedgEntry.SetLoadFields("Expiration Date");
        if rItemLedgEntry.FindLast() then
            exit(rItemLedgEntry."Expiration Date");

        exit(0D);
    end;

    /// <summary>
    /// Si el producto lleva lotes con el seguimiento estándar de BC: código de seguimiento con
    /// "Seguim. específico lote". Decide de dónde sale el lote en todo SGA: con él, del
    /// seguimiento de BC (y el picking lo escribe en el pedido); sin él, del lote propio del
    /// ensamblado, y al pedido no se le pone seguimiento.
    /// </summary>
    procedure LoteEstandar(prm_Producto: Code[20]): Boolean
    var
        rItem: Record Item;
        rCodigoSeguimiento: Record "Item Tracking Code";
    begin
        rItem.SetLoadFields("Item Tracking Code");
        if not rItem.Get(prm_Producto) then
            exit(false);
        if rItem."Item Tracking Code" = '' then
            exit(false);

        rCodigoSeguimiento.SetLoadFields("Lot Specific Tracking");
        if not rCodigoSeguimiento.Get(rItem."Item Tracking Code") then
            exit(false);

        exit(rCodigoSeguimiento."Lot Specific Tracking");
    end;
}
