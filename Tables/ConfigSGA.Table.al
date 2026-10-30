namespace AntonioNadal.SGA;

using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Warehouse.Structure;
using System.Security.User;

/// <summary>
/// Table Config. SGA (ID 51104).
/// Configuración única del módulo SGA.
///
/// Los campos de estrategia y de confirmación por escaneo se configuran aquí en la Fase 1
/// y los consumen los motores de ubicación y picking (Fase 2) y las páginas de PDA (Fase 3).
/// </summary>
table 51104 "Config. SGA"
{
    Caption = 'Configuración SGA';
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Clave primaria';
            DataClassification = ToBeClassified;
        }
        field(10; "Almacen por Defecto"; Code[10])
        {
            Caption = 'Almacén por defecto';
            DataClassification = ToBeClassified;
            TableRelation = Location;
            ToolTip = 'Almacén que se propone en las consultas y el mapa, y sobre el que se resuelven las ubicaciones por defecto de esta configuración.';
        }
        field(20; "Ubic. Recepcion Compras"; Code[20])
        {
            Caption = 'Ubic. recepción compras';
            DataClassification = ToBeClassified;
            TableRelation = Bin.Code where("Location Code" = field("Almacen por Defecto"));
            ToolTip = 'Ubicación de muelle donde queda la mercancía de compra hasta que se ubica.';
        }
        field(21; "Ubic. Entrada Produccion"; Code[20])
        {
            Caption = 'Ubic. entrada producción';
            DataClassification = ToBeClassified;
            TableRelation = Bin.Code where("Location Code" = field("Almacen por Defecto"));
            ToolTip = 'Ubicación donde se deposita el producto terminado de fabricación propia hasta que se ubica.';
        }
        field(22; "Ubic. Expedicion"; Code[20])
        {
            Caption = 'Ubic. expedición';
            DataClassification = ToBeClassified;
            TableRelation = Bin.Code where("Location Code" = field("Almacen por Defecto"));
            ToolTip = 'Ubicación de muelle de salida donde se concentra lo recogido para servir.';
        }
        field(23; "Ubic. Desbordamiento"; Code[20])
        {
            Caption = 'Ubic. desbordamiento';
            DataClassification = ToBeClassified;
            TableRelation = Bin.Code where("Location Code" = field("Almacen por Defecto"));
            ToolTip = 'Ubicación donde el motor deja la mercancía cuando no encuentra hueco válido.';
        }
        field(24; "Ubic. Ajustes"; Code[20])
        {
            Caption = 'Ubic. ajustes';
            DataClassification = ToBeClassified;
            TableRelation = Bin.Code where("Location Code" = field("Almacen por Defecto"));
            ToolTip = 'Ubicación contrapartida de los ajustes y descuadres detectados en la conciliación.';
        }
        field(30; "Estrategia Ubicacion"; Enum "Estrategia Ubicacion SGA")
        {
            Caption = 'Estrategia ubicación';
            DataClassification = ToBeClassified;
        }
        field(34; "Estrategia Ubic. Ensamblados"; Enum "Estrategia Ubicacion SGA")
        {
            Caption = 'Estrategia ubicación ensamblados';
            DataClassification = ToBeClassified;
            InitValue = "Solo Hueco Vacio";
            ToolTip = 'Cómo se propone el hueco para lo que sale de un ensamblado. Por defecto solo huecos vacíos; cámbielo si prefiere la misma estrategia que el resto de entradas.';
        }
        field(35; "Estrategia Ubic. Compras"; Enum "Estrategia Ubicacion SGA")
        {
            Caption = 'Estrategia ubicación compras';
            DataClassification = ToBeClassified;
            ToolTip = 'Cómo se propone el hueco para lo que llega en una recepción de compra. Por defecto la estándar: la casa del producto, si no consolidar y si no el primer hueco libre.';
        }
        field(31; "Estrategia Picking"; Enum "Estrategia Picking SGA")
        {
            Caption = 'Estrategia picking';
            DataClassification = ToBeClassified;
        }
        field(37; "Tipo Ubic. Nuevas"; Enum "Tipo UM SGA")
        {
            Caption = 'Tipo de hueco al generar';
            DataClassification = ToBeClassified;
            InitValue = Pale;
            ToolTip = 'Qué admiten las ubicaciones que se crean con "Generar ubicaciones": Palé, Caja o Unidad. Los huecos de caja o de unidades sueltas se suelen configurar después en su ficha.';
        }
        field(40; "Control Capacidad"; Enum "Control Capacidad SGA")
        {
            Caption = 'Control capacidad';
            DataClassification = ToBeClassified;
            ToolTip = 'Qué hacer cuando una entrada supera la capacidad declarada de la ubicación.';
        }
        field(41; "Permitir Cantidad Negativa"; Boolean)
        {
            Caption = 'Permitir cantidad negativa';
            DataClassification = ToBeClassified;
            ToolTip = 'Si está activo, se admite sacar de una ubicación más de lo que consta. Solo para arranques con datos incompletos.';
        }
        field(42; "Exigir Confirmar Ubicacion"; Boolean)
        {
            Caption = 'Exigir confirmar ubicación';
            DataClassification = ToBeClassified;
            InitValue = true;
            ToolTip = 'Obliga al operario a escanear la ubicación para cerrar la tarea.';
        }
        field(43; "Permitir Desvio Ubicacion"; Boolean)
        {
            Caption = 'Permitir desvío ubicación';
            DataClassification = ToBeClassified;
            InitValue = true;
            ToolTip = 'Permite al operario dejar o coger la mercancía en una ubicación distinta de la sugerida, quedando registrado el desvío.';
        }
        field(45; "Exigir Asignacion Picking"; Boolean)
        {
            Caption = 'Exigir asignación de picking';
            DataClassification = ToBeClassified;
            ToolTip = 'Si está activo, las órdenes de picking nacen pendientes de asignar y solo las puede preparar el preparador al que un responsable se las asigne en "Asignar órdenes de picking". Si no, cada preparador coge la siguiente sin asignar.';
        }
        field(46; "Exigir Digito Control"; Boolean)
        {
            Caption = 'Exigir dígito de control al recoger';
            DataClassification = ToBeClassified;
            ToolTip = 'Si está activo, al confirmar cada parada de picking el preparador tiene que teclear el dígito de control impreso en la etiqueta del hueco del que recoge. Certifica que está delante del hueco. Requiere haber impreso las etiquetas de ubicación.';
        }
        field(44; "Dias Aviso Caducidad"; Integer)
        {
            Caption = 'Días aviso caducidad';
            DataClassification = ToBeClassified;
            MinValue = 0;
            ToolTip = 'Días de antelación con los que se avisa de un lote próximo a caducar.';
        }
        field(50; "Nos. Orden SGA"; Code[20])
        {
            Caption = 'Nºs orden SGA';
            DataClassification = ToBeClassified;
            TableRelation = "No. Series";
            ToolTip = 'Serie numérica de las órdenes de trabajo de almacén. La consume la gestión de órdenes de la Fase 2.';
        }
        field(60; "Crear Ubicacion SGA Auto"; Boolean)
        {
            Caption = 'Crear datos SGA automáticamente';
            DataClassification = ToBeClassified;
            InitValue = true;
            ToolTip = 'Crea la fila de datos SGA la primera vez que se usa una ubicación de la topología. Si se desactiva, la ubicación debe estar dada de alta previamente.';
        }
        field(70; "Columnas Mapa"; Integer)
        {
            Caption = 'Columnas mapa';
            DataClassification = ToBeClassified;
            InitValue = 31;
            MinValue = 1;
            MaxValue = 32;
            ToolTip = 'Número de columnas (huecos) que muestra el mapa por estantería. Máximo 32.';
        }
        field(80; "Dias Analisis ABC"; Integer)
        {
            Caption = 'Días de ventas del análisis ABC';
            DataClassification = ToBeClassified;
            InitValue = 90;
            MinValue = 1;
            ToolTip = 'Cuántos días de ventas, contando hasta hoy, se miran para clasificar los productos por rotación.';
        }
        field(81; "Corte ABC Clase A"; Decimal)
        {
            Caption = 'Corte clase A (%)';
            DataClassification = ToBeClassified;
            InitValue = 80;
            MinValue = 1;
            MaxValue = 100;
            DecimalPlaces = 0 : 1;
            ToolTip = 'Son A los productos que, de más a menos vendido, suman hasta este % de los palés salidos.';
        }
        field(82; "Corte ABC Clase B"; Decimal)
        {
            Caption = 'Corte clase B (%)';
            DataClassification = ToBeClassified;
            InitValue = 95;
            MinValue = 1;
            MaxValue = 100;
            DecimalPlaces = 0 : 1;
            ToolTip = 'Son B los productos que siguen a los A hasta este % de los palés salidos. El resto son C.';
        }
        field(83; "Cajas Minimas Hueco Pale"; Integer)
        {
            Caption = 'Cajas mínimas para hueco de palé';
            DataClassification = ToBeClassified;
            InitValue = 10;
            MinValue = 1;
            ToolTip = 'Las cajas sueltas de una referencia se proponen en un hueco de palé a partir de esta cantidad; por debajo, en un hueco de caja.';
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
    /// Devuelve la configuración, creándola vacía la primera vez.
    /// </summary>
    procedure ObtenerConfig()
    begin
        if not Get() then begin
            Init();
            Insert(true);
        end;
    end;

    /// <summary>
    /// Clase SGA de una unidad para un producto concreto. Sale solo de la ficha del producto,
    /// sin configurar nada en las unidades de medida:
    ///   - Unidad: la unidad base (1 unidad), las unidades sueltas;
    ///   - Palé: el "Cód. palé por defecto", y cualquier unidad que lleve al menos lo mismo;
    ///   - Caja: la unidad de venta, si lleva más de una unidad y menos que el palé.
    /// Cualquier otra unidad queda sin clase: no se le propone hueco y el motivo lo explica.
    /// </summary>
    procedure TipoUMProducto(prm_Producto: Code[20]; prm_UM: Code[10]): Enum "Tipo UM SGA"
    var
        rItem: Record Item;
        rItemUM: Record "Item Unit of Measure";
        factor: Decimal;
        factorPale: Decimal;
    begin
        if (prm_Producto = '') or (prm_UM = '') then
            exit("Tipo UM SGA"::" ");
        if not rItemUM.Get(prm_Producto, prm_UM) then
            exit("Tipo UM SGA"::" ");
        factor := rItemUM."Qty. per Unit of Measure";
        if factor <= 1 then
            exit("Tipo UM SGA"::Unidad);
        if not rItem.Get(prm_Producto) then
            exit("Tipo UM SGA"::" ");

        factorPale := FactorUMProducto(prm_Producto, rItem."Cod. Pale por Defecto");
        if (prm_UM = rItem."Cod. Pale por Defecto") or ((factorPale > 1) and (factor >= factorPale)) then
            exit("Tipo UM SGA"::Pale);
        if prm_UM = rItem."Sales Unit of Measure" then
            exit("Tipo UM SGA"::Caja);
        exit("Tipo UM SGA"::" ");
    end;

    /// <summary>
    /// Si un hueco que admite prm_Tipo acepta mercancía de prm_Producto en prm_UM. Es lo que se
    /// valida al dejar algo en un hueco, también cuando el operario elige otro distinto del
    /// propuesto. Con la UM en blanco se entiende la base del producto.
    ///   - Palé: el palé y también cajas de la misma referencia (un palé incompleto). Que sea de
    ///     una sola referencia lo garantiza "Acepta múltiples productos", que en palé va apagado.
    ///   - Caja: solo cajas, de cualquier referencia.
    ///   - Unidad: solo unidades sueltas.
    ///   - En blanco (sin configurar): cualquier cosa menos unidades sueltas, que solo van a
    ///     huecos de Unidad. Estos huecos no se proponen nunca (ver TipoHuecoDestino).
    /// </summary>
    procedure UMAdmitida(prm_Producto: Code[20]; prm_Tipo: Enum "Tipo UM SGA"; prm_UM: Code[10]): Boolean
    var
        rItem: Record Item;
        clase: Enum "Tipo UM SGA";
    begin
        if prm_UM = '' then
            if rItem.Get(prm_Producto) then
                prm_UM := rItem."Base Unit of Measure";
        clase := TipoUMProducto(prm_Producto, prm_UM);

        case prm_Tipo of
            prm_Tipo::Pale:
                exit(clase in [clase::Pale, clase::Caja]);
            prm_Tipo::" ":
                exit(clase <> clase::Unidad);
            else
                exit(clase = prm_Tipo);
        end;
    end;

    /// <summary>
    /// Clase de hueco que se propone para una cantidad: el palé a palé, las unidades sueltas a
    /// Unidad, y las cajas a Caja si son menos de "Cajas Minimas Hueco Pale" o a Palé (palé
    /// incompleto de una referencia) si son esas o más. En blanco si la unidad no tiene clase:
    /// entonces no se propone ningún hueco.
    /// </summary>
    procedure TipoHuecoDestino(prm_Producto: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal): Enum "Tipo UM SGA"
    var
        rItem: Record Item;
        clase: Enum "Tipo UM SGA";
    begin
        if prm_UM = '' then
            if rItem.Get(prm_Producto) then
                prm_UM := rItem."Base Unit of Measure";
        clase := TipoUMProducto(prm_Producto, prm_UM);
        if clase <> clase::Caja then
            exit(clase);

        ObtenerConfig();
        if "Cajas Minimas Hueco Pale" <= 0 then
            "Cajas Minimas Hueco Pale" := 10;
        if prm_Cantidad < "Cajas Minimas Hueco Pale" then
            exit(clase::Caja);
        exit(clase::Pale);
    end;

    /// <summary>
    /// La unidad del producto de la clase indicada, de su ficha: Palé → "Cód. palé por defecto",
    /// Caja → unidad de venta, Unidad → unidad base. En blanco si no la tiene o no es de esa
    /// clase (por ejemplo, una unidad de venta que es la base).
    /// </summary>
    procedure UMProductoDeTipo(prm_Producto: Code[20]; prm_Tipo: Enum "Tipo UM SGA"): Code[10]
    var
        rItem: Record Item;
        um: Code[10];
    begin
        if not rItem.Get(prm_Producto) then
            exit('');

        case prm_Tipo of
            prm_Tipo::Pale:
                um := rItem."Cod. Pale por Defecto";
            prm_Tipo::Caja:
                um := rItem."Sales Unit of Measure";
            prm_Tipo::Unidad:
                um := rItem."Base Unit of Measure";
            else
                exit('');
        end;

        if um = '' then
            exit('');
        if TipoUMProducto(prm_Producto, um) <> prm_Tipo then
            exit('');
        exit(um);
    end;

    /// <summary>
    /// Unidades base de una UM del producto. Cero si el producto no tiene esa unidad.
    /// </summary>
    local procedure FactorUMProducto(prm_Producto: Code[20]; prm_UM: Code[10]): Decimal
    var
        rItemUM: Record "Item Unit of Measure";
    begin
        if (prm_UM = '') or not rItemUM.Get(prm_Producto, prm_UM) then
            exit(0);
        exit(rItemUM."Qty. per Unit of Measure");
    end;

    /// <summary>
    /// UM en la que se mide la capacidad de un hueco para un producto concreto: en un hueco de
    /// palé, el palé de ese producto ("1 palé" son 200 o 300 según el producto); en uno de caja,
    /// su caja. En blanco (UM base) si el hueco admite cualquiera o el producto no tiene esa clase.
    /// </summary>
    procedure UMCapacidadProducto(prm_Producto: Code[20]; prm_Tipo: Enum "Tipo UM SGA"): Code[10]
    begin
        exit(UMProductoDeTipo(prm_Producto, prm_Tipo));
    end;

    /// <summary>
    /// Con "Exigir Asignacion Picking", solo un responsable de picking (marcado en
    /// Configuración de usuarios) puede repartir órdenes o cambiar su prioridad. Sin ella, el
    /// reparto es libre, igual que el preparador se asigna solo las que coge.
    ///
    /// Se comprueba por código y no solo con el conjunto de permisos porque los conjuntos
    /// estándar de BC suelen dar ejecución sobre todas las páginas.
    /// </summary>
    procedure ComprobarResponsablePicking()
    var
        rUserSetup: Record "User Setup";
        NoResponsablePickingErr: Label 'Solo un responsable de picking puede asignar órdenes o cambiar su prioridad. Pida que le marquen "Responsable picking SGA" en Configuración de usuarios.';
    begin
        ObtenerConfig();
        if not "Exigir Asignacion Picking" then
            exit;

        if rUserSetup.Get(UserId()) then
            if rUserSetup."Responsable Picking SGA" then
                exit;

        Error(NoResponsablePickingErr);
    end;

    /// <summary>
    /// Comprueba que la ubicación indicada está configurada; si no, lanza error indicando el campo.
    /// </summary>
    procedure TestUbicacionConfigurada(prm_Ubicacion: Code[20]; prm_NombreCampo: Text)
    var
        CampoSinConfigurarErr: Label 'Debe configurar %1 en la configuración de SGA.', Comment = '%1 = nombre del campo';
    begin
        if prm_Ubicacion = '' then
            Error(CampoSinConfigurarErr, prm_NombreCampo);
    end;
}
