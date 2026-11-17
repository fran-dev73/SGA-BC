namespace AntonioNadal.SGA;

using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;

/// <summary>
/// Codeunit Unidades Producto SGA (ID 51108).
/// Lo que SGA sabe de las unidades de medida de un producto: cuántas unidades base lleva cada
/// una, cuál es la base y cuáles son su palé y su caja. El mapa (Cod. "Gestion Mapa SGA") y el
/// palé de una tarea (Cod. "Gestion Entradas SGA") leen el factor de la ficha por su cuenta.
///
/// Las conversiones que llevan el factor guardado en el propio documento (línea de venta,
/// ensamblado, línea de picking) no pasan por aquí: usan el de su registro, porque la ficha
/// puede haber cambiado después.
/// </summary>
codeunit 51108 "Unidades Producto SGA"
{
    Access = Public;

    /// <summary>
    /// Cuántas unidades base contiene una unidad de medida del producto, con el estándar
    /// ("Unit of Measure Management".GetQtyPerUnitOfMeasure): 1 con la unidad base o en blanco,
    /// y error estándar si el producto no existe, no tiene esa unidad o su factor es cero.
    /// Nunca devuelve cero.
    /// </summary>
    procedure FactorUM(prm_Producto: Code[20]; prm_UM: Code[10]): Decimal
    var
        rItem: Record Item;
    begin
        // En blanco el estándar también da 1; así no se lee la ficha ni falla sin producto.
        if prm_UM = '' then
            exit(1);

        rItem.SetLoadFields("Base Unit of Measure");
        rItem.Get(prm_Producto);
        exit(cUOMMgt.GetQtyPerUnitOfMeasure(rItem, prm_UM));
    end;

    /// <summary>
    /// Unidad de medida base del producto. En blanco si el producto no existe.
    /// </summary>
    procedure UMBase(prm_Producto: Code[20]): Code[10]
    var
        unidadBase: Code[10];
    begin
        if LeerUMBase(prm_Producto, unidadBase) then;
        exit(unidadBase);
    end;

    /// <summary>
    /// Unidad base del producto, leída de la ficha una vez por producto en cada instancia del
    /// codeunit: quien recorre muchas líneas la pide sin volver a leer la ficha. False (y en
    /// blanco) si el producto no existe.
    /// </summary>
    procedure LeerUMBase(prm_Producto: Code[20]; var prm_UMBase: Code[10]): Boolean
    var
        rItem: Record Item;
    begin
        if UMBasesLeidas.Get(prm_Producto, prm_UMBase) then
            exit(true);

        prm_UMBase := '';
        rItem.SetLoadFields("Base Unit of Measure");
        if not rItem.Get(prm_Producto) then
            exit(false);

        prm_UMBase := rItem."Base Unit of Measure";
        UMBasesLeidas.Add(prm_Producto, prm_UMBase);
        exit(true);
    end;

    /// <summary>
    /// El palé del producto: su "Cód. palé por defecto", si lo tiene entre sus unidades y lleva
    /// más de una unidad base. En blanco si no. Es la unidad con la que se mide la capacidad de
    /// las ubicaciones.
    /// </summary>
    procedure UMPale(prm_Producto: Code[20]): Code[10]
    var
        codPale: Code[10];
        factor: Decimal;
    begin
        LeerPale(prm_Producto, codPale, factor);
        exit(codPale);
    end;

    /// <summary>
    /// Unidades base que lleva el palé del producto (UMPale). Uno si no tiene palé: entonces lo
    /// que hay se cuenta en unidades base. Nunca cero: se puede dividir por él. Quien convierte
    /// muchas cantidades del mismo producto lo lee una vez.
    /// </summary>
    procedure FactorPale(prm_Producto: Code[20]): Decimal
    var
        codPale: Code[10];
        factor: Decimal;
    begin
        if LeerPale(prm_Producto, codPale, factor) then
            exit(factor);
        exit(1);
    end;

    /// <summary>
    /// El palé del producto y su factor, leídos una vez: la unidad "Cod. Pale por Defecto" de la
    /// ficha si existe y lleva más de una unidad base. False, en blanco, si no.
    /// </summary>
    local procedure LeerPale(prm_Producto: Code[20]; var prm_UMPale: Code[10]; var prm_FactorPale: Decimal): Boolean
    var
        rItem: Record Item;
        rItemUM: Record "Item Unit of Measure";
    begin
        prm_UMPale := '';
        prm_FactorPale := 0;
        rItem.SetLoadFields("Cod. Pale por Defecto");
        if not rItem.Get(prm_Producto) then
            exit(false);
        if rItem."Cod. Pale por Defecto" = '' then
            exit(false);
        // Sin palé válido no es un error: el producto se cuenta en unidades base.
        rItemUM.SetLoadFields("Qty. per Unit of Measure");
        if not rItemUM.Get(prm_Producto, rItem."Cod. Pale por Defecto") then
            exit(false);
        if rItemUM."Qty. per Unit of Measure" <= 1 then
            exit(false);
        prm_UMPale := rItem."Cod. Pale por Defecto";
        prm_FactorPale := rItemUM."Qty. per Unit of Measure";
        exit(true);
    end;

    /// <summary>
    /// Si la unidad de medida es la caja de venta del producto: la de venta de la ficha, con más
    /// de una unidad base y menos que el palé. Es lo que decide que una línea se prepare por cajas.
    /// </summary>
    procedure EsCaja(prm_Producto: Code[20]; prm_UM: Code[10]): Boolean
    var
        rItem: Record Item;
        factorCaja: Decimal;
    begin
        if prm_UM = '' then
            exit(false);
        rItem.SetLoadFields("Sales Unit of Measure");
        if not rItem.Get(prm_Producto) then
            exit(false);
        if rItem."Sales Unit of Measure" <> prm_UM then
            exit(false);
        factorCaja := FactorUM(prm_Producto, prm_UM);
        exit((factorCaja > 1) and (factorCaja < FactorPale(prm_Producto)));
    end;

    /// <summary>
    /// Volumen en litros de una unidad de medida del producto: el volumen de la ficha (por unidad
    /// base) por las unidades base que lleva.
    /// </summary>
    procedure VolumenUM(prm_Producto: Code[20]; prm_UM: Code[10]): Decimal
    var
        rItem: Record Item;
    begin
        rItem.SetLoadFields("Unit Volume");
        if not rItem.Get(prm_Producto) then
            exit(0);
        exit(rItem."Unit Volume" * FactorUM(prm_Producto, prm_UM));
    end;

    /// <summary>
    /// Una cantidad base de un producto, en palés de ese producto (medio palé = 0,5). Sin palé,
    /// en unidades base. Sin redondear. Es la medida de la capacidad de una ubicación.
    /// </summary>
    procedure EnPales(prm_Producto: Code[20]; prm_CantidadBase: Decimal): Decimal
    begin
        exit(prm_CantidadBase / FactorPale(prm_Producto));
    end;

    /// <summary>
    /// Reparte una cantidad en unidad base en los trozos que se ubican por separado: una línea
    /// por palé completo (Cantidad 1) y una con el resto, en ese orden y con Linea correlativa.
    /// El resto va en cajas si son cajas exactas y, si no, en unidades base. No deja líneas con
    /// cantidad cero; sin palé, todo va en la línea del resto.
    ///
    /// prm_UMPale en blanco: el palé y la caja de la ficha. Con un palé indicado (el de una tarea
    /// de embotellado) se usa ese, con su factor, y la caja es la unidad de venta si lleva más
    /// de una unidad y menos que ese palé.
    ///
    /// Solo rellena producto, unidad, cantidades y el texto del trozo (Paso): el almacén, el lote
    /// y el hueco los pone quien lo usa. Borra antes lo que hubiera en TempLinea.
    ///
    /// prm_MaxLineas mayor que cero: no crea más líneas que esas (las primeras del reparto, en
    /// el mismo orden); 0 reparte entero.
    /// </summary>
    procedure Repartir(prm_Producto: Code[20]; prm_CantidadBase: Decimal; prm_UMPale: Code[10]; prm_MaxLineas: Integer; var TempLinea: Record "Linea Ubicacion SGA" temporary)
    var
        umPaleReparto: Code[10];
        umCaja: Code[10];
        factorPaleReparto: Decimal;
        factorCaja: Decimal;
        resto: Decimal;
        cajas: Decimal;
        paso: Text;
        pales: Integer;
        palesACrear: Integer;
        i: Integer;
        linea: Integer;
        PaleDeLbl: Label 'Palé %1 de %2', Comment = '%1 = nº de palé, %2 = total';
        RestoLbl: Label 'Resto: %1', Comment = '%1 = desglose, p. ej. 12 CAJA12, 6 BOTELLA';
    begin
        TempLinea.Reset();
        TempLinea.DeleteAll();
        if (prm_Producto = '') or (prm_CantidadBase <= 0) then
            exit;

        UnidadesReparto(prm_Producto, prm_UMPale, umPaleReparto, factorPaleReparto, umCaja, factorCaja);
        resto := prm_CantidadBase;

        if umPaleReparto <> '' then begin
            pales := Round(resto / factorPaleReparto, 1, '<');
            palesACrear := pales;
            if (prm_MaxLineas > 0) and (palesACrear > prm_MaxLineas) then
                palesACrear := prm_MaxLineas;
            for i := 1 to palesACrear do
                AnadirTrozo(TempLinea, linea, prm_MaxLineas, prm_Producto, StrSubstNo(PaleDeLbl, i, pales), umPaleReparto, 1, factorPaleReparto);
            resto := Round(resto - pales * factorPaleReparto, 0.00001);
        end;

        if resto <= 0 then
            exit;

        // El resto es un solo trozo, que va a un solo hueco: en cajas si son cajas exactas.
        paso := StrSubstNo(RestoLbl, DesgloseCon(prm_Producto, resto, umPaleReparto, factorPaleReparto, umCaja, factorCaja));
        if umCaja <> '' then
            cajas := Round(resto / factorCaja, 1, '<');
        if (cajas > 0) and (cajas * factorCaja = resto) then
            AnadirTrozo(TempLinea, linea, prm_MaxLineas, prm_Producto, paso, umCaja, cajas, resto)
        else
            AnadirTrozo(TempLinea, linea, prm_MaxLineas, prm_Producto, paso, UMBase(prm_Producto), resto, resto);
    end;

    /// <summary>
    /// Una cantidad en unidad base dicha en palés, cajas y unidades sueltas, con el palé y la
    /// caja de la ficha: 690 botellas con palé de 540 y CAJA12 son "1 PALE, 12 CAJA12, 6
    /// BOTELLA". Divide en lugar de recorrer los trozos, así que no tiene límite de palés. Vacío
    /// si el producto va en blanco o la cantidad no es positiva.
    /// </summary>
    procedure Desglose(prm_Producto: Code[20]; prm_CantidadBase: Decimal): Text
    var
        umPaleReparto: Code[10];
        umCaja: Code[10];
        factorPaleReparto: Decimal;
        factorCaja: Decimal;
    begin
        if (prm_Producto = '') or (prm_CantidadBase <= 0) then
            exit('');

        UnidadesReparto(prm_Producto, '', umPaleReparto, factorPaleReparto, umCaja, factorCaja);
        exit(DesgloseCon(prm_Producto, prm_CantidadBase, umPaleReparto, factorPaleReparto, umCaja, factorCaja));
    end;

    local procedure DesgloseCon(prm_Producto: Code[20]; prm_CantidadBase: Decimal; prm_UMPale: Code[10]; prm_FactorPale: Decimal; prm_UMCaja: Code[10]; prm_FactorCaja: Decimal): Text
    var
        resto: Decimal;
        texto: Text;
    begin
        resto := prm_CantidadBase;
        AnadirAlDesglose(prm_UMPale, prm_FactorPale, resto, texto);
        AnadirAlDesglose(prm_UMCaja, prm_FactorCaja, resto, texto);

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
    /// producto no la tiene. La caja es la unidad de venta si lleva más de una unidad y menos
    /// que el palé.
    /// </summary>
    local procedure UnidadesReparto(prm_Producto: Code[20]; prm_UMPaleIndicada: Code[10]; var prm_UMPale: Code[10]; var prm_FactorPale: Decimal; var prm_UMCaja: Code[10]; var prm_FactorCaja: Decimal)
    var
        rItem: Record Item;
    begin
        prm_FactorPale := 0;
        prm_FactorCaja := 0;
        prm_UMCaja := '';
        if prm_UMPaleIndicada = '' then
            prm_UMPale := UMPale(prm_Producto)
        else
            prm_UMPale := prm_UMPaleIndicada;
        if prm_UMPale <> '' then
            prm_FactorPale := FactorUM(prm_Producto, prm_UMPale);

        rItem.SetLoadFields("Sales Unit of Measure");
        if not rItem.Get(prm_Producto) then
            exit;
        if rItem."Sales Unit of Measure" = '' then
            exit;

        prm_FactorCaja := FactorUM(prm_Producto, rItem."Sales Unit of Measure");
        if (prm_FactorCaja <= 1) or ((prm_FactorPale > 0) and (prm_FactorCaja >= prm_FactorPale)) then begin
            prm_FactorCaja := 0;
            exit;
        end;
        prm_UMCaja := rItem."Sales Unit of Measure";
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

    var
        // Global para aprovechar su caché: guarda la última unidad leída de un producto.
        cUOMMgt: Codeunit "Unit of Measure Management";
        // Caché de LeerUMBase: unidad base de cada producto ya leído.
        UMBasesLeidas: Dictionary of [Code[20], Code[10]];
}
