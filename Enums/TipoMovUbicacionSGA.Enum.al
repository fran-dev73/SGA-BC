namespace AntonioNadal.SGA;

/// <summary>
/// Enum Tipo Mov. Ubicacion SGA (ID 51102).
/// Naturaleza del movimiento de ubicación.
/// </summary>
enum 51102 "Tipo Mov. Ubicacion SGA"
{
    Extensible = true;
    Caption = 'Tipo mov. ubicación SGA';

    value(0; Entrada)
    {
        Caption = 'Entrada';
    }
    value(1; Salida)
    {
        Caption = 'Salida';
    }
    value(2; Traslado)
    {
        Caption = 'Traslado';
    }
    value(3; Ajuste)
    {
        Caption = 'Ajuste';
    }
    value(4; Recuento)
    {
        Caption = 'Recuento';
    }
    value(5; "Carga Inicial")
    {
        Caption = 'Carga inicial';
    }
}
