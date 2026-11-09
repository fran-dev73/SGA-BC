namespace AntonioNadal.SGA;

/// <summary>
/// Page Ordenes Picking SGA (ID 51118).
/// Lista de órdenes de trabajo de almacén: qué hay que preparar, quién lo prepara y cuánto
/// le queda. Desde aquí se entra a la pantalla del preparador.
/// </summary>
page 51118 "Ordenes Picking SGA"
{
    Caption = 'Órdenes de picking SGA';
    PageType = List;
    SourceTable = "Orden Picking SGA";
    UsageCategory = Lists;
    ApplicationArea = All;
    CardPageId = "Ficha Orden Picking SGA";
    InsertAllowed = false;
    Editable = false;
    SourceTableView = sorting("No. Orden") order(descending);

    layout
    {
        area(Content)
        {
            repeater(Ordenes)
            {
                field("No. Orden"; Rec."No. Orden")
                {
                    ToolTip = 'Número de la orden de picking.';
                    ApplicationArea = All;
                }
                field(Origen; Rec.Origen)
                {
                    ApplicationArea = All;
                }
                field("No. Documento Origen"; Rec."No. Documento Origen")
                {
                    ToolTip = 'Documento que hay que preparar.';
                    ApplicationArea = All;
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
                }
                field(Estado; Rec.Estado)
                {
                    ToolTip = 'Situación de la orden.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field("Cod. Usuario Asignado"; Rec."Cod. Usuario Asignado")
                {
                    ToolTip = 'Preparador que tiene asignada la orden.';
                    ApplicationArea = All;
                }
                field("No. Lineas"; Rec."No. Lineas")
                {
                    ToolTip = 'Número de paradas del recorrido.';
                    ApplicationArea = All;
                }
                field("Lineas Pendientes"; Rec."Lineas Pendientes")
                {
                    ToolTip = 'Paradas que quedan por recoger.';
                    ApplicationArea = All;
                }
                field("Fecha Creacion"; Rec."Fecha Creacion")
                {
                    ToolTip = 'Momento en que se creó la orden.';
                    ApplicationArea = All;
                }
                field("Fecha Finalizacion"; Rec."Fecha Finalizacion")
                {
                    ToolTip = 'Momento en que se terminó de preparar.';
                    ApplicationArea = All;
                }
                field("Fecha Paso a Documento"; Rec."Fecha Paso a Documento")
                {
                    ToolTip = 'Última vez que lo recogido se pasó al pedido de venta. En blanco en una orden finalizada: hay que pasarla a mano.';
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SiguienteOrden)
            {
                Caption = 'Siguiente orden';
                ToolTip = 'Abre la pantalla de preparación con la siguiente orden que le toca, por prioridad: primero las suyas sin terminar. Si la configuración no exige asignación y no tiene ninguna, coge la siguiente sin asignar. Al terminar una orden pasa sola a la siguiente.';
                ApplicationArea = All;
                Image = NextRecord;
                RunObject = page "Preparar Picking SGA";
            }
            action(Preparar)
            {
                Caption = 'Preparar';
                ToolTip = 'Abre la pantalla que guía al preparador parada a parada. Con asignación exigida, solo para el preparador asignado; si no, la orden pasa a ser suya.';
                ApplicationArea = All;
                Image = Warehouse;

                trigger OnAction()
                var
                    cPicking: Codeunit "Gestion Picking SGA";
                begin
                    cPicking.AbrirPreparacion(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(SegundaRonda)
            {
                Caption = 'Segunda ronda de picking';
                ToolTip = 'Crea una orden con lo que falta para cada pedido lanzado que ya pasó por picking, no tiene orden abierta y ahora sí tiene stock ubicado de lo que le faltaba. Los que siguen sin stock esperan a la siguiente ronda.';
                ApplicationArea = All;
                Image = Reuse;

                trigger OnAction()
                var
                    cPicking: Codeunit "Gestion Picking SGA";
                begin
                    Message(cPicking.SegundaRonda());
                    CurrPage.Update(false);
                end;
            }
            action(MisOrdenes)
            {
                Caption = 'Mis órdenes';
                ToolTip = 'Muestra solo las órdenes pendientes asignadas a usted.';
                ApplicationArea = All;
                Image = User;

                trigger OnAction()
                var
                    cPicking: Codeunit "Gestion Picking SGA";
                begin
                    Rec.SetRange("Cod. Usuario Asignado", cPicking.UsuarioActual());
                    Rec.SetFilter(Estado, '%1|%2', Rec.Estado::Abierta, Rec.Estado::"En Proceso");
                    Rec.SetCurrentKey(Estado, Prioridad, "No. Orden");
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
            action(Asignarme)
            {
                Caption = 'Asignármela';
                ToolTip = 'Se pone como preparador de esta orden. No está disponible si la configuración exige asignación: entonces reparte el responsable.';
                ApplicationArea = All;
                Image = User;
                Visible = not ExigeAsignacion;

                trigger OnAction()
                var
                    cPicking: Codeunit "Gestion Picking SGA";
                begin
                    cPicking.AsignarOrden(Rec, cPicking.UsuarioActual());
                    CurrPage.Update(false);
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
                ToolTip = 'Diario de movimientos generados al preparar este documento. Es la trazabilidad de qué salió de qué ubicación.';
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

                actionref(SiguienteOrden_Promoted; SiguienteOrden)
                {
                }
                actionref(Preparar_Promoted; Preparar)
                {
                }
                actionref(SegundaRonda_Promoted; SegundaRonda)
                {
                }
                actionref(MisOrdenes_Promoted; MisOrdenes)
                {
                }
                actionref(Asignarme_Promoted; Asignarme)
                {
                }
                actionref(PasarAPedido_Promoted; PasarAPedido)
                {
                }
            }
        }
    }

    views
    {
        view(Pendientes)
        {
            Caption = 'Pendientes';
            Filters = where(Estado = filter("Pendiente Asignar" | Abierta | "En Proceso"));
        }
        view(SinAsignar)
        {
            Caption = 'Sin asignar';
            Filters = where(Estado = filter("Pendiente Asignar" | Abierta | "En Proceso"), "Cod. Usuario Asignado" = const(''));
        }
        view(SinPasarAlPedido)
        {
            Caption = 'Terminadas sin pasar al pedido';
            Filters = where(Estado = const(Finalizada), "Fecha Paso a Documento" = const(0DT));
        }
    }

    var
        EstiloFila: Text;
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
        EstiloFila := Rec.EstiloEstado();
    end;
}
