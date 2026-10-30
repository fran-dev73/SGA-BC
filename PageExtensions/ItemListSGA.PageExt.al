namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;

/// <summary>
/// PageExtension Item List SGA (ID 51101) extends Page "Item List".
/// Añade a la lista de productos el acceso directo a "¿dónde está este producto?".
/// </summary>
pageextension 51101 "Item List SGA" extends "Item List"
{
    actions
    {
        addlast(processing)
        {
            group(SGA)
            {
                Caption = 'SGA';
                Image = Warehouse;

                action(DondeEstaSGA)
                {
                    Caption = '¿Dónde está?';
                    ToolTip = 'Muestra en qué ubicaciones está este producto y cuánto hay en cada una.';
                    ApplicationArea = All;
                    Image = BinContent;

                    trigger OnAction()
                    var
                        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
                    begin
                        cUbicaciones.ConsultarUbicacionesProducto(Rec."No.", '', '', '');
                    end;
                }
            }
        }
    }
}
