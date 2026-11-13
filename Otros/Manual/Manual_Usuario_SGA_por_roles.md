# Manual de usuario de SGA

Gestión de almacén en Business Central: ubicaciones, entradas, picking, reubicaciones y control del contenido. Este manual está organizado **por rol**: cada persona lee el capítulo de su rol.

Documento de trabajo. Los huecos marcados como **[CAPTURA nn]** se completan con las imágenes de las pantallas; la lista de todas está en el anexo A.

[[TOC]]

## 1. Cómo usar este manual

- Busca tu rol en el capítulo 2 y lee su capítulo (3, 4 o 5).
- Las pantallas de SGA llevan **SGA** en el título (*Órdenes de picking SGA*, *Preparar picking SGA*…). Lo que no lo lleva es de Business Central.
- Puedes abrir cualquier pantalla desde el **buscador** (Alt+Q) escribiendo su nombre, o desde la barra de navegación del rol.
- Los nombres de botones van en **negrita**, y los de campos y vistas, en *cursiva*.
- Todo movimiento queda registrado en **Movimientos de ubicación**, que no se edita ni se borra. Un error se corrige con otro movimiento.

> **[CAPTURA 01]** Buscador de Business Central (Alt+Q) escribiendo "Ubicar" y mostrando las pantallas de SGA. Datos de ejemplo: texto "Ubicar".

## 2. Roles y perfiles

Hay tres roles de trabajo y un rol de administración. Cada uno ve su propio **rol center** (la página de inicio), con sus menús.

| Rol | Perfil de Business Central | Quién lo usa | Dónde trabaja | Capítulo |
|---|---|---|---|---|
| **Almacén SGA** | ALMACEN SGA | Almacenero y responsable de almacén | Ordenador, Business Central web | 3 |
| **Preparador SGA (PDA)** | PREPARADOR SGA (PDA) | Preparador y carretillero | Terminal Android con la app de Business Central | 4 |
| **Procesador de pedidos** | Procesador de pedidos | Oficina de ventas | Ordenador | 5 |
| **Administración** | (el que configure la implantación) | Quien pone en marcha SGA | Ordenador | 6 |

Para asignar un perfil, en la configuración del usuario de Business Central, o desde *Mi configuración* si el usuario puede elegirlo.

> **[CAPTURA 02]** *Mi configuración* con el perfil "Almacén SGA" seleccionado. Datos de ejemplo: usuario de prueba "ALMACEN01".

## 3. Rol Almacén SGA

Es el rol del día a día del almacén: ubicar lo que llega, controlar dónde está cada cosa y, si eres responsable, repartir el picking.

### 3.1 El rol center

Al entrar ves los indicadores del almacén (pilas) y, en la barra de navegación, los menús agrupados así:

| Grupo | Qué contiene |
|---|---|
| **Almacén SGA** | El trabajo diario: ubicar, picking, reubicaciones y dónde está el producto |
| **Almacén SGA - Ventas y compras** | Productos, pedidos y albaranes de venta y de compra |
| **Almacén SGA - Consultas** | Ubicaciones, contenido, mapas, movimientos, conciliación y análisis ABC |
| **Almacén SGA - Informes** | Conciliación con el stock |
| **Almacén SGA - Configuración** | Zonas, ubicaciones, carga inicial y configuración de SGA |

> **[CAPTURA 03]** Rol center Almacén SGA completo, con los cinco grupos desplegados. Datos de ejemplo: el usuario ALMACEN01 con alguna pila con cifras.

En el grupo **Picking** del rol center hay pilas con el número de órdenes en cada situación. Al pulsar una, se abre la pantalla que la resuelve:

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

Las pilas de órdenes no cuentan las reubicaciones, que tienen la suya.

> **[CAPTURA 04]** Grupo *Picking* del rol center con sus pilas. Datos de ejemplo: al menos una pila en rojo (envío vencido) y una verde (terminadas hoy).

### 3.2 Antes de ubicar: tipos de ubicación y cómo se elige el hueco

**Tipo de ubicación.** Cada ubicación tiene un tipo que decide para qué se usa:

| Tipo | Para qué es | Al ubicar |
|---|---|---|
| **Almacenamiento** | La reserva; de aquí salen las reubicaciones | Es lo primero que se propone |
| **Picking** | De donde se preparan los pedidos | Solo si no queda sitio en almacenamiento |
| *(en blanco)* | Muelles, ajustes… | Nunca se propone |

**Estrategia.** Dentro de almacenamiento (y luego de picking), el hueco concreto lo decide la estrategia de ubicación de la configuración. Solo se proponen huecos que admiten la mercancía: no bloqueados, con sitio, y sin otro producto o lote si no aceptan mezcla. Junto a cada propuesta sale el **porqué** (*Ubicación fija del producto*, *Ya hay este producto ahí*, *Primer hueco con sitio*…).

| Estrategia | Qué hueco propone | Cuándo conviene |
|---|---|---|
| **Estándar** | Su casa (ubicación fija o el nº de estante de la ficha); si no, donde ya está el producto y cabe más; si no, el primer hueco con sitio | La de uso general |
| **Priorizar consolidación** | Donde ya está el producto y cabe más; si no, el primer hueco con sitio | Huecos de varios palés, para no repartir un producto |
| **Solo ubicación fija** | Solo su casa. Si no tiene o no cabe, *No se puede ubicar* | Cada producto tiene su sitio y no hay excepciones |
| **Primera libre por ruta** | El primer hueco con sitio del recorrido | Llenar siempre desde los mejores huecos |
| **Solo hueco vacío** | El primer hueco totalmente vacío del recorrido | Palés de producción: cada palé a un hueco limpio |

