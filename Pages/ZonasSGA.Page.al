namespace AntonioNadal.SGA;

/// <summary>
/// Page Zonas SGA (ID 51105).
/// Mantenimiento de las zonas del almacén y de sus prioridades.
/// </summary>
page 51105 "Zonas SGA"
{
    Caption = 'Zonas SGA';
    PageType = List;
    SourceTable = "Zona SGA";
    UsageCategory = Administration;
    ApplicationArea = All;
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Cod. Almacen"; Rec."Cod. Almacen")
                {
                    ToolTip = 'Almacén al que pertenece la zona.';
                    ApplicationArea = All;
                }
                field(Code; Rec.Code)
                {
                    ToolTip = 'Código de la zona.';
                    ApplicationArea = All;
                }
                field(Descripcion; Rec.Descripcion)
                {
                    ToolTip = 'Descripción de la zona.';
                    ApplicationArea = All;
                }
                field("Tipo Ubicacion"; Rec."Tipo Ubicacion")
                {
                    ToolTip = 'Tipo que se propone por defecto a las ubicaciones de esta zona.';
                    ApplicationArea = All;
                }
                field("Grupo IIEE"; Rec."Grupo IIEE")
                {
                    ApplicationArea = All;
                }
                field("Prioridad Picking"; Rec."Prioridad Picking")
                {
                    ToolTip = 'Secuencia de picking que toma una ubicación al asignarle esta zona, si aún no tiene la suya. Menor valor, antes en el recorrido.';
                    ApplicationArea = All;
                }
                field(Bloqueada; Rec.Bloqueada)
                {
                    ToolTip = 'Impide proponer las ubicaciones de esta zona para ubicar o recoger.';
                    ApplicationArea = All;
                }
                field(Playa; Rec.Playa)
                {
                    ApplicationArea = All;
                }
                field("Ubicacion por Defecto"; Rec."Ubicacion por Defecto")
                {
                    ApplicationArea = All;
                }
                field("No. Ubicaciones"; Rec."No. Ubicaciones")
                {
                    ToolTip = 'Número de ubicaciones asignadas a la zona.';
                    ApplicationArea = All;
                    DrillDown = true;
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(VerUbicaciones)
            {
                Caption = 'Ubicaciones SGA';
                ToolTip = 'Muestra las ubicaciones asignadas a esta zona.';
                ApplicationArea = All;
                Image = BinContent;
                RunObject = page "Ubicaciones SGA";
                RunPageLink = "Cod. Almacen" = field("Cod. Almacen"),
                              "Cod. Zona SGA" = field(Code);
            }
        }
        area(Promoted)
        {
            group(Category_Navigate)
            {
                Caption = 'Zona';

                actionref(VerUbicaciones_Promoted; VerUbicaciones)
                {
                }
            }
        }
    }
}
