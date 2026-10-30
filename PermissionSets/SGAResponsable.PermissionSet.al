namespace AntonioNadal.SGA;

/// <summary>
/// PermissionSet SGA Responsable (ID 51101).
/// Lo de "PermissionSet-SGA" más el reparto de órdenes de picking. Se asigna a los
/// responsables de almacén; los preparadores se quedan con "PermissionSet-SGA".
///
/// Ojo: el permiso sobre la página ordena, pero no impide. Los conjuntos estándar de BC suelen
/// dar ejecución sobre todas las páginas, así que lo que de verdad frena a un preparador es la
/// casilla "Responsable picking SGA" de Configuración de usuarios, que se comprueba por código
/// cuando la configuración exige asignación.
/// </summary>
permissionset 51101 "SGA-Responsable"
{
    Assignable = true;
    Caption = 'SGA - Responsable de almacén';
    IncludedPermissionSets = "PermissionSet-SGA";

    Permissions = page "Asignar Ordenes Picking SGA" = X;
}