El **recorrido** es la *secuencia de picking* de cada ubicación: cuanto menor, antes se propone.

Si el producto tiene grupo IIEE con zonas asignadas, se busca primero en esas zonas. Si no queda sitio, se busca en todo el almacén y el porqué lo avisa. Mover o ubicar a mano fuera de las zonas de su grupo pide confirmación.

| Pantalla | Estrategia que usa | Por defecto |
|---|---|---|
| Ubicar recepciones | Estrategia de ubicación de compras | Estándar |
| Ubicar ensamblados e Imprimir y ubicar palés | Estrategia de ubicación de ensamblados | Solo hueco vacío |
| Ubicar producto y Mover contenido | Estrategia de ubicación | Estándar |
| Carga inicial y Ubicar seleccionadas | Fija, no se configura | Ver el capítulo 6 |
| Reubicaciones | Fija, no se configura | El mismo hueco que se vació |

Si el almacén está casi lleno, todas las estrategias acaban en el primer hueco libre: cambiar de estrategia no gana sitio.

**Huecos reservados.** En *Ubicar recepciones*, *Ubicar ensamblados*, *Imprimir y ubicar palés* y *Ubicar producto*, el hueco que se propone queda **reservado** para esa línea: no se propone a nadie más hasta que se ubica.

- **Se usa:** al confirmar, la reserva se quita y el hueco queda ocupado.
- **No se usa:** se suelta al pedir **Otra ubicación**, al escribir otro hueco, al pasar a otra tarea, al recargar la lista y al cerrar la pantalla.
- **Se queda reservado** (por ejemplo, si se cierra el navegador sin salir de la pantalla): en **Ubicaciones SGA**, vista *Reservadas*, selecciona el hueco y pulsa **Liberar reserva**.

Un hueco reservado para otra entrada no se puede escribir a mano: avisa de para quién está.

**SSCC del palé.** Cada palé lleva su código SSCC, el de su etiqueta. Al ubicar, lee la etiqueta del palé en la columna *SSCC* (vale la lectura entera del código de barras o teclear los 18 dígitos). Si el palé no trae etiqueta, deja *SSCC* en blanco: al confirmar se le da uno nuevo. El SSCC sirve para saber **dónde está** un palé concreto (ver 3.4), no para el picking.

### 3.3 Ubicar lo que llega

Lo que entra por compra o por producción se ubica después de registrarlo. Son tres pantallas, y en todas el proceso es el mismo: **proponer**, dejar la mercancía, corregir la *Ubicación confirmada* si la has dejado en otro hueco, y **confirmar**. Una cantidad se reparte en palés completos, cada uno a su hueco, y un resto en cajas o en unidades.

#### Ubicar recepciones

Lo que ha entrado en albaranes de compra registrados. Se abre con *Prod. externo* en la clase de artículo.

1. Ajusta los filtros: *Registrado desde / hasta*, *Clase de artículo* (por defecto *Prod. externo*; *Todas* para no filtrar), *Producto*, *Almacén* y *Solo lo que falta por ubicar*.
2. Pulsa **Proponer ubicaciones**: reparte las líneas sin dar el mismo hueco a dos. **Otra ubicación** si una propuesta no te convence.
3. Lee el *SSCC* del palé, deja la mercancía y pulsa **Confirmar esta línea** o **Confirmar todo**. Se ubica de palé en palé: *A ubicar* es lo que queda, sin pasar de un palé. Si el palé viene incompleto, baja *A ubicar*.
4. Si a la línea le quedan más palés, se queda sin hueco: pulsa otra vez **Proponer ubicaciones**.

En estas pantallas no sale nada anterior a la **fecha inicio SGA** de la configuración, aunque se pida una fecha anterior: lo que entró antes ya es stock de BC y lo colocó la carga inicial.

> **[CAPTURA 05]** Ubicar recepciones: filtros arriba y líneas con *SSCC*, *A ubicar* y *Ubicación propuesta*. Datos de ejemplo: un albarán de compra con dos líneas, una con SSCC leído y otra en blanco.

#### Ubicar ensamblados

Igual que las recepciones, con los embotellados registrados. Se abre con el día de trabajo.

> **[CAPTURA 06]** Ubicar ensamblados con un embotellado propuesto. Datos de ejemplo: un ensamblado del día con su palé pendiente.

#### Imprimir y ubicar palés

Pantalla de producción: cada etiqueta que se imprime en la línea deja el palé ubicado. Imprimir y ubicar es un solo paso, así no hay palés con etiqueta y sin ubicación.

1. Elige la tarea que está en línea.
2. En **Siguiente palé** ves la *Ubicación*, el *Por qué ahí* y la *Situación* (palé completo o último palé).
3. Pulsa **Proponer ubicación** u **Otra ubicación**; si lo dejas en otro hueco, escríbelo en *Ubicación*.
4. Pulsa **Imprimir y ubicar**: sale la etiqueta y el palé queda ubicado con el mismo SSCC que lleva la etiqueta.

> En el entorno de pruebas (Sandbox) la etiqueta sale en formato A5 y lleva un SSCC distinto del que queda ubicado. En producción, con BarTender, coinciden.

> **[CAPTURA 07]** Imprimir y ubicar palés: tarea en línea, *Siguiente palé* con la ubicación propuesta y el *Por qué ahí*. Datos de ejemplo: tarea de producción en curso.

#### Ubicar producto

Para una cosa suelta, o para ubicar lo que no viene de un documento. Indica producto, lote, caducidad y cantidad, o pulsa **Ubicar todo lo pendiente** para traer lo que falta de ese producto.

