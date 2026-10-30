# Manual SGA — Gestión de Ubicaciones en Dynamics BC

**SGA** es un sistema pequeño y ligero de gestión de almacén que responde tres preguntas:
1. ¿Cuántas ubicaciones hay y en qué estado están (vacías, con hueco, llenas, bloqueadas)?
2. ¿Qué producto, variante, lote y caducidad hay en cada ubicación?
3. ¿Dónde tengo que ir a recoger un producto? ¿Y dónde lo tengo que dejar cuando entra?

**No mueve el stock de BC**; solo te dice dónde está ubicado y controla que el contenido de las ubicaciones no se degrade.

---

## Concepto: lo que ves es lo que hay

En BC, tu stock es un número global por producto. En SGA, ese mismo stock **repartido entre ubicaciones**, con detalle de **lote y caducidad**. Por eso es útil: sin SGA, solo sabes que tienes 500 cajas de un producto; con SGA, sabes que 200 están en la nave A, 150 en cuarentena esperando QC y 150 en una ubicación bloqueada porque vencen en una semana.

SGA vive **en paralelo** con el stock de BC: son dos capas independientes. El stock global sigue siendo la verdad de BC, pero **si el contenido de las ubicaciones y el stock se desincroniza, SGA te lo dice**.

---

## Primeros pasos: puesta en marcha (primera vez)

### 1. Entra en el rol de almacén

SGA se maneja como cualquier otra área de Business Central, con su rol y su buscador.

**Rol propio**: cambia al rol **Almacén SGA**. Arriba verás los indicadores del almacén, en la barra de navegación lo del día a día (*Ubicar producto*, *Ubicar ensamblados*, *Ubicar recepciones*, *Órdenes de picking*, *¿Dónde está el producto?*, *Contenido de ubicaciones*, *Ubicaciones SGA*) y a la izquierda las secciones **Almacén**, **Control** y **Configuración**, más **Tareas periódicas**, **Puesta en marcha** e **Informes**.

**Desde el rol de Procesador de Pedidos**: tienes las mismas opciones en las secciones `Almacén SGA`, `Almacén SGA - Consultas` y `Almacén SGA - Configuración`.

**Con el buscador**: todo lo importante sale escribiendo su nombre en la lupa (Alt+Q), igual que el resto de BC. Prueba con "Ubicar producto", "Órdenes de picking" o "Configuración SGA".

Las páginas que no salen en el buscador son las que en BC tampoco salen: las fichas se abren desde su lista, y los diálogos de trasladar o recontar desde el contenido.

### 2. Configura SGA
**Dónde**: *Configuración SGA*, en *Almacén SGA* > **Configuración**. También sale al buscarlo.

Aquí fijas:
- **Almacén por defecto**: el almacén donde lanzarás los procesos si no especificas otro.
- **Ubicaciones de cada flujo**: 
  - *Recepción de compras*: dónde llegan las compras (típicamente "Muelle de entrada"). Hoy no la usa ningún proceso: *Ubicar recepciones* lleva la mercancía directa del albarán a su hueco.
  - *Entrada de producción*: dónde baja la producción terminada.
  - *Expedición*: dónde prepara el picking antes de enviar (típicamente "Muelle de salida").
  - *Desbordamiento*: dónde va lo que no cabe en su ubicación natural.
  - *Ajustes*: dónde van los recuentos que no cuadran.
- **Estrategias**:
  - *Estrategia de ubicación*: cómo se decide dónde colocar un producto que entra.
  - *Estrategia de picking*: cómo se decide cuál coger si hay el producto en varias ubicaciones.
  - *Días aviso caducidad*: cuántos días antes del vencimiento avisar.
- **Controles**: si avisar o bloquear cuando se llena una ubicación, si permitir cantidades negativas por error, etc.

### 3. Crea las zonas
**Dónde**: *Zonas*, en *Almacén SGA* > **Configuración**.

Una zona es un grupo lógico de ubicaciones (ej: "Nave A", "Cuarentena", "Producción"). Cada zona tiene:
- **Tipo de ubicación por defecto**: las ubicaciones que crees en esta zona heredarán este tipo (Picking, Reserva, Producción, etc.).
- **Prioridades de ubicación y picking**: si hay varias ubicaciones libres, cuál preferir.

### 4. Mira las ubicaciones que ya tienes
**Dónde**: *Ubicaciones del almacén*, en *Almacén SGA* > **Almacén**.

Son las ubicaciones estándar de Business Central, los *bins* del almacén. SGA **no sustituye esa tabla**: le añade encima su ficha de gestión (capacidad, bloqueo, reglas de mezcla, zona). Si el almacén todavía no tiene ubicaciones, las creas en el paso siguiente.

### 5. Genera ubicaciones (si no las tienes)
**Dónde**: *Generar ubicaciones*, en *Almacén SGA* > **Puesta en marcha**. También en *Configuración SGA* (botón *Generar ubicaciones*), en la lista de *Ubicaciones* y en el buscador.

La estructura del almacén **no se escribe en la configuración**: allí solo está *Columnas mapa*, que es cuántos huecos dibuja el mapa. Se crea con este proceso, que pide:

| Campo | Qué es en el almacén | Ejemplo |
|---|---|---|
| Almacén | El almacén de BC | PRINCIPAL |
| Nave | Una letra por nave | A |
| Estantería desde / hasta | El **pasillo** o estantería | 1 a 10 |
| Columna desde / hasta | El **hueco** a lo largo de la estantería | 1 a 31 |
| Altura desde / hasta | El **nivel**, de abajo arriba | 1 a 4 |
| Zona, Tipo ubicación, Capacidad uds. | Lo que heredan las ubicaciones nuevas | RESERVA, Reserva, 1 |

Por ejemplo, la nave A con estanterías 1-10, columnas 1-31 y alturas 1-4 son 1.240 huecos. Si los pasillos tienen distinto número de huecos o alturas, lánzalo una vez por cada grupo de pasillos iguales.

**Antes**: crea la zona en *Zonas*, comprueba que los productos tienen rellenos el *Cód. palé por defecto* y la *Unidad de medida de venta* (de ahí saca SGA el palé y la caja), y revisa el *Tipo de hueco al generar* de la configuración (por defecto *Palé*). **Después**: revisa capacidades y tipos (ver abajo) y ajusta *Columnas mapa* al número de huecos del pasillo más largo (máximo 32).

**Ajustar capacidad, tipo y zona después de generar.** Se hace en la lista **Ubicaciones SGA** (rol *Almacén SGA*, barra de navegación), **no** en *Ubicaciones del almacén*, que es la lista estándar de BC y no tiene estos datos:

> **Solo ubicaciones vacías.** La configuración de una ubicación (*Admite*, capacidad, mezclas, zona, tipo, secuencia de picking, producto fijo y cantidades mínima y máxima) solo se cambia si **no tiene nada dentro**. Si tiene contenido, en su ficha esos campos salen bloqueados, y el cambio en bloque se la salta y al terminar dice cuántas y cuáles no ha cambiado. Antes de reconfigurarla, vacíala o traslada lo que tenga. Bloquearla o cambiar su descripción sí se puede siempre.

