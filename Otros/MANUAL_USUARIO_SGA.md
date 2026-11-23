# Manual de usuario de SGA

Para quien trabaja con SGA cada día. Cada uno lee su apartado; el último dice qué hacer cuando algo no sale. Cómo se configura está en el [manual de implantación](MANUAL_IMPLANTACION_SGA.md).

## Lo básico

- **Business Central dice cuánto hay; SGA dice dónde.** SGA no cambia el stock de BC: lo reparte entre los huecos del almacén. Si no coinciden, la conciliación lo enseña (apartado 6).
- Las pantallas de SGA llevan **SGA** en el título. Se abren desde los menús del rol o desde el buscador (Alt+Q).
- Cada ubicación tiene un **tipo**:

| Tipo | Para qué es |
|---|---|
| **Almacenamiento** | La reserva. Es lo primero que se propone al ubicar, y de aquí salen las reposiciones |
| **Picking** | De donde se preparan los pedidos. Se propone al ubicar si no queda sitio en almacenamiento |
| *(en blanco)* | Muelles, ajustes… Nunca se propone |

- Todo movimiento queda en **Movimientos de ubicación**, que no se edita. Un error se corrige con otro movimiento. Solo *Inicializar contenido*, al empezar de cero, los borra.

| Quién | Rol de BC | Apartado |
|---|---|---|
| Oficina | Procesador de pedidos | 1 |
| Preparador | Preparador SGA (PDA) en el terminal; Almacén SGA en el ordenador | 2 |
| Carretillero | Preparador SGA (PDA) | 3 |
| Entradas | Almacén SGA | 4 |
| Responsable de almacén | Almacén SGA | 5 |
| Todos | | 6 y 7 |

---

## 1. Oficina: pedidos de venta

**Toda venta sale por picking.** No uses las acciones de almacén estándar de BC.

### Enviar un pedido

1. Lanza el pedido.
2. Pestaña **Almacén SGA** > **Enviar a SGA**.

SGA crea las órdenes de picking y **reserva** la ubicación y el lote de cada cosa: otro pedido ya no lo ve disponible. Las órdenes se reparten así:

- cada palé completo de una línea, una orden;
- lo que se vende en cajas (la unidad de venta del producto), una orden por producto con todas sus cajas;
- las unidades sueltas de todas las líneas, juntas en órdenes de hasta un palé.

Por ejemplo, 4 palés de un producto y 2 cajas de otro son 5 órdenes.

No deja enviarlo si no está lanzado, si tiene una orden sin terminar, si todo lo que queda por servir ya está recogido o si un producto no tiene *Cód. palé por defecto* en su ficha. **Un pedido enviado a SGA ya no se puede volver a abrir.**

### Si falta stock

- Las órdenes se crean con lo que hay y el aviso dice qué falta de cada producto. Solo da error si no hay nada ubicado de ningún producto del pedido.
- Cuando haya stock y estén terminadas todas las órdenes del pedido, se envía lo que falta: en el pedido, otra vez **Enviar a SGA**; para todos los pedidos a la vez, **Segunda ronda de picking** en *Órdenes de picking SGA*.
- Mientras tanto el pedido sale como *Parcial*. Si se decide servirlo así, se registra el envío de lo preparado.

### Ver cuánto está preparado

- **Estado preparación SGA**, en el pedido y en la lista: *Sin preparar*, *Parcial* o *Preparado*. En blanco si no queda nada por enviar.
- En la lista de pedidos, pestaña **Almacén SGA**: **Ver preparados**, **Ver preparados en parte** y **Ver todos**.
- En las líneas, la columna *Cantidad preparada* (si no se ve, añádela con *Personalizar*).

### Pasar al pedido

Al terminar cada orden, SGA rellena la **cantidad a enviar** y los **lotes** de cada línea. Después se registra el envío como siempre.

- Si el paso falla, repítelo con **Pasar picking al pedido** (en el pedido) o **Pasar al pedido** (en la orden). La vista *Terminadas sin pasar al pedido* de *Órdenes de picking SGA* enseña las que faltan.
- **No cambies a mano la cantidad a enviar ni los lotes**: SGA no se entera y BC y las ubicaciones se descuadran.

