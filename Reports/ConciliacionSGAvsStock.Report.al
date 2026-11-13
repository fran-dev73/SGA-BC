namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;

/// <summary>
/// Report Conciliacion SGA vs Stock (ID 51103).
/// Compara, producto a producto y lote a lote, el stock que tiene BC con el contenido que
/// SGA tiene ubicado, y deja el resultado en la página "Conciliacion SGA".
///
/// Es el control que evita que la capa de ubicaciones se degrade: si aparecen diferencias,
/// o falta ubicar mercancía que ya entró, o sobra contenido que ya salió sin registrarse.
/// </summary>
report 51103 "Conciliacion SGA vs Stock"
{
    Caption = 'Conciliación SGA vs stock';
    ProcessingOnly = true;
    UsageCategory = Tasks;
    ApplicationArea = All;

    dataset
    {
        dataitem(Producto; Item)
        {
            RequestFilterFields = "No.", "Item Category Code", "Inventory Posting Group";

            trigger OnPreDataItem()
            begin
                Producto.SetRange(Type, Producto.Type::Inventory);
                cStock.LimpiarBuffer(rBuffer);
                ProductosRevisados := 0;
            end;

            trigger OnAfterGetRecord()
            begin
                cStock.AcumularStockPorLote(Producto."No.", codAlmacen, rBuffer);
                cStock.AcumularContenidoUbicado(Producto."No.", codAlmacen, rBuffer);
                ProductosRevisados += 1;
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
                        ToolTip = 'Almacén que se concilia. En blanco concilia todos.';
                        ApplicationArea = All;
                        TableRelation = Location;
                    }
                    field(SoloDiferencias; blnSoloDiferencias)
                    {
                        Caption = 'Mostrar solo diferencias';
                        ToolTip = 'Descarta del resultado las combinaciones producto-lote que ya cuadran.';
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
            blnSoloDiferencias := true;
        end;
    }

    var
        rBuffer: Record "Buffer Conciliacion SGA";
        cStock: Codeunit "Consulta Stock SGA";
        codAlmacen: Code[10];
        blnSoloDiferencias: Boolean;
        ProductosRevisados: Integer;

    trigger OnPostReport()
    var
        pagConciliacion: Page "Conciliacion SGA";
        SinDiferenciasMsg: Label 'Se han revisado %1 productos y no hay ninguna diferencia entre el stock de BC y el contenido de las ubicaciones.', Comment = '%1 = productos revisados';
    begin
        cStock.ClasificarYFiltrar(rBuffer, blnSoloDiferencias);

        if rBuffer.IsEmpty() then begin
            if GuiAllowed() then
                Message(SinDiferenciasMsg, ProductosRevisados);
            exit;
        end;

        if not GuiAllowed() then
            exit;

        pagConciliacion.SetTableView(rBuffer);
        pagConciliacion.Run();
    end;
}
