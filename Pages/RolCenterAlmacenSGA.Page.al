namespace AntonioNadal.SGA;

using Microsoft.Warehouse.Structure;

/// <summary>
/// Page Rol Center Almacen SGA (ID 51112).
/// Rol center del almacenero, con la estructura habitual de Business Central: indicadores
/// arriba, los accesos del día a día en la navegación, y el resto agrupado en secciones,
/// tareas periódicas e informes.
///
/// Siguiendo la convención del proyecto no se define un objeto profile: el rol se asigna
/// en el entorno, igual que los demás rol centers de la app.
/// </summary>
page 51112 "Rol Center Almacen SGA"
{
    Caption = 'Almacén SGA';
    PageType = RoleCenter;

    layout
    {
        area(RoleCenter)
        {
            group(Indicadores)
            {
                part(Cues; "Cue SGA")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        // Lo que se usa cada día, a un clic desde la barra de navegación.
        area(Embedding)
        {
            action(UbicarProducto)
            {
                Caption = 'Ubicar producto';
                ToolTip = 'Dice en qué hueco dejar la mercancía y registra la ubicación cuando el operario la confirma.';
                ApplicationArea = All;
                RunObject = page "Ubicar Producto SGA";
            }
            action(PendienteUbicar)
            {
                Caption = 'Pendiente de ubicar';
                ToolTip = 'Stock que no está en ninguna ubicación, lote a lote, para ubicarlo a mano o varios a la vez.';
                ApplicationArea = All;
                RunObject = page "Pendiente Ubicar SGA";
            }
            action(UbicarEnsamblados)
            {
                Caption = 'Ubicar ensamblados';
                ToolTip = 'Reparte entre huecos lo que ha salido de los ensamblados de un día.';
                ApplicationArea = All;
                RunObject = page "Ubicar Entradas SGA";
                RunPageView = where(Origen = const(Produccion));
            }
            action(UbicarPaletsLinea)
            {
                Caption = 'Imprimir y ubicar palés';
                ToolTip = 'Saca la etiqueta de cada palé que sale de la línea y lo deja ubicado.';
                ApplicationArea = All;
                RunObject = page "Ubicar Palets Linea SGA";
            }
            action(UbicarRecepciones)
            {
                Caption = 'Ubicar recepciones';
                ToolTip = 'Reparte entre huecos lo que ha llegado en las recepciones de compra de un día.';
                ApplicationArea = All;
                RunObject = page "Ubicar Entradas SGA";
                RunPageView = where(Origen = const(Compra));
            }
            action(OrdenesPicking)
            {
                Caption = 'Órdenes de picking';
                ToolTip = 'Qué hay que preparar, quién lo prepara y cuánto le queda.';
                ApplicationArea = All;
                RunObject = page "Ordenes Picking SGA";
            }
            action(AsignarPicking)
            {
                Caption = 'Asignar órdenes de picking';
                ToolTip = 'Reparte las órdenes de picking entre los preparadores y fija su prioridad.';
                ApplicationArea = All;
                RunObject = page "Asignar Ordenes Picking SGA";
            }
            action(DondeEsta)
            {
                Caption = '¿Dónde está el producto?';
                ToolTip = 'Localiza un producto y dice a qué ubicación hay que ir a recogerlo.';
                ApplicationArea = All;
                RunObject = page "Consulta Ubic. Producto SGA";
            }
            action(Contenido)
            {
                Caption = 'Contenido de ubicaciones';
                ToolTip = 'Qué producto y lote hay en cada ubicación. Desde aquí se traslada, se bloquea y se recuenta.';
                ApplicationArea = All;
                RunObject = page "Contenido Ubicaciones SGA";
            }
            action(Ubicaciones)
            {
                Caption = 'Ubicaciones SGA';
                ToolTip = 'Ubicaciones del almacén, con su estado y su ocupación.';
                ApplicationArea = All;
                RunObject = page "Ubicaciones SGA";
            }
        }

        area(Sections)
        {
            group(Almacen)
            {
                Caption = 'Almacén';

                action(MapaAlmacen)
                {
                    Caption = 'Mapa de almacén';
                    ToolTip = 'Rejilla de la nave con el estado de cada hueco. Filtre por estantería para verla de frente.';
                    ApplicationArea = All;
                    Image = Map;
                    RunObject = page "Mapa Almacen SGA";
                }
                action(Mapa3D)
                {
                    Caption = 'Mapa 3D de almacén';
                    ToolTip = 'El almacén en volumen, con cada ubicación coloreada según su ocupación.';
                    ApplicationArea = All;
                    Image = Map;
                    RunObject = page "Mapa 3D Almacen SGA";
                }
                action(UbicacionesEstandar)
                {
                    Caption = 'Ubicaciones del almacén';
                    ToolTip = 'Ubicaciones estándar (bins) sobre las que SGA añade sus datos de gestión.';
                    ApplicationArea = All;
                    Image = BinContent;
                    RunObject = page "Bin List";
                }
            }
            group(Control)
            {
                Caption = 'Control';

                action(Movimientos)
                {
                    Caption = 'Movimientos de ubicación';
                    ToolTip = 'Diario de entradas, salidas y traslados: quién movió qué, cuándo y desde dónde.';
                    ApplicationArea = All;
                    Image = Journals;
                    RunObject = page "Movs. Ubicacion SGA";
                }
                action(Conciliacion)
                {
                    Caption = 'Conciliación SGA vs stock';
                    ToolTip = 'Diferencias entre el stock de BC y el contenido de ubicaciones.';
                    ApplicationArea = All;
                    Image = Balance;
                    RunObject = page "Conciliacion SGA";
                }
                action(AnalisisABC)
                {
                    Caption = 'Análisis ABC';
                    ToolTip = 'Clasifica los productos por los palés que salen y dice cuántos palés están en un hueco de su clase.';
                    ApplicationArea = All;
                    Image = Statistics;
                    RunObject = page "Analisis ABC SGA";
                }
            }
            group(Configuracion)
            {
                Caption = 'Configuración';
                Image = Setup;

                action(ConfiguracionSGA)
                {
                    Caption = 'Configuración SGA';
                    ToolTip = 'Almacén por defecto, ubicaciones de cada flujo, unidades de medida, estrategias y controles.';
                    ApplicationArea = All;
                    Image = Setup;
                    RunObject = page "Config. SGA";
                }
                action(Zonas)
                {
                    Caption = 'Zonas';
                    ToolTip = 'Agrupa las ubicaciones en zonas y fija sus prioridades de ubicación y de picking.';
                    ApplicationArea = All;
                    Image = Warehouse;
                    RunObject = page "Zonas SGA";
                }
            }
        }

        area(Processing)
        {
            group(TareasPeriodicas)
            {
                Caption = 'Tareas periódicas';
                Image = Journals;

                action(Conciliar)
                {
                    Caption = 'Conciliar con el stock';
                    ToolTip = 'Compara el contenido por ubicación con las existencias de los movimientos de producto.';
                    ApplicationArea = All;
                    Image = Balance;
                    RunObject = report "Conciliacion SGA vs Stock";
                }
                action(SincronizarUbicaciones)
                {
                    Caption = 'Sincronizar ubicaciones';
                    ToolTip = 'Da de alta en SGA las ubicaciones que todavía no tienen datos de gestión.';
                    ApplicationArea = All;
                    Image = Refresh;
                    RunObject = report "Sincronizar Ubicaciones SGA";
                }
            }
            group(PuestaEnMarcha)
            {
                Caption = 'Puesta en marcha';
                Image = Setup;

                action(GenerarUbicaciones)
                {
                    Caption = 'Generar ubicaciones';
                    ToolTip = 'Crea de golpe todas las ubicaciones de un rango de estanterías, columnas y alturas.';
                    ApplicationArea = All;
                    Image = CreateForm;
                    RunObject = report "Generar Ubicaciones SGA";
                }
                action(CargaInicial)
                {
                    Caption = 'Carga inicial de contenido';
                    ToolTip = 'Reparte el stock que ya existe en BC entre las ubicaciones. Conviene lanzarlo primero en simulación.';
                    ApplicationArea = All;
                    Image = Import;
                    RunObject = report "Carga Inicial Contenido SGA";
                }
            }
        }

        area(Reporting)
        {
            action(InventarioPorUbicacion)
            {
                Caption = 'Inventario por ubicación';
                ToolTip = 'Exporta a Excel el contenido de las ubicaciones.';
                ApplicationArea = All;
                Image = "Report";
                RunObject = report "Inventario por Ubicacion SGA";
            }
            action(OcupacionUbicaciones)
            {
                Caption = 'Ocupación de ubicaciones';
                ToolTip = 'Exporta a Excel el estado y la ocupación de cada ubicación.';
                ApplicationArea = All;
                Image = "Report";
                RunObject = report "Ocupacion Ubicaciones SGA";
            }
        }
    }
}
