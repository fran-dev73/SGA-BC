namespace AntonioNadal.SGA;

/// <summary>
/// Profile PREPARADOR SGA.
/// Rol de la PDA: publica el área de trabajo "Rol Center Preparador SGA" para asignarlo a los
/// preparadores y carretilleros que trabajan con la app móvil de BC.
/// </summary>
profile "PREPARADOR SGA"
{
    Caption = 'Preparador SGA (PDA)';
    ProfileDescription = 'Preparador o carretillero con PDA: prepara la siguiente orden de picking o reubicación escaneando producto y ubicación, y consulta dónde está cada producto.';
    RoleCenter = "Rol Center Preparador SGA";
    Enabled = true;
}
