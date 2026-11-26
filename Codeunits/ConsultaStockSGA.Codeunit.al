namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using System.Utilities;

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
    var
        CategoriaExcluidaTok: Label '820', Locked = true;

    /// <summary>
    /// Si SGA ubica el producto: de tipo Inventario, sin marcar como "Producto Tianna" y fuera
    /// de la categoría 820. Es la regla de todo SGA: lo mismo que filtra FiltrarProductosSGA y lo
    /// que miran EsProductoSGA y TestProductoSGA. prm_Item tiene que traer leídos esos tres
    /// campos; para quien ya tiene la ficha leída por otro motivo.
    /// </summary>
    procedure ProductoSGA(var prm_Item: Record Item): Boolean
    begin
        exit(prm_Item.IsInventoriableType() and not prm_Item."Producto Tianna" and
             (prm_Item."Item Category Code" <> CategoriaExcluidaTok));
    end;

    /// <summary>
    /// ProductoSGA de un producto por su código, con la ficha que guarda prm_UM (Unidades
    /// Producto SGA.Ficha): quien mira muchos productos pasa siempre la misma instancia y cada
    /// ficha se lee una vez. False si el producto no existe.
    /// </summary>
    procedure EsProductoSGA(prm_Producto: Code[20]; var prm_UM: Codeunit "Unidades Producto SGA"): Boolean
    var
        rFicha: Record Item;
    begin
        if not prm_UM.Ficha(prm_Producto, rFicha) then
            exit(false);
        exit(ProductoSGA(rFicha));
    end;

    /// <summary>
    /// Deja en prm_Item solo los productos que SGA ubica (ProductoSGA). Va en otro grupo de
    /// filtros para no sustituir los que ya traiga.
    /// </summary>
    procedure FiltrarProductosSGA(var prm_Item: Record Item)
    var
        grupo: Integer;
    begin
        grupo := prm_Item.FilterGroup();
        prm_Item.FilterGroup(2);
        prm_Item.SetRange(Type, prm_Item.Type::Inventory);
        prm_Item.SetRange("Producto Tianna", false);
        prm_Item.SetFilter("Item Category Code", '<>%1', CategoriaExcluidaTok);
        prm_Item.FilterGroup(grupo);
    end;

    /// <summary>
    /// Error si SGA no ubica el producto (ProductoSGA). Sin ficha, el error estándar de que no
    /// existe.
    /// </summary>
    procedure TestProductoSGA(prm_Producto: Code[20])
    var
        rFicha: Record Item;
    begin
        if not cUM.Ficha(prm_Producto, rFicha) then
            rFicha.Get(prm_Producto);
        TestProductoSGA(rFicha);
    end;

    /// <summary>
    /// Error si el producto lleva lotes de BC (LoteEstandar) y no se dice el lote: en blanco se
    /// mezclarían todos.
    /// </summary>
    procedure TestLoteIndicado(prm_Producto: Code[20]; prm_Lote: Code[50])
    var
        LoteObligatorioErr: Label 'El producto %1 lleva lotes: indique el lote que va a ubicar.', Comment = '%1 = producto';
    begin
        if (prm_Lote = '') and LoteEstandar(prm_Producto) then
            Error(LoteObligatorioErr, prm_Producto);
    end;

    /// <summary>
    /// TestProductoSGA sobre la ficha ya leída por quien llama, con el tipo, "Producto Tianna" y
    /// la categoría.
    /// </summary>
    procedure TestProductoSGA(var prm_Item: Record Item)
    var
        ProductoFueraSGAErr: Label 'SGA no ubica el producto %1: solo los de tipo Inventario que no son "Producto Tianna" ni de la categoría %2.', Comment = '%1 = producto, %2 = categoría excluida';
    begin
        if not ProductoSGA(prm_Item) then
            Error(ProductoFueraSGAErr, prm_Item."No.", CategoriaExcluidaTok);
    end;

    /// <summary>
    /// Acumula en el buffer el stock de BC de un producto en un almacén, desglosado por lote.
    /// No borra el buffer: suma sobre lo que ya haya, de modo que se puede llamar en bucle para
    /// varios productos. Con el producto en blanco, todos los del almacén en una sola lectura
    /// (Pendiente de ubicar). SGA no distingue variantes: el stock de todas se suma en la misma
    /// fila.
    /// </summary>
    local procedure AcumularStockPorLote(prm_Producto: Code[20]; prm_Almacen: Code[10]; var rStock: Record "Buffer Conciliacion SGA")
    var
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
                AcumularFila(rStock, qMovsAbiertos.Item_No, qMovsAbiertos.Location_Code,
                             qMovsAbiertos.Lot_No_, umBase, qMovsAbiertos.Remaining_Quantity, 0);
        qMovsAbiertos.Close();
    end;

    /// <summary>
    /// Acumula en el buffer el contenido que SGA tiene ubicado de un producto,
    /// desglosado por lote. Con el producto en blanco, todos los del almacén.
    /// Un producto sin lotes de BC se acumula sin lote: su stock de BC no lo lleva aunque SGA
    /// guarde el del ensamblado, y comparar lote a lote daría una fila "sin ubicar" y otra
    /// "sobra" de la misma mercancía.
    /// </summary>
    local procedure AcumularContenidoUbicado(prm_Producto: Code[20]; prm_Almacen: Code[10]; var rStock: Record "Buffer Conciliacion SGA")
    var
        rContenido: Record "Contenido Ubicacion SGA";
        conLoteBC: Dictionary of [Code[20], Boolean];
        umBase: Code[10];
        lote: Code[50];
        loteEstandarProducto: Boolean;
    begin
        rContenido.SetCurrentKey("No. Producto", "Cod. Almacen", "No. Lote");
        if prm_Producto <> '' then
            rContenido.SetRange("No. Producto", prm_Producto);
        if prm_Almacen <> '' then
            rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetLoadFields("No. Producto", "Cod. Almacen", "No. Lote", "Cantidad Base");
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
                AcumularFila(rStock, rContenido."No. Producto", rContenido."Cod. Almacen",
                             lote, umBase, 0, rContenido."Cantidad Base");
        until rContenido.Next() = 0;
    end;

    /// <summary>
    /// Conciliación (Rep. "Conciliacion SGA vs Stock"): deja en el buffer del usuario el stock
    /// de BC y lo ubicado, lote a lote, de los productos que SGA ubica (ProductoSGA) en un almacén
    /// (en blanco, todos), con la misma lectura que "Pendiente de ubicar" (LeerStockYUbicado).
    /// Con prm_SoloDiferencias, solo las filas que no cuadran. Borra antes la conciliación
    /// anterior del usuario (el buffer es compartido: dos personas pueden conciliar a la vez).
    /// Devuelve cuántas filas quedan.
    /// </summary>
    procedure Conciliar(prm_Almacen: Code[10]; prm_VistaProductos: Text; prm_SoloDiferencias: Boolean): Integer
    var
        rStock: Record "Buffer Conciliacion SGA";
        TempStock: Record "Buffer Conciliacion SGA" temporary;
        cVentana: Codeunit "Ventana Progreso SGA";
        lineas: Integer;
        TituloLbl: Label 'Conciliando el stock de BC con las ubicaciones…';
    begin
        rStock.FiltrarUsuarioActual();
        rStock.DeleteAll();

        // Se acumula en memoria y a la tabla solo va lo que se enseña.
        cVentana.Abrir(TituloLbl, 0);
        LeerStockYUbicado(prm_Almacen, prm_VistaProductos, TempStock, cVentana);
        cVentana.Cerrar();

        // Leyendo todo el almacén de una vez vienen todos los productos: fuera los que SGA no
        // ubica y, si se piden solo las diferencias, lo que cuadra.
        if TempStock.FindSet() then
            repeat
                if EsProductoSGA(TempStock."No. Producto", cUM) and not (prm_SoloDiferencias and (TempStock.Diferencia = 0)) then begin
                    rStock := TempStock;
                    rStock.Insert();
                    lineas += 1;
                end;
            until TempStock.Next() = 0;
        exit(lineas);
    end;

    /// <summary>
    /// Acumula en prm_Stock el stock de BC y lo ubicado, lote a lote, de un almacén. Si
    /// prm_VistaProductos (GetView de Item) trae filtros, solo de los productos que SGA ubica y
    /// los cumplen, uno a uno. Sin filtros, los de todo el almacén de una vez (dos consultas, no
    /// dos por producto), sin mirar si SGA los ubica: eso lo decide quien llama.
    /// </summary>
    local procedure LeerStockYUbicado(prm_Almacen: Code[10]; prm_VistaProductos: Text; var prm_Stock: Record "Buffer Conciliacion SGA"; var prm_Ventana: Codeunit "Ventana Progreso SGA")
    var
        rItem: Record Item;
        LeyendoStockLbl: Label 'Leyendo el stock y las ubicaciones del almacén';
        LeyendoProductoLbl: Label 'Leyendo stock del producto %1', Comment = '%1 = nº de producto';
    begin
        if prm_VistaProductos <> '' then
            rItem.SetView(prm_VistaProductos);
        if rItem.GetFilters() = '' then begin
            prm_Ventana.Fase(LeyendoStockLbl);
            AcumularStockPorLote('', prm_Almacen, prm_Stock);
            AcumularContenidoUbicado('', prm_Almacen, prm_Stock);
            exit;
        end;

        FiltrarProductosSGA(rItem);
        rItem.SetLoadFields("No.");
        prm_Ventana.FijarTotal(rItem.Count());
        if rItem.FindSet() then
            repeat
                prm_Ventana.Avanzar(StrSubstNo(LeyendoProductoLbl, rItem."No."));
                AcumularStockPorLote(rItem."No.", prm_Almacen, prm_Stock);
                AcumularContenidoUbicado(rItem."No.", prm_Almacen, prm_Stock);
            until rItem.Next() = 0;
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
        cConfirmMgt: Codeunit "Confirm Management";
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

        if not cConfirmMgt.GetResponseOrDefault(StrSubstNo(ColocarEnAjustesQst, aRegularizar, prm_Fila."No. Producto", rConfig."Ubic. Ajustes"), false) then
            exit(false);

        // El stock que BC tiene y SGA no aparece en la ubicación de ajustes hasta que
        // alguien lo coloque físicamente donde le corresponde.
        cContenido.RegistrarAjuste("Tipo Mov. Ubicacion SGA"::Ajuste, prm_Fila."Cod. Almacen", rConfig."Ubic. Ajustes", prm_Fila."No. Producto",
                                   prm_Fila."No. Lote", '', prm_Fila."Unidad Medida Base",
                                   aRegularizar, RegularizacionConciliacionLbl);

        prm_Fila."Stock SGA" += aRegularizar;
        prm_Fila.CalcularDiferencia();
        prm_Fila.Modify();

        exit(true);
    end;

    local procedure AcumularFila(var rStock: Record "Buffer Conciliacion SGA"; prm_Producto: Code[20]; prm_Almacen: Code[10]; prm_Lote: Code[50]; prm_UMBase: Code[10]; prm_StockBC: Decimal; prm_StockSGA: Decimal)
    var
        rConfig: Record "Config. SGA";
        usuario: Code[50];
    begin
        usuario := rConfig.UsuarioActual();

        if rStock.Get(usuario, prm_Producto, prm_Almacen, prm_Lote) then begin
            rStock."Stock BC" := rStock."Stock BC" + prm_StockBC;
            rStock."Stock SGA" := rStock."Stock SGA" + prm_StockSGA;
            rStock.CalcularDiferencia();
            rStock.Modify();
            exit;
        end;

        rStock.Init();
        rStock."Cod. Usuario" := usuario;
        rStock."No. Producto" := prm_Producto;
        rStock."Cod. Almacen" := prm_Almacen;
        rStock."No. Lote" := prm_Lote;
        rStock."Unidad Medida Base" := prm_UMBase;
        rStock."Stock BC" := prm_StockBC;
        rStock."Stock SGA" := prm_StockSGA;
        rStock.CalcularDiferencia();
        rStock.Insert();
    end;

    /// <summary>
    /// Lo que hay en stock y no está en ninguna ubicación, por producto y lote, en un
    /// almacén. Deja en prm_Pendiente una línea por cada lote con algo sin ubicar (Diferencia,
    /// en unidad base) y devuelve cuántas. prm_Pendiente tiene que ser temporal: se vacía entero,
    /// sin mirar el usuario, y la tabla real guarda la conciliación de todos.
    ///
    /// De lo sin ubicar se separa lo que está pendiente en "Ubicar recepciones" o "Ubicar
    /// ensamblados" (En Documentos): eso se ubica desde esas pantallas, que lo cuentan por su
    /// documento; si se ubicara por otro lado, lo volverían a pedir. Lo que queda (A Ubicar)
    /// no tiene documento que lo reclame: restos de una carga inicial, ajustes, etc.
    ///
    /// Solo cuenta los productos que SGA ubica (ProductoSGA) con existencias en el almacén. Con
    /// prm_EntradoDesde, de cada lote solo cuenta lo que queda de lo entrado desde esa fecha (lo
    /// de antes lo coloca la carga inicial); en blanco, todo. Solo mira los documentos de los
    /// lotes que tienen algo sin ubicar.
    ///
    /// Si prm_VistaProductos (GetView de Item) trae filtros, solo se leen el stock y el contenido
    /// de los productos que los cumplen, uno a uno. Sin filtros, los de todo el almacén se leen de
    /// una vez (dos consultas, no dos por producto). Las existencias de un producto son la suma de
    /// sus lotes: lo que queda en los movimientos abiertos suma lo mismo que su Inventory.
    /// </summary>
    procedure CargarPendienteUbicar(prm_Almacen: Code[10]; prm_VistaProductos: Text; prm_EntradoDesde: Date; var prm_Pendiente: Record "Buffer Conciliacion SGA" temporary): Integer
    var
        TempStock: Record "Buffer Conciliacion SGA" temporary;
        TempEntradas: Record "Linea Ubicacion SGA" temporary;
        cEntradas: Codeunit "Gestion Entradas SGA";
        cVentana: Codeunit "Ventana Progreso SGA";
        existencias: Dictionary of [Code[20], Decimal];
        producto: Code[20];
        productoCuenta: Boolean;
        suma: Decimal;
        lineas: Integer;
        PendienteNoTemporalErr: Label 'El pendiente de ubicar solo se calcula sobre una tabla temporal.';
        TituloLbl: Label 'Calculando lo pendiente de ubicar…';
        ProductoLbl: Label 'Revisando lotes del producto %1', Comment = '%1 = nº de producto';
    begin
        if not prm_Pendiente.IsTemporary() then
            Error(PendienteNoTemporalErr);
        prm_Pendiente.Reset();
        prm_Pendiente.DeleteAll();

        // Se enseña en qué va: la lectura del stock (de todo el almacén o producto a producto) y
        // luego lote a lote.
        cVentana.Abrir(TituloLbl, 0);
        LeerStockYUbicado(prm_Almacen, prm_VistaProductos, TempStock, cVentana);

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

        producto := '';
        repeat
            cVentana.Avanzar(StrSubstNo(ProductoLbl, TempStock."No. Producto"));
            if TempStock."No. Producto" <> producto then begin
                producto := TempStock."No. Producto";
                productoCuenta := false;
                if existencias.Get(producto) > 0 then
                    productoCuenta := EsProductoSGA(producto, cUM);
            end;

            if productoCuenta then begin
                prm_Pendiente := TempStock;
                if CalcularPendienteLote(cEntradas, TempEntradas, prm_Almacen, prm_EntradoDesde, prm_Pendiente) then begin
                    prm_Pendiente."Fecha Caducidad" := CaducidadLote(producto, TempStock."No. Lote");
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
    /// Deja marcados en prm_Item (MarkedOnly) los productos con algo que ubicar a mano en el
    /// almacén: "A Ubicar" de CargarPendienteUbicar con la "Fecha inicio SGA", lo mismo que mide
    /// "Ubicar producto". Error si no hay ninguno.
    /// </summary>
    procedure MarcarPendientesUbicar(prm_Almacen: Code[10]; var prm_Item: Record Item)
    var
        TempPendiente: Record "Buffer Conciliacion SGA" temporary;
        rConfig: Record "Config. SGA";
        producto: Code[20];
        NadaPendienteErr: Label 'No hay nada pendiente de ubicar a mano en el almacén %1.', Comment = '%1 = almacén';
    begin
        rConfig.ObtenerConfig();
        CargarPendienteUbicar(prm_Almacen, '', rConfig."Fecha Inicio SGA", TempPendiente);
        TempPendiente.SetFilter("A Ubicar", '>0');
        if not TempPendiente.FindSet() then
            Error(NadaPendienteErr, prm_Almacen);
        // Mark va por la clave primaria: basta con ponerla, sin leer la ficha.
        producto := '';
        repeat
            if TempPendiente."No. Producto" <> producto then begin
                producto := TempPendiente."No. Producto";
                prm_Item."No." := producto;
                prm_Item.Mark(true);
            end;
        until TempPendiente.Next() = 0;
        prm_Item.MarkedOnly(true);
    end;

    /// <summary>
    /// Lo pendiente de ubicar de un lote: la regla única que usan "Pendiente de ubicar" y
    /// "Ubicar producto". prm_Lote trae el producto, el lote, "Stock BC" y "Stock SGA"; deja en
    /// él la Diferencia (sin ubicar), "En Documentos" (lo que espera en Ubicar recepciones o
    /// Ubicar ensamblados) y "A Ubicar" (el resto). Lo entrado antes de prm_EntradoDesde es de
    /// la carga inicial mientras SGA no haya movido nunca el lote. Devuelve si queda algo sin
    /// ubicar.
    /// </summary>
    local procedure CalcularPendienteLote(var prm_Entradas: Codeunit "Gestion Entradas SGA"; var prm_Buffer: Record "Linea Ubicacion SGA" temporary; prm_Almacen: Code[10]; prm_EntradoDesde: Date; var prm_Lote: Record "Buffer Conciliacion SGA" temporary): Boolean
    var
        stockDesde: Decimal;
    begin
        prm_Lote.CalcularDiferencia();
        if (prm_Lote.Diferencia > 0) and (prm_EntradoDesde <> 0D) and
           not LoteMovidoEnSGA(prm_Lote."No. Producto", prm_Almacen, prm_Lote."No. Lote")
        then begin
            stockDesde := StockEntradoDesde(prm_Lote."No. Producto", prm_Almacen, prm_Lote."No. Lote", prm_EntradoDesde);
            if prm_Lote.Diferencia > stockDesde then
                prm_Lote.Diferencia := stockDesde;
        end;
        if prm_Lote.Diferencia <= 0 then
            exit(false);

        prm_Lote."En Documentos" := PendienteEnDocumentosHasta(prm_Entradas, prm_Buffer, prm_Almacen, prm_Lote, prm_Lote.Diferencia);
        prm_Lote."A Ubicar" := prm_Lote.Diferencia - prm_Lote."En Documentos";
        exit(true);
    end;

    /// <summary>
    /// Si SGA tiene algún movimiento del lote en el almacén. Un lote en blanco (producto sin
    /// lotes de BC) mira el producto entero: SGA puede guardarle el lote del ensamblado.
    /// </summary>
    local procedure LoteMovidoEnSGA(prm_Producto: Code[20]; prm_Almacen: Code[10]; prm_Lote: Code[50]): Boolean
    var
        rMovimiento: Record "Movimiento Ubicacion SGA";
    begin
        rMovimiento.SetCurrentKey("No. Producto", "No. Lote", "Fecha Registro");
        rMovimiento.SetRange("No. Producto", prm_Producto);
        if prm_Lote <> '' then
            rMovimiento.SetRange("No. Lote", prm_Lote);
        rMovimiento.SetRange("Cod. Almacen", prm_Almacen);
        exit(not rMovimiento.IsEmpty());
    end;

    /// <summary>
    /// Lo que le queda al lote en el almacén de las entradas registradas desde prm_Fecha, en
    /// unidad base: lo pendiente del lote nunca pasa de aquí.
    /// </summary>
    local procedure StockEntradoDesde(prm_Producto: Code[20]; prm_Almacen: Code[10]; prm_Lote: Code[50]; prm_Fecha: Date): Decimal
    var
        rMov: Record "Item Ledger Entry";
    begin
        rMov.SetRange("Item No.", prm_Producto);
        rMov.SetRange(Open, true);
        rMov.SetRange(Positive, true);
        rMov.SetRange("Location Code", prm_Almacen);
        rMov.SetRange("Lot No.", prm_Lote);
        rMov.SetFilter("Posting Date", '>=%1', prm_Fecha);
        rMov.CalcSums("Remaining Quantity");
        exit(rMov."Remaining Quantity");
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
    /// movimientos de producto abiertos de ese producto y lote en el almacén, que son
    /// los que suma AcumularStockPorLote.
    /// </summary>
    procedure MostrarStockBC(var prm_Linea: Record "Buffer Conciliacion SGA")
    var
        rItemLedgEntry: Record "Item Ledger Entry";
    begin
        rItemLedgEntry.SetRange("Item No.", prm_Linea."No. Producto");
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
    /// Lo que queda por ubicar de un lote (producto y lote de prm_Lote), en unidad
    /// base, en las pantallas de entradas de ese origen (recepciones o ensamblados), desde la
    /// fecha de inicio de SGA. Lo de documentos anteriores queda en "A Ubicar": ya es stock de BC.
    /// </summary>
    local procedure PendienteEnDocumentos(var prm_Entradas: Codeunit "Gestion Entradas SGA"; var prm_Buffer: Record "Linea Ubicacion SGA" temporary; prm_Origen: Enum "Origen Mov. SGA"; prm_Almacen: Code[10]; var prm_Lote: Record "Buffer Conciliacion SGA" temporary): Decimal
    var
        total: Decimal;
    begin
        prm_Entradas.CargarEntradasLote(prm_Buffer, prm_Origen, prm_Almacen, prm_Lote."No. Producto", prm_Lote."No. Lote");
        prm_Buffer.Reset();
        if prm_Buffer.FindSet() then
            repeat
                total += prm_Buffer.Pendiente() * cUM.FactorUM(prm_Buffer."No. Producto", prm_Buffer."Cod. Unidad Medida");
            until prm_Buffer.Next() = 0;
        exit(total);
    end;

    /// <summary>
    /// Lo que queda por ubicar de un producto (y lote, si viene) en un almacén, en unidad base:
    /// la suma de "A Ubicar" de sus lotes, con la misma regla que "Pendiente de ubicar"
    /// (CalcularPendienteLote, con la "Fecha inicio SGA"). Un lote al que le sobra no resta a
    /// los que les falta.
    ///
    /// Devuelve también el stock y lo ya ubicado por referencia, porque un pendiente a cero
    /// no dice si es que no hay stock o si es que ya está todo colocado.
    /// </summary>
    procedure PendienteDeUbicar(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50]; var prm_StockBase: Decimal; var prm_UbicadoBase: Decimal) pendiente: Decimal
    var
        TempStock: Record "Buffer Conciliacion SGA" temporary;
        TempEntradas: Record "Linea Ubicacion SGA" temporary;
        rConfig: Record "Config. SGA";
        cEntradas: Codeunit "Gestion Entradas SGA";
    begin
        prm_StockBase := 0;
        prm_UbicadoBase := 0;

        AcumularStockPorLote(prm_Producto, prm_Almacen, TempStock);
        AcumularContenidoUbicado(prm_Producto, prm_Almacen, TempStock);
        // Sin lotes de BC, el stock de BC no lleva lote aunque SGA guarde el del ensamblado: se
        // mira el total del producto, como en la conciliación.
        if (prm_Lote <> '') and LoteEstandar(prm_Producto) then
            TempStock.SetRange("No. Lote", prm_Lote);

        rConfig.ObtenerConfig();
        if TempStock.FindSet() then
            repeat
                prm_StockBase += TempStock."Stock BC";
                prm_UbicadoBase += TempStock."Stock SGA";
                if CalcularPendienteLote(cEntradas, TempEntradas, prm_Almacen, rConfig."Fecha Inicio SGA", TempStock) then
                    pendiente += TempStock."A Ubicar";
            until TempStock.Next() = 0;
    end;

    /// <summary>
    /// Dónde está un producto: abre "Consulta Ubic. Producto SGA" con los filtros que vengan
    /// informados.
    /// </summary>
    procedure ConsultarUbicacionesProducto(prm_Producto: Code[20]; prm_Almacen: Code[10]; prm_Lote: Code[50])
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        // La página recoge estos filtros en su OnOpenPage, así que se le pasan puestos.
        if prm_Producto <> '' then
            rContenido.SetRange("No. Producto", prm_Producto);
        if prm_Almacen <> '' then
            rContenido.SetRange("Cod. Almacen", prm_Almacen);
        if prm_Lote <> '' then
            rContenido.SetRange("No. Lote", prm_Lote);

        Page.Run(Page::"Consulta Ubic. Producto SGA", rContenido);
    end;

    /// <summary>
    /// Caducidad de un lote, con el estándar (ExistingExpirationDate de "Item Tracking
    /// Management"): la de su última entrada en el producto. Es la fecha que se
    /// guarda en el contenido y en los movimientos al ubicar, y la que enseña "Pendiente de ubicar".
    /// Se lee una vez por producto y lote en cada instancia: todos los palés de un lote llevan
    /// la misma.
    /// </summary>
    procedure CaducidadLote(prm_Producto: Code[20]; prm_Lote: Code[50]) caducidad: Date
    var
        TempItemTrackingSetup: Record "Item Tracking Setup" temporary;
        cItemTrackingMgt: Codeunit "Item Tracking Management";
        clave: Text;
        existenMovs: Boolean;
    begin
        if prm_Lote = '' then
            exit(0D);

        clave := prm_Producto + '|' + prm_Lote;
        if CaducidadesLeidas.Get(clave, caducidad) then
            exit(caducidad);
        TempItemTrackingSetup."Lot No." := prm_Lote;
        caducidad := cItemTrackingMgt.ExistingExpirationDate(prm_Producto, '', TempItemTrackingSetup, false, existenMovs);
        CaducidadesLeidas.Add(clave, caducidad);
    end;

    /// <summary>
    /// Si el producto lleva lotes con el seguimiento estándar de BC: código de seguimiento con
    /// "Seguim. específico lote". Decide de dónde sale el lote en todo SGA: con él, del
    /// seguimiento de BC (y el picking lo escribe en el pedido); sin él, del lote propio del
    /// ensamblado, y al pedido no se le pone seguimiento.
    /// </summary>
    procedure LoteEstandar(prm_Producto: Code[20]) conLote: Boolean
    var
        rItem: Record Item;
        rCodigoSeguimiento: Record "Item Tracking Code";
    begin
        // Una vez por producto en cada instancia.
        if LotesEstandar.Get(prm_Producto, conLote) then
            exit(conLote);

        rItem.SetLoadFields("Item Tracking Code");
        if rItem.Get(prm_Producto) then
            if rItem."Item Tracking Code" <> '' then begin
                rCodigoSeguimiento.SetLoadFields("Lot Specific Tracking");
                if rCodigoSeguimiento.Get(rItem."Item Tracking Code") then
                    conLote := rCodigoSeguimiento."Lot Specific Tracking";
            end;
        LotesEstandar.Add(prm_Producto, conLote);
    end;

    var
        // Una instancia para todo el proceso: guarda lo leído de cada producto.
        cUM: Codeunit "Unidades Producto SGA";
        // Lo ya leído en LoteEstandar: si cada producto lleva lote de BC.
        LotesEstandar: Dictionary of [Code[20], Boolean];
        // Lo ya leído en CaducidadLote, por "producto|lote".
        CaducidadesLeidas: Dictionary of [Text, Date];
}
