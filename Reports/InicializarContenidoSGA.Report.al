namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;

/// <summary>
/// Report Inicializar Contenido SGA (ID 51107).
/// Lo contrario de la carga inicial: deja el almacén sin nada ubicado, borrando el contenido,
/// los movimientos de ubicación y las órdenes de picking sin terminar. Con "Eliminar también
/// las ubicaciones" borra además todos los huecos del almacén (ficha SGA y Bin), para volver a
/// generarlos; si no, las ubicaciones se quedan. Aquí solo se piden las opciones; el trabajo lo
/// hacen Inicializar de Cod. "Gestion Contenido SGA" y EliminarUbicaciones de Cod. "Gestion
/// Ubicaciones SGA".
///
/// No toca el stock de BC.
/// </summary>
report 51107 "Inicializar Contenido SGA"
{
    Caption = 'Inicializar contenido SGA';
    ProcessingOnly = true;
    UsageCategory = Tasks;
    ApplicationArea = All;

    dataset
    {
        // El dataitem solo sirve para que el usuario filtre productos; se recorre en el codeunit.
        dataitem(Producto; Item)
        {
            RequestFilterFields = "No.", "Item Category Code", "Inventory Posting Group";

            trigger OnPreDataItem()
            begin
                Ejecutar();
                CurrReport.Break();
            end;
        }
    }

    requestpage
    {
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
                        ToolTip = 'Almacén que se deja sin nada ubicado. Con filtro de productos, solo esos productos.';
                        ApplicationArea = All;
                        TableRelation = Location;
                        ShowMandatory = true;
                    }
                    field(EliminarUbicaciones; blnEliminarUbicaciones)
                    {
                        Caption = 'Eliminar también las ubicaciones';
                        ToolTip = 'Borra además todas las ubicaciones del almacén (la ficha SGA y la ubicación de BC), para volver a generarlas. Solo sin filtro de productos. Las que tienen stock o documentos de almacén pendientes en BC no se pueden borrar y se quedan.';
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
        blnEliminarUbicaciones: Boolean;

    local procedure Ejecutar()
    var
        cContenido: Codeunit "Gestion Contenido SGA";
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        alcance: Text;
        ejemplos: Text;
        motivo: Text;
        eliminadas: Integer;
        noEliminadas: Integer;
        InicializarQst: Label 'Se va a borrar el contenido de las ubicaciones del almacén %1 (%2), todos sus movimientos de ubicación y las órdenes de picking sin terminar. Las ubicaciones y el stock de BC no cambian. No se puede deshacer.\\¿Desea continuar?', Comment = '%1 = almacén, %2 = qué productos';
        EliminarUbicacionesQst: Label 'Se va a borrar todo lo del almacén %1 en SGA: el contenido de las ubicaciones, todos sus movimientos, las órdenes de picking sin terminar y las propias ubicaciones (ficha SGA y ubicación de BC). El stock de BC no cambia. No se puede deshacer.\\¿Desea continuar?', Comment = '%1 = almacén';
        EliminarConFiltroErr: Label 'Para eliminar las ubicaciones quite el filtro de productos: se borra el almacén entero.';
        TodosProductosLbl: Label 'todos los productos';
        ProcesoFinalizadoMsg: Label 'Proceso finalizado.';
        UbicacionesEliminadasMsg: Label 'Proceso finalizado. Ubicaciones eliminadas: %1.', Comment = '%1 = cuántas';
        UbicacionesNoEliminadasMsg: Label 'Proceso finalizado. Ubicaciones eliminadas: %1. No se han podido eliminar %2 (por ejemplo: %3).\\Motivo de la primera: %4', Comment = '%1 = eliminadas, %2 = no eliminadas, %3 = primeras ubicaciones, %4 = error de BC';
    begin
        alcance := Producto.GetFilters();
        if blnEliminarUbicaciones and (alcance <> '') then
            Error(EliminarConFiltroErr);

        if alcance = '' then
            alcance := TodosProductosLbl;
        if GuiAllowed() then
            if blnEliminarUbicaciones then begin
                if not Confirm(EliminarUbicacionesQst, false, codAlmacen) then
                    exit;
            end else
                if not Confirm(InicializarQst, false, codAlmacen, alcance) then
                    exit;

        cContenido.Inicializar(codAlmacen, Producto.GetView());
        if blnEliminarUbicaciones then
            eliminadas := cUbicaciones.EliminarUbicaciones(codAlmacen, noEliminadas, ejemplos, motivo);

        if not GuiAllowed() then
            exit;
        case true of
            not blnEliminarUbicaciones:
                Message(ProcesoFinalizadoMsg);
            noEliminadas = 0:
                Message(UbicacionesEliminadasMsg, eliminadas);
            else
                Message(UbicacionesNoEliminadasMsg, eliminadas, noEliminadas, ejemplos, motivo);
        end;
    end;
}
