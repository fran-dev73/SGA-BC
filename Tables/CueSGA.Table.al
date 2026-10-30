namespace AntonioNadal.SGA;

using Microsoft.Inventory.Location;

/// <summary>
/// Table Cue SGA (ID 51105).
/// Origen de los indicadores del rol center de almacén. Todos los contadores son
/// FlowField sobre "Ubicacion SGA", "Contenido Ubicacion SGA" y "Movimiento Ubicacion SGA",
/// filtrados por los FlowFilter de almacén y fecha.
/// </summary>
table 51105 "Cue SGA"
{
    Caption = 'Cue SGA';
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Clave primaria';
            DataClassification = ToBeClassified;
        }
        field(10; "Ubicaciones Totales"; Integer)
        {
            Caption = 'Ubicaciones totales';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen")));
        }
        field(11; "Ubicaciones Vacias"; Integer)
        {
            Caption = 'Ubicaciones vacías';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                      "Estado SGA" = const(Vacia)));
        }
        field(12; "Ubicaciones Parciales"; Integer)
        {
            Caption = 'Ubicaciones parciales';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                      "Estado SGA" = const(Parcial)));
        }
        field(13; "Ubicaciones Llenas"; Integer)
        {
            Caption = 'Ubicaciones llenas';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                      "Estado SGA" = const(Llena)));
        }
        field(14; "Ubicaciones Bloqueadas"; Integer)
        {
            Caption = 'Ubicaciones bloqueadas';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                      "Estado SGA" = const(Bloqueada)));
        }
        field(20; "Lineas Contenido"; Integer)
        {
            Caption = 'Líneas de contenido';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Contenido Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen")));
        }
        field(21; "Contenido Bloqueado"; Integer)
        {
            Caption = 'Contenido bloqueado';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Contenido Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                                Bloqueado = const(true)));
        }
        field(22; "Contenido Reservado"; Integer)
        {
            Caption = 'Contenido reservado';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Contenido Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                                "Cantidad Reservada" = filter(> 0)));
        }
        field(30; "Movimientos Periodo"; Integer)
        {
            Caption = 'Movimientos del periodo';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Movimiento Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                                 "Fecha Registro" = field("Filtro Fecha")));
        }
        field(90; "Filtro Almacen"; Code[10])
        {
            Caption = 'Filtro almacén';
            FieldClass = FlowFilter;
            TableRelation = Location;
        }
        field(91; "Filtro Fecha"; Date)
        {
            Caption = 'Filtro fecha';
            FieldClass = FlowFilter;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    /// <summary>
    /// Devuelve el registro de cues, creándolo la primera vez.
    /// </summary>
    procedure ObtenerCue()
    begin
        if not Get() then begin
            Init();
            Insert();
        end;
    end;
}