1. Pulsa **Proponer ubicación**: la tabla **Dónde dejarlo** tiene una línea por palé y una por el resto.
2. Lee en cada línea el *SSCC* de su palé (en blanco, se le da uno nuevo).
3. Pulsa **Confirmar todo** o **Confirmar esta línea**.

Si la propuesta trae un trozo que no cabe, sale como **SIN SITIO** y dice por qué (no hay ubicación de esa clase, las que hay son de muelle, están llenas o bloqueadas, o la unidad no está marcada como palé o caja).

> **[CAPTURA 08]** Ubicar producto con la tabla *Dónde dejarlo*: una línea por palé con su SSCC y otra con el resto. Datos de ejemplo: producto de prueba con dos palés y una caja suelta.

> **[CAPTURA 09]** Diálogo de confirmación de Ubicar producto: "¿Ubicar ahora palé 1 de 2 en 101-03-01?". Datos de ejemplo: ubicación de almacenamiento de prueba.

#### Pendiente de ubicar

Muestra el stock de Business Central que no está en ninguna ubicación, lote a lote: *Sin ubicar* = *Stock BC* − *Ubicado*. Lo que sale en *En recepciones o ensamblados* se ubica desde esas pantallas. El resto se ubica desde aquí:

- **Ubicar**: abre *Ubicar producto* con la línea ya puesta.
- **Ubicar seleccionadas**: busca hueco para varias líneas a la vez, como la carga inicial: cada palé a un hueco vacío y el resto junto. Se puede **simular** antes (no guarda nada). Al terminar enseña lo ubicado y, de lo que no cabe, el motivo.

> **[CAPTURA 10]** Pendiente de ubicar con las columnas *Stock BC*, *Ubicado*, *Sin ubicar* y *En recepciones o ensamblados*. Datos de ejemplo: dos lotes, uno con cifras en *Sin ubicar* y otro en *En recepciones*.

> **[CAPTURA 11]** Diálogo de *Ubicar seleccionadas* con las opciones "Ubicar ahora" y "Solo simular". Datos de ejemplo: tres líneas seleccionadas.

> **[CAPTURA 12]** Resultado de *Ubicar seleccionadas*: lo ubicado y lo que no cabe, con su motivo. Datos de ejemplo: una línea sin sitio.

### 3.4 Picking y responsable de almacén

#### Órdenes de picking

Lista de las órdenes de picking, de venta y de reubicación. Desde aquí:

- **Siguiente orden**: abre la pantalla de preparación con la orden que te toca, por prioridad, primero las tuyas. Al terminarla, pasa sola a la siguiente.
- **Preparar**: una orden concreta.
- **Asignármela**: si la configuración no exige asignación.
- **Cancelar orden**: cancela la orden y libera lo reservado.
- **Pasar al pedido** (si la orden está terminada y no ha pasado): repite el paso de la cantidad a enviar y los lotes.
- **Segunda ronda de picking**: crea las órdenes de los pedidos que aún tienen algo pendiente (ver capítulo 5).

Vistas: *Terminadas sin pasar al pedido*, *Con paradas retenidas* y las de estado.

> **[CAPTURA 13]** Órdenes de picking SGA con varias órdenes en distintos estados. Datos de ejemplo: una sin empezar, una en proceso y una terminada sin pasar al pedido.

#### Asignar órdenes de picking

En esta pantalla salen las órdenes vivas con su cliente, fecha de envío y paradas pendientes. Solo la usa el responsable.

- Vistas **Sin asignar** y **Asignadas**.
- **Asignar a**: da las seleccionadas a un preparador (también se puede teclear en *Asignada a*).
- **Quitar asignación**: las devuelve a la bolsa. Una orden empezada se puede reasignar, pero no dejar sin nadie.
- **Subir prioridad** y **Bajar prioridad**: cuanto mayor la *Prioridad*, antes sale. La prioridad es del pedido: cambian a la vez todas sus órdenes.
- **Ver orden** y **Ver pedido**.

Si la configuración exige asignación de picking:

| | Desactivada | Activada |
|---|---|---|
| La orden nace… | *Abierta* | *Pendiente de asignar* |
| *Siguiente orden* da… | Las suyas y, si no tiene, la siguiente sin asignar | Solo las suyas |
| *Asignármela* | Disponible | No: reparte el responsable |
| Quién reparte y cambia prioridades | Cualquiera | Solo los responsables de picking |

> **[CAPTURA 14]** Asignar órdenes de picking con las vistas *Sin asignar* y *Asignadas*. Datos de ejemplo: tres órdenes sin asignar y una asignada a PREP01.

#### Paradas retenidas

Una parada que el preparador **salta dos veces** queda **retenida**: algo impide recogerla. El preparador ya no la ve, pero sigue pendiente, conserva su reserva y su orden no se termina.

- Se ven en la pila **Paradas retenidas** del rol center, en la acción **Paradas retenidas** y en la columna *Con paradas retenidas* de las órdenes.
- La lista dice qué preparador la retuvo y cuándo.
- **Contenido de la ubicación** enseña qué hay en el hueco según SGA.
- **Buscar en otra ubicación** la resuelve: cancela la parada y crea paradas nuevas en otros huecos con stock del producto. Las nuevas vuelven al preparador de la orden. Si no hay stock en ningún otro hueco, la parada queda cancelada.
- Lo recogido del resto de la orden ya está en el pedido: no se duplica nada.

> **[CAPTURA 15]** Paradas de picking SGA, vista *Retenidas*, con la acción *Buscar en otra ubicación*. Datos de ejemplo: una parada retenida por PREP01.

