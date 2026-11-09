namespace AntonioNadal.SGA;

/// <summary>
/// Page Calculos ABC SGA (ID 51129).
/// Los cálculos ABC guardados, del más reciente al más antiguo. Sirve para ver cómo evoluciona
/// la concentración de ventas y para borrar los que ya no hagan falta (se borran con sus líneas).
/// </summary>
page 51129 "Calculos ABC SGA"
{
    Caption = 'Cálculos ABC SGA';
    PageType = List;
    SourceTable = "Calculo ABC SGA";
    SourceTableView = sorting("No.") order(descending);
    UsageCategory = None;
    ApplicationArea = All;
    InsertAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Calculos)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                }
                field("Fecha Calculo"; Rec."Fecha Calculo")
                {
                    ApplicationArea = All;
                }
                field("Cod. Almacen"; Rec."Cod. Almacen")
                {
                    ApplicationArea = All;
                }
                field("Fecha Desde"; Rec."Fecha Desde")
                {
                    ApplicationArea = All;
                }
                field("Fecha Hasta"; Rec."Fecha Hasta")
                {
                    ApplicationArea = All;
                }
                field(Productos; Rec.Productos)
                {
                    ApplicationArea = All;
                }
                field("% Salidas Top 20"; Rec."% Salidas Top 20")
                {
                    ApplicationArea = All;
                    Style = Strong;
                }
                field("Palets Salidos"; Rec."Palets Salidos")
                {
                    ApplicationArea = All;
                }
                field("Productos A"; Rec."Productos A")
                {
                    ApplicationArea = All;
                }
                field("Productos B"; Rec."Productos B")
                {
                    ApplicationArea = All;
                }
                field("Productos C"; Rec."Productos C")
                {
                    ApplicationArea = All;
                }
                field("Palets en Almacen"; Rec."Palets en Almacen")
                {
                    ApplicationArea = All;
                }
                field(BienUbicados; Rec.PorcentajeBienUbicados())
                {
                    Caption = '% palés en hueco de su clase';
                    ToolTip = 'Qué parte de los palés está en un hueco de su misma clase.';
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 1;
                }
                field(AEnA; Rec.PorcentajeAEnHuecosA())
                {
                    Caption = '% palés A en huecos A';
                    ToolTip = 'Qué parte de los palés A está en los mejores huecos.';
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 1;
                }
                field("Productos Sin UM Pale"; Rec."Productos Sin UM Pale")
                {
                    ApplicationArea = All;
                }
                field(Usuario; Rec.Usuario)
                {
                    ApplicationArea = All;
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(VerClasificacion)
            {
                Caption = 'Ver clasificación';
                ToolTip = 'Abre el análisis de este cálculo, producto a producto.';
                ApplicationArea = All;
                Image = View;

                trigger OnAction()
                var
                    pAnalisis: Page "Analisis ABC SGA";
                begin
                    pAnalisis.FijarCalculo(Rec."No.");
                    pAnalisis.Run();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(VerClasificacion_Promoted; VerClasificacion)
                {
                }
            }
        }
    }
}
