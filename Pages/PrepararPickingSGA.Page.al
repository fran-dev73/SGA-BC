namespace AntonioNadal.SGA;

/// <summary>
/// Page Preparar Picking SGA (ID 51121).
/// Pantalla del preparador: le dice a qué ubicación ir, qué producto y qué lote coger y en
/// qué cantidad. El preparador escanea o teclea la ubicación de la que recoge y confirma.
///
/// La confirmación es la que retira el stock de la ubicación y deja la huella en el diario
/// de movimientos, con el documento origen y el usuario, para la trazabilidad inversa.
///
/// Trabaja sobre las paradas pendientes de una orden, ordenadas por recorrido físico.
/// </summary>
page 51121 "Preparar Picking SGA"
{
    Caption = 'Preparar picking';
    PageType = Card;
    SourceTable = "Linea Orden Picking SGA";
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    SourceTableView = sorting("No. Orden", Estado, "Secuencia Picking");

    layout
    {
        area(Content)
        {
            group(Avance)
            {
                Caption = 'Recorrido';

                field(Progreso; Progreso)
                {
                    Caption = 'Progreso';
                    ToolTip = 'Paradas recogidas sobre el total de la orden.';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                }
                field("No. Orden"; Rec."No. Orden")
                {
                    ToolTip = 'Orden que se está preparando.';
                    ApplicationArea = All;
                    Editable = false;
                }
            }
            group(Destino)
            {
                Caption = 'Vaya a esta ubicación';

                field("Cod. Bin Propuesto"; Rec."Cod. Bin Propuesto")
                {
                    Caption = 'Ubicación';
                    ToolTip = 'Ubicación a la que hay que ir a recoger.';
                    ApplicationArea = All;
                    Editable = false;
                    Style = StrongAccent;
                }
                field("Secuencia Picking"; Rec."Secuencia Picking")
                {
                    Caption = 'Secuencia';
                    ToolTip = 'Posición de la parada en el recorrido.';
                    ApplicationArea = All;
                    Editable = false;
                }
            }
            group(Mercancia)
            {
                Caption = 'Y coja esto';

                field("No. Producto"; Rec."No. Producto")
                {
                    Caption = 'Producto';
                    ToolTip = 'Producto que hay que recoger.';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                }
                field("Descripcion Producto"; Rec."Descripcion Producto")
                {
                    Caption = 'Descripción';
                    ToolTip = 'Descripción del producto.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("No. Lote"; Rec."No. Lote")
                {
                    Caption = 'Lote';
                    ToolTip = 'Lote concreto que hay que recoger.';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                }
                field("Fecha Caducidad"; Rec."Fecha Caducidad")
                {
                    Caption = 'Caducidad';
                    ToolTip = 'Caducidad del lote que hay que recoger.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(PendienteDocumento; PendienteDocumento)
                {
                    Caption = 'Cantidad a recoger';
                    ToolTip = 'Cantidad que queda por recoger en esta parada, en la unidad del pedido.';
                    ApplicationArea = All;
                    Editable = false;
                    DecimalPlaces = 0 : 5;
                    Style = Strong;
                }
                field(UMPedido; UMPedido)
                {
                    Caption = 'Unidad';
                    ToolTip = 'Unidad de medida del pedido: cajas, palés o la que lleve la línea.';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                }
                field(PendienteBase; Rec."Cantidad Pendiente")
                {
                    Caption = 'En unidades base';
                    ToolTip = 'La misma cantidad en la unidad de medida base del producto.';
                    ApplicationArea = All;
                    Editable = false;
                    Visible = MostrarBase;
                }
            }
            group(Validacion)
            {
                Caption = 'Confirme lo recogido';

                field(UbicacionEscaneada; UbicacionEscaneada)
                {
                    Caption = 'Ubicación de la que recoge';
                    ToolTip = 'Escanee o teclee la ubicación de la que está recogiendo. Debe coincidir con la indicada.';
                    ApplicationArea = All;
                    ShowMandatory = true;

                    trigger OnValidate()
                    begin
                        ComprobarUbicacion();
                    end;
                }
                field(DigitoControl; DigitoControl)
                {
                    Caption = 'Dígito de control';
                    ToolTip = 'Número grande de la etiqueta del hueco del que recoge. Certifica que está delante del hueco.';
                    ApplicationArea = All;
                    Visible = ExigeDigito;
                    ShowMandatory = true;
                    Style = StrongAccent;
                }
                field(CantidadRecogida; CantidadRecogida)
                {
                    Caption = 'Cantidad recogida';
                    ToolTip = 'Cantidad que ha cogido realmente, en la unidad del pedido. Por defecto, la pendiente de la parada.';
                    DecimalPlaces = 0 : 5;
                    ApplicationArea = All;
                    MinValue = 0;
                    ShowMandatory = true;
                }
                field(Aviso; Aviso)
                {
                    Caption = 'Aviso';
                    ToolTip = 'Avisos sobre la ubicación escaneada.';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Unfavorable;
                    Visible = HayAviso;
                    MultiLine = true;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ConfirmarParada)
            {
                Caption = 'Confirmar recogida';
                ToolTip = 'Registra lo recogido, retira el stock de la ubicación y pasa a la siguiente parada.';
                ApplicationArea = All;
                Image = Approve;

                trigger OnAction()
                begin
                    Confirmar();
                end;
            }
            action(SaltarParada)
            {
                Caption = 'Saltar parada';
                ToolTip = 'Deja esta parada para el final y pasa a la siguiente.';
                ApplicationArea = All;
                Image = NextRecord;

                trigger OnAction()
                var
                    SinMasParadasMsg: Label 'No hay más paradas pendientes.';
                begin
                    if Rec.Next() = 0 then
                        Message(SinMasParadasMsg)
                    else
                        Preparar();
                    CurrPage.Update(false);
                end;
            }
            action(NoHayStock)
            {
                Caption = 'No hay stock aquí';
                ToolTip = 'Cancela esta parada porque la mercancía no está en la ubicación. Queda constancia para revisar el hueco.';
                ApplicationArea = All;
                Image = Cancel;

                trigger OnAction()
                begin
                    MarcarSinStock();
                end;
            }
            action(VerContenidoUbicacion)
            {
                Caption = 'Ver qué hay en la ubicación';
                ToolTip = 'Muestra el contenido registrado de la ubicación indicada.';
                ApplicationArea = All;
                Image = BinContent;

                trigger OnAction()
                var
                    rContenido: Record "Contenido Ubicacion SGA";
                begin
                    rContenido.SetRange("Cod. Almacen", Rec."Cod. Almacen");
                    rContenido.SetRange("Cod. Bin", Rec."Cod. Bin Propuesto");
                    Page.Run(Page::"Contenido Ubicaciones SGA", rContenido);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(ConfirmarParada_Promoted; ConfirmarParada)
                {
                }
                actionref(SaltarParada_Promoted; SaltarParada)
                {
                }
                actionref(NoHayStock_Promoted; NoHayStock)
                {
                }
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
        HayAviso: Boolean;
        Progreso: Text;
        LineaMostrada: Integer;
        DigitoControl: Text[10];
        ExigeDigito: Boolean;

    trigger OnOpenPage()
    var
        rConfig: Record "Config. SGA";
    begin
        rConfig.ObtenerConfig();
        ExigeDigito := rConfig."Exigir Digito Control";
        Rec.FiltrarPendientes();
        if Rec.FindFirst() then;
        Preparar();
    end;

    trigger OnAfterGetRecord()
    begin
        // La captura solo se reinicia al cambiar de parada. Si se reiniciara en cada
        // refresco se borraría la ubicación que el preparador está tecleando.
        if LineaMostrada <> Rec."No. Linea" then
            Preparar()
        else
            CalcularProgreso();
    end;

    /// <summary>
    /// Deja la pantalla lista para la parada actual.
    /// </summary>
    local procedure Preparar()
    begin
        LineaMostrada := Rec."No. Linea";
        PendienteDocumento := Rec.EnUMDocumento(Rec."Cantidad Pendiente");
        UMPedido := Rec.UMVisible();
        MostrarBase := UMPedido <> Rec."Cod. Unidad Medida";
        CantidadRecogida := PendienteDocumento;
        UbicacionEscaneada := '';
        DigitoControl := '';
        Aviso := '';
        HayAviso := false;
        CalcularProgreso();
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
    /// Avisa en pantalla si la ubicación escaneada no es la indicada. Que el desvío se
    /// admita o no lo decide el motor al confirmar, según la configuración.
    /// </summary>
    local procedure ComprobarUbicacion()
    var
        rConfig: Record "Config. SGA";
        DesvioUbicacionLbl: Label 'Esa no es la ubicación indicada (%1). Se registrará como desvío.', Comment = '%1 = ubicación indicada';
        DesvioNoPermitidoLbl: Label 'Esa no es la ubicación indicada (%1) y la configuración no permite desviarse.', Comment = '%1 = ubicación indicada';
    begin
        Aviso := '';
        HayAviso := false;

        if UbicacionEscaneada = '' then
            exit;

        if UbicacionEscaneada = Rec."Cod. Bin Propuesto" then
            exit;

        rConfig.ObtenerConfig();
        HayAviso := true;
        if rConfig.DesvioPermitido(Rec."Cod. Bin Propuesto", UbicacionEscaneada) then
            Aviso := StrSubstNo(DesvioUbicacionLbl, Rec."Cod. Bin Propuesto")
        else
            Aviso := StrSubstNo(DesvioNoPermitidoLbl, Rec."Cod. Bin Propuesto");
    end;

    local procedure Confirmar()
    var
        cPicking: Codeunit "Gestion Picking SGA";
        CantidadNoIndicadaErr: Label 'Indique la cantidad recogida.';
    begin
        if CantidadRecogida <= 0 then
            Error(CantidadNoIndicadaErr);

        // El preparador habla en la UM del pedido; la parada, en base.
        cPicking.ConfirmarLinea(Rec, UbicacionEscaneada, Rec.CantidadBaseDesdeDocumento(CantidadRecogida, PendienteDocumento), DigitoControl);

        // Al quedar recogida sale del filtro de pendientes, así que se recarga la vista.
        if not SiguienteParada() then begin
            TerminarOrden();
            exit;
        end;

        Preparar();
        CurrPage.Update(false);
    end;

    local procedure MarcarSinStock()
    var
        cPicking: Codeunit "Gestion Picking SGA";
        SinStockQst: Label 'Se cancelará la parada de %1 en %2 y quedará constancia. ¿Continuar?', Comment = '%1 = producto, %2 = ubicación';
    begin
        if not Confirm(SinStockQst, false, Rec."No. Producto", Rec."Cod. Bin Propuesto") then
            exit;

        cPicking.CancelarLinea(Rec);

        if not SiguienteParada() then begin
            TerminarOrden();
            exit;
        end;

        Preparar();
        CurrPage.Update(false);
    end;

    /// <summary>
    /// Cierra el recorrido y pasa lo recogido al pedido. Se guarda antes lo confirmado: si el
    /// pedido no acepta los datos, el preparador no pierde su trabajo y oficina lo repite
    /// desde la orden con "Pasar al pedido".
    /// </summary>
    local procedure TerminarOrden()
    var
        rOrden: Record "Orden Picking SGA";
        OrdenTerminadaPasadaMsg: Label 'Orden terminada. Lo recogido ya está en el pedido %1.', Comment = '%1 = nº pedido';
        OrdenTerminadaSinPasarMsg: Label 'Orden terminada, pero no se ha podido pasar al pedido %1:\%2\\Avise a oficina para que lo pase desde la orden.', Comment = '%1 = nº pedido, %2 = error';
        OrdenTerminadaMsg: Label 'Orden terminada.';
    begin
        Commit();

        if not rOrden.Get(Rec."No. Orden") then begin
            Message(OrdenTerminadaMsg);
            CurrPage.Close();
            exit;
        end;

        if rOrden.Origen <> rOrden.Origen::Venta then
            Message(OrdenTerminadaMsg)
        else
            if Codeunit.Run(Codeunit::"Gestion Picking SGA", rOrden) then
                Message(OrdenTerminadaPasadaMsg, rOrden."No. Documento Origen")
            else
                Message(OrdenTerminadaSinPasarMsg, rOrden."No. Documento Origen", GetLastErrorText());

        CurrPage.Close();
    end;

    /// <summary>
    /// Recoloca el cursor en la primera parada que siga pendiente. Devuelve false si no queda
    /// ninguna, que es la señal de que la orden está terminada.
    /// </summary>
    local procedure SiguienteParada(): Boolean
    var
        orden: Code[20];
    begin
        orden := Rec."No. Orden";

        Rec.Reset();
        Rec.SetCurrentKey("No. Orden", Estado, "Secuencia Picking");
        Rec.SetRange("No. Orden", orden);
        Rec.FiltrarPendientes();

        exit(Rec.FindFirst());
    end;
}
