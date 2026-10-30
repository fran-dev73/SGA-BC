namespace AntonioNadal.SGA;

using Microsoft.Warehouse.Structure;

/// <summary>
/// Table Linea Plan Ubicacion SGA (ID 51114).
/// Reparto de lo que se va a ubicar desde "Ubicar producto": una línea por trozo (cada palé,
/// las cajas, las unidades sueltas) con el hueco propuesto, el que confirma el operario y si se
/// ha podido ubicar. Solo vive en memoria mientras la página está abierta.
/// </summary>
table 51114 "Linea Plan Ubicacion SGA"
{
    Caption = 'Línea plan ubicación SGA';
    TableType = Temporary;
    DataClassification = ToBeClassified;

    fields
    {
        field(1; Linea; Integer)
        {
            Caption = 'Línea';
            DataClassification = ToBeClassified;
        }
        field(10; Paso; Text[100])
        {
            Caption = 'Qué';
            DataClassification = ToBeClassified;
        }
        field(20; "Cod. Almacen"; Code[10])
        {
            Caption = 'Almacén';
            DataClassification = ToBeClassified;
        }
        field(21; "Cod. Unidad Medida"; Code[10])
        {
            Caption = 'Unidad';
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
        field(30; "Ubicacion Propuesta"; Code[20])
        {
            Caption = 'Ubicación propuesta';
            DataClassification = ToBeClassified;
        }
        field(31; "Ubicacion Confirmada"; Code[20])
        {
            Caption = 'Ubicación confirmada';
            DataClassification = ToBeClassified;
            TableRelation = Bin.Code where("Location Code" = field("Cod. Almacen"));
        }
        field(40; Estado; Option)
        {
            Caption = 'Estado';
            DataClassification = ToBeClassified;
            OptionMembers = Pendiente,Ubicado,"Sin Sitio";
            OptionCaption = 'Pendiente,Ubicado,No se puede ubicar';
        }
        field(41; Motivo; Text[500])
        {
            Caption = 'Motivo';
            DataClassification = ToBeClassified;
        }
    }

    keys
    {
        key(PK; Linea)
        {
            Clustered = true;
        }
    }
}
