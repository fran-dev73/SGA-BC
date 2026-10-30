namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;

/// <summary>
/// PageExtension Item Card SGA (ID 51100) extends Page "Item Card".
/// Añade a la ficha de producto el factbox con las ubicaciones en las que está y el
/// acceso a la consulta de localización.
/// </summary>
pageextension 51100 "Item Card SGA" extends "Item Card"
{
    layout
    {
        addlast(factboxes)
        {
            part(UbicacionesSGAFactBox; "Ubicaciones Producto FactBox")
            {
                Caption = 'Ubicaciones SGA';
                ApplicationArea = All;
                SubPageLink = "No. Producto" = field("No.");
            }
        }
    }

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
                        cStock: Codeunit "Consulta Stock SGA";
                    begin
                        cStock.ConsultarUbicacionesProducto(Rec."No.", '', '', '');
                    end;
                }
                action(MovsUbicacionSGA)
                {
                    Caption = 'Movimientos de ubicación';
                    ToolTip = 'Muestra el histórico de movimientos de ubicación de este producto.';
                    ApplicationArea = All;
                    Image = Entries;
                    RunObject = page "Movs. Ubicacion SGA";
                    RunPageLink = "No. Producto" = field("No.");
                }
            }
        }
    }
}
