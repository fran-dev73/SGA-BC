namespace AntonioNadal.SGA;

/// <summary>
/// Page Rol Center Preparador SGA (ID 51133).
/// Área de trabajo de la PDA: lo justo para preparar desde la app móvil de BC. La primera
/// opción abre directamente la pantalla de preparación, que busca sola la orden que le toca
/// (al carretillero, una reubicación) y encadena una tras otra; el resto son la lista de
/// órdenes y las consultas que necesita en el pasillo.
///
/// Lo publica el perfil "PREPARADOR SGA".
/// </summary>
page 51133 "Rol Center Preparador SGA"
{
    Caption = 'Preparador SGA';
    PageType = RoleCenter;

    layout
    {
        area(RoleCenter)
        {
            part(Cues; "Cue Preparador SGA")
            {
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        area(Embedding)
        {
            action(Preparar)
            {
                Caption = 'Preparar pedidos SGA';
                ToolTip = 'Abre la pantalla de preparación con la siguiente orden que le toca y, al terminarla, pasa sola a la siguiente.';
                ApplicationArea = All;
                RunObject = page "Preparar Picking SGA";
            }
            action(OrdenesPicking)
            {
                Caption = 'Órdenes de picking';
                ToolTip = 'Las órdenes por preparar, para elegir una concreta.';
                ApplicationArea = All;
                RunObject = page "Ordenes Picking SGA";
            }
            action(Reubicaciones)
            {
                Caption = 'Reubicaciones';
                ToolTip = 'Lo que hay que llevar de almacenamiento a picking.';
                ApplicationArea = All;
                RunObject = page "Reubicaciones SGA";
            }
            action(DondeEsta)
            {
                Caption = '¿Dónde está el producto?';
                ToolTip = 'Localiza un producto y dice a qué ubicación hay que ir a recogerlo.';
                ApplicationArea = All;
                RunObject = page "Consulta Ubic. Producto SGA";
            }
            action(Contenido)
            {
                Caption = 'Contenido de ubicaciones';
                ToolTip = 'Qué hay en cada ubicación: producto, lote, caducidad y cantidad.';
                ApplicationArea = All;
                RunObject = page "Contenido Ubicaciones SGA";
            }
        }
    }
}