1. Filtra las ubicaciones que quieras cambiar (por ejemplo, un pasillo: *Cód. ubicación* = `A-03-*`).
2. Selecciónalas todas (**Ctrl+A**) o marca las que quieras.
3. Pulsa **Cambiar en bloque** y marca solo lo que quieras cambiar: *Capacidad* (1 = un palé, 72 = setenta y dos cajas, 0 = sin límite), *Admite* (Palé / Caja), *Acepta múltiples productos*, *Tipo ubicación* y *Zona*.

Así se ponen, por ejemplo, todos los huecos de palé a capacidad 1, o se convierte un pasillo entero en huecos mixtos de caja. Una sola ubicación también se puede cambiar en su ficha o directamente en la línea.

**Etiquetas de ubicación.** En la misma lista, selecciona los huecos y pulsa **Imprimir etiquetas**. Sale una etiqueta de **70 × 35 mm** por hueco, pensada para impresora de etiquetas:

```
┌──────────────────────────────┐
│ A-01-15-3          CONTROL   │
│                    ┌──────┐  │
│                    │  47  │  │
│                    └──────┘  │
│ ║│║║│║│║║│║║│║│║║│║║│║│║║│   │  ← código de barras del hueco
│ PRINCIPAL · Palé             │
└──────────────────────────────┘
```

- El **código de barras** (Code 128) es el del hueco: se escanea en *Ubicación de la que recoge* o en *Ubicación confirmada*.
- El **dígito de control** (dos cifras, en el recuadro) se teclea al recoger si la configuración lo exige. Cada hueco recibe el suyo al crearse; si alguno no lo tiene, se genera al imprimir.
- **Regenerar dígitos de control** da números nuevos a los huecos seleccionados (por ejemplo, si una etiqueta se ha copiado o fotografiado). Hay que reimprimir sus etiquetas: las viejas dejan de valer.

También se puede lanzar desde el buscador como *Etiquetas de ubicación*, filtrando por almacén, ubicación, zona o tipo.

Por cada hueco crea **dos cosas**: la ubicación estándar de BC y su ficha de gestión de SGA. El código sigue el formato `nave-estantería-columna-altura` (`A-01-15-3`), y de ese código salen tanto la rejilla del mapa como el **orden de recorrido** que luego sigue el picking.

Es idempotente: lo que ya existe no se toca, así que puedes relanzarlo para ampliar una nave.

**Requisito**: el almacén debe tener activado *Ubicación obligatoria* (`Bin Mandatory`) en su ficha.

### 6. Sincroniza la topología
**Dónde**: *Sincronizar ubicaciones*, en *Almacén SGA* > **Tareas periódicas**.

SGA recorre las ubicaciones estándar del almacén y crea una **ficha de gestión** para cada una que aún no la tenga: capacidad, bloqueo, reglas de mezcla, etc. Úsalo cuando alguien ha dado de alta ubicaciones por fuera de SGA.

Si es la **primera vez**, después de sincronizar ajusta capacidad y tipo en la lista **Ubicaciones SGA** con **Cambiar en bloque** (ver el paso 5).

### 7. Reparte el stock que ya tienes
**Dónde**: *Carga inicial de contenido*, en *Almacén SGA* > **Puesta en marcha**.

Se lanza **una vez, al arrancar**. BC sabe cuánto stock hay de cada producto y lote, pero SGA empieza con las ubicaciones vacías. Este proceso da de alta ese stock en las ubicaciones, para que SGA y BC arranquen cuadrados. **No mueve stock en BC**: solo crea el contenido de las ubicaciones y un movimiento de *Carga inicial* en el diario.

Lee el stock por **producto, variante y lote**, con su caducidad, y lo deja según la **ubicación de destino**:

| Ubicación de destino | Dónde deja cada producto |
|---|---|
| **Huecos libres** (recomendado) | Reparte por la nave, como se haría a mano (ver abajo). |
| **Ubicación fija del producto** | Todo el lote en su casa, el campo *Estantería* (Shelf No.) de la ficha. Si no tiene, en la *Ubicación indicada*. |
| **Ubicación indicada** | Todo en la *Ubicación indicada*, una ubicación "de paso" para repartir después con *Trasladar*. |

La *Ubicación indicada* sale rellena con la **ubicación de ajustes** de la configuración. Con **Huecos libres** sale bloqueada y no se usa: el hueco lo elige siempre el sistema.

**Cómo reparte *Huecos libres***, lote a lote:

1. Pasa la cantidad a **palés** con el *Cód. palé por defecto* del producto (PALE200, EUROPALE…, se llame como se llame). Ejemplo: 2.700 botellas, con un palé de 1.200, son 2 palés y sobran 300.
2. **Cada palé completo va a un hueco de palé vacío**: primero los huecos reservados a ese producto (*Producto fijo*), luego el siguiente libre siguiendo la ruta. Solo usa huecos de tipo *Picking* o *Reserva*, sin bloquear y con *Admite* = Palé (los que lo tienen en blanco no se usan).
3. **Lo que sobra se pasa a cajas** (su *Unidad de medida de venta*): si son menos de 10 van a un hueco de caja, juntándolas con el mismo producto si ya está en alguno; si son 10 o más, a un hueco de palé (un palé incompleto). Siempre respetando la capacidad.
4. Lo que no llega a una caja (botellas sueltas) va a una **ubicación de unidades sueltas** (*Admite* = Unidad), juntándolo con el mismo producto si ya está. Si no hay, no se carga.
5. **Producto sin palé por defecto**: no se puede repartir por huecos y **no se carga**; sale en el resultado con ese motivo. Rellena su *Cód. palé por defecto* y vuelve a lanzar la carga (con *Omitir productos que ya están ubicados*).
6. **Si no quedan huecos**, lo que no cabe **no se carga**. Saldrá en la conciliación como *sin ubicar*.

**Al terminar**, el mensaje resume cuánto se ha quedado fuera **por cada motivo** (por ejemplo *"No queda espacio en ubicaciones de Palé… (35 líneas)"*), y la página de resultado da el detalle de cada línea, con la causa y qué hacer. Ver *TROUBLESHOOTING.md* para cada motivo.

Antes de lanzarlo: comprueba que los productos tienen rellenos el *Cód. palé por defecto* y la *Unidad de medida de venta*, con su cantidad, y que los huecos tienen *Admite* configurado.

**Al terminar** sale el resumen y la lista **Resultado de la carga inicial**: qué ha ido a cada hueco y, en la vista *No cargado*, lo que se ha quedado fuera y por qué.

**Ojo**:
- **Lánzalo primero con *Solo simular***. Hace el reparto completo, enseña la misma lista hueco a hueco y lo deshace todo. Lo que veas es exactamente lo que hará.
- **Para relanzarlo** (por ejemplo, tras crear más huecos o completar unidades de medida), marca *Omitir productos que ya están ubicados* para no duplicar.
- En los modos *Ubicación fija* e *Ubicación indicada* no se comprueba capacidad ni UM: es una carga de arranque y se corrige después con *Trasladar*.

