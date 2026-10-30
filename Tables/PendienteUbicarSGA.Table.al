namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;

/// <summary>
/// Table Pendiente Ubicar SGA (ID 51115).
/// Lo que hay en stock y no está en ninguna ubicación, por almacén, producto, variante y lote.
/// Solo vive en memoria: lo calcula CargarPendienteUbicar de "Consulta Stock SGA" cada vez que
/// se abre o se actualiza la página "Pendiente Ubicar SGA".
/// </summary>
table 51115 "Pendiente Ubicar SGA"
{
    Caption = 'Pendiente de ubicar SGA';
    TableType = Temporary;
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Cod. Almacen"; Code[10])
        {
            Caption = 'Almacén';
            DataClassification = ToBeClassified;
            TableRelation = Location;
            ToolTip = 'Almacén del stock.';
        }
        field(2; "No. Producto"; Code[20])
        {
            Caption = 'Nº producto';
            DataClassification = ToBeClassified;
            TableRelation = Item;
            ToolTip = 'Producto con stock sin ubicar.';
        }
        field(3; "Cod. Variante"; Code[10])
        {
            Caption = 'Variante';
            DataClassification = ToBeClassified;
            ToolTip = 'Variante del producto.';
        }
        field(4; "No. Lote"; Code[50])
        {
            Caption = 'Lote';
            DataClassification = ToBeClassified;
            ToolTip = 'Lote del stock sin ubicar.';
        }
        field(10; Descripcion; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = ToBeClassified;
            ToolTip = 'Descripción del producto.';
        }
        field(11; "Fecha Caducidad"; Date)
        {
            Caption = 'Fecha caducidad';
            DataClassification = ToBeClassified;
            ToolTip = 'Caducidad del lote, la del stock de BC.';
        }
        field(12; "Unidad Medida Base"; Code[10])
        {
            Caption = 'Unidad base';
            DataClassification = ToBeClassified;
            ToolTip = 'Unidad en la que van las cantidades de la línea.';
        }
        field(20; "Stock BC"; Decimal)
        {
            Caption = 'Stock BC';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            ToolTip = 'Existencias del lote en BC, en el almacén.';
        }
        field(21; "Stock SGA"; Decimal)
        {
            Caption = 'Ubicado';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            ToolTip = 'Lo que ya está en ubicaciones de SGA.';
        }
        field(22; Pendiente; Decimal)
        {
            Caption = 'Sin ubicar';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            ToolTip = 'Stock de BC que no está en ninguna ubicación.';
        }
        field(23; "En Documentos"; Decimal)
        {
            Caption = 'En recepciones o ensamblados';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            ToolTip = 'Parte de lo sin ubicar que está pendiente en "Ubicar recepciones" o "Ubicar ensamblados". Se ubica desde esas pantallas, no desde aquí: si se ubicara aquí, ellas lo volverían a pedir.';
        }
        field(24; "A Ubicar"; Decimal)
        {
            Caption = 'A ubicar aquí';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            ToolTip = 'Lo sin ubicar que no tiene documento pendiente: es lo que se ubica desde esta página.';
        }
        field(25; Desglose; Text[100])
        {
            Caption = 'Desglose';
            DataClassification = ToBeClassified;
            ToolTip = 'Lo que hay que ubicar aquí, en palés, cajas y botellas sueltas.';
        }
    }

    keys
    {
        key(PK; "Cod. Almacen", "No. Producto", "Cod. Variante", "No. Lote")
        {
            Clustered = true;
        }
    }
}
