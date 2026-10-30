namespace AntonioNadal.SGA;

using AntonioNadal.Produccion;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Inventory.Setup;
using System.Environment;

/// <summary>
/// Page Ubicar Palets Linea SGA (ID 51127).
/// Versión de "Impresión Etiquetas Producción" (Pag50250) para trabajar con SGA: cada vez que
/// se imprime la etiqueta de un palé, ese palé queda ubicado en el hueco que se propone (o en
/// el que diga el operario). Imprimir y ubicar es un solo paso, para que no haya palés con
/// etiqueta y sin ubicación.
///
/// El palé se apunta al pedido de ensamblado enlazado a la tarea (ver PrepararPaleTarea en
/// "Gestion Entradas SGA"), así que al registrar el ensamblado "Ubicar entradas" ya lo da por
/// colocado.
///
/// En producción la etiqueta se genera igual que en Pag50250: mismo fichero para BarTender, misma
/// ruta y mismo contador de etiquetas impresas en la tarea. En Sandbox no se toca BarTender: sale
/// la etiqueta A5 (report 50237) directa a impresora por Universal Print.
/// </summary>
page 51127 "Ubicar Palets Linea SGA"
{
    Caption = 'Imprimir y ubicar palés de producción';
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
                        cUbicaciones.ComprobarUbicacionExiste(TempPaleActual."Cod. Almacen", TempPaleActual."Ubicacion Confirmada");
                        TempPaleActual.Modify();
                    end;
                }
                field(Motivo; TempPaleActual."Motivo Propuesta")
                {
                    Caption = 'Por qué ahí';
                    ToolTip = 'Por qué se propone ese hueco.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(CantidadPale; TempPaleActual."Cantidad a Ubicar")
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
                    AjustarEtiquetasQst: Label 'Esta acción iguala las etiquetas solicitadas con las impresas. ¿Continuar?';
                begin
                    if not Confirm(AjustarEtiquetasQst, false) then
                        exit;

                    Rec."Etiquetas Impresas" := Rec."Etiquetas Totales";
                    Rec.Estado := Rec.Estado::Finalizado;
                    Rec.Modify();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

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
        TempPaleActual: Record "Buffer Ubicar Entrada SGA";
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
                tipoPale := StrSubstNo(PaleIncompletoLbl, TempPaleActual."Cantidad a Ubicar", TempPaleActual."Cod. Unidad Medida");
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
    /// Imprime la etiqueta del palé y lo ubica. Todo lo que puede impedir ubicarlo se comprueba
    /// antes de imprimir, para no dejar etiquetas de palés sin ubicación.
    /// </summary>
    local procedure ImprimirYUbicarPale()
    var
        cEntradas: Codeunit "Gestion Entradas SGA";
        EnvironmentInformation: Codeunit "Environment Information";
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
        ComprobarEtiqueta();

        // En Sandbox no se toca BarTender (su carpeta FTP es la de producción): la etiqueta sale
        // con el report A5, directa a la impresora que tenga asignada en Selección de impresoras.
        if EnvironmentInformation.IsSandbox() then
            ImprimirEtiquetaA5()
        else begin
            ComprobarBarTender();
            EnviarEtiqueta();
        end;
        // La etiqueta ya ha salido: que un fallo al ubicar no deshaga el contador de
        // impresas. El palé quedaría pendiente y se ubica desde "Ubicar entradas".
        Commit();

        ubicacionPale := TempPaleActual."Ubicacion Confirmada";
        cantidad := TempPaleActual."Cantidad a Ubicar";
        cEntradas.ConfirmarFila(TempPaleActual);
        UltimoPale := StrSubstNo(UltimoPaleLbl, cantidad, TempPaleActual."Cod. Unidad Medida", ubicacionPale, Time);

        CargarPale();
        CurrPage.Update(false);
    end;

    /// <summary>
    /// Lo que impide sacar la etiqueta, salga por donde salga: sin códigos de barras,
    /// producción sin empezar o todas las etiquetas ya impresas.
    /// </summary>
    local procedure ComprobarEtiqueta()
    var
        rItemRef: Record "Item Reference";
        SinCodigosBarrasErr: Label 'Este producto no tiene códigos de barras definidos, revisar y después volver a imprimir.';
        ProduccionNoIniciadaErr: Label 'No se pueden imprimir etiquetas de una producción no iniciada.';
        EtiquetasYaImpresasErr: Label 'Ya están impresas las %1 etiquetas planificadas para esta tarea.', Comment = '%1 = etiquetas totales';
    begin
        rItemRef.SetRange("Item No.", Rec."Cod. Producto");
        rItemRef.SetRange("Reference Type", rItemRef."Reference Type"::"Bar Code");
        if rItemRef.IsEmpty() then
            Error(SinCodigosBarrasErr);

        if not Rec."Todo el dia" then begin
            // El 3502007 se etiqueta sin esperar a que arranque la línea, igual que en Pag50250.
            if (Rec."Cod. Producto" <> '3502007') and (Rec."Estado Produccion" = Rec."Estado Produccion"::"0") then
                Error(ProduccionNoIniciadaErr);
            // Pag50250 dejaba sacar una de más (comparaba con >). Aquí cada etiqueta es un palé
            // que se ubica, así que no se pasa de las planificadas.
            if Rec."Etiquetas Impresas" >= Rec."Etiquetas Totales" then
                Error(EtiquetasYaImpresasErr, Rec."Etiquetas Totales");
        end;
    end;

    /// <summary>
    /// BarTender necesita la ruta y la conexión FTP de la carpeta que vigila la impresora.
    /// </summary>
    local procedure ComprobarBarTender()
    var
        rConfExistencias: Record "Inventory Setup";
        FaltaRutaEtiquetasErr: Label 'Falta configuración ruta exportación impresión etiquetas producción.';
    begin
        if not rConfExistencias.Get() then
            Error(FaltaRutaEtiquetasErr);
        rConfExistencias.TestField("Ruta Fichero Etiquetas");
        rConfExistencias.TestField("Conexion FTP - Impr. Etiquetas");
    end;

    /// <summary>
    /// Genera el fichero de la etiqueta, lo sube a la carpeta que vigila la impresora y suma
    /// una etiqueta impresa a la tarea. Mismo contenido que CrearFicheroImpresora de Pag50250,
    /// que tenía el código repetido para "Todo el día" y el resto.
    /// </summary>
    local procedure EnviarEtiqueta()
    var
        rItem: Record Item;
        rDatos: Record "Datos Reports Temporales";
        rConfExistencias: Record "Inventory Setup";
        TempFileBuffer: Record "DynES HLP File Buffer" temporary;
        cduDynasoftFTPHelper: Codeunit "DynES HLP Ftp Helper";
        OutStr: OutStream;
        dato: Text;
        tipoPrecinto: Code[20];
        volumen: Text;
        caducidadText: Text;
        dun14: Text;
        ean13: Text;
        FicheroTok: Label 'EtiquetasA5.txt', Locked = true;
        CodigoDatosTok: Label 'BARTENDER', Locked = true;
    begin
        rItem.Get(Rec."Cod. Producto");
        rItem.CalcFields("EAN-13", "DUN-14");
        dun14 := CopyStr(rItem."DUN-14", 1, 13);    // Caja: DUN-14 sin dígito de control
        ean13 := CopyStr(rItem."EAN-13", 1, 12);    // Botella: EAN-13 sin dígito de control

        // Sin precinto se etiqueta como EXPORT.
        if Rec."Tipo Precinto" <> '' then
            tipoPrecinto := Rec."Tipo Precinto"
        else
            tipoPrecinto := 'EXPORT';

        if rItem."Unit Volume" = 1.0 then
            volumen := '1,00'
        else
            volumen := Format(rItem."Unit Volume");

        caducidadText := Format(Rec.Caducidad, 6, '<Year,2><Month,2><Day,2>');

        dato := Rec.Descripcion + ';' +
                'GRADOS: ' + Format(rItem."Grados de Alcohol") + ';' +
                'VOLUMEN: ' + volumen + ';' +
                'FAMILIA: ' + rItem."Tipo Alcohol" + ';' +
                'LOTE: ' + Rec.Lote + ';' +
                'NAV: ' + Rec."Cod. Producto" + ';' +
                'VARIANTE: ' + tipoPrecinto + ';' +
                Rec."Unidad Medida Venta" + ';' +
                Rec."Cod. Pale Defecto" + ';' +
                dun14 + ';' +
                ean13 + ';' +
                CodigoPale() + ';' +
                ';' +
                Format(Rec."Qty. Und. Medida") + ';' +
                '01' + ';' +
                Rec.Lote + ';' +
                caducidadText;

        rDatos.SetRange(Code01, CodigoDatosTok);
        rDatos.DeleteAll();

        rDatos.Init();
        rDatos.Usuario := CopyStr(UserId(), 1, MaxStrLen(rDatos.Usuario));
        rDatos.Fecha := Today;
        rDatos.Hora := Time;
        rDatos.Code01 := CodigoDatosTok;
        rDatos.Integer01 := 1;
        rDatos.Text01 := CopyStr(dato, 1, MaxStrLen(rDatos.Text01));
        rDatos.Insert();

        Rec."Etiquetas Impresas" += 1;
        if Rec."Etiquetas Impresas" = 1 then
            Rec."Hora Primera Impresion" := Time;
        if Rec."Etiquetas Totales" = Rec."Etiquetas Impresas" then begin
            Rec.Estado := Rec.Estado::Finalizado;
            Rec."Hora Ultima Impresion" := Time;
        end;
        Rec.Modify();

        rConfExistencias.Get();
        TempFileBuffer.Init();
        TempFileBuffer.Id := 2;
        TempFileBuffer."Full File Path" := StrSubstNo('%1%2', rConfExistencias."Ruta Fichero Etiquetas", FicheroTok);
        TempFileBuffer."File Name" := FicheroTok;
        TempFileBuffer."File Content".CreateOutStream(OutStr);
        Xmlport.Export(Xmlport::"Ficheros Impresora", OutStr, rDatos);
        TempFileBuffer.Insert();
        TempFileBuffer.SetRange(Id, 2);
        cduDynasoftFTPHelper.Upload(CopyStr(rConfExistencias."Conexion FTP - Impr. Etiquetas", 1, 20), TempFileBuffer);
    end;

    /// <summary>
    /// Etiqueta A5 (report 50237) sin ventana de opciones: va directa a la impresora que tenga
    /// el report en Selección de impresoras (Universal Print). Sin impresora asignada, BC la
    /// descarga en PDF.
    ///
    /// El report ya suma la etiqueta impresa, y solo si se imprime de verdad. Si el contador no
    /// sube, no ha salido etiqueta y se para aquí: no se ubica un palé sin etiqueta. Lo que el
    /// report no hace (horas y dar la tarea por terminada) se completa después.
    /// </summary>
    local procedure ImprimirEtiquetaA5()
    var
        rTarea: Record "Tareas Produccion";
        impresasAntes: Decimal;
        EtiquetaNoImpresaErr: Label 'No ha salido la etiqueta del palé: no se ubica.';
    begin
        impresasAntes := Rec."Etiquetas Impresas";

        // Un report no se puede lanzar con una transacción abierta.
        Commit();
        rTarea.Get(Rec.Linea);
        rTarea.SetRecFilter();
        Report.RunModal(Report::"Etiqueta Producto A5", false, false, rTarea);

        Rec.Get(Rec.Linea);
        if Rec."Etiquetas Impresas" <= impresasAntes then
            Error(EtiquetaNoImpresaErr);

        if Rec."Etiquetas Impresas" = 1 then
            Rec."Hora Primera Impresion" := Time;
        if Rec."Etiquetas Totales" = Rec."Etiquetas Impresas" then begin
            Rec.Estado := Rec.Estado::Finalizado;
            Rec."Hora Ultima Impresion" := Time;
        end;
        Rec.Modify();
    end;

    /// <summary>
    /// Código de unidad de envío del palé (EAN-128), sacado del DUN-14 de la unidad de venta,
    /// el lote, las cajas por palé y el tipo de precinto. Es lo único que aprovechaba la
    /// etiqueta de Barras128 en Pag50250; el resto de lo que calculaba no se usaba.
    /// </summary>
    local procedure CodigoPale(): Text
    var
        rUnidMedProd: Record "Item Unit of Measure";
        cduCodBarras: Codeunit "Gestion Codigos Barras";
        codigoDUN14: Code[20];
        usoPrecinto: Text[1];
    begin
        if rUnidMedProd.Get(Rec."Cod. Producto", Rec."Unidad Medida Venta") then begin
            rUnidMedProd.CalcFields("Codigo Barras");
            codigoDUN14 := CopyStr(rUnidMedProd."Codigo Barras", 1, MaxStrLen(codigoDUN14));
        end;

        if (StrPos(Rec."Tipo Precinto", 'B4') > 0) or (StrPos(Rec."Tipo Precinto", 'E6') > 0) then
            usoPrecinto := '0';
        if StrPos(Rec."Tipo Precinto", 'SP') > 0 then
            usoPrecinto := '2';

        cduCodBarras.Run();
        cduCodBarras.GetEAN128PaletsVariante(CopyStr(codigoDUN14, 1, 14), Rec.Lote, Format(Rec."Qty. Und. Medida"), usoPrecinto);
        exit(CopyStr(cduCodBarras.GetEAN128PaletsTxt2(), 5, 17));
    end;
}