Filtros útiles: *Nº*, *Categoría* y *Grupo contable inventario* del producto, para cargar por partes.

---

## Día a día: operaciones normales

### Pregunta 1: ¿Dónde recojo este producto?
**Dónde**: *¿Dónde está el producto?*, en la barra de navegación del rol *Almacén SGA*.

Buscas por producto, y te dice **todas las ubicaciones donde hay stock**, ordenado por **caducidad** (FEFO: First Expires First Out) y luego por **recorrido dentro del almacén** (para minimizar movimientos).

Cada línea te muestra:
- Ubicación y zona.
- Lote y caducidad.
- Cantidad disponible (no la que está reservada para otros picking).
- Si está bloqueada.

Puedes filtrar por:
- Lote específico.
- Solo lo disponible (oculta lo bloqueado).
- Un almacén específico (si tienes varios).

### Pregunta 2: ¿Dónde coloco este producto que entra?
**Dónde**: *Ubicar producto*, en la barra de navegación del rol *Almacén SGA*.

Esta pantalla te dice dónde dejar la mercancía que acabas de recibir, y registra la ubicación cuando la confirmas.

1. Indicas **producto, lote, caducidad y cantidad**, en la unidad que quieras (botellas, cajas, palés). O pulsas **Ubicar todo lo pendiente**, que pone todo lo que falta por ubicar de ese producto.
2. Pulsas **Proponer ubicación**. SGA **reparte** la cantidad con tres unidades del producto, las de su ficha:
   - **Palé por defecto**: cada palé completo, uno a uno, a un hueco de palé ("Palé 1 de 2").
   - **Unidad de venta** (CAJA12…): las que sobren, juntas, a un hueco de caja.
   - **Unidad base** (botella): solo lo que no llega a una unidad de venta.

   Otras unidades del producto no entran en el reparto. *Equivale a* enseña el pendiente con el mismo desglose: 690 botellas con palé de 540 y CAJA12 son *1 PALE, 12 CAJA12, 6 BOTELLA*.
3. **El resultado sale en la tabla *Dónde dejarlo***, una línea por parte:

   | Qué | Cantidad | Unidad | Ubicación propuesta | Ubicación confirmada | Estado | Motivo |
   |---|---|---|---|---|---|---|
   | Palé 1 de 1 | 1 | PALE | A-01-03-1 | A-01-03-1 | Pendiente | Primer hueco vacío… |
   | Unidades de venta | 12 | CAJA12 | | | **No se puede ubicar** | No hay ninguna ubicación de caja… |
   | Unidades sueltas | 6 | BOTELLA | M-01-01-1 | M-01-01-1 | Pendiente | … |

   Ningún hueco se propone dos veces. Lo que no tiene sitio sale en rojo como **No se puede ubicar**, con el motivo.
4. Si dejas algo en otro hueco, **escanea o teclea la ubicación real** en *Ubicación confirmada* de esa línea.
5. **Confirmar todo** registra las líneas con ubicación; las que no tienen sitio se quedan como están. **Confirmar esta línea** registra solo la seleccionada. Lo ubicado pasa a *Ubicado* (verde) y lo que queda pasa a la cantidad, para volver a proponerlo cuando haya sitio.

Si el reparto da **una sola línea** con hueco, la pantalla te pregunta directamente si la ubicas.

**Si no encuentra sitio**, el motivo dice qué falta configurar:
- **No existe ninguna ubicación de esa clase** (por ejemplo, de caja): te explica cómo crear una (ficha de la ubicación → *Admite* = Caja, *Acepta múltiples productos*, *Capacidad* en cajas).
- **Existen, pero son de muelle, cuarentena u otro uso**: solo se proponen las de tipo *Picking* o *Reserva*.
- **Existen, pero ninguna tiene sitio**: llenas, bloqueadas, con otro producto o con otro lote (el motivo tiene en cuenta el lote que estás ubicando).

**El orden de recorrido** ("ruta de picking") es el campo **Secuencia picking** de cada ubicación. Se calcula solo al generarlas a partir del código: primero el pasillo, luego el hueco y luego el nivel (A-01-01-1, A-01-01-2… A-01-02-1…). Si quieres que unos huecos se llenen antes que otros, cambia su *Secuencia picking* en la ficha: cuanto menor, antes.

Al confirmar, la mercancía queda registrada en el contenido de esa ubicación y se apunta una línea en el diario de movimientos.

**Cómo decide la propuesta**: según la *Estrategia de ubicación* que tengas en la configuración.

| Estrategia | Qué hace |
|---|---|
| Estándar | La casa del producto; si no, consolidar donde ya lo haya; si no, primer hueco libre |
| Priorizar consolidación | Primero agrupa con lo que ya hay; si no cabe, hueco libre |
| Solo ubicación fija | Únicamente la casa del producto; si no cabe, no propone |
| Primera libre por ruta | El primer hueco libre siguiendo el recorrido físico |

En todos los casos descarta las ubicaciones bloqueadas, las que no tienen capacidad para la cantidad y las que incumplen las reglas de mezcla de producto o de lote.

**Si te desvías**: si dejas la mercancía en un sitio distinto del propuesto, la pantalla te avisa. Que se admita o no depende de *Permitir desvío de ubicación* en la configuración. Con *Exigir confirmar ubicación* activo, no puedes confirmar sin haber pedido antes una propuesta.

### Pregunta 2 bis: ¿Dónde coloco lo que ha llegado hoy?
**Dónde**: *Ubicar recepciones* y *Ubicar ensamblados*, en la barra de navegación del rol *Almacén SGA*.

*Ubicar producto* sirve para una cosa suelta. Estas dos pantallas sirven para **todo lo que ha entrado en un día** de golpe: las recepciones de compra registradas o los embotellados registrados.

1. Ajusta los **filtros de arriba** (se pueden tocar nada más abrir):
   - **Registrado desde / hasta**: rango de fechas de registro. En blanco, sin límite. En *Ubicar recepciones* se abre **sin fechas**, así que salen todas las recepciones que aún tienen stock y no están ubicadas; en *Ubicar ensamblados*, el día de trabajo.
   - **Clase de artículo**: la de la ficha del producto, a elegir entre *Prod. propio* y *Prod. externo*. En recepciones sale por defecto **Prod. externo**; *Todas* para no filtrar.
   - **Producto**: solo las entradas de ese producto. En blanco, todos.
   - **Almacén** y **Solo lo que falta por ubicar**.
2. Sale una línea por cada cosa que ha entrado. En las recepciones es una por albarán, producto, lote y unidad de medida; en los ensamblados, una por ensamblado.
3. Pulsas **Proponer ubicaciones**. El sistema reparte las líneas entre huecos **sin dar el mismo hueco a dos líneas**. Si una propuesta no te convence, *Otra ubicación*.
4. Dejas la mercancía, corriges la *Ubicación confirmada* si la has dejado en otro sitio, y pulsas *Confirmar esta línea* o *Confirmar todo*.

Puedes ubicar una línea **en varias veces** bajando la cantidad *A ubicar*. Lo que ya está colocado se sabe por el diario, así que puedes cerrar la pantalla y volver más tarde: solo saldrá lo que falta.