---

## 2. Preparador: preparar pedidos

### Empezar

- **En el terminal:** rol *Preparador SGA (PDA)* > **Preparar pedidos SGA**.
- **En el ordenador:** *Órdenes de picking SGA* > **Siguiente orden**. **Preparar** abre una orden concreta y **Asignármela** te la queda (si no se exige asignación).

Sale la orden que te toca: primero las tuyas, por prioridad. Al terminarla pasa sola a la siguiente; si no hay más, ofrece **BUSCAR SIGUIENTE ORDEN**. En el terminal, el grupo **Mi picking SGA** cuenta tus órdenes y reposiciones y las disponibles.

### Cada línea

La pantalla *Preparar picking SGA* dice:

- **VAYA A**: la ubicación. En un pedido, al lado, **→ PLAYA** y la playa donde dejar lo recogido.
- **COJA**: la cantidad, en la unidad del pedido, y la descripción del producto. En pequeño, el código, el lote, la caducidad, el palé (SSCC) y la cantidad en unidades base.
- **CONFIRME**: en rojo, pendiente; en verde, hecho.

1. Ve a la ubicación y coge el producto.
2. Si coges otra cantidad, cámbiala con **−** y **+** o tecleándola.
3. Escanea la etiqueta del hueco, o teclea su código. La línea se confirma sola y pasa a la siguiente (el botón **CONFIRMAR** hace lo mismo).

Ni el producto ni el palé se leen: solo la ubicación. Si lo leído no es una ubicación del almacén, sale en rojo con un pitido: lee la etiqueta del hueco que tienes delante. Si coges de otro hueco, escanea ese: se registra como desvío si la configuración lo permite y, si no, sale en rojo.

**Botones:**

- **Saltar**: deja la línea para el final. Si la saltas otra vez queda **retenida** para el responsable y ya no te sale.
- **Sin stock**: el producto no está en el hueco. Si aceptas buscar en otra ubicación, la pantalla dice de dónde cogerlo; si no hay en ninguna, lo dice en rojo. El hueco no se corrige solo: hay que recontarlo.

Al terminar sale *Orden terminada*, la playa en la que dejarla y que lo recogido ya está en el pedido. Si quedan líneas retenidas, dice que la orden está recorrida y cuántas quedan para el responsable. Si dice que no se ha podido pasar al pedido, avisa a oficina: no se pierde nada.

**En qué orden sale.** De un pedido salen primero los palés, luego las cajas (las de más volumen antes, para que queden abajo) y por último los sueltos. Se recoge primero de palés completos de almacenamiento, luego de picking y lo que falte de las demás ubicaciones (menos la de ajustes). Dentro de cada paso manda la estrategia de picking: lo que entró antes (FIFO), lo que antes caduca, y lo que no tiene caducidad al final (FEFO) o por orden de ubicación (por su código). Lo que se traslada o se repone conserva su fecha de entrada.

### Preparar el terminal (una vez)

Terminal Android con lector integrado y la app de **Business Central** de Google Play. En el programa del lector (en Zebra, *DataWedge*) crea un perfil para la app de Business Central con salida por *Intent* y la salida por teclado desactivada:

| Ajuste | Valor |
|---|---|
| Intent delivery | Broadcast intent |
| Intent action | `com.businesscentral.barcode.receive_barcode` |
| Intent category | `com.businesscentral.barcode.receive_category` |
| Clave del dato (Honeywell, Datalogic) | `com.symbol.datawedge.data_string` |
| Clave del tipo (Honeywell, Datalogic) | `com.symbol.datawedge.label_type` |

En Zebra las claves ya son esas. Un lector que escribe como un teclado (de anillo, Bluetooth) vale sin configurar nada. La pantalla no abre el teclado del terminal hasta que tocas una casilla.

---

## 3. Carretillero: reposiciones

Una **reposición** lleva mercancía de almacenamiento a un hueco de picking. Se prepara igual que un pedido (apartado 2): la línea dice **DE** origen **→ A** destino. Recoge en el origen, confirma y la mercancía pasa al destino. Si es un palé justo, la cantidad sale en palés.

