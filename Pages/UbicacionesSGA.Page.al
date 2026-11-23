namespace AntonioNadal.SGA;

using System.Utilities;

/// <summary>
/// Page Ubicaciones SGA (ID 51100).
/// Lista de trabajo de las ubicaciones: cuántas hay, en qué estado están, cuánto tienen
/// dentro y qué capacidad les queda. Es el punto de entrada del módulo.
/// </summary>
page 51100 "Ubicaciones SGA"
{
    Caption = 'Ubicaciones SGA';
    PageType = List;
    SourceTable = "Ubicacion SGA";
    UsageCategory = Lists;
    ApplicationArea = All;
    CardPageId = "Ficha Ubicacion SGA";
    // Como en las listas estándar: se edita en la ficha. Desde Configuración se abre normal
    // (Nuevo, Eliminar y ficha editable); desde Consultas, con AbrirSoloConsulta (solo ver).
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Cod. Bin"; Rec."Cod. Bin")
                {
                    Caption = 'Cód. Ubicación';
                    ToolTip = 'Código de la ubicación en la topología pasillo-estantería-altura (101-15-03).';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field("Cod. Almacen"; Rec."Cod. Almacen")
                {
                    ToolTip = 'Almacén al que pertenece la ubicación.';
                    ApplicationArea = All;
                }
                field(Descripcion; Rec.Descripcion)
                {
                    ApplicationArea = All;
                }
                field("Estado SGA"; Rec."Estado SGA")
                {
                    ToolTip = 'Estado de ocupación calculado: vacía, parcial, llena o bloqueada.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field("% Ocupacion"; Rec."% Ocupacion")
                {
                    ApplicationArea = All;
                    StyleExpr = EstiloPorcentaje;
                }
                field("Cod. Zona SGA"; Rec."Cod. Zona SGA")
                {
                    ToolTip = 'Zona a la que pertenece la ubicación.';
                    ApplicationArea = All;
                }
                field("Tipo Ubicacion"; Rec."Tipo Ubicacion")
                {
                    ApplicationArea = All;
                }
                field("Secuencia Picking"; Rec."Secuencia Picking")
                {
                    ToolTip = 'Orden de recorrido físico de la ubicación.';
                    ApplicationArea = All;
                }
                field("Lineas Contenido"; Rec."Lineas Contenido")
                {
                    ToolTip = 'Número de líneas de contenido de la ubicación: una por producto, lote y palé.';
                    ApplicationArea = All;
                    DrillDown = true;
                }
                field("Cantidad Base"; Rec."Cantidad Base")
                {
                    ToolTip = 'Unidades base que hay actualmente en la ubicación.';
                    ApplicationArea = All;
                }
                field("Capacidad Uds."; Rec."Capacidad Uds.")
                {
                    ToolTip = 'Cuántos palés caben; cada producto se cuenta con su palé por defecto. 0 = sin límite. Para cambiar muchas a la vez, use "Cambiar en bloque".';
                    ApplicationArea = All;
                }
                field("Control Capacidad"; Rec."Control Capacidad")
                {
                    ApplicationArea = All;
                    Visible = false;
                }
                field(Bloqueada; Rec.Bloqueada)
                {
                    ToolTip = 'Si está activo, la ubicación no admite entradas ni se propone para recoger.';
                    ApplicationArea = All;
                }
                field("Motivo Bloqueo"; Rec."Motivo Bloqueo")
                {
                    ApplicationArea = All;
                }
                field("Reservada Para"; Rec."Reservada Para")
                {
                    ApplicationArea = All;
                    Style = Attention;
                }
                field("Reservada Por"; Rec."Reservada Por")
                {
                    ApplicationArea = All;
                }
                field("Fecha Reserva"; Rec."Fecha Reserva")
                {
                    ApplicationArea = All;
                    Visible = false;
                }
                field("Producto Fijo"; Rec."Producto Fijo")
                {
                    ToolTip = 'Producto que tiene esta ubicación como casa. Solo se admite este producto.';
                    ApplicationArea = All;
                }
                field("Permite Mezcla Producto"; Rec."Permite Mezcla Producto")
                {
                    ToolTip = 'Marcado, el hueco admite productos distintos a la vez, como una estantería de picking con varias referencias.';
                    ApplicationArea = All;
                }
                field("Permite Mezcla Lote"; Rec."Permite Mezcla Lote")
                {
                    ToolTip = 'Si se desactiva, la ubicación solo puede contener un lote a la vez.';
                    ApplicationArea = All;
                    Visible = false;
                }
                field(Fondo; Rec.Fondo)
                {
                    ApplicationArea = All;
                }
                field("Fecha Ultimo Movimiento"; Rec."Fecha Ultimo Movimiento")
                {
                    ToolTip = 'Fecha y hora del último movimiento registrado en la ubicación.';
                    ApplicationArea = All;
                }
            }
        }
        area(FactBoxes)
        {
            part(ContenidoFactBox; "Contenido Ubicacion Subpag")
            {
                Caption = 'Contenido';
                ApplicationArea = All;
                SubPageLink = "Cod. Almacen" = field("Cod. Almacen"),
                              "Cod. Bin" = field("Cod. Bin");
            }
            part(MovimientosFactBox; "Movs. Ubicacion FactBox")
            {
                Caption = 'Últimas entradas en la ubicación';
                ApplicationArea = All;
                SubPageLink = "Cod. Almacen" = field("Cod. Almacen"),
                              "Cod. Bin Destino" = field("Cod. Bin");
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(VerContenido)
            {
                Caption = 'Contenido';
                ToolTip = 'Muestra qué productos y lotes hay en esta ubicación.';
                ApplicationArea = All;
                Image = ItemLines;
                RunObject = page "Contenido Ubicaciones SGA";
                RunPageLink = "Cod. Almacen" = field("Cod. Almacen"),
                              "Cod. Bin" = field("Cod. Bin");
            }
            action(VerMovsEntrada)
            {
                Caption = 'Movimientos de entrada';
                ToolTip = 'Muestra lo que ha entrado en esta ubicación.';
                ApplicationArea = All;
                Image = Entries;
                RunObject = page "Movs. Ubicacion SGA";
                RunPageLink = "Cod. Almacen" = field("Cod. Almacen"),
                              "Cod. Bin Destino" = field("Cod. Bin");
            }
            action(VerMovsSalida)
            {
                Caption = 'Movimientos de salida';
                ToolTip = 'Muestra lo que ha salido de esta ubicación.';
                ApplicationArea = All;
                Image = Entries;
                RunObject = page "Movs. Ubicacion SGA";
                RunPageLink = "Cod. Almacen" = field("Cod. Almacen"),
                              "Cod. Bin Origen" = field("Cod. Bin");
            }
            action(VerZonas)
            {
                Caption = 'Zonas';
                ToolTip = 'Mantenimiento de las zonas del almacén.';
                ApplicationArea = All;
                Image = Warehouse;
                Visible = not SoloConsulta;
                RunObject = page "Zonas SGA";
            }
            action(VerMapa)
            {
                Caption = 'Mapa de almacén';
                ToolTip = 'Muestra la rejilla de la nave con el estado de ocupación de cada hueco.';
                ApplicationArea = All;
                Image = Map;
                RunObject = page "Mapa Almacen SGA";
            }
        }
        area(Processing)
        {
            action(ImprimirEtiquetas)
            {
                Caption = 'Imprimir etiquetas';
                ToolTip = 'Imprime la etiqueta de puntal de las ubicaciones seleccionadas: el código de la ubicación con su código de barras.';
                ApplicationArea = All;
                Image = PrintReport;

                trigger OnAction()
                var
                    rSeleccion: Record "Ubicacion SGA";
                begin
                    CurrPage.SetSelectionFilter(rSeleccion);
                    Report.RunModal(Report::"Etiquetas Ubicaciones SGA", true, false, rSeleccion);
                end;
            }
            action(CambiarEnBloque)
            {
                Caption = 'Cambiar en bloque';
                ToolTip = 'Cambia de una vez la capacidad, qué admiten, el tipo, la zona o la mezcla de productos de las ubicaciones seleccionadas. Filtre la lista y seleccione todas con Ctrl+A.';
                ApplicationArea = All;
                Image = ChangeBatch;
                Visible = not SoloConsulta;

                trigger OnAction()
                var
                    rSeleccion: Record "Ubicacion SGA";
                    pCambiar: Page "Cambiar Ubicaciones SGA";
                begin
                    CurrPage.SetSelectionFilter(rSeleccion);
                    pCambiar.Inicializar(rSeleccion);
                    if pCambiar.RunModal() <> Action::OK then
                        exit;
                    pCambiar.Aplicar();
                    CurrPage.Update(false);
                end;
            }
            action(LiberarReserva)
            {
                Caption = 'Liberar reserva';
                ToolTip = 'Quita la reserva de las ubicaciones seleccionadas, para que se puedan volver a proponer. Úselo si una pantalla de ubicar se ha cerrado mal y el hueco se ha quedado reservado sin usarse.';
                ApplicationArea = All;
                Image = ReleaseDoc;
                Visible = not SoloConsulta;

                trigger OnAction()
                var
                    rSeleccion: Record "Ubicacion SGA";
                    cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
                    cConfirmMgt: Codeunit "Confirm Management";
                    LiberarReservaQst: Label 'Se quitará la reserva de las ubicaciones seleccionadas. Si alguien está ubicando en ellas, se le podrán proponer a otro.\¿Desea continuar?';
                    ReservasLiberadasMsg: Label 'Se ha quitado la reserva de %1 ubicaciones.', Comment = '%1 = número de ubicaciones';
                begin
                    if not cConfirmMgt.GetResponseOrDefault(LiberarReservaQst, false) then
                        exit;

                    CurrPage.SetSelectionFilter(rSeleccion);
                    Message(ReservasLiberadasMsg, cUbicaciones.LiberarReservasSeleccion(rSeleccion));
                    CurrPage.Update(false);
                end;
            }
            action(AlternarBloqueo)
            {
                Caption = 'Bloquear / desbloquear';
                ToolTip = 'Bloquea o desbloquea la ubicación seleccionada.';
                ApplicationArea = All;
                Image = Lock;
                Visible = not SoloConsulta;

                trigger OnAction()
                begin
                    Rec.Validate(Bloqueada, not Rec.Bloqueada);
                    Rec.Modify(true);
                    CurrPage.Update(false);
                end;
            }
            action(RecalcularEstado)
            {
                Caption = 'Recalcular ocupación';
                ToolTip = 'Vuelve a calcular el estado y el porcentaje de ocupación de las ubicaciones del almacén seleccionado.';
                ApplicationArea = All;
                Image = Recalculate;
                Visible = not SoloConsulta;

                trigger OnAction()
                var
                    cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
                    actualizadas: Integer;
                    UbicacionesActualizadasMsg: Label 'Se han actualizado %1 ubicaciones.', Comment = '%1 = número';
                begin
                    actualizadas := cUbicaciones.RecalcularEstados(Rec."Cod. Almacen", '');
                    Message(UbicacionesActualizadasMsg, actualizadas);
                    CurrPage.Update(false);
                end;
            }
            action(Conciliar)
            {
                Caption = 'Conciliar con el stock';
                ToolTip = 'Compara el contenido por ubicación con las existencias de los movimientos de producto y lista las diferencias.';
                ApplicationArea = All;
                Image = Balance;
                RunObject = report "Conciliacion SGA vs Stock";
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(CambiarEnBloque_Promoted; CambiarEnBloque)
                {
                }
                actionref(ImprimirEtiquetas_Promoted; ImprimirEtiquetas) { }
                actionref(LiberarReserva_Promoted; LiberarReserva) { }
                actionref(AlternarBloqueo_Promoted; AlternarBloqueo)
                {
                }
                actionref(RecalcularEstado_Promoted; RecalcularEstado)
                {
                }
                actionref(Conciliar_Promoted; Conciliar)
                {
                }
            }
            group(Category_Navigate)
            {
                Caption = 'Ubicación';

                actionref(VerContenido_Promoted; VerContenido)
                {
                }
                actionref(VerMovsEntrada_Promoted; VerMovsEntrada)
                {
                }
                actionref(VerMovsSalida_Promoted; VerMovsSalida)
                {
                }
                actionref(VerMapa_Promoted; VerMapa)
                {
                }
            }
        }
    }

    views
    {
        view(Vacias)
        {
            Caption = 'Vacías';
            Filters = where("Estado SGA" = const(Vacia));
        }
        view(Parciales)
        {
            Caption = 'Con hueco';
            Filters = where("Estado SGA" = const(Parcial));
        }
        view(Llenas)
        {
            Caption = 'Llenas';
            Filters = where("Estado SGA" = const(Llena));
        }
        view(Bloqueadas)
        {
            Caption = 'Bloqueadas';
            Filters = where("Estado SGA" = const(Bloqueada));
        }
        view(Reservadas)
        {
            Caption = 'Reservadas';
            Filters = where("Reservada Por" = filter(<> ''));
        }
        view(Picking)
        {
            Caption = 'Picking';
            Filters = where("Tipo Ubicacion" = const(Picking));
        }
        view(Almacenamiento)
        {
            Caption = 'Almacenamiento';
            Filters = where("Tipo Ubicacion" = const(Almacenamiento));
        }
        view(SinTipo)
        {
            Caption = 'Sin tipo';
            Filters = where("Tipo Ubicacion" = const(" "));
        }
    }

    var
        EstiloFila: Text;
        EstiloPorcentaje: Text;
        SoloConsulta: Boolean;

    trigger OnAfterGetRecord()
    begin
        EstiloFila := Rec.EstiloEstado();
        EstiloPorcentaje := Rec.EstiloOcupacion();
    end;

    /// <summary>
    /// Abre la lista desde Consultas: solo se mira. Sin los botones que cambian datos ni el
    /// mantenimiento de zonas, y con la ficha en modo ver. Crear, cambiar y borrar se hace
    /// desde Configuración.
    /// </summary>
    procedure AbrirSoloConsulta()
    begin
        SoloConsulta := true;
        Editable(false);
        Run();
    end;
}
