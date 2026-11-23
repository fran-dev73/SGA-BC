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
                    ApplicationArea = All;
                }
                field("Zona por Defecto"; Rec."Zona por Defecto")
                {
                    ApplicationArea = All;
                }
                field("Fecha Inicio SGA"; Rec."Fecha Inicio SGA")
                {
                    ApplicationArea = All;
                }
            }
            group(UbicacionesFlujo)
            {
                Caption = 'Ubicaciones por flujo';

                field("Ubic. Ajustes"; Rec."Ubic. Ajustes")
                {
                    ApplicationArea = All;
                }
                field("Playa por Defecto"; Rec."Playa por Defecto")
                {
                    ApplicationArea = All;
                }
            }
            group(Estrategias)
            {
                Caption = 'Estrategias';

                field("Estrategia Ubicacion"; Rec."Estrategia Ubicacion")
                {
                    ApplicationArea = All;
                }
                field("Estrategia Ubic. Ensamblados"; Rec."Estrategia Ubic. Ensamblados")
                {
                    ApplicationArea = All;
                }
                field("Estrategia Ubic. Compras"; Rec."Estrategia Ubic. Compras")
                {
                    ApplicationArea = All;
                }
                field("Estrategia Picking"; Rec."Estrategia Picking")
                {
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
                    ApplicationArea = All;
                }
                field("Permitir Cantidad Negativa"; Rec."Permitir Cantidad Negativa")
                {
                    ApplicationArea = All;
                }
                field("Exigir Confirmar Ubicacion"; Rec."Exigir Confirmar Ubicacion")
                {
                    ApplicationArea = All;
                }
                field("Permitir Desvio Ubicacion"; Rec."Permitir Desvio Ubicacion")
                {
                    ApplicationArea = All;
                }
                field("Exigir Asignacion Picking"; Rec."Exigir Asignacion Picking")
                {
                    ApplicationArea = All;
                }
            }
            group(Numeracion)
            {
                Caption = 'Numeración';

                field("Nos. Orden SGA"; Rec."Nos. Orden SGA")
                {
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
                ToolTip = 'Crea las ubicaciones que falten en un rango de pasillos, estanterías y alturas, con su zona, tipo y capacidad. Las que ya existen no se tocan.';
                ApplicationArea = All;
                Image = CreateForm;
                RunObject = report "Generar Ubicaciones SGA";
            }
            action(RecalcularUbicaciones)
            {
                Caption = 'Recalcular ubicaciones';
                ToolTip = 'Recalcula el estado y la ocupación de las ubicaciones y, si se marca, reconstruye el contenido desde los movimientos.';
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
                actionref(RecalcularUbicaciones_Promoted; RecalcularUbicaciones)
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
