namespace AntonioNadal.SGA;

/// <summary>
/// Page Ficha Orden Picking SGA (ID 51119).
/// Cabecera de una orden de picking con sus paradas, para ver de un vistazo qué queda y
/// dónde se ha recogido realmente cada cosa.
/// </summary>
page 51119 "Ficha Orden Picking SGA"
{
    Caption = 'Orden de picking';
    PageType = Document;
    SourceTable = "Orden Picking SGA";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("No. Orden"; Rec."No. Orden")
                {
                    ToolTip = 'Número de la orden de picking.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("No. Documento Origen"; Rec."No. Documento Origen")
                {
                    ToolTip = 'Documento que hay que preparar.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Descripcion; Rec.Descripcion)
                {
                    ToolTip = 'Descripción de la orden.';
                    ApplicationArea = All;
                }
                field("Cod. Almacen"; Rec."Cod. Almacen")
                {
                    ToolTip = 'Almacén en el que se prepara.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Origen; Rec.Origen)
                {
                    ToolTip = 'Flujo del que procede la orden.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Estado; Rec.Estado)
                {
                    ToolTip = 'Situación de la orden.';
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = EstiloOrden;
                }
                field("Cod. Usuario Asignado"; Rec."Cod. Usuario Asignado")
                {
                    ToolTip = 'Preparador que tiene asignada la orden. Si la configuración exige asignación, se cambia en "Asignar órdenes de picking".';
                    ApplicationArea = All;
                    Editable = not ExigeAsignacion;
                }
                field(Prioridad; Rec.Prioridad)
                {
                    ToolTip = 'Cuanto mayor, antes le sale al preparador con "Siguiente orden".';
                    ApplicationArea = All;
                    Editable = not ExigeAsignacion;
                }
                field("Nombre Cliente"; Rec."Nombre Cliente")
                {
                    ToolTip = 'Cliente del pedido de venta.';
                    ApplicationArea = All;
                }
                field("Fecha Envio"; Rec."Fecha Envio")
                {
                    ToolTip = 'Fecha de envío del pedido de venta.';
                    ApplicationArea = All;
                }
            }
            group(Seguimiento)
            {
                Caption = 'Seguimiento';

                field("No. Lineas"; Rec."No. Lineas")
                {
                    ToolTip = 'Número de paradas del recorrido.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Lineas Pendientes"; Rec."Lineas Pendientes")
                {
                    ToolTip = 'Paradas que quedan por recoger.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Fecha Creacion"; Rec."Fecha Creacion")
                {
                    ToolTip = 'Momento en que se creó la orden.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Cod. Usuario Creacion"; Rec."Cod. Usuario Creacion")
                {
                    ToolTip = 'Usuario que creó la orden.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Fecha Finalizacion"; Rec."Fecha Finalizacion")
                {
                    ToolTip = 'Momento en que se terminó de preparar.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Fecha Paso a Documento"; Rec."Fecha Paso a Documento")
                {
                    ToolTip = 'Última vez que lo recogido se pasó al pedido de venta. En blanco en una orden finalizada: hay que pasarla con "Pasar al pedido".';
                    ApplicationArea = All;
                    Editable = false;
                }
            }
            part(Paradas; "Lineas Orden Picking Subpag")
            {
                Caption = 'Paradas';
                ApplicationArea = All;
                SubPageLink = "No. Orden" = field("No. Orden");
                UpdatePropagation = Both;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Preparar)
            {
                Caption = 'Preparar';
                ToolTip = 'Abre la pantalla que guía al preparador parada a parada.';
                ApplicationArea = All;
                Image = Warehouse;

                trigger OnAction()
                var
                    rLinea: Record "Linea Orden Picking SGA";
                    cPicking: Codeunit "Gestion Picking SGA";
                    SinParadasPendientesErr: Label 'La orden %1 no tiene paradas pendientes.', Comment = '%1 = nº orden';
                begin
                    rLinea.SetRange("No. Orden", Rec."No. Orden");
                    rLinea.SetFilter(Estado, '%1|%2', rLinea.Estado::Pendiente, rLinea.Estado::Parcial);
                    if rLinea.IsEmpty() then
                        Error(SinParadasPendientesErr, Rec."No. Orden");

                    CurrPage.SaveRecord();
                    if not cPicking.TomarParaPreparar(Rec) then
                        exit;
                    Commit();

                    Page.Run(Page::"Preparar Picking SGA", rLinea);
                    CurrPage.Update(false);
                end;
            }
            action(PasarAPedido)
            {
                Caption = 'Pasar al pedido';
                ToolTip = 'Rellena en el pedido de venta la cantidad a enviar y los lotes recogidos. Se hace solo al terminar la orden; úselo si entonces falló o para pasar una orden a medias.';
                ApplicationArea = All;
                Image = TransferOrder;

                trigger OnAction()
                var
                    cPicking: Codeunit "Gestion Picking SGA";
                    PickingPasadoMsg: Label 'Lo recogido se ha pasado al pedido %1.', Comment = '%1 = nº pedido';
                begin
                    cPicking.PasarAPedido(Rec);
                    CurrPage.Update(false);
                    Message(PickingPasadoMsg, Rec."No. Documento Origen");
                end;
            }
            action(CancelarOrden)
            {
                Caption = 'Cancelar orden';
                ToolTip = 'Cancela la orden y todas sus paradas pendientes.';
                ApplicationArea = All;
                Image = Cancel;

                trigger OnAction()
                var
                    cPicking: Codeunit "Gestion Picking SGA";
                    CancelarOrdenQst: Label '¿Cancelar la orden %1 y todas sus paradas pendientes?', Comment = '%1 = nº orden';
                begin
                    if not Confirm(CancelarOrdenQst, false, Rec."No. Orden") then
                        exit;
                    cPicking.CancelarOrden(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(MovimientosOrden)
            {
                Caption = 'Movimientos del documento';
                ToolTip = 'Diario de movimientos generados al preparar este documento.';
                ApplicationArea = All;
                Image = Journals;
                RunObject = page "Movs. Ubicacion SGA";
                RunPageLink = "No. Documento Origen" = field("No. Documento Origen");
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(Preparar_Promoted; Preparar)
                {
                }
                actionref(PasarAPedido_Promoted; PasarAPedido)
                {
                }
            }
        }
    }

    var
        EstiloOrden: Text;
        ExigeAsignacion: Boolean;

    trigger OnOpenPage()
    var
        rConfig: Record "Config. SGA";
    begin
        rConfig.ObtenerConfig();
        ExigeAsignacion := rConfig."Exigir Asignacion Picking";
    end;

    trigger OnAfterGetRecord()
    begin
        EstiloOrden := Rec.EstiloEstado();
    end;
}
