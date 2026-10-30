namespace AntonioNadal.SGA;

using Microsoft.Sales.RoleCenters;
using Microsoft.Warehouse.Structure;

/// <summary>
/// PageExtension Order Processor SGA (ID 51103) extends Page "Order Processor Role Center".
/// Añade al rol de procesador de pedidos el menú de gestión de ubicaciones, agrupado como
/// agrupa el estándar de almacén: primero lo que se hace a diario, luego las consultas y por
/// último la configuración.
///
/// Se hace en una extensión propia dentro de SGA, en lugar de tocar
/// Pag-Ext50110 "Order Procesor", para que el módulo siga siendo autocontenido.
/// </summary>
pageextension 51103 "Order Processor SGA" extends "Order Processor Role Center"
{
    actions
    {
        addlast(sections)
        {
            group(SGATareas)
            {
                Caption = 'Almacén SGA';

                action(UbicarProductoSGA)
                {
                    Caption = 'Ubicar producto';
                    ToolTip = 'Dice en qué hueco dejar la mercancía y registra la ubicación cuando el operario la confirma.';
                    ApplicationArea = All;
                    Image = CreateWarehousePick;
                    RunObject = page "Ubicar Producto SGA";
                }
                action(PendienteUbicarSGA)
                {
                    Caption = 'Pendiente de ubicar';
                    ToolTip = 'Stock que no está en ninguna ubicación, lote a lote, para ubicarlo a mano o varios a la vez.';
                    ApplicationArea = All;
                    Image = PutawayLines;
                    RunObject = page "Pendiente Ubicar SGA";
                }
                action(UbicarEnsambladosSGA)
                {
                    Caption = 'Ubicar ensamblados';
                    ToolTip = 'Reparte entre huecos lo que ha salido de los ensamblados de un día.';
                    ApplicationArea = All;
                    Image = Warehouse;
                    RunObject = page "Ubicar Entradas SGA";
                    RunPageView = where(Origen = const(Produccion));
                }
                action(UbicarPaletsLineaSGA)
                {
                    Caption = 'Imprimir y ubicar palés';
                    ToolTip = 'Saca la etiqueta de cada palé que sale de la línea y lo deja ubicado.';
                    ApplicationArea = All;
                    Image = PutawayLines;
                    RunObject = page "Ubicar Palets Linea SGA";
                }
                action(UbicarRecepcionesSGA)
                {
                    Caption = 'Ubicar recepciones';
                    ToolTip = 'Reparte entre huecos lo que ha llegado en las recepciones de compra de un día.';
                    ApplicationArea = All;
                    Image = Warehouse;
                    RunObject = page "Ubicar Entradas SGA";
                    RunPageView = where(Origen = const(Compra));
                }
                action(OrdenesPickingSGA)
                {
                    Caption = 'Órdenes de picking';
                    ToolTip = 'Qué documentos hay que preparar, quién los prepara y cuánto les queda.';
                    ApplicationArea = All;
                    Image = Warehouse;
                    RunObject = page "Ordenes Picking SGA";
                }
                action(AsignarPickingSGA)
                {
                    Caption = 'Asignar órdenes de picking';
                    ToolTip = 'Reparte las órdenes de picking entre los preparadores y fija su prioridad.';
                    ApplicationArea = All;
                    Image = Warehouse;
                    RunObject = page "Asignar Ordenes Picking SGA";
                }
                action(DondeEstaSGA)
                {
                    Caption = '¿Dónde está el producto?';
                    ToolTip = 'Localiza un producto y dice a qué ubicación hay que ir a recogerlo.';
                    ApplicationArea = All;
                    Image = Find;
                    RunObject = page "Consulta Ubic. Producto SGA";
                }
            }
            group(SGAConsultas)
            {
                Caption = 'Almacén SGA - Consultas';

                action(UbicacionesSGA)
                {
                    Caption = 'Ubicaciones SGA';
                    ToolTip = 'Ubicaciones del almacén, con su estado y su ocupación.';
                    ApplicationArea = All;
                    Image = BinContent;
                    RunObject = page "Ubicaciones SGA";
                }
                action(ContenidoUbicacionesSGA)
                {
                    Caption = 'Contenido de ubicaciones';
                    ToolTip = 'Qué producto, variante y lote hay en cada hueco, y en qué cantidad.';
                    ApplicationArea = All;
                    Image = ItemLines;
                    RunObject = page "Contenido Ubicaciones SGA";
                }
                action(MapaAlmacenSGA)
                {
                    Caption = 'Mapa de almacén';
                    ToolTip = 'Rejilla de la nave con el estado de ocupación de cada hueco.';
                    ApplicationArea = All;
                    Image = Map;
                    RunObject = page "Mapa Almacen SGA";
                }
                action(Mapa3DAlmacenSGA)
                {
                    Caption = 'Mapa 3D de almacén';
                    ToolTip = 'El almacén en volumen, con cada ubicación coloreada según su ocupación.';
                    ApplicationArea = All;
                    Image = Map;
                    RunObject = page "Mapa 3D Almacen SGA";
                }
                action(MovsUbicacionSGA)
                {
                    Caption = 'Movimientos de ubicación';
                    ToolTip = 'Diario de entradas, salidas y traslados: quién movió qué, cuándo y desde dónde.';
                    ApplicationArea = All;
                    Image = Journals;
                    RunObject = page "Movs. Ubicacion SGA";
                }
                action(ConciliacionSGA)
                {
                    Caption = 'Conciliación con el stock';
                    ToolTip = 'Diferencias entre el stock de BC y el contenido de las ubicaciones.';
                    ApplicationArea = All;
                    Image = Balance;
                    RunObject = page "Conciliacion SGA";
                }
                action(AnalisisABCSGA)
                {
                    Caption = 'Análisis ABC';
                    ToolTip = 'Clasifica los productos por los palés que salen y dice cuántos palés están en un hueco de su clase.';
                    ApplicationArea = All;
                    Image = Statistics;
                    RunObject = page "Analisis ABC SGA";
                }
            }
            group(SGAConfiguracion)
            {
                Caption = 'Almacén SGA - Configuración';
                Image = Setup;

                action(ConfigSGA)
                {
                    Caption = 'Configuración SGA';
                    ToolTip = 'Almacén por defecto, ubicaciones de cada flujo, estrategias y control de capacidad.';
                    ApplicationArea = All;
                    Image = Setup;
                    RunObject = page "Config. SGA";
                }
                action(ZonasSGA)
                {
                    Caption = 'Zonas';
                    ToolTip = 'Agrupa las ubicaciones en zonas y fija sus prioridades de ubicación y de picking.';
                    ApplicationArea = All;
                    Image = Warehouse;
                    RunObject = page "Zonas SGA";
                }
                action(UbicacionesEstandar)
                {
                    Caption = 'Ubicaciones del almacén';
                    ToolTip = 'Ubicaciones estándar (bins) sobre las que SGA añade sus datos de gestión.';
                    ApplicationArea = All;
                    Image = BinContent;
                    RunObject = page "Bin List";
                }
                action(GenerarUbicacionesSGA)
                {
                    Caption = 'Generar ubicaciones';
                    ToolTip = 'Crea de golpe todas las ubicaciones de un rango de estanterías, columnas y alturas.';
                    ApplicationArea = All;
                    Image = CreateForm;
                    RunObject = report "Generar Ubicaciones SGA";
                }
                action(SincronizarUbicacionesSGA)
                {
                    Caption = 'Sincronizar ubicaciones';
                    ToolTip = 'Da de alta en SGA las ubicaciones que aún no tienen datos de gestión.';
                    ApplicationArea = All;
                    Image = Refresh;
                    RunObject = report "Sincronizar Ubicaciones SGA";
                }
                action(CargaInicialSGA)
                {
                    Caption = 'Carga inicial de contenido';
                    ToolTip = 'Reparte el stock que ya existe en BC entre las ubicaciones.';
                    ApplicationArea = All;
                    Image = Import;
                    RunObject = report "Carga Inicial Contenido SGA";
                }
            }
        }
    }
}
