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
}
