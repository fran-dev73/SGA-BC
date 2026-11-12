# Manual de implantación de SGA

Para quien configura SGA: vosotros o el partner. Se hace una vez y se toca solo para ampliar o
corregir. El día a día de quien trabaja está en la [guía de uso](GUIA_USO_SGA.md). Cómo funciona
por dentro, en la [documentación técnica](DOCUMENTACION_TECNICA_SGA.md).

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

## 1. Roles y permisos

1. En *Mi configuración* > *Rol*, elige **Almacén SGA**. El rol de *Procesador de pedidos* tiene los mismos menús. A quien prepara con PDA se le asigna **Preparador SGA (PDA)**.
2. Los menús: **Almacén SGA** (día a día), **Almacén SGA - Ventas y compras**, **Almacén SGA - Consultas**, **Almacén SGA - Informes** y **Almacén SGA - Configuración**.
3. Conjuntos de permisos: **PermissionSet-SGA** para todos y **SGA - Responsable de almacén** para los responsables (añade *Asignar órdenes de picking* e *Inicializar contenido*). Para abrir productos, pedidos y albaranes hacen falta además los permisos estándar de BC.
4. En **Configuración de usuarios**, marca **Responsable picking SGA** a quien reparta órdenes, y **Carretillero SGA** a quien haga las reubicaciones.

## 2. Configuración SGA

Menú **Almacén SGA - Configuración** > **Configuración SGA**.

| Pestaña | Qué se pone |
|---|---|
| General | *Almacén por defecto*, *Zona por defecto* y *Fecha inicio SGA* (ver apartado 7) |
| Ubicaciones por flujo | *Ubic. ajustes*: donde van las faltas que se regularizan. Mejor una ubicación sin tipo |
| Estrategias | Estrategia de ubicación, de compras y de ensamblados, estrategia de picking (FEFO, FIFO…) y días de aviso de caducidad. Ver la tabla de estrategias en la guía de uso |
| Estrategias > grupo IIEE | *Campo del grupo IIEE en el producto*: el campo de la ficha del producto que guarda su grupo IIEE. Se elige de la lista y al lado sale su nombre. En blanco, no se agrupa |
| Análisis ABC | Días de ventas y cortes de las clases A y B |
| Controles | Ver la tabla de controles más abajo |
| Numeración | *Nºs orden SGA*: obligatoria para crear órdenes de picking y reubicaciones |

**Controles:**

| Control | Qué hace |
|---|---|
| *Control capacidad* | *Avisar* o *Bloquear* cuando una ubicación se pasa de su capacidad |
| *Permitir desvío ubicación* | Admite recoger de un hueco distinto del propuesto |
| *Exigir confirmar ubicación* | Obliga a escanear la ubicación al ubicar mercancía. No afecta al picking, que siempre lee la ubicación de la etiqueta del hueco (ver apartado 6) |
| *Exigir escanear producto al recoger* | Pide el producto escaneado en cada parada |
| *Exigir asignación de picking* | Las órdenes nacen pendientes de asignar y las reparte un responsable |
| *Permitir cantidad negativa* | Solo para arranques |

## 3. Zonas

**Zonas SGA** agrupa ubicaciones (por ejemplo RESERVA o CÁMARA). Su *Tipo ubicación* es el que heredan las ubicaciones que se crean en ella.

Su **Grupo IIEE** reúne en ella los productos de ese grupo: al ubicar, se busca primero en las zonas de su grupo y, si están llenas, en el resto del almacén. La zona admite igualmente productos de otros grupos, y un grupo puede tener varias zonas. Necesita el campo del grupo IIEE configurado en el apartado 2.

**Playas.** Donde se dejan los pedidos preparados. Se crea una zona sin tipo con la casilla **Playa** y una ubicación por playa (por ejemplo PLAYA con PLAYA-1 a PLAYA-4), también sin tipo, así que nunca se proponen para ubicar ni reponer. En **Ubicación por defecto** va la playa a la que el preparador lleva el picking de venta: la PDA se la indica en cada parada y al terminar la orden.

## 4. Crear las ubicaciones

- **Generar ubicaciones** crea los huecos de golpe. Pide almacén, zona, pasillo desde y hasta (1 a 999), estantería desde y hasta (1 a 99), altura desde y hasta (dos cifras, de 00 a 99), tipo ubicación y capacidad en palés.
- Pasillo y estantería van de uno en uno. La altura va de 10 en 10 desde la inicial y sin pasar de la final: de 00 a 40 crea 00, 10, 20, 30 y 40.
- El código sale como `pasillo-estantería-altura` con ceros: `101-15-03`. De él salen la secuencia de picking (el orden de recorrido, cuanto menor antes) y los mapas.
- Lánzalo una vez por zona y por grupo de pasillos iguales. Se puede relanzar para ampliar: lo que ya existe no se toca.
- El almacén tiene que tener marcada *Ubicación obligatoria* en su ficha.
- **Sincronizar ubicaciones** da de alta en SGA las ubicaciones creadas en BC por fuera. Las deja sin tipo: hay que ponérselo.

## 5. Tipo y capacidad

