namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.Warehouse.Structure;

/// <summary>
/// Page Rol Center Almacen SGA (ID 51112).
/// Rol center del almacenero. Sus menús son los mismos que los del rol de Procesador de
/// Pedidos (Pag-Ext51103), para que se encuentre todo igual en los dos: "Almacén SGA" (el día
/// a día), "- Ventas y compras" (productos, pedidos e históricos de albaranes), "- Consultas",
/// "- Informes" y "- Configuración" (incluida la puesta en marcha). Si se toca uno, se toca el
/// otro. Además, la barra de navegación lleva los productos y los pedidos y albaranes.
///
/// Lo publica el perfil "ALMACEN SGA", que es el que se elige o se asigna a los usuarios.
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
        // Lo que el almacén consulta de BC, a un clic desde la barra de navegación.
        area(Embedding)
        {
            action(Productos)
            {
                Caption = 'Productos';
                ToolTip = 'Fichas de los productos: unidades de medida, palé por defecto y existencias.';
                ApplicationArea = All;
                RunObject = page "Item List";
            }
            action(PedidosVenta)
            {
                Caption = 'Pedidos de venta';
                ToolTip = 'Pedidos de venta, de los que salen las órdenes de picking al lanzarlos.';
                ApplicationArea = All;
                RunObject = page "Sales Order List";
            }
            action(AlbaranesVenta)
            {
                Caption = 'Albaranes de venta';
                ToolTip = 'Envíos de venta ya registrados.';
                ApplicationArea = All;
                RunObject = page "Posted Sales Shipments";
            }
            action(PedidosCompra)
            {
                Caption = 'Pedidos de compra';
                ToolTip = 'Pedidos de compra pendientes de recibir.';
                ApplicationArea = All;
                RunObject = page "Purchase Order List";
            }
            action(AlbaranesCompra)
            {
                Caption = 'Albaranes de compra';
                ToolTip = 'Recepciones de compra ya registradas, de las que sale lo que hay que ubicar.';
                ApplicationArea = All;
                RunObject = page "Posted Purchase Receipts";
            }
        }

        area(Sections)
        {
            group(SGATareas)
            {
                Caption = 'Almacén SGA';

                action(UbicarProducto)
                {
                    Caption = 'Ubicar producto';
                    ToolTip = 'Dice en qué hueco dejar la mercancía y registra la ubicación cuando el operario la confirma.';
                    ApplicationArea = All;
                    Image = CreateWarehousePick;
                    RunObject = page "Ubicar Producto SGA";
                }
                action(PendienteUbicar)
                {
                    Caption = 'Pendiente de ubicar';
                    ToolTip = 'Stock que no está en ninguna ubicación, lote a lote, para ubicarlo a mano o varios a la vez.';
                    ApplicationArea = All;
                    Image = PutawayLines;
                    RunObject = page "Pendiente Ubicar SGA";
                }
                action(UbicarEnsamblados)
                {
                    Caption = 'Ubicar ensamblados';
                    ToolTip = 'Reparte entre huecos lo que ha salido de los ensamblados de un día.';
                    ApplicationArea = All;
                    Image = Warehouse;
                    RunObject = codeunit "Abrir Ubicar Ensamblados SGA";
                }
                action(UbicarPaletsLinea)
                {
                    Caption = 'Imprimir y ubicar palés';
                    ToolTip = 'Saca la etiqueta de cada palé que sale de la línea y lo deja ubicado.';
                    ApplicationArea = All;
                    Image = PutawayLines;
                    RunObject = page "Ubicar Palets Linea SGA";
                }
                action(UbicarRecepciones)
                {
                    Caption = 'Ubicar recepciones';
                    ToolTip = 'Reparte entre huecos lo que ha llegado en las recepciones de compra de un día.';
                    ApplicationArea = All;
                    Image = Warehouse;
                    RunObject = codeunit "Abrir Ubicar Recepciones SGA";
                }
                action(OrdenesPicking)
                {
                    Caption = 'Órdenes de picking';
                    ToolTip = 'Qué documentos hay que preparar, quién los prepara y cuánto les queda.';
                    ApplicationArea = All;
                    Image = Warehouse;
                    RunObject = page "Ordenes Picking SGA";
                }
                action(AsignarPicking)
                {
                    Caption = 'Asignar órdenes de picking';
                    ToolTip = 'Reparte las órdenes de picking entre los preparadores y fija su prioridad.';
                    ApplicationArea = All;
                    Image = Warehouse;
                    RunObject = page "Asignar Ordenes Picking SGA";
                }
                action(DondeEsta)
                {
                    Caption = '¿Dónde está el producto?';
                    ToolTip = 'Localiza un producto y dice a qué ubicación hay que ir a recogerlo.';
                    ApplicationArea = All;
                    Image = Find;
                    RunObject = page "Consulta Ubic. Producto SGA";
                }
            }
            group(SGAVentasCompras)
            {
                Caption = 'Almacén SGA - Ventas y compras';

                action(SeccionProductos)
                {
                    Caption = 'Productos';
                    ToolTip = 'Fichas de los productos: unidades de medida, palé por defecto y existencias.';
                    ApplicationArea = All;
                    Image = Item;
                    RunObject = page "Item List";
                }
                action(SeccionPedidosVenta)
                {
                    Caption = 'Pedidos de venta';
                    ToolTip = 'Pedidos de venta, de los que salen las órdenes de picking al lanzarlos.';
                    ApplicationArea = All;
                    Image = Document;
                    RunObject = page "Sales Order List";
                }
                action(SeccionAlbaranesVenta)
                {
                    Caption = 'Histórico de albaranes de venta';
                    ToolTip = 'Envíos de venta ya registrados.';
                    ApplicationArea = All;
                    Image = PostedShipment;
                    RunObject = page "Posted Sales Shipments";
                }
                action(SeccionPedidosCompra)
                {
                    Caption = 'Pedidos de compra';
                    ToolTip = 'Pedidos de compra pendientes de recibir.';
                    ApplicationArea = All;
                    Image = Document;
                    RunObject = page "Purchase Order List";
                }
                action(SeccionAlbaranesCompra)
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

                action(Ubicaciones)
                {
                    Caption = 'Ubicaciones SGA';
                    ToolTip = 'Ubicaciones del almacén, con su estado y su ocupación.';
                    ApplicationArea = All;
                    Image = BinContent;
                    RunObject = page "Ubicaciones SGA";
                }
                action(Contenido)
                {
                    Caption = 'Contenido de ubicaciones';
                    ToolTip = 'Qué producto y lote hay en cada ubicación. Desde aquí se traslada (también a otra zona), se bloquea y se recuenta.';
                    ApplicationArea = All;
                    Image = ItemLines;
                    RunObject = page "Contenido Ubicaciones SGA";
                }
                action(MapaAlmacen)
                {
                    Caption = 'Mapa de almacén';
                    ToolTip = 'Rejilla de la nave con el estado de ocupación de cada hueco.';
                    ApplicationArea = All;
                    Image = Map;
                    RunObject = page "Mapa Almacen SGA";
                }
                action(Mapa3D)
                {
                    Caption = 'Mapa 3D de almacén';
                    ToolTip = 'El almacén en volumen, en planta o de frente, por zonas, con cada ubicación coloreada según su estado.';
                    ApplicationArea = All;
                    Image = Map;
                    RunObject = page "Mapa 3D Almacen SGA";
                }
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
                    Caption = 'Conciliación con el stock';
                    ToolTip = 'Diferencias entre el stock de BC y el contenido de las ubicaciones.';
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
            group(SGAInformes)
            {
                Caption = 'Almacén SGA - Informes';

                action(Conciliar)
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

                action(ConfiguracionSGA)
                {
                    Caption = 'Configuración SGA';
                    ToolTip = 'Almacén por defecto, ubicaciones de cada flujo, estrategias y control de capacidad.';
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
                action(UbicacionesEstandar)
                {
                    Caption = 'Ubicaciones del almacén';
                    ToolTip = 'Ubicaciones estándar (bins) sobre las que SGA añade sus datos de gestión.';
                    ApplicationArea = All;
                    Image = BinContent;
                    RunObject = page "Bin List";
                }
                action(GenerarUbicaciones)
                {
                    Caption = 'Generar ubicaciones';
                    ToolTip = 'Crea de golpe todas las ubicaciones de una zona en un rango de estanterías, columnas y alturas.';
                    ApplicationArea = All;
                    Image = CreateForm;
                    RunObject = report "Generar Ubicaciones SGA";
                }
                action(SincronizarUbicaciones)
                {
                    Caption = 'Sincronizar ubicaciones';
                    ToolTip = 'Da de alta en SGA las ubicaciones que aún no tienen datos de gestión.';
                    ApplicationArea = All;
                    Image = Refresh;
                    RunObject = report "Sincronizar Ubicaciones SGA";
                }
                action(CargaInicial)
                {
                    Caption = 'Carga inicial de contenido';
                    ToolTip = 'Reparte el stock que ya existe en BC entre las ubicaciones. Conviene lanzarlo primero en simulación.';
                    ApplicationArea = All;
                    Image = Import;
                    RunObject = report "Carga Inicial Contenido SGA";
                }
                action(InicializarContenido)
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
