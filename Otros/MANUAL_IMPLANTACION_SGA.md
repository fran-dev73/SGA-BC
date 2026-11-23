# Manual de implantación de SGA

Para quien configura SGA: vosotros o el partner. Se hace una vez y se toca solo para ampliar o corregir. El día a día de quien trabaja está en el [manual de usuario](MANUAL_USUARIO_SGA.md). Cómo funciona por dentro, en la [documentación técnica](DOCUMENTACION_TECNICA_SGA.md).

## Índice

1. [Roles y permisos](#1-roles-y-permisos)
2. [Configuración SGA](#2-configuración-sga)
3. [Zonas](#3-zonas)
4. [Crear las ubicaciones](#4-crear-las-ubicaciones)
5. [Tipo y capacidad](#5-tipo-y-capacidad)
6. [Etiquetas de ubicación](#6-etiquetas-de-ubicación)
7. [Carga inicial](#7-carga-inicial)
8. [Empezar de cero](#8-empezar-de-cero)
9. [Tareas programadas](#9-tareas-programadas)
10. [Lista de comprobación](#10-lista-de-comprobación)

---

## Antes de empezar: datos de Business Central

SGA se apoya en el maestro de BC. Sin estos datos, la configuración de abajo no sirve de nada. Hacerlo en este orden:

1. **Almacén.** Cada almacén que use SGA tiene marcada *Ubicación obligatoria*. SGA crea los huecos como ubicaciones (`Bin`) de BC, así que no hace falta darlos de alta antes en BC.
2. **Productos con palé.** En la ficha del producto, *Cód. palé por defecto* con una unidad de medida de palé en su *Unidades de medida* y su factor (cuántas unidades base tiene el palé). Sin ese factor mayor que 1, el producto se cuenta como si no tuviera palé: no cabe en las ubicaciones con capacidad y la carga inicial no lo reparte por huecos.
3. **Series.** Una serie de números para *Nºs orden SGA* (apartado 2); sin ella no se puede enviar ningún pedido a SGA. Los SSCC de los palés que entran sin etiqueta salen de las series de la *Configuración de inventario*, *Nº serie EAN-128 - IA00* (número de 9 dígitos) y *Nº serie ind. extensión IA00* (dígito de extensión), las mismas de las etiquetas de palé del resto del sistema; sin ellas no se puede ubicar un palé que entra sin etiqueta.
4. **Lotes de BC (opcional).** Para tener trazabilidad por lote en los albaranes y facturas de venta, el producto fabricado necesita un código de seguimiento con *Seguimiento específico de lote* (y, si se quiere caducidad, *Usar fechas de caducidad* y la *Fórmula de caducidad* en su ficha). Con eso, el *Lote* del ensamblado pasa solo al seguimiento de BC y el picking lo escribe en el pedido. BC no deja cambiar el código de seguimiento de un producto que ya tiene movimientos.
5. **Usuarios.** Cada persona con su usuario de BC y su rol (apartado 1), antes de configurar la PDA.

## 1. Roles y permisos

1. En *Mi configuración* > *Rol*, elige **Almacén SGA**. El rol de *Procesador de pedidos* tiene los mismos menús. A quien prepara con PDA se le asigna **Preparador SGA (PDA)**.
2. Menús: **Almacén SGA** (día a día), **Almacén SGA - Ventas y compras**, **Almacén SGA - Consultas**, **Almacén SGA - Informes** y **Almacén SGA - Configuración**.
3. Conjuntos de permisos: **PermissionSet-SGA** para todos y **SGA - Responsable de almacén** para los responsables (añade *Inicializar contenido*). Quién puede asignar órdenes y cambiar su prioridad lo dice *Responsable picking SGA* en Configuración de usuarios, cuando la configuración exige asignación. Para abrir productos, pedidos y albaranes hacen falta además los permisos estándar de BC.
4. En *Configuración de usuarios*, marca **Responsable picking SGA** a quien reparta órdenes, y **Carretillero SGA** a quien haga las reposiciones.

## 2. Configuración SGA

Menú **Almacén SGA - Configuración** > **Configuración SGA**.

| Pestaña | Qué se pone |
|---|---|
| General | *Almacén por defecto* y *Zona por defecto* |
| Ubicaciones por flujo | *Ubic. ajustes*: donde van las faltas que se regularizan. Mejor una ubicación sin tipo. *Playa por defecto*: la playa con la que nacen las órdenes de picking de venta (apartado 3) |
| Estrategias | Estrategia de ubicación, de compras y de ensamblados; estrategia de picking (FIFO, FEFO o por orden de ubicación). Ver *Estrategias de ubicación*, más abajo |
| Análisis ABC | Días de ventas y cortes de las clases A y B |
| Controles | Ver tabla siguiente |
| Numeración | *Nºs orden SGA*: obligatoria para crear órdenes de picking y reposiciones. Los SSCC no se configuran aquí: ver *Series* en *Antes de empezar* |

| Control | Qué hace |
|---|---|
| Control capacidad | Avisar o Bloquear cuando una ubicación se pasa de su capacidad |
| Permitir desvío ubicación | Admite recoger de un hueco distinto del propuesto, y dejar en uno distinto del propuesto al ubicar (Ubicar producto, Ubicar recepciones y ensamblados, Imprimir y ubicar) |
| Exigir confirmar ubicación | En *Ubicar producto*, obliga a escanear la etiqueta del hueco en el que se deja cada línea (columna *Ubicación leída*) |
| Exigir asignación de picking | Las órdenes nacen pendientes de asignar y las reparte un responsable |
| Permitir cantidad negativa | Solo para arranques |

### Estrategias de ubicación

Primero se busca en las ubicaciones de almacenamiento y, si ninguna sirve, en las de picking; las ubicaciones sin tipo no se proponen nunca. Dentro de cada tipo, la estrategia decide el orden. En todas, los huecos se recorren por **secuencia de picking**, de menor a mayor, que es la ruta física del almacén.

| Estrategia | Orden de búsqueda |
|---|---|
| **Estándar** | 1. Ubicación fija del producto. 2. Consolidar: un hueco que ya tenga ese producto. 3. Primer hueco con sitio en la ruta |
| **Priorizar consolidación** | 1. Consolidar. 2. Primer hueco con sitio en la ruta |
| **Solo ubicación fija** | Solo la ubicación fija del producto. Si no tiene, o no cabe, *No se puede ubicar* |
| **Primera libre por ruta** | Primer hueco con sitio en la ruta |
| **Solo hueco vacío** | Primer hueco totalmente vacío en la ruta |

- **Ubicación fija del producto**: un hueco con *Producto fijo* igual al producto. Si no hay ninguno, el *Nº de estante* de la ficha del producto, si ese hueco existe y admite la entrada.
- **Consolidar**: entre los huecos que ya tienen el producto y admiten la entrada, el de menor secuencia de picking.

Qué estrategia usa cada pantalla:

| Pantalla o proceso | Estrategia | Por defecto |
|---|---|---|
| Ubicar recepciones | *Estrategia ubic. compras* | Estándar |
| Ubicar ensamblados | *Estrategia ubic. ensamblados* | Solo hueco vacío |
| Imprimir y ubicar palés (producción) | *Estrategia ubic. ensamblados* | Solo hueco vacío |
| Ubicar producto | *Estrategia ubicación* | Estándar |
| Trasladar contenido a otra zona | *Estrategia ubicación*, dentro de la zona elegida | Estándar |
| Reposiciones de picking | Estándar, solo huecos de picking | Fija |
| Carga inicial, *Huecos libres* | Palés: primer hueco vacío sin producto fijo. Resto: Priorizar consolidación | Fija |
| Carga inicial, ubicación fija o indicada | Sin estrategia: la ubicación fija del producto o la indicada | Fija |
| Ubicar seleccionadas | Igual que la carga inicial, pero primero almacenamiento y luego picking. Entra como entrada manual, con SSCC nuevo | Fija |

## 3. Zonas

**Zonas SGA** agrupa ubicaciones (por ejemplo RESERVA o CÁMARA). La zona no tiene tipo: en una misma zona puede haber ubicaciones de almacenamiento y de picking. El tipo se pone en cada ubicación.

**Playas.** Cada playa donde se dejan los pedidos preparados es una zona con la casilla **Playa** marcada, sin ubicaciones (por ejemplo PLAYA1, PLAYA2). Después, en *Configuración SGA*, elige la *Playa por defecto*.

## 4. Crear las ubicaciones

Se crean, cambian y eliminan solo desde el menú *Almacén SGA - Configuración*. Desde *Consultas*, *Ubicaciones SGA* y su ficha se abren en modo ver.

- **Ubicaciones del almacén** (en Configuración) abre *Ubicaciones SGA* con **Nuevo** y **Eliminar**, y la ficha editable. **Nuevo** crea una ubicación suelta a mano (por ejemplo un fondo de pasillo) y también la de BC si no existe. El código tiene que ser `xxx-xx-xx` con los mismos límites que *Generar ubicaciones*: pasillo de 001 a 999, estantería de 01 a 99 y altura de 00 a 99; la descripción es el código y la secuencia sale del código. La descripción es la de la ubicación de BC: para cambiarla, ficha del almacén > *Ubicaciones*. **Eliminar** borra la ubicación SGA y la de BC; no deja si tiene contenido o si BC no permite borrarla.

- **Generar ubicaciones** crea los huecos de golpe. Pide almacén, zona, pasillo desde y hasta (1 a 999), estantería desde y hasta (1 a 99), altura desde y hasta (dos cifras, de 00 a 99), tipo de ubicación y capacidad en palés. Pasillo y estantería van de uno en uno. La altura va de 10 en 10 desde la inicial sin pasar de la final: de 00 a 40 crea 00, 10, 20, 30 y 40.
- El código sale como `pasillo-estantería-altura` con ceros: `101-15-03`. De él salen la secuencia de picking (el orden de recorrido: cuanto menor, antes) y los mapas.
- Lánzalo una vez por zona y por grupo de pasillos iguales. Se puede relanzar para ampliar: lo que ya existe no se toca.
- El almacén tiene que tener marcada *Ubicación obligatoria* en su ficha.
- **Sincronizar ubicaciones** da de alta en SGA las ubicaciones creadas en BC por fuera. Las deja sin tipo: hay que ponérselo.

## 5. Tipo y capacidad

1. En **Ubicaciones SGA** filtra por código (por ejemplo, el pasillo 103). La vista *Sin tipo* enseña las que faltan.
2. Selecciónalas y pulsa **Cambiar en bloque**. Marca solo lo que quieras cambiar: capacidad, control de capacidad, mezcla de productos, tipo y zona.
3. Una sola ubicación se cambia en su ficha, que además tiene producto fijo, mezcla de lotes y secuencia de picking.

La configuración de una ubicación solo se cambia si está vacía. Bloquearla se puede siempre.

**Fondo de pasillo.** Una ubicación a ras de suelo al fondo del pasillo con sitio para varios palés de productos distintos. Se crea con **Nuevo** en *Ubicaciones del almacén*, con un código de la posición siguiente a la última estantería y altura 01 (`101-31-01`), para que el mapa la dibuje en su sitio, y una descripción con la que nombrarla ("Fondo pasillo 101"). En su ficha: tipo *Almacenamiento*, *Capacidad* = palés que caben, las dos mezclas y **Fondo de pasillo** marcados. Al marcarla, su posición no puede tener otras alturas, y mientras esté marcada no se pueden crear (ni a mano ni con *Generar ubicaciones*, que las salta). En el mapa 3D, coloreado por estado, sale en rosa (con la parte oscura hasta donde está ocupada) y su ficha flotante dice *Fondo de pasillo*.

**Capacidad en palés.** Cada producto se cuenta con su *Cód. palé por defecto*: medio palé ocupa 0,5. Un producto sin palé en su ficha no cabe en una ubicación con capacidad. Con 0 no hay capacidad declarada: no limita, nunca sale como llena y su ocupación queda a 0 %.

## 6. Etiquetas de ubicación

En **Ubicaciones SGA**, selecciona los huecos y pulsa **Imprimir etiquetas**. Cada etiqueta lleva el código de la ubicación y su código de barras. Hay que pegarlas antes de empezar a trabajar, por pasillos: el preparador escanea la etiqueta del hueco del que recoge (siempre) y, con *Exigir confirmar ubicación*, la del hueco en el que deja la mercancía en *Ubicar producto*.

## 7. Carga inicial

Reparte entre las ubicaciones el stock que ya tiene BC. Menú **Configuración** > **Carga inicial de contenido**.

1. Antes:
   - los productos tienen *Cód. palé por defecto* y *Unidad medida venta*, y las ubicaciones tienen tipo y capacidad;
   - en *Configuración SGA* > *General* está puesta la **Fecha inicio SGA** (sin ella no se lanza). Las recepciones y ensamblados desde esa fecha se ubican desde *Ubicar recepciones* y *Ubicar ensamblados*, no los coge la carga.
2. *Ubicación de destino* = **Huecos libres**: cada palé completo a un hueco vacío y el resto junto en otro hueco con sitio. Se llena primero picking y luego almacenamiento. Para que picking no se llene de palés de unos pocos productos, *Máx. ubicaciones de picking por producto* (por defecto 1) limita cuántas ocupa cada uno. Sus ubicaciones reservadas (producto fijo) se llenan igualmente.
3. Lánzala primero con **Solo simular**: hace el reparto completo, lo enseña y lo deshace.
4. Al terminar sale **Resultado de la carga inicial**. La vista *No cargado* dice qué se ha quedado fuera y por qué.
5. Se puede relanzar sin riesgo: carga, lote a lote, solo lo que falta (stock de BC menos lo ya ubicado y menos lo pendiente en albaranes y ensamblados), lo mismo que enseña **Pendiente de ubicar**.

## 8. Empezar de cero

**Inicializar contenido** (solo responsables) deja el almacén sin nada ubicado: borra el contenido, los movimientos de ubicación y las órdenes de picking sin terminar. Las ubicaciones y el stock de BC no cambian. Con **Eliminar también las ubicaciones** borra además los huecos del almacén entero. No se puede deshacer.

## 9. Tareas programadas

Algunas tareas se pueden dejar en la cola de proyectos de BC para que corran solas. No vienen dadas de alta: hay que crearlas en **Cola de proyectos** > **Nueva entrada**, con *Tipo de objeto a ejecutar* = **Codeunit** y el ID indicado.

| Tarea | Codeunit (ID) | Qué hace | Cuándo |
|---|---|---|---|
| Planificar reposiciones | *Reposiciones SGA* (51113) | Repone el picking de los productos que lo necesitan | Cada hora o cada noche |
| Análisis ABC | *Análisis ABC SGA* (51107) | Calcula las clases de rotación (solo observa) | Una vez por semana |

La segunda ronda de picking no se programa: se lanza a mano desde **Órdenes de picking SGA**.

## 10. Lista de comprobación

Antes de dar el almacén por operativo:

- [ ] Datos de BC listos: almacén con ubicación obligatoria, palés con factor, serie *Nºs orden SGA* y series de SSCC de la configuración de inventario (antes de empezar).
- [ ] Rol y permisos asignados a cada usuario (apartado 1).
- [ ] Configuración SGA revisada, en especial estrategias, controles y numeración (apartado 2).
- [ ] Zonas creadas (apartado 3).
- [ ] Ubicaciones generadas con su tipo y capacidad (apartados 4 y 5).
- [ ] Carga inicial simulada, revisada y lanzada (apartado 7).
- [ ] Etiquetas impresas y pegadas por pasillos (apartado 6).
- [ ] *Fecha inicio SGA* puesta antes de la carga inicial (apartado 7).
- [ ] Un pedido de prueba de principio a fin, con la PDA y con el navegador.
- [ ] Tareas programadas dadas de alta (apartado 9).