#### Reubicaciones

Una reubicación lleva mercancía de almacenamiento a picking. Se crea sola cuando una ubicación de picking se queda a cero de un producto (por una recogida, un traslado, *Vaciar ubicación*, *Quitar de la ubicación* o un ajuste). También puedes planificarlas: **Planificar reubicaciones** repasa el almacén y repone los productos que no tienen nada en picking.

Hace falta stock disponible en almacenamiento; si no hay, no se crea. Trae como mucho un palé.

- Vistas **Por hacer** y **Hechas**.
- Acciones: **Planificar reubicaciones**, **Preparar**, **Cancelar** (libera la reserva) y **Orden**.

> **[CAPTURA 16]** Reubicaciones SGA, vista *Por hacer*, con una planificación recién hecha. Datos de ejemplo: dos reubicaciones de productos sin picking.

#### Etiquetas de ubicación

Cada hueco tiene su etiqueta, y el preparador lee en ella la ubicación de la que recoge. Deben estar pegadas antes de empezar a recoger. Se hace por pasillos:

1. En **Ubicaciones SGA**, filtra el pasillo y selecciona sus huecos.
2. Pulsa **Imprimir etiquetas** y pega cada una en su hueco.

> **[CAPTURA 17]** Ubicaciones SGA filtradas por un pasillo, con los huecos seleccionados y la acción *Imprimir etiquetas*. Datos de ejemplo: pasillo 101.

#### Quién es quién: responsable y carretillero

En **Configuración de usuarios**, en la línea de cada usuario:

- **Responsable picking SGA**: puede repartir órdenes y cambiar prioridades cuando se exige asignación. Es esta casilla la que manda, no el conjunto de permisos.
- **Carretillero SGA**: con *Siguiente orden* recibe las reubicaciones y no los pedidos (ver capítulo 4).

> **[CAPTURA 18]** Configuración de usuarios con las casillas *Responsable picking SGA* y *Carretillero SGA*. Datos de ejemplo: usuarios RESP01 y CARR01.

### 3.5 Consultas

#### ¿Dónde está el producto?

Escribe el *Producto* (y, si quieres, *Almacén* y *Lote*). Salen todas las ubicaciones donde está, por caducidad. *Solo con cantidad disponible* oculta lo bloqueado y lo reservado. Se abre también desde la ficha o la lista de productos: grupo **SGA** > **¿Dónde está?**

**Un palé concreto:** lee su etiqueta (o teclea los 18 dígitos) en *SSCC*. Salen las ubicaciones en las que está: el palé y, si se ha partido, sus cajas en otros huecos.

> **[CAPTURA 19]** ¿Dónde está el producto? con un producto buscado y varias ubicaciones. Datos de ejemplo: un producto con tres huecos.

> **[CAPTURA 20]** ¿Dónde está el producto? buscando por SSCC. Datos de ejemplo: un SSCC real de la base de pruebas.

#### Ubicaciones SGA

La lista de huecos con su estado y su ocupación, coloreada: gris vacía, verde con hueco, amarillo llena y rojo bloqueada.

- Vistas: **Vacías**, **Con hueco**, **Llenas**, **Bloqueadas**, **Reservadas**, **Picking**, **Almacenamiento** y **Sin tipo**.
- Acciones: **Cambiar en bloque**, **Imprimir etiquetas**, **Liberar reserva**, **Bloquear / desbloquear**, **Recalcular ocupación**.
- En la ficha de la ubicación: **Vaciar ubicación** (todo queda sin ubicar; el stock de BC no cambia), **Movimientos de entrada** y **Movimientos de salida**.

> **[CAPTURA 21]** Ubicaciones SGA con sus colores de estado. Datos de ejemplo: huecos vacíos, con hueco, llenos y uno bloqueado.

#### Contenido de ubicaciones

Qué producto, lote y palé (SSCC) hay en cada hueco: una línea por palé. Vistas **Bloqueado** y **Con reserva**.

- **Trasladar**: a otra ubicación. Si eliges *Zona destino*, propone un hueco de esa zona y dice por qué.
- **Bloquear / desbloquear** una línea (por ejemplo, un lote en cuarentena).
- **Recontar**: tecleas la *Cantidad contada* y la diferencia queda registrada, sea de más o de menos.
- **Quitar de la ubicación**: la línea sale entera y queda pendiente de ubicar. No deja hacerlo si está reservada.
- **Movimientos del palé**: la historia del SSCC de la línea.

> **[CAPTURA 22]** Contenido de ubicaciones con SSCC visible y la acción *Movimientos del palé*. Datos de ejemplo: un palé trasladado de un hueco a otro.

#### Mapa de almacén

Una rejilla por *Almacén* y *Pasillo*: una fila por altura y una columna por estantería. Gris vacía, verde con hueco, naranja llena, rojo bloqueada y azul (*RESERV*) reservada para una entrada que se está ubicando. Pulsar una celda abre su contenido.

> **[CAPTURA 23]** Mapa de almacén de un pasillo con los cinco estados. Datos de ejemplo: pasillo 101.

#### Mapa 3D de almacén

- Arriba, *Almacén*, *Zona* y *Pasillo*. En el lienzo hay tres vistas: **3D**, **Planta** y **Frente** (un pasillo de frente, la de trabajo).
- **Colorear por**: *Estado*, *Posición ABC* (la clase de cada hueco por su posición), *Rotación ABC* (la clase del producto que hay dentro) o *Caducidad*. Por estado, las reservadas para una entrada salen en turquesa.
- **Buscar**: un producto o una ubicación; las coincidencias se marcan en naranja.
- Con el ratón: pasar por encima enseña lo que hay; clic abre el contenido; doble clic aísla el pasillo; clic derecho vacía la ubicación; arrastrar una ubicación con contenido sobre otra la traslada, solo dentro de la misma zona.

