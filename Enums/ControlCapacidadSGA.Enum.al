namespace AntonioNadal.SGA;

/// <summary>
/// Enum Control Capacidad SGA (ID 51106).
/// Qué hacer cuando una entrada supera la capacidad declarada de la ubicación: avisar o
/// bloquear. La capacidad se controla siempre.
/// </summary>
enum 51106 "Control Capacidad SGA"
{
    Extensible = true;
    Caption = 'Control capacidad SGA';

    value(1; Avisar)
    {
        Caption = 'Avisar';
    }
    value(2; Bloquear)
    {
        Caption = 'Bloquear';
    }
}