- Con **Carretillero SGA** marcado, *Siguiente orden* te da lo tuyo y después las reposiciones sin asignar, nunca pedidos. Sin marcar, al revés. Lo que te asigna el responsable te llega siempre.
- Se crean solas cuando un hueco de picking se queda a cero de un producto (por una recogida, un traslado, un recuento a la baja, al quitarlo o al vaciar el hueco), salvo que ya haya una pendiente hacia ese hueco. **Planificar reposiciones** repone además los productos que no tienen nada en picking.
- Hace falta stock disponible en almacenamiento. Traen como mucho un palé, y el hueco espera a su producto: no se propone a otro.
- Página **Reposiciones SGA**: vistas *Por hacer* y *Hechas*; **Planificar reposiciones**, **Preparar**, **Cancelar** (libera la reserva) y **Orden**.

---

## 4. Entradas: ubicar lo que llega

| Lo que entra | Pantalla |
|---|---|
| Albarán de compra registrado | **Ubicar recepciones** |
| Palé que sale de la línea de producción | **Imprimir y ubicar palés** |
| Palé de un ensamblado que ya trae etiqueta y no se ubicó en la línea | **Ubicar ensamblados** |
| Cualquier otra cosa | **Ubicar producto** o **Pendiente de ubicar** |

En todas es igual: **proponer**, dejar la mercancía y **confirmar**. Si la dejas en otro hueco, cámbialo antes de confirmar; se admite si la configuración permite desvíos.

- **Palés y resto.** Cada palé completo va a su hueco y el resto (cajas o unidades) a otro.
- **SSCC.** Lee la etiqueta del palé en la columna *SSCC* (o teclea los 18 dígitos). Si el palé no trae etiqueta, déjala en blanco: al confirmar se le da un SSCC nuevo.
- **Dónde propone.** Primero almacenamiento, luego picking. Solo huecos que admiten la mercancía: no bloqueados, con sitio y sin otro producto o lote si no aceptan mezcla. Junto a cada propuesta sale el porqué.
- **Hueco reservado.** En recepciones, ensamblados e imprimir y ubicar, el hueco propuesto queda reservado para esa línea hasta que se confirma. Se suelta solo con **Otra ubicación**, al escribir otro hueco, al cambiar de tarea, al recargar o al cerrar. Si se queda colgado (por ejemplo, al cerrar el navegador): *Ubicaciones SGA* > vista *Reservadas* > **Liberar reserva**.
- No sale nada anterior a la **Fecha inicio SGA**: eso ya lo colocó la carga inicial.
### Ubicar recepciones

1. Ajusta los filtros: fechas de registro, *Clase de artículo* (por defecto *Prod. externo*; *Todas* para no filtrar), *Producto*, *Almacén* y *Solo lo que falta por ubicar*.
2. **Proponer ubicaciones**. **Otra ubicación** si una no te convence.
3. Se ubica de palé en palé: *A ubicar* es lo que queda, sin pasar de un palé (bájalo si el palé viene incompleto). Lee el *SSCC* y pulsa **Confirmar esta línea** o **Confirmar todo**.
4. Si a la línea le quedan palés, vuelve a **Proponer ubicaciones**.

### Ubicar ensamblados

Los palés de producción se ubican al imprimir su etiqueta (*Imprimir y ubicar palés*). Esta pantalla queda para el que se quedó sin ubicar en la línea: funciona igual que recepciones, con los ensamblados registrados, y se abre con el día de trabajo. Lee la etiqueta que ya lleva el palé; aquí no se imprimen etiquetas. En el buscador sale como *Ubicar entradas SGA*.

### Imprimir y ubicar palés

1. Elige la tarea que está en línea.
2. **Siguiente palé** dice la *Ubicación*, el *Por qué ahí* y si es palé completo o el último.
3. **Proponer ubicación** u **Otra ubicación**. Si lo dejas en otro hueco, escríbelo en *Ubicación*.
4. **Imprimir y ubicar**: sale la etiqueta y el palé queda ubicado con su SSCC.

En el entorno de pruebas (Sandbox), la etiqueta A5 lleva un SSCC distinto del ubicado.

Para ver dónde están los palés de un ensamblado: en la ficha o en la lista de ensamblados registrados, **Palés SGA**. Abre *Contenido de ubicaciones* con sus palés, también las cajas sueltas que se han separado. Los que ya han salido enteros no aparecen.

