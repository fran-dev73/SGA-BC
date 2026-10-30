namespace AntonioNadal.SGA;

using Microsoft.Inventory.Location;

/// <summary>
/// PageExtension Location Card SGA (ID 51102) extends Page "Location Card".
/// Añade a la ficha de almacén los accesos a sus ubicaciones, su mapa y sus zonas.
/// </summary>
pageextension 51102 "Location Card SGA" extends "Location Card"
{
    actions
    {
        addlast(processing)
        {
            group(SGA)
            {
                Caption = 'SGA';
                Image = Warehouse;

                action(UbicacionesSGA)
                {
                    Caption = 'Ubicaciones SGA';
                    ToolTip = 'Ubicaciones de este almacén, con su estado y su ocupación.';
                    ApplicationArea = All;
                    Image = BinContent;
                    RunObject = page "Ubicaciones SGA";
                    RunPageLink = "Cod. Almacen" = field(Code);
                }
                action(ZonasSGA)
                {
                    Caption = 'Zonas SGA';
                    ToolTip = 'Zonas definidas en este almacén.';
                    ApplicationArea = All;
                    Image = Warehouse;
                    RunObject = page "Zonas SGA";
                    RunPageLink = "Cod. Almacen" = field(Code);
                }
                action(ContenidoSGA)
                {
                    Caption = 'Contenido de ubicaciones';
                    ToolTip = 'Qué producto y lote hay en cada ubicación de este almacén.';
                    ApplicationArea = All;
                    Image = ItemLines;
                    RunObject = page "Contenido Ubicaciones SGA";
                    RunPageLink = "Cod. Almacen" = field(Code);
                }
                action(MapaSGA)
                {
                    Caption = 'Mapa de almacén';
                    ToolTip = 'Rejilla de la nave con el estado de ocupación de cada hueco.';
                    ApplicationArea = All;
                    Image = Map;
                    RunObject = page "Mapa Almacen SGA";
                }
            }
        }
    }
}
