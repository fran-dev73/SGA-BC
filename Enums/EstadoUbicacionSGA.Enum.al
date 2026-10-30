namespace AntonioNadal.SGA;

/// <summary>
/// Enum Estado Ubicacion SGA (ID 51101).
/// Estado de ocupación calculado de una ubicación. Se persiste en "Ubicacion SGA"
/// para poder filtrar y contar sin recorrer el contenido.
/// </summary>
enum 51101 "Estado Ubicacion SGA"
{
    Extensible = true;
    Caption = 'Estado ubicación SGA';

    value(0; Vacia)
    {
        Caption = 'Vacía';
    }
    value(1; Parcial)
    {
        Caption = 'Parcial';
    }
    value(2; Llena)
    {
        Caption = 'Llena';
    }
    value(3; Bloqueada)
    {
        Caption = 'Bloqueada';
    }
}