### Ubicar producto

Para una cosa suelta. Indica producto, lote, unidad de medida y cantidad, o pulsa **Ubicar todo lo pendiente**. **Proponer ubicación** llena **Dónde dejarlo**: una línea por palé y una por el resto. Lee en cada línea el *SSCC* de su palé y pulsa **Confirmar todo** o **Confirmar esta línea**. Si la configuración exige confirmar ubicación, antes lee en *Ubicación leída* la etiqueta del hueco donde la dejas.

### Pendiente de ubicar

El stock de BC que no está en ninguna ubicación, lote a lote. Los productos marcados como *Producto Tianna* y los de la categoría 820 no salen nunca. De un lote que SGA no ha movido nunca, solo cuenta lo que ha entrado desde la *Fecha inicio SGA*: lo anterior lo coloca la carga inicial. Si SGA ya ha movido el lote (por ejemplo, se ha quitado de un hueco), sale todo lo que le falta. Arriba eliges *Almacén*, *Productos* (uno, un filtro como `1000..1999`, o varios marcados al pulsar la flecha) y *Clase de artículo*, y pulsas **Calcular**: solo se calcula lo indicado. Al abrir o al cambiar un filtro no se calcula nada. Sin productos ni clase, **Calcular** pregunta antes de revisar todo el almacén. Lo que sale en *En recepciones o ensamblados* se ubica desde esas pantallas. El resto:

- **Ubicar**: abre *Ubicar producto* con todo puesto.
- **Ubicar seleccionadas**: busca hueco para varias líneas a la vez (cada palé a un hueco vacío y el resto junto). Se puede simular antes. Al terminar dice lo ubicado y, de lo que no cabe, por qué.

---

## 5. Responsable de almacén

### Pilas del rol center

El grupo **Picking** del rol *Almacén SGA* cuenta, en el almacén por defecto. Al pulsar una pila se abre la pantalla que la resuelve.

| Pila | Qué cuenta |
|---|---|
| Pendientes de asignar | Órdenes que esperan preparador |
| Sin empezar / En proceso | Órdenes abiertas sin empezar o a medias |
| Envío vencido (rojo) | Órdenes sin terminar con fecha de envío hoy o antes |
| Líneas retenidas (rojo) | Líneas saltadas dos veces |
| Terminadas sin pasar al pedido (rojo) | Órdenes terminadas que no están en el pedido |
| Reposiciones pendientes | Reposiciones por hacer |
| Terminadas hoy (verde) | Órdenes terminadas en la fecha de trabajo |
| Desvíos de ubicación hoy (amarillo) | Líneas recogidas hoy en un hueco distinto del propuesto |

Las pilas de órdenes no cuentan las reposiciones. Los grupos *Ubicaciones*, *Contenido* y *Actividad de hoy* resumen el estado del almacén.

### Asignar y dar prioridad

**Asignar órdenes de picking SGA**, vistas *Sin asignar* y *Asignadas*:

- **Asignar a** da las seleccionadas a un preparador. **Quitar asignación** devuelve a la bolsa las que no se han empezado; una orden empezada se puede reasignar, pero no dejar sin nadie.
- **Subir prioridad** / **Bajar prioridad**: cuanto mayor, antes sale. Cambian a la vez todas las órdenes del pedido.
- **Cambiar playa**: elige la playa donde se dejan las órdenes seleccionadas. Solo cambia las que aún no se han empezado; el mensaje dice cuántas no. También está en *Órdenes de picking SGA*.

Con *Exigir asignación de picking* activada en la configuración, las órdenes nacen *Pendiente de asignar*, cada preparador solo ve las suyas y solo reparten los usuarios marcados como **Responsable picking SGA**. Sin ella, cualquiera coge la siguiente sin asignar o se la asigna.

### Líneas retenidas

Una línea saltada dos veces queda **retenida**: el preparador ya no la ve, pero conserva su reserva y la orden no se termina. Se ven en la pila, en *Líneas de picking SGA* (vista *Retenidas*) y en la vista *Con líneas retenidas* de las órdenes.