1. En **Ubicaciones SGA** filtra por código (por ejemplo, el pasillo 103). La vista *Sin tipo* enseña las que faltan.
2. Selecciónalas y pulsa **Cambiar en bloque**. Marca solo lo que quieras cambiar: capacidad, control de capacidad, mezcla de productos, tipo y zona.
3. Una sola ubicación se cambia en su ficha, que además tiene producto fijo, mezcla de lotes y secuencia de picking.

La configuración de una ubicación **solo se cambia si está vacía**. Bloquearla se puede siempre.

**Capacidad en palés.** Cada producto se cuenta con su *Cód. palé por defecto*: medio palé ocupa 0,5. Un producto sin palé en su ficha no cabe en una ubicación con capacidad. Con 0 no hay capacidad declarada: no limita, pero con cualquier cosa dentro sale como llena.

## 6. Etiquetas de ubicación

### Imprimir etiquetas

En **Ubicaciones SGA**, selecciona los huecos y pulsa **Imprimir etiquetas**. Cada etiqueta lleva el código de la ubicación con su código de barras Code 128 y el código legible debajo. La PDA lee ese código para comprobar que el preparador está delante del hueco correcto.

### Pegar las etiquetas

Las etiquetas deben estar pegadas antes de empezar a recoger. Se imprimen y pegan por pasillos, filtrando por código.

En cada parada, el preparador lee la ubicación de la etiqueta del hueco (o la teclea), y el producto si la configuración lo exige.

## 7. Carga inicial

Reparte entre las ubicaciones el stock que ya tiene BC. Menú *Configuración* > **Carga inicial de contenido**.

1. Antes: los productos tienen *Cód. palé por defecto* y *Unidad medida venta*, y las ubicaciones tienen tipo y capacidad.
2. *Ubicación de destino* = **Huecos libres**: cada palé completo a un hueco vacío y el resto junto en otro hueco con sitio. Se llena **primero picking y luego almacenamiento**. Para que picking no se llene de palés de unos pocos productos, *Máx. ubicaciones de picking por producto* (por defecto 1) limita cuántas ocupa cada uno. Sus ubicaciones reservadas (producto fijo) se llenan igualmente.
3. Lánzalo primero con **Solo simular**: hace el reparto completo, lo enseña y lo deshace.
4. Al terminar sale **Resultado de la carga inicial**. La vista *No cargado* dice qué se ha quedado fuera y por qué.
5. Para relanzarlo, marca **Omitir productos que ya están ubicados**. Lo que no cabe se ubica desde *Pendiente de ubicar*.

**Fecha inicio SGA.** En *Configuración SGA* > *General* va el primer día en que las entradas se ubican desde su documento. Las recepciones, los ensamblados y las tareas de producción anteriores no salen nunca en *Ubicar recepciones*, *Ubicar ensamblados* ni *Imprimir y ubicar palés*: lo que trajeron ya es stock de BC y lo coloca la carga inicial. En *Pendiente de ubicar* esas cantidades salen en *A ubicar*, no en *En recepciones o ensamblados*.

La carga inicial se lanza **antes de registrar ninguna entrada del día de inicio** (el día anterior o a primera hora). Una recepción o un ensamblado de ese día que entrara en la carga se volvería a pedir desde su pantalla y se ubicaría dos veces.

## 8. Empezar de cero

**Inicializar contenido** (solo responsables) deja el almacén sin nada ubicado: borra el contenido, los movimientos de ubicación y las órdenes de picking sin terminar. Las ubicaciones y el stock de BC no cambian. Con **Eliminar también las ubicaciones** borra además los huecos del almacén entero. No se puede deshacer.

## 9. Tareas programadas

Algunas tareas se pueden dejar en la cola de proyectos de BC, para que corran solas. No vienen dadas de alta: hay que crearlas.

| Tarea | Codeunit | Qué hace | Cuándo |
|---|---|---|---|
| Planificar reubicaciones | *Reubicaciones SGA* | Repone el picking de los productos que lo necesitan | Cada hora o cada noche |
| Análisis ABC | *Análisis ABC SGA* | Calcula las clases de rotación (solo observa) | Una vez por semana |

La segunda ronda de picking no se programa: se lanza a mano desde *Órdenes de picking SGA*.

## 10. Lista de comprobación

Antes de dar el almacén por operativo:

- [ ] Rol y permisos asignados a cada usuario (apartado 1).
- [ ] Configuración SGA revisada, en especial estrategias, controles y numeración (apartado 2).
- [ ] Campo del grupo IIEE elegido, si se usan grupos (apartado 2).
- [ ] Zonas creadas, con su tipo y su grupo IIEE si procede (apartado 3).
- [ ] Ubicaciones generadas con su tipo y capacidad (apartados 4 y 5).
- [ ] *Fecha inicio SGA* puesta y carga inicial simulada, revisada y lanzada antes de registrar entradas de ese día (apartado 7).
- [ ] Etiquetas impresas y pegadas en cada hueco, por pasillos, antes de empezar a recoger (apartado 6).
- [ ] Un pedido de prueba de principio a fin, con la PDA y con el navegador.
- [ ] Tareas programadas dadas de alta (apartado 9).
