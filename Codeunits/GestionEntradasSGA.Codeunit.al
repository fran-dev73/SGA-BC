namespace AntonioNadal.SGA;

using AntonioNadal.Produccion;
using Microsoft.Assembly.Document;
using Microsoft.Assembly.History;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Tracking;
using Microsoft.Purchases.Vendor;
using System.Environment;

/// <summary>
/// Codeunit Gestion Entradas SGA (ID 51105).
/// Lleva lo que entra en el almacén hasta su hueco: reúne lo que ha entrado en una fecha
/// (ensamblados registrados o recepciones de compra), propone dónde dejar cada cosa y registra
/// la entrada cuando el operario confirma.
///
/// No se engancha al registro de BC a propósito: las validaciones de SGA (capacidad, mezcla,
/// bloqueo) lanzan error, y dentro del registro harían fallar el albarán. BC registra como
/// siempre y SGA va detrás, leyendo lo registrado.
///
/// Lo que ya está colocado no se guarda en ninguna marca propia: se deduce del diario de
/// movimientos, que es la verdad del módulo. Así la pantalla se puede cerrar y volver a abrir
/// sin perder el hilo y sin arrastrar un estado paralelo que se desincronice.
///
/// Quien escribe sigue siendo Cod. "Gestion Contenido SGA": aquí solo se decide.
///
/// También es dueño del palé de una tarea de producción ("Imprimir y ubicar palés"): prepara
/// el siguiente palé con su hueco (PrepararPaleTarea), saca su etiqueta (BarTender o, en
/// Sandbox, el report A5), anota la etiqueta en la tarea y lo ubica (ImprimirYUbicarPale).
///
/// Todo palé entra con su SSCC: el leído de su etiqueta o, si no la trae, uno nuevo. Por eso
/// las entradas se ubican de palé en palé.
/// </summary>
codeunit 51105 "Gestion Entradas SGA"
{
    Access = Public;

    /// <summary>
    /// Rellena las líneas con lo que ha entrado por el origen indicado (Producción para los
    /// ensamblados, Compra para las recepciones) entre dos fechas de registro. Cualquiera de las
    /// dos fechas puede ir en blanco: sin fechas se mira todo.
    /// prm_Clase filtra por la "Clase de articulo" de la ficha del producto (su valor de opción);
    /// -1 = todas. prm_Producto deja solo ese producto; en blanco, todos.
    /// prm_Buffer queda sin filtros y ordenado por documento.
    /// </summary>
    procedure CargarEntradas(var prm_Buffer: Record "Linea Ubicacion SGA" temporary; prm_Origen: Enum "Origen Mov. SGA"; prm_FechaDesde: Date; prm_FechaHasta: Date; prm_Almacen: Code[10]; prm_SoloPendientes: Boolean; prm_Clase: Integer; prm_Producto: Code[20])
    begin
        FiltrarLote := false;
        CualquierLote := false;
        Cargar(prm_Buffer, prm_Origen, prm_FechaDesde, prm_FechaHasta, prm_Almacen, prm_SoloPendientes, prm_Clase, prm_Producto);
    end;

    /// <summary>
    /// Lo pendiente de ubicar de un solo lote (producto y lote) por el origen indicado,
    /// sin clase y sin más límite de fechas que el inicio de SGA. Es lo que usa "Pendiente de ubicar" para saber cuánto de un lote
    /// espera en estas pantallas: filtrar por el lote evita repasar toda la historia del producto.
    /// </summary>
    procedure CargarEntradasLote(var prm_Buffer: Record "Linea Ubicacion SGA" temporary; prm_Origen: Enum "Origen Mov. SGA"; prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50])
    begin
        FiltrarLote := true;
        LoteFiltro := prm_Lote;
        // Un producto sin lotes de BC se cuadra por el total (su stock de BC no lleva lote): con
        // el lote en blanco cuentan todos sus lotes propios.
        CualquierLote := (prm_Lote = '') and not cStock.LoteEstandar(prm_Producto);
        Cargar(prm_Buffer, prm_Origen, 0D, 0D, prm_Almacen, true, -1, prm_Producto);
    end;

    /// <summary>
    /// Las entradas anteriores a "Fecha Inicio SGA" no se cargan nunca, se pidan las fechas que
    /// se pidan: lo que trajeron ya es stock de BC y lo coloca la carga inicial.
    /// </summary>
    local procedure Cargar(var prm_Buffer: Record "Linea Ubicacion SGA" temporary; prm_Origen: Enum "Origen Mov. SGA"; prm_FechaDesde: Date; prm_FechaHasta: Date; prm_Almacen: Code[10]; prm_SoloPendientes: Boolean; prm_Clase: Integer; prm_Producto: Code[20])
    var
        OrigenNoUbicableErr: Label 'Solo se pueden ubicar entradas de compra o de producción.';
    begin
        LeerConfig();
        FechaDesde := prm_FechaDesde;
        if FechaDesde < Config."Fecha Inicio SGA" then
            FechaDesde := Config."Fecha Inicio SGA";
        FechaHasta := prm_FechaHasta;
        ClaseFiltro := prm_Clase;
        ProductoFiltro := prm_Producto;

        // Las filas que había se descartan: sus huecos dejan de estar reservados.
        LiberarReservasFilas(prm_Buffer);
        prm_Buffer.Reset();
        prm_Buffer.DeleteAll();
        // El orden de la pantalla, por documento. Se fija aquí porque el Reset quita el que
        // traiga la página.
        prm_Buffer.SetCurrentKey(Origen, "No. Documento", "No. Producto", "No. Lote", "Cod. Unidad Medida");

        // Hasta una fecha anterior al inicio de SGA no hay nada que ubicar.
        if (FechaHasta <> 0D) and (FechaHasta < FechaDesde) then
            exit;

        case prm_Origen of
            prm_Origen::Produccion:
                CargarEnsamblados(prm_Buffer, prm_Almacen, prm_SoloPendientes);
            prm_Origen::Compra:
                CargarRecepciones(prm_Buffer, prm_Almacen, prm_SoloPendientes);
            else
                Error(OrigenNoUbicableErr);
        end;
    end;

    /// <summary>
    /// Si la entrada del producto se enseña: SGA lo ubica (Consulta Stock SGA.ProductoSGA) y es
    /// de la clase pedida en pantalla (o no se filtra por clase). prm_Item trae leídos el tipo,
    /// "Producto Tianna", la categoría y la clase.
    /// </summary>
    local procedure ProductoAdmitido(var prm_Item: Record Item): Boolean
    begin
        if not cStock.ProductoSGA(prm_Item) then
            exit(false);
        if ClaseFiltro < 0 then
            exit(true);

        exit(prm_Item."Clase de articulo" = ClaseFiltro);
    end;

    /// <summary>
    /// Ensamblados de tipo Embotellado registrados en una fecha. Una fila por ensamblado y lote
    /// (los da LotesEnsamblado). Las elaboraciones quedan fuera: su salida es granel a depósito,
    /// no va a hueco.
    /// </summary>
    local procedure CargarEnsamblados(var prm_Buffer: Record "Linea Ubicacion SGA" temporary; prm_Almacen: Code[10]; prm_SoloPendientes: Boolean)
    var
        rCabEns: Record "Posted Assembly Header";
        rItem: Record Item;
        lotes: Dictionary of [Code[50], Decimal];
        lote: Code[50];
        filtroEnsamblados: Text;
        qtyPorUM: Decimal;
        almacenFila: Code[10];
        almacenDefecto: Code[10];
        cargadas: Integer;
    begin
        // El ensamblado puede no llevar almacén; en ese caso manda el filtro de la pantalla y,
        // si tampoco lo hay, el almacén por defecto de la configuración.
        LeerConfig();
        almacenDefecto := prm_Almacen;
        if almacenDefecto = '' then
            almacenDefecto := Config."Almacen por Defecto";

        // Con las dos fechas en blanco no filtra.
        if FechaHasta = 0D then
            rCabEns.SetFilter("Posting Date", '%1..', FechaDesde)
        else
            rCabEns.SetRange("Posting Date", FechaDesde, FechaHasta);
        // Un ensamblado deshecho no sacó nada: sin lotes de BC su cantidad sale de la cabecera,
        // que no se pone a cero al deshacerlo.
        rCabEns.SetRange(Reversed, false);
        rItem.SetLoadFields(Type, "Producto Tianna", "Item Category Code", "Clase de articulo");
        // Solo embotellados: las elaboraciones sacan granel a depósito, que no va a hueco.
        rCabEns.SetRange("Tipo documento", rCabEns."Tipo documento"::Embotellado);
        if ProductoFiltro <> '' then
            rCabEns.SetRange("Item No.", ProductoFiltro);
        if FiltrarLote then
            if cStock.LoteEstandar(ProductoFiltro) then begin
                // El lote estándar no está en la cabecera: se buscan los ensamblados que lo sacaron.
                filtroEnsamblados := EnsambladosDelLote();
                if filtroEnsamblados = '' then
                    exit;
                rCabEns.SetFilter("No.", filtroEnsamblados);
            end else
                if not CualquierLote then begin
                    // Un lote más largo que el del ensamblado no puede ser de ningún ensamblado.
                    if StrLen(LoteFiltro) > MaxStrLen(rCabEns.Lote) then
                        exit;
                    rCabEns.SetRange(Lote, LoteFiltro);
                end;
        // El almacén no se filtra en la consulta: está oculto en el pedido de ensamblado
        // (Pag-Ext50105), así que casi todos se registran en blanco y filtrar por él dejaba la
        // lista siempre vacía. Se compara más abajo, ya con el almacén de la fila resuelto.
        rCabEns.SetLoadFields("No.", "Item No.", Quantity, "Quantity (Base)", "Location Code", "Posting Date",
                              "Unit of Measure Code", "Order No.", "Qty. per Unit of Measure", Lote);
        if not rCabEns.FindSet() then
            exit;

        repeat
            // La ficha se relee solo si cambia el producto.
            if rItem."No." <> rCabEns."Item No." then
                if not rItem.Get(rCabEns."Item No.") then
                    Clear(rItem);
            if (rItem."No." <> '') and (rCabEns.Quantity > 0) and ProductoAdmitido(rItem) then begin
                almacenFila := rCabEns."Location Code";
                if almacenFila = '' then
                    almacenFila := almacenDefecto;

                // Si la pantalla pide un almacén concreto, el ensamblado registrado en otro no
                // es de esta lista; los que vienen en blanco ya han heredado el del filtro.
                if (prm_Almacen = '') or (almacenFila = prm_Almacen) then begin
                    prm_Buffer.Init();
                    prm_Buffer.Origen := prm_Buffer.Origen::Produccion;
                    prm_Buffer."No. Documento" := rCabEns."No.";
                    prm_Buffer."Fecha Registro" := rCabEns."Posting Date";
                    prm_Buffer."Cod. Almacen" := almacenFila;
                    prm_Buffer."No. Producto" := rCabEns."Item No.";
                    prm_Buffer."Cod. Unidad Medida" := rCabEns."Unit of Measure Code";
                    prm_Buffer."Documento Relacionado" := rCabEns."Order No.";
                    qtyPorUM := rCabEns."Qty. per Unit of Measure";
                    if qtyPorUM <= 0 then
                        qtyPorUM := 1;

                    // Cada ensamblado es un documento distinto: no hay dos filas con el mismo
                    // documento y lote. Un lote deshecho del todo suma cero y no sale.
                    LotesEnsamblado(rCabEns."Item No.", rCabEns.Lote, '', rCabEns."No.", rCabEns."Quantity (Base)", lotes);
                    foreach lote in lotes.Keys() do
                        if ((not FiltrarLote) or CualquierLote or (lote = LoteFiltro)) and (lotes.Get(lote) > 0) then begin
                            prm_Buffer."No. Lote" := lote;
                            prm_Buffer."Cantidad Entrada" := cUOMMgt.CalcQtyFromBase(lotes.Get(lote), qtyPorUM);
                            CalcularPendiente(prm_Buffer);
                            if (not prm_SoloPendientes) or (prm_Buffer.Estado <> prm_Buffer.Estado::Ubicado) then begin
                                cargadas += 1;
                                prm_Buffer.Linea := cargadas;
                                prm_Buffer.Insert();
                            end;
                        end;
                end;
            end;
        until rCabEns.Next() = 0;
    end;

    /// <summary>
    /// Lotes que saca un ensamblado, con su cantidad en unidad base. Es el único sitio que decide
    /// de dónde sale el lote de un ensamblado, y lo decide el producto (LoteEstandar), no si un
    /// campo está relleno:
    /// - Con lotes estándar, del seguimiento de BC: de los movimientos de producto si está
    ///   registrado (prm_NoRegistrado), del seguimiento del pedido si no. Puede haber varios, o
    ///   ninguno si aún no se ha puesto.
    /// - Sin ellos, toda la cantidad con el lote propio de la cabecera (prm_LotePropio).
    /// </summary>
    local procedure LotesEnsamblado(prm_Producto: Code[20]; prm_LotePropio: Code[50]; prm_NoPedido: Code[20]; prm_NoRegistrado: Code[20]; prm_CantidadBase: Decimal; var prm_Lotes: Dictionary of [Code[50], Decimal])
    var
        rItemLedgEntry: Record "Item Ledger Entry";
        rSeguimiento: Record "Reservation Entry";
    begin
        Clear(prm_Lotes);
        if not cStock.LoteEstandar(prm_Producto) then begin
            prm_Lotes.Add(prm_LotePropio, prm_CantidadBase);
            exit;
        end;

        if prm_NoRegistrado <> '' then begin
            // Deshacer el registro deja movimientos de signo contrario en el mismo documento.
            rItemLedgEntry.SetRange("Document No.", prm_NoRegistrado);
            rItemLedgEntry.SetRange("Entry Type", rItemLedgEntry."Entry Type"::"Assembly Output");
            rItemLedgEntry.SetRange("Item No.", prm_Producto);
            rItemLedgEntry.SetLoadFields("Lot No.", Quantity);
            if rItemLedgEntry.FindSet() then
                repeat
                    SumarLote(prm_Lotes, rItemLedgEntry."Lot No.", rItemLedgEntry.Quantity);
                until rItemLedgEntry.Next() = 0;
            exit;
        end;

        rSeguimiento.SetSourceFilter(Database::"Assembly Header", "Assembly Document Type"::Order.AsInteger(), prm_NoPedido, 0, true);
        rSeguimiento.SetSourceFilter('', 0);
        rSeguimiento.SetFilter("Lot No.", '<>%1', '');
        rSeguimiento.SetLoadFields("Lot No.", "Quantity (Base)");
        if rSeguimiento.FindSet() then
            repeat
                SumarLote(prm_Lotes, rSeguimiento."Lot No.", rSeguimiento."Quantity (Base)");
            until rSeguimiento.Next() = 0;
    end;

    local procedure SumarLote(var prm_Lotes: Dictionary of [Code[50], Decimal]; prm_Lote: Code[50]; prm_Cantidad: Decimal)
    var
        acumulado: Decimal;
    begin
        // Set añade la clave si aún no está.
        if not prm_Lotes.Get(prm_Lote, acumulado) then
            acumulado := 0;
        prm_Lotes.Set(prm_Lote, acumulado + prm_Cantidad);
    end;

    /// <summary>
    /// Filtro con los ensamblados registrados que sacaron el lote de CargarEntradasLote, leídos
    /// de sus movimientos de producto. En blanco si no hay ninguno.
    /// </summary>
    local procedure EnsambladosDelLote(): Text
    var
        rItemLedgEntry: Record "Item Ledger Entry";
        documentos: List of [Code[20]];
        filtro: Text;
    begin
        rItemLedgEntry.SetRange("Item No.", ProductoFiltro);
        rItemLedgEntry.SetRange("Entry Type", rItemLedgEntry."Entry Type"::"Assembly Output");
        rItemLedgEntry.SetRange("Lot No.", LoteFiltro);
        rItemLedgEntry.SetLoadFields("Document No.");
        if rItemLedgEntry.FindSet() then
            repeat
                if not documentos.Contains(rItemLedgEntry."Document No.") then begin
                    documentos.Add(rItemLedgEntry."Document No.");
                    if filtro <> '' then
                        filtro += '|';
                    filtro += rItemLedgEntry."Document No.";
                end;
            until rItemLedgEntry.Next() = 0;

        exit(filtro);
    end;

    /// <summary>
    /// Recepciones de compra registradas en una fecha. Una fila por albarán, producto, lote y
    /// unidad de medida.
    ///
    /// Se leen los movimientos de producto y no las líneas del albarán porque el lote y la
    /// caducidad solo están en el movimiento: la línea no los lleva. Además, deshacer una
    /// recepción genera un movimiento negativo en el mismo albarán, y al sumar por documento
    /// lo deshecho se descuenta solo.
    /// </summary>
    local procedure CargarRecepciones(var prm_Buffer: Record "Linea Ubicacion SGA" temporary; prm_Almacen: Code[10]; prm_SoloPendientes: Boolean)
    var
        rItemLedgEntry: Record "Item Ledger Entry";
        rItem: Record Item;
        rVendor: Record Vendor;
        TempFila: Record "Linea Ubicacion SGA" temporary;
        um: Code[10];
        factor: Decimal;
        siguienteLinea: Integer;
    begin
        rItemLedgEntry.SetRange("Entry Type", rItemLedgEntry."Entry Type"::Purchase);
        rItemLedgEntry.SetRange("Document Type", rItemLedgEntry."Document Type"::"Purchase Receipt");
        if FechaHasta = 0D then
            rItemLedgEntry.SetFilter("Posting Date", '%1..', FechaDesde)
        else
            rItemLedgEntry.SetRange("Posting Date", FechaDesde, FechaHasta);
        rItem.SetLoadFields(Type, "Producto Tianna", "Item Category Code", "Clase de articulo", "Base Unit of Measure");
        // Sin fecha de inicio se mirarían todas las compras de la historia. Se acota a las
        // recepciones que aún tienen stock (movimiento abierto): lo ya consumido o deshecho no
        // tiene nada que colocar en un hueco.
        if FechaDesde = 0D then
            rItemLedgEntry.SetRange(Open, true);
        if prm_Almacen <> '' then
            rItemLedgEntry.SetRange("Location Code", prm_Almacen);
        if ProductoFiltro <> '' then
            rItemLedgEntry.SetRange("Item No.", ProductoFiltro);
        if FiltrarLote then
            rItemLedgEntry.SetRange("Lot No.", LoteFiltro);
        rItemLedgEntry.SetLoadFields("Item No.", "Unit of Measure Code", "Qty. per Unit of Measure", "Document No.", "Lot No.",
                                     Quantity, "Posting Date", "Location Code", "Source Type", "Source No.");
        if not rItemLedgEntry.FindSet() then
            exit;

        // Primera pasada: acumular por fila (documento, producto, lote y UM). Se busca
        // en una copia para no dejar filtros en prm_Buffer, que es la lista de la página. Las
        // cantidades se llevan a la UM del albarán, que es en la que se ha recibido y en la que
        // se deja en el hueco. Cada producto y cada proveedor se leen una vez: un albarán trae
        // muchos movimientos del mismo.
        TempFila.Copy(prm_Buffer, true);
        TempFila.SetCurrentKey(Origen, "No. Documento", "No. Producto", "No. Lote", "Cod. Unidad Medida");
        rVendor.SetLoadFields(Name);
        repeat
            if rItem."No." <> rItemLedgEntry."Item No." then
                if not rItem.Get(rItemLedgEntry."Item No.") then
                    Clear(rItem);
            if (rItem."No." <> '') and ProductoAdmitido(rItem) then begin
                um := rItemLedgEntry."Unit of Measure Code";
                if um = '' then
                    um := rItem."Base Unit of Measure";
                factor := rItemLedgEntry."Qty. per Unit of Measure";
                if factor <= 0 then
                    factor := 1;

                TempFila.SetRange("No. Documento", rItemLedgEntry."Document No.");
                TempFila.SetRange("No. Producto", rItemLedgEntry."Item No.");
                TempFila.SetRange("No. Lote", rItemLedgEntry."Lot No.");
                TempFila.SetRange("Cod. Unidad Medida", um);
                if TempFila.FindFirst() then begin
                    TempFila."Cantidad Entrada" += cUOMMgt.CalcQtyFromBase(rItemLedgEntry.Quantity, factor);
                    TempFila.Modify();
                end else begin
                    TempFila.Init();
                    siguienteLinea += 1;
                    TempFila.Linea := siguienteLinea;
                    TempFila.Origen := TempFila.Origen::Compra;
                    TempFila."No. Documento" := rItemLedgEntry."Document No.";
                    TempFila."Fecha Registro" := rItemLedgEntry."Posting Date";
                    TempFila."Cod. Almacen" := rItemLedgEntry."Location Code";
                    TempFila."No. Producto" := rItemLedgEntry."Item No.";
                    TempFila."No. Lote" := rItemLedgEntry."Lot No.";
                    TempFila."Cod. Unidad Medida" := um;
                    TempFila."Cantidad Entrada" := cUOMMgt.CalcQtyFromBase(rItemLedgEntry.Quantity, factor);
                    if rItemLedgEntry."Source Type" = rItemLedgEntry."Source Type"::Vendor then begin
                        if rVendor."No." <> rItemLedgEntry."Source No." then
                            if not rVendor.Get(rItemLedgEntry."Source No.") then
                                Clear(rVendor);
                        if rVendor."No." <> '' then
                            TempFila."Descripcion Origen" := CopyStr(rVendor.Name, 1, MaxStrLen(TempFila."Descripcion Origen"));
                    end;
                    TempFila.Insert();
                end;
            end;
        until rItemLedgEntry.Next() = 0;

        // Segunda pasada: con la cantidad neta ya sumada, ver cuánto falta y quitar lo que no
        // se tiene que enseñar (recepciones deshechas del todo, o ya ubicadas si se pide).
        TempFila.Reset();
        if TempFila.FindSet() then
            repeat
                if TempFila."Cantidad Entrada" <= 0 then
                    TempFila.Delete()
                else begin
                    CalcularPendiente(TempFila);
                    if prm_SoloPendientes and (TempFila.Estado = TempFila.Estado::Ubicado) then
                        TempFila.Delete()
                    else
                        TempFila.Modify();
                end;
            until TempFila.Next() = 0;
    end;

    /// <summary>
    /// Propone hueco para todas las filas que aún no lo tienen. Va reservando lo que asigna,
    /// para no mandar dos entradas distintas al mismo hueco vacío.
    /// </summary>
    procedure ProponerParaTodos(var prm_Buffer: Record "Linea Ubicacion SGA" temporary): Integer
    var
        TempFila: Record "Linea Ubicacion SGA" temporary;
        asignadas: Text;
        motivo: Text;
        codigo: Code[20];
        propuestas: Integer;
    begin
        TempFila.Copy(prm_Buffer, true);
        TempFila.Reset();
        // Se recorre por la clave Documento a propósito: dentro del bucle se modifica
        // "Ubicacion Propuesta", y si el orden viniera de esa columna (porque el operario
        // haya ordenado por ella) el recorrido se saltaría filas o las repetiría.
        TempFila.SetCurrentKey(Origen, "No. Documento", "No. Producto", "No. Lote", "Cod. Unidad Medida");
        if not TempFila.FindSet() then
            exit(0);

        // Sin hueco la fila sigue Pendiente, con el motivo: en las entradas no se usa "Sin Sitio".
        repeat
            if (TempFila.Estado <> TempFila.Estado::Ubicado) and (TempFila."Ubicacion Propuesta" = '') then begin
                codigo := ProponerParaFila(TempFila, asignadas, motivo);
                TempFila."Ubicacion Propuesta" := codigo;
                TempFila.Motivo := CopyStr(motivo, 1, MaxStrLen(TempFila.Motivo));
                TempFila."Ubicacion Confirmada" := codigo;
                TempFila.Modify();

                if codigo <> '' then begin
                    asignadas := cUbicaciones.AnadirExclusion(asignadas, codigo);
                    propuestas += 1;
                end;
            end else
                asignadas := cUbicaciones.AnadirExclusion(asignadas, TempFila."Ubicacion Propuesta");
        until TempFila.Next() = 0;

        exit(propuestas);
    end;

    /// <summary>
    /// ProponerParaTodos desde la pantalla de ubicar entradas, diciendo cuántas ubicaciones se
    /// han propuesto, que no había nada que proponer o que no ha encontrado sitio (el motivo de
    /// cada fila queda en su línea).
    /// </summary>
    procedure ProponerParaTodosConMensaje(var prm_Buffer: Record "Linea Ubicacion SGA" temporary)
    var
        TempFila: Record "Linea Ubicacion SGA" temporary;
        propuestas: Integer;
        UbicacionesPropuestasMsg: Label 'Se han propuesto %1 ubicaciones.', Comment = '%1 = número de propuestas';
        NingunaPropuestaMsg: Label 'No se ha podido proponer ninguna ubicación: la columna "Por qué ahí" de cada línea dice el motivo.';
        NadaQueProponerMsg: Label 'No hay líneas pendientes sin ubicación propuesta.';
    begin
        TempFila.Copy(prm_Buffer, true);
        TempFila.Reset();
        TempFila.SetFilter(Estado, '<>%1', TempFila.Estado::Ubicado);
        TempFila.SetRange("Ubicacion Propuesta", '');
        if TempFila.IsEmpty() then begin
            Message(NadaQueProponerMsg);
            exit;
        end;

        propuestas := ProponerParaTodos(prm_Buffer);
        if propuestas = 0 then
            Message(NingunaPropuestaMsg)
        else
            Message(UbicacionesPropuestasMsg, propuestas);
    end;

    /// <summary>
    /// Busca una alternativa para una fila, descartando la que ya se le había ofrecido y las
    /// que están reservadas por las demás filas.
    /// </summary>
    procedure ProponerOtra(var prm_Fila: Record "Linea Ubicacion SGA" temporary)
    var
        excluidas: Text;
        motivo: Text;
        codigo: Code[20];
        SinOtraUbicacionMsg: Label 'No hay otra ubicación disponible para %1. Se mantiene la propuesta anterior.', Comment = '%1 = producto';
    begin
        TestFilaSinUbicar(prm_Fila);
        excluidas := ExclusionesDeOtrasFilas(prm_Fila);
        excluidas := cUbicaciones.AnadirExclusion(excluidas, prm_Fila."Ubicacion Propuesta");

        codigo := ProponerParaFila(prm_Fila, excluidas, motivo);

        if codigo = '' then begin
            Message(SinOtraUbicacionMsg, prm_Fila."No. Producto");
            exit;
        end;

        prm_Fila."Ubicacion Propuesta" := codigo;
        prm_Fila.Motivo := CopyStr(motivo, 1, MaxStrLen(prm_Fila.Motivo));
        prm_Fila."Ubicacion Confirmada" := codigo;
        prm_Fila.Modify();
    end;

    /// <summary>
    /// Registra las líneas de un reparto de "Ubicar producto" (ProponerReparto de Cod. "Gestion
    /// Ubicaciones SGA"): todas las que tengan ubicación confirmada y no estén ya ubicadas
    /// (prm_Linea = 0), o solo esa línea. Primero comprueba todas (TestFilaParaUbicar) y luego
    /// registra, para no dejar el reparto a medias por un error en una línea. Cada línea entra
    /// con el SSCC leído de su palé o, si no se ha leído, con uno nuevo. Devuelve lo que queda
    /// sin ubicar del reparto, en unidad base.
    /// </summary>
    procedure ConfirmarReparto(var TempLinea: Record "Linea Ubicacion SGA" temporary; prm_Linea: Integer): Decimal
    var
        cContenido: Codeunit "Gestion Contenido SGA";
        lineas: List of [Integer];
        ssccs: List of [Code[20]];
        n: Integer;
        i: Integer;
        restoBase: Decimal;
        SinLineasConfirmarErr: Label 'No hay ninguna línea con ubicación que confirmar.';
        UbicadoGuiadoLbl: Label 'Ubicado desde la pantalla de ubicación guiada.';
    begin
        TempLinea.Reset();
        if prm_Linea <> 0 then
            TempLinea.SetRange(Linea, prm_Linea);
        TempLinea.SetFilter(Estado, '<>%1', TempLinea.Estado::Ubicado);
        if TempLinea.FindSet() then
            repeat
                // Confirmando todo, lo que no tiene sitio se salta; una línea sola, no.
                if (TempLinea."Ubicacion Confirmada" <> '') or (prm_Linea <> 0) then begin
                    TestFilaParaUbicar(TempLinea);
                    lineas.Add(TempLinea.Linea);
                end;
            until TempLinea.Next() = 0;

        if lineas.Count() = 0 then
            Error(SinLineasConfirmarErr);

        // Primero se registran todas y después se marcan: la tabla de la pantalla es temporal y
        // no se deshace con un error, así que si una falla no debe quedar ninguna como ubicada.
        // El palé sin etiqueta recibe un SSCC nuevo (SSCCPale lo deja en la variable, no en la
        // tabla), que se guarda al marcarla.
        TempLinea.Reset();
        foreach n in lineas do begin
            TempLinea.Get(n);
            ssccs.Add(TempLinea.SSCCPale());
            cContenido.RegistrarEntrada(TempLinea."Cod. Almacen", TempLinea."Ubicacion Confirmada", TempLinea."No. Producto", TempLinea."No. Lote",
                                        ssccs.Get(ssccs.Count()), TempLinea."Cod. Unidad Medida", TempLinea.Cantidad, "Origen Mov. SGA"::Manual, '', UbicadoGuiadoLbl);
        end;
        for i := 1 to lineas.Count() do begin
            TempLinea.Get(lineas.Get(i));
            TempLinea.SSCC := ssccs.Get(i);
            TempLinea.Estado := TempLinea.Estado::Ubicado;
            TempLinea.Motivo := '';
            TempLinea.Modify();
        end;

        TempLinea.SetFilter(Estado, '<>%1', TempLinea.Estado::Ubicado);
        TempLinea.CalcSums("Cantidad Base");
        restoBase := TempLinea."Cantidad Base";
        TempLinea.Reset();
        exit(restoBase);
    end;

    /// <summary>
    /// Registra la entrada de una fila en la ubicación confirmada, con el SSCC leído de su palé o,
    /// si no se ha leído (palé sin etiqueta), con uno nuevo. Si a la fila aún le queda, se queda
    /// sin SSCC ni hueco, con el siguiente palé como cantidad, para proponerle otro.
    /// </summary>
    procedure ConfirmarFila(var prm_Fila: Record "Linea Ubicacion SGA" temporary)
    var
        rMovimiento: Record "Movimiento Ubicacion SGA";
        cContenido: Codeunit "Gestion Contenido SGA";
        descripcion: Text;
        CantidadExcedePendienteErr: Label 'Solo quedan %1 por ubicar de %2.', Comment = '%1 = pendiente, %2 = producto';
        EnsambladoLbl: Label 'Ensamblado %1', Comment = '%1 = nº ensamblado';
        RecepcionLbl: Label 'Recepción %1', Comment = '%1 = nº albarán de compra';
    begin
        TestFilaSinUbicar(prm_Fila);
        TestFilaParaUbicar(prm_Fila);

        // Lo ya ubicado se vuelve a leer del diario, bloqueándolo: la lista puede llevar rato
        // abierta, u otra persona haber ubicado la misma entrada, y no se ubica dos veces.
        rMovimiento.LockTable();
        prm_Fila."Cantidad Ya Ubicada" := YaUbicadaFila(prm_Fila);
        if prm_Fila.Cantidad > prm_Fila.Pendiente() then
            Error(CantidadExcedePendienteErr, prm_Fila.Pendiente(), prm_Fila."No. Producto");

        if prm_Fila.Origen = prm_Fila.Origen::Compra then
            descripcion := StrSubstNo(RecepcionLbl, prm_Fila."No. Documento")
        else
            descripcion := StrSubstNo(EnsambladoLbl, prm_Fila."No. Documento");

        // Puede entrar en el hueco reservado para la fila; ya ocupado, la reserva sobra.
        cContenido.FijarReserva(prm_Fila.ReservaFila());
        cContenido.RegistrarEntrada(prm_Fila."Cod. Almacen", prm_Fila."Ubicacion Confirmada",
                                    prm_Fila."No. Producto", prm_Fila."No. Lote",
                                    prm_Fila.SSCCPale(), prm_Fila."Cod. Unidad Medida", prm_Fila.Cantidad,
                                    prm_Fila.Origen, prm_Fila."No. Documento", descripcion);
        cUbicaciones.LiberarReservas(prm_Fila.ReservaFila(), '');

        CalcularPendiente(prm_Fila);
        if prm_Fila.Estado = prm_Fila.Estado::Pendiente then begin
            prm_Fila.SSCC := '';
            prm_Fila."Ubicacion Propuesta" := '';
            prm_Fila."Ubicacion Confirmada" := '';
            prm_Fila.Motivo := '';
        end;
        prm_Fila.Modify();
    end;

    /// <summary>
    /// Error si la fila ya está ubicada: no hay nada que proponer ni que confirmar.
    /// </summary>
    local procedure TestFilaSinUbicar(var prm_Fila: Record "Linea Ubicacion SGA" temporary)
    var
        LineaYaUbicadaErr: Label 'La línea de %1 ya está ubicada.', Comment = '%1 = producto';
    begin
        if prm_Fila.Estado = prm_Fila.Estado::Ubicado then
            Error(LineaYaUbicadaErr, prm_Fila."No. Producto");
    end;

    /// <summary>
    /// Lo que se comprueba de una fila antes de ubicarla y que no depende de lo ya ubicado:
    /// ubicación indicada, cantidad positiva, desvío permitido por la configuración y no más de
    /// un palé por vez (cada palé entra con su SSCC). En "Ubicar producto" (Origen Manual), con
    /// "Exigir confirmar ubicación", la etiqueta del hueco tiene que estar leída y ser la de la
    /// ubicación en la que se deja. Imprimir y ubicar lo comprueba antes de sacar la etiqueta.
    /// </summary>
    local procedure TestFilaParaUbicar(var prm_Fila: Record "Linea Ubicacion SGA" temporary)
    var
        paleEnUMFila: Decimal;
        UbicacionNoIndicadaErr: Label 'Indique la ubicación en la que ha dejado %1.', Comment = '%1 = producto';
        CantidadNoPositivaErr: Label 'La cantidad a ubicar de %1 debe ser mayor que cero.', Comment = '%1 = producto';
        DesvioNoPermitidoErr: Label 'La configuración no permite dejar %1 en una ubicación distinta de la propuesta (%2).', Comment = '%1 = producto, %2 = ubicación propuesta';
        MasDeUnPaleErr: Label 'Se ubica de palé en palé, cada uno con su SSCC: como mucho %1 %2 de %3 cada vez.', Comment = '%1 = cantidad de un palé, %2 = unidad, %3 = producto';
        SinLecturaErr: Label 'Escanee la etiqueta de la ubicación en la que deja %1: la configuración exige confirmar la ubicación.', Comment = '%1 = producto';
        LecturaDistintaErr: Label 'Se ha leído la ubicación %1, pero %3 se deja en %2. Lleve la mercancía a %2 y escanee su etiqueta, o cambie la ubicación.', Comment = '%1 = ubicación leída, %2 = ubicación de la línea, %3 = producto';
    begin
        if prm_Fila."Ubicacion Confirmada" = '' then
            Error(UbicacionNoIndicadaErr, prm_Fila."No. Producto");

        if prm_Fila.Cantidad <= 0 then
            Error(CantidadNoPositivaErr, prm_Fila."No. Producto");

        LeerConfig();
        if (prm_Fila.Origen = prm_Fila.Origen::Manual) and Config."Exigir Confirmar Ubicacion" then begin
            if prm_Fila."Ubicacion Leida" = '' then
                Error(SinLecturaErr, prm_Fila."No. Producto");
            if prm_Fila."Ubicacion Leida" <> prm_Fila."Ubicacion Confirmada" then
                Error(LecturaDistintaErr, prm_Fila."Ubicacion Leida", prm_Fila."Ubicacion Confirmada", prm_Fila."No. Producto");
        end;

        if prm_Fila."Ubicacion Propuesta" <> '' then
            if not Config.DesvioPermitido(prm_Fila."Ubicacion Propuesta", prm_Fila."Ubicacion Confirmada") then
                Error(DesvioNoPermitidoErr, prm_Fila."No. Producto", prm_Fila."Ubicacion Propuesta");

        // Cada palé entra con su SSCC: no más de un palé por vez.
        if UnPaleEnUMFila(prm_Fila, paleEnUMFila) then
            if prm_Fila.Cantidad > paleEnUMFila then
                Error(MasDeUnPaleErr, paleEnUMFila, prm_Fila."Cod. Unidad Medida", prm_Fila."No. Producto");
    end;

    /// <summary>
    /// Registra todas las filas pendientes que ya tengan ubicación confirmada.
    /// Devuelve cuántas se han ubicado.
    /// </summary>
    procedure ConfirmarTodas(var prm_Buffer: Record "Linea Ubicacion SGA" temporary): Integer
    var
        TempPantalla: Record "Linea Ubicacion SGA" temporary;
        TempTrabajo: Record "Linea Ubicacion SGA" temporary;
        hechas: Integer;
    begin
        // Se trabaja sobre una copia aparte y se pasa a la pantalla al final: la tabla de la
        // pantalla es temporal y no se deshace con un error, así que si una fila falla no debe
        // quedar ninguna como ubicada sin estarlo.
        TempPantalla.Copy(prm_Buffer, true);
        TempPantalla.Reset();
        if not TempPantalla.FindSet() then
            exit(0);
        repeat
            TempTrabajo := TempPantalla;
            TempTrabajo.Insert();
        until TempPantalla.Next() = 0;

        // Por la clave Documento, que no cambia dentro del bucle (cambia Estado).
        TempTrabajo.SetCurrentKey(Origen, "No. Documento", "No. Producto", "No. Lote", "Cod. Unidad Medida");
        TempTrabajo.FindSet();
        repeat
            if (TempTrabajo.Estado <> TempTrabajo.Estado::Ubicado) and (TempTrabajo."Ubicacion Confirmada" <> '') and (TempTrabajo.Cantidad > 0) then begin
                ConfirmarFila(TempTrabajo);
                hechas += 1;
            end;
        until TempTrabajo.Next() = 0;

        TempTrabajo.Reset();
        TempTrabajo.FindSet();
        repeat
            TempPantalla := TempTrabajo;
            TempPantalla.Modify();
        until TempTrabajo.Next() = 0;

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
    /// El palé completo se ubica en la unidad de palé. El incompleto se ubica entero, en cajas (la
    /// unidad de venta) si son cajas exactas y si no en unidades sueltas.
    ///
    /// Sin hueco libre, la ubicación queda en blanco y prm_Aviso dice por qué no lo hay.
    ///
    /// Devuelve false, con el porqué en prm_Aviso, si no hay palé que ubicar (también si la tarea
    /// es anterior a "Fecha Inicio SGA": lo que sacó ya es stock de BC y lo coloca la carga
    /// inicial). Con true, en prm_Aviso puede venir un aviso que no impide ubicar.
    /// </summary>
    procedure PrepararPaleTarea(prm_Tarea: Record "Tareas Produccion"; var prm_Fila: Record "Linea Ubicacion SGA" temporary; var prm_Aviso: Text): Boolean
    var
        rCabEns: Record "Assembly Header";
        rCabEnsReg: Record "Posted Assembly Header";
        TempTrozo: Record "Linea Ubicacion SGA" temporary;
        factorPale: Decimal;
        restantePlanBase: Decimal;
        paleBase: Decimal;
        umDestino: Code[10];
        cantidadDestino: Decimal;
        lotes: Dictionary of [Code[50], Decimal];
        lote: Code[50];
        LoteDesconocidoLbl: Label 'No se sabe el lote del palé: el ensamblado %1 no tiene lote en sus líneas de seguimiento, o tiene varios y ninguno es el de la tarea (%2).', Comment = '%1 = nº ensamblado, %2 = lote de la tarea';
        TareaSinEnsambladoLbl: Label 'La tarea %1 no tiene pedido de ensamblado enlazado: no se sabe a qué entrada apuntar el palé.', Comment = '%1 = nº tarea';
        SinUnidadPaleLbl: Label 'El producto %1 no tiene la unidad de palé %2 definida.', Comment = '%1 = producto, %2 = unidad de palé';
        EnsambladoYaUbicadoLbl: Label 'Ya está ubicado todo lo del ensamblado %1.', Comment = '%1 = nº pedido de ensamblado';
        SinAlmacenLbl: Label 'No hay almacén: ni el ensamblado lo lleva ni hay uno por defecto en la configuración SGA.';
        SinUbicacionLibreLbl: Label 'No hay ninguna ubicación libre que admita este palé: %1', Comment = '%1 = motivo';
        TareaAntesInicioLbl: Label 'La tarea %1 es del %2, anterior al inicio de SGA (%3): sus palés no se ubican desde aquí.', Comment = '%1 = nº tarea, %2 = fecha de la tarea, %3 = fecha de inicio de SGA';
        ProductoFueraSGALbl: Label 'SGA no ubica el producto %1 ("Producto Tianna" o de la categoría excluida): sus palés no van a hueco.', Comment = '%1 = producto';
    begin
        // El palé que había en pantalla se descarta: su hueco deja de estar reservado.
        LiberarReservasFilas(prm_Fila);
        prm_Fila.Reset();
        prm_Fila.DeleteAll();
        prm_Aviso := '';

        LeerConfig();
        if prm_Tarea.Fecha < Config."Fecha Inicio SGA" then begin
            prm_Aviso := StrSubstNo(TareaAntesInicioLbl, prm_Tarea.Linea, prm_Tarea.Fecha, Config."Fecha Inicio SGA");
            exit(false);
        end;
        if not cStock.EsProductoSGA(prm_Tarea."Cod. Producto", cUM) then begin
            prm_Aviso := StrSubstNo(ProductoFueraSGALbl, prm_Tarea."Cod. Producto");
            exit(false);
        end;

        prm_Fila.Init();
        prm_Fila.Linea := 1;
        prm_Fila.Origen := prm_Fila.Origen::Produccion;

        rCabEns.SetRange("Document Type", rCabEns."Document Type"::Order);
        rCabEns.SetRange("Linked Tarea", prm_Tarea.Linea);
        rCabEns.SetLoadFields("No.", "Location Code", "Item No.", Lote, "Quantity (Base)");
        if rCabEns.FindFirst() then begin
            prm_Fila."No. Documento" := rCabEns."No.";
            prm_Fila."Cod. Almacen" := rCabEns."Location Code";
            prm_Fila."No. Producto" := rCabEns."Item No.";
            LotesEnsamblado(rCabEns."Item No.", rCabEns.Lote, rCabEns."No.", '', rCabEns."Quantity (Base)", lotes);
        end else begin
            rCabEnsReg.SetRange("Linked Tarea", prm_Tarea.Linea);
            rCabEnsReg.SetRange(Reversed, false);
            rCabEnsReg.SetLoadFields("No.", "Order No.", "Posting Date", "Location Code", "Item No.", Lote, "Quantity (Base)");
            if not rCabEnsReg.FindLast() then begin
                prm_Aviso := StrSubstNo(TareaSinEnsambladoLbl, prm_Tarea.Linea);
                exit(false);
            end;
            prm_Fila."No. Documento" := rCabEnsReg."Order No.";
            prm_Fila."Documento Relacionado" := rCabEnsReg."No.";
            prm_Fila."Fecha Registro" := rCabEnsReg."Posting Date";
            prm_Fila."Cod. Almacen" := rCabEnsReg."Location Code";
            prm_Fila."No. Producto" := rCabEnsReg."Item No.";
            LotesEnsamblado(rCabEnsReg."Item No.", rCabEnsReg.Lote, '', rCabEnsReg."No.", rCabEnsReg."Quantity (Base)", lotes);
        end;

        // El palé es de un solo lote: el único del ensamblado o, si saca varios, el de la tarea,
        // que es el que lleva la etiqueta.
        if lotes.Count() = 1 then
            lote := lotes.Keys().Get(1)
        else
            if lotes.ContainsKey(prm_Tarea.Lote) then
                lote := prm_Tarea.Lote
            else begin
                prm_Aviso := StrSubstNo(LoteDesconocidoLbl, prm_Fila."No. Documento", prm_Tarea.Lote);
                exit(false);
            end;
        prm_Fila."No. Lote" := lote;
        // Hasta saber la unidad del palé, la fila va en unidad base, la de los lotes y la del
        // diario: así el pendiente sale exacto, sin redondeos de ida y vuelta.
        prm_Fila."Cod. Unidad Medida" := cUM.UMBase(prm_Fila."No. Producto");
        prm_Fila."Cantidad Entrada" := lotes.Get(lote);

        // Mismo criterio que CargarEnsamblados: el almacén suele ir en blanco en el ensamblado.
        if prm_Fila."Cod. Almacen" = '' then
            prm_Fila."Cod. Almacen" := Config."Almacen por Defecto";
        if prm_Fila."Cod. Almacen" = '' then begin
            prm_Aviso := SinAlmacenLbl;
            exit(false);
        end;

        factorPale := cUM.FactorSiExiste(prm_Fila."No. Producto", prm_Tarea."Cod. Pale Defecto");
        if factorPale <= 0 then begin
            prm_Aviso := StrSubstNo(SinUnidadPaleLbl, prm_Fila."No. Producto", prm_Tarea."Cod. Pale Defecto");
            exit(false);
        end;

        CalcularPendiente(prm_Fila);
        if prm_Fila.Estado = prm_Fila.Estado::Ubicado then begin
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
        if paleBase > prm_Fila.Pendiente() then
            paleBase := prm_Fila.Pendiente();

        // Unidad en la que se ubica: el palé completo, en la de palé; el incompleto, entero, en
        // cajas si son cajas exactas y si no en unidades. Es el único trozo del reparto con el
        // palé de la tarea.
        cUM.Repartir(prm_Fila."No. Producto", paleBase, prm_Tarea."Cod. Pale Defecto", 1, TempTrozo);
        if not TempTrozo.FindFirst() then begin
            prm_Aviso := StrSubstNo(EnsambladoYaUbicadoLbl, prm_Fila."No. Documento");
            exit(false);
        end;
        umDestino := TempTrozo."Cod. Unidad Medida";
        cantidadDestino := TempTrozo.Cantidad;

        // La fila pasa entera a esa unidad, para que el pendiente y lo ya ubicado se comparen
        // en la misma unidad que se va a registrar.
        prm_Fila."Cod. Unidad Medida" := umDestino;
        prm_Fila."Cantidad Entrada" := cUM.DesdeBase(prm_Fila."No. Producto", umDestino, prm_Fila."Cantidad Entrada");
        prm_Fila."Cantidad Ya Ubicada" := cUM.DesdeBase(prm_Fila."No. Producto", umDestino, prm_Fila."Cantidad Ya Ubicada");
        prm_Fila.Cantidad := cantidadDestino;
        prm_Fila.Insert();

        ProponerParaTodos(prm_Fila);
        // La propuesta se ha guardado desde otra variable: se relee para traerla.
        prm_Fila.FindFirst();
        if prm_Fila."Ubicacion Propuesta" = '' then
            // El motivo de la fila dice por qué no hay hueco (sin sitio, sin ubicaciones con tipo...).
            prm_Aviso := StrSubstNo(SinUbicacionLibreLbl, prm_Fila.Motivo);

        exit(true);
    end;

    /// <summary>
    /// Abre el contenido de ubicaciones con los palés que entraron con un ensamblado: los
    /// ubicados al imprimir su etiqueta van con el nº del pedido y los de "Ubicar ensamblados",
    /// con el del registrado. Enseña dónde está cada palé ahora, también sus cajas sueltas; uno
    /// que ya ha salido entero no tiene contenido y no sale.
    /// </summary>
    procedure MostrarPalesEnsamblado(prm_NoRegistrado: Code[20]; prm_NoPedido: Code[20])
    var
        rMov: Record "Movimiento Ubicacion SGA";
        rContenido: Record "Contenido Ubicacion SGA";
        pales: List of [Code[20]];
        filtro: Text;
        SinPalesMsg: Label 'El ensamblado %1 no tiene palés ubicados en SGA.', Comment = '%1 = nº ensamblado registrado';
        SinContenidoMsg: Label 'Los palés del ensamblado %1 ya no están en ninguna ubicación. Su historia está en Movimientos de ubicación.', Comment = '%1 = nº ensamblado registrado';
    begin
        rMov.FiltrarEntrada(rMov.Origen::Produccion, prm_NoRegistrado, prm_NoPedido);
        rMov.SetRange("Tipo Movimiento", rMov."Tipo Movimiento"::Entrada);
        rMov.SetFilter(SSCC, '<>%1', '');
        rMov.SetLoadFields(SSCC);
        if rMov.FindSet() then
            repeat
                if not pales.Contains(rMov.SSCC) then begin
                    pales.Add(rMov.SSCC);
                    if filtro <> '' then
                        filtro += '|';
                    filtro += rMov.SSCC;
                end;
            until rMov.Next() = 0;

        if filtro = '' then begin
            Message(SinPalesMsg, prm_NoRegistrado);
            exit;
        end;

        rContenido.SetFilter(SSCC, filtro);
        if rContenido.IsEmpty() then begin
            Message(SinContenidoMsg, prm_NoRegistrado);
            exit;
        end;
        Page.Run(Page::"Contenido Ubicaciones SGA", rContenido);
    end;

    /// <summary>
    /// Imprime la etiqueta del palé de una tarea y lo ubica (prm_Pale, el que ha preparado
    /// PrepararPaleTarea). La ubicación y lo que impide sacar la etiqueta se comprueban antes de
    /// imprimir, para no dejar etiquetas de palés sin ubicación.
    ///
    /// En Sandbox no se toca BarTender (su carpeta FTP es la de producción): la etiqueta sale con
    /// el report A5, directa a la impresora que tenga asignada en Selección de impresoras.
    ///
    /// Hace Commit (antes del report A5 y después de imprimir), así que no se puede llamar
    /// dentro de una transacción de registro ni desde una TryFunction. La tarea queda modificada:
    /// quien llama la relee.
    ///
    /// El SSCC del palé se genera aquí, una vez: el que lleva la etiqueta de BarTender es el
    /// mismo con el que se ubica. La etiqueta A5 genera el suyo dentro del report, así que en
    /// Sandbox el palé se ubica con otro SSCC nuevo, distinto del impreso.
    /// </summary>
    procedure ImprimirYUbicarPale(var prm_Tarea: Record "Tareas Produccion"; var prm_Pale: Record "Linea Ubicacion SGA" temporary)
    var
        rConfExistencias: Record "Inventory Setup";
        EnvironmentInformation: Codeunit "Environment Information";
        cContenido: Codeunit "Gestion Contenido SGA";
    begin
        // Antes de imprimir, todo lo que ConfirmarFila rechazaría: si no, la etiqueta saldría
        // para un palé que luego no se ubica. Lo primero, la fila (ubicación indicada, desvío,
        // un palé).
        TestFilaParaUbicar(prm_Pale);
        ComprobarEtiqueta(prm_Tarea);
        // Que la ubicación exista en SGA y admita el palé con las mismas reglas que al ubicar:
        // si no, saldría una etiqueta para un palé que luego no se puede colocar ahí.
        cContenido.TestEntradaAdmitida(prm_Pale."Cod. Almacen", prm_Pale."Ubicacion Confirmada", prm_Pale."No. Producto",
                                       prm_Pale."No. Lote", prm_Pale."Cod. Unidad Medida", prm_Pale.Cantidad, prm_Pale.ReservaFila());

        if EnvironmentInformation.IsSandbox() then
            ImprimirEtiquetaA5(prm_Tarea)
        else begin
            ComprobarBarTender(rConfExistencias);
            prm_Pale.SSCC := '';
            EnviarEtiqueta(prm_Tarea, prm_Pale.SSCCPale(), rConfExistencias);
            prm_Pale.Modify();
        end;
        // La etiqueta ya ha salido: que un fallo al ubicar no deshaga el contador de
        // impresas. El palé quedaría pendiente y se ubica desde "Ubicar entradas".
        Commit();

        ConfirmarFila(prm_Pale);
    end;

    /// <summary>
    /// Da la tarea por terminada igualando las etiquetas impresas con las totales. No toca las
    /// horas de impresión ni ubica nada.
    /// </summary>
    procedure AjustarEtiquetasImpresas(var prm_Tarea: Record "Tareas Produccion")
    begin
        prm_Tarea."Etiquetas Impresas" := prm_Tarea."Etiquetas Totales";
        prm_Tarea.Estado := prm_Tarea.Estado::Finalizado;
        prm_Tarea.Modify();
    end;

    /// <summary>
    /// Lo que impide sacar la etiqueta, salga por donde salga: sin códigos de barras,
    /// producción sin empezar o todas las etiquetas ya impresas.
    /// </summary>
    local procedure ComprobarEtiqueta(var prm_Tarea: Record "Tareas Produccion")
    var
        rItemRef: Record "Item Reference";
        SinCodigosBarrasErr: Label 'Este producto no tiene códigos de barras definidos, revisar y después volver a imprimir.';
        ProduccionNoIniciadaErr: Label 'No se pueden imprimir etiquetas de una producción no iniciada.';
        EtiquetasYaImpresasErr: Label 'Ya están impresas las %1 etiquetas planificadas para esta tarea.', Comment = '%1 = etiquetas totales';
    begin
        rItemRef.SetRange("Item No.", prm_Tarea."Cod. Producto");
        rItemRef.SetRange("Reference Type", rItemRef."Reference Type"::"Bar Code");
        if rItemRef.IsEmpty() then
            Error(SinCodigosBarrasErr);

        if not prm_Tarea."Todo el dia" then begin
            // El 3502007 se etiqueta sin esperar a que arranque la línea, igual que en Pag50250.
            if (prm_Tarea."Cod. Producto" <> '3502007') and (prm_Tarea."Estado Produccion" = prm_Tarea."Estado Produccion"::"0") then
                Error(ProduccionNoIniciadaErr);
            // Pag50250 deja sacar una de más (compara con >). Aquí cada etiqueta es un palé que
            // se ubica, así que no se pasa de las planificadas.
            if prm_Tarea."Etiquetas Impresas" >= prm_Tarea."Etiquetas Totales" then
                Error(EtiquetasYaImpresasErr, prm_Tarea."Etiquetas Totales");
        end;
    end;

    /// <summary>
    /// BarTender necesita la ruta y la conexión FTP de la carpeta que vigila la impresora. Las
    /// deja leídas en prm_ConfExistencias para enviar la etiqueta.
    /// </summary>
    local procedure ComprobarBarTender(var prm_ConfExistencias: Record "Inventory Setup")
    var
        FaltaRutaEtiquetasErr: Label 'Falta configuración ruta exportación impresión etiquetas producción.';
    begin
        prm_ConfExistencias.SetLoadFields("Ruta Fichero Etiquetas", "Conexion FTP - Impr. Etiquetas");
        if not prm_ConfExistencias.Get() then
            Error(FaltaRutaEtiquetasErr);
        prm_ConfExistencias.TestField("Ruta Fichero Etiquetas");
        prm_ConfExistencias.TestField("Conexion FTP - Impr. Etiquetas");
    end;

    /// <summary>
    /// Genera el fichero de la etiqueta para BarTender, suma una etiqueta impresa a la tarea y
    /// sube el fichero a la carpeta que vigila la impresora. Mismo contenido que
    /// CrearFicheroImpresora de Pag50250. El código del palé son los 17 primeros dígitos del SSCC
    /// (BarTender pone el de control), como allí. prm_ConfExistencias llega leída
    /// (ComprobarBarTender).
    /// </summary>
    local procedure EnviarEtiqueta(var prm_Tarea: Record "Tareas Produccion"; prm_SSCC: Code[20]; var prm_ConfExistencias: Record "Inventory Setup")
    var
        rItem: Record Item;
        rDatos: Record "Datos Reports Temporales";
        TempFileBuffer: Record "DynES HLP File Buffer" temporary;
        cduDynasoftFTPHelper: Codeunit "DynES HLP Ftp Helper";
        OutStr: OutStream;
        dato: Text;
        tipoPrecinto: Code[20];
        volumen: Text;
        caducidadText: Text;
        dun14: Text;
        ean13: Text;
        FicheroTok: Label 'EtiquetasA5.txt', Locked = true;
        CodigoDatosTok: Label 'BARTENDER', Locked = true;
    begin
        rItem.SetLoadFields("Unit Volume", "Grados de Alcohol", "Tipo Alcohol");
        rItem.SetAutoCalcFields("EAN-13", "DUN-14");
        rItem.Get(prm_Tarea."Cod. Producto");
        dun14 := CopyStr(rItem."DUN-14", 1, 13);    // Caja: DUN-14 sin dígito de control
        ean13 := CopyStr(rItem."EAN-13", 1, 12);    // Botella: EAN-13 sin dígito de control

        // Sin precinto se etiqueta como EXPORT.
        if prm_Tarea."Tipo Precinto" <> '' then
            tipoPrecinto := prm_Tarea."Tipo Precinto"
        else
            tipoPrecinto := 'EXPORT';

        if rItem."Unit Volume" = 1.0 then
            volumen := '1,00'
        else
            volumen := Format(rItem."Unit Volume");

        caducidadText := Format(prm_Tarea.Caducidad, 6, '<Year,2><Month,2><Day,2>');

        dato := prm_Tarea.Descripcion + ';' +
                'GRADOS: ' + Format(rItem."Grados de Alcohol") + ';' +
                'VOLUMEN: ' + volumen + ';' +
                'FAMILIA: ' + rItem."Tipo Alcohol" + ';' +
                'LOTE: ' + prm_Tarea.Lote + ';' +
                'NAV: ' + prm_Tarea."Cod. Producto" + ';' +
                'VARIANTE: ' + tipoPrecinto + ';' +
                prm_Tarea."Unidad Medida Venta" + ';' +
                prm_Tarea."Cod. Pale Defecto" + ';' +
                dun14 + ';' +
                ean13 + ';' +
                CopyStr(prm_SSCC, 1, 17) + ';' +
                ';' +
                Format(prm_Tarea."Qty. Und. Medida") + ';' +
                '01' + ';' +
                prm_Tarea.Lote + ';' +
                caducidadText;

        rDatos.SetRange(Code01, CodigoDatosTok);
        rDatos.DeleteAll();

        rDatos.Init();
        rDatos.Usuario := CopyStr(UserId(), 1, MaxStrLen(rDatos.Usuario));
        rDatos.Fecha := Today;
        rDatos.Hora := Time;
        rDatos.Code01 := CodigoDatosTok;
        rDatos.Integer01 := 1;
        rDatos.Text01 := CopyStr(dato, 1, MaxStrLen(rDatos.Text01));
        rDatos.Insert();

        prm_Tarea."Etiquetas Impresas" += 1;
        AnotarEtiquetaImpresa(prm_Tarea);

        TempFileBuffer.Init();
        TempFileBuffer.Id := 2;
        TempFileBuffer."Full File Path" := StrSubstNo('%1%2', prm_ConfExistencias."Ruta Fichero Etiquetas", FicheroTok);
        TempFileBuffer."File Name" := FicheroTok;
        TempFileBuffer."File Content".CreateOutStream(OutStr);
        Xmlport.Export(Xmlport::"Ficheros Impresora", OutStr, rDatos);
        TempFileBuffer.Insert();
        TempFileBuffer.SetRange(Id, 2);
        cduDynasoftFTPHelper.Upload(CopyStr(prm_ConfExistencias."Conexion FTP - Impr. Etiquetas", 1, 20), TempFileBuffer);
    end;

    /// <summary>
    /// Etiqueta A5 (report 50237) sin ventana de opciones: va directa a la impresora que tenga
    /// el report en Selección de impresoras (Universal Print). Sin impresora asignada, BC la
    /// descarga en PDF.
    ///
    /// El report ya suma la etiqueta impresa, y solo si se imprime de verdad. Si el contador no
    /// sube, no ha salido etiqueta y se para aquí: no se ubica un palé sin etiqueta. Lo que el
    /// report no hace (horas y dar la tarea por terminada) lo completa AnotarEtiquetaImpresa.
    /// </summary>
    local procedure ImprimirEtiquetaA5(var prm_Tarea: Record "Tareas Produccion")
    var
        rTarea: Record "Tareas Produccion";
        impresasAntes: Decimal;
        EtiquetaNoImpresaErr: Label 'No ha salido la etiqueta del palé: no se ubica.';
    begin
        impresasAntes := prm_Tarea."Etiquetas Impresas";

        // Un report no se puede lanzar con una transacción abierta.
        Commit();
        rTarea.Get(prm_Tarea.Linea);
        rTarea.SetRecFilter();
        Report.RunModal(Report::"Etiqueta Producto A5", false, false, rTarea);

        prm_Tarea.Get(prm_Tarea.Linea);
        if prm_Tarea."Etiquetas Impresas" <= impresasAntes then
            Error(EtiquetaNoImpresaErr);

        AnotarEtiquetaImpresa(prm_Tarea);
    end;

    /// <summary>
    /// Completa en la tarea una etiqueta que ya está contada en "Etiquetas Impresas": la hora
    /// de la primera y, con la última, la hora y la tarea terminada. Es lo mismo salga la
    /// etiqueta por BarTender o por el report A5.
    /// </summary>
    local procedure AnotarEtiquetaImpresa(var prm_Tarea: Record "Tareas Produccion")
    begin
        if prm_Tarea."Etiquetas Impresas" = 1 then
            prm_Tarea."Hora Primera Impresion" := Time;
        if prm_Tarea."Etiquetas Totales" = prm_Tarea."Etiquetas Impresas" then begin
            prm_Tarea.Estado := prm_Tarea.Estado::Finalizado;
            prm_Tarea."Hora Ultima Impresion" := Time;
        end;
        prm_Tarea.Modify();
    end;

    /// <summary>
    /// Propuesta para una fila concreta, con la estrategia que diga la configuración para
    /// su origen. El hueco propuesto queda reservado para la fila (ReservarHueco) y el que tenía
    /// antes se suelta. Si otra sesión lo ha reservado entre que se propone y se reserva, se
    /// busca otro.
    /// </summary>
    local procedure ProponerParaFila(var prm_Fila: Record "Linea Ubicacion SGA" temporary; prm_Excluidas: Text; var prm_Motivo: Text) codigo: Code[20]
    var
        estrategia: Enum "Estrategia Ubicacion SGA";
        cantidad: Decimal;
        intento: Integer;
    begin
        LeerConfig();

        if prm_Fila.Origen = prm_Fila.Origen::Compra then
            estrategia := Config."Estrategia Ubic. Compras"
        else
            estrategia := Config."Estrategia Ubic. Ensamblados";

        cantidad := prm_Fila.Cantidad;
        if cantidad <= 0 then
            cantidad := prm_Fila.Pendiente();

        cUbicaciones.FijarReserva(prm_Fila.ReservaFila());
        for intento := 1 to 5 do begin
            // Sin hueco, el motivo dice por qué: sin ubicaciones con tipo, sin espacio, etc.
            codigo := cUbicaciones.ProponerUbicacionCon(estrategia, prm_Excluidas,
                                                        prm_Fila."Cod. Almacen", prm_Fila."No. Producto",
                                                        prm_Fila."No. Lote",
                                                        prm_Fila."Cod. Unidad Medida", cantidad, prm_Motivo);
            if (codigo = '') or (prm_Fila.ReservaFila() = '') then
                exit(codigo);
            if cUbicaciones.ReservarHueco(prm_Fila."Cod. Almacen", codigo, prm_Fila.ReservaFila()) then
                exit(codigo);
            prm_Excluidas := cUbicaciones.AnadirExclusion(prm_Excluidas, codigo);
        end;
        exit('');
    end;

    /// <summary>
    /// Suelta los huecos reservados para las filas que no se han llegado a ubicar. Lo llaman
    /// las pantallas al cerrarse.
    /// </summary>
    procedure LiberarReservasFilas(var prm_Buffer: Record "Linea Ubicacion SGA" temporary)
    var
        TempFila: Record "Linea Ubicacion SGA" temporary;
    begin
        TempFila.Copy(prm_Buffer, true);
        TempFila.Reset();
        if TempFila.FindSet() then
            repeat
                // Una fila solo tiene hueco reservado si tiene uno propuesto o confirmado
                // (ProponerParaFila, ProponerOtra, OnValidate de "Ubicacion Confirmada").
                if (TempFila."Ubicacion Propuesta" <> '') or (TempFila."Ubicacion Confirmada" <> '') then
                    cUbicaciones.LiberarReservas(TempFila.ReservaFila(), '');
            until TempFila.Next() = 0;
    end;

    /// <summary>
    /// Rellena lo ya ubicado, lo que se ubica ahora (Cantidad) y el estado de una fila: Ubicado
    /// cuando ya no queda nada y Pendiente si no. Cada palé lleva su SSCC, así que se ubica de
    /// palé en palé: Cantidad es lo que queda, sin pasar de un palé del producto.
    /// </summary>
    local procedure CalcularPendiente(var prm_Fila: Record "Linea Ubicacion SGA" temporary)
    var
        paleEnUMFila: Decimal;
    begin
        prm_Fila."Cantidad Ya Ubicada" := YaUbicadaFila(prm_Fila);
        prm_Fila.Cantidad := prm_Fila.Pendiente();
        if UnPaleEnUMFila(prm_Fila, paleEnUMFila) then
            if prm_Fila.Cantidad > paleEnUMFila then
                prm_Fila.Cantidad := paleEnUMFila;
        if prm_Fila.Cantidad <= 0 then
            prm_Fila.Estado := prm_Fila.Estado::Ubicado
        else
            prm_Fila.Estado := prm_Fila.Estado::Pendiente;
    end;

    /// <summary>
    /// Un palé del producto expresado en la unidad de la fila, en prm_PaleEnUM. False si el
    /// producto no tiene palé (FactorPale da 1): entonces no se limita a un palé.
    /// </summary>
    local procedure UnPaleEnUMFila(var prm_Fila: Record "Linea Ubicacion SGA" temporary; var prm_PaleEnUM: Decimal): Boolean
    var
        factorPale: Decimal;
    begin
        factorPale := cUM.FactorPale(prm_Fila."No. Producto");
        if factorPale <= 1 then
            exit(false);
        prm_PaleEnUM := cUM.DesdeBase(prm_Fila."No. Producto", prm_Fila."Cod. Unidad Medida", factorPale);
        exit(true);
    end;

    /// <summary>
    /// Lo ya ubicado de una fila, en su unidad, leído del diario de movimientos. Los palés
    /// ubicados al imprimir su etiqueta (Ubicar Palets Linea SGA) van con el nº del pedido de
    /// ensamblado (Documento Relacionado), que no es el del registrado: sin sumarlos se ubicarían
    /// dos veces.
    ///
    /// La clave (Origen + documento) no lleva sumatorios: CalcSums suma en la tabla, sobre los
    /// pocos movimientos del documento.
    /// En las recepciones se filtra por unidad de medida: un albarán puede traer el mismo lote
    /// en cajas y en palés, en filas distintas, y no hay que mezclarlas.
    /// En producción hay una sola fila por ensamblado, pero sus palés pueden haberse ubicado en
    /// otra unidad al imprimir la etiqueta (palé, cajas o unidades, ver PrepararPaleTarea). Ahí
    /// se suma todo en unidad base y se devuelve en la unidad de la fila.
    /// </summary>
    local procedure YaUbicadaFila(var prm_Fila: Record "Linea Ubicacion SGA" temporary): Decimal
    var
        rMov: Record "Movimiento Ubicacion SGA";
        todasLasUM: Boolean;
    begin
        if prm_Fila."No. Documento" = '' then
            exit(0);

        todasLasUM := prm_Fila.Origen = prm_Fila.Origen::Produccion;

        rMov.FiltrarEntrada(prm_Fila.Origen, prm_Fila."No. Documento", prm_Fila."Documento Relacionado");
        rMov.SetRange("No. Producto", prm_Fila."No. Producto");
        rMov.SetRange("No. Lote", prm_Fila."No. Lote");
        if not todasLasUM then
            rMov.SetRange("Cod. Unidad Medida", prm_Fila."Cod. Unidad Medida");
        rMov.SetRange("Tipo Movimiento", rMov."Tipo Movimiento"::Entrada);
        rMov.CalcSums(Cantidad, "Cantidad Base");

        if todasLasUM then
            exit(cUM.DesdeBase(prm_Fila."No. Producto", prm_Fila."Cod. Unidad Medida", rMov."Cantidad Base"));
        exit(rMov.Cantidad);
    end;

    /// <summary>
    /// Filtro de exclusión con los huecos que ya tienen reservadas las demás filas.
    /// </summary>
    local procedure ExclusionesDeOtrasFilas(var prm_Fila: Record "Linea Ubicacion SGA" temporary): Text
    var
        TempOtra: Record "Linea Ubicacion SGA" temporary;
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
                excluidas := cUbicaciones.AnadirExclusion(excluidas, TempOtra."Ubicacion Propuesta");
        until TempOtra.Next() = 0;

        exit(excluidas);
    end;

    /// <summary>
    /// Lee la configuración la primera vez que se necesita en la instancia; las siguientes,
    /// la que ya tiene.
    /// </summary>
    local procedure LeerConfig()
    begin
        if ConfigLeida then
            exit;
        Config.ObtenerConfig();
        ConfigLeida := true;
    end;

    var
        // La configuración, leída una vez por instancia (LeerConfig).
        Config: Record "Config. SGA";
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        cUM: Codeunit "Unidades Producto SGA";
        cUOMMgt: Codeunit "Unit of Measure Management";
        cStock: Codeunit "Consulta Stock SGA";
        ConfigLeida: Boolean;
        FechaDesde: Date;
        FechaHasta: Date;
        ClaseFiltro: Integer;
        ProductoFiltro: Code[20];
        // Solo con CargarEntradasLote: deja la carga en un lote.
        FiltrarLote: Boolean;
        CualquierLote: Boolean;
        LoteFiltro: Code[50];
}
