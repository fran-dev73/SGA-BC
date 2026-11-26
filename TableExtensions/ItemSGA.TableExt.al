namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;

/// <summary>
/// TableExtension Item SGA (ID 51101) extends Record "Item".
/// Lo que el producto tiene en ubicaciones de SGA, en unidad base, para verlo al lado de las
/// existencias de BC (Inventory): deben coincidir, y si no, la diferencia está sin ubicar o
/// descuadrada. Los dos campos se filtran igual por almacén ("Location Filter").
///
/// Va en una extensión propia, y no en Tab-Ext50017 "Item", para que el módulo siga siendo
/// autocontenido dentro de su carpeta.
/// </summary>
tableextension 51101 "Item SGA" extends Item
{
    fields
    {
        field(51100; "Stock SGA"; Decimal)
        {
            Caption = 'Existencias SGA';
            ToolTip = 'Lo que hay del producto en ubicaciones de SGA, en la unidad de medida base. Debe coincidir con Inventario; si no, hay stock sin ubicar o un descuadre. Pulse para ver en qué ubicaciones está.';
            FieldClass = FlowField;
            CalcFormula = sum("Contenido Ubicacion SGA"."Cantidad Base" where("No. Producto" = field("No."),
                                                                             "Cod. Almacen" = field("Location Filter")));
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
    }
}
