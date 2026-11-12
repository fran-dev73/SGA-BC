# Guía de uso de SGA

Para quien trabaja con SGA cada día: oficina, responsable, preparador y carretillero. Cada uno
lee solo su apartado. Cómo se configura todo está en el [manual de implantación](MANUAL_IMPLANTACION_SGA.md).

## Antes de empezar

- Las pantallas de SGA llevan **SGA** en el título (*Órdenes de picking SGA*, *Preparar picking SGA*…). Lo que no lo lleva es de Business Central.
- Cada ubicación tiene un **tipo**:

| Tipo | Para qué es | Al ubicar |
|---|---|---|
| **Almacenamiento** | La reserva; de aquí salen las reubicaciones | Es lo primero que se propone |
| **Picking** | De donde se preparan los pedidos | Solo si no queda sitio en almacenamiento |
| *(en blanco)* | Muelles, ajustes… | Nunca se propone |

- Todo movimiento queda en **Movimientos de ubicación**, que no se edita ni se borra.

---

## 1. Oficina: pedidos de venta

**Toda venta sale por picking.** No uses las acciones de almacén estándar de BC.

### Enviar un pedido a SGA

1. Lanza el pedido.
2. En el pedido, pestaña **Almacén SGA**, pulsa **Enviar a SGA**.
3. SGA reparte el pedido en **órdenes de picking de un palé como mucho**, porque solo se prepara un palé a la vez:
   - cada palé completo de una línea es una orden;
   - las cajas y unidades sueltas de todas las líneas se juntan en órdenes que no pasan de un palé (½ palé de un producto y ¼ de otro van en la misma orden).

   Por ejemplo, 4 palés y 2 cajas son 5 órdenes.
4. Busca de qué ubicación y lote coger cada cosa y lo **reserva**: otro pedido ya no lo ve disponible.
5. Si el pedido ya se preparó en parte, solo manda lo que falta.

No deja enviarlo si el pedido no está lanzado, si tiene alguna orden de picking sin terminar o si algún producto no tiene palé en su ficha (*Cód. palé por defecto*).

**Un pedido enviado a SGA ya no se puede volver a abrir.**

### Si falta stock: dos rondas

Si no hay stock ubicado para todo:

- **Primera ronda.** Las órdenes se crean con lo que hay. El aviso dice, producto a producto, qué falta y cuánto, en la unidad del pedido. Solo da error si no hay nada ubicado de ningún producto del pedido.
- **Segunda ronda.** Cuando ya haya stock ubicado (porque ha llegado una compra o se ha ubicado lo pendiente) y estén terminadas todas las órdenes del pedido:
  - **Un pedido:** vuelve a pulsar **Enviar a SGA**. Solo manda lo que falta.
  - **Todos a la vez:** en **Órdenes de picking SGA**, pulsa **Segunda ronda de picking**. Crea las órdenes de cada pedido que aún tenga algo pendiente, ya tenga stock y no tenga órdenes sin terminar. Dice cuántas ha creado y cuántos pedidos siguen esperando.

Mientras tanto el pedido sale como **Parcial** en la lista de pedidos. Si se decide servirlo así, se registra el envío de lo preparado como siempre.

### Ver cuánto está preparado

- **Estado preparación SGA**, en la cabecera del pedido y en la lista: *Sin preparar*, *Parcial* o *Preparado*. En blanco si no queda nada por enviar.
- En la lista de pedidos, pestaña **Almacén SGA**: **Ver preparados**, **Ver preparados en parte** y **Ver todos**.
- En las líneas, la columna **Cantidad preparada** (si no se ve, añádela con *Personalizar*).
- Una orden *Finalizada* no siempre es un pedido *Preparado*: si faltaba stock o se marcó *Sin stock*, queda *Parcial*.

### Pasar al pedido

Al terminar la orden, SGA rellena solo la **cantidad a enviar** y los **lotes** de cada línea. Lo que no se ha recogido queda con cantidad a enviar cero. Después se registra el envío como siempre.

Si el paso falla, repítelo con **Pasar picking al pedido** (desde el pedido) o **Pasar al pedido** (desde la orden). La vista *Terminadas sin pasar al pedido* de *Órdenes de picking* enseña las que faltan. **No cambies a mano la cantidad a enviar ni los lotes**: SGA no se entera.

