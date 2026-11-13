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
    value(7; Recuento)
    {
        Caption = 'Recuento';
    }
    value(8; "Carga Inicial")
    {
        Caption = 'Carga inicial';
    }
    // Reubicación de almacenamiento a picking (Cod. "Reubicaciones SGA").
    value(9; Reposicion)
    {
        Caption = 'Reubicación';
    }
}
