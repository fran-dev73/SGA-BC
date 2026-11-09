# SGA — Resumen para dirección de proyecto

SGA es el módulo de gestión de ubicaciones del almacén dentro de Business Central. Documentos: [guía de uso](GUIA_USO_SGA.md), [manual de implantación](MANUAL_IMPLANTACION_SGA.md) y [documentación técnica](DOCUMENTACION_TECNICA_SGA.md), que incluye la arquitectura y las decisiones de almacén.

## Qué resuelve

- **Dónde está cada cosa**: qué producto, lote y caducidad hay en cada hueco, con mapa, mapa 3D y búsqueda.
- **Dónde dejar lo que entra**: propone el hueco para compras, ensamblados y palés de la línea, y registra lo que confirma el operario.
- **De dónde coger lo que sale**: cada pedido de venta se convierte en una orden de picking con el recorrido, el lote y la cantidad; lo recogido vuelve solo al pedido.
- **Reposición del picking**: planifica traer mercancía de almacenamiento a picking.
- **Control**: diario de movimientos que no se edita, conciliación diaria contra el stock de BC, recuentos y bloqueos.

## Qué no resuelve

- **No sustituye el stock de BC**: BC sigue mandando en cantidades, lotes y contabilidad. SGA solo dice dónde está.
- **No ubica al registrar**: las compras y ensamblados se ubican después, al confirmarlo el operario. Así un hueco lleno nunca impide registrar un albarán.
- **No crea solo la orden de picking**: oficina la envía desde el pedido lanzado.
- **No regulariza excesos**: si las ubicaciones tienen más que BC, se recuenta a mano.
- **No usa los documentos de almacén estándar de BC** (picking, envíos y movimientos de almacén).

## Flujos principales

| Flujo | En una frase |
|---|---|
| Puesta en marcha | Se generan las ubicaciones con tipo y capacidad, se imprimen sus etiquetas y se reparte el stock de BC con la carga inicial (simulando antes). |
| Recepción de compra | Tras registrar el albarán, *Ubicar recepciones* propone un hueco por línea y el operario confirma. |
| Producción | *Imprimir y ubicar palés* ubica cada palé al imprimir su etiqueta; *Ubicar ensamblados* recoge lo que falte. |
| Venta | Oficina envía el pedido a picking, el preparador recoge parada a parada y la cantidad a enviar y los lotes pasan solos al pedido. |
| PDA | En la app móvil de BC, con el rol *Preparador SGA (PDA)*: escanea el producto, teclea el dígito del hueco y la parada se confirma sola. |
| Reparto del trabajo | Un responsable asigna órdenes y prioridades; los carretilleros reciben las reubicaciones y los preparadores los pedidos. |
| Control | La conciliación compara cada día ubicaciones contra stock de BC; las diferencias se corrigen con recuento o regularización. |

## Cómo se decide dónde va la mercancía

- Cada ubicación es de **Almacenamiento** (reserva), **Picking** (de donde se prepara) o **sin tipo** (muelles, ajustes: nunca se proponen).
- Lo que entra va **primero a almacenamiento**; a picking solo si no queda sitio.
- La capacidad se mide en **palés**, con el palé por defecto de cada producto. Una cantidad se reparte en palés completos, cada uno a su hueco, y un resto.
- Dentro de cada tipo, el orden lo da la **estrategia** de la configuración. Para producción, el **primer hueco vacío** siguiendo el recorrido; para compras, la casa del producto, si no junto a lo que ya hay y si no el primer hueco libre.
- Al recoger se coge primero lo que antes caduca (FEFO, configurable), palés enteros de almacenamiento si el pedido llega a un palé, y lo demás de picking.

## Cómo se repone el picking

- Un producto necesita una **reubicación** cuando tiene stock en almacenamiento y nada en picking.
- Se planifica **al vaciarse** una ubicación de picking por una venta, y con *Planificar reubicaciones* (a mano o programado) para todo el almacén.
- Se trae **un palé como mucho**, a la misma ubicación de picking o a otra con sitio, que queda guardada para ese producto.
- Se prepara como un picking: los usuarios marcados como **Carretillero SGA** las reciben con *Siguiente orden*.
- **Coste aceptado**: entre que se vacía el picking y llega la reubicación, una venta de ese producto coge de almacenamiento.

## Estado

**Hecho** (desarrollado y documentado):

- Ubicaciones, zonas, generación, etiquetas con dígito de control y cambio en bloque.
- Carga inicial con simulación, *Pendiente de ubicar* e inicialización.
- Entradas: recepciones de compra, ensamblados y palés de la línea.
- Picking de venta completo: envío, asignación, prioridades, preparación, dígito de control y paso al pedido.
- Picking con PDA: escáner integrado en la app móvil de BC, comprobación del producto (GTIN, referencia o GS1-128 con lote) y rol propio.
- Reubicaciones y reparto entre preparadores y carretilleros.
- Consultas, mapa, mapa 3D con traslados arrastrando, conciliación, recuento y análisis ABC.

**Pendiente de probar en sandbox**:

- Registrar el envío de un pedido pasado desde picking con producto con lote, y con líneas en cajas (redondeos).
- Envío parcial y nueva orden del mismo pedido.
- PDA real: lectura por intent en el terminal (Zebra DataWedge u otro), GS1-128 de las etiquetas de producto y confirmación automática.
- Almacenes con envío de almacén obligatorio: ahí el paso al pedido no sirve tal cual.
- Que el palé de una tarea pase a su ensamblado registrado y que *Ubicar ensamblados* pida solo lo que falta.
- Recepciones deshechas del todo o en parte.
- Etiquetas de ubicación en la impresora real (lectura del código de barras).

## Decisiones abiertas

1. **Reponer por mínimo en vez de al vaciarse.** Evitaría coger de almacenamiento mientras llega la reubicación, a cambio de poner cantidad mínima y máxima en cada hueco de picking.
2. **Qué productos reponer primero cuando no hay picking para todos.** Se planifican en el orden en que salen; el que no encuentra hueco se queda sin planificar.