namespace AntonioNadal.SGA;

using Microsoft.Inventory.Location;
using System.Utilities;

/// <summary>
/// Report Sincronizar Ubicaciones SGA (ID 51101).
/// Da de alta en SGA las ubicaciones de la topología que aún no tienen datos de gestión
/// de almacén, recalcula la ocupación y, si se pide, reconstruye el contenido a partir del
/// diario de movimientos.
///
/// La reconstrucción es la red de seguridad del módulo: deja el contenido exactamente como
/// lo dictan los movimientos registrados. Las reservas de las órdenes abiertas no se
/// conservan, porque las vuelve a fijar la gestión de órdenes.
/// </summary>
report 51101 "Sincronizar Ubicaciones SGA"
{
    Caption = 'Sincronizar ubicaciones SGA';
    ProcessingOnly = true;
    UsageCategory = Tasks;
    ApplicationArea = All;

    dataset
    {
        dataitem(Proceso; Integer)
        {
            DataItemTableView = sorting(Number) where(Number = const(1));

            trigger OnAfterGetRecord()
            var
                cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
                cContenido: Codeunit "Gestion Contenido SGA";
                ConfirmarReconstruirQst: Label 'Se va a borrar el contenido por ubicación del almacén %1 y a reconstruirlo desde el diario de movimientos. Las reservas de las órdenes abiertas se perderán. ¿Desea continuar?', Comment = '%1 = almacén, o "todos" si no se ha filtrado';
                TodosAlmacenesLbl: Label 'todos los almacenes';
                ProcesoFinalizadoMsg: Label 'Proceso finalizado.';
                textoAlmacen: Text;
            begin
                cUbicaciones.SincronizarTopologia(codAlmacen);

                if not blnReconstruirContenido then begin
                    cUbicaciones.RecalcularEstados(codAlmacen);
                    if GuiAllowed() then
                        Message(ProcesoFinalizadoMsg);
                    exit;
                end;

                if codAlmacen <> '' then
                    textoAlmacen := codAlmacen
                else
                    textoAlmacen := TodosAlmacenesLbl;

                if GuiAllowed() then
                    if not Confirm(ConfirmarReconstruirQst, false, textoAlmacen) then
                        exit;

                cContenido.FijarModoSilencioso(true);
                cContenido.ReconstruirContenido(codAlmacen);
                cUbicaciones.RecalcularEstados(codAlmacen);

                if GuiAllowed() then
                    Message(ProcesoFinalizadoMsg);
            end;
        }
    }

    requestpage
    {
        SaveValues = true;

        layout
        {
            area(Content)
            {
                group(Opciones)
                {
                    Caption = 'Opciones';

                    field(Almacen; codAlmacen)
                    {
                        Caption = 'Almacén';
                        ToolTip = 'Almacén que se sincroniza. En blanco sincroniza todos.';
                        ApplicationArea = All;
                        TableRelation = Location;
                    }
                    field(ReconstruirContenido; blnReconstruirContenido)
                    {
                        Caption = 'Reconstruir contenido desde los movimientos';
                        ToolTip = 'Borra el contenido por ubicación y lo vuelve a construir reproduciendo el diario de movimientos. Úselo solo si sospecha que el contenido está descuadrado.';
                        ApplicationArea = All;
                    }
                }
            }
        }

        trigger OnOpenPage()
        var
            rConfig: Record "Config. SGA";
        begin
            rConfig.ObtenerConfig();
            if codAlmacen = '' then
                codAlmacen := rConfig."Almacen por Defecto";
        end;
    }

    var
        codAlmacen: Code[10];
        blnReconstruirContenido: Boolean;
}