**Cómo decide**: con *Estrategia ubicación compras* para las recepciones (por defecto la estándar) y *Estrategia ubicación ensamblados* para lo producido (por defecto solo huecos vacíos).

**Si deshaces una recepción** en BC, la cantidad que se ha deshecho se descuenta sola de la línea. Si ya la habías ubicado, sácala de la ubicación con un recuento.

### Pregunta 2 ter: ¿Cómo ubico los palés según salen de la línea?
**Dónde**: *Imprimir y ubicar palés*, en la barra de navegación del rol *Almacén SGA* y en el menú **SGA** del rol *Procesador de pedidos*.

Es la pantalla *Impresión Etiquetas Producción* con un paso más: **cada etiqueta que imprimes deja ese palé ubicado**. Así no hace falta esperar a que se registre el ensamblado ni pasar luego por *Ubicar ensamblados*.

1. Salen las tareas de hoy que aún tienen etiquetas por imprimir. Elige la que está en línea.
2. Arriba, en **Siguiente palé**, ves la **Ubicación** en la que dejarlo, por qué se propone ahí, cuánto lleva el palé y cuánto lleva ubicado ya el ensamblado.
3. Si no te convence, **Otra ubicación**. Si lo dejas en otro hueco, escanéalo o tecléalo en *Ubicación*.
4. **Imprimir y ubicar**: sale la etiqueta y el palé queda en esa ubicación. La pantalla te propone en el momento el hueco del siguiente.

No hay forma de imprimir sin ubicar: cada etiqueta es un palé ubicado.

**Qué se necesita**: la tarea tiene que tener un **pedido de ensamblado enlazado**, porque el palé se apunta a ese ensamblado. Así, cuando se registre, *Ubicar ensamblados* ya sabe lo que está colocado y solo pide lo que falte. Si la tarea no tiene ensamblado, en *Situación* lo verás en rojo y no se podrá imprimir desde aquí.

**Cuánto es un palé**: lo dice la tarea. Cada etiqueta es un palé de su *Palé* por defecto, completo, salvo el **último**, que lleva lo que queda de lo planificado. El palé completo se ubica como palé. El incompleto se ubica **en cajas**: a un hueco de caja si son menos de 10 y a uno de palé si son 10 o más. Si sobran botellas que no llegan a una caja, la pantalla avisa y quedan para *Ubicar producto*. La pantalla dice en *Situación* si el palé es completo o incompleto.

**No te deja imprimir** si el producto no tiene códigos de barras, si la producción no ha empezado o si ya están impresas todas las etiquetas planificadas (la pantalla antigua dejaba sacar una de más).

**En Sandbox** no se manda nada a BarTender: la etiqueta sale en formato **A5**, directa a la impresora que tenga asignada el report *Etiqueta Producto A5* en **Selección de impresoras** (Universal Print). Si no tiene impresora asignada, BC descarga la etiqueta en PDF. Si la etiqueta no llega a salir, el palé no se ubica.


### Pregunta 2 quater: ¿Qué se ha quedado sin ubicar?
**Dónde**: *Pendiente de ubicar*, en la barra de navegación del rol *Almacén SGA* y en tu menú *Almacén SGA*.

Enseña el stock que no está en ninguna ubicación, **lote a lote**, calculado al abrir (no hace falta conciliar). Por cada lote:
- **A ubicar aquí** y su **desglose** (*2 PALE, 5 CAJA12, 6 BOTELLA*): lo que se ubica desde esta página.
- **En recepciones o ensamblados** (en ámbar): lo que está pendiente en *Ubicar recepciones* o *Ubicar ensamblados*. Se ubica desde allí; desde aquí no, para que esas pantallas no lo vuelvan a pedir.

Acciones:
- **Ubicar**: abre *Ubicar producto* con producto, lote, caducidad y cantidad ya puestos. Pulsas *Proponer ubicación* y confirmas, o cambias el hueco a mano.
- **Ubicar seleccionadas**: busca hueco para varias líneas a la vez, con las mismas reglas que la carga inicial (palés a palé, cajas a caja o a palé según cuántas sean, botellas a *Unidad*). Se puede **simular** antes. Al terminar enseña lo ubicado y, de lo que no cabe, el motivo.
- **Dónde está el producto**, **Movimientos del producto**, **Ubicar recepciones** y **Ubicar ensamblados**.
### Pregunta 3: ¿Cómo preparo un pedido de venta?
**Toda salida de venta pasa por picking.** El circuito tiene tres pasos: oficina envía el pedido a picking, el preparador lo recoge y lo recogido vuelve solo al pedido.

**1. Oficina: enviar a picking.** En el *Pedido de venta*, pestaña **Almacén SGA** de la barra de acciones (junto a *Proceso*) > **Enviar a picking**. No uses las acciones de almacén estándar de BC (*Crear ubicación/picking de existencias*, *Crear envío de almacén*): con SGA, la salida va siempre por esta pestaña. En la misma pestaña están *Órdenes de picking*, *Pasar picking al pedido* y *Movimientos de ubicación*.

- El pedido tiene que estar **lanzado**.
- No puede tener **otra orden de picking abierta**. Si la hay, termínala o cancélala primero.
- Por cada línea busca dónde está el producto y genera una **parada** por cada ubicación y lote que hay que coger.
- Lo que va a coger cada parada queda **reservado** en su ubicación: otro pedido ya no lo verá como disponible.
- Si el pedido ya se preparó en parte, solo manda a recoger **lo que falta**.

**1 bis. Responsable: asignar.** En *Asignar órdenes de picking* salen las órdenes vivas con su cliente, fecha de envío (en rojo si ya toca), paradas y unidades pendientes.

- Selecciona una o varias y pulsa **Asignar a** para dárselas a un preparador. También puedes teclear el preparador en la línea.
- **Quitar asignación** las devuelve a la bolsa, si no se han empezado. Una orden empezada se puede reasignar a otro, pero no dejar sin nadie.
- **Prioridad**: cuanto mayor, antes le sale al preparador. *Subir prioridad* y *Bajar prioridad* actúan sobre las seleccionadas.

Si este paso es obligatorio o no lo decide **Exigir asignación de picking**, en *Configuración SGA* > *Controles*:

| | Desactivada (por defecto) | Activada |
|---|---|---|
| Al enviar a picking, la orden nace… | *Abierta* | *Pendiente de asignar* |
| *Siguiente orden* le da al preparador… | las suyas y, si no tiene, la siguiente sin asignar | solo las suyas |
| *Asignármela* y *Preparar* una orden ajena | sí (pregunta si era de otro) | no: solo el asignado |
| *Asignada a* y *Prioridad* en la ficha | editables | solo desde *Asignar órdenes de picking* |
| Quién puede repartir y cambiar prioridades | cualquiera | solo los **responsables de picking** |

**Quién es responsable de picking**: el usuario que tenga marcada la casilla **Responsable picking SGA** en *Configuración de usuarios*. Al resto, con la asignación exigida, *Asignar órdenes de picking* no le deja ni entrar.

