namespace AntonioNadal.SGA;

using System.Device;
using System.Utilities;

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
/// BarcodeScannerProviderAddIn. Se escanee o se teclee, la lectura es la ubicación de la que
/// recoge, de la etiqueta del hueco, y se comprueba al momento. Con una ubicación válida la
/// parada se confirma sola. Un error de lectura se avisa en la pantalla, con pitido, sin ventana.
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
                    // Cantidad recogida en la unidad del pedido. 9 = formato XML: el punto
                    // decimal, sea cual sea el idioma del usuario.
                    if not Evaluate(valor, prm_Valor, 9) then
                        exit;
                    if valor < 0 then
                        valor := 0;
                    CantidadRecogida := valor;
                end;

                trigger Accion(prm_Accion: Text)
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
        EscanerDisponible: Boolean;
        PantallaLista: Boolean;
        HayParada: Boolean;
        EnTurno: Boolean;
        MotivoSinParadas: Text;
        Playa: Code[10];

    trigger OnOpenPage()
    begin
        // Abierta desde una orden, trabaja esa. Abierta sola (menú de la PDA, Siguiente
        // orden), busca la que le toca y, al terminarla, pasa a la siguiente.
        EnTurno := Rec.GetFilter("No. Orden") = '';
        if EnTurno then
            BuscarSiguienteOrden()
        else begin
            CargarParadas(CopyStr(Rec.GetFilter("No. Orden"), 1, MaxStrLen(Rec."No. Orden")));
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
            CargarParadas(rOrden."No. Orden")
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
    /// Deja la pantalla lista para la parada actual, con el avance del recorrido.
    /// </summary>
    local procedure Preparar()
    var
        rOrden: Record "Orden Picking SGA";
        total: Integer;
        hechas: Integer;
        ProgresoLbl: Label '%1 de %2 líneas', Comment = '%1 = líneas hechas, %2 = total de líneas';
    begin
        LineaMostrada := Rec."No. Linea";
        // Lo de un pedido se deja en la playa de su orden; una reubicación lleva su propio destino.
        Playa := '';
        if HayParada and (Rec."Cod. Bin Destino" = '') then begin
            rOrden.SetLoadFields(Playa);
            if rOrden.Get(Rec."No. Orden") then
                Playa := rOrden.Playa;
        end;
        PendienteDocumento := Rec.EnUMDocumento(Rec."Cantidad Pendiente");
        UMPedido := Rec.UMVisible();
        MostrarBase := UMPedido <> Rec."Cod. Unidad Medida";
        CantidadRecogida := PendienteDocumento;
        UbicacionEscaneada := '';
        Avisar('', false);
        // Progreso solo necesita el número: con la pantalla vacía no hay orden que leer.
        rOrden."No. Orden" := Rec."No. Orden";
        rOrden.Progreso(hechas, total);
        Progreso := StrSubstNo(ProgresoLbl, hechas, total);
        Pintar();
    end;

    /// <summary>
    /// Manda a la pantalla la parada actual y lo capturado. Antes de que el control esté
    /// montado no hace nada: al montarse, él mismo lo pide.
    /// </summary>
    local procedure Pintar()
    var
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
        datos.Add('ubicacionLeida', UbicacionEscaneada);
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
    /// Lo escaneado o tecleado, o recibido del escáner de la app: la ubicación de la que recoge,
    /// de la etiqueta del hueco. Si no es la indicada, avisa: se registrará como desvío o, si la
    /// configuración no lo permite, se vuelve a pedir. Si es válida, la parada se confirma sola.
    /// </summary>
    local procedure ProcesarLectura(prm_Lectura: Text)
    var
        rConfig: Record "Config. SGA";
        cLectura: Codeunit "Codigos Barras SGA";
        bin: Code[20];
        NoEsUbicacionErr: Label '%1 no es una ubicación de este almacén. Escanee la etiqueta del hueco.', Comment = '%1 = lo leído';
        DesvioUbicacionMsg: Label 'Esa no es la ubicación indicada (%1). Se registrará como desvío.', Comment = '%1 = ubicación indicada';
        DesvioNoPermitidoErr: Label 'Esa no es la ubicación indicada (%1) y la configuración no permite desviarse.', Comment = '%1 = ubicación indicada';
    begin
        prm_Lectura := DelChr(prm_Lectura, '<>', ' ');
        if (prm_Lectura = '') or not HayParada then
            exit;

        if not cLectura.EsUbicacion(Rec."Cod. Almacen", prm_Lectura, bin) then begin
            Avisar(StrSubstNo(NoEsUbicacionErr, prm_Lectura), true);
            Pintar();
            exit;
        end;

        Avisar('', false);
        if bin <> Rec."Cod. Bin Propuesto" then begin
            rConfig.ObtenerConfig();
            // Un desvío no permitido no cuenta como leída: se vuelve a pedir la ubicación.
            if not rConfig.DesvioPermitido(Rec."Cod. Bin Propuesto", bin) then begin
                UbicacionEscaneada := '';
                Avisar(StrSubstNo(DesvioNoPermitidoErr, Rec."Cod. Bin Propuesto"), true);
                Pintar();
                exit;
            end;
            Avisar(StrSubstNo(DesvioUbicacionMsg, Rec."Cod. Bin Propuesto"), false);
        end;
        UbicacionEscaneada := bin;

        CurrPage.Pantalla.Senal('ok');
        Pintar();
        Confirmar();
    end;

    local procedure Confirmar()
    var
        cPicking: Codeunit "Gestion Picking SGA";
    begin
        // La cantidad la comprueba ConfirmarLinea. El preparador habla en la UM del pedido; la parada, en base.
        cPicking.ConfirmarLinea(Rec, UbicacionEscaneada, Rec.CantidadBaseDesdeDocumento(CantidadRecogida, PendienteDocumento));
        CurrPage.Pantalla.Senal('ok');
        SiguienteParada();
    end;

    /// <summary>
    /// Tras confirmar, saltar o sustituir una parada: recarga la vista (lo hecho sale del filtro
    /// de pendientes) y prepara la siguiente o, si no queda ninguna, termina la orden. Devuelve
    /// false si la ha terminado.
    /// </summary>
    local procedure SiguienteParada(): Boolean
    begin
        if not CargarParadas(Rec."No. Orden") then begin
            TerminarOrden();
            exit(false);
        end;
        Preparar();
        exit(true);
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
        ParadaRetenidaMsg: Label 'La línea de %1 queda retenida para el jefe de almacén.', Comment = '%1 = ubicación';
    begin
        bin := Rec."Cod. Bin Propuesto";
        retenida := cPicking.SaltarParada(Rec);

        // Al recargar, la saltada pasa detrás de las que no se han saltado.
        if not SiguienteParada() then
            exit;
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
        cConfirmMgt: Codeunit "Confirm Management";
        resultado: Text;
        cubierta: Boolean;
        SinStockQst: Label '¿Buscar en otra ubicación?';
    begin
        if not cConfirmMgt.GetResponseOrDefault(SinStockQst, true) then
            exit;

        resultado := cPicking.SustituirParadaSinStock(Rec, cubierta);

        if not SiguienteParada() then
            exit;
        Avisar(resultado, not cubierta);
        Pintar();
    end;

    /// <summary>
    /// Cierra el recorrido (TerminarRecorrido de Cod. "Gestion Picking SGA": guarda y pasa lo
    /// recogido al pedido). En turno no se cierra la pantalla: el resultado sale como aviso y se
    /// carga la siguiente orden; si no ha pasado al pedido, el aviso va en rojo.
    /// </summary>
    local procedure TerminarOrden()
    var
        cPicking: Codeunit "Gestion Picking SGA";
        resultado: Text;
        fallo: Boolean;
    begin
        resultado := cPicking.TerminarRecorrido(Rec."No. Orden", fallo);

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
    /// recorrido, con el cursor en la primera. Las saltadas van al final: una parada saltada no
    /// vuelve hasta terminar las que no lo están. Devuelve false si no queda ninguna.
    /// </summary>
    local procedure CargarParadas(prm_Orden: Code[20]): Boolean
    begin
        Rec.Reset();
        Rec.SetCurrentKey("No. Orden", "Veces Saltada", "Secuencia Picking");
        Rec.SetRange("No. Orden", prm_Orden);
        Rec.FiltrarParaPreparar();
        HayParada := Rec.FindFirst();
        exit(HayParada);
    end;
}
