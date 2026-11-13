namespace AntonioNadal.SGA;

using Microsoft.Warehouse.Structure;

/// <summary>
/// Table Linea Ubicacion SGA (ID 51114).
/// Un trozo de mercancía a ubicar, con su unidad, el hueco propuesto, el que se confirma y si se
/// ha podido ubicar o por qué no. Es la tabla única de "trozo a ubicar"; Origen dice para qué es
/// cada línea:
/// - Manual: el reparto de "Ubicar producto" (cada palé y el resto).
/// - "Carga Inicial": el resultado de la carga inicial y de "Ubicar seleccionadas".
/// - Compra y Produccion: lo que ha entrado en "Ubicar entradas" (un ensamblado, o un producto,
///   variante, lote y unidad de un albarán de compra) y el palé de una tarea en "Imprimir y
///   ubicar palés". Estas líneas llevan además el documento, la cantidad que entró y la ya
///   ubicada; Cantidad es lo que se va a ubicar ahora.
///
/// Es temporal: solo vive en memoria mientras se usa. Lo ya ubicado de una entrada no se guarda
/// aquí: se deduce del diario de movimientos cada vez que se carga. En la simulación de la carga
/// inicial es lo único que queda, porque los movimientos se deshacen y las tablas temporales no
/// entran en esa vuelta atrás.
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
            ToolTip = 'Número de la línea, en el orden en que se ha repartido o cargado.';
            DataClassification = ToBeClassified;
        }
        field(2; Origen; Enum "Origen Mov. SGA")
        {
            Caption = 'Origen';
            ToolTip = 'Para qué es la línea: Manual en "Ubicar producto", Carga inicial en la carga inicial y en "Ubicar seleccionadas", Compra o Producción en "Ubicar entradas" y en el palé de una tarea.';
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
            ToolTip = 'Cantidad, en la unidad de la línea. En las entradas, lo que se va a colocar ahora.';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
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
        // Largo para que quepa la lectura entera de la etiqueta (GS1-128 con más datos que el SSCC);
        // al validar se queda solo el SSCC (SSCCPale).
        field(28; SSCC; Code[100])
        {
            Caption = 'SSCC';
            ToolTip = 'Código del palé (SSCC). Escanee la etiqueta del palé; si no la tiene, se genera uno al ubicar.';
            DataClassification = ToBeClassified;

            trigger OnValidate()
            var
                cLectura: Codeunit "Lectura Codigos SGA";
            begin
                SSCC := cLectura.SSCCLeido(SSCC);
            end;
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
            // Las entradas (Compra y Produccion) no llevan relación ni búsqueda: el hueco se escanea o
            // se teclea. El resto conserva la búsqueda y la validación estándar de la relación con Bin.
            TableRelation = if (Origen = filter(<> Compra & <> Produccion)) Bin.Code where("Location Code" = field("Cod. Almacen"));

            trigger OnValidate()
            var
                cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
            begin
                cUbicaciones.ComprobarUbicacionExiste("Cod. Almacen", "Ubicacion Confirmada");

                // En las entradas, el hueco elegido a mano queda reservado para la fila y el que
                // tenía se suelta. Uno reservado para otra entrada no se puede elegir.
                if ReservaFila() = '' then
                    exit;
                if "Ubicacion Confirmada" = '' then
                    cUbicaciones.LiberarReservas(ReservaFila(), '')
                else
                    cUbicaciones.TestReservarHueco("Cod. Almacen", "Ubicacion Confirmada", ReservaFila());
            end;
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
        field(50; "No. Documento"; Code[20])
        {
            Caption = 'Nº documento';
            ToolTip = 'Ensamblado o albarán de compra del que viene la mercancía.';
            DataClassification = ToBeClassified;
        }
        field(51; "Documento Relacionado"; Code[20])
        {
            Caption = 'Documento relacionado';
            ToolTip = 'Otro número con el que esta misma entrada puede estar ya ubicada. En los ensamblados, el del pedido sin registrar: los palés que se ubican al imprimir su etiqueta van con ese número.';
            DataClassification = ToBeClassified;
        }
        field(52; "Descripcion Origen"; Text[100])
        {
            Caption = 'Procedencia';
            ToolTip = 'Proveedor de la recepción. En los ensamblados va en blanco.';
            DataClassification = ToBeClassified;
        }
        field(53; "Fecha Registro"; Date)
        {
            Caption = 'Fecha registro';
            ToolTip = 'Fecha de registro del albarán o del ensamblado.';
            DataClassification = ToBeClassified;
        }
        field(60; "Cantidad Entrada"; Decimal)
        {
            Caption = 'Cantidad entrada';
            ToolTip = 'Cantidad que ha entrado: la ensamblada, o la recibida neta de deshacer recepciones.';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
        }
        field(61; "Cantidad Ya Ubicada"; Decimal)
        {
            Caption = 'Ya ubicada';
            ToolTip = 'Cantidad de esta entrada que SGA ya tiene colocada en ubicaciones.';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
        }
    }

    keys
    {
        key(PK; Linea)
        {
            Clustered = true;
        }
        // Una entrada por documento, producto, variante, lote y unidad: un albarán de compra
        // puede traer el mismo producto en varios lotes y unidades, y cada combinación va a su
        // hueco. La unicidad la asegura quien carga (Cod. "Gestion Entradas SGA").
        key(Documento; Origen, "No. Documento", "No. Producto", "Cod. Variante", "No. Lote", "Cod. Unidad Medida")
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
    /// A nombre de quién se reservan los huecos de esta fila (Cod. "Gestion Ubicaciones
    /// SGA".ReservarHueco): la entrada y su línea, que es lo que ve quien mira la ubicación.
    /// Solo las entradas (compra y producción) reservan; el resto, en blanco.
    /// </summary>
    procedure ReservaFila(): Text
    var
        ReservaFilaLbl: Label '%1 %2, línea %3', Comment = '%1 = origen, %2 = nº documento, %3 = línea';
    begin
        if not (Origen in [Origen::Compra, Origen::Produccion]) then
            exit('');
        exit(StrSubstNo(ReservaFilaLbl, Origen, "No. Documento", Linea));
    end;

    /// <summary>
    /// SSCC de la línea, ya validado. Si no se ha leído ninguno, da uno nuevo y lo deja en la
    /// línea: todo palé que se ubica lleva su SSCC.
    /// </summary>
    procedure SSCCPale(): Code[20]
    var
        cLectura: Codeunit "Lectura Codigos SGA";
    begin
        if SSCC = '' then
            SSCC := cLectura.NuevoSSCC();
        exit(CopyStr(SSCC, 1, 20));
    end;

    /// <summary>
    /// Cantidad de una entrada que todavía falta por colocar.
    /// </summary>
    procedure Pendiente(): Decimal
    begin
        if "Cantidad Entrada" - "Cantidad Ya Ubicada" < 0 then
            exit(0);

        exit("Cantidad Entrada" - "Cantidad Ya Ubicada");
    end;

    /// <summary>
    /// Expresión de estilo de la línea: verde si ya está ubicada, rojo si no tiene sitio,
    /// destacada si aún no tiene hueco propuesto y normal si está pendiente con su hueco.
    /// </summary>
    procedure EstiloEstado(): Text
    begin
        case Estado of
            Estado::Ubicado:
                exit('Favorable');
            Estado::"Sin Sitio":
                exit('Unfavorable');
        end;

        if "Ubicacion Propuesta" = '' then
            exit('Attention');

        exit('Standard');
    end;

    /// <summary>
    /// Estilo de la línea en el resultado de la carga inicial: normal si se ha cargado
    /// (Ubicado) y en rojo si no.
    /// </summary>
    procedure EstiloCargaInicial(): Text
    begin
        if Estado = Estado::Ubicado then
            exit('Standard');

        exit('Unfavorable');
    end;
}
