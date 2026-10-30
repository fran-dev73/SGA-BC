namespace AntonioNadal.SGA;

using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
using System.Security.User;

/// <summary>
/// PermissionSet SGA (ID 51100).
/// Permisos de los objetos de SGA. Se mantiene aparte de "PermissionSet-AN" para que
/// todo el módulo viva en su propia carpeta y se pueda asignar por separado al personal
/// de almacén.
/// </summary>
permissionset 51100 "PermissionSet-SGA"
{
    Assignable = true;
    Caption = 'PermissionSet-SGA';

    Permissions = table "Zona SGA" = X,
        tabledata "Zona SGA" = RIMD,
        table "Ubicacion SGA" = X,
        tabledata "Ubicacion SGA" = RIMD,
        table "Contenido Ubicacion SGA" = X,
        tabledata "Contenido Ubicacion SGA" = RIMD,
        table "Movimiento Ubicacion SGA" = X,
        tabledata "Movimiento Ubicacion SGA" = RIMD,
        table "Config. SGA" = X,
        tabledata "Config. SGA" = RIMD,
        table "Cue SGA" = X,
        tabledata "Cue SGA" = RIMD,
        table "Buffer Mapa SGA" = X,
        tabledata "Buffer Mapa SGA" = RIMD,
        table "Buffer Conciliacion SGA" = X,
        tabledata "Buffer Conciliacion SGA" = RIMD,
        codeunit "Carga Inicial SGA" = X,
        page "Resultado Carga Inicial SGA" = X,
        table "Orden Picking SGA" = X,
        tabledata "Orden Picking SGA" = RIMD,
        table "Linea Orden Picking SGA" = X,
        tabledata "Linea Orden Picking SGA" = RIMD,
        // Al terminar un picking se escribe en el pedido: cantidad a enviar y seguimiento por lote.
        tabledata "Sales Line" = RM,
        tabledata "Reservation Entry" = RIMD,
        // Para saber si el usuario es responsable de picking.
        tabledata "User Setup" = R,
        codeunit "Gestion Contenido SGA" = X,
        codeunit "Gestion Ubicaciones SGA" = X,
        codeunit "Gestion Mapa SGA" = X,
        codeunit "Consulta Stock SGA" = X,
        codeunit "Gestion Picking SGA" = X,
        codeunit "Gestion Entradas SGA" = X,
        codeunit "Unidades Producto SGA" = X,
        table "Calculo ABC SGA" = X,
        tabledata "Calculo ABC SGA" = RIMD,
        table "Clasificacion ABC SGA" = X,
        tabledata "Clasificacion ABC SGA" = RIMD,
        // El análisis ABC lee las ventas de los movimientos de producto.
        tabledata "Item Ledger Entry" = R,
        codeunit "Analisis ABC SGA" = X,
        page "Analisis ABC SGA" = X,
        page "Calculos ABC SGA" = X,
        page "Ubicaciones SGA" = X,
        page "Ficha Ubicacion SGA" = X,
        page "Contenido Ubicacion Subpag" = X,
        page "Contenido Ubicaciones SGA" = X,
        page "Movs. Ubicacion SGA" = X,
        page "Zonas SGA" = X,
        page "Config. SGA" = X,
        page "Mapa Almacen SGA" = X,
        page "Mapa 3D Almacen SGA" = X,
        page "Consulta Ubic. Producto SGA" = X,
        page "Ubicaciones Producto FactBox" = X,
        page "Movs. Ubicacion FactBox" = X,
        page "Cue SGA" = X,
        page "Rol Center Almacen SGA" = X,
        page "Conciliacion SGA" = X,
        page "Mover Contenido SGA" = X,
        page "Recontar Contenido SGA" = X,
        page "Ubicar Producto SGA" = X,
        page "Pendiente Ubicar SGA" = X,
        page "Plan Ubicacion SGA Subpag" = X,
        page "Ubicar Entradas SGA" = X,
        page "Ubicar Palets Linea SGA" = X,
        page "Cambiar Ubicaciones SGA" = X,
        page "Ordenes Picking SGA" = X,
        page "Ficha Orden Picking SGA" = X,
        page "Lineas Orden Picking Subpag" = X,
        page "Preparar Picking SGA" = X,
        report "Generar Ubicaciones SGA" = X,
        report "Sincronizar Ubicaciones SGA" = X,
        report "Carga Inicial Contenido SGA" = X,
        report "Conciliacion SGA vs Stock" = X,
        report "Inventario por Ubicacion SGA" = X,
        report "Ocupacion Ubicaciones SGA" = X,
        report "Etiquetas Ubicaciones SGA" = X;
}
