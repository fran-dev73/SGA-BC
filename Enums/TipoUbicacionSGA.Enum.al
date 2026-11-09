namespace AntonioNadal.SGA;

/// <summary>
/// Enum Tipo Ubicacion SGA (ID 51100).
/// Para qué es una ubicación:
///   - Almacenamiento: reserva. Es la primera que se busca al ubicar.
///   - Picking: de donde se prepara. Se busca al ubicar si no queda sitio en almacenamiento, y se
///     repone desde almacenamiento con las reubicaciones.
///   - En blanco: sin tipo (muelles, ajustes…). No se propone al ubicar ni se repone.
/// </summary>
enum 51100 "Tipo Ubicacion SGA"
{
    Extensible = true;
    Caption = 'Tipo ubicación SGA';

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; Picking)
    {
        Caption = 'Picking';
    }
    // Ordinal 2: era "Reserva", así que las ubicaciones de reserva pasan a ser de almacenamiento.
    value(2; Almacenamiento)
    {
        Caption = 'Almacenamiento';
    }
}