---

## 2. Responsable de almacén

### Asignar órdenes y prioridad

En **Asignar órdenes de picking SGA** salen las órdenes vivas con su cliente, fecha de envío y paradas pendientes.

- Vistas **Sin asignar** y **Asignadas**.
- **Asignar a**: da las seleccionadas a un preparador. También se puede teclear en *Asignada a*.
- **Quitar asignación**: las devuelve a la bolsa. Una orden empezada se puede reasignar, pero no dejar sin nadie.
- **Subir prioridad** / **Bajar prioridad**: cuanto mayor la *Prioridad*, antes sale.
- **Ver orden** y **Ver pedido**.

Si está activada *Exigir asignación de picking* (en la configuración):

| | Desactivada | Activada |
|---|---|---|
| La orden nace… | *Abierta* | *Pendiente de asignar* |
| *Siguiente orden* da… | las suyas y, si no tiene, la siguiente sin asignar | solo las suyas |
| *Asignármela* | disponible | no: reparte el responsable |
| Quién reparte y cambia prioridades | cualquiera | solo los responsables de picking |

### Paradas retenidas

Una parada que el preparador **salta dos veces** queda **retenida**: algo impide recogerla. El preparador ya no la ve, pero sigue pendiente, conserva su reserva y su orden no se termina.

- Se ven en la pila **Paradas retenidas** del rol center (grupo *Picking*), en la acción **Paradas retenidas** (lista *Paradas de picking SGA*, vista *Retenidas*) y en la columna y la vista *Con paradas retenidas* de **Órdenes de picking SGA**. En las paradas de la orden salen marcadas como *Retenida*, en rojo.
- La lista dice qué preparador la retuvo y cuándo. **Contenido de la ubicación** enseña qué hay en el hueco según SGA.
- **Buscar en otra ubicación** la resuelve: cancela la parada y crea paradas nuevas en otros huecos con stock del producto, igual que *Sin stock* en la PDA. Las nuevas vuelven al preparador de la orden, que la termina al recogerlas. Si no hay stock en ningún otro hueco, la parada queda cancelada.
- Lo recogido del resto de la orden ya está en el pedido: al terminar las paradas nuevas se vuelve a pasar sin duplicar nada.

### Pilas de picking

En el rol center de almacén, el grupo **Picking** cuenta, en el almacén por defecto de la configuración:

| Pila | Qué cuenta | Al pulsarla |
|---|---|---|
| Pendientes de asignar | Órdenes que esperan preparador | *Asignar órdenes de picking* |
| Sin empezar | Órdenes abiertas que nadie ha empezado | *Órdenes de picking* |
| En proceso | Órdenes que se están recogiendo | *Órdenes de picking* |
| Envío vencido (rojo) | Órdenes sin terminar con fecha de envío hoy o antes | *Órdenes de picking* |
| Paradas retenidas (rojo) | Paradas saltadas dos veces | *Paradas de picking*, con *Buscar en otra ubicación* |
| Terminadas sin pasar al pedido (rojo) | Órdenes de venta terminadas que no están en el pedido | *Órdenes de picking*, con *Pasar al pedido* |
| Reubicaciones pendientes | Movimientos de almacenamiento a picking por hacer | *Reubicaciones* |
| Terminadas hoy (verde) | Órdenes terminadas en la fecha de trabajo | *Órdenes de picking* |
| Desvíos de ubicación hoy | Paradas recogidas hoy en un hueco distinto del propuesto | *Paradas de picking* |

Las de órdenes no cuentan las reubicaciones, que tienen su propia pila.

En el rol center del preparador, **Mi picking** cuenta sus órdenes y sus reubicaciones sin terminar y, si la configuración no exige asignación, las órdenes sin asignar que puede coger.

Para cancelar una orden: *Órdenes de picking* > **Cancelar orden**. Libera lo reservado.

### Quién es quién

En **Configuración de usuarios**, en la línea de cada usuario:

