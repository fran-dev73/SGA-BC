namespace AntonioNadal.SGA;

using Microsoft.Assembly.History;

/// <summary>
/// PageExtension Posted Assembly Orders SGA (ID 51109) extends Page "Posted Assembly Orders".
/// Añade a la lista de ensamblados registrados dónde están ahora los palés que los formaron.
/// </summary>
pageextension 51109 "Posted Assembly Orders SGA" extends "Posted Assembly Orders"
{
    actions
    {
        addlast(navigation)
        {
            action(PalesSGA)
            {
                Caption = 'Palés SGA';
                ToolTip = 'Muestra en qué ubicaciones están ahora los palés del ensamblado seleccionado, también sus cajas sueltas. Los que ya han salido enteros no aparecen.';
                ApplicationArea = All;
                Image = BinContent;

                trigger OnAction()
                var
                    cEntradas: Codeunit "Gestion Entradas SGA";
                begin
                    cEntradas.MostrarPalesEnsamblado(Rec."No.", Rec."Order No.");
                end;
            }
        }
    }
}
