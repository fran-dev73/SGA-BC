namespace AntonioNadal.SGA;

/// <summary>
/// Enum Estrategia Ubicacion SGA (ID 51104).
/// Política de decisión del motor de ubicación (put-away). Se configura en Fase 1
/// y la consume el motor de la Fase 2.
/// </summary>
enum 51104 "Estrategia Ubicacion SGA"
{
    Extensible = true;
    Caption = 'Estrategia ubicación SGA';

    value(0; Estandar)
    {
        Caption = 'Estándar: fija > consolidar > libre';
    }
    value(1; "Priorizar Consolidacion")
    {
        Caption = 'Priorizar consolidación';
    }
    value(2; "Solo Ubicacion Fija")
    {
        Caption = 'Solo ubicación fija';
    }
    value(3; "Primera Libre por Ruta")
    {
        Caption = 'Primera libre por ruta';
    }
    value(4; "Solo Hueco Vacio")
    {
        Caption = 'Solo hueco vacío';
    }
}
