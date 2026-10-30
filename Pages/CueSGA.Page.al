namespace AntonioNadal.SGA;

/// <summary>
/// Page Cue SGA (ID 51111).
/// Indicadores del rol center de almacén: cuántas ubicaciones hay y en qué estado,
/// cuánto contenido está bloqueado o reservado y cuántos movimientos ha habido hoy.
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
    var
        rConfig: Record "Config. SGA";
    begin
        Rec.ObtenerCue();

        rConfig.ObtenerConfig();
        if rConfig."Almacen por Defecto" <> '' then
            Rec.SetFilter("Filtro Almacen", '%1', rConfig."Almacen por Defecto");

        Rec.SetFilter("Filtro Fecha", '%1', WorkDate());
    end;
}
