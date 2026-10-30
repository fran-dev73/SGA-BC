namespace AntonioNadal.SGA;

using Microsoft.Warehouse.Structure;

/// <summary>
/// Table Linea Ubicacion SGA (ID 51114).
/// Un trozo de mercancía a ubicar: cada palé, las cajas o las unidades sueltas, con su unidad,
/// el hueco propuesto, el que se confirma y si se ha podido ubicar o por qué no. Es la tabla
/// única de "trozo a ubicar": el reparto de "Ubicar producto" (Origen Manual) y el resultado de
/// la carga inicial y de "Ubicar seleccionadas" (Origen "Carga Inicial").
///
/// Es temporal: solo vive en memoria mientras se usa. En la simulación de la carga inicial es lo
/// único que queda, porque los movimientos se deshacen y las tablas temporales no entran en esa
/// vuelta atrás.
/// </summary>
table 51114 "Linea Ubicacion SGA"
{
    Caption = 'Línea ubicación SGA';
    TableType = Temporary;
    DataClassification = ToBeClassified;

    fields
    {
        field(1; Linea; Integer)
        {
            Caption = 'Línea';
            ToolTip = 'Número de la línea, en el orden en que se ha repartido.';
            DataClassification = ToBeClassified;
        }
        field(2; Origen; Enum "Origen Mov. SGA")
        {
            Caption = 'Origen';
            ToolTip = 'Para qué es la línea: Manual en "Ubicar producto", Carga inicial en la carga inicial y en "Ubicar seleccionadas".';
            DataClassification = ToBeClassified;
        }
        field(10; Paso; Text[100])
        {
            Caption = 'Qué';
            ToolTip = 'Qué parte de la mercancía es: cada palé, las cajas o las unidades sueltas.';
            DataClassification = ToBeClassified;
        }
        field(20; "Cod. Almacen"; Code[10])
        {
            Caption = 'Almacén';
            ToolTip = 'Almacén en el que se ubica.';
            DataClassification = ToBeClassified;
        }
        field(21; "Cod. Unidad Medida"; Code[10])
        {
            Caption = 'Unidad';
            ToolTip = 'Unidad en la que se ubica: palé, unidad de venta o unidad base.';
            DataClassification = ToBeClassified;
        }
        field(22; Cantidad; Decimal)
        {
            Caption = 'Cantidad';
            ToolTip = 'Cantidad, en la unidad de la línea.';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
        }
        field(23; "Cantidad Base"; Decimal)
        {
            Caption = 'Cantidad (UM base)';
            ToolTip = 'La misma cantidad en la unidad de medida base.';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
        }
        field(24; "No. Producto"; Code[20])
        {
            Caption = 'Nº producto';
            ToolTip = 'Producto que se ubica.';
            DataClassification = ToBeClassified;
        }
        field(25; "Descripcion Producto"; Text[100])
        {
            Caption = 'Descripción';
            ToolTip = 'Descripción del producto.';
            DataClassification = ToBeClassified;
        }
        field(26; "Cod. Variante"; Code[10])
        {
            Caption = 'Cód. variante';
            ToolTip = 'Variante del producto.';
            DataClassification = ToBeClassified;
        }
        field(27; "No. Lote"; Code[50])
        {
            Caption = 'Nº lote';
            ToolTip = 'Lote de la mercancía.';
            DataClassification = ToBeClassified;
        }
        field(30; "Ubicacion Propuesta"; Code[20])
        {
            Caption = 'Ubicación propuesta';
            ToolTip = 'Hueco que propone el sistema.';
            DataClassification = ToBeClassified;
        }
        field(31; "Ubicacion Confirmada"; Code[20])
        {
            Caption = 'Ubicación confirmada';
            ToolTip = 'Hueco en el que se deja. En blanco si no se ha podido ubicar.';
            DataClassification = ToBeClassified;
            TableRelation = Bin.Code where("Location Code" = field("Cod. Almacen"));
        }
        field(40; Estado; Option)
        {
            Caption = 'Estado';
            ToolTip = 'Pendiente de confirmar, ya ubicado o sin sitio.';
            DataClassification = ToBeClassified;
            OptionMembers = Pendiente,Ubicado,"Sin Sitio";
            OptionCaption = 'Pendiente,Ubicado,No se puede ubicar';
        }
        field(41; Motivo; Text[500])
        {
            Caption = 'Motivo';
            ToolTip = 'Por qué se propone ese hueco, o por qué no se puede ubicar.';
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

    /// <summary>
    /// Expresión de estilo de la línea según su estado: verde si ya está ubicada, rojo si no
    /// tiene sitio y normal si está pendiente.
    /// </summary>
    procedure EstiloEstado(): Text
    begin
        case Estado of
            Estado::Ubicado:
                exit('Favorable');
            Estado::"Sin Sitio":
                exit('Unfavorable');
        end;

        exit('Standard');
    end;
}
