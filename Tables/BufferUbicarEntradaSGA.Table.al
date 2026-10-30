namespace AntonioNadal.SGA;

/// <summary>
/// Table Buffer Ubicar Entrada SGA (ID 51110).
/// Alimenta la pantalla de ubicación de entradas: una fila por cada cosa que ha entrado en la
/// fecha consultada (un ensamblado, o un producto y lote de un albarán de compra), con el
/// hueco que se le propone y el que finalmente se confirma.
///
/// Es una tabla temporal a propósito. El estado de verdad es el contenido de las ubicaciones
/// y el diario de movimientos, así que la pantalla se reconstruye al abrirse y deduce lo que
/// ya está ubicado en lugar de guardar un estado paralelo que se pueda desincronizar.
/// </summary>
table 51110 "Buffer Ubicar Entrada SGA"
{
    Caption = 'Entrada por ubicar';
    DataClassification = ToBeClassified;
    TableType = Temporary;

    fields
    {
        field(5; Origen; Enum "Origen Mov. SGA")
        {
            Caption = 'Origen';
            DataClassification = ToBeClassified;
            ToolTip = 'De dónde viene la mercancía: Producción para los ensamblados, Compra para las recepciones.';
        }
        field(10; "No. Documento"; Code[20])
        {
            Caption = 'Nº documento';
            DataClassification = ToBeClassified;
        }
        field(11; "Documento Relacionado"; Code[20])
        {
            Caption = 'Documento relacionado';
            DataClassification = ToBeClassified;
            ToolTip = 'Otro número con el que esta misma entrada puede estar ya ubicada. En los ensamblados, el del pedido sin registrar: los palés que se ubican al imprimir su etiqueta van con ese número.';
        }
        field(15; "Descripcion Origen"; Text[100])
        {
            Caption = 'Procedencia';
            DataClassification = ToBeClassified;
            ToolTip = 'Proveedor de la recepción. En los ensamblados va en blanco.';
        }
        field(20; "Fecha Registro"; Date)
        {
            Caption = 'Fecha registro';
            DataClassification = ToBeClassified;
        }
        field(30; "Cod. Almacen"; Code[10])
        {
            Caption = 'Cód. almacén';
            DataClassification = ToBeClassified;
        }
        field(40; "No. Producto"; Code[20])
        {
            Caption = 'Nº producto';
            DataClassification = ToBeClassified;
        }
        field(41; "Descripcion Producto"; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = ToBeClassified;
        }
        field(42; "Cod. Variante"; Code[10])
        {
            Caption = 'Cód. variante';
            DataClassification = ToBeClassified;
        }
        field(43; "No. Lote"; Code[50])
        {
            Caption = 'Nº lote';
            DataClassification = ToBeClassified;
        }
        field(50; "Cod. Unidad Medida"; Code[10])
        {
            Caption = 'Unidad de medida';
            DataClassification = ToBeClassified;
        }
        field(60; "Cantidad Entrada"; Decimal)
        {
            Caption = 'Cantidad entrada';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            ToolTip = 'Cantidad que ha entrado: la ensamblada, o la recibida neta de deshacer recepciones.';
        }
        field(61; "Cantidad Ya Ubicada"; Decimal)
        {
            Caption = 'Ya ubicada';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            ToolTip = 'Cantidad de esta entrada que SGA ya tiene colocada en ubicaciones.';
        }
        field(62; "Cantidad a Ubicar"; Decimal)
        {
            Caption = 'A ubicar';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            ToolTip = 'Cantidad que se va a colocar ahora. Por defecto, todo lo que queda pendiente.';
        }
        field(70; "Ubicacion Propuesta"; Code[20])
        {
            Caption = 'Ubicación propuesta';
            DataClassification = ToBeClassified;
        }
        field(71; "Motivo Propuesta"; Text[500])
        {
            Caption = 'Por qué ahí';
            DataClassification = ToBeClassified;
        }
        field(72; "Ubicacion Confirmada"; Code[20])
        {
            Caption = 'Ubicación confirmada';
            DataClassification = ToBeClassified;
            ToolTip = 'Hueco en el que se ha dejado realmente la mercancía.';
        }
        field(80; Ubicado; Boolean)
        {
            Caption = 'Ubicado';
            DataClassification = ToBeClassified;
            ToolTip = 'Marcado cuando ya no queda nada pendiente de colocar de esta entrada.';
        }
    }

    keys
    {
        // Un albarán de compra puede traer el mismo producto en varios lotes y unidades: cada
        // combinación es una fila, porque cada una va a su hueco y se ubica por separado.
        key(PK; Origen, "No. Documento", "No. Producto", "Cod. Variante", "No. Lote", "Cod. Unidad Medida")
        {
            Clustered = true;
        }
        key(Pendientes; Ubicado, "Ubicacion Propuesta")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No. Documento", "No. Producto", "No. Lote")
        {
        }
    }

    /// <summary>
    /// Cantidad que todavía falta por colocar.
    /// </summary>
    procedure Pendiente(): Decimal
    begin
        if "Cantidad Entrada" - "Cantidad Ya Ubicada" < 0 then
            exit(0);

        exit("Cantidad Entrada" - "Cantidad Ya Ubicada");
    end;

    /// <summary>
    /// Expresión de estilo para la pantalla.
    /// </summary>
    procedure Estilo(): Text
    begin
        if Ubicado then
            exit('Favorable');

        if "Ubicacion Propuesta" = '' then
            exit('Attention');

        exit('Standard');
    end;
}
