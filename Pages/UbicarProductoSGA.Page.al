namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;

/// <summary>
/// Page Ubicar Producto SGA (ID 51117).
/// Ubicación guiada: el operario dice qué producto trae, el sistema le propone dónde
/// dejarlo según la estrategia configurada, y al confirmar queda registrado en el contenido
/// de la ubicación y en el diario de movimientos.
///
/// No tiene tabla de origen porque es un formulario de captura: lo que persiste lo escribe
/// Cod. "Gestion Contenido SGA", que es la única puerta de escritura del módulo.
/// </summary>
page 51117 "Ubicar Producto SGA"
{
    Caption = 'Ubicar producto SGA';
    PageType = Card;
    UsageCategory = Tasks;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    SaveValues = false;

    layout
    {
        area(Content)
        {
            group(Mercancia)
            {
                Caption = 'Qué se ubica';

                field(Almacen; Almacen)
                {
                    Caption = 'Almacén';
                    ToolTip = 'Almacén en el que se ubica la mercancía.';
                    ApplicationArea = All;
                    TableRelation = Location;
                    ShowMandatory = true;

                    trigger OnValidate()
                    begin
                        RecalcularPendiente();
                        LimpiarPropuesta();
                    end;
                }
                field(Producto; Producto)
                {
                    Caption = 'Producto';
                    ToolTip = 'Producto que se va a dejar en la ubicación.';
                    ApplicationArea = All;
                    TableRelation = Item;
                    ShowMandatory = true;

                    trigger OnValidate()
                    begin
                        CargarProducto();
                        RecalcularPendiente();
                        LimpiarPropuesta();
                    end;
                }
                field(DescripcionProducto; DescripcionProducto)
                {
                    Caption = 'Descripción';
                    ToolTip = 'Descripción del producto seleccionado.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Variante; Variante)
                {
                    Caption = 'Variante';
                    ToolTip = 'Variante del producto, si la maneja.';
                    ApplicationArea = All;
                    TableRelation = "Item Variant".Code;

                    trigger OnValidate()
                    var
                        rVariante: Record "Item Variant";
                        VarianteNoDelProductoErr: Label 'La variante %1 no es del producto %2.', Comment = '%1 = variante, %2 = producto';
                    begin
                        // El filtro por producto no cabe en el TableRelation porque la página
                        // no tiene tabla de origen, así que se comprueba aquí.
                        if (Variante <> '') and (Producto <> '') then
                            if not rVariante.Get(Producto, Variante) then
                                Error(VarianteNoDelProductoErr, Variante, Producto);
                        RecalcularPendiente();
                        LimpiarPropuesta();
                    end;
                }
                field(Lote; Lote)
                {
                    Caption = 'Lote';
                    ToolTip = 'Lote de la mercancía. Determina con qué se puede mezclar en la ubicación.';
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        RecalcularPendiente();
                        LimpiarPropuesta();
                    end;
                }
                field(UM; UM)
                {
                    Caption = 'Unidad de medida';
                    ToolTip = 'Unidad en la que se expresa la cantidad. Solo las unidades de medida del producto seleccionado.';
                    ApplicationArea = All;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        rUM: Record "Item Unit of Measure";
                        pUM: Page "Item Units of Measure";
                        SeleccioneProductoErr: Label 'Seleccione primero un producto.';
                    begin
                        if Producto = '' then
                            Error(SeleccioneProductoErr);

                        rUM.SetRange("Item No.", Producto);
                        pUM.SetTableView(rUM);
                        pUM.LookupMode(true);
                        if pUM.RunModal() = Action::LookupOK then begin
                            pUM.GetRecord(rUM);
                            UM := rUM.Code;
                        end;
                        exit(true);
                    end;

                    trigger OnValidate()
                    begin
                        if (UM <> '') and (Producto <> '') then
                            cUM.TestUMProducto(Producto, UM);
                        RecalcularPendiente();
                    end;
                }
                field(PendienteUbicar; PendienteUbicar)
                {
                    Caption = 'Pendiente de ubicar';
                    ToolTip = 'Cantidad que queda por colocar, en la unidad de medida elegida: lo que hay en el almacén según Business Central menos lo que SGA ya tiene repartido en ubicaciones.';
                    ApplicationArea = All;
                    Editable = false;
                    DecimalPlaces = 0 : 5;
                    Style = Strong;
                }
                field(DesglosePendiente; DesglosePendiente)
                {
                    Caption = 'Equivale a';
                    ToolTip = 'Lo pendiente repartido en palé por defecto, unidad de venta y unidad base. Por ejemplo, 690 botellas con palé de 540 y CAJA12 son 1 palé, 12 CAJA12 y 6 botellas.';
                    ApplicationArea = All;
                    Editable = false;
                    Style = StrongAccent;
                }
                field(DetalleDisponible; DetalleDisponible)
                {
                    Caption = 'Detalle';
                    ToolTip = 'De dónde sale el pendiente: existencias en el almacén y cantidad ya ubicada.';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Subordinate;
                }
                field(Cantidad; Cantidad)
                {
                    Caption = 'Cantidad a ubicar';
                    ToolTip = 'Cuántas unidades de la medida elegida se van a dejar. Si la unidad es el palé, aquí van palés.';
                    ApplicationArea = All;
                    MinValue = 0;
                    ShowMandatory = true;

                    trigger OnValidate()
                    begin
                        CalcularEquivalencia();
                        LimpiarPropuesta();
                    end;
                }
                field(EquivaleBase; EquivaleBase)
                {
                    Caption = 'Son en total';
                    ToolTip = 'A cuánto equivale la cantidad indicada en la unidad base del producto.';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Subordinate;
                }
            }
            part(Plan; "Plan Ubicacion SGA Subpag")
            {
                Caption = 'Dónde dejarlo';
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(UsarPendiente)
            {
                Caption = 'Ubicar todo lo pendiente';
                ToolTip = 'Pone como cantidad todo lo que queda por ubicar del producto y lo reparte: cada palé a un hueco y el resto junto a otro, primero en almacenamiento y luego en picking.';
                ApplicationArea = All;
                Image = AllLines;

                trigger OnAction()
                var
                    NadaPendienteErr: Label 'No queda nada pendiente de ubicar de este producto en el almacén.';
                begin
                    if PendienteUbicar <= 0 then
                        Error(NadaPendienteErr);
                    Cantidad := PendienteUbicar;
                    CalcularEquivalencia();
                    CalcularPropuesta();
                end;
            }
            action(Proponer)
            {
                Caption = 'Proponer ubicación';
                ToolTip = 'Reparte la cantidad en palés, unidades de venta y unidades sueltas, y propone un hueco para cada parte. El resultado sale en la tabla "Dónde dejarlo".';
                ApplicationArea = All;
                Image = Suggest;

                trigger OnAction()
                begin
                    CalcularPropuesta();
                end;
            }
            action(ConfirmarTodo)
            {
                Caption = 'Confirmar todo';
                ToolTip = 'Registra todas las líneas de la tabla que tienen ubicación confirmada. Las que no tienen sitio se quedan como están.';
                ApplicationArea = All;
                Image = Approve;

                trigger OnAction()
                begin
                    ConfirmarLineas(0);
                end;
            }
            action(ConfirmarLinea)
            {
                Caption = 'Confirmar esta línea';
                ToolTip = 'Registra solo la línea seleccionada de la tabla.';
                ApplicationArea = All;
                Image = Approve;

                trigger OnAction()
                var
                    SeleccioneLineaErr: Label 'Seleccione una línea de la tabla.';
                begin
                    if CurrPage.Plan.Page.LineaActual() = 0 then
                        Error(SeleccioneLineaErr);
                    ConfirmarLineas(CurrPage.Plan.Page.LineaActual());
                end;
            }
            action(VerContenido)
            {
                Caption = 'Ver contenido de la ubicación';
                ToolTip = 'Muestra qué hay ahora mismo en la ubicación de la línea seleccionada.';
                ApplicationArea = All;
                Image = BinContent;

                trigger OnAction()
                var
                    cContenido: Codeunit "Gestion Contenido SGA";
                begin
                    TempPlan.Reset();
                    if not TempPlan.Get(CurrPage.Plan.Page.LineaActual()) then
                        exit;
                    cContenido.MostrarContenidoUbicacion(Almacen, TempPlan."Ubicacion Confirmada");
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(UsarPendiente_Promoted; UsarPendiente)
                {
                }
                actionref(Proponer_Promoted; Proponer)
                {
                }
                actionref(ConfirmarTodo_Promoted; ConfirmarTodo)
                {
                }
                actionref(ConfirmarLinea_Promoted; ConfirmarLinea)
                {
                }
            }
        }
    }

    var
        TempPlan: Record "Linea Ubicacion SGA";
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        cUM: Codeunit "Unidades Producto SGA";
        Almacen: Code[10];
        Producto: Code[20];
        DescripcionProducto: Text[100];
        Variante: Code[10];
        Lote: Code[50];
        UM: Code[10];
        Cantidad: Decimal;
        PendienteUbicar: Decimal;
        DetalleDisponible: Text;
        DesglosePendiente: Text;
        EquivaleBase: Text;
        Preparada: Boolean;
        CantidadPreparada: Decimal;

    trigger OnOpenPage()
    var
        rConfig: Record "Config. SGA";
    begin
        if Preparada then begin
            // Viene con los datos puestos (desde "Pendiente de ubicar"): se respetan.
            CargarProducto();
            UM := cUM.UMBase(Producto);
            Cantidad := CantidadPreparada;
            RecalcularPendiente();
        end else begin
            rConfig.ObtenerConfig();
            Almacen := rConfig."Almacen por Defecto";
        end;
        CurrPage.Plan.Page.Cargar(TempPlan);
    end;

    /// <summary>
    /// Abre la página con lo que hay que ubicar ya indicado: almacén, producto, variante, lote,
    /// caducidad y cantidad en unidad base. El operario solo tiene que pulsar "Proponer".
    /// </summary>
    procedure Preparar(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_CantidadBase: Decimal)
    begin
        Almacen := prm_Almacen;
        Producto := prm_Producto;
        Variante := prm_Variante;
        Lote := prm_Lote;
        CantidadPreparada := prm_CantidadBase;
        Preparada := true;
    end;

    local procedure CargarProducto()
    var
        rItem: Record Item;
    begin
        DescripcionProducto := '';
        UM := '';

        if Producto = '' then
            exit;

        if not rItem.Get(Producto) then
            exit;

        DescripcionProducto := CopyStr(rItem.Description, 1, MaxStrLen(DescripcionProducto));
        UM := rItem."Base Unit of Measure";
    end;

    /// <summary>
    /// Recalcula cuánto queda por ubicar y lo expresa en la unidad de medida elegida.
    /// Sin esto el operario no sabe cuánta mercancía le queda por colocar.
    /// </summary>
    local procedure RecalcularPendiente()
    var
        cStock: Codeunit "Consulta Stock SGA";
        stockBase: Decimal;
        ubicadoBase: Decimal;
        pendienteBase: Decimal;
        DetallePendienteLbl: Label '%1 en el almacén, %2 ya ubicado (en %3).', Comment = '%1 = stock, %2 = ubicado, %3 = unidad base';
    begin
        PendienteUbicar := 0;
        DetalleDisponible := '';
        DesglosePendiente := '';

        if (Producto = '') or (Almacen = '') then
            exit;

        pendienteBase := cStock.PendienteDeUbicar(Almacen, Producto, Variante, Lote, stockBase, ubicadoBase);

        // El cálculo va en unidad base; se pasa a la UM elegida con su factor de conversión.
        PendienteUbicar := Round(pendienteBase / cUM.FactorUM(Producto, UM), 0.00001);
        DetalleDisponible := StrSubstNo(DetallePendienteLbl, stockBase, ubicadoBase, cUM.UMBase(Producto));
        DesglosePendiente := cUM.Desglose(Producto, pendienteBase);
        CalcularEquivalencia();
    end;

    /// <summary>
    /// Dice a cuánto equivale en unidad base lo que se ha tecleado en la unidad elegida.
    /// </summary>
    local procedure CalcularEquivalencia()
    var
        cantidadBase: Decimal;
        EquivalenciaLbl: Label '%1 %2 (%3)', Comment = '%1 = cantidad en unidad base, %2 = unidad base, %3 = desglose';
    begin
        EquivaleBase := '';

        if (Producto = '') or (Cantidad <= 0) then
            exit;

        cantidadBase := Round(Cantidad * cUM.FactorUM(Producto, UM), 0.00001);
        EquivaleBase := StrSubstNo(EquivalenciaLbl, cantidadBase, cUM.UMBase(Producto), cUM.Desglose(Producto, cantidadBase));
    end;

    local procedure LimpiarPropuesta()
    begin
        TempPlan.Reset();
        TempPlan.DeleteAll();
        CurrPage.Plan.Page.Cargar(TempPlan);
    end;

    /// <summary>
    /// Proponer: el reparto y el hueco de cada parte los decide ProponerReparto de "Gestion
    /// Ubicaciones SGA"; aquí se enseña el resultado. Si sale una sola línea con hueco, se
    /// pregunta directamente si ubicarla.
    /// </summary>
    local procedure CalcularPropuesta()
    var
        rConfig: Record "Config. SGA";
        DatosIncompletosErr: Label 'Indique almacén, producto y cantidad antes de proponer una ubicación.';
        UbicarLineaQst: Label '¿Ubicar %1 %2 de %3 en %4?', Comment = '%1 = cantidad, %2 = unidad, %3 = producto, %4 = ubicación';
    begin
        if (Almacen = '') or (Producto = '') or (Cantidad <= 0) then
            Error(DatosIncompletosErr);

        rConfig.ObtenerConfig();
        cUbicaciones.ProponerReparto(rConfig."Estrategia Ubicacion", Almacen, Producto, Variante, Lote,
                                     Round(Cantidad * cUM.FactorUM(Producto, UM), 0.00001), TempPlan);

        CurrPage.Plan.Page.Cargar(TempPlan);
        CurrPage.Update(false);

        // Una sola línea con hueco: no hace falta tabla para decidir.
        TempPlan.Reset();
        if TempPlan.Count() = 1 then begin
            TempPlan.FindFirst();
            if TempPlan.Estado = TempPlan.Estado::Pendiente then
                if Confirm(UbicarLineaQst, true, TempPlan.Cantidad, TempPlan."Cod. Unidad Medida", Producto, TempPlan."Ubicacion Propuesta") then
                    ConfirmarLineas(TempPlan.Linea);
        end;
    end;

    /// <summary>
    /// Registra las líneas de la tabla (todas con prm_Linea = 0, o solo una) con ConfirmarReparto
    /// de "Gestion Ubicaciones SGA". Lo que queda sin ubicar pasa a ser la cantidad, en unidad
    /// base, para volver a proponerlo cuando haya sitio; la tabla se queda a la vista.
    /// </summary>
    local procedure ConfirmarLineas(prm_Linea: Integer)
    var
        restoBase: Decimal;
    begin
        restoBase := cUbicaciones.ConfirmarReparto(TempPlan, prm_Linea, Almacen, Producto, Variante, Lote);

        UM := cUM.UMBase(Producto);
        Cantidad := restoBase;
        RecalcularPendiente();
        CurrPage.Plan.Page.Cargar(TempPlan);
        CurrPage.Update(false);
    end;
}