Para los permisos hay dos conjuntos: **PermissionSet-SGA** para los preparadores y **SGA - Responsable de almacén** para los responsables (incluye el anterior más la pantalla de asignación). Asignar el conjunto ayuda a ordenar, pero lo que de verdad decide es la casilla: márcala siempre a los responsables.

**2. Preparador: recoger.** En *Órdenes de picking* tiene:

- **Siguiente orden**: abre la siguiente que le toca, por prioridad: primero las suyas sin terminar y, si no exige asignación, la siguiente sin asignar. Es el botón del día a día.
- **Mis órdenes** y las vistas *Pendientes* y *Sin asignar*, para ver qué hay.
- **Preparar** sobre una orden concreta. Si no tenía preparador, pasa a ser suya; si era de otro, pregunta antes. Con *Exigir asignación*, solo puede prepararla el asignado.

La pantalla de preparación le va diciendo, parada a parada:

- **A qué ubicación ir** (en grande).
- **Qué producto y qué lote** coger, con su caducidad.
- **Cuánta cantidad, en la unidad del pedido** (cajas, palés…). Si no es la unidad base, debajo sale también en unidades.

El preparador **escanea o teclea la ubicación de la que recoge**, ajusta la cantidad si ha cogido menos (también en la unidad del pedido) y pulsa *Confirmar recogida*. Ahí el stock sale de la ubicación, se libera su reserva y queda la huella en el diario. Luego pasa sola a la siguiente parada.

**Certificar el hueco con el dígito de control.** Si en *Configuración SGA* > *Controles* está activo **Exigir dígito de control al recoger**, en cada parada aparece el campo **Dígito de control**: el preparador teclea el número grande de la etiqueta del hueco del que recoge. Si no coincide, no deja confirmar. Como ese número solo está en la etiqueta (es al azar y distinto en cada hueco), certifica que el preparador está delante del hueco y no ha tecleado el código de memoria. Si se desvía a otro hueco, vale el dígito de ese otro hueco.

También puede **saltar** una parada para dejarla al final, o marcar **No hay stock aquí** si el hueco está vacío: esa parada se cancela, se libera su reserva y queda constancia para revisar el hueco.

**Mientras se prepara: cantidad preparada.** En las líneas del pedido de venta, la columna **Cantidad preparada** (delante de *Cantidad a enviar*) dice cuánto se ha recogido ya en las órdenes de picking de esa línea, en su unidad de medida. Se actualiza parada a parada. No es la cantidad a enviar: esa se rellena después, al terminar la preparación. Si no la ves, añádela con *Personalizar*.

**¿Está preparado el pedido?** En la cabecera del pedido de venta (junto a *Estado*) y en la *lista de pedidos* sale el **Estado preparación SGA**, calculado sobre lo que queda por enviar:

| Estado | Cuándo |
|---|---|
| **Preparado** | Todas las líneas tienen recogido al menos lo que les queda por enviar: listo para registrar el envío |
| **Parcial** | Algo está recogido, pero no todo |
| **Sin preparar** | No hay nada recogido de lo pendiente |
| *(en blanco)* | El pedido no tiene nada pendiente de enviar |

En la *lista de pedidos*, pestaña **Almacén SGA**: **Ver preparados**, **Ver preparados en parte** y **Ver todos**. Ojo: una orden de picking *Finalizada* no significa pedido *Preparado*; si faltaba stock al crearla o se marcó *No hay stock aquí*, el pedido queda *Parcial*.

**3. Automático: vuelta al pedido.** Al terminar la última parada, SGA rellena en el pedido de venta:

- La **cantidad a enviar** de cada línea: lo recogido y aún no enviado. Las líneas sin recoger quedan con cantidad a enviar **cero**, porque lo que no ha pasado por picking no sale.
- El **seguimiento por lote**: los lotes que han salido de las ubicaciones, con sus cantidades.

Después oficina registra el envío como siempre. Si el paso al pedido falla (por ejemplo, porque la línea tiene reservas por lote), el preparador ve el aviso y no pierde nada. Oficina lo repite con **Pasar al pedido** desde la orden, o con **Pasar picking al pedido** desde el pedido. La vista *Terminadas sin pasar al pedido* de *Órdenes de picking* enseña las que faltan.

**Cómo decide de dónde coger**: según la *Estrategia de picking* de la configuración.

| Estrategia | De dónde coge primero |
|---|---|
| FEFO | El lote que antes caduca |
| FIFO | El que lleva más tiempo en la ubicación |
| Vaciar ubicación | Agrupa por ubicación, para dejar huecos libres |
| Lote exacto | Se comporta como FEFO al generar la orden, pero cada parada dice el lote concreto |

Nunca propone ubicaciones bloqueadas ni contenido bloqueado, y solo cuenta la **cantidad disponible** (descontando lo reservado).

**Si no hay stock ubicado suficiente**, la orden se crea igual con lo que haya y te avisa de cuántas unidades han quedado sin asignar: es mejor preparar lo que existe que no preparar nada.

### Traslada contenido entre ubicaciones
**Dónde**: *Contenido de ubicaciones*, en la barra de navegación del rol *Almacén SGA*.

Ves todo el contenido del almacén. Selecciona una línea y pulsa *Trasladar*:
- Dices cuánto trasladas (por defecto, todo).
- Seleccionas la ubicación de destino.
- Pulsas OK.

El movimiento **deja rastro inmediato** en el diario, y **la ocupación se recalcula al momento**.

### Bloquea y desbloquea ubicaciones
En la misma página, acciones *Alternar bloqueo*: marca la ubicación como **bloqueada** (ej: porque está esperando QC, o porque vence en pocos días). Puedes poner un motivo: "En cuarentena" o "Vencimiento próximo".

Mientras está bloqueada, no se puede picking de ahí.

### Quita mercancía de una ubicación (deshacer una ubicación)
**Dónde**: *Contenido de ubicaciones* > acción **Quitar de la ubicación**.

Selecciona una o varias líneas y pulsa la acción. Cada línea sale **entera** de su ubicación y queda un movimiento de salida en el diario ("Quitado de la ubicación: pendiente de ubicar").

**El stock de BC no cambia**: la mercancía sigue en el almacén, solo que sin ubicación. Vuelve a aparecer como pendiente en *Ubicar producto* (botón *Ubicar todo lo pendiente*) y en la conciliación como *sin ubicar*, hasta que la vuelvas a colocar.

No deja quitar lo que esté reservado por una orden de picking: cancela antes la orden o su parada.

**Vaciar una ubicación entera.** Para sacar de golpe todo lo que hay en un hueco:
- En la **ficha de la ubicación**, acción **Vaciar ubicación**.
- En el **mapa 3D**, **clic derecho** sobre el bloque: sale la lista de lo que contiene para confirmar.

Todo el contenido queda **sin ubicar** (la "zona de nadie"): no está en ningún hueco, pero sigue en el stock de BC, y vuelve a salir como pendiente en *Ubicar producto* y como *sin ubicar* en la conciliación hasta que se recoloca. Es todo o nada: si alguna línea está reservada por una orden de picking, no se vacía nada.

### Recuenta el contenido
**Dónde**: *Contenido de ubicaciones* > acción *Recontar*

