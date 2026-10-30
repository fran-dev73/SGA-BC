namespace AntonioNadal.SGA;

/// <summary>
/// Enum Tipo UM SGA (ID 51109).
/// Clase de una unidad de medida para SGA: palé, caja, unidad suelta o ninguna.
///
/// La clase de cada unidad sale de la ficha del producto (palé por defecto, unidad de venta y
/// unidad base; ver TipoUMProducto en "Config. SGA"), y cada ubicación declara cuál admite.
/// Así un hueco de palé admite cualquier palé, se llame como se llame y lleve lo que lleve.
/// </summary>
enum 51109 "Tipo UM SGA"
{
    Extensible = true;
    Caption = 'Tipo UM SGA';

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; Pale)
    {
        Caption = 'Palé';
    }
    value(2; Caja)
    {
        Caption = 'Caja';
    }
    value(3; Unidad)
    {
        Caption = 'Unidad';
    }
}
