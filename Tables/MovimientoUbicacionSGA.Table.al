namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using System.Security.User;

/// <summary>
/// Table Movimiento Ubicacion SGA (ID 51103).
/// Diario de movimientos de ubicación. Es la fuente de verdad de SGA: el contenido
/// de "Contenido Ubicacion SGA" es un agregado de estas filas y se puede reconstruir
/// desde ellas con Rep. "Sincronizar Ubicaciones SGA".
///
/// Las filas no se modifican nunca. Solo las inserta Cod. "Gestion Contenido SGA".
/// </summary>
table 51103 "Movimiento Ubicacion SGA"
{
    Caption = 'Movimiento ubicación SGA';
    DataClassification = ToBeClassified;
    LookupPageId = "Movs. Ubicacion SGA";
    DrillDownPageId = "Movs. Ubicacion SGA";

    fields
    {
        field(1; "No. Movimiento"; Integer)
        {
            Caption = 'Nº movimiento';
            DataClassification = ToBeClassified;
            AutoIncrement = true;
            Editable = false;
        }
        field(10; "Tipo Movimiento"; Enum "Tipo Mov. Ubicacion SGA")
        {
            Caption = 'Tipo movimiento';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(11; Origen; Enum "Origen Mov. SGA")
        {
            Caption = 'Origen';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(20; "Cod. Almacen"; Code[10])
        {
            Caption = 'Cód. almacén';
            DataClassification = ToBeClassified;
            TableRelation = Location;
            Editable = false;
        }
        field(30; "Cod. Bin Origen"; Code[20])
        {
            Caption = 'Cód. ubicación origen';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(31; "Cod. Bin Destino"; Code[20])
        {
            Caption = 'Cód. ubicación destino';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(40; "No. Producto"; Code[20])
        {
            Caption = 'Nº producto';
            DataClassification = ToBeClassified;
            TableRelation = Item;
            Editable = false;
        }
        field(41; "Cod. Variante"; Code[10])
        {
            Caption = 'Cód. variante';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(42; "No. Lote"; Code[50])
        {
            Caption = 'Nº lote';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(43; "Fecha Caducidad"; Date)
        {
            Caption = 'Fecha caducidad';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(44; SSCC; Code[20])
        {
            Caption = 'SSCC';
            DataClassification = ToBeClassified;
            Editable = false;
            ToolTip = 'Código del palé (SSCC) que se ha movido. En un traslado es el mismo en el origen y en el destino.';
        }
        field(50; "Cod. Unidad Medida"; Code[10])
        {
            Caption = 'Cód. unidad medida';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(51; "Ctdad. por Unidad Medida"; Decimal)
        {
            Caption = 'Ctdad. por unidad medida';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(60; Cantidad; Decimal)
        {
            Caption = 'Cantidad';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(61; "Cantidad Base"; Decimal)
        {
            Caption = 'Cantidad (UM base)';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(70; "No. Documento Origen"; Code[20])
        {
            Caption = 'Nº documento origen';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(71; "No. Linea Origen"; Integer)
        {
            Caption = 'Nº línea origen';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(80; "Fecha Registro"; Date)
        {
            Caption = 'Fecha registro';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(82; "Fecha-Hora Registro"; DateTime)
        {
            Caption = 'Fecha-hora registro';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(90; "Cod. Usuario"; Code[50])
        {
            Caption = 'Cód. usuario';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = "User Setup";
            Editable = false;
        }
        field(100; Descripcion; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(110; "Descripcion Producto"; Text[100])
        {
            Caption = 'Descripción producto';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup(Item.Description where("No." = field("No. Producto")));
        }
    }

    keys
    {
        key(PK; "No. Movimiento")
        {
            Clustered = true;
        }
        key(Producto; "No. Producto", "Cod. Variante", "No. Lote", "Fecha Registro")
        {
        }
        key(UbicDestino; "Cod. Almacen", "Cod. Bin Destino", "Fecha Registro")
        {
        }
        key(UbicOrigen; "Cod. Almacen", "Cod. Bin Origen", "Fecha Registro")
        {
        }
        key(Cronologia; "Fecha-Hora Registro", "No. Movimiento")
        {
        }
        key(Documento; Origen, "No. Documento Origen", "No. Linea Origen")
        {
        }
        key(Usuario; "Cod. Usuario", "Fecha Registro")
        {
        }
        key(Pale; SSCC, "Fecha-Hora Registro")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No. Movimiento", "Tipo Movimiento", "No. Producto", Cantidad)
        {
        }
    }

    trigger OnInsert()
    begin
        TestEscrituraAutorizada();
    end;

    trigger OnModify()
    var
        ModificarMovimientoErr: Label 'Los movimientos de ubicación no se pueden modificar. Registre un movimiento de corrección.';
    begin
        Error(ModificarMovimientoErr);
    end;

    trigger OnDelete()
    begin
        TestEscrituraAutorizada();
    end;

    trigger OnRename()
    var
        RenombrarMovimientoErr: Label 'Los movimientos de ubicación no se pueden renombrar.';
    begin
        Error(RenombrarMovimientoErr);
    end;

    var
        EscrituraAutorizada: Boolean;

    /// <summary>
    /// Habilita la escritura de esta instancia del registro. La invoca únicamente
    /// Cod. "Gestion Contenido SGA".
    /// </summary>
    procedure AutorizarEscritura()
    begin
        EscrituraAutorizada := true;
    end;

    local procedure TestEscrituraAutorizada()
    var
        RegistroNoAutorizadoErr: Label 'Los movimientos de ubicación solo se pueden registrar desde la gestión de contenido SGA.';
    begin
        if not EscrituraAutorizada then
            Error(RegistroNoAutorizadoErr);
    end;

    /// <summary>
    /// Texto legible del recorrido del movimiento, para listas y factboxes.
    /// </summary>
    procedure Recorrido(): Text
    begin
        case true of
            ("Cod. Bin Origen" <> '') and ("Cod. Bin Destino" <> ''):
                exit("Cod. Bin Origen" + ' -> ' + "Cod. Bin Destino");
            "Cod. Bin Destino" <> '':
                exit('-> ' + "Cod. Bin Destino");
            "Cod. Bin Origen" <> '':
                exit("Cod. Bin Origen" + ' ->');
        end;

        exit('');
    end;
}
