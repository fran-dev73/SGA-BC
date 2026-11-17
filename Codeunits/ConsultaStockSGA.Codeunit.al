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
        cUM: Codeunit "Unidades Producto SGA";
        qMovsAbiertos: Query "Grouped Item Ledger Entries";
        umBase: Code[10];
    begin
        // La query estándar suma la cantidad pendiente de los movimientos abiertos; agrupa
        // también por UM, serie y paquete, y AcumularFila junta lo que cae en la misma fila.
        if prm_Producto <> '' then
            qMovsAbiertos.SetRange(Item_No, prm_Producto);
        if prm_Almacen <> '' then
            qMovsAbiertos.SetRange(Location_Code, prm_Almacen);
        qMovsAbiertos.Open();
        while qMovsAbiertos.Read() do
            // Los movimientos de un producto que ya no existe no se acumulan.
            if cUM.LeerUMBase(qMovsAbiertos.Item_No, umBase) then
                AcumularFila(rStock, qMovsAbiertos.Item_No, qMovsAbiertos.Variant_Code, qMovsAbiertos.Location_Code,
                             qMovsAbiertos.Lot_No_, umBase, qMovsAbiertos.Remaining_Quantity, 0);
        qMovsAbiertos.Close();
    end;

    /// <summary>
    /// Acumula en el buffer el contenido que SGA tiene ubicado de un producto,
    /// desglosado por variante y lote. Con el producto en blanco, todos los del almacén.
    /// Un producto sin lotes de BC se acumula sin lote: su stock de BC no lo lleva aunque SGA
    /// guarde el del ensamblado, y comparar lote a lote daría una fila "sin ubicar" y otra
    /// "sobra" de la misma mercancía.
    /// </summary>
    procedure AcumularContenidoUbicado(prm_Producto: Code[20]; prm_Almacen: Code[10]; var rStock: Record "Buffer Conciliacion SGA")
    var
        rContenido: Record "Contenido Ubicacion SGA";
        cUM: Codeunit "Unidades Producto SGA";
        conLoteBC: Dictionary of [Code[20], Boolean];
        umBase: Code[10];
        lote: Code[50];
        loteEstandarProducto: Boolean;
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
            if not conLoteBC.Get(rContenido."No. Producto", loteEstandarProducto) then begin
                loteEstandarProducto := LoteEstandar(rContenido."No. Producto");
                conLoteBC.Add(rContenido."No. Producto", loteEstandarProducto);
            end;
            lote := rContenido."No. Lote";
            if not loteEstandarProducto then
                lote := '';
            if cUM.LeerUMBase(rContenido."No. Producto", umBase) then
                AcumularFila(rStock, rContenido."No. Producto", rContenido."Cod. Variante", rContenido."Cod. Almacen",
                             lote, umBase, 0, rContenido."Cantidad Base");
        until rContenido.Next() = 0;
    end;

    /// <summary>
    /// Deja el buffer filtrado por el usuario y, con prm_SoloDiferencias, solo las filas con
    /// diferencia (ya calculada al acumular).
    /// </summary>
    procedure ClasificarYFiltrar(var rStock: Record "Buffer Conciliacion SGA"; prm_SoloDiferencias: Boolean)
    begin
        // Siempre acotado al usuario: el buffer es compartido y dos personas pueden
        // estar conciliando a la vez.
        rStock.Reset();
        rStock.FiltrarUsuarioActual();

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
        TempEntradas: Record "Linea Ubicacion SGA" temporary;
        TempLote: Record "Buffer Conciliacion SGA" temporary;
        cContenido: Codeunit "Gestion Contenido SGA";
        cEntradas: Codeunit "Gestion Entradas SGA";
        enDocumentos: Decimal;
        aRegularizar: Decimal;
        OtroAlmacenErr: Label 'No se puede regularizar en el almacén %1: la ubicación de ajustes (%2) es del almacén por defecto (%3). Esa diferencia se resuelve ubicando la mercancía.', Comment = '%1 = almacén de la línea, %2 = ubicación de ajustes, %3 = almacén por defecto';
        TodoEnDocumentosMsg: Label 'Los %1 sin ubicar de esta línea están pendientes en Ubicar recepciones o Ubicar ensamblados: ubíquelos desde allí.', Comment = '%1 = cantidad';
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
        // La ubicación de ajustes es una ubicación del almacén por defecto.
        if prm_Fila."Cod. Almacen" <> rConfig."Almacen por Defecto" then
            Error(OtroAlmacenErr, prm_Fila."Cod. Almacen", rConfig."Ubic. Ajustes", rConfig."Almacen por Defecto");

        // Lo que espera en Ubicar recepciones o Ubicar ensamblados no se regulariza: esas
        // pantallas lo seguirían pidiendo y, al ubicarlo, sobraría. Solo se lleva a ajustes el resto.
        // La fila es de la tabla real; el cálculo pide una temporal con el lote.
        TempLote := prm_Fila;
        enDocumentos := PendienteEnDocumentosHasta(cEntradas, TempEntradas, prm_Fila."Cod. Almacen", TempLote, prm_Fila.Diferencia);
        aRegularizar := prm_Fila.Diferencia - enDocumentos;
        if aRegularizar <= 0 then begin
            Message(TodoEnDocumentosMsg, prm_Fila.Diferencia);
            exit(false);
        end;

        if not Confirm(ColocarEnAjustesQst, false, aRegularizar, prm_Fila."No. Producto", rConfig."Ubic. Ajustes") then
            exit(false);

        // El stock que BC tiene y SGA no aparece en la ubicación de ajustes hasta que
        // alguien lo coloque físicamente donde le corresponde.
        if cContenido.RegistrarAjuste(prm_Fila."Cod. Almacen", rConfig."Ubic. Ajustes", prm_Fila."No. Producto",
                                      prm_Fila."Cod. Variante", prm_Fila."No. Lote", prm_Fila."Unidad Medida Base",
                                      aRegularizar, RegularizacionConciliacionLbl) = 0
        then
            exit(false);

        prm_Fila."Stock SGA" += aRegularizar;
        prm_Fila.CalcularDiferencia();
        prm_Fila.Modify();

        exit(true);
    end;

    local procedure AcumularFila(var rStock: Record "Buffer Conciliacion SGA"; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Almacen: Code[10]; prm_Lote: Code[50]; prm_UMBase: Code[10]; prm_StockBC: Decimal; prm_StockSGA: Decimal)
    var
        rConfig: Record "Config. SGA";
        usuario: Code[50];
    begin
        usuario := rConfig.UsuarioActual();

        if rStock.Get(usuario, prm_Producto, prm_Variante, prm_Almacen, prm_Lote) then begin
            rStock."Stock BC" := rStock."Stock BC" + prm_StockBC;
            rStock."Stock SGA" := rStock."Stock SGA" + prm_StockSGA;
            rStock.CalcularDiferencia();
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
        rStock.CalcularDiferencia();
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
                        productoCuenta := rItem.IsInventoriableType();
            end;

            if productoCuenta then begin
                prm_Pendiente := TempStock;
                prm_Pendiente.CalcularDiferencia();
                if prm_Pendiente.Diferencia > 0 then begin
                    prm_Pendiente."Fecha Caducidad" := CaducidadLote(producto, TempStock."Cod. Variante", TempStock."No. Lote");

                    cantidadDoc := PendienteEnDocumentosHasta(cEntradas, TempEntradas, prm_Almacen, TempStock, prm_Pendiente.Diferencia);
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
    /// Lo que espera del lote en Ubicar recepciones y Ubicar ensamblados juntos, en unidad base,
    /// sin pasar de prm_Tope.
    /// </summary>
    local procedure PendienteEnDocumentosHasta(var prm_Entradas: Codeunit "Gestion Entradas SGA"; var prm_Buffer: Record "Linea Ubicacion SGA" temporary; prm_Almacen: Code[10]; var prm_Lote: Record "Buffer Conciliacion SGA" temporary; prm_Tope: Decimal) enDocumentos: Decimal
    begin
        // Lo de los documentos nunca cuenta más que lo pendiente: el resto ya es stock de BC.
        enDocumentos := PendienteEnDocumentos(prm_Entradas, prm_Buffer, "Origen Mov. SGA"::Compra, prm_Almacen, prm_Lote) +
                        PendienteEnDocumentos(prm_Entradas, prm_Buffer, "Origen Mov. SGA"::Produccion, prm_Almacen, prm_Lote);
        if enDocumentos > prm_Tope then
            enDocumentos := prm_Tope;
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
        TempLote: Record "Buffer Conciliacion SGA" temporary;
        TempEntradas: Record "Linea Ubicacion SGA" temporary;
        cEntradas: Codeunit "Gestion Entradas SGA";
        loteBC: Code[50];
        pendiente: Decimal;
        enDocumentos: Decimal;
    begin
        prm_StockBase := 0;
        prm_UbicadoBase := 0;

        if prm_Producto = '' then
            exit(0);

        if not rItem.Get(prm_Producto) then
            exit(0);

        // Sin lotes de BC, el stock de BC no lleva lote aunque SGA guarde el del ensamblado: se
        // compara el total del producto, como en la conciliación.
        if LoteEstandar(prm_Producto) then
            loteBC := prm_Lote;

        if prm_Almacen <> '' then
            rItem.SetRange("Location Filter", prm_Almacen);
        if prm_Variante <> '' then
            rItem.SetRange("Variant Filter", prm_Variante);
        if loteBC <> '' then
            rItem.SetRange("Lot No. Filter", loteBC);
        rItem.CalcFields(Inventory);

        prm_StockBase := rItem.Inventory;
        prm_UbicadoBase := TotalUbicadoProducto(prm_Almacen, prm_Producto, prm_Variante, loteBC);
        pendiente := prm_StockBase - prm_UbicadoBase;
        if pendiente <= 0 then
            exit(pendiente);

        // Lo pendiente en Ubicar recepciones y Ubicar ensamblados se ubica desde allí, que lo
        // cuentan por su documento: si se ubicara aquí, lo volverían a pedir. Igual que en
        // "Pendiente de ubicar" (CargarPendienteUbicar).
        TempLote."No. Producto" := prm_Producto;
        TempLote."Cod. Variante" := prm_Variante;
        TempLote."No. Lote" := loteBC;
        enDocumentos := PendienteEnDocumentosHasta(cEntradas, TempEntradas, prm_Almacen, TempLote, pendiente);
        exit(pendiente - enDocumentos);
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
    /// Caducidad de un lote, con el estándar (ExistingExpirationDate de "Item Tracking
    /// Management"): la de su última entrada en el producto y variante. Es la fecha que se
    /// guarda en el contenido y en los movimientos al ubicar, y la que enseña "Pendiente de ubicar".
    /// </summary>
    procedure CaducidadLote(prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]): Date
    var
        TempItemTrackingSetup: Record "Item Tracking Setup" temporary;
        cItemTrackingMgt: Codeunit "Item Tracking Management";
        existenMovs: Boolean;
    begin
        if prm_Lote = '' then
            exit(0D);

        TempItemTrackingSetup."Lot No." := prm_Lote;
        exit(cItemTrackingMgt.ExistingExpirationDate(prm_Producto, prm_Variante, TempItemTrackingSetup, false, existenMovs));
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