> **[CAPTURA 24]** Mapa 3D de almacén en vista *Frente*, con *Colorear por Estado*. Datos de ejemplo: pasillo 101.

#### Movimientos de ubicación

El diario de todo: quién movió qué, cuándo y de dónde a dónde. Vistas **Traslados** y **Ajustes y recuentos**.

> **[CAPTURA 25]** Movimientos de ubicación, vista *Traslados*. Datos de ejemplo: un traslado y un recuento del mismo día.

#### Conciliación con el stock

Compara lo que dice Business Central con lo que hay en las ubicaciones.

1. En el informe **Conciliar con el stock** (grupo *Informes*), elige *Almacén* y *Mostrar solo diferencias*.
2. El último resultado se vuelve a abrir en **Conciliación con el stock** (grupo *Consultas*). Vistas **Stock sin ubicar** (Business Central tiene más que las ubicaciones) y **Sobra en ubicaciones** (las ubicaciones tienen más que Business Central).
3. Lo que falta, mejor ubicarlo en su sitio. Si no, **Regularizar en ubicación de ajustes** lo deja en la ubicación de ajustes, sin SSCC: es una diferencia, no un palé. Lo que sobra no se regulariza: se recuenta.
4. **Volver a conciliar** para comprobar.

Conviene lanzarla al final del día o cuando alguien no encuentre un producto.

> **[CAPTURA 26]** Conciliación con el stock, vista *Stock sin ubicar*, con la acción *Regularizar en ubicación de ajustes*. Datos de ejemplo: una diferencia de cinco unidades.

#### Análisis ABC (solo observa)

Clasifica los productos por los palés que salen: **A** los que más, **C** los que menos. **No cambia nada**: sirve para decidir si conviene ubicar por rotación.

- **Calcular ahora** hace un cálculo nuevo; **Cálculos anteriores** guarda los de antes.
- El *Resumen* da la concentración, las clases, los huecos y los avisos.
- **Mostrar** filtra la lista: una clase, los que cambian de clase o los que están fuera de su clase.

> **[CAPTURA 27]** Análisis ABC SGA con el resumen y una clase filtrada. Datos de ejemplo: un cálculo de los últimos 90 días.

### 3.6 Ventas y compras (solo consulta)

Desde el grupo *Ventas y compras* se abren las listas estándar de Business Central, ya dentro de SGA: **Productos**, **Pedidos de venta**, **Histórico de albaranes de venta**, **Pedidos de compra** e **Histórico de albaranes de compra**. Desde ellas se llega al pedido y a su pestaña **Almacén SGA** (ver capítulo 5).

### 3.7 Informes y configuración

- **Informes**: *Conciliar con el stock* (ver 3.5).
- **Configuración**: *Configuración SGA* (solo consulta para el almacén; los cambios los hace el administrador, capítulo 6), *Zonas*, *Ubicaciones del almacén*, *Generar ubicaciones*, *Sincronizar ubicaciones*, *Carga inicial de contenido* e *Inicializar contenido*.

> **Atención:** **Inicializar contenido** borra todo el contenido ubicado, los movimientos de ubicación y las órdenes de picking sin terminar del almacén. Las ubicaciones se conservan. Úsalo solo para repetir la carga inicial desde cero.

> **[CAPTURA 28]** Grupo *Almacén SGA - Configuración* del rol center. Datos de ejemplo: ninguno.

## 4. Rol Preparador SGA (PDA)

El rol del preparador y del carretillero, en un terminal de mano. Lo justo para preparar: la primera opción abre la pantalla de preparación, que busca sola la orden que te toca y encadena una tras otra.

> **[CAPTURA 29]** Rol center del preparador en la PDA, con *Preparar pedidos SGA* arriba. Datos de ejemplo: usuario PREP01.

### 4.1 Preparar el terminal (una vez)

Terminal Android con lector integrado y la app de **Business Central** instalada desde Google Play. En el programa del lector (en Zebra, *DataWedge*), crea un perfil para la app de Business Central con la salida por *Intent*:

| Ajuste | Valor |
|---|---|
| Intent delivery | Broadcast intent |
| Intent action | `com.businesscentral.barcode.receive_barcode` |
| Intent category | `com.businesscentral.barcode.receive_category` |
| Clave del dato (Honeywell, Datalogic) | `com.symbol.datawedge.data_string` |
| Clave del tipo (Honeywell, Datalogic) | `com.symbol.datawedge.label_type` |

En Zebra las claves ya son esas. Desactiva la salida por teclado del mismo perfil. Un lector que escribe como un teclado (de anillo, Bluetooth) también vale sin configurar nada.

### 4.2 Preparar pedidos

1. Entra con el rol **Preparador SGA (PDA)** y pulsa **Preparar pedidos SGA**. Se abre la orden que te toca. Al terminarla carga la siguiente; si no hay más, ofrece **BUSCAR SIGUIENTE ORDEN**.
2. Ve a la ubicación, coge el producto y **escanéalo**. Si no es el de la parada, lo dice al momento.
3. Escanea el **código de la ubicación** de la etiqueta del hueco. Si no se lee, tecléalo.
4. Si coges otra cantidad, cámbiala antes.
5. La parada se confirma sola y pasa a la siguiente.

