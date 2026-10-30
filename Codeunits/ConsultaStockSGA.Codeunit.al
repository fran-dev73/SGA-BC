namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;

/// <summary>
/// Codeunit Consulta Stock SGA (ID 51103).
/// Responde a "cuánto hay en BC y cuánto en SGA". Único sitio que traduce los movimientos de
/// producto de BC a "cuánto stock hay de este producto, en este almacén, de cada lote", sobre
/// la tabla "Buffer Conciliacion SGA". Lo usan la carga inicial, la conciliación y la página
/// "Pendiente Ubicar SGA" (con la tabla en temporal), para que todas midan exactamente lo mismo.
/// También da lo ya ubicado y lo pendiente de un producto, la caducidad de un lote y la
/// consulta de dónde está un producto, y regulariza una fila de la conciliación en la
/// ubicación de ajustes (RegularizarConciliacion).
///
/// El stock por lote se obtiene de la cantidad pendiente de los movimientos abiertos, que
/// es la forma en que BC representa las existencias vivas de cada lote.
/// </summary>
codeunit 51103 "Consulta Stock SGA"
{
    /// <summary>
    /// Acumula en el buffer el stock de BC de un producto en un almacén, desglosado por
    /// variante y lote. No borra el buffer: suma sobre lo que ya haya, de modo que se puede
    /// llamar en bucle para varios productos.
    /// </summary>
    procedure AcumularStockPorLote(prm_Producto: Code[20]; prm_Almacen: Code[10]; var rStock: Record "Buffer Conciliacion SGA")
    var
        rItemLedgEntry: Record "Item Ledger Entry";
        rItem: Record Item;
        umBase: Code[10];
    begin
        if not rItem.Get(prm_Producto) then
            exit;

        umBase := rItem."Base Unit of Measure";

        rItemLedgEntry.SetCurrentKey("Item No.", Open, "Variant Code", Positive, "Location Code", "Posting Date");
        rItemLedgEntry.SetRange("Item No.", prm_Producto);
        rItemLedgEntry.SetRange(Open, true);
        if prm_Almacen <> '' then
            rItemLedgEntry.SetRange("Location Code", prm_Almacen);

        if not rItemLedgEntry.FindSet() then
            exit;

        repeat
            if rItemLedgEntry."Remaining Quantity" <> 0 then
                AcumularFila(rStock, prm_Producto, rItemLedgEntry."Variant Code", rItemLedgEntry."Location Code",
                             rItemLedgEntry."Lot No.", umBase, rItemLedgEntry."Remaining Quantity", 0);
        until rItemLedgEntry.Next() = 0;
    end;

    /// <summary>
    /// Acumula en el buffer el contenido que SGA tiene ubicado de un producto,
    /// desglosado por variante y lote.
    /// </summary>
    procedure AcumularContenidoUbicado(prm_Producto: Code[20]; prm_Almacen: Code[10]; var rStock: Record "Buffer Conciliacion SGA")
    var
        rContenido: Record "Contenido Ubicacion SGA";
        rItem: Record Item;
        umBase: Code[10];
    begin
        if not rItem.Get(prm_Producto) then
            exit;

        umBase := rItem."Base Unit of Measure";

        rContenido.SetCurrentKey("No. Producto", "Cod. Variante", "Cod. Almacen", "No. Lote");
        rContenido.SetRange("No. Producto", prm_Producto);
        if prm_Almacen <> '' then
            rContenido.SetRange("Cod. Almacen", prm_Almacen);

        if not rContenido.FindSet() then
            exit;

        repeat
            AcumularFila(rStock, prm_Producto, rContenido."Cod. Variante", rContenido."Cod. Almacen",
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
    /// Solo recorre los productos con existencias en el almacén (FlowField Inventory), y solo
    /// mira los documentos de los que tienen algo sin ubicar.
    /// </summary>
    procedure CargarPendienteUbicar(prm_Almacen: Code[10]; var prm_Pendiente: Record "Buffer Conciliacion SGA" temporary): Integer
    var
        rItem: Record Item;
        TempStock: Record "Buffer Conciliacion SGA" temporary;
        TempEntradas: Record "Buffer Ubicar Entrada SGA" temporary;
        cEntradas: Codeunit "Gestion Entradas SGA";
        cUM: Codeunit "Unidades Producto SGA";
        enDocumentos: Dictionary of [Text, Decimal];
        clave: Text;
        cantidadDoc: Decimal;
        lineas: Integer;
        PendienteNoTemporalErr: Label 'El pendiente de ubicar solo se calcula sobre una tabla temporal.';
    begin
        if not prm_Pendiente.IsTemporary() then
            Error(PendienteNoTemporalErr);
        prm_Pendiente.Reset();
        prm_Pendiente.DeleteAll();

        rItem.SetRange(Type, rItem.Type::Inventory);
        rItem.SetFilter("Location Filter", prm_Almacen);
        rItem.SetAutoCalcFields(Inventory);
        if not rItem.FindSet() then
            exit(0);

        repeat
            if rItem.Inventory > 0 then begin
                TempStock.Reset();
                TempStock.DeleteAll();
                AcumularStockPorLote(rItem."No.", prm_Almacen, TempStock);
                AcumularContenidoUbicado(rItem."No.", prm_Almacen, TempStock);
                TempStock.SetFilter("Stock BC", '>0');
                if TempStock.FindSet() then begin
                    Clear(enDocumentos);
                    repeat
                        prm_Pendiente := TempStock;
                        prm_Pendiente.ActualizarEstado();
                        if prm_Pendiente.Diferencia > 0 then begin
                            // Los documentos pendientes del producto se miran una vez, al primer lote.
                            if enDocumentos.Count() = 0 then begin
                                AcumularEnDocumentos(cEntradas, TempEntradas, "Origen Mov. SGA"::Compra, prm_Almacen, rItem."No.", enDocumentos);
                                AcumularEnDocumentos(cEntradas, TempEntradas, "Origen Mov. SGA"::Produccion, prm_Almacen, rItem."No.", enDocumentos);
                                enDocumentos.Add('', 0);
                            end;

                            prm_Pendiente."Fecha Caducidad" := CaducidadLote(rItem."No.", TempStock."Cod. Variante", TempStock."No. Lote");

                            clave := TempStock."Cod. Variante" + '|' + TempStock."No. Lote";
                            cantidadDoc := 0;
                            if enDocumentos.Get(clave, cantidadDoc) then;
                            if cantidadDoc > prm_Pendiente.Diferencia then
                                cantidadDoc := prm_Pendiente.Diferencia;
                            prm_Pendiente."En Documentos" := cantidadDoc;
                            prm_Pendiente."A Ubicar" := prm_Pendiente.Diferencia - cantidadDoc;
                            prm_Pendiente.Desglose := CopyStr(cUM.Desglose(rItem."No.", prm_Pendiente."A Ubicar"), 1, MaxStrLen(prm_Pendiente.Desglose));
                            prm_Pendiente.Insert();
                            lineas += 1;
                        end;
                    until TempStock.Next() = 0;
                end;
            end;
        until rItem.Next() = 0;

        exit(lineas);
    end;

    /// <summary>
    /// Suma, por variante y lote y en unidad base, lo que queda por ubicar de un producto en las
    /// pantallas de entradas de ese origen (recepciones o ensamblados), sin límite de fechas.
    /// </summary>
    local procedure AcumularEnDocumentos(var prm_Entradas: Codeunit "Gestion Entradas SGA"; var prm_Buffer: Record "Buffer Ubicar Entrada SGA" temporary; prm_Origen: Enum "Origen Mov. SGA"; prm_Almacen: Code[10]; prm_Producto: Code[20]; var prm_Acumulado: Dictionary of [Text, Decimal])
    var
        cUM: Codeunit "Unidades Producto SGA";
        clave: Text;
        actual: Decimal;
    begin
        prm_Entradas.CargarEntradas(prm_Buffer, prm_Origen, 0D, 0D, prm_Almacen, true, -1, prm_Producto);
        prm_Buffer.Reset();
        if prm_Buffer.FindSet() then
            repeat
                clave := prm_Buffer."Cod. Variante" + '|' + prm_Buffer."No. Lote";
                actual := 0;
                if prm_Acumulado.Get(clave, actual) then;
                prm_Acumulado.Set(clave, actual + prm_Buffer.Pendiente() * cUM.FactorUM(prm_Buffer."No. Producto", prm_Buffer."Cod. Unidad Medida"));
            until prm_Buffer.Next() = 0;
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
}
