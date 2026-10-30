namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Warehouse.Structure;

/// <summary>
/// Table Contenido Ubicacion SGA (ID 51102).
/// Estado actual del almacén: qué producto, variante, lote y unidad de medida hay
/// ahora mismo en cada ubicación, y en qué cantidad.
///
/// Es una capa de detalle sobre el stock de BC, no un stock paralelo: la cantidad total
/// la siguen gobernando los movimientos de producto. Un traslado entre ubicaciones
/// mueve filas de esta tabla y NO genera movimiento de producto.
///
/// Solo escribe en ella Cod. "Gestion Contenido SGA". Los triggers lo imponen para que
/// el estado de ocupación y el diario de movimientos no puedan quedar descuadrados.
/// </summary>
table 51102 "Contenido Ubicacion SGA"
{
    Caption = 'Contenido ubicación SGA';
    DataClassification = ToBeClassified;
    LookupPageId = "Contenido Ubicaciones SGA";
    DrillDownPageId = "Contenido Ubicaciones SGA";

    fields
    {
        field(10; "Cod. Almacen"; Code[10])
        {
            Caption = 'Cód. almacén';
            DataClassification = ToBeClassified;
            TableRelation = Location;
        }
        field(20; "Cod. Bin"; Code[20])
        {
            Caption = 'Cód. bin';
            DataClassification = ToBeClassified;
            TableRelation = Bin where("Location Code" = field("Cod. Almacen"));
        }
        field(30; "No. Producto"; Code[20])
        {
            Caption = 'Nº producto';
            DataClassification = ToBeClassified;
            TableRelation = Item;
        }
        field(40; "Cod. Variante"; Code[10])
        {
            Caption = 'Cód. variante';
            DataClassification = ToBeClassified;
            TableRelation = "Item Variant".Code where("Item No." = field("No. Producto"));
        }
        field(50; "No. Lote"; Code[50])
        {
            Caption = 'Nº lote';
            DataClassification = ToBeClassified;
        }
        field(60; "Cod. Unidad Medida"; Code[10])
        {
            Caption = 'Cód. unidad medida';
            DataClassification = ToBeClassified;
            TableRelation = "Item Unit of Measure".Code where("Item No." = field("No. Producto"));
        }
        field(70; Cantidad; Decimal)
        {
            Caption = 'Cantidad';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            Editable = false;
            ToolTip = 'Cantidad en la unidad de medida de la línea.';
        }
        field(71; "Ctdad. por Unidad Medida"; Decimal)
        {
            Caption = 'Ctdad. por unidad medida';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            Editable = false;
            InitValue = 1;
        }
        field(72; "Cantidad Base"; Decimal)
        {
            Caption = 'Cantidad (UM base)';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            Editable = false;
            ToolTip = 'Cantidad convertida a la unidad de medida base. Es la cantidad con la que se compara contra el stock de BC.';
        }
        field(80; "Cantidad Reservada"; Decimal)
        {
            Caption = 'Cantidad reservada';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            Editable = false;
            ToolTip = 'Cantidad base ya comprometida por órdenes de picking pendientes.';
        }
        field(81; "Cantidad Disponible"; Decimal)
        {
            Caption = 'Cantidad disponible';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            Editable = false;
            ToolTip = 'Cantidad base libre para recoger: cantidad menos reservada.';
        }
        field(90; "Fecha Caducidad"; Date)
        {
            Caption = 'Fecha caducidad';
            DataClassification = ToBeClassified;
            Editable = false;
            ToolTip = 'Caducidad del lote. Es el criterio de ordenación cuando la estrategia de picking es FEFO.';
        }
        field(100; "Fecha Ultima Entrada"; DateTime)
        {
            Caption = 'Fecha última entrada';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(101; "Fecha Ultima Salida"; DateTime)
        {
            Caption = 'Fecha última salida';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(110; Bloqueado; Boolean)
        {
            Caption = 'Bloqueado';
            DataClassification = ToBeClassified;
            ToolTip = 'Impide que el motor de picking proponga esta línea de contenido.';
        }
        field(111; "Motivo Bloqueo"; Text[50])
        {
            Caption = 'Motivo bloqueo';
            DataClassification = ToBeClassified;
        }
        field(120; Descripcion; Text[100])
        {
            Caption = 'Descripción';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup(Item.Description where("No." = field("No. Producto")));
        }
        field(130; "Cod. Zona SGA"; Code[10])
        {
            Caption = 'Cód. zona';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("Ubicacion SGA"."Cod. Zona SGA" where("Cod. Almacen" = field("Cod. Almacen"),
                                                                       "Cod. Bin" = field("Cod. Bin")));
        }
        field(131; "Tipo Ubicacion"; Enum "Tipo Ubicacion SGA")
        {
            Caption = 'Tipo ubicación';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("Ubicacion SGA"."Tipo Ubicacion" where("Cod. Almacen" = field("Cod. Almacen"),
                                                                        "Cod. Bin" = field("Cod. Bin")));
        }
        field(132; "Secuencia Picking"; Integer)
        {
            Caption = 'Secuencia picking';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("Ubicacion SGA"."Secuencia Picking" where("Cod. Almacen" = field("Cod. Almacen"),
                                                                           "Cod. Bin" = field("Cod. Bin")));
        }
    }

    keys
    {
        key(PK; "Cod. Almacen", "Cod. Bin", "No. Producto", "Cod. Variante", "No. Lote", "Cod. Unidad Medida")
        {
            Clustered = true;
        }
        key(Ubicacion; "Cod. Almacen", "Cod. Bin")
        {
            SumIndexFields = Cantidad, "Cantidad Base", "Cantidad Reservada", "Cantidad Disponible";
        }
        key(Producto; "No. Producto", "Cod. Variante", "Cod. Almacen", "No. Lote")
        {
            SumIndexFields = "Cantidad Base", "Cantidad Reservada", "Cantidad Disponible";
        }
        key(FEFO; "Cod. Almacen", "No. Producto", "Cod. Variante", Bloqueado, "Fecha Caducidad", "Cod. Bin")
        {
            SumIndexFields = "Cantidad Base", "Cantidad Disponible";
        }
        key(Lote; "No. Lote", "No. Producto", "Cod. Almacen")
        {
            SumIndexFields = "Cantidad Base";
        }
        key(Antiguedad; "Cod. Almacen", "No. Producto", "Fecha Ultima Entrada")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Cod. Bin", "No. Producto", "No. Lote", Cantidad)
        {
        }
        fieldgroup(Brick; "Cod. Bin", "No. Producto", Descripcion, "No. Lote", Cantidad)
        {
        }
    }

    trigger OnInsert()
    begin
        TestEscrituraAutorizada();
    end;

    trigger OnModify()
    begin
        TestEscrituraAutorizada();
    end;

    trigger OnDelete()
    begin
        TestEscrituraAutorizada();
    end;

    trigger OnRename()
    var
        RenombrarContenidoErr: Label 'No se puede renombrar el contenido de una ubicación. Use un traslado.';
    begin
        Error(RenombrarContenidoErr);
    end;

    var
        EscrituraAutorizada: Boolean;

    /// <summary>
    /// Habilita la escritura de esta instancia del registro. La invoca únicamente
    /// Cod. "Gestion Contenido SGA" justo antes de insertar, modificar o eliminar.
    /// </summary>
    procedure AutorizarEscritura()
    begin
        EscrituraAutorizada := true;
    end;

    local procedure TestEscrituraAutorizada()
    var
        ModificacionNoAutorizadaErr: Label 'El contenido de ubicación solo se puede modificar desde la gestión de contenido SGA, para que la ocupación y el histórico de movimientos no queden descuadrados.';
    begin
        if not EscrituraAutorizada then
            Error(ModificacionNoAutorizadaErr);
    end;

    /// <summary>
    /// Recalcula la cantidad base y la disponible a partir de la cantidad y del factor de conversión.
    /// </summary>
    procedure ActualizarCantidades()
    begin
        if "Ctdad. por Unidad Medida" <= 0 then
            "Ctdad. por Unidad Medida" := 1;

        "Cantidad Base" := Round(Cantidad * "Ctdad. por Unidad Medida", 0.00001);
        "Cantidad Disponible" := "Cantidad Base" - "Cantidad Reservada";
    end;

    /// <summary>
    /// Indica si el lote de la línea está caducado a la fecha indicada.
    /// </summary>
    procedure EstaCaducado(prm_Fecha: Date): Boolean
    begin
        if "Fecha Caducidad" = 0D then
            exit(false);

        exit("Fecha Caducidad" < prm_Fecha);
    end;

    /// <summary>
    /// Expresión de estilo para las páginas de contenido.
    /// </summary>
    procedure EstiloContenido(): Text
    begin
        if Bloqueado then
            exit('Unfavorable');

        if EstaCaducado(WorkDate()) then
            exit('Unfavorable');

        if "Cantidad Reservada" > 0 then
            exit('Ambiguous');

        exit('Standard');
    end;
}
