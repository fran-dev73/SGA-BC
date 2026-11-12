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
/// La fila se crea bajo demanda con Cod. "Gestion Ubicaciones SGA".ObtenerOCrear, de modo
/// que SGA es puramente aditivo y la topología estándar no se toca.
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
        }
        field(30; Descripcion; Text[50])
        {
            Caption = 'Descripción';
            DataClassification = ToBeClassified;
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
                // Al asignar zona hereda tipo y ruta si la ubicación aún no los tiene.
                if "Cod. Zona SGA" = '' then
                    exit;
                if not rZona.Get("Cod. Almacen", "Cod. Zona SGA") then
                    exit;
                if "Tipo Ubicacion" = "Tipo Ubicacion"::" " then
                    "Tipo Ubicacion" := rZona."Tipo Ubicacion";
                if "Secuencia Picking" = 0 then
                    "Secuencia Picking" := rZona."Prioridad Picking";
            end;
        }
        field(50; "Tipo Ubicacion"; Enum "Tipo Ubicacion SGA")
        {
            Caption = 'Tipo ubicación';
            DataClassification = ToBeClassified;
            ToolTip = 'Almacenamiento: reserva, es la primera que se busca al ubicar. Picking: de donde se prepara; se busca al ubicar si no queda sitio en almacenamiento y se repone desde almacenamiento con las reubicaciones. En blanco (muelles, ajustes…): no se propone ni se repone.';

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
        field(72; "Capacidad Volumen"; Decimal)
        {
            Caption = 'Capacidad volumen';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            MinValue = 0;

            trigger OnValidate()
            begin
                TestVacia();
            end;
        }
        field(73; "Capacidad Peso"; Decimal)
        {
            Caption = 'Capacidad peso';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            MinValue = 0;

            trigger OnValidate()
            begin
                TestVacia();
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
                RecalcularOcupacion();
            end;
        }
        field(81; "Motivo Bloqueo"; Text[50])
        {
            Caption = 'Motivo bloqueo';
            DataClassification = ToBeClassified;
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
        field(110; "Ctdad. Minima"; Decimal)
        {
            Caption = 'Ctdad. mínima';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            ToolTip = 'Por debajo de esta cantidad la ubicación es candidata a reposición desde reserva.';

            trigger OnValidate()
            begin
                TestVacia();
            end;
        }
        field(111; "Ctdad. Maxima"; Decimal)
        {
            Caption = 'Ctdad. máxima';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            ToolTip = 'Cantidad hasta la que se repone la ubicación.';

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
        }
        field(130; "Fecha Ultimo Movimiento"; DateTime)
        {
            Caption = 'Fecha último movimiento';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(140; "Zone Code"; Code[10])
        {
            Caption = 'Cód. zona BC';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup(Bin."Zone Code" where("Location Code" = field("Cod. Almacen"), Code = field("Cod. Bin")));
        }
        field(141; "Bin Type Code"; Code[10])
        {
            Caption = 'Tipo ubicación BC';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup(Bin."Bin Type Code" where("Location Code" = field("Cod. Almacen"), Code = field("Cod. Bin")));
        }
        field(142; Dedicated; Boolean)
        {
            Caption = 'Dedicada BC';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup(Bin.Dedicated where("Location Code" = field("Cod. Almacen"), Code = field("Cod. Bin")));
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
        rBin: Record Bin;
        BinNoExisteErr: Label 'La ubicación %1 no existe en el almacén %2.', Comment = '%1 = ubicación, %2 = almacén';
    begin
        // Se valida contra Bin y no contra la topología propia: SGA es aditivo sobre la
        // topología estándar, y es de Bin de donde SincronizarTopologia lee las ubicaciones.
        if not rBin.Get("Cod. Almacen", "Cod. Bin") then
            Error(BinNoExisteErr, "Cod. Bin", "Cod. Almacen");
        RecalcularOcupacion();
    end;

    /// <summary>
    /// Si la ubicación está reservada para otra entrada: de otro usuario, de otra sesión o para
    /// otra fila de la misma pantalla. Con prm_Para en blanco, cualquier reserva es de otro.
    /// </summary>
    procedure ReservadaParaOtro(prm_Para: Text): Boolean
    begin
        if "Reservada Por" = '' then
            exit(false);
        exit(("Reservada Por" <> UserId()) or ("Sesion Reserva" <> SessionId()) or ("Reservada Para" <> prm_Para));
    end;

    /// <summary>
    /// Reserva la ubicación para prm_Para en esta sesión. False, sin tocarla, si ya está
    /// reservada para otro.
    /// </summary>
    procedure Reservar(prm_Para: Text): Boolean
    begin
        if ReservadaParaOtro(prm_Para) then
            exit(false);

        "Reservada Para" := CopyStr(prm_Para, 1, MaxStrLen("Reservada Para"));
        "Reservada Por" := CopyStr(UserId(), 1, MaxStrLen("Reservada Por"));
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

    /// <summary>
    /// Error si la ubicación leída en la etiqueta del hueco no es una ubicación SGA del almacén.
    /// Es lo que certifica que el preparador lee el hueco al que va: la etiqueta trae el código
    /// de la ubicación y se compara con la propuesta en el picking.
    /// </summary>
    procedure ComprobarUbicacionLeida(prm_Almacen: Code[10]; prm_Bin: Code[20])
    var
        UbicacionNoExisteErr: Label 'La ubicación %1 no existe en SGA para el almacén %2.', Comment = '%1 = ubicación, %2 = almacén';
    begin
        if not Get(prm_Almacen, prm_Bin) then
            Error(UbicacionNoExisteErr, prm_Bin, prm_Almacen);
    end;

    trigger OnDelete()
    var
        rContenido: Record "Contenido Ubicacion SGA";
        UbicacionConContenidoErr: Label 'No se pueden eliminar los datos SGA de la ubicación %1 porque todavía tiene contenido.', Comment = '%1 = ubicación';
    begin
        rContenido.SetRange("Cod. Almacen", "Cod. Almacen");
        rContenido.SetRange("Cod. Bin", "Cod. Bin");
        if not rContenido.IsEmpty() then
            Error(UbicacionConContenidoErr, "Cod. Bin");
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
        ocupado := OcupadoEnPales();

        if "Capacidad Uds." > 0 then
            "% Ocupacion" := Round(ocupado / "Capacidad Uds." * 100, 0.01)
        else
            if "Cantidad Base" > 0 then
                "% Ocupacion" := 100
            else
                "% Ocupacion" := 0;

        case true of
            Bloqueada:
                "Estado SGA" := "Estado SGA"::Bloqueada;
            "Lineas Contenido" = 0:
                "Estado SGA" := "Estado SGA"::Vacia;
            ("Capacidad Uds." > 0) and (ocupado >= "Capacidad Uds."):
                "Estado SGA" := "Estado SGA"::Llena;
            "Capacidad Uds." = 0:
                // Sin capacidad declarada no se puede distinguir parcial de llena: con contenido queda llena.
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
        rContenido.SetRange("Cod. Almacen", "Cod. Almacen");
        rContenido.SetRange("Cod. Bin", "Cod. Bin");
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
        prm_Contenido.SetRange("Cod. Almacen", "Cod. Almacen");
        prm_Contenido.SetRange("Cod. Bin", "Cod. Bin");
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
    /// Si la ubicación tiene tipo (Almacenamiento o Picking). Solo esas se proponen y se
    /// clasifican; las que no tienen tipo (muelles, ajustes…) quedan fuera.
    /// </summary>
    procedure TieneTipo(): Boolean
    begin
        exit("Tipo Ubicacion" <> "Tipo Ubicacion"::" ");
    end;

    /// <summary>
    /// Si la ubicación no tiene nada dentro. Solo una ubicación vacía se puede reconfigurar.
    /// </summary>
    procedure EstaVacia(): Boolean
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        rContenido.SetRange("Cod. Almacen", "Cod. Almacen");
        rContenido.SetRange("Cod. Bin", "Cod. Bin");
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

        if "Cod. Zona SGA" <> '' then
            if rZona.Get("Cod. Almacen", "Cod. Zona SGA") then
                if rZona.Bloqueada then
                    exit(false);

        exit(true);
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
