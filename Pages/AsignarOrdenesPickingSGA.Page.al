namespace AntonioNadal.SGA;

using Microsoft.Sales.Document;
using System.Security.AccessControl;
using System.Security.User;

/// <summary>
/// Page Asignar Ordenes Picking SGA (ID 51124).
/// Pantalla del responsable de almacén: las órdenes de picking vivas, para repartirlas entre
/// los preparadores y fijar en qué orden se hacen.
///
/// Es el paso intermedio entre "Enviar a picking" y la preparación. Con "Exigir asignación de
/// picking" en la configuración es obligatorio: una orden no se puede preparar hasta que se
/// asigna aquí. Sin ella sirve igual para repartir, pero los preparadores también pueden
/// coger las que estén sin asignar.
///
/// El cambio de estado al asignar (pendiente de asignar / abierta) lo hace la propia tabla al
/// validar "Cod. Usuario Asignado", tanto si se teclea en la línea como si se usa la acción.
/// </summary>
page 51124 "Asignar Ordenes Picking SGA"
{
    Caption = 'Asignar órdenes de picking SGA';
    PageType = List;
    SourceTable = "Orden Picking SGA";
    SourceTableView = sorting(Estado, Prioridad, "No. Orden")
                      where(Estado = filter("Pendiente Asignar" | Abierta | "En Proceso"));
    UsageCategory = Tasks;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;
    AboutTitle = 'Repartir el picking';
    AboutText = 'Seleccione una o varias órdenes y pulse "Asignar a" para dárselas a un preparador. Suba la prioridad de lo urgente: es lo primero que le saldrá con "Siguiente orden".';

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
                    Editable = false;
                    StyleExpr = EstiloFila;
                }
                field(Origen; Rec.Origen)
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("No. Documento Origen"; Rec."No. Documento Origen")
                {
                    ToolTip = 'Pedido de venta que hay que preparar.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Nombre Cliente"; Rec."Nombre Cliente")
                {
                    ToolTip = 'Cliente del pedido.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Fecha Envio"; Rec."Fecha Envio")
                {
                    ToolTip = 'Fecha de envío del pedido. Lo que sale antes, conviene prepararlo antes.';
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = EstiloFecha;
                }
                field(Estado; Rec.Estado)
                {
                    ToolTip = 'Situación de la orden.';
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = EstiloFila;
                }
                field("Cod. Usuario Asignado"; Rec."Cod. Usuario Asignado")
                {
                    ToolTip = 'Preparador al que se asigna. Puede teclearlo aquí o usar "Asignar a" con varias órdenes seleccionadas.';
                    ApplicationArea = All;
                    Style = Strong;
                }
                field(Prioridad; Rec.Prioridad)
                {
                    ToolTip = 'Cuanto mayor, antes le sale al preparador con "Siguiente orden". A igual prioridad, la más antigua primero.';
                    ApplicationArea = All;
                }
                field("No. Lineas"; Rec."No. Lineas")
                {
                    Caption = 'Paradas';
                    ToolTip = 'Número de paradas del recorrido.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Lineas Pendientes"; Rec."Lineas Pendientes")
                {
                    Caption = 'Paradas pendientes';
                    ToolTip = 'Paradas que quedan por recoger.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Cantidad Pendiente"; Rec."Cantidad Pendiente")
                {
                    ToolTip = 'Unidades base que quedan por recoger. Da idea del trabajo que lleva la orden.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Cod. Almacen"; Rec."Cod. Almacen")
                {
                    ToolTip = 'Almacén en el que se prepara.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Fecha Creacion"; Rec."Fecha Creacion")
                {
                    ToolTip = 'Momento en que se envió el pedido a picking.';
                    ApplicationArea = All;
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AsignarA)
            {
                Caption = 'Asignar a';
                ToolTip = 'Asigna las órdenes seleccionadas al preparador que elija.';
                ApplicationArea = All;
                Image = UserSetup;

                trigger OnAction()
                var
                    rUsuario: Record User;
                begin
                    if Page.RunModal(Page::"User Lookup", rUsuario) <> Action::LookupOK then
                        exit;

                    AsignarSeleccion(CopyStr(rUsuario."User Name", 1, MaxStrLen(Rec."Cod. Usuario Asignado")));
                end;
            }
            action(QuitarAsignacion)
            {
                Caption = 'Quitar asignación';
                ToolTip = 'Deja sin preparador las órdenes seleccionadas que no se hayan empezado.';
                ApplicationArea = All;
                Image = RemoveLine;

                trigger OnAction()
                begin
                    AsignarSeleccion('');
                end;
            }
            action(SubirPrioridad)
            {
                Caption = 'Subir prioridad';
                ToolTip = 'Suma uno a la prioridad de las órdenes seleccionadas.';
                ApplicationArea = All;
                Image = MoveUp;

                trigger OnAction()
                begin
                    CambiarPrioridad(1);
                end;
            }
            action(BajarPrioridad)
            {
                Caption = 'Bajar prioridad';
                ToolTip = 'Resta uno a la prioridad de las órdenes seleccionadas, sin bajar de cero.';
                ApplicationArea = All;
                Image = MoveDown;

                trigger OnAction()
                begin
                    CambiarPrioridad(-1);
                end;
            }
        }
        area(Navigation)
        {
            action(VerOrden)
            {
                Caption = 'Ver orden';
                ToolTip = 'Abre la ficha de la orden con sus paradas.';
                ApplicationArea = All;
                Image = Document;
                RunObject = page "Ficha Orden Picking SGA";
                RunPageLink = "No. Orden" = field("No. Orden");
            }
            action(VerPedido)
            {
                Caption = 'Ver pedido';
                ToolTip = 'Abre el pedido de venta de la orden.';
                ApplicationArea = All;
                Image = Order;

                trigger OnAction()
                var
                    rCabVenta: Record "Sales Header";
                begin
                    if rCabVenta.Get(rCabVenta."Document Type"::Order, Rec."No. Documento Origen") then
                        Page.Run(Page::"Sales Order", rCabVenta);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(AsignarA_Promoted; AsignarA)
                {
                }
                actionref(QuitarAsignacion_Promoted; QuitarAsignacion)
                {
                }
                actionref(SubirPrioridad_Promoted; SubirPrioridad)
                {
                }
                actionref(BajarPrioridad_Promoted; BajarPrioridad)
                {
                }
            }
        }
    }

    views
    {
        view(PendientesAsignar)
        {
            Caption = 'Sin asignar';
            Filters = where("Cod. Usuario Asignado" = const(''));
        }
        view(Asignadas)
        {
            Caption = 'Asignadas';
            Filters = where("Cod. Usuario Asignado" = filter(<> ''));
        }
    }

    var
        EstiloFila: Text;
        EstiloFecha: Text;

    trigger OnOpenPage()
    var
        cPicking: Codeunit "Gestion Picking SGA";
    begin
        // Con asignación exigida, la pantalla es solo para responsables: un preparador no debe
        // poder repartirse el trabajo. La tabla lo vuelve a comprobar al asignar.
        cPicking.ComprobarResponsablePicking();
    end;

    trigger OnAfterGetRecord()
    begin
        EstiloFila := Rec.EstiloEstado();
        EstiloFecha := Rec.EstiloFechaEnvio();
    end;

    /// <summary>
    /// Asigna (o desasigna, con prm_Usuario en blanco) todas las órdenes seleccionadas.
    /// </summary>
    local procedure AsignarSeleccion(prm_Usuario: Code[50])
    var
        rOrden: Record "Orden Picking SGA";
        cPicking: Codeunit "Gestion Picking SGA";
        hechas: Integer;
        OrdenesAsignadasMsg: Label 'Se han asignado %1 órdenes a %2.', Comment = '%1 = número, %2 = usuario';
        AsignacionQuitadaMsg: Label 'Se ha quitado la asignación de %1 órdenes.', Comment = '%1 = número';
    begin
        CurrPage.SetSelectionFilter(rOrden);
        hechas := cPicking.AsignarOrdenes(rOrden, prm_Usuario);
        CurrPage.Update(false);

        if prm_Usuario = '' then
            Message(AsignacionQuitadaMsg, hechas)
        else
            Message(OrdenesAsignadasMsg, hechas, prm_Usuario);
    end;

    local procedure CambiarPrioridad(prm_Delta: Integer)
    var
        rOrden: Record "Orden Picking SGA";
        cPicking: Codeunit "Gestion Picking SGA";
    begin
        CurrPage.SetSelectionFilter(rOrden);
        cPicking.CambiarPrioridad(rOrden, prm_Delta);
        CurrPage.Update(false);
    end;
}
