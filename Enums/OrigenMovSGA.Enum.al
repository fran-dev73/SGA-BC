namespace AntonioNadal.SGA;

/// <summary>
/// Enum Origen Mov. SGA (ID 51103).
/// Flujo del que procede el movimiento de ubicación.
/// </summary>
enum 51103 "Origen Mov. SGA"
{
    Extensible = true;
    Caption = 'Origen mov. SGA';

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; Manual)
    {
        Caption = 'Manual';
    }
    value(2; Compra)
    {
        Caption = 'Compra';
    }
    value(3; Produccion)
    {
        Caption = 'Producción';
    }
    value(4; Venta)
    {
        Caption = 'Venta';
    }
    value(5; "Doc. Almacen")
    {
        Caption = 'Doc. almacén';
    }
    value(6; "Diario Producto")
    {
        Caption = 'Diario producto';
    }
    value(7; Recuento)
    {
        Caption = 'Recuento';
    }
    value(8; "Carga Inicial")
    {
        Caption = 'Carga inicial';
    }
    value(9; Reposicion)
    {
        Caption = 'Reposición';
    }
}