El operario mete lo que contó. SGA calcula la diferencia y la registra. Si hay **falta**, te avisa. Si hay **exceso**, registra la diferencia pero no la regulariza sola (ver apartado "Control").

---

## Control: evita que SGA se degrade

### La conciliación: comparar SGA vs BC
**Dónde**: *Conciliar con el stock*, en *Almacén SGA* > **Tareas periódicas**.

Este informe es **crítico**: compara el stock que tiene BC con el contenido de las ubicaciones. Si no cuadran, algo se rompió (error manual, bug, falta de sincronización).

Muestra:
- **Qué falta por ubicar**: stock en BC que no está en ninguna ubicación. SGA intenta regularizarlo automáticamente (lo mete en la ubicación de ajustes).
- **Qué sobra**: contenido en ubicaciones que no existe en BC. **Requiere recuento manual**: no se auto-regulariza.
- **Cuadra perfecto**: stock y contenido coinciden.

**Frecuencia**: lanza esto cada vez que:
- Recibas una compra (para comprobar que la carga inicial la metió bien).
- Hayas hecho cambios manuales en BC sin avisar a SGA.
- Alguien reporte "no encuentro el producto".

### Ver el resultado de la última conciliación
**Dónde**: *Conciliación SGA vs stock*, en *Almacén SGA* > **Control**.

Aquí están todas las diferencias que encontró la última ejecución. Puedes filtrar por:
- **Solo diferencias**: oculta lo que cuadra.
- **SobraEnSGA**: ubicaciones con contenido que no debería existir.
- **SinUbicar**: stock de BC que falta por repartir.

Desde aquí puedes regularizar directamente (para faltas; para excesos tienes que reccontar).

### El diario de movimientos
**Dónde**: *Movimientos de ubicación*, en *Almacén SGA* > **Control**.

Registro inmutable de **toda** entrado/salida/traslado en SGA. Cada línea tiene:
- Qué tipo de movimiento (Entrada, Salida, Traslado, Ajuste, Recuento).
- De dónde a dónde.
- Qué producto, lote, caducidad, cantidad.
- Quién lo hizo y cuándo.

Es útil para:
- Auditoría: "¿Quién sacó 50 cajas de la ubicación X?".
- Reconstrucción: si la tabla de contenido se corrompe, se regenera leyendo este diario.

### Análisis ABC: qué productos rotan más
**Dónde**: *Análisis ABC*, en *Almacén SGA* > **Control** (y en el menú *Almacén SGA - Consultas* del rol *Procesador de pedidos*).

Clasifica los productos por los **palés que salen**: **A** los que más, **C** los que menos. **Solo informa**: no cambia ninguna ubicación. Sirve para decidir si en el futuro conviene ubicar por rotación (ver [ESTRATEGIAS_UBICACION.md](ESTRATEGIAS_UBICACION.md)).

1. Se abre con el último cálculo del almacén por defecto. Pulsa **Calcular ahora** para hacer uno nuevo con las ventas y los palés de hoy.
2. Arriba, el **resumen**:
   - **Concentración**: "El 20 % de los productos hace el X % de los palés salidos". Es la cifra clave: cuanto más alta, más rendiría ubicar por rotación.
   - **Clases**: productos de cada clase.
   - **Huecos**: cuántos palés están en un hueco de su clase. Los mejores huecos son los de abajo y los primeros en la secuencia de picking.
   - **Avisos**: productos sin unidad de palé, que no se pueden clasificar bien.
3. Debajo, un producto por línea, **de más a menos palés salidos**, con el % acumulado. La clase va en verde (A), ámbar (B) o gris (C). En rojo: la *clase anterior* si ha cambiado y los *palés en hueco de su clase* si hay alguno fuera de su clase.
4. **Mostrar** filtra la lista: solo A, B o C, los que cambian de clase o los que tienen palés fuera de su clase.

**Cálculos anteriores** guarda todos los cálculos, para ver cómo evoluciona. Desde ahí se abre uno antiguo o se borran los que sobren.

**Parámetros** en *Configuración SGA* > **Análisis ABC**: días de ventas que se miran (90) y cortes de clase (A hasta el 80 %, B hasta el 95 %).

**Automático**: se puede programar en la *cola de proyectos* con el codeunit **51107** "Analisis ABC SGA". Calcula el almacén por defecto de la configuración.

---

## Visualización: entender el almacén de un vistazo

### Ubicaciones SGA (lista con semáforo)
**Dónde**: *Ubicaciones SGA*, en la barra de navegación del rol *Almacén SGA*.

Todas las ubicaciones con **semáforo visual**:
- 🟢 Verde: vacía.
- 🟡 Amarillo: con hueco.
- 🔴 Rojo: llena.
- 🚫 Gris: bloqueada.

Cada línea muestra:
- Ubicación, zona, tipo.
- Capacidad y ocupación actual.
- Líneas de contenido (cuántos productos diferentes hay).
- Cuándo se tocó última vez.

Vistas rápidas: *Vacías* / *Parciales* / *Llenas* / *Bloqueadas*.

### Mapa de nave
**Dónde**: *Mapa de almacén*, en *Almacén SGA* > **Almacén**.

Rejilla visual de la nave. Cada celda es una ubicación, coloreada por estado:
- Verde: vacía.
- Amarillo: parcial.
- Rojo: llena.
- Gris: bloqueada.

Al pulsar una celda, ves el detalle: qué hay dentro y sus cantidades.

**Verlo como un alzado**: filtra por *Estantería* y verás ese pasillo de frente: los huecos en horizontal (1 a 31) y las alturas en vertical, con la altura más alta arriba. Es la vista natural para ir a buscar algo.

**Se actualiza solo**: el mapa se reconstruye cada vez que lo abres leyendo las ubicaciones que hay en ese momento. Si añades o quitas estanterías, se refleja sin tener que hacer nada.

**Límite**: 32 columnas en pantalla, configurable en *Columnas mapa*. Si una nave tiene más huecos que eso, el mapa te avisa.

### Mapa 3D
**Dónde**: *Mapa 3D de almacén*, en *Almacén SGA* > **Almacén**.

El almacén en volumen: cada ubicación es un bloque colocado en su estantería, su columna y su altura, con el mismo código de colores.

- **Arrastrar** gira el almacén; **Mayús + arrastrar** lo desplaza; la **rueda** acerca y aleja **hacia donde apunta el ratón**. El botón *Girar 45°* gira de golpe.
- **Pasar por encima** de un bloque abre una **ficha con lo que hay dentro**. Por cada línea: la **descripción del producto** (y debajo su código, lote y caducidad), la **cantidad** y el **tipo de palé** del producto (el *Cód. palé por defecto* de su ficha). La cantidad sale como se cuenta en el almacén: en un **hueco de palé**, *1 PALE* si el palé está completo y, si no llega al 100 %, el **número de cajas** (por ejemplo *30 CAJA12 · PALE · 45 CAJA12/palé*); en un hueco de **unidades sueltas**, en **botellas**; en el resto, en **cajas**. Las líneas bloqueadas salen en rojo. Sale con cualquier zoom, aunque el almacén se vea entero. Si el hueco tiene más de 8 líneas, la ficha avisa de cuántas faltan.
- **Pulsar** un bloque abre el contenido de esa ubicación; **doble clic** aísla su pasillo; **clic derecho** lo vacía (ver *Vaciar una ubicación entera*).

