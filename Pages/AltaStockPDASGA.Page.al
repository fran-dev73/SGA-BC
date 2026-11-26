namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using System.Device;

/// <summary>
/// Page Alta Stock PDA SGA (ID 51136).
/// Alta en SGA, palé a palé desde la PDA, del stock que ya está en el almacén y SGA aún no tiene
/// ubicado: con el almacén lleno no se puede vaciar para colocarlo todo con la carga inicial.
///
/// Misma base que "Preparar Picking SGA": la dibuja el control "Picking PDA SGA" (modo 'alta')
/// y las lecturas llegan igual, escaneadas o tecleadas en la casilla de lectura, o del escáner
/// de la app de BC (BarcodeScannerProviderAddIn). Es Card y no UserControlHost, que no sirve en
/// la app móvil. La página solo recoge lo leído; el alta la hace Cod. "Gestion Contenido SGA"
/// (IntentarAltaStock), y sus errores salen en el aviso de la pantalla.
///
/// De cada palé: la ubicación, la etiqueta (su SSCC, si la tiene), el producto (de la lista de
/// productos SGA propios o externos), el lote (tecleado o leído en su casilla) y la cantidad en
/// la unidad que se elija. ACEPTAR lo da de alta; el producto, el lote y la unidad se quedan
/// para el siguiente palé, y la ubicación, el SSCC y la cantidad se vacían.
/// </summary>
page 51136 "Alta Stock PDA SGA"
{
    Caption = 'Alta de stock SGA';
    PageType = Card;
    // Sin registro, BC repetiría el nombre de la pantalla como título de la ficha: dice el almacén.
    DataCaptionExpression = TituloAlmacen();
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    LinksAllowed = false;

    layout
    {
        area(Content)
        {
            usercontrol(Pantalla; "Picking PDA SGA")
            {
                ApplicationArea = All;

                trigger Listo()
                begin
                    PantallaLista := true;
                    Pintar();
                end;

                trigger Lectura(prm_Texto: Text)
                begin
                    ProcesarLectura(prm_Texto);
                end;

                trigger Cantidad(prm_Valor: Text)
                var
                    valor: Decimal;
                begin
                    // 9 = formato XML: el punto decimal, sea cual sea el idioma del usuario.
                    if not Evaluate(valor, prm_Valor, 9) then
                        exit;
                    if valor < 0 then
                        valor := 0;
                    CantidadPale := valor;
                end;

                trigger Dato(prm_Campo: Text; prm_Valor: Text)
                begin
                    case prm_Campo of
                        'ubicacion':
                            begin
                                PonerUbicacionTecleada(prm_Valor);
                                exit;
                            end;
                        'lote':
                            begin
                                Lote := CopyStr(DelChr(prm_Valor, '<>', ' '), 1, MaxStrLen(Lote));
                                Avisar('', false);
                            end;
                        'busqueda':
                            begin
                                // Sin comillas: la búsqueda va tal cual, y unas comillas escritas
                                // se buscarían como parte del texto.
                                BusquedaProducto := DelChr(DelChr(prm_Valor, '=', '"'''), '<>', ' ');
                                TandasProductos := 1;
                            end;
                    end;
                    Pintar();
                end;

                trigger Accion(prm_Accion: Text)
                begin
                    case true of
                        prm_Accion = 'aceptar':
                            Aceptar();
                        prm_Accion = 'producto':
                            begin
                                EligiendoProducto := true;
                                BusquedaProducto := '';
                                TandasProductos := 1;
                                Pintar();
                            end;
                        // La lista ha llegado abajo: se añade la tanda siguiente.
                        prm_Accion = 'masProductos':
                            begin
                                TandasProductos += 1;
                                Pintar();
                            end;
                        prm_Accion = 'volver':
                            begin
                                EligiendoProducto := false;
                                Pintar();
                            end;
                        prm_Accion.StartsWith('elegir:'):
                            ElegirProducto(CopyStr(prm_Accion.Substring(StrLen('elegir:') + 1), 1, MaxStrLen(Producto)));
                        prm_Accion.StartsWith('unidad:'):
                            begin
                                UnidadPale := CopyStr(prm_Accion.Substring(StrLen('unidad:') + 1), 1, MaxStrLen(UnidadPale));
                                Pintar();
                            end;
                    end;
                end;
            }
            // Escáner de la PDA. Sin interfaz: solo recibe lo leído.
            usercontrol(Escaner; BarcodeScannerProviderAddIn)
            {
                ApplicationArea = All;

                trigger ControlAddInReady(IsSupported: Boolean)
                var
                    IntentAccionTok: Label 'com.businesscentral.barcode.receive_barcode', Locked = true;
                    IntentCategoriaTok: Label 'com.businesscentral.barcode.receive_category', Locked = true;
                    IntentDatoTok: Label 'com.symbol.datawedge.data_string', Locked = true;
                    IntentFormatoTok: Label 'com.symbol.datawedge.label_type', Locked = true;
                begin
                    EscanerDisponible := IsSupported;
                    // Mismas claves que "Preparar Picking SGA" (Zebra DataWedge).
                    if EscanerDisponible then
                        CurrPage.Escaner.RequestBarcodeScannerAsync(IntentAccionTok, IntentCategoriaTok, IntentDatoTok, IntentFormatoTok);
                    Pintar();
                end;

                trigger BarcodeReceived(Barcode: Text; Format: Text)
                begin
                    ProcesarLectura(Barcode);
                end;
            }
        }
    }

    var
        cUM: Codeunit "Unidades Producto SGA";
        Almacen: Code[10];
        Ubicacion: Code[20];
        Producto: Code[20];
        Lote: Code[50];
        SSCC: Code[20];
        UnidadPale: Code[10];
        CantidadPale: Decimal;
        Aviso: Text;
        AvisoEsError: Boolean;
        EscanerDisponible: Boolean;
        PantallaLista: Boolean;
        EligiendoProducto: Boolean;
        BusquedaProducto: Text;
        TandasProductos: Integer;

    trigger OnOpenPage()
    var
        rConfig: Record "Config. SGA";
        AlmacenObligatorioErr: Label 'Ponga el almacén por defecto en la configuración de SGA.';
    begin
        Almacen := rConfig.AlmacenODefecto('');
        if Almacen = '' then
            Error(AlmacenObligatorioErr);
    end;

    local procedure TituloAlmacen(): Text
    var
        AlmacenLbl: Label 'Almacén %1', Comment = '%1 = código del almacén';
    begin
        exit(StrSubstNo(AlmacenLbl, Almacen));
    end;

    /// <summary>
    /// Manda a la pantalla lo leído hasta ahora. Antes de que el control esté montado no hace
    /// nada: al montarse, él mismo lo pide.
    /// </summary>
    local procedure Pintar()
    var
        datos: JsonObject;
        unidades: JsonArray;
        listaUnidades: List of [Code[10]];
        unidad: Code[10];
    begin
        if not PantallaLista then
            exit;

        datos.Add('modo', 'alta');
        datos.Add('escaner', EscanerDisponible);
        datos.Add('ubicacion', Ubicacion);
        datos.Add('producto', Producto);
        datos.Add('descripcion', cUM.Descripcion(Producto));
        datos.Add('lote', Lote);
        datos.Add('sscc', SSCC);
        if CantidadPale = 0 then
            datos.Add('cantidad', '')
        else
            datos.Add('cantidad', Format(CantidadPale, 0, 9));
        datos.Add('unidad', UnidadPale);
        cUM.Unidades(Producto, listaUnidades);
        foreach unidad in listaUnidades do
            unidades.Add(unidad);
        datos.Add('unidades', unidades);
        datos.Add('aviso', Aviso);
        datos.Add('avisoError', AvisoEsError);
        datos.Add('eligiendo', EligiendoProducto);
        if EligiendoProducto then
            AnadirListaProductos(datos);
        CurrPage.Pantalla.Mostrar(datos);
    end;

    /// <summary>
    /// La lista de productos para elegir el del palé: los que SGA ubica, de clase propio o
    /// externo y, si hay búsqueda, con ella en cualquier parte del código o de la descripción,
    /// sin distinguir mayúsculas. La búsqueda se compara aquí y no con un filtro, para que el
    /// texto se busque tal cual, sin la sintaxis de filtros de BC.
    ///
    /// Va de 25 en 25: manda las tandas pedidas hasta ahora (TandasProductos) y hayMas si quedan
    /// más; al bajar hasta el final de la lista, la pantalla pide la siguiente ('masProductos').
    /// </summary>
    local procedure AnadirListaProductos(var prm_Datos: JsonObject)
    var
        rItem: Record Item;
        cStock: Codeunit "Consulta Stock SGA";
        productos: JsonArray;
        fila: JsonObject;
        buscado: Text;
        cuantos: Integer;
        limite: Integer;
    begin
        limite := 25 * TandasProductos;
        buscado := UpperCase(BusquedaProducto);
        cStock.FiltrarProductosSGA(rItem);
        rItem.SetFilter("Clase de articulo", '%1|%2', rItem."Clase de articulo"::"Prod. Propio", rItem."Clase de articulo"::"Prod. Externo");
        rItem.SetLoadFields(Description);
        if rItem.FindSet() then
            repeat
                if (buscado = '') or (StrPos(rItem."No.", buscado) > 0) or UpperCase(rItem.Description).Contains(buscado) then begin
                    cuantos += 1;
                    if cuantos <= limite then begin
                        Clear(fila);
                        fila.Add('no', rItem."No.");
                        fila.Add('descripcion', rItem.Description);
                        productos.Add(fila);
                    end;
                end;
            until (rItem.Next() = 0) or (cuantos > limite);
        prm_Datos.Add('busqueda', BusquedaProducto);
        prm_Datos.Add('productos', productos);
        prm_Datos.Add('hayMas', cuantos > limite);
    end;

    local procedure Avisar(prm_Texto: Text; prm_EsError: Boolean)
    begin
        Aviso := prm_Texto;
        AvisoEsError := prm_EsError;
        if prm_EsError and PantallaLista then
            CurrPage.Pantalla.Senal('error');
    end;

    /// <summary>
    /// La ubicación escrita a mano en su casilla: antes de buscarla se comprueba que tenga el
    /// formato de los códigos de ubicación (Gestion Ubicaciones SGA.CodigoUbicacionValido), para
    /// avisar de un código mal escrito y no de una ubicación que no existe.
    /// </summary>
    local procedure PonerUbicacionTecleada(prm_Valor: Text)
    var
        cLectura: Codeunit "Codigos Barras SGA";
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        codigo: Code[20];
        bin: Code[20];
        motivo: Text;
        UbicacionNoExisteErr: Label 'La ubicación %1 no existe en el almacén %2.', Comment = '%1 = ubicación, %2 = almacén';
    begin
        codigo := cLectura.UbicacionLeida(prm_Valor);
        if codigo = '' then
            exit;
        // Mal escrita o inexistente, se quita la anterior: ACEPTAR no puede grabar en otro hueco.
        case true of
            not cUbicaciones.CodigoUbicacionValido(codigo, motivo):
                begin
                    Ubicacion := '';
                    Avisar(motivo, true);
                end;
            not cLectura.EsUbicacion(Almacen, codigo, bin):
                begin
                    Ubicacion := '';
                    Avisar(StrSubstNo(UbicacionNoExisteErr, codigo, Almacen), true);
                end;
            else begin
                Ubicacion := bin;
                Avisar('', false);
                CurrPage.Pantalla.Senal('ok');
            end;
        end;
        Pintar();
    end;

    /// <summary>
    /// Lo escaneado o tecleado en la casilla de lectura, o recibido del escáner de la app: la
    /// etiqueta de una ubicación (pasa a ser la del alta) o la de un palé (su SSCC).
    /// </summary>
    local procedure ProcesarLectura(prm_Lectura: Text)
    var
        cLectura: Codeunit "Codigos Barras SGA";
        bin: Code[20];
        ssccLeido: Code[20];
        LecturaDesconocidaErr: Label '%1 no es una ubicación de este almacén ni la etiqueta de un palé.', Comment = '%1 = lo leído';
    begin
        prm_Lectura := DelChr(prm_Lectura, '<>', ' ');
        if prm_Lectura = '' then
            exit;

        case true of
            cLectura.EsUbicacion(Almacen, prm_Lectura, bin):
                Ubicacion := bin;
            cLectura.LeerSSCC(prm_Lectura, ssccLeido):
                SSCC := ssccLeido;
            else begin
                Avisar(StrSubstNo(LecturaDesconocidaErr, prm_Lectura), true);
                Pintar();
                exit;
            end;
        end;
        Avisar('', false);
        CurrPage.Pantalla.Senal('ok');
        Pintar();
    end;

    /// <summary>
    /// El producto del palé, elegido en la lista de la pantalla. Al cambiarlo, el lote se vacía y
    /// la unidad pasa a la primera del producto.
    /// </summary>
    local procedure ElegirProducto(prm_Producto: Code[20])
    var
        listaUnidades: List of [Code[10]];
    begin
        EligiendoProducto := false;
        if prm_Producto <> Producto then begin
            Producto := prm_Producto;
            Lote := '';
            cUM.Unidades(Producto, listaUnidades);
            UnidadPale := '';
            if listaUnidades.Count() > 0 then
                UnidadPale := listaUnidades.Get(1);
        end;
        Avisar('', false);
        Pintar();
    end;

    /// <summary>
    /// Da de alta el palé con lo leído (IntentarAltaStock) y deja la pantalla para el siguiente.
    /// Lo que falte o lo que impida el alta (capacidad, lote, SSCC repetido…) se avisa en la
    /// pantalla, con pitido, sin ventanas de BC.
    /// </summary>
    local procedure Aceptar()
    var
        cContenido: Codeunit "Gestion Contenido SGA";
        motivo: Text;
        ProductoObligatorioErr: Label 'Elija el producto del palé.';
        CantidadObligatoriaErr: Label 'Indique la cantidad del palé.';
        AltaHechaMsg: Label 'Alta: %1 %2 de %3 en %4.', Comment = '%1 = cantidad, %2 = unidad, %3 = producto, %4 = ubicación';
    begin
        if Producto = '' then begin
            Avisar(ProductoObligatorioErr, true);
            Pintar();
            exit;
        end;
        if CantidadPale <= 0 then begin
            Avisar(CantidadObligatoriaErr, true);
            Pintar();
            exit;
        end;

        // Si no se puede dar de alta no se registra nada, y el motivo sale en el aviso de la
        // pantalla, no en una ventana de BC.
        if not cContenido.IntentarAltaStock(Almacen, Ubicacion, Producto, Lote, SSCC, UnidadPale, CantidadPale, motivo) then begin
            Avisar(motivo, motivo <> '');
            Pintar();
            exit;
        end;

        Avisar(StrSubstNo(AltaHechaMsg, CantidadPale, UnidadPale, Producto, Ubicacion), false);
        // Cada palé lleva su ubicación: se vacía con la etiqueta y la cantidad.
        Ubicacion := '';
        SSCC := '';
        CantidadPale := 0;
        CurrPage.Pantalla.Senal('ok');
        Pintar();
    end;
}
