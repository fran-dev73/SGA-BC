namespace AntonioNadal.SGA;

using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Location;
using Microsoft.Warehouse.Structure;

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
        field(12; "Zona por Defecto"; Code[10])
        {
            Caption = 'Zona por defecto';
            DataClassification = ToBeClassified;
            TableRelation = "Zona SGA".Code where("Cod. Almacen" = field("Almacen por Defecto"));
            ToolTip = 'Zona que se propone en las consultas y el mapa, y sobre la que se resuelven las ubicaciones por defecto de esta configuración.';
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
            InitValue = Bloquear;
            ToolTip = 'Qué hacer cuando una entrada supera la capacidad de una ubicación que tiene "Control capacidad" = Según configuración: bloquearla, o avisar y dejar seguir si se confirma. Cada ubicación puede llevar el suyo. La capacidad se controla siempre.';
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
            ObsoleteState = Removed;
            ObsoleteReason = 'El mapa enseña siempre las columnas que existen, hasta el tope de la rejilla.';
            ObsoleteTag = 'SGA';
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
            Caption = 'Clase A: del 0 % hasta (%)';
            DataClassification = ToBeClassified;
            InitValue = 80;
            MinValue = 1;
            MaxValue = 100;
            DecimalPlaces = 0 : 1;
            ToolTip = 'Los productos se ordenan de más a menos palés salidos y se van sumando. Son A los que se suman desde el 0 % hasta este % acumulado. Con 80, los A mueven el 80 % de los palés.';
        }
        field(82; "Corte ABC Clase B"; Decimal)
        {
            Caption = 'Clase B: desde la A hasta (%)';
            DataClassification = ToBeClassified;
            InitValue = 95;
            MinValue = 1;
            MaxValue = 100;
            DecimalPlaces = 0 : 1;
            ToolTip = 'Son B los productos que siguen a los A, desde el corte de la A hasta este % acumulado; el resto, hasta el 100 %, son C. Es acumulado, así que no puede ser menor que el de la A. Con A 80 y B 95: A mueven el 80 %, B el 15 % y C el 5 %.';
        }
        field(83; "Cajas Minimas Hueco Pale"; Integer)
        {
            Caption = 'Cajas mínimas para hueco de palé';
            DataClassification = ToBeClassified;
            InitValue = 10;
            MinValue = 1;
            ToolTip = 'Las cajas sueltas de una referencia se proponen en un hueco de palé a partir de esta cantidad; por debajo, en un hueco de caja.';
        }
        field(84; "Reubicar Pale A por ABC"; Boolean)
        {
            Caption = 'Proponer reubicar palés A al ubicar';
            DataClassification = ToBeClassified;
            ToolTip = 'Si está activo, al ubicar una entrada se propone trasladar un palé de clase A que esté lejos de la salida a un hueco libre más cercano, antes de buscar el hueco de la entrada. Requiere haber calculado el análisis ABC. Desactivado, la ubicación sigue el orden de recorrido como siempre.';
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
    /// Regla de desvío: dejar o coger en una ubicación distinta de la propuesta solo se admite
    /// con "Permitir Desvio Ubicacion". Ir a la propuesta siempre está permitido. Cada llamador
    /// decide qué hace si no se permite (error o aviso). Trabaja sobre la configuración ya
    /// leída con ObtenerConfig, para no volver a leerla en cada línea de un bucle.
    /// </summary>
    procedure DesvioPermitido(prm_Propuesta: Code[20]; prm_Confirmada: Code[20]): Boolean
    begin
        exit("Permitir Desvio Ubicacion" or (prm_Confirmada = prm_Propuesta));
    end;

    /// <summary>
    /// Qué parte de los palés salidos mueve cada clase con los cortes actuales, que son
    /// acumulados: con 80 y 95, "A 80 % · B 15 % · C 5 %".
    /// </summary>
    procedure RepartoABC(): Text
    var
        RepartoABCLbl: Label 'A %1 % · B %2 % · C %3 %', Comment = '%1 = parte de la A, %2 = parte de la B, %3 = parte de la C';
        CortesABCMalLbl: Label 'El corte de la B tiene que ser mayor o igual que el de la A.';
    begin
        if "Corte ABC Clase B" < "Corte ABC Clase A" then
            exit(CortesABCMalLbl);
        exit(StrSubstNo(RepartoABCLbl, "Corte ABC Clase A", "Corte ABC Clase B" - "Corte ABC Clase A", 100 - "Corte ABC Clase B"));
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
