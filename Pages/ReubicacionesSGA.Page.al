namespace AntonioNadal.SGA;

/// <summary>
/// Page Reubicaciones SGA (ID 51132).
/// Las reubicaciones de almacenamiento a picking: las paradas de las órdenes de origen
/// Reposicion (las que llevan ubicación destino). Por defecto, las que quedan por hacer.
///
/// Desde aquí se planifican las que falten (Cod. "Reubicaciones SGA".PlanificarAlmacen), se
/// abre la preparación de su orden y se cancelan. Se planifican también solas al vaciar un
/// picking y, si se programa, con la cola de proyectos (Cod. "Reubicaciones SGA").
/// </summary>
page 51132 "Reubicaciones SGA"
{
    Caption = 'Reubicaciones SGA';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Linea Orden Picking SGA";
    SourceTableView = sorting("Cod. Almacen", "Cod. Bin Destino", Estado) where("Cod. Bin Destino" = filter(<> ''));
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lineas)
            {
                field("No. Orden"; Rec."No. Orden")
                {
                    ToolTip = 'Orden de reubicaciones en la que va. Se prepara como un picking.';
                }
                field(Estado; Rec.Estado)
                {
                    ToolTip = 'Si la reubicación está por hacer, a medias, hecha o cancelada.';
                    StyleExpr = EstiloFila;
                }
                field("No. Producto"; Rec."No. Producto")
                {
                    ToolTip = 'Producto que se lleva a picking.';
                }
                field("Descripcion Producto"; Rec."Descripcion Producto")
                {
                    ToolTip = 'Descripción del producto.';
                }
                field("No. Lote"; Rec."No. Lote")
                {
                    ToolTip = 'Lote que se lleva.';
                }
                field(SSCC; Rec.SSCC)
                {
                    ToolTip = 'Palé (SSCC) que se lleva.';
                }
                field("Cod. Bin Propuesto"; Rec."Cod. Bin Propuesto")
                {
                    Caption = 'Desde';
                    ToolTip = 'Ubicación de almacenamiento de la que se coge.';
                }
                field("Cod. Bin Destino"; Rec."Cod. Bin Destino")
                {
                    Caption = 'Hasta';
                    Style = Strong;
                }
                field(PendienteDocumento; Rec.EnUMDocumento(Rec."Cantidad Pendiente"))
                {
                    Caption = 'Pendiente';
                    ToolTip = 'Lo que queda por llevar, en la unidad de la columna Unidad.';
                    DecimalPlaces = 0 : 5;
                }
                field(Unidad; Rec.UMVisible())
                {
                    Caption = 'Unidad';
                    ToolTip = 'El palé si se lleva un palé justo; si no, la unidad base.';
                }
                field("Cantidad a Recoger"; Rec."Cantidad a Recoger")
                {
                    ToolTip = 'Lo que se planificó llevar, en unidades base.';
                    Visible = false;
                }
                field("Cod. Bin Confirmado"; Rec."Cod. Bin Confirmado")
                {
                    ToolTip = 'Ubicación de la que se ha cogido realmente.';
                    Visible = false;
                }
                field("Cod. Usuario Confirmacion"; Rec."Cod. Usuario Confirmacion")
                {
                    ToolTip = 'Quién la ha hecho.';
                }
                field("Fecha Confirmacion"; Rec."Fecha Confirmacion")
                {
                    ToolTip = 'Cuándo se ha hecho.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Planificar)
            {
                Caption = 'Planificar reubicaciones';
                ToolTip = 'Planifica traer de almacenamiento cada producto que no tiene nada en picking y sí en almacenamiento, a su ubicación de picking o a la primera libre.';
                Image = CalculatePlan;

                trigger OnAction()
                var
                    cReubicaciones: Codeunit "Reubicaciones SGA";
                    PlanificadasMsg: Label 'Reubicaciones planificadas: %1.', Comment = '%1 = número';
                begin
                    Message(PlanificadasMsg, cReubicaciones.PlanificarAlmacen());
                    CurrPage.Update(false);
                end;
            }
            action(Preparar)
            {
                Caption = 'Preparar';
                ToolTip = 'Abre la pantalla de preparación con las reubicaciones pendientes de la orden de esta línea.';
                Image = Start;

                trigger OnAction()
                var
                    rOrden: Record "Orden Picking SGA";
                    cPicking: Codeunit "Gestion Picking SGA";
                begin
                    // AbrirPreparacion lee la orden al día: basta con su número.
                    rOrden."No. Orden" := Rec."No. Orden";
                    cPicking.AbrirPreparacion(rOrden);
                end;
            }
            action(Cancelar)
            {
                Caption = 'Cancelar';
                ToolTip = 'Cancela la reubicación y libera el stock que tenía reservado. Lo ya llevado no se deshace.';
                Image = Cancel;

                trigger OnAction()
                var
                    cPicking: Codeunit "Gestion Picking SGA";
                    CancelarQst: Label '¿Cancelar la reubicación de %1 de %2 a %3?', Comment = '%1 = producto, %2 = ubicación origen, %3 = ubicación destino';
                begin
                    if not Confirm(CancelarQst, false, Rec."No. Producto", Rec."Cod. Bin Propuesto", Rec."Cod. Bin Destino") then
                        exit;
                    cPicking.CancelarLinea(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(VerOrden)
            {
                Caption = 'Orden';
                ToolTip = 'Abre la orden de esta reubicación: preparador asignado, prioridad y avance.';
                Image = Document;
                RunObject = page "Ficha Orden Picking SGA";
                RunPageLink = "No. Orden" = field("No. Orden");
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(Planificar_Promoted; Planificar)
                {
                }
                actionref(Preparar_Promoted; Preparar)
                {
                }
                actionref(Cancelar_Promoted; Cancelar)
                {
                }
            }
        }
    }

    views
    {
        view(Pendientes)
        {
            Caption = 'Por hacer';
            Filters = where(Estado = filter(Pendiente | Parcial));
        }
        view(Hechas)
        {
            Caption = 'Hechas';
            Filters = where(Estado = const(Recogida));
        }
    }

    var
        EstiloFila: Text;

    trigger OnAfterGetRecord()
    begin
        EstiloFila := Rec.EstiloEstado();
    end;
}
