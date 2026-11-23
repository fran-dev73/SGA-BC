namespace AntonioNadal.SGA;

/// <summary>
/// Enum Estrategia Picking SGA (ID 51105).
/// Orden en que el picking coge el stock dentro de cada paso (OrdenarPorEstrategia de
/// "Gestion Picking SGA"). Se elige en la configuración.
/// </summary>
enum 51105 "Estrategia Picking SGA"
{
    Extensible = true;
    Caption = 'Estrategia picking SGA';

    value(0; FIFO)
    {
        Caption = 'FIFO (primera entrada)';
    }
    value(1; FEFO)
    {
        Caption = 'FEFO (primera caducidad)';
    }
    value(3; "Orden Ubicacion")
    {
        Caption = 'Por orden de ubicación';
    }
}