**Trabajar por pasillo.** Al elegir un pasillo (desplegable *Pasillo*, botones **<** **>** o doble clic en un bloque) el mapa lo **encuadra solo**: lo agranda hasta llenar el lienzo. Con los bloques así de grandes se escribe encima el **producto** que contienen (y "+N" si hay más). *Centrar* vuelve a encuadrar lo que se está viendo; con *Todos*, el almacén entero.

**Trasladar arrastrando.** Activa el botón **Trasladar** de la barra (o mantén **Ctrl** pulsado) y arrastra un bloque con contenido hasta otro:

1. El origen se pinta en azul y el destino en amarillo, con una flecha entre los dos.
2. Al soltar, si el origen tiene varios productos o lotes, eliges cuál.
3. Sale el diálogo de traslado con origen y destino ya puestos; confirmas la cantidad (por defecto, todo lo disponible) y, si quieres, un motivo.
4. Se registra como cualquier traslado (queda en el diario) y el mapa se actualiza **sin perder el giro, el zoom ni el pasillo** que tenías.

Soltar fuera de un bloque o sobre el mismo origen no hace nada. Desde un bloque vacío no se puede arrastrar. Las reglas son las de siempre: si el destino está bloqueado, no tiene sitio o no admite ese producto, el traslado se rechaza con el motivo.

Sirve para lo que la rejilla no: ver de un golpe dónde se está llenando el almacén y qué pasillos están vacíos.

Igual que la rejilla, **se reconstruye al abrirlo**, así que los cambios de estanterías salen solos.

---

## Informes: exporta a Excel

### Inventario por ubicación
**Dónde**: *Inventario por ubicación*, en *Almacén SGA* > **Informes**.

Export completo a Excel de todo el contenido: producto, variante, lote, caducidad, cantidad, si está bloqueado, cuándo se tocó.

### Ocupación de ubicaciones
**Dónde**: *Ocupación de ubicaciones*, en *Almacén SGA* > **Informes**.

Excel con resumen de cada ubicación: capacidad, ocupación actual, porcentaje, cuántas están vacías/parciales/llenas/bloqueadas.

Útil para ver si necesitas más ubicaciones o si tienes capacidad ociosa.

---

## Conceptos importantes

### Lote y caducidad: la clave
**Todo se controla por lote y caducidad**. Es lo único que te permite separar un producto que entró en dos momentos diferentes. Si BC no tiene lotes/caducidades, SGA no funciona bien.

### Ubicaciones de palé y ubicaciones mixtas de caja
**Palé, caja y unidad salen de la ficha de cada producto**, sin configurar nada en *Unidades de medida*:
- el **Cód. palé por defecto** es el **palé** (y cualquier unidad igual de grande o mayor), se llame PALE, PALE200 o EUROPALE;
- la **Unidad de medida de venta** (CAJA12…) es la **caja**: lo que no llega a una caja son unidades sueltas;
- la **Unidad de medida base** (botella) es la **unidad**.

Cualquier otra unidad del producto no tiene clase: no se le propone hueco, y el motivo dice que hay que usar una de esas tres o revisar la ficha.

**Qué admite cada hueco** (ficha de la ubicación, apartado *Capacidad*, campo **Admite**; o en bloque con *Cambiar ubicaciones en bloque*):

| Admite | Qué se le propone | Qué acepta si el operario lo elige | Varios productos |
|---|---|---|---|
| **Palé** | Palés, y cajas de una referencia a partir de *Cajas mínimas para hueco de palé* (10) | Palés y cajas | No |
| **Caja** | Cajas sueltas, menos de 10, de cualquier referencia | Solo cajas | Sí |
| **Unidad** | Unidades sueltas (botellas) | Solo unidades sueltas | Sí |
| *(en blanco)* | **Nada**: una ubicación sin configurar no se propone | Palés y cajas, nunca unidades | No |

Las unidades sueltas **solo** pueden ir a ubicaciones de *Unidad*. El umbral de las cajas se cambia en *Configuración SGA* > **Cajas mínimas para hueco de palé**.

Cada ubicación declara **qué clase admite** (campo *Admite*) y **cuántos le caben** (campo *Capacidad*):

| Tipo de hueco | Admite | Capacidad | Acepta múltiples productos |
|---|---|---|---|
| De palé | Palé | 1 | No |
| Mixto de cajas | Caja | 72 | Sí |
| De unidades sueltas | Unidad | en unidades base | Sí |
| Sin configurar | (en blanco) | — | No: no se propone |

Reglas que aplica el sistema solo:

1. **Un hueco de palé admite cualquier palé**, se llame como se llame, y también **cajas de esa misma referencia** (un palé incompleto). Botellas sueltas no.
2. **La capacidad se cuenta en la clase del hueco.** *Capacidad 1* en un hueco de palé es **un palé del producto que entra**: 200, 300 o 1.200 unidades, según lo que diga su unidad de palé. En un hueco de caja, 72 son 72 cajas, cada una con lo que lleve la caja de su producto.
3. **Solo los huecos de caja y de unidad pueden ser mixtos.** La casilla *Acepta múltiples productos* solo se deja marcar si el hueco admite *Caja* o *Unidad*.

**El palé, la caja y la unidad de cada producto** salen de su ficha: el *Cód. palé por defecto*, la *Unidad de medida de venta* y la *Unidad de medida base*. Por qué se decidió así, y las reglas de qué va a cada hueco, están en [ESTRATEGIAS_UBICACION.md](ESTRATEGIAS_UBICACION.md).

Cuando generas ubicaciones, nacen con el **Tipo de hueco al generar** de la configuración (por defecto *Palé*) y de un solo producto. Las mixtas de caja se marcan después, una a una, en su ficha.

**Ubicación de botellas sueltas.** Para las botellas que no llegan a una caja, de cualquier producto, basta una ubicación con *Admite* = **Unidad** (vacía, de tipo *Picking* o *Reserva*). Al poner *Unidad* (o *Caja*) se marcan solas **Acepta múltiples productos** y **Acepta múltiples lotes**. Con *Capacidad* 0 no tiene límite; si se pone un número, son botellas. Desde ese momento, *Ubicar producto* y la carga inicial mandan ahí las sueltas.

### El Shelf No. de la ficha del producto
Si en la **ficha del producto** pones un **Shelf No.** (ubicación fija), SGA dirá: "Este producto siempre va aquí". Es útil para productos que necesitan una ubicación específica (ej: piezas de repuesto que siempre guardan en el mismo sitio).

Si no pones Shelf No., la ubicación se decide por estrategia cuando entra nuevo stock.

### Disponible vs Reservado
- **Disponible**: cantidad que hay menos la que ya alguien cogió (está en un picking que sale hoy).
- **Cantidad bruta**: lo que hay, punto.

