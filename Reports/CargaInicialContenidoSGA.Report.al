namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Warehouse.Structure;

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

                        trigger OnValidate()
                        begin
                            ActualizarUbicacionIndicada();
                        end;
                    }
                    field(UbicacionIndicada; codUbicacionIndicada)
                    {
                        Caption = 'Ubicación indicada';
                        ToolTip = 'Ubicación de paso. Con "Ubicación indicada" va todo aquí; con "Ubicación fija del producto", solo los productos sin casa. Con "Huecos libres" no se usa: el sistema elige el hueco, y lo que no tiene sitio sale como no cargado.';
                        Editable = blnUbicacionIndicadaEditable;
                        ApplicationArea = All;
                        TableRelation = Bin.Code;
                    }
                    field(MaxPickingProducto; intMaxPickingProducto)
                    {
                        Caption = 'Máx. ubicaciones de picking por producto';
                        ToolTip = 'Con "Huecos libres", cuántas ubicaciones de picking puede ocupar cada producto. Así picking no se llena de palés de unos pocos productos y queda sitio para todos; el resto de sus palés va a almacenamiento. Cuentan también las que ya ocupa. Sus ubicaciones reservadas (Producto fijo) se llenan igualmente.';
                        ApplicationArea = All;
                        MinValue = 1;
                        Editable = blnMaxPickingEditable;
                    }
                    field(OmitirConContenido; blnOmitirConContenido)
                    {
                        Caption = 'Omitir productos que ya están ubicados';
                        ToolTip = 'Salta los productos que ya tienen contenido en alguna ubicación de este almacén, para poder volver a ejecutar el proceso sin duplicar.';
                        ApplicationArea = All;
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
            ActualizarUbicacionIndicada();
        end;
    }

    var
        codAlmacen: Code[10];
        codUbicacionIndicada: Code[20];
        // "Huecos Libres" va al final para no cambiar lo que tengan guardado los usuarios (SaveValues).
        optDestino: Option "Ubicacion Fija del Producto","Ubicacion Indicada","Huecos Libres";
        blnOmitirConContenido: Boolean;
        blnSimular: Boolean;
        blnUbicacionIndicadaEditable: Boolean;
        blnMaxPickingEditable: Boolean;
        intMaxPickingProducto: Integer;

    local procedure Ejecutar()
    var
        TempResultado: Record "Linea Ubicacion SGA" temporary;
        cCarga: Codeunit "Carga Inicial SGA";
        pResultado: Page "Resultado Carga Inicial SGA";
        textoError: Text;
        ConfirmarCargaQst: Label 'Se va a crear el contenido inicial de las ubicaciones del almacén %1 a partir del stock actual. ¿Desea continuar?', Comment = '%1 = almacén';
        ProcesoFinalizadoMsg: Label 'Proceso finalizado.';
    begin
        if (not blnSimular) and GuiAllowed() then
            if not Confirm(ConfirmarCargaQst, false, codAlmacen) then
                exit;

        cCarga.Configurar(codAlmacen, optDestino, UbicacionIndicadaEfectiva(), blnOmitirConContenido, blnSimular, Producto.GetView());
        cCarga.FijarMaxPickingProducto(intMaxPickingProducto);

        // Codeunit.Run para poder recoger el fin de simulación, que llega como error para que
        // la base de datos deshaga lo escrito.
        if not cCarga.Run() then begin
            textoError := GetLastErrorText();
            if not cCarga.EsFinSimulacion(textoError) then
                Error(textoError);
        end;

        if not GuiAllowed() then
            exit;

        // Solo el aviso de fin: el detalle, línea a línea y con su motivo, está en la página
        // de resultado.
        Message(ProcesoFinalizadoMsg);

        cCarga.ObtenerResultado(TempResultado);
        if not TempResultado.IsEmpty() then begin
            pResultado.Rellenar(TempResultado);
            pResultado.Run();
        end;
    end;

    /// <summary>
    /// Con "Huecos libres" el hueco lo elige el sistema: la ubicación indicada no se deja tocar
    /// y no se usa, tampoco para los productos sin palé, que salen como no cargados. El máximo
    /// de picking por producto, al revés: solo cuenta con "Huecos libres".
    /// </summary>
    local procedure ActualizarUbicacionIndicada()
    begin
        blnUbicacionIndicadaEditable := optDestino <> optDestino::"Huecos Libres";
        blnMaxPickingEditable := not blnUbicacionIndicadaEditable;
    end;

    local procedure UbicacionIndicadaEfectiva(): Code[20]
    begin
        if optDestino = optDestino::"Huecos Libres" then
            exit('');
        exit(codUbicacionIndicada);
    end;
}
