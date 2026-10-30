namespace AntonioNadal.SGA;

using Microsoft.Sales.Document;

/// <summary>
/// PageExtension Sales Order Subform SGA (ID 51107) extends Page "Sales Order Subform".
/// Enseña en las líneas del pedido la cantidad ya preparada en SGA, delante de la cantidad a
/// enviar, que se rellena después de la preparación.
/// </summary>
pageextension 51107 "Sales Order Subform SGA" extends "Sales Order Subform"
{
    layout
    {
        addbefore("Qty. to Ship")
        {
            field("Cantidad Preparada SGA"; Rec."Cantidad Preparada SGA")
            {
                ApplicationArea = All;
            }
        }
    }
}
