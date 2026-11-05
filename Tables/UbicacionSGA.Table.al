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
            Caption = 'Cód. bin';
            DataClassification = ToBeClassified;
            NotBlank = true;
            TableRelation = Bin where("Location Code" = field("Cod. Almacen"));
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
            Caption = 'Capacidad';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            ToolTip = 'Cuánto cabe, en la clase que admite (palés o cajas): 1 en una ubicación de palé, 72 en una de cajas. 0 = sin límite declarado.';

            trigger OnValidate()
            begin
                TestVacia();
                RecalcularOcupacion();
            end;
        }
        field(71; "Capacidad Palets"; Decimal)
        {
            Caption = 'Capacidad palés';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 2;
            MinValue = 0;

            trigger OnValidate()
            begin
                TestVacia();
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
            Caption = 'Acepta múltiples productos';
            DataClassification = ToBeClassified;
            InitValue = true;
            ToolTip = 'Si está marcado, la ubicación puede contener productos distintos. Solo se puede marcar en ubicaciones que admiten Caja o Unidad.';

            trigger OnValidate()
            var
                MezclaNoPermitidaErr: Label 'Solo las ubicaciones de caja o de unidades sueltas pueden aceptar varios productos. Esta admite %1.', Comment = '%1 = tipo de la ubicación';
                AdmiteCajaOUnidadErr: Label 'Indique primero que la ubicación admite cajas o unidades sueltas.';
            begin
                TestVacia();
                if not "Permite Mezcla Producto" then
                    exit;

                if EsUmMixta() then
                    exit;

                if "Tipo UM Admitida" = "Tipo UM Admitida"::" " then
                    Error(AdmiteCajaOUnidadErr);

                Error(MezclaNoPermitidaErr, "Tipo UM Admitida");
            end;
        }
        field(91; "Permite Mezcla Lote"; Boolean)
        {
            Caption = 'Permite mezcla lote';
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
        field(113; "Tipo UM Admitida"; Enum "Tipo UM SGA")
        {
            Caption = 'Admite';
            DataClassification = ToBeClassified;
            ToolTip = 'Qué admite el hueco: Palé (el palé del producto y cajas de una referencia), Caja (cajas sueltas de varios productos) o Unidad (botellas sueltas de varios productos). En blanco, sin configurar: no se propone. Al poner Caja o Unidad se marca "Acepta múltiples productos". La capacidad se cuenta en esa clase: 1 = un palé del producto que entre.';

            trigger OnValidate()
            begin
                TestVacia();
                // El tipo manda: las de caja y las de unidades sueltas son para varios productos;
                // las de palé, de uno. Se puede desmarcar después si una de caja es de uno solo.
                "Permite Mezcla Producto" := EsUmMixta();
                // Varios productos supone varios lotes: si no, dos referencias con lotes distintos
                // chocarían en la misma ubicación aunque tuviera sitio.
                if EsUmMixta() then
                    "Permite Mezcla Lote" := true;
            end;
        }
        field(114; "Digito Control"; Code[2])
        {
            Caption = 'Dígito de control';
            DataClassification = ToBeClassified;
            Editable = false;
            ToolTip = 'Número de dos cifras, distinto en cada hueco, que va impreso en su etiqueta. Al recoger se teclea para certificar que el preparador está delante del hueco: no se puede saber sin verlo. Se asigna solo al crear la ubicación; si se regenera, hay que reimprimir la etiqueta.';
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
            Caption = 'Código zona (estándar)';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup(Bin."Zone Code" where("Location Code" = field("Cod. Almacen"), Code = field("Cod. Bin")));
        }
        field(141; "Bin Type Code"; Code[10])
        {
            Caption = 'Tipo bin (estándar)';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup(Bin."Bin Type Code" where("Location Code" = field("Cod. Almacen"), Code = field("Cod. Bin")));
        }
        field(142; Dedicated; Boolean)
        {
            Caption = 'Dedicado (estándar)';
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
        key(Ubicar; "Cod. Almacen", "Tipo Ubicacion", Bloqueada, "Estado SGA", "Secuencia Picking")
        {
        }
        key(Ruta; "Cod. Almacen", "Secuencia Picking", "Cod. Bin")
        {
        }
        key(ProductoFijo; "Cod. Almacen", "Producto Fijo")
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
        if "Digito Control" = '' then
            GenerarDigitoControl();
        RecalcularOcupacion();
    end;

    /// <summary>
    /// Asigna un dígito de control nuevo, de 10 a 99. Al azar a propósito: si siguiera el
    /// código del hueco, se podría deducir sin estar delante, que es lo que se quiere evitar.
    /// No hace Modify: decide el llamante. Cambiarlo obliga a reimprimir la etiqueta.
    /// </summary>
    procedure GenerarDigitoControl()
    var
        guid: Text;
        i: Integer;
        acumulado: Integer;
    begin
        // Se saca de un GUID y no de Random: Random repite la misma serie en cada sesión si no
        // se siembra, y sembrarlo por hora daría el mismo número a los huecos de una tirada.
        guid := UpperCase(Format(CreateGuid()));
        for i := 1 to StrLen(guid) do
            acumulado := (acumulado * 31 + StrPos('0123456789ABCDEF', CopyStr(guid, i, 1))) mod 100000;

        "Digito Control" := Format(acumulado mod 90 + 10);
    end;

    /// <summary>
    /// Comprueba el dígito de control tecleado o escaneado contra el de la ubicación.
    /// </summary>
    procedure DigitoControlCorrecto(prm_Digito: Text): Boolean
    begin
        if "Digito Control" = '' then
            exit(false);

        exit(DelChr(prm_Digito, '<>', ' ') = "Digito Control");
    end;

    /// <summary>
    /// Error si el dígito de control tecleado no es el de la ubicación prm_Bin del almacén
    /// prm_Almacen, que lee en Rec. Certifica que quien confirma está delante del hueco: el
    /// dígito solo está en su etiqueta. Una ubicación sin datos SGA da el mismo error que un
    /// dígito incorrecto, para que la comprobación no se pueda saltar.
    /// </summary>
    procedure TestDigitoControl(prm_Almacen: Code[10]; prm_Bin: Code[20]; prm_Digito: Text)
    var
        DigitoNoIndicadoErr: Label 'Teclee el dígito de control de la etiqueta de la ubicación %1.', Comment = '%1 = ubicación';
        DigitoIncorrectoErr: Label 'El dígito de control no corresponde a la ubicación %1. Compruebe que está recogiendo del hueco correcto.', Comment = '%1 = ubicación';
        UbicacionSinDigitoErr: Label 'La ubicación %1 no tiene dígito de control. Genérelo e imprima su etiqueta desde la lista de ubicaciones.', Comment = '%1 = ubicación';
    begin
        if DelChr(prm_Digito, '<>', ' ') = '' then
            Error(DigitoNoIndicadoErr, prm_Bin);

        if not Get(prm_Almacen, prm_Bin) then
            Error(DigitoIncorrectoErr, prm_Bin);

        if "Digito Control" = '' then
            Error(UbicacionSinDigitoErr, prm_Bin);

        if not DigitoControlCorrecto(prm_Digito) then
            Error(DigitoIncorrectoErr, prm_Bin);
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
        ocupado := OcupadoEnUMHueco();

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
    /// Lo que hay en el hueco, contado en la clase que admite: palés en un hueco de palé, cajas
    /// en uno de caja. Cada línea se convierte con el palé o la caja de su producto, porque en
    /// el mismo hueco pueden convivir palés de 200 y de 300. Sin tipo, en unidades base.
    /// </summary>
    procedure OcupadoEnUMHueco(): Decimal
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

        // Lo mismo que EnUMHueco de cada línea, con el factor de cada producto leído una vez:
        // un hueco suele tener varias líneas (lotes) del mismo producto.
        repeat
            if not factores.Get(rContenido."No. Producto", factor) then begin
                factor := cUM.FactorClase(rContenido."No. Producto", "Tipo UM Admitida");
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
    /// Si caben prm_Entrada más, contadas en la clase del hueco (EnUMHueco), sin pasar de la
    /// capacidad. Sin capacidad declarada, siempre. Es la comprobación de la propuesta, que mira
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

        exit(OcupadoEnUMHueco() + prm_Entrada <= "Capacidad Uds.");
    end;

    /// <summary>
    /// Una cantidad base de un producto, contada en la clase que admite el hueco: palés en uno
    /// de palé, cajas en uno de caja, cada producto con su palé o su caja. Sin tipo, o si el
    /// producto no tiene unidad de esa clase, en unidades base. Sin redondear: redondea quien la
    /// usa, si le hace falta.
    /// </summary>
    procedure EnUMHueco(prm_Producto: Code[20]; prm_CantidadBase: Decimal): Decimal
    var
        cUM: Codeunit "Unidades Producto SGA";
    begin
        exit(cUM.CantidadEnClase(prm_Producto, "Tipo UM Admitida", prm_CantidadBase));
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
    /// Deja en Rec solo las ubicaciones de almacenaje: Picking y Reserva. Son las únicas que se
    /// proponen y se clasifican; muelles, cuarentena, ajustes y producción quedan fuera.
    /// </summary>
    procedure FiltrarDeAlmacenaje()
    begin
        SetFilter("Tipo Ubicacion", '%1|%2', "Tipo Ubicacion"::Picking, "Tipo Ubicacion"::Reserva);
    end;

    /// <summary>
    /// Si la ubicación es de almacenaje (Picking o Reserva). Ver FiltrarDeAlmacenaje.
    /// </summary>
    procedure EsDeAlmacenaje(): Boolean
    begin
        exit("Tipo Ubicacion" in ["Tipo Ubicacion"::Picking, "Tipo Ubicacion"::Reserva]);
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
    /// Error si la ubicación tiene contenido. La configuración (qué admite, capacidad, mezclas,
    /// zona, tipo, ruta, producto fijo, reposición) solo se cambia con la ubicación vacía: si no,
    /// lo que ya hay dentro podría dejar de cumplirla (un palé en un hueco que pasa a ser de
    /// cajas, dos productos en uno que deja de aceptar mezcla…). Bloquearla sí se puede siempre.
    /// </summary>
    procedure TestVacia()
    var
        UbicacionConContenidoConfigErr: Label 'La ubicación %1 tiene contenido y solo se puede cambiar su configuración cuando está vacía. Vacíela o traslade su contenido antes.', Comment = '%1 = ubicación';
    begin
        if not EstaVacia() then
            Error(UbicacionConContenidoConfigErr, "Cod. Bin");
    end;

    /// <summary>
    /// Indica si la ubicación es de las que admiten varios productos: las de caja.
    /// Sin tipo la ubicación no está clasificada y no se considera mixta.
    /// </summary>
    procedure EsUmMixta(): Boolean
    begin
        exit("Tipo UM Admitida" in ["Tipo UM Admitida"::Caja, "Tipo UM Admitida"::Unidad]);
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
