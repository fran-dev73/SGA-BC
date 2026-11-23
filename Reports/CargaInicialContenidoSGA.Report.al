namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using System.Utilities;

/// <summary>
/// Report Carga Inicial Contenido SGA (ID 51102).
/// Arranca el módulo dando de alta en las ubicaciones el stock que ya existe en BC. Aquí solo
/// se piden las opciones: el trabajo lo hace Cod. "Carga Inicial SGA", que es también quien
/// simula (haciendo la carga y deshaciéndola).
///
/// No modifica el stock de BC en ningún caso: solo crea la capa de ubicaciones.
/// </summary>
report 51102 "Carga Inicial Contenido SGA"
{
    Caption = 'Carga inicial de contenido SGA';
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
                        ToolTip = 'Almacén cuyo stock se va a dar de alta en ubicaciones.';
                        ApplicationArea = All;
                        TableRelation = Location;
                        ShowMandatory = true;
                    }
                    field(Destino; optDestino)
                    {
                        Caption = 'Ubicación de destino';
                        OptionCaption = 'Ubicación fija del producto,Ubicación indicada,Huecos libres';
                        ToolTip = 'Huecos libres: cada palé a un hueco vacío por la ruta (primero picking, hasta el máximo por producto, y luego almacenamiento) y el resto junto a un hueco con sitio; lo que no cabe no se carga. Ubicación fija del producto: a su casa (Shelf No.) o, si no tiene, a la ubicación indicada. Ubicación indicada: todo a una ubicación de paso.';
                        ApplicationArea = All;
                    }
                    field(UbicacionIndicada; codUbicacionIndicada)
                    {
                        Caption = 'Ubicación indicada';
                        ToolTip = 'Ubicación de paso. Con "Ubicación indicada" va todo aquí; con "Ubicación fija del producto", solo los productos sin casa. Con "Huecos libres" no se usa: el sistema elige el hueco, y lo que no tiene sitio sale como no cargado.';
                        Editable = optDestino <> optDestino::"Huecos Libres";
                        ApplicationArea = All;

                        trigger OnLookup(var Text: Text): Boolean
                        var
                            rUbicacionSGA: Record "Ubicacion SGA";
                        begin
                            rUbicacionSGA.SetRange("Cod. Almacen", codAlmacen);
                            if Page.RunModal(0, rUbicacionSGA) <> Action::LookupOK then
                                exit(false);
                            Text := rUbicacionSGA."Cod. Bin";
                            exit(true);
                        end;

                        trigger OnValidate()
                        var
                            cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
                        begin
                            // Solo ubicaciones del almacén que se carga.
                            cUbicaciones.ComprobarUbicacionExiste(codAlmacen, codUbicacionIndicada);
                        end;
                    }
                    field(MaxPickingProducto; intMaxPickingProducto)
                    {
                        Caption = 'Máx. ubicaciones de picking por producto';
                        ToolTip = 'Con "Huecos libres", cuántas ubicaciones de picking puede ocupar cada producto. Así picking no se llena de palés de unos pocos productos y queda sitio para todos; el resto de sus palés va a almacenamiento. Cuentan también las que ya ocupa. Sus ubicaciones reservadas (Producto fijo) se llenan igualmente.';
                        ApplicationArea = All;
                        MinValue = 1;
                        Editable = optDestino = optDestino::"Huecos Libres";
                    }
                    field(Simular; blnSimular)
                    {
                        Caption = 'Solo simular';
                        ToolTip = 'Hace el reparto completo, enseña el resultado hueco a hueco y lo deshace. Conviene ejecutarlo así la primera vez.';
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
            if codUbicacionIndicada = '' then
                codUbicacionIndicada := rConfig."Ubic. Ajustes";
            if intMaxPickingProducto = 0 then
                intMaxPickingProducto := 1;
        end;
    }

    var
        codAlmacen: Code[10];
        codUbicacionIndicada: Code[20];
        // "Huecos Libres" va al final para no cambiar lo que tengan guardado los usuarios (SaveValues).
        optDestino: Option "Ubicacion Fija del Producto","Ubicacion Indicada","Huecos Libres";
        blnSimular: Boolean;
        intMaxPickingProducto: Integer;

    local procedure Ejecutar()
    var
        cCarga: Codeunit "Carga Inicial SGA";
        cConfirmMgt: Codeunit "Confirm Management";
        ConfirmarCargaQst: Label 'Se va a crear el contenido inicial de las ubicaciones del almacén %1 a partir del stock actual. ¿Desea continuar?', Comment = '%1 = almacén';
    begin
        if (not blnSimular) and GuiAllowed() then
            if not cConfirmMgt.GetResponseOrDefault(StrSubstNo(ConfirmarCargaQst, codAlmacen), false) then
                exit;

        cCarga.Configurar(codAlmacen, optDestino, codUbicacionIndicada, blnSimular, Producto.GetView(), intMaxPickingProducto);
        cCarga.MostrarResultado(cCarga.Run());
    end;
}