El cursor está siempre en la casilla que toca leer (ubicación o producto). La pantalla no abre el teclado del terminal hasta que tocas una casilla.

> **[CAPTURA 30]** Preparar picking SGA en la PDA: bloques *VAYA A*, *COJA* y *CONFIRME*. Datos de ejemplo: una parada de un pedido con playa.

> **[CAPTURA 31]** Preparar picking SGA con una lectura incorrecta en rojo. Datos de ejemplo: escanear un producto que no es el de la parada.

**Cómo se lee cada parada:**

- **VAYA A**: la ubicación, en grande. En un pedido, al lado, **→ PLAYA** y la playa donde dejar lo recogido. En una reubicación: **DE** origen **→ A** destino.
- **COJA**: la cantidad, en la unidad del pedido. Debajo, la descripción del producto y, en pequeño, su código, el lote, la caducidad, el palé (SSCC) y la cantidad en unidades base.
- **CONFIRME**: lo que falta para confirmar (*Ubicación*, *Producto*). En rojo, pendiente; en verde, hecho.

**Lecturas.** Lee, en este orden, la **ubicación** de la etiqueta del hueco y, si se pide, el **producto** que coges. Cada lectura puede ser un escaneo o teclearse. Si una lectura no es correcta, la pantalla lo dice en rojo, con un pitido grave: vuelve a escanear o a teclear.

- El producto se reconoce por su código de barras, su GTIN o su número de producto, y también por una etiqueta GS1-128 con (01) o (02). Si la etiqueta trae el lote (10), tiene que ser el de la parada.
- El palé **no se lee**: se da por bueno que lo que coges es del palé de la parada (o del palé de ese hueco, si coges de otro).

**Otros botones:**

- **Saltar**: deja la parada para el final. Al acabar el recorrido vuelven a salir las saltadas. Si la saltas por segunda vez queda **retenida** para el responsable y ya no vuelve a salir. Cuando solo quedan retenidas, la orden se da por recorrida y pasas a la siguiente.
- **Sin stock**: si el producto no está en el hueco. Pregunta si buscar en otra ubicación. La pantalla dice de dónde se recoge en su lugar. Si no hay en ninguna, el aviso sale en rojo.

Si recoges de otro hueco, avisa: que lo admita depende de la configuración de desvíos. Al terminar sale *Orden terminada*, la playa en la que dejarla y que lo recogido ya está en el pedido. Si dice que no se ha podido pasar al pedido, avisa a oficina: no se pierde nada.

**De dónde se recoge.** La orden se arma en tres pasadas: primero **palés completos** de almacenamiento, luego **picking**, y lo que falte del resto de almacenamiento. Dentro de cada pasada manda la estrategia de picking de la configuración:

| Estrategia de picking | Qué se coge antes |
|---|---|
| **FIFO** (por defecto) | Lo que entró antes |
| **FEFO** | Lo que caduca antes |
| **Vaciar ubicación** | Por orden de código de ubicación, para ir dejando huecos vacíos |

### 4.3 Órdenes y reubicaciones (carretillero)

**Mi picking** cuenta las órdenes y las reubicaciones sin terminar que te tocan y, si la configuración no exige asignación, las órdenes sin asignar que puedes coger.

- Con **Carretillero SGA** marcado, **Siguiente orden** te da primero lo tuyo y, si no tienes, la siguiente **reubicación** sin asignar. Nunca un pedido.
- Sin marcar, al revés: pedidos y nunca reubicaciones.
- Lo que el responsable te asigna siempre te llega, sea pedido o reubicación.

**Cómo se hace una reubicación:** en *Preparar picking SGA*, la primera línea dice **DE** origen **→ A** ubicación de picking. Recoge en el origen y confirma como cualquier parada: la mercancía pasa al destino. Si es un palé justo, la cantidad sale en palés.

> **[CAPTURA 32]** Preparar picking SGA en una reubicación, con la línea *DE → A*. Datos de ejemplo: origen 201-01-01 y destino 101-03-01.

### 4.4 Consulta desde la PDA

- **¿Dónde está el producto?**: busca un producto (o un SSCC) y dice a qué ubicación ir a recogerlo.
- **Contenido de ubicaciones**: qué hay en cada hueco.

Son las mismas pantallas que en el ordenador, pero con la lista pensada para leer en el terminal (ver capítulo 3.5).

## 5. Oficina: Procesador de pedidos

Toda venta sale por picking. **No uses las acciones de almacén estándar de Business Central** para servir un pedido: se hace desde SGA.

El rol **Procesador de pedidos** tiene los mismos menús de SGA que el rol de almacén, así que todo lo del capítulo 3 se encuentra igual desde aquí.

### 5.1 Enviar un pedido a SGA

1. Lanza el pedido.
2. En el pedido, pestaña **Almacén SGA**, pulsa **Enviar a SGA**.
3. SGA reparte el pedido en **órdenes de picking de un palé como mucho**, porque solo se prepara un palé a la vez:
   - cada palé completo de una línea es una orden;
   - las cajas y unidades sueltas de todas las líneas se juntan en órdenes que no pasan de un palé. Por ejemplo, medio palé de un producto y un cuarto de otro van en la misma orden.

   Por ejemplo, 4 palés y 2 cajas son 5 órdenes.
4. Busca de qué ubicación y lote coger cada cosa y lo **reserva**: otro pedido ya no lo ve disponible.
5. Si el pedido ya se preparó en parte, solo manda lo que falta.

No deja enviarlo si el pedido no está lanzado, si tiene alguna orden de picking sin terminar o si algún producto no tiene palé en su ficha (*Cód. palé por defecto*).