- **Contenido de la ubicación** enseña qué hay en el hueco según SGA.
- **Buscar en otra ubicación** cancela la línea y crea otras en huecos con stock, que vuelven al preparador de la orden. Si no hay stock en ningún otro hueco, queda cancelada.

### Cancelar

- Una orden: *Órdenes de picking SGA* > **Cancelar orden**. Libera lo reservado. Si ya tenía algo recogido, lo avisa y lo pasa al pedido, porque esa mercancía ya no está en su hueco.
- Una línea: en la ficha de la orden, **Cancelar línea**. Libera su reserva.

### Quién es quién

En **Configuración de usuarios**, en la línea de cada usuario:

- **Responsable picking SGA**: reparte órdenes y cambia prioridades cuando se exige asignación. Manda la casilla, no el conjunto de permisos.
- **Carretillero SGA**: recibe reposiciones y no pedidos (apartado 3).

### Etiquetas de ubicación

Cada hueco lleva su etiqueta, y el preparador la lee al recoger. Se imprimen por pasillos: en **Ubicaciones SGA**, filtra el pasillo, selecciona los huecos y pulsa **Imprimir etiquetas**.

---

## 6. Consultas y control

### ¿Dónde está el producto?

Solo consulta. Escribe el *Producto* y, si quieres, *Almacén* y *Lote*. Salen las ubicaciones donde está, por caducidad. *Solo con cantidad disponible* oculta lo bloqueado y lo reservado. También desde la ficha o la lista de productos (**SGA** > **¿Dónde está?**), desde **Ver todas** del cuadro de ubicaciones del producto y desde la columna *Ubicado* de *Pendiente de ubicar*.

Para un palé concreto, lee su etiqueta en *SSCC*: sale dónde está y, si se ha partido, dónde están sus cajas.

### Ubicaciones SGA

Los huecos con su ocupación: gris vacía, verde con hueco, amarillo llena y rojo bloqueada. El *% ocupación* va en verde por debajo del 80 %, en ámbar del 80 al 99 % y en rojo desde el 100 %; sin capacidad (0, sin límite), sin color. Vistas por estado y por tipo, y *Reservadas* y *Sin tipo*. Acciones: **Cambiar en bloque**, **Imprimir etiquetas**, **Liberar reserva**, **Bloquear / desbloquear** y **Recalcular ocupación**. En la ficha, además, **Vaciar ubicación** (todo queda sin ubicar; el stock de BC no cambia), sus movimientos y el contenido, que solo se mira: se traslada y se bloquea desde *Contenido de ubicaciones*. Desde *Consultas* solo se mira: ni esas acciones ni la ficha cambian nada; se hace desde *Configuración*.

### Contenido de ubicaciones

Qué hay en cada hueco: una línea por palé, con producto, lote y SSCC. Es para trabajar con el contenido, así que está en el menú *Almacén SGA* y no en *Consultas*.

- **Trasladar** a otra ubicación. Con *Zona destino*, propone un hueco de esa zona. Al pulsar Aceptar se registra; si no se puede (el destino no la admite, por ejemplo), sale el motivo y la ventana sigue abierta para cambiarlo.
- **Bloquear / desbloquear** una línea, por ejemplo un lote en cuarentena. Lo reservado por una orden no se puede bloquear.
- **Recontar**: escribe la *Cantidad contada* en unidades base y al pulsar Aceptar la diferencia queda registrada. Corrige solo la ubicación, no el stock de BC.
- **Quitar de la ubicación**: enseña lo que se quita, pide confirmación y las líneas seleccionadas salen enteras y quedan pendientes de ubicar. Es lo mismo que **Vaciar ubicación** de la ficha y del mapa 3D.
- **Movimientos del palé**: la historia de su SSCC.

### Bloquear

Hay tres bloqueos, y quitar uno no quita los otros:

- La **línea** (en *Contenido de ubicaciones*): no se recoge de ella.
- La **ubicación** (*Ubicaciones SGA* o su ficha) y su **zona** (*Zonas SGA*): ni se deja ni se recoge, y en los mapas sale en rojo.

### Mapas

