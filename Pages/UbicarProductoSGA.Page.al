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
    Caption = 'Ubicar producto';
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
                field(Caducidad; Caducidad)
                {
                    Caption = 'Fecha caducidad';
                    ToolTip = 'Fecha de caducidad del lote. Es la que ordena las salidas por FEFO.';
                    ApplicationArea = All;
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
                ToolTip = 'Pone como cantidad todo lo que queda por ubicar del producto y lo reparte: cada palé a un hueco de palé, las unidades de venta a un hueco de caja y lo que no llega a una unidad de venta, suelto.';
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
                    rContenido: Record "Contenido Ubicacion SGA";
                begin
                    TempPlan.Reset();
                    if not TempPlan.Get(CurrPage.Plan.Page.LineaActual()) then
                        exit;
                    rContenido.SetRange("Cod. Almacen", Almacen);
                    rContenido.SetRange("Cod. Bin", TempPlan."Ubicacion Confirmada");
                    Page.Run(Page::"Contenido Ubicaciones SGA", rContenido);
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
        Caducidad: Date;
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
    procedure Preparar(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_Caducidad: Date; prm_CantidadBase: Decimal)
    begin
        Almacen := prm_Almacen;
        Producto := prm_Producto;
        Variante := prm_Variante;
        Lote := prm_Lote;
        Caducidad := prm_Caducidad;
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

        pendienteBase := cUbicaciones.PendienteDeUbicar(Almacen, Producto, Variante, Lote, stockBase, ubicadoBase);

        // El cálculo va en unidad base; se pasa a la UM elegida con su factor de conversión.
        PendienteUbicar := Round(pendienteBase / cUM.FactorUM(Producto, UM), 0.00001);
        DetalleDisponible := StrSubstNo(DetallePendienteLbl, stockBase, ubicadoBase, cUM.UMBase(Producto));
        DesglosePendiente := Desglosar(pendienteBase);
        CalcularEquivalencia();
    end;

    /// <summary>
    /// Las tres unidades con las que se trabaja: el palé por defecto de la ficha, la unidad de
    /// venta (la caja) y la unidad base. Ninguna otra unidad del producto entra en el reparto.
    /// La de venta solo cuenta si es mayor que la base y menor que el palé; el palé, si es
    /// mayor que la base. Factor 0 = esa unidad no se usa.
    /// </summary>
    local procedure UnidadesJuego(var prm_UMPale: Code[10]; var prm_FactorPale: Decimal; var prm_UMVenta: Code[10]; var prm_FactorVenta: Decimal)
    var
        rItem: Record Item;
        rUM: Record "Item Unit of Measure";
    begin
        prm_UMPale := '';
        prm_FactorPale := 0;
        prm_UMVenta := '';
        prm_FactorVenta := 0;
        if not rItem.Get(Producto) then
            exit;

        if rItem."Cod. Pale por Defecto" <> '' then
            if rUM.Get(Producto, rItem."Cod. Pale por Defecto") then
                if rUM."Qty. per Unit of Measure" > 1 then begin
                    prm_UMPale := rUM.Code;
                    prm_FactorPale := rUM."Qty. per Unit of Measure";
                end;

        if rItem."Sales Unit of Measure" <> '' then
            if rUM.Get(Producto, rItem."Sales Unit of Measure") then
                if (rUM."Qty. per Unit of Measure" > 1) and
                   ((prm_FactorPale = 0) or (rUM."Qty. per Unit of Measure" < prm_FactorPale))
                then begin
                    prm_UMVenta := rUM.Code;
                    prm_FactorVenta := rUM."Qty. per Unit of Measure";
                end;
    end;

    /// <summary>
    /// Reparte una cantidad en unidad base entre palé, unidad de venta y unidad base:
    /// 690 botellas con palé de 540 y CAJA12 son "1 PALE, 12 CAJA12, 6 BOTELLA".
    /// </summary>
    local procedure Desglosar(prm_CantidadBase: Decimal): Text
    var
        umPale: Code[10];
        umVenta: Code[10];
        fp: Decimal;
        fv: Decimal;
        resto: Decimal;
        cuantos: Decimal;
        texto: Text;
    begin
        if (Producto = '') or (prm_CantidadBase <= 0) then
            exit('');

        UnidadesJuego(umPale, fp, umVenta, fv);
        resto := prm_CantidadBase;

        if fp > 0 then begin
            cuantos := Round(resto / fp, 1, '<');
            if cuantos > 0 then begin
                texto := Format(cuantos) + ' ' + umPale;
                resto -= cuantos * fp;
            end;
        end;

        if fv > 0 then begin
            cuantos := Round(resto / fv, 1, '<');
            if cuantos > 0 then begin
                if texto <> '' then
                    texto += ', ';
                texto += Format(cuantos) + ' ' + umVenta;
                resto -= cuantos * fv;
            end;
        end;

        resto := Round(resto, 0.00001);
        if resto > 0 then begin
            if texto <> '' then
                texto += ', ';
            texto += Format(resto) + ' ' + cUM.UMBase(Producto);
        end;

        exit(texto);
    end;

    /// <summary>
    /// Dice a cuánto equivale en unidad base lo que se ha tecleado en la unidad elegida.
    /// </summary>
    local procedure CalcularEquivalencia()
    var
        factor: Decimal;
        EquivalenciaLbl: Label '%1 %2 (%3)', Comment = '%1 = cantidad en unidad base, %2 = unidad base, %3 = desglose';
    begin
        EquivaleBase := '';

        if (Producto = '') or (Cantidad <= 0) then
            exit;

        factor := cUM.FactorUM(Producto, UM);
        EquivaleBase := StrSubstNo(EquivalenciaLbl, Round(Cantidad * factor, 0.00001), cUM.UMBase(Producto),
                                   Desglosar(Round(Cantidad * factor, 0.00001)));
    end;

    local procedure LimpiarPropuesta()
    begin
        TempPlan.Reset();
        TempPlan.DeleteAll();
        CurrPage.Plan.Page.Cargar(TempPlan);
    end;

    /// <summary>
    /// Proponer: reparte la cantidad (cada palé por separado, luego las unidades de venta y al
    /// final lo que no llega a una unidad de venta) y busca hueco para cada parte, sin dar el
    /// mismo hueco a dos. El resultado va a la tabla; lo que no tiene sitio queda marcado con el
    /// motivo. Si sale una sola línea con hueco, se pregunta directamente si ubicarla.
    /// </summary>
    local procedure CalcularPropuesta()
    var
        rConfig: Record "Config. SGA";
        restoBase: Decimal;
        cant: Decimal;
        umPaso: Code[10];
        texto: Text;
        motivo: Text;
        hueco: Code[20];
        excluidas: Text;
        palesTotales: Integer;
        paleActual: Integer;
        umPale: Code[10];
        umVenta: Code[10];
        fp: Decimal;
        fv: Decimal;
        vueltas: Integer;
        DatosIncompletosErr: Label 'Indique almacén, producto y cantidad antes de proponer una ubicación.';
        UbicarLineaQst: Label '¿Ubicar %1 %2 de %3 en %4?', Comment = '%1 = cantidad, %2 = unidad, %3 = producto, %4 = ubicación';
    begin
        if (Almacen = '') or (Producto = '') or (Cantidad <= 0) then
            Error(DatosIncompletosErr);

        rConfig.ObtenerConfig();
        TempPlan.Reset();
        TempPlan.DeleteAll();

        restoBase := Round(Cantidad * cUM.FactorUM(Producto, UM), 0.00001);
        UnidadesJuego(umPale, fp, umVenta, fv);
        if fp > 0 then
            palesTotales := Round(restoBase / fp, 1, '<');

        // Tope de vueltas por si una unidad mal configurada no hiciera bajar el resto.
        vueltas := 0;
        while (restoBase > 0) and (vueltas < 200) do begin
            vueltas += 1;
            DefinirPaso(restoBase, umPale, fp, umVenta, fv, palesTotales, paleActual, umPaso, cant, texto);
            if cant <= 0 then
                break;

            hueco := cUbicaciones.ProponerUbicacionCon(rConfig."Estrategia Ubicacion", excluidas, Almacen, Producto,
                                                       Variante, Lote, umPaso, cant, motivo);

            TempPlan.Init();
            TempPlan.Linea := vueltas;
            TempPlan.Origen := TempPlan.Origen::Manual;
            TempPlan.Paso := CopyStr(texto, 1, MaxStrLen(TempPlan.Paso));
            TempPlan."Cod. Almacen" := Almacen;
            TempPlan."No. Producto" := Producto;
            TempPlan."Descripcion Producto" := DescripcionProducto;
            TempPlan."Cod. Variante" := Variante;
            TempPlan."No. Lote" := Lote;
            TempPlan."Cod. Unidad Medida" := umPaso;
            TempPlan.Cantidad := cant;
            TempPlan."Cantidad Base" := Round(cant * cUM.FactorUM(Producto, umPaso), 0.00001);
            TempPlan."Ubicacion Propuesta" := hueco;
            TempPlan."Ubicacion Confirmada" := hueco;
            // Sin hueco, el motivo ya trae la causa.
            if hueco = '' then
                TempPlan.Estado := TempPlan.Estado::"Sin Sitio"
            else begin
                TempPlan.Estado := TempPlan.Estado::Pendiente;
                excluidas := cUbicaciones.AnadirExclusion(excluidas, hueco);
            end;
            TempPlan.Motivo := CopyStr(motivo, 1, MaxStrLen(TempPlan.Motivo));
            TempPlan.Insert();

            restoBase -= TempPlan."Cantidad Base";
        end;

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
    /// Qué parte toca con lo que queda (en UM base): un palé, las unidades de venta completas o,
    /// si no llega a una unidad de venta, las unidades sueltas.
    /// </summary>
    local procedure DefinirPaso(prm_RestoBase: Decimal; prm_UMPale: Code[10]; prm_FactorPale: Decimal; prm_UMVenta: Code[10]; prm_FactorVenta: Decimal; prm_PalesTotales: Integer; var prm_PaleActual: Integer; var prm_UM: Code[10]; var prm_Cantidad: Decimal; var prm_Texto: Text)
    var
        PaleDeLbl: Label 'Palé %1 de %2', Comment = '%1 = nº de palé, %2 = total';
        UnidadesVentaLbl: Label 'Unidades de venta';
        UnidadesSueltasLbl: Label 'Unidades sueltas';
    begin
        case true of
            (prm_FactorPale > 0) and (prm_RestoBase >= prm_FactorPale):
                begin
                    prm_PaleActual += 1;
                    prm_UM := prm_UMPale;
                    prm_Cantidad := 1;
                    prm_Texto := StrSubstNo(PaleDeLbl, prm_PaleActual, prm_PalesTotales);
                end;
            (prm_FactorVenta > 0) and (prm_RestoBase >= prm_FactorVenta):
                begin
                    prm_UM := prm_UMVenta;
                    prm_Cantidad := Round(prm_RestoBase / prm_FactorVenta, 1, '<');
                    prm_Texto := UnidadesVentaLbl;
                end;
            else begin
                prm_UM := cUM.UMBase(Producto);
                prm_Cantidad := prm_RestoBase;
                prm_Texto := UnidadesSueltasLbl;
            end;
        end;
    end;

    /// <summary>
    /// Registra las líneas de la tabla: todas las que tengan ubicación confirmada y no estén ya
    /// ubicadas (prm_Linea = 0), o solo una. Primero se comprueban todas y luego se registra,
    /// para no dejar el reparto a medias por un error en una línea.
    /// </summary>
    local procedure ConfirmarLineas(prm_Linea: Integer)
    var
        rConfig: Record "Config. SGA";
        cContenido: Codeunit "Gestion Contenido SGA";
        lineas: List of [Integer];
        n: Integer;
        restoBase: Decimal;
        SinLineasConfirmarErr: Label 'No hay ninguna línea con ubicación que confirmar.';
        IndiqueUbicacionErr: Label 'Indique la ubicación de la línea "%1".', Comment = '%1 = qué';
        DesvioNoPermitidoErr: Label 'La configuración no permite desviarse de la ubicación propuesta (%1) en la línea "%2".', Comment = '%1 = ubicación, %2 = qué';
        SinPropuestaErr: Label 'La línea "%1" no tiene ubicación propuesta y la configuración exige proponer antes de confirmar.', Comment = '%1 = qué';
        UbicadoGuiadoLbl: Label 'Ubicado desde la pantalla de ubicación guiada.';
    begin
        rConfig.ObtenerConfig();

        TempPlan.Reset();
        if prm_Linea <> 0 then
            TempPlan.SetRange(Linea, prm_Linea);
        TempPlan.SetFilter(Estado, '<>%1', TempPlan.Estado::Ubicado);
        if TempPlan.FindSet() then
            repeat
                if TempPlan."Ubicacion Confirmada" = '' then begin
                    // Confirmando todo, lo que no tiene sitio se salta; una línea sola, no.
                    if prm_Linea <> 0 then
                        Error(IndiqueUbicacionErr, TempPlan.Paso);
                end else begin
                    cUbicaciones.ComprobarUbicacionExiste(Almacen, TempPlan."Ubicacion Confirmada");
                    if (TempPlan."Ubicacion Propuesta" = '') and rConfig."Exigir Confirmar Ubicacion" then
                        Error(SinPropuestaErr, TempPlan.Paso);
                    if (TempPlan."Ubicacion Propuesta" <> '') and (TempPlan."Ubicacion Confirmada" <> TempPlan."Ubicacion Propuesta") and
                       not rConfig."Permitir Desvio Ubicacion"
                    then
                        Error(DesvioNoPermitidoErr, TempPlan."Ubicacion Propuesta", TempPlan.Paso);
                    lineas.Add(TempPlan.Linea);
                end;
            until TempPlan.Next() = 0;

        if lineas.Count() = 0 then
            Error(SinLineasConfirmarErr);

        TempPlan.Reset();
        foreach n in lineas do begin
            TempPlan.Get(n);
            cContenido.RegistrarEntrada(Almacen, TempPlan."Ubicacion Confirmada", Producto, Variante, Lote,
                                        TempPlan."Cod. Unidad Medida", TempPlan.Cantidad, "Origen Mov. SGA"::Manual, '', 0, UbicadoGuiadoLbl);
            TempPlan.Estado := TempPlan.Estado::Ubicado;
            TempPlan.Motivo := '';
            TempPlan.Modify();
        end;

        // Lo que queda sin ubicar pasa a ser la cantidad, en unidad base, para volver a
        // proponerlo cuando haya sitio. La tabla se queda a la vista con el resultado.
        TempPlan.SetFilter(Estado, '<>%1', TempPlan.Estado::Ubicado);
        TempPlan.CalcSums("Cantidad Base");
        restoBase := TempPlan."Cantidad Base";
        TempPlan.Reset();

        UM := cUM.UMBase(Producto);
        Cantidad := restoBase;
        RecalcularPendiente();
        CurrPage.Plan.Page.Cargar(TempPlan);
        CurrPage.Update(false);
    end;
}