**Un pedido enviado a SGA ya no se puede volver a abrir.**

> **[CAPTURA 33]** Pedido de venta, pestaña *Almacén SGA*, con la acción *Enviar a SGA*. Datos de ejemplo: un pedido lanzado con tres líneas.

### 5.2 Si falta stock: dos rondas

- **Primera ronda.** Las órdenes se crean con lo que hay. El aviso dice, producto a producto, qué falta y cuánto, en la unidad del pedido. Solo da error si no hay nada ubicado de ningún producto del pedido.
- **Segunda ronda.** Cuando ya haya stock ubicado (porque ha llegado una compra o se ha ubicado lo pendiente) y estén terminadas todas las órdenes del pedido:
  - **Un pedido:** vuelve a pulsar **Enviar a SGA**. Solo manda lo que falta.
  - **Todos a la vez:** en **Órdenes de picking SGA**, pulsa **Segunda ronda de picking**. Crea las órdenes de cada pedido que aún tenga algo pendiente, ya tenga stock y no tenga órdenes sin terminar. Dice cuántas ha creado y cuántos pedidos siguen esperando.

Mientras tanto el pedido sale como **Parcial** en la lista de pedidos. Si se decide servirlo así, se registra el envío de lo preparado como siempre.

### 5.3 Ver cuánto está preparado

- **Estado preparación SGA**, en la cabecera del pedido y en la lista: *Sin preparar*, *Parcial* o *Preparado*. En blanco si no queda nada por enviar.
- En la lista de pedidos, pestaña **Almacén SGA**: **Ver preparados**, **Ver preparados en parte** y **Ver todos**.
- En las líneas, la columna **Cantidad preparada** (si no se ve, añádela con *Personalizar*).
- Una orden *Finalizada* no siempre es un pedido *Preparado*: si faltaba stock o se marcó *Sin stock*, queda *Parcial*.

> **[CAPTURA 34]** Lista de pedidos de venta con la columna *Estado preparación SGA* y la vista *Ver preparados en parte*. Datos de ejemplo: un pedido *Parcial* y uno *Preparado*.

### 5.4 Pasar al pedido

Al terminar la orden, SGA rellena solo la **cantidad a enviar** y los **lotes** de cada línea. Lo que no se ha recogido queda con cantidad a enviar cero. Después se registra el envío como siempre.

Si el paso falla, repítelo con **Pasar picking al pedido** (desde el pedido) o **Pasar al pedido** (desde la orden). La vista *Terminadas sin pasar al pedido* de *Órdenes de picking* enseña las que faltan.

> **No cambies a mano la cantidad a enviar ni los lotes del pedido**: SGA no se entera.

## 6. Administración

Quien pone en marcha SGA configura las ubicaciones, las estrategias y los controles. Esa parte tiene su propio documento: **MANUAL_IMPLANTACION_SGA.md**, en la carpeta *Otros*.

Las páginas de configuración son:

| Página | Qué se configura |
|---|---|
| **Configuración SGA** | Almacén y zona por defecto, fecha inicio SGA, ubicación de ajustes, estrategias de ubicación y de picking, análisis ABC, controles (capacidad, desvíos, escaneo, asignación de picking) y numeración |
| **Zonas** | Agrupar ubicaciones por zona y grupo IIEE, y dar la secuencia de picking inicial de sus ubicaciones |
| **Ubicaciones del almacén** | Ubicaciones estándar sobre las que SGA añade sus datos (tipo, capacidad, mezclas, producto fijo) |
| **Generar ubicaciones** | Crea la estructura del almacén a partir de los rangos de pasillo, estantería y altura |
| **Sincronizar ubicaciones** | Da de alta en SGA las ubicaciones que todavía no tienen datos |
| **Carga inicial de contenido** | Reparte el stock que ya tiene Business Central entre las ubicaciones. Conviene lanzarla primero en simulación |
| **Inicializar contenido** | Deja el almacén sin nada ubicado para repetir la carga inicial desde cero |

> **[CAPTURA 35]** Configuración SGA, grupo *General* y grupo *Estrategias*. Datos de ejemplo: almacén 1, fecha inicio SGA de la puesta en marcha.

> **[CAPTURA 36]** Carga inicial de contenido en modo *Solo simular*, con el resultado de lo que se ha quedado fuera y por qué. Datos de ejemplo: un producto sin palé en su ficha.

## 7. Si algo falla

Lo más frecuente está aquí. Los casos con más detalle, con su causa y su solución paso a paso, están en **TROUBLESHOOTING.md**, en la carpeta *Otros*.