- **Responsable picking SGA**: puede repartir órdenes y cambiar prioridades cuando se exige asignación. Es la casilla la que manda, no el conjunto de permisos.
- **Carretillero SGA**: con *Siguiente orden* recibe las reubicaciones y no los pedidos (ver apartado 4).

### Etiquetas de ubicación

Cada hueco tiene su etiqueta, y el picking lee en ella la ubicación de la que recoge. Las etiquetas deben estar pegadas antes de empezar a recoger. Se hace por pasillos:

1. En **Ubicaciones SGA**, filtra el pasillo y selecciona sus huecos.
2. **Imprimir etiquetas** y pega cada una en su hueco.

---

## 3. Preparador: preparar pedidos

### Con la pantalla de Business Central

1. Abre **Órdenes de picking SGA** y pulsa **Siguiente orden**. Abre la pantalla de preparación con la orden que te toca, por prioridad, primero las tuyas. Al terminarla pasa sola a la siguiente.
2. También puedes ver **Mis órdenes**, las vistas *Pendientes* y *Sin asignar*, **Preparar** (una orden concreta) y **Asignármela**.
3. En la pantalla **Preparar picking SGA** cada parada muestra:
   - **VAYA A**: la ubicación, en grande. En un pedido, al lado, **→ PLAYA** y la playa donde dejar lo recogido (la ubicación por defecto de la zona de playas). En una reubicación: **DE** origen **→ A** destino.
   - **COJA**: la cantidad, en la unidad del pedido. Debajo, la descripción del producto y, en pequeño, su código, el lote, la caducidad y la cantidad en unidades base.
   - **CONFIRME**: las marcas de lo que falta (*Ubicación*, *Producto*). Rojo es pendiente; verde, hecho.
4. Lee, en este orden, la **ubicación** de la etiqueta del hueco y, si se pide, el **producto** que coges. El cursor pasa solo a la casilla siguiente cuando la anterior está bien leída (se pone en verde). Cada lectura puede ser un escaneo o teclearse: toca la casilla que toca y escribe.
5. Si coges otra cantidad, cámbiala con **−** y **+** o tecleándola.
6. Cuando está completo, la parada **se confirma sola** y pasa a la siguiente.

Si una lectura no es correcta, la pantalla lo dice en rojo, con un pitido grave. Vuelve a escanear o a teclear.

**Otros botones:**

- **Saltar**: deja la parada para el final. Al acabar el recorrido vuelven a salir las saltadas. Si saltas una por segunda vez queda **retenida** para el jefe de almacén y ya no vuelve a salir. Cuando solo quedan retenidas, la orden se da por recorrida: lo recogido pasa al pedido y pasas a la siguiente orden.
- **Sin stock**: si el producto no está en el hueco. Pregunta si buscar en otra ubicación. Si sí, la parada se cancela y lo que faltaba se busca en otro hueco del mismo producto. La pantalla dice de dónde («*No estaba en 101-03-10. Se recoge de otra ubicación: 102-01-00*»). Si no hay en ninguna, el aviso sale en rojo. El hueco vacío no se corrige: hay que recontarlo.

Si recoges de otro hueco, avisa: que lo admita depende de la configuración de desvíos. Al terminar sale *Orden terminada*, la playa en la que dejarla y que lo recogido ya está en el pedido. Si dice que no se ha podido pasar al pedido, avisa a oficina: no se pierde nada.

**El producto se reconoce** por su código de barras, su GTIN o su nº de producto, y también por una etiqueta GS1-128 con (01) o (02). Si la etiqueta trae el lote (10), tiene que ser el de la parada.

**De dónde se recoge.** La orden se arma en tres pasadas: primero **palés completos** de almacenamiento, luego **picking**, y lo que falte del resto de almacenamiento. Dentro de cada pasada manda la estrategia de picking de la configuración:

| Estrategia picking | Qué se coge antes |
|---|---|
| **FIFO** (por defecto) | Lo que entró antes |
| **FEFO** | Lo que caduca antes |
| **Lote exacto** | Como FEFO; la parada dice el lote concreto |
| **Vaciar ubicación** | Por orden de código de ubicación, para ir dejando huecos vacíos |

### Con la PDA (terminal de mano)

