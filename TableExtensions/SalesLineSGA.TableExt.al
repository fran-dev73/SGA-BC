namespace AntonioNadal.SGA;

using Microsoft.Sales.Document;

/// <summary>
/// TableExtension Sales Line SGA (ID 51102) extends Record "Sales Line".
/// Cantidad preparada en SGA para cada línea de pedido: lo recogido en sus órdenes de picking,
/// en la unidad de medida de la línea.
///
/// No es la cantidad a enviar: esa se rellena al terminar la orden (o con "Pasar picking al
/// pedido"). La preparada se ve mientras se prepara, parada a parada.
///
/// Va en una extensión propia, y no en Tab-Ext50020 "Sales Line", para que el módulo siga
/// siendo autocontenido dentro de su carpeta.
/// </summary>
tableextension 51102 "Sales Line SGA" extends "Sales Line"
{
    fields
    {
        field(51100; "Cantidad Preparada SGA"; Decimal)
        {
            Caption = 'Cantidad preparada';
            ToolTip = 'Lo recogido en las órdenes de picking de SGA para esta línea, en su unidad de medida. La cantidad a enviar se rellena después, al terminar la preparación.';
            FieldClass = FlowField;
            CalcFormula = sum("Linea Orden Picking SGA"."Cantidad Recogida UM Pedido" where("No. Documento Origen" = field("Document No."),
                                                                                            "No. Linea Origen" = field("Line No.")));
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
    }
}
