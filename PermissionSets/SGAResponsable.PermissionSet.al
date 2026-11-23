namespace AntonioNadal.SGA;

/// <summary>
/// PermissionSet SGA Responsable (ID 51101).
/// Lo de "PermissionSet-SGA" más la inicialización del contenido, que deja un almacén sin nada
/// ubicado. Se asigna a los responsables de almacén.
///
/// El reparto de órdenes de picking no va aquí: quién puede asignar lo decide la casilla
/// "Responsable picking SGA" de Configuración de usuarios, que se comprueba por código cuando
/// la configuración exige asignación. Sin ella el reparto es libre.
/// </summary>
permissionset 51101 "SGA-Responsable"
{
    Assignable = true;
    Caption = 'SGA - Responsable de almacén';
    IncludedPermissionSets = "PermissionSet-SGA";

    Permissions = report "Inicializar Contenido SGA" = X;
}
