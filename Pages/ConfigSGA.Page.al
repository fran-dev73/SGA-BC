namespace AntonioNadal.SGA;

/// <summary>
/// Page Config. SGA (ID 51106).
/// Configuración del módulo: ubicaciones por defecto de cada flujo, estrategias de los
/// motores y control de capacidad.
/// </summary>
page 51106 "Config. SGA"
{
    Caption = 'Configuración SGA';
    PageType = Card;
    SourceTable = "Config. SGA";
    UsageCategory = Administration;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Almacen por Defecto"; Rec."Almacen por Defecto")
                {
                    ToolTip = 'Almacén que se propone en las consultas y el mapa, y sobre el que se resuelven las ubicaciones por defecto de esta configuración.';
                    ApplicationArea = All;
                }
                field("Zona por Defecto"; Rec."Zona por Defecto")
                {
                    ToolTip = 'Zona que se propone en las consultas y el mapa, y sobre la que se resuelven las ubicaciones por defecto de esta configuración.';
                    ApplicationArea = All;
                }
                field("Crear Ubicacion SGA Auto"; Rec."Crear Ubicacion SGA Auto")
                {
                    ToolTip = 'Crea la fila de datos SGA la primera vez que se usa una ubicación de la topología. Si se desactiva, la ubicación debe estar dada de alta previamente.';
                    ApplicationArea = All;
                }
            }
            group(UbicacionesFlujo)
            {
                Caption = 'Ubicaciones por flujo';

                field("Ubic. Recepcion Compras"; Rec."Ubic. Recepcion Compras")
                {
                    ToolTip = 'Ubicación de muelle donde queda la mercancía de compra hasta que se ubica.';
                    ApplicationArea = All;
                }
                field("Ubic. Entrada Produccion"; Rec."Ubic. Entrada Produccion")
                {
                    ToolTip = 'Ubicación donde se deposita el producto terminado de fabricación propia hasta que se ubica.';
                    ApplicationArea = All;
                }
                field("Ubic. Expedicion"; Rec."Ubic. Expedicion")
                {
                    ToolTip = 'Ubicación de muelle de salida donde se concentra lo recogido para servir.';
                    ApplicationArea = All;
                }
                field("Ubic. Desbordamiento"; Rec."Ubic. Desbordamiento")
                {
                    ToolTip = 'Ubicación donde el motor deja la mercancía cuando no encuentra hueco válido.';
                    ApplicationArea = All;
                }
                field("Ubic. Ajustes"; Rec."Ubic. Ajustes")
                {
                    ToolTip = 'Ubicación contrapartida de los ajustes y descuadres detectados en la conciliación.';
                    ApplicationArea = All;
                }
            }
            group(Estrategias)
            {
                Caption = 'Estrategias';

                field("Estrategia Ubicacion"; Rec."Estrategia Ubicacion")
                {
                    ToolTip = 'Política con la que se decide dónde colocar la mercancía que entra.';
                    ApplicationArea = All;
                }
                field("Estrategia Ubic. Ensamblados"; Rec."Estrategia Ubic. Ensamblados")
                {
                    ToolTip = 'Política para lo que sale de un ensamblado. Por defecto solo huecos vacíos, para que lo producido no se mezcle. Cámbielo a cualquier otra si prefiere consolidar.';
                    ApplicationArea = All;
                }
                field("Estrategia Ubic. Compras"; Rec."Estrategia Ubic. Compras")
                {
                    ToolTip = 'Política para lo que llega en una recepción de compra. Por defecto la estándar: la casa del producto, si no consolidar y si no el primer hueco libre.';
                    ApplicationArea = All;
                }
                field("Cajas Minimas Hueco Pale"; Rec."Cajas Minimas Hueco Pale")
                {
                    ApplicationArea = All;
                }
                field("Reubicar Pale A por ABC"; Rec."Reubicar Pale A por ABC")
                {
                    ApplicationArea = All;
                }
                field("Estrategia Picking"; Rec."Estrategia Picking")
                {
                    ToolTip = 'Política con la que el motor decide de dónde sacar la mercancía. La consume el motor de la Fase 2.';
                    ApplicationArea = All;
                }
                field("Tipo Ubic. Nuevas"; Rec."Tipo Ubic. Nuevas")
                {
                    ToolTip = 'Qué admiten las ubicaciones que se crean con "Generar ubicaciones": Palé, Caja o Unidad.';
                    ApplicationArea = All;
                }
                field("Dias Aviso Caducidad"; Rec."Dias Aviso Caducidad")
                {
                    ToolTip = 'Días de antelación con los que se avisa de un lote próximo a caducar.';
                    ApplicationArea = All;
                }
            }
            group(AnalisisABC)
            {
                Caption = 'Análisis ABC';
                InstructionalText = 'Los productos se ordenan de más a menos palés salidos y se van sumando. Los cortes son porcentajes acumulados: A va del 0 % al corte de la A, B del corte de la A al de la B, y C del corte de la B al 100 %.';

                field("Dias Analisis ABC"; Rec."Dias Analisis ABC")
                {
                    ApplicationArea = All;
                }
                field("Corte ABC Clase A"; Rec."Corte ABC Clase A")
                {
                    ApplicationArea = All;
                }
                field("Corte ABC Clase B"; Rec."Corte ABC Clase B")
                {
                    ApplicationArea = All;
                }
                field(RepartoABC; Rec.RepartoABC())
                {
                    Caption = 'Reparto de los palés salidos';
                    ToolTip = 'Qué parte de los palés salidos mueve cada clase con los cortes de arriba.';
                    ApplicationArea = All;
                    Editable = false;
                }
            }
            group(Controles)
            {
                Caption = 'Controles';

                field("Control Capacidad"; Rec."Control Capacidad")
                {
                    ToolTip = 'Qué hacer cuando una entrada supera la capacidad de una ubicación que tiene "Control capacidad" = Según configuración: bloquearla, o avisar y dejar seguir si se confirma. Cada ubicación puede llevar el suyo. La capacidad se controla siempre.';
                    ApplicationArea = All;
                    ValuesAllowed = Avisar, Bloquear;
                }
                field("Permitir Cantidad Negativa"; Rec."Permitir Cantidad Negativa")
                {
                    ToolTip = 'Si está activo, se admite sacar de una ubicación más de lo que consta. Solo para arranques con datos incompletos.';
                    ApplicationArea = All;
                }
                field("Exigir Confirmar Ubicacion"; Rec."Exigir Confirmar Ubicacion")
                {
                    ToolTip = 'Obliga al operario a escanear la ubicación para cerrar la tarea. Lo consumen las páginas de PDA de la Fase 3.';
                    ApplicationArea = All;
                }
                field("Permitir Desvio Ubicacion"; Rec."Permitir Desvio Ubicacion")
                {
                    ToolTip = 'Permite al operario dejar o coger la mercancía en una ubicación distinta de la sugerida, quedando registrado el desvío.';
                    ApplicationArea = All;
                }
                field("Exigir Digito Control"; Rec."Exigir Digito Control")
                {
                    ToolTip = 'Si está activo, al confirmar cada parada de picking el preparador tiene que teclear el dígito de control impreso en la etiqueta del hueco del que recoge. Certifica que está delante del hueco. Requiere haber impreso las etiquetas de ubicación.';
                    ApplicationArea = All;
                }
                field("Exigir Asignacion Picking"; Rec."Exigir Asignacion Picking")
                {
                    ToolTip = 'Si está activo, las órdenes de picking nacen pendientes de asignar y solo las puede preparar el preparador al que un responsable se las asigne en "Asignar órdenes de picking". Si no, cada preparador coge la siguiente sin asignar.';
                    ApplicationArea = All;
                }
            }
            group(Numeracion)
            {
                Caption = 'Numeración';

                field("Nos. Orden SGA"; Rec."Nos. Orden SGA")
                {
                    ToolTip = 'Serie numérica de las órdenes de trabajo de almacén. La consume la gestión de órdenes de la Fase 2.';
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(GenerarUbicaciones)
            {
                Caption = 'Generar ubicaciones';
                ToolTip = 'Crea la estructura del almacén: todas las ubicaciones a partir de los rangos de pasillo, estantería y altura.';
                ApplicationArea = All;
                Image = CreateForm;
                RunObject = report "Generar Ubicaciones SGA";
            }
            action(SincronizarTopologia)
            {
                Caption = 'Sincronizar ubicaciones';
                ToolTip = 'Da de alta en SGA las ubicaciones de la topología que todavía no tienen datos de gestión de almacén.';
                ApplicationArea = All;
                Image = Refresh;
                RunObject = report "Sincronizar Ubicaciones SGA";
            }
            action(CargaInicial)
            {
                Caption = 'Carga inicial de contenido';
                ToolTip = 'Reparte el stock actual en las ubicaciones para arrancar el módulo.';
                ApplicationArea = All;
                Image = Import;
                RunObject = report "Carga Inicial Contenido SGA";
            }
        }
        area(Navigation)
        {
            action(VerUbicaciones)
            {
                Caption = 'Ubicaciones SGA';
                ToolTip = 'Abre la lista de ubicaciones.';
                ApplicationArea = All;
                Image = BinContent;
                RunObject = page "Ubicaciones SGA";
            }
            action(VerZonas)
            {
                Caption = 'Zonas';
                ToolTip = 'Abre el mantenimiento de zonas.';
                ApplicationArea = All;
                Image = Warehouse;
                RunObject = page "Zonas SGA";
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(GenerarUbicaciones_Promoted; GenerarUbicaciones)
                {
                }
                actionref(SincronizarTopologia_Promoted; SincronizarTopologia)
                {
                }
                actionref(CargaInicial_Promoted; CargaInicial)
                {
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.ObtenerConfig();
    end;
}
