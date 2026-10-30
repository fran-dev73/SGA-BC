namespace AntonioNadal.SGA;

/// <summary>
/// Enum Estrategia Picking SGA (ID 51105).
/// Política de decisión del motor de picking. Se configura en Fase 1
/// y la consume el motor de la Fase 2.
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
    value(2; "Lote Exacto")
    {
        Caption = 'Lote exacto';
    }
    value(3; "Vaciar Ubicacion")
    {
        Caption = 'Vaciar ubicación';
    }
}
