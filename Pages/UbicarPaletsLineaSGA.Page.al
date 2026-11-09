namespace AntonioNadal.SGA;

using AntonioNadal.Produccion;

/// <summary>
/// Page Ubicar Palets Linea SGA (ID 51127).
/// Versión de "Impresión Etiquetas Producción" (Pag50250) para trabajar con SGA: cada vez que
/// se imprime la etiqueta de un palé, ese palé queda ubicado en el hueco que se propone (o en
/// el que diga el operario). Imprimir y ubicar es un solo paso, para que no haya palés con
/// etiqueta y sin ubicación.
///
/// La página captura la tarea y la ubicación y enseña la situación del palé. El trabajo lo
/// hace "Gestion Entradas SGA": PrepararPaleTarea calcula el siguiente palé y su hueco, y
/// ImprimirYUbicarPale saca la etiqueta y lo ubica. El palé se apunta al pedido de ensamblado
/// enlazado a la tarea, así que al registrar el ensamblado "Ubicar entradas" ya lo da por
/// colocado.
///
/// En producción la etiqueta se genera igual que en Pag50250: mismo fichero para BarTender, misma
/// ruta y mismo contador de etiquetas impresas en la tarea. En Sandbox no se toca BarTender: sale
/// la etiqueta A5 (report 50237) directa a impresora por Universal Print.
/// </summary>
page 51127 "Ubicar Palets Linea SGA"
{
    Caption = 'Imprimir y ubicar palés de producción SGA';
    // Worksheet y no List: en una lista BC abre en modo consulta y no se podría cambiar la
    // ubicación propuesta sin pulsar antes "Editar lista".
    PageType = Worksheet;
    SourceTable = "Tareas Produccion";
    SourceTableView = sorting(Orden);
    ApplicationArea = All;
    UsageCategory = Tasks;
    InsertAllowed = false;
    DeleteAllowed = false;
    AboutTitle = 'Imprimir y ubicar palés';
    AboutText = 'Elija la tarea que está en línea. Arriba sale el hueco en el que dejar el siguiente palé; cámbielo si lo deja en otro. "Imprimir y ubicar" saca la etiqueta y deja el palé ubicado en SGA.';

    layout
    {
        area(Content)
        {
            group(PaleSiguiente)
            {
                Caption = 'Siguiente palé';

                field(Ubicacion; TempPaleActual."Ubicacion Confirmada")
                {
                    Caption = 'Ubicación';
                    ToolTip = 'Hueco en el que se deja el palé. Sale el propuesto; escanee o teclee otro si lo deja en otro sitio.';
                    ApplicationArea = All;
                    Editable = HayPale;
                    Style = Strong;

                    trigger OnValidate()
                    begin
                        TempPaleActual.Modify();
                    end;
                }
                field(Motivo; TempPaleActual.Motivo)
                {
                    Caption = 'Por qué ahí';
                    ToolTip = 'Por qué se propone ese hueco.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(CantidadPale; TempPaleActual.Cantidad)
                {
                    Caption = 'Cantidad del palé';
                    ToolTip = 'Lo que se ubica con este palé, en la unidad del ensamblado. El último puede ir incompleto.';
                    ApplicationArea = All;
                    Editable = false;
                    DecimalPlaces = 0 : 5;
                }
                field(UnidadPale; TempPaleActual."Cod. Unidad Medida")
                {
                    Caption = 'Unidad';
                    ToolTip = 'Unidad del ensamblado, que es en la que se ubica.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Situacion; Situacion)
                {
                    Caption = 'Situación';
                    ToolTip = 'Cuánto lleva ubicado el ensamblado de la tarea, o por qué no se puede ubicar.';
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = EstiloSituacion;
                }
                field(UltimoPale; UltimoPale)
                {
                    Caption = 'Último palé';
                    ToolTip = 'Dónde se ha dejado el último palé impreso desde esta pantalla.';
                    ApplicationArea = All;
                    Editable = false;
                }
            }
            repeater(General)
            {
                Editable = false;

                field(Linea; Rec.Linea)
                {
                    ToolTip = 'Número de la tarea de producción.';
                    ApplicationArea = All;
                    Caption = 'Nº tarea';
                }
                field(Fecha; Rec.Fecha)
                {
                    ToolTip = 'Día en que está planificada la tarea.';
                    ApplicationArea = All;
                    Caption = 'Fecha';
                }
                field("Estado Produccion img"; Rec."Estado Produccion img")
                {
                    ToolTip = 'Situación de la producción en la línea.';
                    ApplicationArea = All;
                    Caption = 'Estado';
                }
                field(Orden; Rec.Orden)
                {
                    ToolTip = 'Orden de la tarea dentro del día y la línea.';
                    ApplicationArea = All;
                    Caption = 'Orden';
                }
                field("Linea Fabricacion"; Rec."Linea Fabricacion")
                {
                    ToolTip = 'Línea de embotellado en la que se hace.';
                    ApplicationArea = All;
                    Caption = 'Línea de fabricación';
                }
                field("Cod. Producto"; Rec."Cod. Producto")
                {
                    ToolTip = 'Producto que se embotella.';
                    ApplicationArea = All;
                    Caption = 'Cód. producto';
                }
                field(Descripcion; Rec.Descripcion)
                {
                    ToolTip = 'Descripción del producto.';
                    ApplicationArea = All;
                    Caption = 'Descripción';
                }
                field("Tipo Precinto"; Rec."Tipo Precinto")
                {
                    ToolTip = 'Precinto con el que se etiqueta.';
                    ApplicationArea = All;
                }
                field(Lote; Rec.Lote)
                {
                    ToolTip = 'Lote de la producción.';
                    ApplicationArea = All;
                    Caption = 'Lote';
                }
                field("Cod. Pale Defecto"; Rec."Cod. Pale Defecto")
                {
                    ToolTip = 'Unidad de palé de la tarea: cada etiqueta es un palé de esta unidad.';
                    ApplicationArea = All;
                    Caption = 'Palé';
                }
                field("Etiquetas Totales"; Rec."Etiquetas Totales")
                {
                    ToolTip = 'Etiquetas (palés) planificadas para la tarea.';
                    ApplicationArea = All;
                    Caption = 'Etiquetas totales';
                }
                field("Etiquetas Impresas"; Rec."Etiquetas Impresas")
                {
                    ToolTip = 'Etiquetas ya impresas.';
                    ApplicationArea = All;
                    Caption = 'Etiquetas impresas';
                }
                field(Estado; Rec.Estado)
                {
                    ToolTip = 'Estado de la impresión de etiquetas de la tarea.';
                    ApplicationArea = All;
                    Caption = 'Estado etiquetas';
                }
                field("Estado Produccion"; Rec."Estado Produccion")
                {
                    ToolTip = 'Estado de la producción en la línea.';
                    ApplicationArea = All;
                    Caption = 'Estado producción';
                }
                field("Todo el dia"; Rec."Todo el dia")
                {
                    ToolTip = 'La tarea ocupa la línea todo el día.';
                    ApplicationArea = All;
                    Caption = 'Todo el día';
                    Visible = false;
                }
                field("Litros Produccion"; Rec."Litros Produccion")
                {
                    ToolTip = 'Litros planificados.';
                    ApplicationArea = All;
                    Caption = 'Litros producción';
                    Visible = false;
                }
                field("Unidad Medida Venta"; Rec."Unidad Medida Venta")
                {
                    ToolTip = 'Unidad de venta del producto.';
                    ApplicationArea = All;
                    Caption = 'Unidad medida venta';
                    Visible = false;
                }
                field("Hora Primera Impresion"; Rec."Hora Primera Impresion")
                {
                    ToolTip = 'Hora de la primera etiqueta impresa.';
                    ApplicationArea = All;
                    Caption = 'Hora primera impresión';
                    Visible = false;
                }
                field("Hora Ultima Impresion"; Rec."Hora Ultima Impresion")
                {
                    ToolTip = 'Hora de la última etiqueta impresa.';
                    ApplicationArea = All;
                    Caption = 'Hora última impresión';
                    Visible = false;
                }
                field(Observacion1; Rec.Observacion1)
                {
                    ToolTip = 'Observaciones de la tarea.';
                    ApplicationArea = All;
                    Caption = 'Observación 1';
                }
                field(Observacion2; Rec.Observacion2)
                {
                    ToolTip = 'Observaciones que van en la etiqueta.';
                    ApplicationArea = All;
                    Caption = 'Observación 2';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ImprimirYUbicar)
            {
                Caption = 'Imprimir y ubicar';
                ToolTip = 'Saca la etiqueta del palé y lo deja ubicado en la ubicación de arriba.';
                ApplicationArea = All;
                Image = PutawayLines;

                trigger OnAction()
                begin
                    ImprimirYUbicarPale();
                end;
            }
            action(ProponerUbicacion)
            {
                Caption = 'Proponer ubicación';
                ToolTip = 'Calcula ahora el hueco del almacén en el que dejar el siguiente palé, con la estrategia de ensamblados de la configuración, y lo pone arriba. Se puede cambiar antes de imprimir. Si no hay hueco, dice por qué.';
                ApplicationArea = All;
                Image = Suggest;

                trigger OnAction()
                var
                    SinHuecoMsg: Label 'No se ha podido proponer ubicación.\\%1', Comment = '%1 = motivo';
                    PropuestaMsg: Label 'El palé va a %1.\\%2', Comment = '%1 = ubicación, %2 = por qué ahí';
                begin
                    CargarPale();
                    CurrPage.Update(false);
                    if not HayPale then
                        Error(Situacion);
                    if TempPaleActual."Ubicacion Propuesta" = '' then
                        Message(SinHuecoMsg, Situacion)
                    else
                        Message(PropuestaMsg, TempPaleActual."Ubicacion Propuesta", TempPaleActual.Motivo);
                end;
            }
            action(OtraUbicacion)
            {
                Caption = 'Otra ubicación';
                ToolTip = 'Descarta el hueco propuesto y busca otro disponible.';
                ApplicationArea = All;
                Image = Change;

                trigger OnAction()
                var
                    cEntradas: Codeunit "Gestion Entradas SGA";
                begin
                    if not HayPale then
                        Error(Situacion);

                    cEntradas.ProponerOtra(TempPaleActual);
                    CurrPage.Update(false);
                end;
            }
            action(VerContenido)
            {
                Caption = 'Ver contenido de la ubicación';
                ToolTip = 'Muestra qué hay ahora mismo en la ubicación de arriba.';
                ApplicationArea = All;
                Image = BinContent;

                trigger OnAction()
                var
                    rContenido: Record "Contenido Ubicacion SGA";
                begin
                    rContenido.SetRange("Cod. Almacen", TempPaleActual."Cod. Almacen");
                    rContenido.SetRange("Cod. Bin", TempPaleActual."Ubicacion Confirmada");
                    Page.Run(Page::"Contenido Ubicaciones SGA", rContenido);
                end;
            }
            action(ActualizarUnitario)
            {
                Caption = 'Actualizar';
                ToolTip = 'Lee de la línea lo producido y vuelve a calcular el siguiente palé.';
                ApplicationArea = All;
                Image = RefreshPlanningLine;

                trigger OnAction()
                var
                    cGestionQR: Codeunit "Gestion QRs - Tunel";
                begin
                    cGestionQR.ActualizaUnitario_Tunel(Rec.Linea);
                    CargarPale();
                    CurrPage.Update(false);
                end;
            }
            action(Ajusta)
            {
                Caption = 'Ajustar impr. etiquetas';
                ToolTip = 'Da la tarea por terminada igualando las etiquetas impresas con las totales. No ubica nada.';
                ApplicationArea = All;
                Image = Approve;

                trigger OnAction()
                var
                    cEntradas: Codeunit "Gestion Entradas SGA";
                    AjustarEtiquetasQst: Label 'Esta acción iguala las etiquetas solicitadas con las impresas. ¿Continuar?';
                begin
                    if not Confirm(AjustarEtiquetasQst, false) then
                        exit;

                    cEntradas.AjustarEtiquetasImpresas(Rec);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(ProponerUbicacion_Promoted; ProponerUbicacion)
                {
                }
                actionref(ImprimirYUbicar_Promoted; ImprimirYUbicar)
                {
                }
                actionref(OtraUbicacion_Promoted; OtraUbicacion)
                {
                }
                actionref(ActualizarUnitario_Promoted; ActualizarUnitario)
                {
                }
            }
        }
    }

    var
        TempPaleActual: Record "Linea Ubicacion SGA" temporary;
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        TareaPale: Integer;
        HayPale: Boolean;
        Situacion: Text;
        EstiloSituacion: Text;
        UltimoPale: Text;

    trigger OnOpenPage()
    begin
        Rec.SetFilter(Estado, '<>%1', Rec.Estado::Finalizado);
        Rec.SetRange(Fecha, Today);
    end;

    trigger OnAfterGetCurrRecord()
    begin
        // Solo al cambiar de tarea: si no, cada refresco tiraría la ubicación que haya
        // tecleado el operario.
        if Rec.Linea <> TareaPale then
            CargarPale();
    end;

    /// <summary>
    /// Calcula el siguiente palé de la tarea seleccionada y el hueco que le toca.
    /// </summary>
    local procedure CargarPale()
    var
        cEntradas: Codeunit "Gestion Entradas SGA";
        aviso: Text;
        SituacionPaleLbl: Label '%1 Ubicado %2 de %3 %4 del ensamblado %5.', Comment = '%1 = palé completo o incompleto, %2 = ubicado, %3 = total, %4 = unidad, %5 = nº pedido de ensamblado';
        PaleCompletoLbl: Label 'Palé completo.';
        PaleIncompletoLbl: Label 'Palé incompleto (último de la tarea): %1 %2.', Comment = '%1 = cantidad, %2 = unidad';
        tipoPale: Text;
    begin
        TareaPale := Rec.Linea;
        HayPale := cEntradas.PrepararPaleTarea(Rec, TempPaleActual, aviso);

        // Con hueco propuesto, el aviso solo informa (botellas que no llegan a una caja).
        if HayPale and ((aviso = '') or (TempPaleActual."Ubicacion Propuesta" <> '')) then begin
            if TempPaleActual."Cod. Unidad Medida" = Rec."Cod. Pale Defecto" then
                tipoPale := PaleCompletoLbl
            else
                tipoPale := StrSubstNo(PaleIncompletoLbl, TempPaleActual.Cantidad, TempPaleActual."Cod. Unidad Medida");
            Situacion := StrSubstNo(SituacionPaleLbl, tipoPale, TempPaleActual."Cantidad Ya Ubicada", TempPaleActual."Cantidad Entrada",
                                    TempPaleActual."Cod. Unidad Medida", TempPaleActual."No. Documento");
            EstiloSituacion := 'Standard';
            if aviso <> '' then begin
                Situacion += ' ' + aviso;
                EstiloSituacion := 'Ambiguous';
            end;
        end else begin
            Situacion := aviso;
            EstiloSituacion := 'Unfavorable';
        end;
    end;

    /// <summary>
    /// Imprime la etiqueta del palé y lo ubica, con Cod. "Gestion Entradas SGA". Todo lo que
    /// puede impedir ubicarlo se comprueba antes de imprimir, para no dejar etiquetas de palés
    /// sin ubicación: aquí, que haya palé y una ubicación válida; en el codeunit, lo de la
    /// etiqueta.
    /// </summary>
    local procedure ImprimirYUbicarPale()
    var
        cEntradas: Codeunit "Gestion Entradas SGA";
        ubicacionPale: Code[20];
        cantidad: Decimal;
        UbicacionNoIndicadaErr: Label 'Indique la ubicación en la que deja el palé.';
        UltimoPaleLbl: Label '%1 %2 en %3 (%4)', Comment = '%1 = cantidad, %2 = unidad, %3 = ubicación, %4 = hora';
    begin
        if Rec.Linea <> TareaPale then
            CargarPale();
        if not HayPale then
            Error(Situacion);
        if TempPaleActual."Ubicacion Confirmada" = '' then
            Error(UbicacionNoIndicadaErr);
        cUbicaciones.ComprobarUbicacionExiste(TempPaleActual."Cod. Almacen", TempPaleActual."Ubicacion Confirmada");

        // Se guardan antes: al ubicar, la fila pasa a llevar lo que queda pendiente.
        ubicacionPale := TempPaleActual."Ubicacion Confirmada";
        cantidad := TempPaleActual.Cantidad;
        cEntradas.ImprimirYUbicarPale(Rec, TempPaleActual);
        Rec.Get(Rec.Linea);
        UltimoPale := StrSubstNo(UltimoPaleLbl, cantidad, TempPaleActual."Cod. Unidad Medida", ubicacionPale, Time);

        CargarPale();
        CurrPage.Update(false);
    end;
}
