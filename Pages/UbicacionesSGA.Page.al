namespace AntonioNadal.SGA;

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
    // Como en las listas estándar: solo consulta, y se edita en la ficha.
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
                    ToolTip = 'Descripción libre de la ubicación.';
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
                    ToolTip = 'Porcentaje de la capacidad declarada que está ocupado.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
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
                    ToolTip = 'Número de combinaciones producto-lote distintas que hay en la ubicación.';
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
                    ToolTip = 'Razón del bloqueo.';
                    ApplicationArea = All;
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
                field("Digito Colocado"; Rec."Digito Colocado")
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
                ToolTip = 'Imprime la etiqueta (70 × 35 mm) de las ubicaciones seleccionadas: código, código de barras y dígito de control.';
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
            action(RegenerarDigitos)
            {
                Caption = 'Regenerar dígitos de control';
                ToolTip = 'Da un dígito de control nuevo a las ubicaciones seleccionadas. Hay que reimprimir sus etiquetas: las viejas dejarán de valer.';
                ApplicationArea = All;
                Image = Refresh;

                trigger OnAction()
                var
                    rSeleccion: Record "Ubicacion SGA";
                    cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
                    hechas: Integer;
                    RegenerarDigitosQst: Label 'Se va a cambiar el dígito de control de %1 ubicaciones. Sus etiquetas actuales dejarán de valer y habrá que reimprimirlas. ¿Continuar?', Comment = '%1 = número';
                    DigitosRegeneradosMsg: Label 'Se han regenerado %1 dígitos de control. Reimprima sus etiquetas.', Comment = '%1 = número';
                begin
                    CurrPage.SetSelectionFilter(rSeleccion);
                    if not Confirm(RegenerarDigitosQst, false, rSeleccion.Count()) then
                        exit;

                    hechas := cUbicaciones.RegenerarDigitos(rSeleccion);
                    CurrPage.Update(false);
                    Message(DigitosRegeneradosMsg, hechas);
                end;
            }
            action(DigitoColocado)
            {
                Caption = 'Dígito colocado';
                ToolTip = 'Marca o desmarca las ubicaciones seleccionadas como que ya tienen puesto su dígito de control. Desde que se marcan, al recoger de ellas se pide el dígito (si la configuración lo exige). Márquelas después de pegar las etiquetas.';
                ApplicationArea = All;
                Image = Approve;

                trigger OnAction()
                var
                    rSeleccion: Record "Ubicacion SGA";
                    cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
                    opcion: Integer;
                    OpcionesTxt: Label 'Ya tienen el dígito puesto,Todavía no lo tienen';
                    PreguntaTxt: Label '%1 ubicaciones seleccionadas:', Comment = '%1 = número';
                    MarcadasMsg: Label 'Se han actualizado %1 ubicaciones.', Comment = '%1 = número';
                begin
                    CurrPage.SetSelectionFilter(rSeleccion);
                    opcion := StrMenu(OpcionesTxt, 1, StrSubstNo(PreguntaTxt, rSeleccion.Count()));
                    if opcion = 0 then
                        exit;

                    Message(MarcadasMsg, cUbicaciones.MarcarDigitoColocado(rSeleccion, opcion = 1));
                    CurrPage.Update(false);
                end;
            }
            action(CambiarEnBloque)
            {
                Caption = 'Cambiar en bloque';
                ToolTip = 'Cambia de una vez la capacidad, qué admiten, el tipo, la zona o la mezcla de productos de las ubicaciones seleccionadas. Filtre la lista y seleccione todas con Ctrl+A.';
                ApplicationArea = All;
                Image = ChangeBatch;

                trigger OnAction()
                var
                    rSeleccion: Record "Ubicacion SGA";
                    pCambiar: Page "Cambiar Ubicaciones SGA";
                    hechas: Integer;
                    omitidas: Integer;
                    ejemplo: Text;
                    UbicacionesCambiadasMsg: Label 'Se han cambiado %1 ubicaciones.', Comment = '%1 = número';
                    UbicacionesCambiadasOmitidasMsg: Label 'Se han cambiado %1 ubicaciones.\%2 no se han cambiado porque tienen contenido (%3…). Su configuración solo se cambia cuando están vacías.', Comment = '%1 = cambiadas, %2 = omitidas, %3 = primeras ubicaciones omitidas';
                begin
                    CurrPage.SetSelectionFilter(rSeleccion);
                    pCambiar.Inicializar(rSeleccion);
                    if pCambiar.RunModal() <> Action::OK then
                        exit;

                    hechas := pCambiar.Aplicar();
                    CurrPage.Update(false);
                    omitidas := pCambiar.UbicacionesOmitidas(ejemplo);
                    if omitidas = 0 then
                        Message(UbicacionesCambiadasMsg, hechas)
                    else
                        Message(UbicacionesCambiadasOmitidasMsg, hechas, omitidas, ejemplo);
                end;
            }
            action(AlternarBloqueo)
            {
                Caption = 'Bloquear / desbloquear';
                ToolTip = 'Bloquea o desbloquea la ubicación seleccionada.';
                ApplicationArea = All;
                Image = Lock;

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

                trigger OnAction()
                var
                    cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
                    actualizadas: Integer;
                    UbicacionesActualizadasMsg: Label 'Se han actualizado %1 ubicaciones.', Comment = '%1 = número';
                begin
                    actualizadas := cUbicaciones.RecalcularEstados(Rec."Cod. Almacen");
                    Message(UbicacionesActualizadasMsg, actualizadas);
                    CurrPage.Update(false);
                end;
            }
            action(SincronizarTopologia)
            {
                Caption = 'Sincronizar ubicaciones';
                ToolTip = 'Da de alta en SGA las ubicaciones de la topología que todavía no tienen datos de gestión de almacén.';
                ApplicationArea = All;
                Image = Refresh;
                RunObject = report "Sincronizar Ubicaciones SGA";
            }
            action(GenerarUbicaciones)
            {
                Caption = 'Generar ubicaciones';
                ToolTip = 'Crea de golpe todas las ubicaciones de un rango de estanterías, columnas y alturas.';
                ApplicationArea = All;
                Image = CreateForm;
                RunObject = report "Generar Ubicaciones SGA";
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
                actionref(DigitoColocado_Promoted; DigitoColocado) { }
                actionref(AlternarBloqueo_Promoted; AlternarBloqueo)
                {
                }
                actionref(RecalcularEstado_Promoted; RecalcularEstado)
                {
                }
                actionref(SincronizarTopologia_Promoted; SincronizarTopologia)
                {
                }
                actionref(GenerarUbicaciones_Promoted; GenerarUbicaciones)
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
        view(SinDigitoColocado)
        {
            Caption = 'Sin dígito colocado';
            Filters = where("Digito Colocado" = const(false), "Tipo Ubicacion" = filter(<> " "));
        }
    }

    var
        EstiloFila: Text;

    trigger OnAfterGetRecord()
    begin
        EstiloFila := Rec.EstiloEstado();
    end;
}
