namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Warehouse.Structure;

/// <summary>
/// Table Linea Orden Picking SGA (ID 51109).
/// Cada línea es una parada del recorrido: ir a una ubicación concreta y recoger una
/// cantidad de un producto y lote determinados.
///
/// Una línea del documento origen puede dar varias líneas de picking si la cantidad está
/// repartida entre varias ubicaciones o varios lotes, por eso se guarda "No. Linea Origen".
/// Las líneas se ordenan por "Secuencia Picking" para que el recorrido sea el físico.
/// </summary>
table 51109 "Linea Orden Picking SGA"
{
    Caption = 'Línea de picking SGA';
    DataClassification = ToBeClassified;

    fields
    {
        field(10; "No. Orden"; Code[20])
        {
            Caption = 'Nº orden';
            DataClassification = ToBeClassified;
            TableRelation = "Orden Picking SGA"."No. Orden";
        }
        field(11; "No. Linea"; Integer)
        {
            Caption = 'Nº línea';
            DataClassification = ToBeClassified;
        }
        field(20; "Cod. Almacen"; Code[10])
        {
            Caption = 'Cód. almacén';
            DataClassification = ToBeClassified;
            TableRelation = Location;
        }
        field(30; "No. Producto"; Code[20])
        {
            Caption = 'Nº producto';
            DataClassification = ToBeClassified;
            TableRelation = Item;
        }
        field(31; "Descripcion Producto"; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = ToBeClassified;
        }
        field(32; "Cod. Variante"; Code[10])
        {
            Caption = 'Cód. variante';
            DataClassification = ToBeClassified;
        }
        field(33; "No. Lote"; Code[50])
        {
            Caption = 'Nº lote';
            DataClassification = ToBeClassified;
        }
        field(34; "Fecha Caducidad"; Date)
        {
            Caption = 'Fecha caducidad';
            DataClassification = ToBeClassified;
        }
        field(35; "No. Documento Origen"; Code[20])
        {
            Caption = 'Nº documento origen';
            DataClassification = ToBeClassified;
            Editable = false;
            ToolTip = 'Pedido de venta del que sale la parada. Es el mismo de la cabecera de la orden; se repite aquí para poder sumar lo preparado por línea de pedido.';
        }
        field(40; "Cod. Unidad Medida"; Code[10])
        {
            Caption = 'Unidad de medida';
            DataClassification = ToBeClassified;
        }
        field(41; "UM Documento"; Code[10])
        {
            Caption = 'UM pedido';
            DataClassification = ToBeClassified;
            ToolTip = 'Unidad de medida de la línea del pedido. Es la que ve el preparador: las cantidades de la parada se guardan en UM base.';
        }
        field(42; "Ctdad. por UM Documento"; Decimal)
        {
            Caption = 'Ctdad. por UM pedido';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            InitValue = 1;
        }
        field(50; "Cantidad a Recoger"; Decimal)
        {
            Caption = 'Cantidad a recoger';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(51; "Cantidad Recogida"; Decimal)
        {
            Caption = 'Cantidad recogida';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            Editable = false;
        }
        field(52; "Cantidad Pendiente"; Decimal)
        {
            Caption = 'Cantidad pendiente';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(53; "Cantidad Recogida UM Pedido"; Decimal)
        {
            Caption = 'Cantidad recogida (UM pedido)';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            Editable = false;
            ToolTip = 'Lo recogido en la unidad de medida de la línea del pedido. Es lo que suma la cantidad preparada de la línea de venta.';
        }
        field(60; "Cod. Bin Propuesto"; Code[20])
        {
            Caption = 'Ubicación propuesta';
            DataClassification = ToBeClassified;
            TableRelation = Bin where("Location Code" = field("Cod. Almacen"));
            ToolTip = 'Ubicación de la que el sistema dice que hay que recoger.';
        }
        field(61; "Cod. Bin Confirmado"; Code[20])
        {
            Caption = 'Ubicación confirmada';
            DataClassification = ToBeClassified;
            TableRelation = Bin where("Location Code" = field("Cod. Almacen"));
            ToolTip = 'Ubicación de la que el preparador ha recogido realmente.';
        }
        field(70; Estado; Enum "Estado Linea Picking SGA")
        {
            Caption = 'Estado';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(80; "Secuencia Picking"; Integer)
        {
            Caption = 'Secuencia picking';
            DataClassification = ToBeClassified;
            ToolTip = 'Orden de recorrido físico. Las líneas se recorren de menor a mayor.';
        }
        field(90; "No. Linea Origen"; Integer)
        {
            Caption = 'Nº línea origen';
            DataClassification = ToBeClassified;
            ToolTip = 'Línea del documento origen que ha generado esta parada.';
        }
        field(100; "Fecha Confirmacion"; DateTime)
        {
            Caption = 'Fecha confirmación';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(101; "Cod. Usuario Confirmacion"; Code[50])
        {
            Caption = 'Confirmada por';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
        }
    }

    keys
    {
        key(PK; "No. Orden", "No. Linea")
        {
            Clustered = true;
            SumIndexFields = "Cantidad Pendiente";
        }
        key(Recorrido; "No. Orden", Estado, "Secuencia Picking")
        {
        }
        key(Producto; "No. Producto", "No. Lote")
        {
        }
        key(LineaPedido; "No. Documento Origen", "No. Linea Origen")
        {
            SumIndexFields = "Cantidad Recogida UM Pedido";
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No. Producto", "Cod. Bin Propuesto", "Cantidad a Recoger")
        {
        }
    }

    trigger OnInsert()
    begin
        ActualizarPendiente();
    end;

    /// <summary>
    /// Recalcula cantidad pendiente y estado a partir de lo recogido.
    /// No hace Modify: decide el llamante.
    /// </summary>
    procedure ActualizarPendiente()
    begin
        if "Ctdad. por UM Documento" > 0 then
            "Cantidad Recogida UM Pedido" := Round("Cantidad Recogida" / "Ctdad. por UM Documento", 0.00001)
        else
            "Cantidad Recogida UM Pedido" := "Cantidad Recogida";

        if Estado = Estado::Cancelada then begin
            "Cantidad Pendiente" := 0;
            exit;
        end;

        "Cantidad Pendiente" := "Cantidad a Recoger" - "Cantidad Recogida";
        if "Cantidad Pendiente" < 0 then
            "Cantidad Pendiente" := 0;

        case true of
            "Cantidad Recogida" <= 0:
                Estado := Estado::Pendiente;
            "Cantidad Pendiente" > 0:
                Estado := Estado::Parcial;
            else
                Estado := Estado::Recogida;
        end;
    end;

    /// <summary>
    /// Expresión de estilo para las páginas.
    /// </summary>
    procedure EstiloEstado(): Text
    begin
        case Estado of
            Estado::Pendiente:
                exit('Standard');
            Estado::Parcial:
                exit('Ambiguous');
            Estado::Recogida:
                exit('Favorable');
            Estado::Cancelada:
                exit('Subordinate');
        end;

        exit('Standard');
    end;

    /// <summary>
    /// Pasa una cantidad en UM base a la UM del pedido, que es en la que habla el preparador.
    /// </summary>
    procedure EnUMDocumento(prm_CantidadBase: Decimal): Decimal
    begin
        if "Ctdad. por UM Documento" <= 0 then
            exit(prm_CantidadBase);

        exit(Round(prm_CantidadBase / "Ctdad. por UM Documento", 0.00001));
    end;

    /// <summary>
    /// Pasa una cantidad en la UM del pedido a UM base.
    /// </summary>
    procedure EnUMBase(prm_CantidadDocumento: Decimal): Decimal
    begin
        if "Ctdad. por UM Documento" <= 0 then
            exit(prm_CantidadDocumento);

        exit(Round(prm_CantidadDocumento * "Ctdad. por UM Documento", 0.00001));
    end;

    /// <summary>
    /// UM con la que se enseña la parada: la del pedido, o la base si la parada es anterior
    /// a que se guardara.
    /// </summary>
    procedure UMVisible(): Code[10]
    begin
        if "UM Documento" <> '' then
            exit("UM Documento");

        exit("Cod. Unidad Medida");
    end;

    /// <summary>
    /// Indica si el preparador se ha desviado de la ubicación propuesta.
    /// </summary>
    procedure HayDesvio(): Boolean
    begin
        exit(("Cod. Bin Confirmado" <> '') and ("Cod. Bin Confirmado" <> "Cod. Bin Propuesto"));
    end;
}