Al enviar un pedido a picking, lo que se va a coger se marca como "Reservado" pero **no sale de la ubicación**. Sale cuando el preparador confirma la recogida.

### Un traslado no genera IIEE
Trasladar desde ubicación A a ubicación B es **solo organización**. El stock en BC sigue siendo el mismo, en el mismo almacén. No afecta costes ni ledger.

### Movimientos inmutables
El diario de movimientos **no se puede editar ni borrar**. Es la fuente de verdad de SGA. Si alguien comete error, se registra un **movimiento de ajuste** que lo compensa.

---

## Límites y lo que no hace (aún)

### Las entradas se ubican a mano, no al registrar
Cuando registras una recepción o un ensamblado, SGA **no la coloca en el momento**: queda pendiente en *Ubicar recepciones* o *Ubicar ensamblados* hasta que alguien la confirma. Es a propósito: si un hueco estuviera lleno o bloqueado, el registro del albarán en BC fallaría. Mientras no se ubica, la conciliación lo enseña como *SinUbicar*.

### La orden de picking no se crea sola
Hay que enviarla desde el pedido de venta con *Enviar a picking*. Si alguien cambia a mano la cantidad a enviar o los lotes después del paso al pedido, SGA no lo sabe: lo que salga de BC sin haber salido de una ubicación lo enseña la conciliación como *SobraEnSGA*.

### No maneja PDA (Fase 3)
Los operarios en planta usan PDA. SGA aún no tiene páginas de PDA integradas. Por ahora, es de escritorio.

### No auto-regulariza el exceso
Si el recuento te da 50 cajas y solo había 40, SGA te avisa pero **no crea las 10 de más**. Tienes que investigar: ¿son robo? ¿son un error de entrada? ¿un lote que falta registrar? Una vez sabes qué pasó, lo ajustas a mano.

### Capacidad opcional
La capacidad de cada hueco es opcional y se cuenta en la clase que admite (1 = un palé, 72 = setenta y dos cajas). Con capacidad 0 el hueco no tiene límite: SGA no controla si se llena y podría juntar varios palés en él.

---

## Flujo típico de un día

1. **Llega una compra**. Se registra la recepción en BC como siempre. Abres *Ubicar recepciones* y pulsas *Proponer ubicaciones*.
2. **Dejas la mercancía** donde te dice, corriges la ubicación si la has dejado en otro sitio y confirmas. Ya está registrada.
3. **Entra un pedido de venta**. Se lanza y, desde el pedido, *Almacén SGA > Enviar a picking*.
4. **El preparador pulsa *Siguiente orden*** en *Órdenes de picking*. Va parada a parada: ubicación, producto, lote y cantidad en la unidad del pedido. Escanea cada ubicación y confirma lo recogido.
5. **Al terminar**, el pedido ya tiene la cantidad a enviar y los lotes. Oficina registra el envío.
6. **Al final del día**: lanzas *Conciliar con el stock* para comprobar que todo cuadra.
7. **Si hay diferencia**: la regularizas (si es falta) o investigas (si es exceso).

---

## ¿Y si algo falla?

### "No encuentro el producto que debería estar aquí"
- Abre *¿Dónde está el producto?* y búscalo.
- Si aparece pero con otro lote/caducidad, es ese.
- Si no aparece: lanza *Conciliar con el stock* para ver si falta por ubicar.

### "La ocupación de una ubicación no suma"
- Entra en la ficha de la ubicación y pulsa *Recalcular estado*.
- Recalcula en vivo el contenido y la ocupación.

### "Alguien movió cosas manualmente en BC y SGA no lo sabe"
- Lanza *Conciliar con el stock*.
- Pulsa *Regularizar* sobre las faltas (SGA las mete en ajustes).
- Investiga los excesos y recuéntalos a mano.

### "Quiero reconstruir todo el contenido desde cero"
- Abre *Sincronizar ubicaciones*.
- Marca *Reconstruir contenido* (destruye el contenido actual y lo regenera desde el diario de movimientos).
- **Cuidado**: borra todo y reconstruye. Solo úsalo si algo se rompió.

---

## Resumen: SGA en 30 segundos

✅ **Decide**: dónde colocar lo que entra y de dónde coger lo que sale, y te dice por qué.

✅ **Mantén**: un diario inmutable de todos los movimientos, una conciliación diaria contra BC.

❌ **No hace (aún)**: ubicar sola la mercancía al registrar la compra o el ensamblado (hay que confirmarlo en *Ubicar recepciones* o *Ubicar ensamblados*), crear sola la orden de picking, operaciones de PDA, regularizar excesos.

🎯 **Beneficio**: si SGA y BC coinciden todos los días, sabes que tu visibilidad de almacén es real. Si no coinciden, lo descubres al momento.

---

## Ayuda rápida

| Necesito... | Voy a... |
|---|---|
| Configurar el almacén por primera vez | *Configuración SGA* (paso 1) |
| Crear ubicaciones de golpe | *Generar ubicaciones* |
| Ver dónde está un producto | *¿Dónde está el producto?* |
| Saber dónde colocar lo que entra | *Ubicar producto* |
| Colocar lo recibido o lo embotellado en el día | *Ubicar recepciones* / *Ubicar ensamblados* |
| Ver y ubicar lo que ha quedado sin ubicar | *Pendiente de ubicar* |
| Imprimir la etiqueta de un palé de la línea y ubicarlo | *Imprimir y ubicar palés* |
| Preparar un pedido de venta | Pedido de venta (lanzado) > *Enviar a picking* |
| Coger la siguiente orden a preparar | *Órdenes de picking* > *Siguiente orden* |
| Repartir el picking entre preparadores | *Asignar órdenes de picking* > *Asignar a* |
| Volver a pasar un picking al pedido | Orden > *Pasar al pedido* |
| Ver qué queda por preparar | *Órdenes de picking* |
| Mover contenido de una ubicación a otra | *Contenido de ubicaciones* > *Trasladar* |
| Bloquear una ubicación (vencimiento próximo, etc.) | *Contenido de ubicaciones* > *Alternar bloqueo* |
| Contar una ubicación manualmente | *Contenido de ubicaciones* > *Recontar* |
| Deshacer una ubicación equivocada | *Contenido de ubicaciones* > *Quitar de la ubicación* |
| Vaciar un hueco entero | Ficha de la ubicación > *Vaciar ubicación*, o clic derecho en el bloque del *Mapa 3D* |
| Comprobar si SGA y BC coinciden | *Conciliar con el stock* |
| Ver un mapa visual de la nave | *Mapa de almacén* |
| Ver el almacén en 3D | *Mapa 3D de almacén* |
| Mover mercancía de un hueco a otro sobre el plano | *Mapa 3D* > *Trasladar* y arrastrar |
| Decir qué cabe en un hueco (palé o cajas) | *Ubicaciones SGA* > *Cambiar en bloque* (o la ficha de la ubicación) |
| Cambiar qué unidad es el palé o la caja de un producto | Ficha del producto: *Cód. palé por defecto* y *Unidad de medida de venta* |
| Exportar inventario a Excel | *Inventario por ubicación* |
| Ver quién movió qué y cuándo | *Movimientos de ubicación* |

