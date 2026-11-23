namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Warehouse.Structure;

/// <summary>
/// Table Ubicacion SGA (ID 51101).
/// Atributos de gestión de almacén de un Bin: zona SGA, tipo, capacidad, bloqueo,
/// reglas de mezcla y estado de ocupación.
///
/// Es una tabla compañera 1:1 de la tabla estándar Bin (7302) en lugar de una
/// tableextension porque AL no permite extender objetos definidos en la propia app.
/// Si falta la fila de un Bin, el primer movimiento la da de alta sincronizando la topología
/// (Cod. "Gestion Contenido SGA"), de modo que SGA es puramente aditivo y la topología
/// estándar no se toca.
///
/// "Estado SGA" y "% Ocupacion" están persistidos (no son FlowField) para poder contar y
/// filtrar ubicaciones vacías/llenas sin recorrer el contenido. Los mantiene
/// Cod. "Gestion Contenido SGA" y se reconstruyen con Rep. "Sincronizar Ubicaciones SGA".
/// </summary>
table 51101 "Ubicacion SGA"
{
    Caption = 'Ubicación SGA';
    DataClassification = ToBeClassified;
    LookupPageId = "Ubicaciones SGA";
    DrillDownPageId = "Ubicaciones SGA";

    fields
    {
        field(10; "Cod. Almacen"; Code[10])
        {
            Caption = 'Cód. almacén';
            DataClassification = ToBeClassified;
            TableRelation = Location;
            NotBlank = true;
        }
        field(20; "Cod. Bin"; Code[20])
        {
            Caption = 'Cód. ubicación';
            DataClassification = ToBeClassified;
            NotBlank = true;
            TableRelation = Bin.Code where("Location Code" = field("Cod. Almacen"));
            // El alta a mano escribe un código nuevo: su Bin lo crea OnInsert (CompletarAlta).
            ValidateTableRelation = false;

            trigger OnValidate()
            var
                cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
            begin
                // Al teclearlo (alta a mano), con el formato y los rangos de Generar ubicaciones.
                cUbicaciones.ComprobarCodigoUbicacion("Cod. Bin");
            end;
        }
        field(30; Descripcion; Text[100])
        {
            Caption = 'Descripción';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup(Bin.Description where("Location Code" = field("Cod. Almacen"), Code = field("Cod. Bin")));
            ToolTip = 'Descripción de la ubicación: es la de su ubicación de BC (ficha del almacén > Ubicaciones), y se cambia allí. Al crearla es el código.';
        }
        field(40; "Cod. Zona SGA"; Code[10])
        {
            Caption = 'Cód. zona';
            DataClassification = ToBeClassified;
            TableRelation = "Zona SGA".Code where("Cod. Almacen" = field("Cod. Almacen"));

            trigger OnValidate()
            var
                rZona: Record "Zona SGA";
            begin
                TestVacia();
                rZona.ComprobarAdmiteUbicaciones("Cod. Almacen", "Cod. Zona SGA");
                // Una zona bloqueada bloquea sus ubicaciones.
                RecalcularOcupacion();
            end;
        }
        field(50; "Tipo Ubicacion"; Enum "Tipo Ubicacion SGA")
        {
            Caption = 'Tipo ubicación';
            DataClassification = ToBeClassified;
            ToolTip = 'Almacenamiento: reserva, es la primera que se busca al ubicar. Picking: de donde se prepara; se busca al ubicar si no queda sitio en almacenamiento y se repone desde almacenamiento con las reposiciones. En blanco (muelles, ajustes…): no se propone ni se repone.';

            trigger OnValidate()
            begin
                TestVacia();
            end;
        }
        field(60; "Secuencia Picking"; Integer)
        {
            Caption = 'Secuencia picking';
            DataClassification = ToBeClassified;
            ToolTip = 'Orden de recorrido físico. Los motores de picking y de ubicación recorren las ubicaciones por este valor.';

            trigger OnValidate()
            begin
                TestVacia();
            end;
        }
        field(70; "Capacidad Uds."; Decimal)
        {
            Caption = 'Capacidad (palés)';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            ToolTip = 'Cuántos palés caben. Lo que hay se cuenta con el palé por defecto de cada producto: medio palé de un producto ocupa 0,5. 0 = sin límite declarado.';

            trigger OnValidate()
            begin
                TestVacia();
                RecalcularOcupacion();
            end;
        }
        field(74; "Control Capacidad"; Enum "Control Capacidad Ubic. SGA")
        {
            Caption = 'Control capacidad';
            DataClassification = ToBeClassified;
            ToolTip = 'Qué hacer cuando una entrada no cabe en esta ubicación: lo que diga la configuración de SGA, avisar (y dejar seguir si se confirma) o bloquear. Como el resto de su configuración, solo se cambia con la ubicación vacía.';

            trigger OnValidate()
            begin
                TestVacia();
            end;
        }
        field(80; Bloqueada; Boolean)
        {
            Caption = 'Bloqueada';
            DataClassification = ToBeClassified;
            ToolTip = 'La ubicación no se propone ni admite movimientos mientras esté bloqueada.';

            trigger OnValidate()
            begin
                if not Bloqueada then
                    "Motivo Bloqueo" := '';
                RecalcularOcupacion();
            end;
        }
        field(81; "Motivo Bloqueo"; Text[50])
        {
            Caption = 'Motivo bloqueo';
            DataClassification = ToBeClassified;
            ToolTip = 'Por qué está bloqueada la ubicación. Se escribe en la ficha con la ubicación bloqueada y se borra al desbloquearla.';
        }
        field(90; "Permite Mezcla Producto"; Boolean)
        {
            Caption = 'Permite mezcla de productos';
            DataClassification = ToBeClassified;
            InitValue = true;
            ToolTip = 'Si está marcado, la ubicación puede contener productos distintos (una estantería de picking con varias referencias). Sin marcar, un solo producto, como un hueco de palé.';

            trigger OnValidate()
            begin
                TestVacia();
            end;
        }
        field(91; "Permite Mezcla Lote"; Boolean)
        {
            Caption = 'Permite mezcla de lotes';
            DataClassification = ToBeClassified;
            InitValue = true;
            ToolTip = 'Si está desactivado, la ubicación solo puede contener un lote a la vez.';

            trigger OnValidate()
            begin
                TestVacia();
            end;
        }
        field(92; Fondo; Boolean)
        {
            Caption = 'Fondo de pasillo';
            DataClassification = ToBeClassified;
            ToolTip = 'Ubicación a nivel de suelo al fondo del pasillo, con sitio para varios palés. Su posición (pasillo y estantería del código) no tiene alturas: no se puede marcar si ya las hay, ni crearlas mientras esté marcada.';

            trigger OnValidate()
            var
                cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
            begin
                if Fondo then
                    cUbicaciones.ComprobarPuedeSerFondo("Cod. Almacen", "Cod. Bin");
            end;
        }
        field(100; "Producto Fijo"; Code[20])
        {
            Caption = 'Producto fijo';
            DataClassification = ToBeClassified;
            TableRelation = Item;
            ToolTip = 'Producto que tiene esta ubicación como casa. Solo se admite este producto.';

            trigger OnValidate()
            begin
                TestVacia();
            end;
        }
        field(120; "Estado SGA"; Enum "Estado Ubicacion SGA")
        {
            Caption = 'Estado';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(121; "% Ocupacion"; Decimal)
        {
            Caption = '% ocupación';
            DataClassification = ToBeClassified;
            Editable = false;
            DecimalPlaces = 0 : 2;
            MinValue = 0;
            ToolTip = 'Porcentaje de la capacidad declarada que está ocupado: verde por debajo del 80 %, ámbar del 80 al 99 % y rojo desde el 100 %. Con capacidad 0 (sin límite), 0 y sin color.';
        }
        field(130; "Fecha Ultimo Movimiento"; DateTime)
        {
            Caption = 'Fecha último movimiento';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(150; "Cantidad Base"; Decimal)
        {
            Caption = 'Cantidad (UM base)';
            Editable = false;
            DecimalPlaces = 0 : 5;
            FieldClass = FlowField;
            CalcFormula = sum("Contenido Ubicacion SGA"."Cantidad Base" where("Cod. Almacen" = field("Cod. Almacen"),
                                                                              "Cod. Bin" = field("Cod. Bin")));
        }
        field(151; "Lineas Contenido"; Integer)
        {
            Caption = 'Líneas contenido';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Contenido Ubicacion SGA" where("Cod. Almacen" = field("Cod. Almacen"),
                                                                "Cod. Bin" = field("Cod. Bin")));
        }
        field(160; "Reservada Para"; Text[100])
        {
            Caption = 'Reservada para';
            DataClassification = ToBeClassified;
            Editable = false;
            ToolTip = 'Entrada para la que se ha propuesto este hueco y que aún no se ha ubicado: palé de producción, ensamblado o recepción de compra. Mientras tanto no se propone a nadie más. En blanco si no está reservada.';
        }
        field(161; "Reservada Por"; Code[50])
        {
            Caption = 'Reservada por';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
            ToolTip = 'Usuario que tiene la pantalla en la que se ha propuesto el hueco.';
        }
        field(162; "Fecha Reserva"; DateTime)
        {
            Caption = 'Fecha reserva';
            DataClassification = ToBeClassified;
            Editable = false;
            ToolTip = 'Cuándo se ha propuesto el hueco.';
        }
        field(163; "Sesion Reserva"; Integer)
        {
            Caption = 'Sesión reserva';
            DataClassification = SystemMetadata;
            Editable = false;
            ToolTip = 'Sesión de BC en la que se ha propuesto el hueco: la reserva es de esa pantalla.';
        }
    }

    keys
    {
        key(PK; "Cod. Almacen", "Cod. Bin")
        {
            Clustered = true;
        }
        key(Estado; "Cod. Almacen", "Estado SGA", "Secuencia Picking")
        {
        }
        key(Zona; "Cod. Almacen", "Cod. Zona SGA", "Secuencia Picking")
        {
        }
        // La de la propuesta: los huecos de un tipo, por ruta.
        key(Ubicar; "Cod. Almacen", "Tipo Ubicacion", "Secuencia Picking", "Cod. Bin")
        {
        }
        key(Ruta; "Cod. Almacen", "Secuencia Picking", "Cod. Bin")
        {
        }
        key(ProductoFijo; "Cod. Almacen", "Producto Fijo")
        {
        }
        key(Reservas; "Reservada Por", "Sesion Reserva", "Reservada Para")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Cod. Bin", Descripcion, "Estado SGA")
        {
        }
        fieldgroup(Brick; "Cod. Bin", Descripcion, "Estado SGA", "% Ocupacion")
        {
        }
    }

    trigger OnInsert()
    var
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
    begin
        // SGA es aditivo sobre la topología estándar: sin su Bin no hay ubicación. El alta a mano
        // (Nueva ubicación SGA) lo crea aquí; los demás caminos ya lo traen creado.
        cUbicaciones.CompletarAlta(Rec);
        RecalcularOcupacion();
    end;

    trigger OnRename()
    var
        RenombrarUbicacionErr: Label 'No se puede cambiar el almacén ni el código de una ubicación: su contenido y sus movimientos se quedarían con el código anterior.';
    begin
        Error(RenombrarUbicacionErr);
    end;

    /// <summary>
    /// Si la ubicación está reservada para otra entrada: de otro usuario, de otra sesión o para
    /// otra fila de la misma pantalla. Con prm_Para en blanco, cualquier reserva es de otro.
    /// </summary>
    procedure ReservadaParaOtro(prm_Para: Text): Boolean
    var
        rConfig: Record "Config. SGA";
    begin
        if "Reservada Por" = '' then
            exit(false);
        exit(("Reservada Por" <> rConfig.UsuarioActual()) or ("Sesion Reserva" <> SessionId()) or ("Reservada Para" <> prm_Para));
    end;

    /// <summary>
    /// Reserva la ubicación para prm_Para en esta sesión. False, sin tocarla, si ya está
    /// reservada para otro.
    /// </summary>
    procedure Reservar(prm_Para: Text): Boolean
    var
        rConfig: Record "Config. SGA";
    begin
        if ReservadaParaOtro(prm_Para) then
            exit(false);

        "Reservada Para" := CopyStr(prm_Para, 1, MaxStrLen("Reservada Para"));
        "Reservada Por" := rConfig.UsuarioActual();
        "Fecha Reserva" := CurrentDateTime();
        "Sesion Reserva" := SessionId();
        Modify();
        exit(true);
    end;

    /// <summary>
    /// Quita la reserva, sea de quien sea.
    /// </summary>
    procedure LiberarReserva()
    begin
        if "Reservada Por" = '' then
            exit;

        Clear("Reservada Para");
        Clear("Reservada Por");
        Clear("Fecha Reserva");
        Clear("Sesion Reserva");
        Modify();
    end;

    trigger OnDelete()
    var
        rContenido: Record "Contenido Ubicacion SGA";
        UbicacionConContenidoErr: Label 'No se pueden eliminar los datos SGA de la ubicación %1 porque todavía tiene contenido.', Comment = '%1 = ubicación';
    begin
        rContenido.FiltrarUbicacion("Cod. Almacen", "Cod. Bin");
        if not rContenido.IsEmpty() then
            Error(UbicacionConContenidoErr, "Cod. Bin");
        // Su Bin se borra con ella (BorrarBinConFicha de "Gestion Ubicaciones SGA").
    end;

    /// <summary>
    /// Recalcula "Estado SGA" y "% Ocupacion" a partir del contenido actual y de la
    /// capacidad declarada. No hace Modify: el llamante decide cuándo persistir.
    /// </summary>
    procedure RecalcularOcupacion()
    var
        ocupado: Decimal;
    begin
        CalcFields("Cantidad Base", "Lineas Contenido");

        // Lo ocupado en palés solo se calcula contra una capacidad declarada. Capacidad 0 es sin
        // límite: no se llena nunca y su % de ocupación queda a 0.
        "% Ocupacion" := 0;
        if "Capacidad Uds." > 0 then begin
            ocupado := OcupadoEnPales();
            "% Ocupacion" := Round(ocupado / "Capacidad Uds." * 100, 0.01);
        end;

        case true of
            // Bloqueada ella o su zona entera.
            not EsUtilizable():
                "Estado SGA" := "Estado SGA"::Bloqueada;
            "Lineas Contenido" = 0:
                "Estado SGA" := "Estado SGA"::Vacia;
            ("Capacidad Uds." > 0) and (ocupado >= "Capacidad Uds."):
                "Estado SGA" := "Estado SGA"::Llena;
            else
                "Estado SGA" := "Estado SGA"::Parcial;
        end;
    end;

    /// <summary>
    /// Lo que hay en el hueco, en palés. Cada línea se convierte con el palé de su producto,
    /// porque en el mismo hueco pueden convivir palés de 200 y de 300. Un producto sin palé
    /// cuenta en unidades base.
    /// </summary>
    procedure OcupadoEnPales(): Decimal
    var
        rContenido: Record "Contenido Ubicacion SGA";
        cUM: Codeunit "Unidades Producto SGA";
        factores: Dictionary of [Code[20], Decimal];
        factor: Decimal;
        total: Decimal;
    begin
        rContenido.FiltrarUbicacion("Cod. Almacen", "Cod. Bin");
        // Una línea en negativo (con "Permitir cantidad negativa") no libera sitio.
        rContenido.SetFilter("Cantidad Base", '>%1', 0);
        rContenido.SetLoadFields("No. Producto", "Cantidad Base");
        if not rContenido.FindSet() then
            exit(0);

        // Lo mismo que EnPales de cada línea, con el factor de cada producto leído una vez:
        // un hueco suele tener varias líneas (lotes) del mismo producto.
        repeat
            if not factores.Get(rContenido."No. Producto", factor) then begin
                factor := cUM.FactorPale(rContenido."No. Producto");
                factores.Add(rContenido."No. Producto", factor);
            end;
            total += rContenido."Cantidad Base" / factor;
        until rContenido.Next() = 0;

        exit(Round(total, 0.00001));
    end;

    /// <summary>
    /// Si, al no caber una entrada, se avisa (y se deja seguir confirmando) en vez de bloquear.
    /// Manda el control propio de la ubicación; con "Según configuración", el de "Config. SGA".
    /// Cualquier otro valor bloquea: la capacidad se controla siempre.
    /// </summary>
    procedure SoloAvisaCapacidad(): Boolean
    var
        rConfig: Record "Config. SGA";
    begin
        case "Control Capacidad" of
            "Control Capacidad"::Avisar:
                exit(true);
            "Control Capacidad"::Bloquear:
                exit(false);
        end;
        rConfig.ObtenerConfig();
        exit(rConfig."Control Capacidad" = rConfig."Control Capacidad"::Avisar);
    end;

    /// <summary>
    /// Si caben prm_Entrada palés más (EnPales), sin pasar de la capacidad. Sin capacidad declarada, siempre. Es la comprobación de la propuesta, que mira
    /// muchos huecos seguidos: parte del estado y del "% Ocupacion" guardados, que deja al día
    /// cada movimiento (RecalcularOcupacion), y solo suma el contenido línea a línea cuando el
    /// resultado cae tan cerca de la capacidad que el redondeo del % podría cambiarlo.
    /// </summary>
    procedure CabeEntrada(prm_Entrada: Decimal): Boolean
    var
        estimado: Decimal;
        margen: Decimal;
    begin
        if "Capacidad Uds." <= 0 then
            exit(true);
        // Llena: lo que hay ya llega a la capacidad.
        if "Estado SGA" = "Estado SGA"::Llena then
            exit(false);

        // El % va redondeado a 0,01: lo ocupado que da se aleja como mucho un 0,005 % de la
        // capacidad. El margen dobla eso.
        estimado := "% Ocupacion" * "Capacidad Uds." / 100;
        margen := "Capacidad Uds." * 0.0001;
        if estimado + prm_Entrada <= "Capacidad Uds." - margen then
            exit(true);
        if estimado + prm_Entrada > "Capacidad Uds." + margen then
            exit(false);

        exit(OcupadoEnPales() + prm_Entrada <= "Capacidad Uds.");
    end;

    /// <summary>
    /// Si la ubicación está reservada ("Producto fijo") a un producto distinto de prm_Producto.
    /// </summary>
    procedure FijaParaOtroProducto(prm_Producto: Code[20]): Boolean
    begin
        exit(("Producto Fijo" <> '') and ("Producto Fijo" <> prm_Producto));
    end;

    /// <summary>
    /// Qué contenido del hueco impide dejar en él prm_Producto con lote prm_Lote: 0 si nada,
    /// 5 si hay otro producto y el hueco no acepta mezcla de productos, 6 si hay otro lote y no
    /// acepta mezcla de lotes (los mismos códigos que el motivo de rechazo de la propuesta).
    /// Solo mira si existe una línea que choca, sin leerla: es la que usa la propuesta.
    /// </summary>
    procedure ContenidoQueImpideMezcla(prm_Producto: Code[20]; prm_Lote: Code[50]): Integer
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        exit(ComprobarMezcla(prm_Producto, prm_Lote, false, rContenido));
    end;

    /// <summary>
    /// Igual que ContenidoQueImpideMezcla sin contenido, pero deja en prm_Contenido la línea
    /// que choca, para poder nombrarla en el mensaje.
    /// </summary>
    procedure ContenidoQueImpideMezcla(prm_Producto: Code[20]; prm_Lote: Code[50]; var prm_Contenido: Record "Contenido Ubicacion SGA"): Integer
    begin
        exit(ComprobarMezcla(prm_Producto, prm_Lote, true, prm_Contenido));
    end;

    local procedure ComprobarMezcla(prm_Producto: Code[20]; prm_Lote: Code[50]; prm_LeerLinea: Boolean; var prm_Contenido: Record "Contenido Ubicacion SGA"): Integer
    begin
        prm_Contenido.Reset();
        prm_Contenido.FiltrarUbicacion("Cod. Almacen", "Cod. Bin");
        // Si hay que nombrar la línea que choca, solo hacen falta su producto y su lote.
        if prm_LeerLinea then
            prm_Contenido.SetLoadFields("No. Producto", "No. Lote");

        if not "Permite Mezcla Producto" then begin
            prm_Contenido.SetFilter("No. Producto", '<>%1', prm_Producto);
            if HayLineaQueChoca(prm_Contenido, prm_LeerLinea) then
                exit(5);
            prm_Contenido.SetRange("No. Producto");
        end;

        // El lote se mira en todo el hueco, sea del producto que sea.
        if not "Permite Mezcla Lote" then begin
            prm_Contenido.SetFilter("No. Lote", '<>%1', prm_Lote);
            if HayLineaQueChoca(prm_Contenido, prm_LeerLinea) then
                exit(6);
            prm_Contenido.SetRange("No. Lote");
        end;

        exit(0);
    end;

    local procedure HayLineaQueChoca(var prm_Contenido: Record "Contenido Ubicacion SGA"; prm_LeerLinea: Boolean): Boolean
    begin
        if prm_LeerLinea then
            exit(prm_Contenido.FindFirst());
        exit(not prm_Contenido.IsEmpty());
    end;

    /// <summary>
    /// Zona SGA de una ubicación. En blanco si la ubicación no existe o no tiene zona.
    /// </summary>
    procedure ZonaDe(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]): Code[10]
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        rUbicacionSGA.SetLoadFields("Cod. Zona SGA");
        if rUbicacionSGA.Get(prm_Almacen, prm_Ubicacion) then
            exit(rUbicacionSGA."Cod. Zona SGA");
        exit('');
    end;

    /// <summary>
    /// Si la ubicación no tiene nada dentro. Solo una ubicación vacía se puede reconfigurar.
    /// </summary>
    procedure EstaVacia(): Boolean
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        rContenido.FiltrarUbicacion("Cod. Almacen", "Cod. Bin");
        exit(rContenido.IsEmpty());
    end;

    /// <summary>
    /// Error si la ubicación tiene contenido. La configuración (tipo, capacidad, mezclas, zona,
    /// ruta, producto fijo, reposición) solo se cambia con la ubicación vacía: si no, lo que ya
    /// hay dentro podría dejar de cumplirla (dos palés en un hueco que pasa a ser de uno, dos
    /// productos en uno que deja de aceptar mezcla…). Bloquearla sí se puede siempre.
    /// </summary>
    procedure TestVacia()
    var
        UbicacionConContenidoConfigErr: Label 'La ubicación %1 tiene contenido y solo se puede cambiar su configuración cuando está vacía. Vacíela o traslade su contenido antes.', Comment = '%1 = ubicación';
    begin
        if not EstaVacia() then
            Error(UbicacionConContenidoConfigErr, "Cod. Bin");
    end;

    /// <summary>
    /// Indica si la ubicación admite movimientos en este momento.
    /// </summary>
    procedure EsUtilizable(): Boolean
    var
        rZona: Record "Zona SGA";
    begin
        if Bloqueada then
            exit(false);

        rZona.SetLoadFields(Bloqueada);
        if "Cod. Zona SGA" <> '' then
            if rZona.Get("Cod. Almacen", "Cod. Zona SGA") then
                if rZona.Bloqueada then
                    exit(false);

        exit(true);
    end;

    /// <summary>
    /// Expresión de estilo del % de ocupación: verde por debajo del 80 %, ámbar del 80 al
    /// 99 % y rojo desde el 100 %. Sin capacidad declarada (sin límite), sin color.
    /// </summary>
    procedure EstiloOcupacion(): Text
    begin
        case true of
            "Capacidad Uds." <= 0:
                exit('Standard');
            "% Ocupacion" >= 100:
                exit('Unfavorable');
            "% Ocupacion" >= 80:
                exit('Ambiguous');
        end;

        exit('Favorable');
    end;

    /// <summary>
    /// Expresión de estilo para las páginas: colorea la ubicación según su estado.
    /// </summary>
    procedure EstiloEstado(): Text
    begin
        case "Estado SGA" of
            "Estado SGA"::Vacia:
                exit('Subordinate');
            "Estado SGA"::Parcial:
                exit('Favorable');
            "Estado SGA"::Llena:
                exit('Ambiguous');
            "Estado SGA"::Bloqueada:
                exit('Unfavorable');
        end;

        exit('Standard');
    end;
}
