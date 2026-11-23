namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;

/// <summary>
/// Report Conciliacion SGA vs Stock (ID 51103).
/// Compara, producto a producto y lote a lote, el stock que tiene BC con el contenido que
/// SGA tiene ubicado, y deja el resultado en la página "Conciliacion SGA". El cálculo lo hace
/// Conciliar de Cod. "Consulta Stock SGA"; el informe solo pide el almacén y los productos.
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
        // Solo para los filtros de productos de la página de petición.
        dataitem(Producto; Item)
        {
            RequestFilterFields = "No.", "Item Category Code", "Inventory Posting Group";

            trigger OnPreDataItem()
            begin
                Conciliar();
                CurrReport.Break();
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
                    field(MostrarCuadradas; blnMostrarCuadradas)
                    {
                        Caption = 'Mostrar también las que cuadran';
                        ToolTip = 'Incluye en el resultado las combinaciones producto-lote que ya cuadran. Desmarcado, solo salen las diferencias.';
                        ApplicationArea = All;
                    }
                }
            }
        }

        trigger OnOpenPage()
        var
            rConfig: Record "Config. SGA";
        begin
            codAlmacen := rConfig.AlmacenODefecto(codAlmacen);
        end;
    }

    var
        codAlmacen: Code[10];
        // En negativo para que, sin nada guardado (SaveValues), salgan solo las diferencias.
        blnMostrarCuadradas: Boolean;

    local procedure Conciliar()
    var
        cStock: Codeunit "Consulta Stock SGA";
        SinDiferenciasMsg: Label 'No hay ninguna diferencia entre el stock de BC y el contenido de las ubicaciones.';
    begin
        if cStock.Conciliar(codAlmacen, Producto.GetView(), not blnMostrarCuadradas) = 0 then begin
            if GuiAllowed() then
                Message(SinDiferenciasMsg);
            exit;
        end;

        if GuiAllowed() then
            Page.Run(Page::"Conciliacion SGA");
    end;
}