| Síntoma | Qué hacer |
|---|---|
| *¿Dónde está el producto?* no lo encuentra | Quita los filtros de *Lote* y *Almacén*. Si sigue sin salir, no está ubicado: búscalo en *Pendiente de ubicar*. |
| No propone una ubicación que existe | Casi siempre no tiene tipo (vista *Sin tipo*). Si no, está bloqueada, es de otro producto fijo, no tiene sitio o espera una reubicación. |
| *No se puede ubicar*: no queda espacio | Libera ubicaciones, amplía su capacidad en palés o crea más. |
| *No se puede ubicar*: el producto no tiene palé | Rellena el *Cód. palé por defecto* del producto y vuelve a proponer. |
| Ha metido más de un palé en un hueco | El hueco tiene capacidad 0. Quita el contenido, pon capacidad = 1 y vuelve a ubicar. |
| La ocupación de una ubicación no cuadra | Ficha de la ubicación > *Recalcular ocupación*. |
| No me deja cambiar la configuración de una ubicación | Tiene contenido. Trasládalo o vacíalo; si solo quieres que no se use, bloquéala. |
| Una recepción no sale en *Ubicar recepciones* | Vacía las fechas y el producto, pon *Clase de artículo* = *Todas* y desmarca *Solo lo que falta por ubicar*. Si no entró por albarán de compra, usa *Ubicar producto*. |
| Deshice una recepción que ya estaba ubicada | *Contenido de ubicaciones* > *Recontar* con la cantidad real. |
| No deja enviar el pedido a picking | Lánzalo. Si ya tiene una orden abierta, termínala o cancélala. |
| La orden terminó pero el pedido no tiene cantidad a enviar ni lotes | Pulsa *Pasar al pedido* en la orden. |
| *Siguiente orden*: no tiene órdenes asignadas | Se exige asignación: el responsable reparte en *Asignar órdenes de picking*. |
| En la PDA no pasa nada al escanear | Revisa el perfil del lector (capítulo 4.1) y que la salida por teclado esté desactivada. Solo funciona en la app de Business Central. |
| *El código … no corresponde a ningún producto* | Da de alta el código como referencia de tipo *Código de barras* del producto o en su GTIN. |
| Un responsable no puede asignar | En *Configuración de usuarios*, marca *Responsable picking SGA*. |
| Un picking vacío no tiene reubicación | Revisa que haya stock disponible en almacenamiento, una ubicación de picking con sitio y la serie de órdenes. Luego *Planificar reubicaciones*. |
| El mapa 3D sale en blanco | Elige el almacén y vacía zona y pasillo. Los códigos deben seguir el formato `101-15-03`. |
| La ubicación leída no existe en SGA | La etiqueta que se ha leído no es de una ubicación SGA del almacén. Lee la etiqueta del hueco que tienes delante. |

## Anexo A. Lista de capturas

Cada captura se pega en el hueco de su número. Usa datos de la base de pruebas, nunca de clientes reales. Para los SSCC, usa uno que exista en la base de pruebas.

| Nº | Capítulo | Pantalla | Qué debe mostrar |
|---|---|---|---|
| 01 | 1 | Buscador (Alt+Q) | Búsqueda "Ubicar" con las pantallas de SGA |
| 02 | 2 | Mi configuración | Perfil "Almacén SGA" seleccionado |
| 03 | 3.1 | Rol center Almacén SGA | Los cinco grupos desplegados |
| 04 | 3.1 | Grupo Picking | Pilas con alguna en rojo y alguna en verde |
| 05 | 3.3 | Ubicar recepciones | Filtros, líneas con SSCC, A ubicar y propuesta |
| 06 | 3.3 | Ubicar ensamblados | Embotellado propuesto |
| 07 | 3.3 | Imprimir y ubicar palés | Tarea en línea y Siguiente palé |
| 08 | 3.3 | Ubicar producto: Dónde dejarlo | Una línea por palé con SSCC y otra con el resto |
| 09 | 3.3 | Ubicar producto: diálogo | "¿Ubicar ahora palé…?" |
| 10 | 3.3 | Pendiente de ubicar | Stock BC, Ubicado, Sin ubicar, En recepciones |
| 11 | 3.3 | Ubicar seleccionadas: opciones | Ubicar ahora / Solo simular |
| 12 | 3.3 | Ubicar seleccionadas: resultado | Lo ubicado y lo que no cabe con su motivo |
| 13 | 3.4 | Órdenes de picking | Órdenes en distintos estados |
| 14 | 3.4 | Asignar órdenes de picking | Vistas Sin asignar y Asignadas |
| 15 | 3.4 | Paradas retenidas | Parada retenida con Buscar en otra ubicación |
| 16 | 3.4 | Reubicaciones | Vista Por hacer tras planificar |
| 17 | 3.4 | Ubicaciones SGA filtradas por pasillo | Huecos seleccionados e Imprimir etiquetas |
| 18 | 3.4 | Configuración de usuarios | Casillas Responsable y Carretillero |
| 19 | 3.5 | ¿Dónde está el producto? | Producto con varias ubicaciones |
| 20 | 3.5 | ¿Dónde está el producto?: por SSCC | Búsqueda de un palé |
| 21 | 3.5 | Ubicaciones SGA | Colores de estado |
| 22 | 3.5 | Contenido de ubicaciones | SSCC visible y Movimientos del palé |
| 23 | 3.5 | Mapa de almacén | Pasillo con los cinco estados |
| 24 | 3.5 | Mapa 3D de almacén | Vista Frente, colorear por Estado |
| 25 | 3.5 | Movimientos de ubicación | Vista Traslados |
| 26 | 3.5 | Conciliación con el stock | Stock sin ubicar y Regularizar |
| 27 | 3.5 | Análisis ABC | Resumen y una clase filtrada |
| 28 | 3.7 | Configuración del rol center | Grupo Almacén SGA - Configuración |
| 29 | 4 | Rol center del preparador (PDA) | Preparar pedidos SGA arriba |
| 30 | 4.2 | Preparar picking en la PDA | VAYA A, COJA y CONFIRME |
| 31 | 4.2 | Preparar picking: lectura incorrecta | Mensaje en rojo |
| 32 | 4.3 | Reubicación en la PDA | Línea DE → A |
| 33 | 5.1 | Pedido de venta, pestaña Almacén SGA | Acción Enviar a SGA |
| 34 | 5.3 | Lista de pedidos con estado de preparación | Pedidos Parcial y Preparado |
| 35 | 6 | Configuración SGA | Grupos General y Estrategias |
| 36 | 6 | Carga inicial en simulación | Resultado con lo que queda fuera |
