namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;

/// <summary>
/// Table Buffer Conciliacion SGA (ID 51107).
/// Resultado de la última conciliación entre el stock de BC (movs. de producto) y el
/// contenido por ubicación de SGA, por producto, variante, almacén y lote.
///
/// No es temporal a propósito: el informe la rellena y la página "Conciliacion SGA" la
/// consulta después. Las filas se guardan por usuario, así que dos personas pueden
/// conciliar a la vez sin pisarse.
/// </summary>
table 51107 "Buffer Conciliacion SGA"
{
    Caption = 'Conciliación SGA vs stock';
    DataClassification = ToBeClassified;

    fields
    {
        field(5; "Cod. Usuario"; Code[50])
        {
            Caption = 'Cód. usuario';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(10; "No. Producto"; Code[20])
        {
            Caption = 'Nº producto';
            DataClassification = ToBeClassified;
            TableRelation = Item;
        }
        field(20; "Cod. Variante"; Code[10])
        {
            Caption = 'Cód. variante';
            DataClassification = ToBeClassified;
        }
        field(30; "Cod. Almacen"; Code[10])
        {
            Caption = 'Cód. almacén';
            DataClassification = ToBeClassified;
            TableRelation = Location;
        }
        field(40; "No. Lote"; Code[50])
        {
            Caption = 'Nº lote';
            DataClassification = ToBeClassified;
        }
        field(50; "Stock BC"; Decimal)
        {
            Caption = 'Stock BC';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            ToolTip = 'Existencias según los movimientos de producto, en unidad de medida base.';
        }
        field(51; "Stock SGA"; Decimal)
        {
            Caption = 'Stock SGA';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            ToolTip = 'Suma del contenido de todas las ubicaciones, en unidad de medida base.';
        }
        field(52; Diferencia; Decimal)
        {
            Caption = 'Diferencia';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            ToolTip = 'Stock BC menos stock SGA. Positivo: hay stock sin ubicar. Negativo: sobra en ubicaciones.';
        }
        field(60; Estado; Option)
        {
            Caption = 'Estado';
            DataClassification = ToBeClassified;
            OptionMembers = Cuadra,"Sin Ubicar","Sobra en SGA";
            OptionCaption = 'Cuadra,Sin ubicar,Sobra en SGA';
        }
        field(70; "Unidad Medida Base"; Code[10])
        {
            Caption = 'Unidad medida base';
            DataClassification = ToBeClassified;
        }
        field(80; Descripcion; Text[100])
        {
            Caption = 'Descripción';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup(Item.Description where("No." = field("No. Producto")));
        }
    }

    keys
    {
        key(PK; "Cod. Usuario", "No. Producto", "Cod. Variante", "Cod. Almacen", "No. Lote")
        {
            Clustered = true;
        }
        key(Diferencia; "Cod. Usuario", Diferencia)
        {
        }
        key(Estado; "Cod. Usuario", Estado, "No. Producto")
        {
        }
    }

    /// <summary>
    /// Calcula la diferencia y clasifica la fila.
    /// </summary>
    procedure ActualizarEstado()
    begin
        Diferencia := Round("Stock BC" - "Stock SGA", 0.00001);

        case true of
            Diferencia = 0:
                Estado := Estado::Cuadra;
            Diferencia > 0:
                Estado := Estado::"Sin Ubicar";
            else
                Estado := Estado::"Sobra en SGA";
        end;
    end;

    /// <summary>
    /// Expresión de estilo para la página de conciliación.
    /// </summary>
    procedure EstiloConciliacion(): Text
    begin
        case Estado of
            Estado::Cuadra:
                exit('Favorable');
            Estado::"Sin Ubicar":
                exit('Ambiguous');
            Estado::"Sobra en SGA":
                exit('Unfavorable');
        end;

        exit('Standard');
    end;
}
