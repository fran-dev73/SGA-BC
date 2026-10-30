namespace AntonioNadal.SGA;

/// <summary>
/// Enum Estado Linea Picking SGA (ID 51108).
/// Situación de una línea de picking: lo que le queda por hacer al preparador.
/// </summary>
enum 51108 "Estado Linea Picking SGA"
{
    Extensible = true;
    Caption = 'Estado línea picking SGA';

    value(0; Pendiente)
    {
        Caption = 'Pendiente';
    }
    value(1; Parcial)
    {
        Caption = 'Parcial';
    }
    value(2; Recogida)
    {
        Caption = 'Recogida';
    }
    value(3; Cancelada)
    {
        Caption = 'Cancelada';
    }
}
