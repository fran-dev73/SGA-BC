namespace AntonioNadal.SGA;

/// <summary>
/// Page Cue SGA (ID 51111).
/// Indicadores del rol center de almacén: cuántas ubicaciones hay y en qué estado,
/// cuánto contenido está bloqueado o reservado, cómo va el picking y cuántos movimientos ha
/// habido hoy.
/// </summary>
page 51111 "Cue SGA"
{
    Caption = 'Almacén SGA';
    PageType = CardPart;
    SourceTable = "Cue SGA";
    ApplicationArea = All;
    RefreshOnActivate = true;

    layout
    {
        area(Content)
        {
            cuegroup(Picking)
            {
                Caption = 'Picking';

                field("Ordenes Sin Asignar"; Rec."Ordenes Sin Asignar")
                {
                    ToolTip = 'Órdenes de picking que esperan a que el responsable las asigne a un preparador.';
                    ApplicationArea = All;
                    DrillDownPageId = "Asignar Ordenes Picking SGA";
                    Style = Attention;
                }
                field("Ordenes Sin Empezar"; Rec."Ordenes Sin Empezar")
                {
                    ToolTip = 'Órdenes de picking abiertas que nadie ha empezado a recoger.';
                    ApplicationArea = All;
                    DrillDownPageId = "Ordenes Picking SGA";
                }
                field("Ordenes En Proceso"; Rec."Ordenes En Proceso")
                {
                    ToolTip = 'Órdenes de picking que se están recogiendo.';
                    ApplicationArea = All;
                    DrillDownPageId = "Ordenes Picking SGA";
                }
                field("Ordenes Envio Vencido"; Rec."Ordenes Envio Vencido")
                {
                    ToolTip = 'Órdenes de picking sin terminar cuyo pedido tiene la fecha de envío hoy o antes.';
                    ApplicationArea = All;
                    DrillDownPageId = "Ordenes Picking SGA";
                    Style = Unfavorable;
                }
                field("Paradas Retenidas"; Rec."Paradas Retenidas")
                {
                    ToolTip = 'Paradas de picking que el preparador ha saltado dos veces y esperan a que el jefe de almacén las resuelva.';
                    ApplicationArea = All;
                    DrillDownPageId = "Paradas Picking SGA";
                    Style = Unfavorable;
                }
                field("Ordenes Sin Pasar Pedido"; Rec."Ordenes Sin Pasar Pedido")
                {
                    ToolTip = 'Órdenes de venta terminadas cuyo resultado no se ha pasado al pedido. Hay que pasarlas a mano con Pasar al pedido.';
                    ApplicationArea = All;
                    DrillDownPageId = "Ordenes Picking SGA";
                    Style = Unfavorable;
                }
                field("Reubicaciones Pendientes"; Rec."Reubicaciones Pendientes")
                {
                    ToolTip = 'Movimientos de almacenamiento a picking que quedan por hacer.';
                    ApplicationArea = All;
                    DrillDownPageId = "Reubicaciones SGA";
                }
                field("Ordenes Terminadas Hoy"; Rec."Ordenes Terminadas Hoy")
                {
                    ToolTip = 'Órdenes de picking terminadas en la fecha de trabajo.';
                    ApplicationArea = All;
                    DrillDownPageId = "Ordenes Picking SGA";
                    Style = Favorable;
                }
                field("Desvios Hoy"; Rec."Desvios Hoy")
                {
                    ToolTip = 'Paradas confirmadas hoy en una ubicación distinta de la propuesta.';
                    ApplicationArea = All;
                    DrillDownPageId = "Paradas Picking SGA";
                    Style = Ambiguous;
                }
            }
            cuegroup(Ubicaciones)
            {
                Caption = 'Ubicaciones';

                field("Ubicaciones Totales"; Rec."Ubicaciones Totales")
                {
                    ToolTip = 'Total de ubicaciones dadas de alta en SGA.';
                    ApplicationArea = All;
                    DrillDownPageId = "Ubicaciones SGA";
                }
                field("Ubicaciones Vacias"; Rec."Ubicaciones Vacias")
                {
                    ToolTip = 'Ubicaciones sin nada dentro, disponibles para ubicar.';
                    ApplicationArea = All;
                    DrillDownPageId = "Ubicaciones SGA";
                    Style = Favorable;
                }
                field("Ubicaciones Parciales"; Rec."Ubicaciones Parciales")
                {
                    ToolTip = 'Ubicaciones con contenido y hueco todavía disponible.';
                    ApplicationArea = All;
                    DrillDownPageId = "Ubicaciones SGA";
                }
                field("Ubicaciones Llenas"; Rec."Ubicaciones Llenas")
                {
                    ToolTip = 'Ubicaciones que han alcanzado su capacidad declarada.';
                    ApplicationArea = All;
                    DrillDownPageId = "Ubicaciones SGA";
                    Style = Ambiguous;
                }
                field("Ubicaciones Bloqueadas"; Rec."Ubicaciones Bloqueadas")
                {
                    ToolTip = 'Ubicaciones bloqueadas, que no admiten entradas ni se proponen para recoger.';
                    ApplicationArea = All;
                    DrillDownPageId = "Ubicaciones SGA";
                    Style = Unfavorable;
                }
            }
            cuegroup(Contenido)
            {
                Caption = 'Contenido';

                field("Lineas Contenido"; Rec."Lineas Contenido")
                {
                    ToolTip = 'Combinaciones producto-lote-ubicación que hay en el almacén.';
                    ApplicationArea = All;
                    DrillDownPageId = "Contenido Ubicaciones SGA";
                }
                field("Contenido Reservado"; Rec."Contenido Reservado")
                {
                    ToolTip = 'Líneas de contenido con cantidad comprometida por órdenes de picking.';
                    ApplicationArea = All;
                    DrillDownPageId = "Contenido Ubicaciones SGA";
                }
                field("Contenido Bloqueado"; Rec."Contenido Bloqueado")
                {
                    ToolTip = 'Líneas de contenido bloqueadas, que el motor de picking no propone.';
                    ApplicationArea = All;
                    DrillDownPageId = "Contenido Ubicaciones SGA";
                    Style = Unfavorable;
                }
            }

            cuegroup(Actividad)
            {
                Caption = 'Actividad de hoy';

                field("Movimientos Periodo"; Rec."Movimientos Periodo")
                {
                    Caption = 'Movimientos de hoy';
                    ToolTip = 'Movimientos de ubicación registrados en la fecha de trabajo.';
                    ApplicationArea = All;
                    DrillDownPageId = "Movs. Ubicacion SGA";
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.ObtenerCue();
        Rec.FiltrarCue();
    end;
}
