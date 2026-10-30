namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;

/// <summary>
/// Codeunit Consulta Stock SGA (ID 51103).
/// Único sitio que traduce los movimientos de producto de BC a "cuánto stock hay de este
/// producto, en este almacén, de cada lote". Lo usan la carga inicial, la conciliación y la
/// página "Pendiente Ubicar SGA", para que todas midan exactamente lo mismo.
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
        rStock.SetRange("Cod. Usuario", CopyStr(UserId(), 1, MaxStrLen(rStock."Cod. Usuario")));

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
        rStock.SetRange("Cod. Usuario", CopyStr(UserId(), 1, MaxStrLen(rStock."Cod. Usuario")));
        rStock.DeleteAll();
        rStock.Reset();
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
    /// almacén. Deja en prm_Pendiente una línea por cada lote con algo sin ubicar y devuelve
    /// cuántas.
    ///
    /// De lo sin ubicar se separa lo que está pendiente en "Ubicar recepciones" o "Ubicar
    /// ensamblados" (En Documentos): eso se ubica desde esas pantallas, que lo cuentan por su
    /// documento; si se ubicara por otro lado, lo volverían a pedir. Lo que queda (A Ubicar)
    /// no tiene documento que lo reclame: restos de una carga inicial, ajustes, etc.
    ///
    /// Solo recorre los productos con existencias en el almacén (FlowField Inventory), y solo
    /// mira los documentos de los que tienen algo sin ubicar.
    /// </summary>
    procedure CargarPendienteUbicar(prm_Almacen: Code[10]; var prm_Pendiente: Record "Pendiente Ubicar SGA"): Integer
    var
        rItem: Record Item;
        TempStock: Record "Buffer Conciliacion SGA" temporary;
        TempEntradas: Record "Buffer Ubicar Entrada SGA" temporary;
        cEntradas: Codeunit "Gestion Entradas SGA";
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        enDocumentos: Dictionary of [Text, Decimal];
        clave: Text;
        cantidadDoc: Decimal;
        lineas: Integer;
    begin
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
                        if TempStock."Stock BC" > TempStock."Stock SGA" then begin
                            // Los documentos pendientes del producto se miran una vez, al primer lote.
                            if enDocumentos.Count() = 0 then begin
                                AcumularEnDocumentos(cEntradas, TempEntradas, "Origen Mov. SGA"::Compra, prm_Almacen, rItem."No.", enDocumentos);
                                AcumularEnDocumentos(cEntradas, TempEntradas, "Origen Mov. SGA"::Produccion, prm_Almacen, rItem."No.", enDocumentos);
                                enDocumentos.Add('', 0);
                            end;

                            prm_Pendiente.Init();
                            prm_Pendiente."Cod. Almacen" := TempStock."Cod. Almacen";
                            prm_Pendiente."No. Producto" := rItem."No.";
                            prm_Pendiente."Cod. Variante" := TempStock."Cod. Variante";
                            prm_Pendiente."No. Lote" := TempStock."No. Lote";
                            prm_Pendiente.Descripcion := rItem.Description;
                            prm_Pendiente."Unidad Medida Base" := TempStock."Unidad Medida Base";
                            prm_Pendiente."Fecha Caducidad" := CaducidadLote(rItem."No.", TempStock."Cod. Variante", prm_Almacen, TempStock."No. Lote");
                            prm_Pendiente."Stock BC" := TempStock."Stock BC";
                            prm_Pendiente."Stock SGA" := TempStock."Stock SGA";
                            prm_Pendiente.Pendiente := TempStock."Stock BC" - TempStock."Stock SGA";

                            clave := TempStock."Cod. Variante" + '|' + TempStock."No. Lote";
                            cantidadDoc := 0;
                            if enDocumentos.Get(clave, cantidadDoc) then;
                            if cantidadDoc > prm_Pendiente.Pendiente then
                                cantidadDoc := prm_Pendiente.Pendiente;
                            prm_Pendiente."En Documentos" := cantidadDoc;
                            prm_Pendiente."A Ubicar" := prm_Pendiente.Pendiente - cantidadDoc;
                            prm_Pendiente.Desglose := CopyStr(cUbicaciones.DesgloseCantidad(rItem."No.", prm_Pendiente."A Ubicar"), 1, MaxStrLen(prm_Pendiente.Desglose));
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
    /// Caducidad del lote, la de su primer movimiento abierto en el almacén.
    /// </summary>
    local procedure CaducidadLote(prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Almacen: Code[10]; prm_Lote: Code[50]): Date
    var
        rItemLedgEntry: Record "Item Ledger Entry";
    begin
        if prm_Lote = '' then
            exit(0D);
        rItemLedgEntry.SetCurrentKey("Item No.", Open, "Variant Code", Positive, "Location Code", "Posting Date");
        rItemLedgEntry.SetRange("Item No.", prm_Producto);
        rItemLedgEntry.SetRange(Open, true);
        rItemLedgEntry.SetRange("Variant Code", prm_Variante);
        rItemLedgEntry.SetRange("Location Code", prm_Almacen);
        rItemLedgEntry.SetRange("Lot No.", prm_Lote);
        rItemLedgEntry.SetLoadFields("Expiration Date");
        if rItemLedgEntry.FindFirst() then
            exit(rItemLedgEntry."Expiration Date");
        exit(0D);
    end;
}
