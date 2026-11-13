namespace AntonioNadal.SGA;

using System.Device;

/// <summary>
/// Page Preparar Picking SGA (ID 51121).
/// Pantalla del preparador: le dice a qué ubicación ir, qué producto y qué lote coger y en
/// qué cantidad, y recoge lo que lee o teclea para confirmar la parada.
///
/// La pantalla la dibuja el control "Picking PDA SGA", pensado para un terminal de mano y que
/// funciona igual en el navegador. La página solo le manda la parada (Pintar) y atiende lo que
/// devuelve; la lógica es de Cod. "Gestion Picking SGA".
///
/// En la app móvil de BC sobre un terminal con escáner, las lecturas llegan por el control
/// BarcodeScannerProviderAddIn. Se escanee o se teclee, cada lectura es la ubicación de la que
/// recoge o el producto, y se comprueba al momento. La ubicación se lee de la etiqueta del
/// hueco. La parada se confirma sola cuando tiene ubicación y, si lo exige la configuración,
/// producto (ParadaCompleta). Un error de lectura se avisa en la pantalla, con pitido, sin ventana.
///
/// La confirmación es la que retira el stock de la ubicación y deja la huella en el diario
/// de movimientos, con el documento origen y el usuario, para la trazabilidad inversa.
///
/// Trabaja sobre las paradas pendientes de una orden, ordenadas por recorrido físico. Abierta
/// desde una orden, trabaja esa y se cierra al terminarla. Abierta sola (menú de la PDA,
/// "Siguiente orden"), está "en turno": toma la orden que le toca (SiguienteOrdenPreparar) y, al
/// terminarla, pasa a la siguiente sin cerrarse.
/// </summary>
page 51121 "Preparar Picking SGA"
{
    Caption = 'Preparar picking SGA';
    PageType = Card;
    SourceTable = "Linea Orden Picking SGA";
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    LinksAllowed = false;
    // La barra de título de BC dice la orden; la pantalla propia no la repite.
    DataCaptionFields = "No. Orden";
    SourceTableView = sorting("No. Orden", Estado, "Secuencia Picking");

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
                begin
                    LeerCantidad(prm_Valor);
                end;

                trigger Accion(prm_Accion: Text)
                begin
                    EjecutarAccion(prm_Accion);
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
                    // Claves del dato de Zebra DataWedge, que no se pueden cambiar en el
                    // terminal; Honeywell y Datalogic se configuran con las mismas.
                    if EscanerDisponible then
                        CurrPage.Escaner.RequestBarcodeScannerAsync(IntentAccionTok, IntentCategoriaTok, IntentDatoTok, IntentFormatoTok);
                    // Con escáner la pantalla no pone el foco en los campos (abriría el teclado).
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
        UbicacionEscaneada: Code[20];
        CantidadRecogida: Decimal;
        PendienteDocumento: Decimal;
        UMPedido: Code[10];
        MostrarBase: Boolean;
        Aviso: Text;
        AvisoEsError: Boolean;
        Progreso: Text;
        LineaMostrada: Integer;
        ProductoEscaneado: Text[100];
        EscanerDisponible: Boolean;
        PantallaLista: Boolean;
        HayParada: Boolean;
        EnTurno: Boolean;
        MotivoSinParadas: Text;
        Playa: Code[20];

    trigger OnOpenPage()
    begin
        // Abierta desde una orden, trabaja esa. Abierta sola (menú de la PDA, Siguiente
        // orden), busca la que le toca y, al terminarla, pasa a la siguiente.
        EnTurno := Rec.GetFilter("No. Orden") = '';
        if EnTurno then
            BuscarSiguienteOrden()
        else begin
            Rec.FiltrarParaPreparar();
            HayParada := Rec.FindFirst();
            Preparar();
        end;
    end;

    /// <summary>
    /// Carga la siguiente orden que le toca al usuario. Si no hay, la pantalla lo dice y ofrece
    /// volver a buscar.
    /// </summary>
    local procedure BuscarSiguienteOrden()
    var
        rOrden: Record "Orden Picking SGA";
        cPicking: Codeunit "Gestion Picking SGA";
    begin
        if cPicking.SiguienteOrdenPreparar(rOrden, MotivoSinParadas) then
            HayParada := CargarParadas(rOrden."No. Orden")
        else
            HayParada := false;
        Preparar();
    end;

    trigger OnAfterGetRecord()
    begin
        // La captura solo se reinicia al cambiar de parada.
        if LineaMostrada <> Rec."No. Linea" then
            Preparar();
    end;

    /// <summary>
    /// Deja la pantalla lista para la parada actual.
    /// </summary>
    local procedure Preparar()
    var
        rZona: Record "Zona SGA";
    begin
        LineaMostrada := Rec."No. Linea";
        // Lo de un pedido se deja en la playa; una reubicación lleva su propio destino.
        Playa := '';
        if HayParada and (Rec."Cod. Bin Destino" = '') then
            Playa := rZona.PlayaPorDefecto(Rec."Cod. Almacen");
        PendienteDocumento := Rec.EnUMDocumento(Rec."Cantidad Pendiente");
        UMPedido := Rec.UMVisible();
        MostrarBase := UMPedido <> Rec."Cod. Unidad Medida";
        CantidadRecogida := PendienteDocumento;
        UbicacionEscaneada := '';
        ProductoEscaneado := '';
        Avisar('', false);
        CalcularProgreso();
        Pintar();
    end;

    local procedure CalcularProgreso()
    var
        rOrden: Record "Orden Picking SGA";
        total: Integer;
        hechas: Integer;
        ProgresoLbl: Label '%1 de %2 paradas', Comment = '%1 = paradas hechas, %2 = total de paradas';
    begin
        // Sin leer la orden: Progreso solo necesita el número, y con la pantalla vacía no lo hay.
        rOrden."No. Orden" := Rec."No. Orden";
        rOrden.Progreso(hechas, total);
        Progreso := StrSubstNo(ProgresoLbl, hechas, total);
    end;

    /// <summary>
    /// Manda a la pantalla la parada actual y lo capturado. Antes de que el control esté
    /// montado no hace nada: al montarse, él mismo lo pide.
    /// </summary>
    local procedure Pintar()
    var
        cPicking: Codeunit "Gestion Picking SGA";
        datos: JsonObject;
        BaseLbl: Label '%1 %2', Locked = true, Comment = '%1 = cantidad, %2 = unidad';
    begin
        if not PantallaLista then
            exit;

        datos.Add('vacia', not HayParada);
        datos.Add('mensaje', MotivoSinParadas);
        datos.Add('enTurno', EnTurno);
        datos.Add('escaner', EscanerDisponible);
        datos.Add('progreso', Progreso);
        datos.Add('ubicacion', Rec."Cod. Bin Propuesto");
        datos.Add('producto', Rec."No. Producto");
        datos.Add('descripcion', Rec."Descripcion Producto");
        datos.Add('lote', Rec."No. Lote");
        datos.Add('sscc', Rec.SSCC);
        datos.Add('caducidad', Format(Rec."Fecha Caducidad"));
        datos.Add('cantidad', Format(PendienteDocumento));
        datos.Add('unidad', UMPedido);
        if MostrarBase then
            datos.Add('cantidadBase', StrSubstNo(BaseLbl, Format(Rec."Cantidad Pendiente"), Rec."Cod. Unidad Medida"))
        else
            datos.Add('cantidadBase', '');
        datos.Add('destino', Rec."Cod. Bin Destino");
        datos.Add('playa', Playa);
        datos.Add('exigeProducto', cPicking.ExigeEscanearProducto());
        datos.Add('ubicacionLeida', UbicacionEscaneada);
        datos.Add('productoLeido', ProductoEscaneado);
        datos.Add('cantidadRecogida', CantidadRecogida);
        datos.Add('aviso', Aviso);
        datos.Add('avisoError', AvisoEsError);
        CurrPage.Pantalla.Mostrar(datos);
    end;

    local procedure Avisar(prm_Texto: Text; prm_EsError: Boolean)
    begin
        Aviso := prm_Texto;
        AvisoEsError := prm_EsError;
        if prm_EsError and PantallaLista then
            CurrPage.Pantalla.Senal('error');
    end;

    /// <summary>
    /// Avisa si la ubicación de la que recoge no es la indicada. Que el desvío se admita o no
    /// lo decide el motor al confirmar, según la configuración.
    /// </summary>
    local procedure ComprobarUbicacion()
    var
        rConfig: Record "Config. SGA";
        DesvioUbicacionMsg: Label 'Esa no es la ubicación indicada (%1). Se registrará como desvío.', Comment = '%1 = ubicación indicada';
        DesvioNoPermitidoErr: Label 'Esa no es la ubicación indicada (%1) y la configuración no permite desviarse.', Comment = '%1 = ubicación indicada';
    begin
        Avisar('', false);
        if (UbicacionEscaneada = '') or (UbicacionEscaneada = Rec."Cod. Bin Propuesto") then
            exit;

        rConfig.ObtenerConfig();
        if rConfig.DesvioPermitido(Rec."Cod. Bin Propuesto", UbicacionEscaneada) then
            Avisar(StrSubstNo(DesvioUbicacionMsg, Rec."Cod. Bin Propuesto"), false)
        else
            Avisar(StrSubstNo(DesvioNoPermitidoErr, Rec."Cod. Bin Propuesto"), true);
    end;

    /// <summary>
    /// Lo escaneado o tecleado en cualquier casilla, o recibido del escáner de la app: la
    /// ubicación de la que recoge o, si no es una ubicación, el producto, que se comprueba al
    /// momento. Lo decide lo leído, no la casilla.
    /// </summary>
    local procedure ProcesarLectura(prm_Lectura: Text)
    var
        cLectura: Codeunit "Lectura Codigos SGA";
        bin: Code[20];
    begin
        prm_Lectura := DelChr(prm_Lectura, '<>', ' ');
        if (prm_Lectura = '') or not HayParada then
            exit;

        if cLectura.EsUbicacion(Rec."Cod. Almacen", prm_Lectura, bin) then begin
            UbicacionEscaneada := bin;
            ComprobarUbicacion();
            // Un desvío no permitido no cuenta como leída: se vuelve a pedir la ubicación.
            if AvisoEsError then
                UbicacionEscaneada := '';
        end else
            if ProbarProducto(prm_Lectura) then begin
                ProductoEscaneado := CopyStr(prm_Lectura, 1, MaxStrLen(ProductoEscaneado));
                Avisar('', false);
            end else begin
                Avisar(GetLastErrorText(), true);
                Pintar();
                exit;
            end;

        if not AvisoEsError then
            CurrPage.Pantalla.Senal('ok');
        Pintar();
        ConfirmarSiCompleta();
    end;

    [TryFunction]
    local procedure ProbarProducto(prm_Lectura: Text)
    var
        cPicking: Codeunit "Gestion Picking SGA";
    begin
        cPicking.TestProductoLeido(Rec, prm_Lectura);
    end;

    /// <summary>
    /// Cantidad recogida que manda la pantalla, en la unidad del pedido y con punto decimal.
    /// </summary>
    local procedure LeerCantidad(prm_Valor: Text)
    var
        valor: Decimal;
    begin
        // 9 = formato XML: el punto decimal, sea cual sea el idioma del usuario.
        if not Evaluate(valor, prm_Valor, 9) then
            exit;
        if valor < 0 then
            valor := 0;
        CantidadRecogida := valor;
    end;

    local procedure EjecutarAccion(prm_Accion: Text)
    begin
        if prm_Accion = 'siguiente' then begin
            BuscarSiguienteOrden();
            exit;
        end;
        if not HayParada then
            exit;
        case prm_Accion of
            'confirmar':
                Confirmar();
            'saltar':
                Saltar();
            'sinstock':
                MarcarSinStock();
        end;
    end;

    /// <summary>
    /// Confirma la parada en cuanto tiene todo lo que exige la configuración.
    /// </summary>
    local procedure ConfirmarSiCompleta()
    var
        cPicking: Codeunit "Gestion Picking SGA";
    begin
        if AvisoEsError then
            exit;
        if cPicking.ParadaCompleta(UbicacionEscaneada, ProductoEscaneado) then
            Confirmar();
    end;

    local procedure Confirmar()
    var
        cPicking: Codeunit "Gestion Picking SGA";
        CantidadNoIndicadaErr: Label 'Indique la cantidad recogida.';
    begin
        if CantidadRecogida <= 0 then
            Error(CantidadNoIndicadaErr);

        // El preparador habla en la UM del pedido; la parada, en base.
        cPicking.ConfirmarLinea(Rec, UbicacionEscaneada, Rec.CantidadBaseDesdeDocumento(CantidadRecogida, PendienteDocumento), ProductoEscaneado);
        CurrPage.Pantalla.Senal('ok');

        // Al quedar recogida sale del filtro de pendientes, así que se recarga la vista.
        if not CargarParadas(Rec."No. Orden") then begin
            TerminarOrden();
            exit;
        end;

        Preparar();
    end;

    /// <summary>
    /// Deja esta parada para el final y pasa a la siguiente. Al acabar el recorrido vuelve a las
    /// saltadas; saltar una por segunda vez la deja retenida para el jefe de almacén
    /// (SaltarParada) y ya no vuelve a salir. Si solo quedan retenidas, la orden se cierra para
    /// el preparador (TerminarOrden).
    /// </summary>
    local procedure Saltar()
    var
        cPicking: Codeunit "Gestion Picking SGA";
        bin: Code[20];
        retenida: Boolean;
        ParadaRetenidaMsg: Label 'La parada de %1 queda retenida para el jefe de almacén.', Comment = '%1 = ubicación';
    begin
        bin := Rec."Cod. Bin Propuesto";
        retenida := cPicking.SaltarParada(Rec);

        if Rec.Next() = 0 then
            if not CargarParadas(Rec."No. Orden") then begin
                TerminarOrden();
                exit;
            end;

        Preparar();
        if retenida then begin
            Avisar(StrSubstNo(ParadaRetenidaMsg, bin), false);
            Pintar();
        end;
    end;

    /// <summary>
    /// "Sin stock": la parada se cancela y lo que faltaba se busca en otra ubicación del producto.
    /// Lo que ha pasado sale como aviso en la parada siguiente, en rojo si no se ha encontrado todo.
    /// </summary>
    local procedure MarcarSinStock()
    var
        cPicking: Codeunit "Gestion Picking SGA";
        resultado: Text;
        cubierta: Boolean;
        SinStockQst: Label '¿Buscar en otra ubicación?';
    begin
        if not Confirm(SinStockQst, true) then
            exit;

        resultado := cPicking.SustituirParadaSinStock(Rec, cubierta);

        if not CargarParadas(Rec."No. Orden") then begin
            TerminarOrden();
            exit;
        end;

        Preparar();
        Avisar(resultado, not cubierta);
        Pintar();
    end;

    /// <summary>
    /// Cierra el recorrido y pasa lo recogido al pedido. Se guarda antes lo confirmado: si el
    /// pedido no acepta los datos, el preparador no pierde su trabajo y oficina lo repite
    /// desde la orden con "Pasar al pedido".
    ///
    /// Si quedan paradas retenidas, la orden sigue en proceso para el jefe de almacén, pero lo
    /// recogido ya pasa al pedido: el paso se puede repetir sin duplicar cuando se resuelvan.
    ///
    /// En turno no se cierra: el resultado sale como aviso y se carga la siguiente orden. Si no
    /// pasa al pedido, el aviso va en rojo.
    /// </summary>
    local procedure TerminarOrden()
    var
        rOrden: Record "Orden Picking SGA";
        rZona: Record "Zona SGA";
        playaOrden: Code[20];
        resultado: Text;
        fallo: Boolean;
        OrdenTerminadaMsg: Label 'Orden %1 terminada.', Comment = '%1 = nº orden';
        DejarEnPlayaMsg: Label 'Déjela en la playa %1.', Comment = '%1 = ubicación de la playa';
        OrdenConRetenidasMsg: Label 'Orden %1 recorrida. %2 paradas quedan retenidas para el jefe de almacén.', Comment = '%1 = nº orden, %2 = número de paradas retenidas';
        PasadaAlPedidoMsg: Label 'Lo recogido ya está en el pedido %1.', Comment = '%1 = nº pedido';
        SinPasarAlPedidoMsg: Label 'No se ha podido pasar al pedido %1: %2 Avise a oficina para que lo pase desde la orden.', Comment = '%1 = nº pedido, %2 = error';
    begin
        Commit();

        resultado := StrSubstNo(OrdenTerminadaMsg, Rec."No. Orden");
        if rOrden.Get(Rec."No. Orden") then begin
            rOrden.CalcFields("Paradas Retenidas");
            if rOrden."Paradas Retenidas" > 0 then
                resultado := StrSubstNo(OrdenConRetenidasMsg, rOrden."No. Orden", rOrden."Paradas Retenidas");
            if rOrden.Origen = rOrden.Origen::Venta then begin
                playaOrden := rZona.PlayaPorDefecto(rOrden."Cod. Almacen");
                if playaOrden <> '' then
                    resultado += ' ' + StrSubstNo(DejarEnPlayaMsg, playaOrden);
                if Codeunit.Run(Codeunit::"Gestion Picking SGA", rOrden) then
                    resultado += ' ' + StrSubstNo(PasadaAlPedidoMsg, rOrden."No. Documento Origen")
                else begin
                    resultado += ' ' + StrSubstNo(SinPasarAlPedidoMsg, rOrden."No. Documento Origen", GetLastErrorText());
                    fallo := true;
                end;
            end;
        end;

        if not EnTurno then begin
            Message(resultado);
            CurrPage.Close();
            exit;
        end;

        BuscarSiguienteOrden();
        if HayParada then
            Avisar(resultado, fallo)
        else
            MotivoSinParadas := resultado + ' ' + MotivoSinParadas;
        Pintar();
    end;

    /// <summary>
    /// Deja la vista en las paradas pendientes y no retenidas de la orden, en orden de
    /// recorrido, con el cursor en la primera. Devuelve false si no queda ninguna.
    /// </summary>
    local procedure CargarParadas(prm_Orden: Code[20]): Boolean
    begin
        Rec.Reset();
        Rec.SetCurrentKey("No. Orden", Estado, "Secuencia Picking");
        Rec.SetRange("No. Orden", prm_Orden);
        Rec.FiltrarParaPreparar();
        HayParada := Rec.FindFirst();
        exit(HayParada);
    end;
}
