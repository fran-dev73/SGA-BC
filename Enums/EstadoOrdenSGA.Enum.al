namespace AntonioNadal.SGA;

/// <summary>
/// Enum Estado Orden SGA (ID 51107).
/// Situación de una orden de trabajo de almacén (picking) dentro de su ciclo de vida.
/// </summary>
enum 51107 "Estado Orden SGA"
{
    Extensible = true;
    Caption = 'Estado orden SGA';

    value(0; Abierta)
    {
        Caption = 'Abierta';
    }
    value(1; "En Proceso")
    {
        Caption = 'En proceso';
    }
    value(2; Finalizada)
    {
        Caption = 'Finalizada';
    }
    value(3; Cancelada)
    {
        Caption = 'Cancelada';
    }
    // Ordinal 4 y al final para no mover los valores ya guardados. Solo se usa con
    // "Exigir Asignacion Picking": la orden espera aquí hasta que un responsable la reparte.
    value(4; "Pendiente Asignar")
    {
        Caption = 'Pendiente de asignar';
    }
}
