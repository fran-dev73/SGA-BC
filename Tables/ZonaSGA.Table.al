namespace AntonioNadal.SGA;

using Microsoft.Inventory.Location;

/// <summary>
/// Table Zona SGA (ID 51100).
/// Agrupación lógica de ubicaciones dentro de un almacén (nave, cámara, zona de picking...).
/// La zona fija las prioridades por defecto que heredan sus ubicaciones.
/// </summary>
table 51100 "Zona SGA"
{
    Caption = 'Zona SGA';
    DataClassification = ToBeClassified;
    LookupPageId = "Zonas SGA";
    DrillDownPageId = "Zonas SGA";

    fields
    {
        field(10; "Cod. Almacen"; Code[10])
        {
            Caption = 'Cód. almacén';
            DataClassification = ToBeClassified;
            TableRelation = Location;
            NotBlank = true;
        }
        field(20; Code; Code[10])
        {
            Caption = 'Código';
            DataClassification = ToBeClassified;
            NotBlank = true;
        }
        field(30; Descripcion; Text[50])
        {
            Caption = 'Descripción';
            DataClassification = ToBeClassified;
        }
        field(40; "Cod. Nave"; Code[1])
        {
            Caption = 'Cód. nave';
            DataClassification = ToBeClassified;
            ToolTip = 'Nave de la topología de ubicaciones a la que corresponde la zona. Informativo.';
        }
        field(50; "Tipo Ubicacion"; Enum "Tipo Ubicacion SGA")
        {
            Caption = 'Tipo ubicación';
            DataClassification = ToBeClassified;
            ToolTip = 'Tipo que se propone por defecto a las ubicaciones que se creen en esta zona.';
        }
        field(60; "Prioridad Ubicacion"; Integer)
        {
            Caption = 'Prioridad ubicación';
            DataClassification = ToBeClassified;
            ToolTip = 'Orden en que el motor de ubicación considera esta zona. Menor valor, antes.';
        }
        field(70; "Prioridad Picking"; Integer)
        {
            Caption = 'Prioridad picking';
            DataClassification = ToBeClassified;
            ToolTip = 'Orden en que el motor de picking considera esta zona. Menor valor, antes.';
        }
        field(80; "Zona de Picking"; Boolean)
        {
            Caption = 'Zona de picking';
            DataClassification = ToBeClassified;
            ToolTip = 'Si está activo, la zona se sirve directamente y es candidata a reposición desde reserva.';
        }
        field(90; Bloqueada; Boolean)
        {
            Caption = 'Bloqueada';
            DataClassification = ToBeClassified;
            ToolTip = 'Impide proponer las ubicaciones de esta zona para ubicar o recoger.';
        }
        field(100; "No. Ubicaciones"; Integer)
        {
            Caption = 'Nº ubicaciones';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Ubicacion SGA" where("Cod. Almacen" = field("Cod. Almacen"),
                                                      "Cod. Zona SGA" = field(Code)));
        }
    }

    keys
    {
        key(PK; "Cod. Almacen", Code)
        {
            Clustered = true;
        }
        key(Ubicar; "Cod. Almacen", Bloqueada, "Prioridad Ubicacion")
        {
        }
        key(Recoger; "Cod. Almacen", Bloqueada, "Prioridad Picking")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Code, Descripcion, "Tipo Ubicacion")
        {
        }
    }

    trigger OnDelete()
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        ZonaConUbicacionesErr: Label 'No se puede eliminar la zona %1 porque tiene ubicaciones asignadas.', Comment = '%1 = zona';
    begin
        rUbicacionSGA.SetRange("Cod. Almacen", "Cod. Almacen");
        rUbicacionSGA.SetRange("Cod. Zona SGA", Code);
        if not rUbicacionSGA.IsEmpty() then
            Error(ZonaConUbicacionesErr, Code);
    end;
}