Terminal Android con lector integrado y la app de **Business Central** instalada desde Google Play.

**Preparar el terminal (una vez).** En el programa del lector (en Zebra, *DataWedge*), crea un perfil para la app de Business Central con la salida por *Intent*:

| Ajuste | Valor |
|---|---|
| Intent delivery | Broadcast intent |
| Intent action | `com.businesscentral.barcode.receive_barcode` |
| Intent category | `com.businesscentral.barcode.receive_category` |
| Clave del dato (Honeywell, Datalogic) | `com.symbol.datawedge.data_string` |
| Clave del tipo (Honeywell, Datalogic) | `com.symbol.datawedge.label_type` |

En Zebra las claves ya son esas. Desactiva la salida por teclado del mismo perfil. Un lector que escribe como un teclado (de anillo, Bluetooth) también vale sin configurar nada.

**Trabajar:**

1. Entra con el rol **Preparador SGA (PDA)** y pulsa **Preparar pedidos SGA**. Se abre la orden que te toca. Al terminarla carga la siguiente; si no hay más, ofrece **BUSCAR SIGUIENTE ORDEN**.
2. Ve a la ubicación, coge el producto y **escanéalo**. Si no es el de la parada, lo dice al momento.
3. Escanea el **código de la ubicación** de la etiqueta del hueco. Si no se lee, tecléalo.
4. Si coges otra cantidad, cámbiala antes.
5. La parada se confirma sola y pasa a la siguiente.

El cursor está siempre en la casilla que toca leer (ubicación, producto), pero la pantalla no abre el teclado del terminal hasta que tocas una casilla.

---

## 4. Carretillero: reubicaciones

Una **reubicación** lleva mercancía de almacenamiento a picking. Se prepara igual que un pedido.

**Qué le llega:**

- Con **Carretillero SGA** marcado, **Siguiente orden** le da primero lo suyo y, si no tiene, la siguiente **reubicación** sin asignar. Nunca un pedido.
- Sin marcar, al revés: pedidos y nunca reubicaciones.
- **Lo que el responsable le asigna le llega siempre**, sea pedido o reubicación.

**Cómo se hace:** en la pantalla **Preparar picking SGA**, la primera línea dice **DE** origen **→ A** ubicación de picking. Recoge en el origen, confirma como cualquier parada y la mercancía pasa al destino. Si es un palé justo, la cantidad sale en palés.

**Cuándo se crean:**

- **Automáticamente, en cuanto una ubicación de picking se queda a cero de un producto**, sea por lo que sea: una recogida de venta, un traslado, *Vaciar ubicación*, *Quitar de la ubicación* o un ajuste. Se repone aunque el producto quede en otra ubicación de picking, salvo que ya haya una reubicación pendiente hacia ese hueco.
- Con **Planificar reubicaciones**, en la página *Reubicaciones SGA*: repasa el almacén y repone los productos que no tienen nada en picking, también los que nunca han tenido picking.

Hace falta stock disponible en almacenamiento; si no hay, no se crea. Trae como mucho un palé. Esa ubicación espera a su producto: no se propone a otro.

**Dónde se ven:** página **Reubicaciones SGA** (menú *Almacén SGA*): vistas **Por hacer** y **Hechas**, y las acciones **Planificar reubicaciones**, **Preparar**, **Cancelar** (libera la reserva) y **Orden**.

---

## 5. Entradas: ubicar lo que llega

Lo que entra por compra o por producción se ubica después de registrarlo. En todas las pantallas es igual: **proponer**, dejar la mercancía, corregir la *Ubicación confirmada* si se ha dejado en otro hueco, y **confirmar**. Una cantidad se reparte en palés completos por separado y un resto, en cajas o en botellas.

**Dónde busca:** primero en las ubicaciones de almacenamiento y, si ninguna sirve, en las de picking. Las que no tienen tipo, nunca.

### Cómo se elige el hueco

Dentro de almacenamiento (y luego de picking), el hueco concreto lo decide la **estrategia**. Solo se proponen huecos que admiten la mercancía: no bloqueados, con sitio, sin otro producto o lote si no aceptan mezcla. Junto a cada propuesta sale el **porqué** (*Ubicación fija del producto*, *Ya hay este producto ahí*, *Primer hueco con sitio*…).

