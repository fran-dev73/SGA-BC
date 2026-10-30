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
                        ToolTip = 'Huecos libres: cada palé a un hueco de palé vacío por la ruta y el resto en cajas a un hueco mixto; lo que no cabe no se carga. Ubicación fija del producto: a su casa (Shelf No.) o, si no tiene, a la ubicación indicada. Ubicación indicada: todo a una ubicación de paso.';
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

    local procedure Ejecutar()
    var
        TempResultado: Record "Linea Ubicacion SGA" temporary;
        cCarga: Codeunit "Carga Inicial SGA";
        pResultado: Page "Resultado Carga Inicial SGA";
        productos: Integer;
        cargadas: Decimal;
        noCargadas: Decimal;
        textoError: Text;
        ConfirmarCargaQst: Label 'Se va a crear el contenido inicial de las ubicaciones del almacén %1 a partir del stock actual. ¿Desea continuar?', Comment = '%1 = almacén';
        SimulacionTerminadaMsg: Label 'Simulación terminada (no se ha guardado nada).\Productos con stock: %1.\Unidades que se cargarían: %2.\Unidades que se quedarían sin cargar: %3.%4', Comment = '%1 = productos, %2 = unidades cargadas, %3 = unidades sin cargar, %4 = resumen por motivo';
        CargaTerminadaMsg: Label 'Carga inicial terminada.\Productos con stock: %1.\Unidades cargadas: %2.\Unidades sin cargar: %3.%4', Comment = '%1 = productos, %2 = unidades cargadas, %3 = unidades sin cargar, %4 = resumen por motivo';
    begin
        if (not blnSimular) and GuiAllowed() then
            if not Confirm(ConfirmarCargaQst, false, codAlmacen) then
                exit;

        cCarga.Configurar(codAlmacen, optDestino, UbicacionIndicadaEfectiva(), blnOmitirConContenido, blnSimular, Producto.GetView());

        // Codeunit.Run para poder recoger el fin de simulación, que llega como error para que
        // la base de datos deshaga lo escrito.
        if not cCarga.Run() then begin
            textoError := GetLastErrorText();
            if not cCarga.EsFinSimulacion(textoError) then
                Error(textoError);
        end;

        cCarga.ObtenerTotales(productos, cargadas, noCargadas);
        cCarga.ObtenerResultado(TempResultado);

        if not GuiAllowed() then
            exit;

        if blnSimular then
            Message(SimulacionTerminadaMsg, productos, cargadas, noCargadas, ResumenNoCargado(TempResultado))
        else
            Message(CargaTerminadaMsg, productos, cargadas, noCargadas, ResumenNoCargado(TempResultado));

        if not TempResultado.IsEmpty() then begin
            pResultado.Rellenar(TempResultado);
            pResultado.Run();
        end;
    end;

    /// <summary>
    /// Con "Huecos libres" el hueco lo elige el sistema: la ubicación indicada no se deja tocar
    /// y no se usa, tampoco para los productos sin palé, que salen como no cargados.
    /// </summary>
    local procedure ActualizarUbicacionIndicada()
    begin
        blnUbicacionIndicadaEditable := optDestino <> optDestino::"Huecos Libres";
    end;

    local procedure UbicacionIndicadaEfectiva(): Code[20]
    begin
        if optDestino = optDestino::"Huecos Libres" then
            exit('');
        exit(codUbicacionIndicada);
    end;

    /// <summary>
    /// Lo que no se ha cargado, agrupado por la causa (la primera frase del motivo): cuántas
    /// líneas por causa, de la más repetida a la menos, hasta 6. El detalle de cada línea, con
    /// qué hacer, está en la página de resultado.
    /// </summary>
    local procedure ResumenNoCargado(var prm_Resultado: Record "Linea Ubicacion SGA" temporary): Text
    var
        lineas: Dictionary of [Text, Integer];
        causas: List of [Text];
        causa: Text;
        elegida: Text;
        texto: Text;
        n: Integer;
        mayor: Integer;
        vuelta: Integer;
        CabeceraLbl: Label '\\Sin cargar, por motivo:';
        LineaLbl: Label '\- %1 (%2 líneas)', Comment = '%1 = causa, %2 = número de líneas';
        MasLbl: Label '\- … y %1 motivos más (ver el detalle).', Comment = '%1 = número de motivos';
    begin
        prm_Resultado.Reset();
        prm_Resultado.SetRange(Estado, prm_Resultado.Estado::"Sin Sitio");
        if not prm_Resultado.FindSet() then begin
            prm_Resultado.Reset();
            exit('');
        end;
        repeat
            causa := PrimeraFrase(prm_Resultado.Motivo);
            if lineas.Get(causa, n) then
                lineas.Set(causa, n + 1)
            else begin
                lineas.Add(causa, 1);
                causas.Add(causa);
            end;
        until prm_Resultado.Next() = 0;
        prm_Resultado.Reset();

        texto := CabeceraLbl;
        for vuelta := 1 to 6 do begin
            mayor := 0;
            elegida := '';
            foreach causa in causas do
                if lineas.Get(causa) > mayor then begin
                    mayor := lineas.Get(causa);
                    elegida := causa;
                end;
            if mayor = 0 then
                exit(texto);
            texto += StrSubstNo(LineaLbl, elegida, mayor);
            lineas.Set(elegida, 0);
        end;

        n := 0;
        foreach causa in causas do
            if lineas.Get(causa) > 0 then
                n += 1;
        if n > 0 then
            texto += StrSubstNo(MasLbl, n);
        exit(texto);
    end;

    /// <summary>
    /// La causa de un motivo: hasta el primer punto. Los motivos empiezan siempre por ella.
    /// </summary>
    local procedure PrimeraFrase(prm_Texto: Text): Text
    var
        p: Integer;
    begin
        p := StrPos(prm_Texto, '. ');
        if p > 0 then
            exit(CopyStr(prm_Texto, 1, p));
        exit(prm_Texto);
    end;
}