- **Mapa de almacén**: una rejilla por pasillo, una fila por altura y una columna por estantería, con los colores de estado y en azul (*RESERV*) las reservadas para una entrada. Pulsar una celda abre su contenido.
- **Mapa 3D de almacén**: vistas *3D*, *Planta* y *Frente*. **Colorear por** estado, posición ABC, rotación ABC o caducidad. **Buscar** marca en naranja un producto o una ubicación. Con el ratón: pasar por encima enseña lo que hay, clic abre el contenido, doble clic aísla el pasillo, clic derecho vacía la ubicación y arrastrar una ubicación sobre otra de la misma zona traslada su contenido. La rueda acerca y aleja; en *Planta* y *Frente*, **Mayús + rueda** desplaza a los lados.

### Movimientos de ubicación

Quién movió qué, cuándo y de dónde a dónde. Vistas *Traslados* y *Ajustes y recuentos*. Para un listado a medida, filtra esta lista, *Contenido de ubicaciones* o *Ubicaciones SGA* y ábrela en Excel.

### Conciliación con el stock

Compara BC con las ubicaciones. Conviene lanzarla al final del día o cuando alguien no encuentra un producto.

1. *Almacén SGA - Informes* > **Conciliar con el stock**, con el *Almacén*. Salen solo las diferencias; *Mostrar también las que cuadran* lo enseña todo.
2. El resultado queda en *Almacén SGA - Consultas* > **Conciliación con el stock**, con las vistas *Stock sin ubicar* (BC tiene más) y *Sobra en ubicaciones* (las ubicaciones tienen más). Al pulsar en *Stock BC* salen los movimientos de producto de los que sale; en *Stock SGA*, en qué ubicaciones está el lote.
3. Lo que falta, ubícalo en su sitio desde *Pendiente de ubicar*. Si no se sabe dónde está, **Regularizar en ubicación de ajustes** lo deja en la ubicación de ajustes, de la que el picking no coge. Lo que sobra no se regulariza: se recuenta.
4. **Volver a conciliar** para comprobar.

### Análisis ABC

Clasifica los productos por los palés que salen: **A** los que más, **C** los que menos. Solo observa, no cambia nada.

- **Calcular ahora** hace un cálculo nuevo; los anteriores se guardan y **Cálculos anteriores** los enseña.
- **Mostrar** filtra por clase, por los que cambian de clase o por los que están fuera de su clase.
- **Ver en el mapa** abre el mapa 3D coloreado por la clase de cada hueco, con el producto de la línea resaltado.

---

## 7. Si algo no sale

### Encontrar y ubicar

| Qué pasa | Qué hacer |
|---|---|
| *¿Dónde está el producto?* no lo encuentra | Quita *Lote* y *Almacén* y desmarca *Solo con cantidad disponible*. Si sigue sin salir, no está ubicado: búscalo en *Pendiente de ubicar*. |
| No propone una ubicación que existe | Casi siempre no tiene tipo: vista *Sin tipo* y **Cambiar en bloque**. Si lo tiene, está bloqueada, es de otro producto fijo, está reservada, no tiene sitio, no admite mezcla o espera una reposición. O la estrategia solo usa huecos vacíos (la de ensamblados, por defecto) o la ubicación fija del producto. |
| Una línea sale *No se puede ubicar* | Lee *Por qué ahí* (en *Ubicar producto*, *Motivo*). Sin tipo: ponlo. Sin espacio: libera o amplía capacidad. Sin palé: rellena el *Cód. palé por defecto* del producto. *Ya propuestas a otras líneas*: confirma las que tienen hueco y vuelve a proponer. Después, **Proponer** otra vez. |
| Dice que la ubicación no la admite | El mensaje dice por qué: bloqueada, reservada para otra entrada o para otro producto, no admite mezcla, o no tiene sitio. Elige otra. Si pregunta si continuar por la capacidad, confirma solo si de verdad va ahí. |
| *El SSCC … ya está en la ubicación …* | Has leído la etiqueta de otro palé o la misma dos veces. Lee la del palé que ubicas o déjala en blanco. |
| Una compra no sale en *Ubicar recepciones* | Vacía fechas, producto y almacén, pon *Clase de artículo* = *Todas* y desmarca *Solo lo que falta por ubicar*. Si no entró por albarán de compra, o es anterior a la *Fecha inicio SGA*, ubícala desde *Pendiente de ubicar*. |
| Deshice una recepción que ya estaba ubicada | *Contenido de ubicaciones* > **Recontar** con la cantidad real. |
| Un traslado no se hizo | Lee el mensaje: el destino no la admite, es el mismo hueco o pides más de lo disponible. Desde el mapa 3D no se traslada entre zonas: usa *Contenido de ubicaciones*. |

