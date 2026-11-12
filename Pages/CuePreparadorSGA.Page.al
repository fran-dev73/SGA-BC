namespace AntonioNadal.SGA;

/// <summary>
/// Page Cue Preparador SGA (ID 51135).
/// Pilas del rol center del preparador: lo que tiene asignado y lo que puede coger. Usa la
/// misma tabla "Cue SGA" que el rol center de almacén, filtrada por el usuario actual.
/// </summary>
page 51135 "Cue Preparador SGA"
{
    Caption = 'Mi picking SGA';
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

                field("Mis Ordenes"; Rec."Mis Ordenes")
                {
                    ToolTip = 'Órdenes de picking asignadas a usted que quedan por terminar.';
                    ApplicationArea = All;
                    DrillDownPageId = "Ordenes Picking SGA";
                }
                field("Mis Reubicaciones"; Rec."Mis Reubicaciones")
                {
                    ToolTip = 'Reubicaciones asignadas a usted que quedan por terminar.';
                    ApplicationArea = All;
                    DrillDownPageId = "Ordenes Picking SGA";
                }
                field("Ordenes Disponibles"; Rec."Ordenes Disponibles")
                {
                    ToolTip = 'Órdenes de picking sin asignar que puede coger con Preparar pedidos.';
                    ApplicationArea = All;
                    DrillDownPageId = "Ordenes Picking SGA";
                    Visible = not ExigeAsignacion;
                }
            }
        }
    }

    var
        ExigeAsignacion: Boolean;

    trigger OnOpenPage()
    var
        rConfig: Record "Config. SGA";
    begin
        Rec.ObtenerCue();
        Rec.FiltrarCue();

        // Con asignación exigida, el preparador no coge órdenes por su cuenta.
        rConfig.ObtenerConfig();
        ExigeAsignacion := rConfig."Exigir Asignacion Picking";
    end;
}
