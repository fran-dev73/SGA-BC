namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.Sales.RoleCenters;
using Microsoft.Warehouse.Structure;

/// <summary>
/// PageExtension Order Processor SGA (ID 51103) extends Page "Order Processor Role Center".
/// Añade al rol de procesador de pedidos el menú de gestión de ubicaciones, agrupado como
/// agrupa el estándar de almacén: primero lo que se hace a diario, luego ventas y compras,
/// las consultas, los informes y por último la configuración. Son los mismos menús que los del
/// rol "Almacén SGA" (Pag51112): si se toca uno, se toca el otro.
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
                action(ParadasRetenidasSGA)
                {
                    Caption = 'Líneas retenidas';
                    ToolTip = 'Líneas de picking que el preparador ha saltado dos veces: qué impide recogerlas y buscar el producto en otra ubicación.';
                    ApplicationArea = All;
                    Image = Warehouse;
                    RunObject = page "Lineas Picking SGA";
                    RunPageView = where(Retenida = const(true), Estado = filter(Pendiente | Parcial));
                }
                action(ReubicacionesSGA)
                {
                    Caption = 'Reposiciones';
                    ToolTip = 'Lo que hay que llevar de almacenamiento a picking: planificarlo, verlo y prepararlo.';
                    ApplicationArea = All;
                    Image = Warehouse;
                    RunObject = page "Reposiciones SGA";
                }
                action(ContenidoUbicacionesSGA)
                {
                    Caption = 'Contenido de ubicaciones';
                    ToolTip = 'Qué producto y lote hay en cada ubicación. Desde aquí se traslada (también a otra zona), se bloquea, se recuenta y se quita de la ubicación.';
                    ApplicationArea = All;
                    Image = ItemLines;
                    RunObject = page "Contenido Ubicaciones SGA";
                }
            }
            group(SGAVentasCompras)
            {
                Caption = 'Almacén SGA - Ventas y compras';

                action(ProductosSGA)
                {
                    Caption = 'Productos';
                    ToolTip = 'Fichas de los productos: unidades de medida, palé por defecto y existencias.';
                    ApplicationArea = All;
                    Image = Item;
                    RunObject = page "Item List";
                }
                action(PedidosVentaSGA)
                {
                    Caption = 'Pedidos de venta';
                    ToolTip = 'Pedidos de venta. Las órdenes de picking salen de un pedido lanzado con Enviar a SGA.';
                    ApplicationArea = All;
                    Image = Document;
                    RunObject = page "Sales Order List";
                }
                action(AlbaranesVentaSGA)
                {
                    Caption = 'Histórico de albaranes de venta';
                    ToolTip = 'Envíos de venta ya registrados.';
                    ApplicationArea = All;
                    Image = PostedShipment;
                    RunObject = page "Posted Sales Shipments";
                }
                action(PedidosCompraSGA)
                {
                    Caption = 'Pedidos de compra';
                    ToolTip = 'Pedidos de compra pendientes de recibir.';
                    ApplicationArea = All;
                    Image = Document;
                    RunObject = page "Purchase Order List";
                }
                action(AlbaranesCompraSGA)
                {
                    Caption = 'Histórico de albaranes de compra';
                    ToolTip = 'Recepciones de compra ya registradas, de las que sale lo que hay que ubicar.';
                    ApplicationArea = All;
                    Image = PostedReceipt;
                    RunObject = page "Posted Purchase Receipts";
                }
            }
            group(SGAConsultas)
            {
                Caption = 'Almacén SGA - Consultas';

                action(UbicacionesSGA)
                {
                    Caption = 'Ubicaciones SGA';
                    ToolTip = 'Ubicaciones del almacén, con su estado y su ocupación. Solo consulta: se crean, cambian y eliminan desde Configuración.';
                    ApplicationArea = All;
                    Image = BinContent;
                    RunObject = codeunit "Consulta Ubicaciones SGA";
                }
                action(DondeEstaSGA)
                {
                    Caption = '¿Dónde está el producto?';
                    ToolTip = 'Localiza un producto, un lote o un palé (leyendo su SSCC) y dice en qué ubicaciones está. Solo consulta.';
                    ApplicationArea = All;
                    Image = Find;
                    RunObject = page "Consulta Ubic. Producto SGA";
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
                    ToolTip = 'El almacén en volumen, en planta o de frente, por zonas, con cada ubicación coloreada según su estado.';
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
            group(SGAInformes)
            {
                Caption = 'Almacén SGA - Informes';

                action(ConciliarSGA)
                {
                    Caption = 'Conciliar con el stock';
                    ToolTip = 'Compara el contenido por ubicación con las existencias de los movimientos de producto.';
                    ApplicationArea = All;
                    Image = Balance;
                    RunObject = report "Conciliacion SGA vs Stock";
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
                    ToolTip = 'Zonas del almacén: agrupan las ubicaciones, se bloquean enteras y marcan las playas.';
                    ApplicationArea = All;
                    Image = Warehouse;
                    RunObject = page "Zonas SGA";
                }
                action(UbicacionesEstandar)
                {
                    Caption = 'Ubicaciones del almacén';
                    ToolTip = 'Crear, configurar y eliminar ubicaciones a mano. Al crear o eliminar una, se crea o elimina también en BC.';
                    ApplicationArea = All;
                    Image = BinContent;
                    RunObject = page "Ubicaciones SGA";
                }
                action(GenerarUbicacionesSGA)
                {
                    Caption = 'Generar ubicaciones';
                    ToolTip = 'Crea las ubicaciones que falten en un rango de pasillos, estanterías y alturas, con su zona, tipo y capacidad. Las que ya existen no se tocan.';
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
                    ToolTip = 'Reparte el stock que ya existe en BC entre las ubicaciones. Conviene lanzarlo primero en simulación.';
                    ApplicationArea = All;
                    Image = Import;
                    RunObject = report "Carga Inicial Contenido SGA";
                }
                action(InicializarContenidoSGA)
                {
                    Caption = 'Inicializar contenido';
                    ToolTip = 'Deja el almacén sin nada ubicado: borra el contenido, los movimientos de ubicación y las órdenes de picking sin terminar. Las ubicaciones se conservan. Sirve para repetir la carga inicial desde cero.';
                    ApplicationArea = All;
                    Image = Delete;
                    RunObject = report "Inicializar Contenido SGA";
                }
            }
        }
    }
}
