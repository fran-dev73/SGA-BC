namespace AntonioNadal.SGA;

/// <summary>
/// Enum Control Capacidad Ubic. SGA (ID 51112).
/// Qué hacer cuando una entrada no cabe en una ubicación concreta: lo que diga el control de
/// capacidad general de "Config. SGA", o uno propio. Lo decide SoloAvisaCapacidad de la tabla
/// "Ubicacion SGA".
/// </summary>
enum 51112 "Control Capacidad Ubic. SGA"
{
    Extensible = true;
    Caption = 'Control capacidad ubicación SGA';

    value(0; "Segun Configuracion")
    {
        Caption = 'Según configuración';
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