| Estrategia | Qué hueco propone | Cuándo conviene |
|---|---|---|
| **Estándar** | Su casa (ubicación fija o la *Nº estante* de la ficha); si no, donde ya está el producto y cabe más; si no, el primer hueco con sitio del recorrido | La de uso general |
| **Priorizar consolidación** | Donde ya está el producto y cabe más; si no, el primer hueco con sitio | Huecos de varios palés, para no repartir un producto |
| **Solo ubicación fija** | Solo su casa. Si no tiene o no cabe, *No se puede ubicar* | Cada producto tiene su sitio y no se admiten excepciones |
| **Primera libre por ruta** | El primer hueco con sitio del recorrido | Llenar siempre desde los mejores huecos |
| **Solo hueco vacío** | El primer hueco **totalmente vacío** del recorrido | Palés de producción: cada palé a un hueco limpio |

El **recorrido** es la *Secuencia picking* de cada ubicación: cuanto menor, antes se propone.

Si el producto tiene **grupo IIEE** y ese grupo tiene zonas, se busca primero en esas zonas. Si no queda sitio, se busca en todo el almacén y el porqué avisa. Al ubicar o mover a mano a un hueco fuera de las zonas de su grupo, pide confirmación.

Qué estrategia usa cada pantalla:

| Pantalla | Estrategia | Por defecto |
|---|---|---|
| Ubicar recepciones | Estrategia de ubicación de compras | Estándar |
| Ubicar ensamblados e Imprimir y ubicar palés | Estrategia de ubicación de ensamblados | Solo hueco vacío |
| Ubicar producto y Mover contenido | Estrategia de ubicación | Estándar |
| Carga inicial y *Ubicar seleccionadas* | Fija, no se configura | Ver [implantación](MANUAL_IMPLANTACION_SGA.md#7-carga-inicial) |
| Reubicaciones | Fija, no se configura | El mismo hueco que se vació |

Si el almacén está casi lleno, todas acaban en el primer hueco libre: cambiar de estrategia no gana sitio.

### Huecos reservados

En *Ubicar recepciones*, *Ubicar ensamblados* e *Imprimir y ubicar palés*, el hueco que se propone queda **reservado** para esa línea: no se propone a nadie más ni se puede usar para otra cosa hasta que se ubica.

- **Se usa**: al confirmar, la reserva se quita y el hueco queda ocupado.
- **No se usa**: se suelta solo al pedir **Otra ubicación**, al escribir otro hueco, al pasar a otra tarea o al volver a cargar la lista, y al cerrar la pantalla.
- **Se queda reservado** (por ejemplo, si se cierra el navegador sin salir de la pantalla): en **Ubicaciones SGA**, vista **Reservadas**, selecciona el hueco y pulsa **Liberar reserva**. Las columnas *Reservada para* y *Reservada por* dicen de qué entrada y de quién es.

Un hueco reservado para otra entrada no se puede escribir a mano: avisa de para quién está.

En estas tres pantallas no sale nunca nada anterior a la **Fecha inicio SGA** de la configuración, aunque se pida una fecha anterior: lo que entró antes ya es stock de BC y lo colocó la carga inicial.

### Ubicar recepciones

Lo que ha entrado en albaranes de compra registrados.

1. Ajusta los filtros: *Registrado desde / hasta*, *Clase de artículo* (por defecto *Prod. externo*; *Todas* para no filtrar), *Producto*, *Almacén* y *Solo lo que falta por ubicar*.
2. **Proponer ubicaciones**: reparte las líneas sin dar el mismo hueco a dos. **Otra ubicación** si no te convence.
3. **Confirmar esta línea** o **Confirmar todo**. Se puede ubicar una línea en varias veces bajando *A ubicar*.

### Ubicar ensamblados

Igual, con los ensamblados registrados. Se abre con el día de trabajo.

### Imprimir y ubicar palés

Cada etiqueta que se imprime en la línea deja el palé ubicado.

1. Elige la tarea que está en línea.
2. En **Siguiente palé** ves la *Ubicación*, *Por qué ahí* y la *Situación* (palé completo o último palé).
3. **Proponer ubicación** u **Otra ubicación**; si lo dejas en otro hueco, escríbelo en *Ubicación*.
4. **Imprimir y ubicar**: sale la etiqueta y el palé queda ubicado.

### Ubicar producto

Para una cosa suelta. Indica producto, lote, caducidad y cantidad, o pulsa **Ubicar todo lo pendiente**. **Proponer ubicación** llena la tabla **Dónde dejarlo**: una línea por palé y una por el resto. Luego **Confirmar todo** o **Confirmar esta línea**.

### Pendiente de ubicar

El stock que no está en ninguna ubicación, lote a lote: *Sin ubicar* = *Stock BC* − *Ubicado*. Lo que sale en *En recepciones o ensamblados* se ubica desde esas pantallas. El resto:

- **Ubicar**: abre *Ubicar producto* con todo puesto.
- **Ubicar seleccionadas**: busca hueco para varias líneas a la vez, con opción de simular.

---

## 6. Consultas y control

### ¿Dónde está el producto?

Escribe el *Producto* (y, si quieres, *Almacén* y *Lote*). Salen todas las ubicaciones donde está, por caducidad. *Solo con cantidad disponible* oculta lo bloqueado y lo reservado. También desde la ficha o la lista de productos: grupo **SGA** > **¿Dónde está?**

### Ubicaciones SGA

La lista de huecos con su estado y su ocupación, coloreada: gris vacía, verde con hueco, amarillo llena y rojo bloqueada.

- Vistas: **Vacías**, **Con hueco**, **Llenas**, **Bloqueadas**, **Reservadas**, **Picking**, **Almacenamiento** y **Sin tipo**.
- Acciones: **Cambiar en bloque**, **Imprimir etiquetas**, **Liberar reserva**, **Bloquear / desbloquear**, **Recalcular ocupación**.
- En la ficha: **Recalcular ocupación**, **Vaciar ubicación** (todo queda sin ubicar; el stock de BC no cambia), **Movimientos de entrada** y **Movimientos de salida**.

### Contenido de ubicaciones

Qué producto y lote hay en cada hueco. Vistas **Bloqueado** y **Con reserva**.

- **Trasladar**: a otra ubicación. Si eliges *Zona destino*, propone un hueco de esa zona y dice por qué.
- **Bloquear / desbloquear** una línea (por ejemplo, un lote en cuarentena).
- **Recontar**: tecleas la *Cantidad contada* y la diferencia queda registrada, sea de más o de menos.
- **Quitar de la ubicación**: la línea sale entera y queda pendiente de ubicar. No deja si está reservada.

### Mapa de almacén

Una rejilla por *Almacén* y *Pasillo*: una fila por altura y una columna por estantería. Gris vacía, verde con hueco, naranja llena, rojo bloqueada y azul (*RESERV*) reservada para una entrada que se está ubicando. Filtrando un pasillo se ve de frente. Pulsar una celda abre su contenido.

### Mapa 3D de almacén

- Arriba, *Almacén*, *Zona* y *Pasillo*. En el lienzo, tres vistas: **3D**, **Planta** y **Frente** (un pasillo de frente, la de trabajo).
- **Colorear por**: *Estado*, *Rotación ABC* o *Caducidad*. Por estado, las reservadas para una entrada salen en turquesa, y al pasar por encima dice para qué entrada y de quién. **Buscar**: un producto o una ubicación; las que coinciden se marcan en naranja.
- Ratón: pasar por encima enseña lo que hay; clic abre el contenido; doble clic aísla el pasillo; **clic derecho vacía** la ubicación; **arrastrar** una ubicación con contenido sobre otra la traslada, solo dentro de la misma zona.

### Movimientos de ubicación

El diario de todo: quién movió qué, cuándo y de dónde a dónde. Vistas **Traslados** y **Ajustes y recuentos**.

### Conciliación con el stock

1. Menú *Informes* > **Conciliar con el stock**: elige *Almacén* y *Mostrar solo diferencias*.
2. El último resultado se vuelve a abrir en *Consultas* > **Conciliación con el stock**. Vistas **Stock sin ubicar** (BC tiene más que las ubicaciones) y **Sobra en ubicaciones** (las ubicaciones tienen más que BC).
3. Lo que falta, mejor ubicarlo en su sitio. Si no, **Regularizar en ubicación de ajustes** lo deja en la ubicación de ajustes. Lo que sobra no se regulariza: se recuenta. **Volver a conciliar** para comprobar.

Lánzala al final del día o cuando alguien no encuentre un producto.

### Bloquear

Una ubicación: *Ubicaciones SGA* > **Bloquear / desbloquear**, o en su ficha. Una ubicación bloqueada no admite entradas ni se propone para recoger. Un lote concreto se bloquea desde *Contenido de ubicaciones*.

### Análisis ABC (solo observa)

Clasifica los productos por los palés que salen: **A** los que más, **C** los que menos. **No cambia nada**: sirve para decidir si conviene ubicar por rotación.

- **Calcular ahora** hace un cálculo nuevo; **Cálculos anteriores** guarda los de antes.
- El *Resumen* da la concentración, las clases, los huecos y los avisos.
- **Mostrar** filtra la lista: una clase, los que cambian de clase o los que están fuera de su clase.

---

## 7. Si algo falla

Lo más frecuente está aquí. Los casos con más detalle, con su causa y su solución paso a paso, están en [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

| Síntoma | Qué hacer |
|---|---|
| *¿Dónde está el producto?* no lo encuentra | Quita los filtros de *Lote* y *Almacén*. Si sigue sin salir, no está ubicado: búscalo en *Pendiente de ubicar*. |
| No propone una ubicación que existe | Casi siempre no tiene tipo (vista *Sin tipo*). Si no, está bloqueada, es de otro producto fijo, no tiene sitio o espera una reubicación. |
| *No se puede ubicar*: no queda espacio | Libera ubicaciones, amplía su capacidad en palés o crea más. |
| *No se puede ubicar*: el producto no tiene palé | Rellena el *Cód. palé por defecto* del producto y vuelve a proponer. |
| Ha metido más de un palé en un hueco | El hueco tiene capacidad 0. *Quitar de la ubicación*, pon capacidad = 1 y vuelve a ubicar. |
| La ocupación de una ubicación no cuadra | Ficha de la ubicación > *Recalcular ocupación*. |
| No me deja cambiar la configuración de una ubicación | Tiene contenido. Trasládalo o vacíalo; si solo quieres que no se use, bloquéala. |
| Una recepción no sale en *Ubicar recepciones* | Vacía las fechas y el producto, pon *Clase de artículo* = *Todas* y desmarca *Solo lo que falta por ubicar*. Si no entró por albarán de compra, usa *Ubicar producto*. |
| Deshice una recepción que ya estaba ubicada | *Contenido de ubicaciones* > *Recontar* con la cantidad real. |
| No deja enviar el pedido a picking | Lánzalo. Si ya tiene una orden abierta, termínala o cancélala. |
| La orden terminó pero el pedido no tiene cantidad a enviar ni lotes | Corrige la causa (reserva por lote en la línea, permisos) y pulsa *Pasar al pedido* en la orden. |
| *Siguiente orden*: no tiene órdenes asignadas | Se exige asignación: el responsable reparte en *Asignar órdenes de picking*. |
| En la PDA no pasa nada al escanear | Revisa el perfil del lector (apartado 3, PDA) y que la salida por teclado esté desactivada. Solo funciona en la app de Business Central. |
| *El código … no corresponde a ningún producto* | Da de alta el código como referencia de tipo *Código de barras* del producto o en su GTIN. |
| Un responsable no puede asignar | En *Configuración de usuarios*, marca *Responsable picking SGA*. |
| Un picking vacío no tiene reubicación | Revisa que haya stock disponible en almacenamiento, una ubicación de picking con sitio y la serie de órdenes. Luego *Planificar reubicaciones*. |
| El mapa 3D sale en blanco | Elige el almacén y vacía zona y pasillo. Los códigos deben seguir `101-15-03`. |
| La ubicación leída no existe en SGA | La etiqueta que se ha leído no es de una ubicación SGA del almacén. Lee la etiqueta del hueco que tienes delante. |
