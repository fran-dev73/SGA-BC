namespace AntonioNadal.SGA;

/// <summary>
/// Table Resultado Carga Inicial SGA (ID 51111).
/// Una fila por cada cosa que la carga inicial ha dejado (o no ha podido dejar) en una
/// ubicación: un palé, un grupo de cajas, o lo que se queda sin cargar y por qué.
///
/// Es temporal: solo sirve para enseñar el resultado al terminar. En simulación es lo único que
/// queda, porque los movimientos se deshacen y las tablas temporales no entran en esa vuelta atrás.
/// </summary>
table 51111 "Resultado Carga Inicial SGA"
{
    Caption = 'Resultado carga inicial SGA';
    DataClassification = ToBeClassified;
    TableType = Temporary;

    fields
    {
        field(1; "No. Entrada"; Integer)
        {
            Caption = 'Nº entrada';
            DataClassification = ToBeClassified;
        }
        field(10; "No. Producto"; Code[20])
        {
            Caption = 'Nº producto';
            DataClassification = ToBeClassified;
        }
        field(11; "Descripcion Producto"; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = ToBeClassified;
        }
        field(12; "Cod. Variante"; Code[10])
        {
            Caption = 'Cód. variante';
            DataClassification = ToBeClassified;
        }
        field(13; "No. Lote"; Code[50])
        {
            Caption = 'Nº lote';
            DataClassification = ToBeClassified;
        }
        field(20; "Cod. Bin"; Code[20])
        {
            Caption = 'Ubicación';
            DataClassification = ToBeClassified;
        }
        field(21; "Cod. Unidad Medida"; Code[10])
        {
            Caption = 'Unidad de medida';
            DataClassification = ToBeClassified;
        }
        field(22; Cantidad; Decimal)
        {
            Caption = 'Cantidad';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
        }
        field(23; "Cantidad Base"; Decimal)
        {
            Caption = 'Cantidad (UM base)';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
        }
        field(30; Cargado; Boolean)
        {
            Caption = 'Cargado';
            DataClassification = ToBeClassified;
        }
        field(31; Motivo; Text[500])
        {
            Caption = 'Motivo';
            DataClassification = ToBeClassified;
        }
    }

    keys
    {
        key(PK; "No. Entrada")
        {
            Clustered = true;
        }
        key(Producto; "No. Producto", "Cod. Variante", "No. Lote")
        {
        }
    }
}