### Ubicaciones

| Qué pasa | Qué hacer |
|---|---|
| Ha metido más de un palé en un hueco | El hueco tiene capacidad 0 (sin límite). **Quitar de la ubicación**, pon capacidad 1 y vuelve a ubicar. |
| La ocupación pasa de 100 % o sale *Llena* con sitio | **Recalcular ocupación**. Si sigue, de verdad tiene más de lo que cabe: traslada lo que sobra. |
| No deja cambiar la configuración de una ubicación | Solo se cambia vacía. Traslada o vacía su contenido; si solo quieres que no se use, bloquéala. |
| Desbloqueé un lote y sigue sin usarse | Mira también el bloqueo de la ubicación y el de su zona. |
| No deja bloquear una línea | Está reservada por una orden: cancela la orden o usa *Buscar en otra ubicación*. |

### Pedidos y picking

| Qué pasa | Qué hacer |
|---|---|
| No deja enviar el pedido | El mensaje dice por qué: lánzalo; termina o cancela su orden abierta; rellena el *Cód. palé por defecto* de los productos que dice; o ubica primero el stock. Si dice que no tiene nada pendiente de preparar, ya está todo recogido: falta pasarlo al pedido y registrar el envío. |
| El preparador no ve lo que espera | El pedido no se ha enviado, no hay stock ubicado, está bloqueado o en la ubicación de ajustes, lo tiene reservado otra orden, o la línea está retenida. |
| *Siguiente orden*: no tiene órdenes asignadas | Se exige asignación: el responsable reparte en *Asignar órdenes de picking*. |
| La orden está asignada a otro | El responsable la reasigna. |
| El responsable no puede asignar | *Configuración de usuarios* > marca **Responsable picking SGA**. |
| No puedo quitar la asignación | La orden está empezada: reasígnala. |
| La orden terminó y el pedido no tiene cantidad a enviar ni lotes | Si la línea tiene reservas por lote, anúlalas. Después **Pasar al pedido** en la orden. Se puede repetir sin duplicar nada. |
| Cambié a mano la cantidad a enviar o los lotes | Antes de registrar, **Pasar picking al pedido**. Si ya se registró, recuenta el hueco del lote que sobra y ubica el que falta. |
| Un hueco de picking vacío no tiene reposición | Hace falta stock disponible en almacenamiento. Después, **Planificar reposiciones**. |
| En el terminal no pasa nada al escanear | Revisa el perfil del lector (apartado 2) y que la salida por teclado esté desactivada. Solo funciona en la app de Business Central. |
| *… no es una ubicación de este almacén* | Lo leído no es una etiqueta de hueco. Lee la del hueco que tienes delante. |

### Conciliación y mapas

| Qué pasa | Qué hacer |
|---|---|
| Falta stock en las ubicaciones | Si espera en *Ubicar recepciones* o *Ubicar ensamblados*, ubícalo allí. Si entró por otra vía (diario, ajuste), desde *Pendiente de ubicar*. Regulariza solo lo que no se sepa dónde está. |
| *Regularizar* no funciona | El mensaje dice por qué: sobra (se recuenta), está pendiente de ubicar en una entrada, falta la ubicación de ajustes en la configuración o es otro almacén distinto del de por defecto. |
| Lo regularizado está en la ubicación de ajustes | *Contenido de ubicaciones*, filtra la de ajustes y **Trasladar** a su hueco. |
| La conciliación tarda | Indica el almacén y filtra los productos. |
| El mapa no dibuja todas las estanterías | La rejilla llega a 32 estanterías: usa el mapa 3D. Las ubicaciones con un código distinto de `101-15-03` no salen en ningún mapa. |
| El mapa 3D sale en blanco | Elige el almacén y vacía zona y pasillo. |
