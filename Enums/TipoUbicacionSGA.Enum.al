namespace AntonioNadal.SGA;

/// <summary>
/// Enum Tipo Ubicacion SGA (ID 51100).
/// Clasifica el uso funcional de una ubicación dentro del almacén.
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
    value(2; Reserva)
    {
        Caption = 'Reserva';
    }
    value(3; "Muelle Entrada")
    {
        Caption = 'Muelle entrada';
    }
    value(4; "Muelle Salida")
    {
        Caption = 'Muelle salida';
    }
    value(5; Produccion)
    {
        Caption = 'Producción';
    }
    value(6; Cuarentena)
    {
        Caption = 'Cuarentena';
    }
    value(7; Desbordamiento)
    {
        Caption = 'Desbordamiento';
    }
    value(8; Ajustes)
    {
        Caption = 'Ajustes';
    }
}
