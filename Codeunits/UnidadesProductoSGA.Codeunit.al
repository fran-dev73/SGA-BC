namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;

/// <summary>
/// Codeunit Unidades Producto SGA (ID 51108).
/// Lo que SGA sabe de las unidades de medida de un producto: cuántas unidades base lleva cada
/// una, cuál es la base y de qué clase es (palé, caja o unidad suelta). Las excepciones que aún
/// leen el factor de la ficha por su cuenta están en ARQUITECTURA.md.
///
/// Las conversiones que llevan el factor guardado en el propio documento (línea de venta,
/// ensamblado, línea de picking) no pasan por aquí: usan el de su registro, porque la ficha
/// puede haber cambiado después.
/// </summary>
codeunit 51108 "Unidades Producto SGA"
{
    Access = Public;

    /// <summary>
    /// Unidades base que lleva una unidad de medida del producto. Uno si el producto o la unidad
    /// van en blanco, si el producto no tiene esa unidad o si su factor no es positivo: un dato
    /// incompleto cuenta como unidad base y no descarta nada por sorpresa.
    /// </summary>
    procedure FactorUM(prm_Producto: Code[20]; prm_UM: Code[10]): Decimal
    var
        rItemUM: Record "Item Unit of Measure";
    begin
        if (prm_Producto = '') or (prm_UM = '') then
            exit(1);

        rItemUM.SetLoadFields("Qty. per Unit of Measure");
        if not rItemUM.Get(prm_Producto, prm_UM) then
            exit(1);

        if rItemUM."Qty. per Unit of Measure" <= 0 then
            exit(1);

        exit(rItemUM."Qty. per Unit of Measure");
    end;

    /// <summary>
    /// Unidad de medida base del producto. En blanco si el producto no existe.
    /// </summary>
    procedure UMBase(prm_Producto: Code[20]): Code[10]
    var
        rItem: Record Item;
    begin
        rItem.SetLoadFields("Base Unit of Measure");
        if not rItem.Get(prm_Producto) then
            exit('');

        exit(rItem."Base Unit of Measure");
    end;

    /// <summary>
    /// Error si la unidad no es la base del producto ni una de sus unidades de medida. Da el
    /// error estándar si el producto no existe. Si la unidad vale, devuelve sus unidades base
    /// (1 la base, y también si su factor no es positivo), para no volver a leerla.
    /// </summary>
    procedure TestUMProducto(prm_Producto: Code[20]; prm_UM: Code[10]): Decimal
    var
        rItem: Record Item;
        rItemUM: Record "Item Unit of Measure";
        UMNoDefinidaErr: Label 'La unidad de medida %1 no está definida para el producto %2.', Comment = '%1 = unidad de medida, %2 = producto';
    begin
        rItem.SetLoadFields("Base Unit of Measure");
        rItem.Get(prm_Producto);
        if prm_UM = rItem."Base Unit of Measure" then
            exit(1);

        rItemUM.SetLoadFields("Qty. per Unit of Measure");
        if not rItemUM.Get(prm_Producto, prm_UM) then
            Error(UMNoDefinidaErr, prm_UM, prm_Producto);

        if rItemUM."Qty. per Unit of Measure" <= 0 then
            exit(1);

        exit(rItemUM."Qty. per Unit of Measure");
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
        // Una unidad que el producto no tiene no es de ninguna clase, ni siquiera Unidad.
        rItemUM.SetLoadFields("Qty. per Unit of Measure");
        if not rItemUM.Get(prm_Producto, prm_UM) then
            exit("Tipo UM SGA"::" ");
        factor := rItemUM."Qty. per Unit of Measure";
        if factor <= 1 then
            exit("Tipo UM SGA"::Unidad);
        rItem.SetLoadFields("Cod. Pale por Defecto", "Sales Unit of Measure");
        if not rItem.Get(prm_Producto) then
            exit("Tipo UM SGA"::" ");

        // FactorUM da 1 si el producto no tiene palé: entonces no hay tamaño de palé que comparar.
        factorPale := FactorUM(prm_Producto, rItem."Cod. Pale por Defecto");
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
        clase: Enum "Tipo UM SGA";
    begin
        if prm_UM = '' then
            prm_UM := UMBase(prm_Producto);
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
    /// entonces no se propone ningún hueco. Con la UM en blanco se entiende la base del producto.
    /// </summary>
    procedure TipoHuecoDestino(prm_Producto: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal): Enum "Tipo UM SGA"
    var
        rConfig: Record "Config. SGA";
        clase: Enum "Tipo UM SGA";
    begin
        if prm_UM = '' then
            prm_UM := UMBase(prm_Producto);
        clase := TipoUMProducto(prm_Producto, prm_UM);
        if clase <> clase::Caja then
            exit(clase);

        rConfig.ObtenerConfig();
        if rConfig."Cajas Minimas Hueco Pale" <= 0 then
            rConfig."Cajas Minimas Hueco Pale" := 10;
        if prm_Cantidad < rConfig."Cajas Minimas Hueco Pale" then
            exit(clase::Caja);
        exit(clase::Pale);
    end;

    /// <summary>
    /// La unidad del producto de la clase indicada, de su ficha: Palé → "Cód. palé por defecto",
    /// Caja → unidad de venta, Unidad → unidad base. En blanco si no la tiene o no es de esa
    /// clase (por ejemplo, una unidad de venta que es la base). Es también la unidad en la que
    /// se mide la capacidad de un hueco de esa clase para ese producto.
    /// </summary>
    procedure UMProductoDeTipo(prm_Producto: Code[20]; prm_Tipo: Enum "Tipo UM SGA"): Code[10]
    var
        rItem: Record Item;
        um: Code[10];
    begin
        rItem.SetLoadFields("Cod. Pale por Defecto", "Sales Unit of Measure", "Base Unit of Measure");
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
    /// Reparte una cantidad en unidad base en los trozos que se ubican por separado: una línea
    /// por palé completo (Cantidad 1), una con las cajas completas y una con las unidades
    /// sueltas que no llegan a una caja, en ese orden y con Linea correlativa. No deja líneas
    /// con cantidad cero; sin caja, todo lo que no llega a un palé va en la línea de sueltas.
    ///
    /// prm_UMPale en blanco: el palé y la caja de la ficha (UMProductoDeTipo). Con un palé
    /// indicado (el de una tarea de embotellado) se usa ese, con su factor, y la caja es la
    /// unidad de venta si lleva más de una unidad y menos que ese palé.
    ///
    /// Solo rellena producto, unidad, cantidades y el texto del trozo (Paso): el almacén, el lote
    /// y el hueco los pone quien lo usa. Borra antes lo que hubiera en TempLinea.
    ///
    /// prm_MaxLineas mayor que cero: no crea más líneas que esas (las primeras del reparto, en
    /// el mismo orden); 0 reparte entero.
    /// </summary>
    procedure Repartir(prm_Producto: Code[20]; prm_CantidadBase: Decimal; prm_UMPale: Code[10]; prm_MaxLineas: Integer; var TempLinea: Record "Linea Ubicacion SGA" temporary)
    var
        umPale: Code[10];
        umCaja: Code[10];
        factorPale: Decimal;
        factorCaja: Decimal;
        resto: Decimal;
        pales: Integer;
        palesACrear: Integer;
        i: Integer;
        linea: Integer;
        cajas: Decimal;
        PaleDeLbl: Label 'Palé %1 de %2', Comment = '%1 = nº de palé, %2 = total';
        UnidadesVentaLbl: Label 'Unidades de venta';
        UnidadesSueltasLbl: Label 'Unidades sueltas';
    begin
        TempLinea.Reset();
        TempLinea.DeleteAll();
        if (prm_Producto = '') or (prm_CantidadBase <= 0) then
            exit;

        UnidadesReparto(prm_Producto, prm_UMPale, umPale, factorPale, umCaja, factorCaja);
        resto := prm_CantidadBase;

        if umPale <> '' then begin
            pales := Round(resto / factorPale, 1, '<');
            palesACrear := pales;
            if (prm_MaxLineas > 0) and (palesACrear > prm_MaxLineas) then
                palesACrear := prm_MaxLineas;
            for i := 1 to palesACrear do
                AnadirTrozo(TempLinea, linea, prm_MaxLineas, prm_Producto, StrSubstNo(PaleDeLbl, i, pales), umPale, 1, factorPale);
            resto := Round(resto - pales * factorPale, 0.00001);
        end;

        if umCaja <> '' then begin
            cajas := Round(resto / factorCaja, 1, '<');
            if cajas > 0 then begin
                AnadirTrozo(TempLinea, linea, prm_MaxLineas, prm_Producto, UnidadesVentaLbl, umCaja, cajas, cajas * factorCaja);
                resto := Round(resto - cajas * factorCaja, 0.00001);
            end;
        end;

        if resto > 0 then
            AnadirTrozo(TempLinea, linea, prm_MaxLineas, prm_Producto, UnidadesSueltasLbl, UMBase(prm_Producto), resto, resto);
    end;

    /// <summary>
    /// Una cantidad en unidad base dicha en palés, cajas y unidades sueltas, con las mismas
    /// unidades que Repartir con el palé de la ficha: 690 botellas con palé de 540 y CAJA12 son
    /// "1 PALE, 12 CAJA12, 6 BOTELLA". Divide en lugar de recorrer los trozos, así que no tiene
    /// límite de palés. Vacío si el producto va en blanco o la cantidad no es positiva.
    /// </summary>
    procedure Desglose(prm_Producto: Code[20]; prm_CantidadBase: Decimal): Text
    var
        umPale: Code[10];
        umCaja: Code[10];
        factorPale: Decimal;
        factorCaja: Decimal;
        resto: Decimal;
        texto: Text;
    begin
        if (prm_Producto = '') or (prm_CantidadBase <= 0) then
            exit('');

        UnidadesReparto(prm_Producto, '', umPale, factorPale, umCaja, factorCaja);
        resto := prm_CantidadBase;
        AnadirAlDesglose(umPale, factorPale, resto, texto);
        AnadirAlDesglose(umCaja, factorCaja, resto, texto);

        resto := Round(resto, 0.00001);
        if resto > 0 then begin
            if texto <> '' then
                texto += ', ';
            texto += Format(resto) + ' ' + UMBase(prm_Producto);
        end;
        exit(texto);
    end;

    /// <summary>
    /// El palé y la caja con los que se reparte (ver Repartir). Unidad en blanco y factor 0 si el
    /// producto no la tiene.
    /// </summary>
    local procedure UnidadesReparto(prm_Producto: Code[20]; prm_UMPaleIndicada: Code[10]; var prm_UMPale: Code[10]; var prm_FactorPale: Decimal; var prm_UMCaja: Code[10]; var prm_FactorCaja: Decimal)
    var
        rItem: Record Item;
    begin
        prm_FactorPale := 0;
        prm_FactorCaja := 0;
        if prm_UMPaleIndicada = '' then begin
            prm_UMPale := UMProductoDeTipo(prm_Producto, "Tipo UM SGA"::Pale);
            prm_UMCaja := UMProductoDeTipo(prm_Producto, "Tipo UM SGA"::Caja);
        end else begin
            prm_UMPale := prm_UMPaleIndicada;
            prm_UMCaja := '';
            rItem.SetLoadFields("Sales Unit of Measure");
            if rItem.Get(prm_Producto) then
                prm_UMCaja := rItem."Sales Unit of Measure";
        end;

        if prm_UMPale <> '' then
            prm_FactorPale := FactorUM(prm_Producto, prm_UMPale);
        if prm_UMCaja = '' then
            exit;

        prm_FactorCaja := FactorUM(prm_Producto, prm_UMCaja);
        // Con el palé de la ficha, UMProductoDeTipo ya lo garantiza; con otro palé, se comprueba.
        if (prm_FactorCaja <= 1) or ((prm_FactorPale > 0) and (prm_FactorCaja >= prm_FactorPale)) then begin
            prm_UMCaja := '';
            prm_FactorCaja := 0;
        end;
    end;

    /// <summary>
    /// Añade un trozo con la Linea siguiente a prm_Linea (la última creada), salvo que ya se
    /// haya llegado a prm_MaxLineas (0 = sin tope).
    /// </summary>
    local procedure AnadirTrozo(var TempLinea: Record "Linea Ubicacion SGA" temporary; var prm_Linea: Integer; prm_MaxLineas: Integer; prm_Producto: Code[20]; prm_Paso: Text; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_CantidadBase: Decimal)
    begin
        if (prm_MaxLineas > 0) and (prm_Linea >= prm_MaxLineas) then
            exit;

        prm_Linea += 1;
        TempLinea.Init();
        TempLinea.Linea := prm_Linea;
        TempLinea.Paso := CopyStr(prm_Paso, 1, MaxStrLen(TempLinea.Paso));
        TempLinea."No. Producto" := prm_Producto;
        TempLinea."Cod. Unidad Medida" := prm_UM;
        TempLinea.Cantidad := prm_Cantidad;
        TempLinea."Cantidad Base" := Round(prm_CantidadBase, 0.00001);
        TempLinea.Insert();
    end;

    local procedure AnadirAlDesglose(prm_UM: Code[10]; prm_Factor: Decimal; var prm_Resto: Decimal; var prm_Texto: Text)
    var
        cuantos: Decimal;
    begin
        if (prm_UM = '') or (prm_Factor <= 0) then
            exit;
        cuantos := Round(prm_Resto / prm_Factor, 1, '<');
        if cuantos <= 0 then
            exit;
        if prm_Texto <> '' then
            prm_Texto += ', ';
        prm_Texto += Format(cuantos) + ' ' + prm_UM;
        prm_Resto -= cuantos * prm_Factor;
    end;
}
