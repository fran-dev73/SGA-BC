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
///
/// Es también la tabla de stock por lote en memoria: "Pendiente Ubicar SGA" y la carga inicial
/// la usan como temporal, y para eso llevan los campos 90 a 93 (caducidad, lo que está en
/// documentos, lo que se ubica desde la página y su desglose), que la conciliación no rellena.
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
        field(90; "Fecha Caducidad"; Date)
        {
            Caption = 'Fecha caducidad';
            DataClassification = ToBeClassified;
            ToolTip = 'Caducidad del lote, la del stock de BC.';
        }
        field(91; "En Documentos"; Decimal)
        {
            Caption = 'En recepciones o ensamblados';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            ToolTip = 'Parte de lo sin ubicar que está pendiente en "Ubicar recepciones" o "Ubicar ensamblados". Se ubica desde esas pantallas, no desde aquí: si se ubicara aquí, ellas lo volverían a pedir. En Pendiente de ubicar, pulse para abrir esa pantalla con los documentos del producto.';
        }
        field(92; "A Ubicar"; Decimal)
        {
            Caption = 'A ubicar aquí';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            ToolTip = 'Lo sin ubicar que no tiene documento pendiente: es lo que se ubica desde esta página.';
        }
        field(93; Desglose; Text[100])
        {
            Caption = 'Desglose';
            DataClassification = ToBeClassified;
            ToolTip = 'Lo que hay que ubicar aquí, en palés, cajas y botellas sueltas.';
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
    }

    /// <summary>
    /// Calcula la diferencia: positiva, stock sin ubicar; negativa, sobra en ubicaciones.
    /// </summary>
    procedure CalcularDiferencia()
    begin
        Diferencia := Round("Stock BC" - "Stock SGA", 0.00001);
    end;

    /// <summary>
    /// Deja solo las filas del usuario actual. No quita otros filtros ni cambia de grupo de
    /// filtros, para que una página pueda llamarlo dentro de su FilterGroup.
    /// </summary>
    procedure FiltrarUsuarioActual()
    begin
        SetRange("Cod. Usuario", CopyStr(UserId(), 1, MaxStrLen("Cod. Usuario")));
    end;

    /// <summary>
    /// Expresión de estilo para la página de conciliación, según el signo de la diferencia.
    /// </summary>
    procedure EstiloConciliacion(): Text
    begin
        case true of
            Diferencia = 0:
                exit('Favorable');
            Diferencia > 0:
                exit('Ambiguous');
            else
                exit('Unfavorable');
        end;
    end;

    /// <summary>
    /// Estilo de "En documentos" en Pendiente de ubicar: en ámbar si parte está en documentos
    /// de entrada que todavía no se han ubicado.
    /// </summary>
    procedure EstiloEnDocumentos(): Text
    begin
        if "En Documentos" > 0 then
            exit('Ambiguous');

        exit('Standard');
    end;
}
