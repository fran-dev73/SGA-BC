namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;

/// <summary>
/// Page Ubicar Entradas SGA (ID 51123).
/// Lo que ha entrado en el almacén en un día, con el hueco que le toca a cada cosa. Sirve para
/// los ensamblados y para las recepciones de compra: el operario ve la lista, el sistema le
/// propone una ubicación para cada línea, y él confirma o pide otra.
///
/// El origen lo fija quien abre la página con RunPageView sobre el campo Origen (así lo hacen el
/// rol center y Pag-Ext51103). Sin filtro se abre en ensamblados, que es como funcionaba antes.
///
/// La lista se reconstruye cada vez que se cambia la fecha: lo que ya está colocado se sabe
/// por el diario de movimientos, no por una marca guardada aparte.
/// </summary>
page 51123 "Ubicar Entradas SGA"
{
    Caption = 'Ubicar entradas';
    // Worksheet y no List: BC abre las listas del menú en modo consulta y los filtros de arriba
    // no se podían tocar sin pulsar antes "Editar lista".
    PageType = Worksheet;
    UsageCategory = Tasks;
    ApplicationArea = All;
    SourceTable = "Buffer Ubicar Entrada SGA";
    SourceTableTemporary = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    AboutTitle = 'Ubicar entradas';
    AboutText = 'Ajuste los filtros de arriba (fechas, almacén, clase de artículo, producto, solo lo pendiente) y pulse "Proponer ubicaciones". El sistema reparte lo que ha entrado entre huecos, sin repetir ninguno. Puede pedir otra ubicación para cualquier línea antes de confirmar.';

    layout
    {
        area(Content)
        {
            group(Filtros)
            {
                Caption = 'Qué se mira';

                field(FiltroFechaDesde; FiltroFechaDesde)
                {
                    Caption = 'Registrado desde';
                    ToolTip = 'Primera fecha de registro que se mira. En blanco, sin límite: en recepciones salen todas las que aún tienen stock.';
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        Recargar();
                    end;
                }
                field(FiltroFechaHasta; FiltroFechaHasta)
                {
                    Caption = 'Registrado hasta';
                    ToolTip = 'Última fecha de registro que se mira. En blanco, hasta hoy.';
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        Recargar();
                    end;
                }
                field(FiltroClase; FiltroClase)
                {
                    Caption = 'Clase de artículo';
                    ToolTip = 'Solo los productos de esta clase (campo "Clase de artículo" de la ficha del producto). Todas para no filtrar.';
                    ApplicationArea = All;
                    // Lo que llega a hueco es producto acabado: los embotellados sacan propios o
                    // externos, y materia prima y granel no se ubican aquí.
                    OptionCaption = 'Todas,Prod. propio,Prod. externo';

                    trigger OnValidate()
                    begin
                        Recargar();
                    end;
                }
                field(FiltroProducto; FiltroProducto)
                {
                    Caption = 'Producto';
                    ToolTip = 'Solo las entradas de este producto. En blanco, todos.';
                    ApplicationArea = All;
                    TableRelation = Item;

                    trigger OnValidate()
                    begin
                        Recargar();
                    end;
                }
                field(FiltroAlmacen; FiltroAlmacen)
                {
                    Caption = 'Almacén';
                    ToolTip = 'Almacén en el que se ubica. En blanco, el que traiga cada entrada.';
                    ApplicationArea = All;
                    TableRelation = Location;

                    trigger OnValidate()
                    begin
                        Recargar();
                    end;
                }
                field(SoloPendientes; SoloPendientes)
                {
                    Caption = 'Solo lo que falta por ubicar';
                    ToolTip = 'Oculta las entradas que ya están colocadas del todo.';
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        Recargar();
                    end;
                }
                field(Resumen; Resumen)
                {
                    Caption = 'Situación';
                    ToolTip = 'Cuántas entradas hay y cuántas quedan por colocar.';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                }
            }
            repeater(Entradas)
            {
                field("Fecha Registro"; Rec."Fecha Registro")
                {
                    ToolTip = 'Fecha de registro del albarán o del ensamblado.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("No. Documento"; Rec."No. Documento")
                {
                    ToolTip = 'Ensamblado o albarán de compra del que viene la mercancía.';
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = EstiloFila;
                }
                field("Descripcion Origen"; Rec."Descripcion Origen")
                {
                    ToolTip = 'Proveedor de la recepción.';
                    ApplicationArea = All;
                    Editable = false;
                    Visible = EsCompra;
                }
                field("No. Producto"; Rec."No. Producto")
                {
                    ToolTip = 'Producto que ha entrado.';
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = EstiloFila;
                }
                field("Descripcion Producto"; Rec."Descripcion Producto")
                {
                    ToolTip = 'Descripción del producto.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Cod. Variante"; Rec."Cod. Variante")
                {
                    ToolTip = 'Variante del producto.';
                    ApplicationArea = All;
                    Editable = false;
                    Visible = false;
                }
                field("No. Lote"; Rec."No. Lote")
                {
                    ToolTip = 'Lote con el que se ha registrado la entrada.';
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = EstiloFila;
                }
                field("Cantidad Entrada"; Rec."Cantidad Entrada")
                {
                    ToolTip = 'Cantidad que ha entrado.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Cantidad Ya Ubicada"; Rec."Cantidad Ya Ubicada")
                {
                    ToolTip = 'Cantidad que ya está colocada en ubicaciones.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Cantidad a Ubicar"; Rec."Cantidad a Ubicar")
                {
                    ToolTip = 'Cantidad que se va a colocar ahora. Se puede reducir para ubicar en varias veces.';
                    ApplicationArea = All;
                }
                field("Cod. Unidad Medida"; Rec."Cod. Unidad Medida")
                {
                    ToolTip = 'Unidad de medida en la que ha entrado.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Ubicacion Propuesta"; Rec."Ubicacion Propuesta")
                {
                    ToolTip = 'Hueco que propone el sistema.';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                }
                field("Motivo Propuesta"; Rec."Motivo Propuesta")
                {
                    ToolTip = 'Por qué se propone ese hueco.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Ubicacion Confirmada"; Rec."Ubicacion Confirmada")
                {
                    ToolTip = 'Hueco en el que se ha dejado realmente. Escanéelo o tecléelo si no es el propuesto.';
                    ApplicationArea = All;

                    trigger OnValidate()
                    var
                        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
                    begin
                        cUbicaciones.ComprobarUbicacionExiste(Rec."Cod. Almacen", Rec."Ubicacion Confirmada");
                    end;
                }
                field("Cod. Almacen"; Rec."Cod. Almacen")
                {
                    ToolTip = 'Almacén en el que se coloca.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Ubicado; Rec.Ubicado)
                {
                    ToolTip = 'Marcado cuando ya no queda nada pendiente de esta línea.';
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = EstiloFila;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ProponerTodas)
            {
                Caption = 'Proponer ubicaciones';
                ToolTip = 'Reparte todo lo pendiente entre huecos, sin asignar el mismo a dos líneas.';
                ApplicationArea = All;
                Image = Suggest;

                trigger OnAction()
                var
                    cEntradas: Codeunit "Gestion Entradas SGA";
                    propuestas: Integer;
                    UbicacionesPropuestasMsg: Label 'Se han propuesto %1 ubicaciones.', Comment = '%1 = número de propuestas';
                    NingunaPropuestaMsg: Label 'No se ha podido proponer ninguna ubicación. Revise que haya huecos libres y sin bloquear.';
                begin
                    propuestas := cEntradas.ProponerParaTodos(Rec);
                    ActualizarResumen();
                    CurrPage.Update(false);

                    if propuestas = 0 then
                        Message(NingunaPropuestaMsg)
                    else
                        Message(UbicacionesPropuestasMsg, propuestas);
                end;
            }
            action(OtraUbicacion)
            {
                Caption = 'Otra ubicación';
                ToolTip = 'Descarta el hueco propuesto para esta línea y busca otro disponible.';
                ApplicationArea = All;
                Image = Find;

                trigger OnAction()
                var
                    cEntradas: Codeunit "Gestion Entradas SGA";
                    LineaYaUbicadaErr: Label 'Esta línea ya está ubicada.';
                begin
                    if Rec.Ubicado then
                        Error(LineaYaUbicadaErr);

                    cEntradas.ProponerOtra(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(ConfirmarLinea)
            {
                Caption = 'Confirmar esta línea';
                ToolTip = 'Registra que la mercancía de esta línea ha quedado en la ubicación confirmada.';
                ApplicationArea = All;
                Image = Approve;

                trigger OnAction()
                var
                    cEntradas: Codeunit "Gestion Entradas SGA";
                    LineaUbicadaMsg: Label 'Ubicado %1 de %2 en %3.', Comment = '%1 = cantidad, %2 = producto, %3 = ubicación';
                    cantidad: Decimal;
                    ubicacion: Code[20];
                begin
                    cantidad := Rec."Cantidad a Ubicar";
                    ubicacion := Rec."Ubicacion Confirmada";

                    cEntradas.ConfirmarFila(Rec);
                    ActualizarResumen();
                    CurrPage.Update(false);

                    Message(LineaUbicadaMsg, cantidad, Rec."No. Producto", ubicacion);
                end;
            }
            action(ConfirmarTodo)
            {
                Caption = 'Confirmar todo';
                ToolTip = 'Registra de golpe todas las líneas que ya tengan ubicación confirmada.';
                ApplicationArea = All;
                Image = PostDocument;

                trigger OnAction()
                var
                    cEntradas: Codeunit "Gestion Entradas SGA";
                    hechas: Integer;
                    ConfirmarTodasQst: Label 'Se van a ubicar todas las líneas que tengan ubicación confirmada. ¿Continuar?';
                    LineasUbicadasMsg: Label 'Se han ubicado %1 líneas.', Comment = '%1 = número de líneas';
                    NingunaLineaListaMsg: Label 'No hay ninguna línea lista para ubicar.';
                begin
                    if not Confirm(ConfirmarTodasQst, false) then
                        exit;

                    hechas := cEntradas.ConfirmarTodas(Rec);
                    ActualizarResumen();
                    CurrPage.Update(false);

                    if hechas = 0 then
                        Message(NingunaLineaListaMsg)
                    else
                        Message(LineasUbicadasMsg, hechas);
                end;
            }
            action(ActualizarLista)
            {
                Caption = 'Actualizar';
                ToolTip = 'Vuelve a leer las entradas del día y lo que ya está colocado.';
                ApplicationArea = All;
                Image = Refresh;

                trigger OnAction()
                begin
                    Recargar();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(VerContenido)
            {
                Caption = 'Ver contenido de la ubicación';
                ToolTip = 'Muestra qué hay ahora mismo en la ubicación propuesta para esta línea.';
                ApplicationArea = All;
                Image = BinContent;

                trigger OnAction()
                var
                    rContenido: Record "Contenido Ubicacion SGA";
                begin
                    rContenido.SetRange("Cod. Almacen", Rec."Cod. Almacen");
                    rContenido.SetRange("Cod. Bin", Rec."Ubicacion Confirmada");
                    Page.Run(Page::"Contenido Ubicaciones SGA", rContenido);
                end;
            }
            action(VerMovimientos)
            {
                Caption = 'Movimientos del documento';
                ToolTip = 'Diario de lo que se ha ubicado de este ensamblado o albarán.';
                ApplicationArea = All;
                Image = Journals;

                trigger OnAction()
                var
                    rMov: Record "Movimiento Ubicacion SGA";
                begin
                    rMov.SetRange(Origen, Rec.Origen);
                    rMov.SetRange("No. Documento Origen", Rec."No. Documento");
                    Page.Run(Page::"Movs. Ubicacion SGA", rMov);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(ProponerTodas_Promoted; ProponerTodas)
                {
                }
                actionref(OtraUbicacion_Promoted; OtraUbicacion)
                {
                }
                actionref(ConfirmarLinea_Promoted; ConfirmarLinea)
                {
                }
                actionref(ConfirmarTodo_Promoted; ConfirmarTodo)
                {
                }
            }
        }
    }

    var
        OrigenPagina: Enum "Origen Mov. SGA";
        FiltroFechaDesde: Date;
        FiltroFechaHasta: Date;
        FiltroClase: Option Todas,"Prod. Propio","Prod. Externo";
        FiltroProducto: Code[20];
        FiltroAlmacen: Code[10];
        SoloPendientes: Boolean;
        EsCompra: Boolean;
        Resumen: Text;
        EstiloFila: Text;

    trigger OnOpenPage()
    var
        rConfig: Record "Config. SGA";
        CaptionEnsambladosLbl: Label 'Ubicar ensamblados';
        CaptionRecepcionesLbl: Label 'Ubicar recepciones de compra';
    begin
        // El origen llega como filtro desde RunPageView. Sin filtro, ensamblados.
        if Rec.GetFilter(Origen) <> '' then
            OrigenPagina := Rec.GetRangeMin(Origen)
        else
            OrigenPagina := OrigenPagina::Produccion;

        EsCompra := OrigenPagina = OrigenPagina::Compra;
        if EsCompra then
            CurrPage.Caption := CaptionRecepcionesLbl
        else
            CurrPage.Caption := CaptionEnsambladosLbl;

        rConfig.ObtenerConfig();
        FiltroAlmacen := rConfig."Almacen por Defecto";
        // Recepciones: todo lo pendiente de productos externos, sin límite de fecha. Ensamblados:
        // lo del día, de cualquier clase, como hasta ahora.
        if EsCompra then begin
            FiltroFechaDesde := 0D;
            FiltroClase := FiltroClase::"Prod. Externo";
        end else begin
            FiltroFechaDesde := WorkDate();
            FiltroFechaHasta := WorkDate();
            FiltroClase := FiltroClase::Todas;
        end;
        SoloPendientes := true;
        Recargar();
    end;

    trigger OnAfterGetRecord()
    begin
        EstiloFila := Rec.Estilo();
    end;

    local procedure Recargar()
    var
        rItem: Record Item;
        cEntradas: Codeunit "Gestion Entradas SGA";
        clase: Integer;
    begin
        // La pantalla solo ofrece propios y externos; el codeunit espera el valor de la ficha
        // del producto, o -1 para no filtrar.
        case FiltroClase of
            FiltroClase::"Prod. Propio":
                clase := rItem."Clase de articulo"::"Prod. Propio";
            FiltroClase::"Prod. Externo":
                clase := rItem."Clase de articulo"::"Prod. Externo";
            else
                clase := -1;
        end;
        cEntradas.CargarEntradas(Rec, OrigenPagina, FiltroFechaDesde, FiltroFechaHasta, FiltroAlmacen, SoloPendientes, clase, FiltroProducto);
        ActualizarResumen();
        if Rec.FindFirst() then;
    end;

    local procedure ActualizarResumen()
    var
        TempFila: Record "Buffer Ubicar Entrada SGA";
        total: Integer;
        pendientes: Integer;
        sinHueco: Integer;
        ResumenEnsambladosLbl: Label '%1 ensamblados, %2 por ubicar.', Comment = '%1 = total, %2 = pendientes';
        ResumenEnsambladosSinHuecoLbl: Label '%1 ensamblados, %2 por ubicar, %3 sin hueco disponible.', Comment = '%1 = total, %2 = pendientes, %3 = sin hueco';
        SinEnsambladosLbl: Label 'No hay ensamblados con estos filtros.';
        ResumenRecepcionesLbl: Label '%1 líneas recibidas, %2 por ubicar.', Comment = '%1 = total, %2 = pendientes';
        ResumenRecepcionesSinHuecoLbl: Label '%1 líneas recibidas, %2 por ubicar, %3 sin hueco disponible.', Comment = '%1 = total, %2 = pendientes, %3 = sin hueco';
        SinRecepcionesLbl: Label 'No hay recepciones de compra con estos filtros.';
    begin
        TempFila.Copy(Rec, true);
        TempFila.Reset();
        total := TempFila.Count();

        if total = 0 then begin
            if EsCompra then
                Resumen := SinRecepcionesLbl
            else
                Resumen := SinEnsambladosLbl;
            exit;
        end;

        TempFila.SetRange(Ubicado, false);
        pendientes := TempFila.Count();

        TempFila.SetRange("Ubicacion Propuesta", '');
        sinHueco := TempFila.Count();

        if EsCompra then begin
            if sinHueco > 0 then
                Resumen := StrSubstNo(ResumenRecepcionesSinHuecoLbl, total, pendientes, sinHueco)
            else
                Resumen := StrSubstNo(ResumenRecepcionesLbl, total, pendientes);
        end else
            if sinHueco > 0 then
                Resumen := StrSubstNo(ResumenEnsambladosSinHuecoLbl, total, pendientes, sinHueco)
            else
                Resumen := StrSubstNo(ResumenEnsambladosLbl, total, pendientes);
    end;
}
