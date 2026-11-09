namespace AntonioNadal.SGA;

/// <summary>
/// Profile ALMACEN SGA.
/// Rol del almacenero: publica el área de trabajo "Rol Center Almacen SGA" para que se pueda
/// elegir en Mi configuración o asignar a usuarios y grupos.
/// </summary>
profile "ALMACEN SGA"
{
    Caption = 'Almacén SGA';
    ProfileDescription = 'Almacenero: ubicar, preparar pedidos, controlar el contenido de las ubicaciones y consultar productos, pedidos y albaranes de venta y compra.';
    RoleCenter = "Rol Center Almacen SGA";
    Enabled = true;
}
