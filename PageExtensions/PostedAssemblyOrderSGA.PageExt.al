namespace AntonioNadal.SGA;

using Microsoft.Assembly.History;

/// <summary>
/// PageExtension Posted Assembly Order SGA (ID 51106) extends Page "Posted Assembly Order".
/// Añade a la ficha del ensamblado registrado dónde están ahora los palés que lo formaron.
/// </summary>
pageextension 51106 "Posted Assembly Order SGA" extends "Posted Assembly Order"
{
    actions
    {
        addlast(navigation)
        {
            action(PalesSGA)
            {
                Caption = 'Palés SGA';
                ToolTip = 'Muestra en qué ubicaciones están ahora los palés de este ensamblado, también sus cajas sueltas. Los que ya han salido enteros no aparecen.';
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
