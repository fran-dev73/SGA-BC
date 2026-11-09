namespace AntonioNadal.SGA;

/// <summary>
/// Enum Control Capacidad SGA (ID 51106).
/// Qué hacer cuando una entrada supera la capacidad declarada de la ubicación.
/// "No comprobar" ya no se ofrece (la configuración solo deja Avisar o Bloquear) y, si una
/// configuración antigua lo tiene, Cod. "Gestion Contenido SGA" bloquea igual que Bloquear.
/// El valor se queda para no dejar sin sentido los datos guardados.
/// </summary>
enum 51106 "Control Capacidad SGA"
{
    Extensible = true;
    Caption = 'Control capacidad SGA';

    value(0; "No Comprobar")
    {
        Caption = 'No comprobar';
    }
    value(1; Avisar)
    {
        Caption = 'Avisar';
    }
    value(2; Bloquear)
    {
        Caption = 'Bloquear';
    }
}
