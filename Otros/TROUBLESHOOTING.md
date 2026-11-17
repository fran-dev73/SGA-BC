# Troubleshooting SGA — Casos comunes y cómo resolverlos

---

## "Lancé la carga inicial y todo metió en una sola ubicación"

**Síntoma**: Después de ejecutar *Carga inicial de contenido*, todo el stock aparece en la misma ubicación (normalmente la de ajustes).

**Causa**: Se lanzó con *Ubicación de destino* = *Ubicación indicada* o *Ubicación fija del producto*. Con *Ubicación indicada* todo va a esa ubicación. Con *Ubicación fija del producto* cada producto va a su casa (la ubicación que lo tiene como *Producto fijo* o el *Nº estante* de su ficha), y los que no tienen casa van a la indicada. La indicada sale por defecto con la *Ubic. ajustes* de la configuración.

**Solución**: usa **Huecos libres**, que reparte cada palé a su hueco. Si ya cargaste:
1. Abre la ficha de esa ubicación y pulsa **Vaciar ubicación**. Todo queda pendiente de ubicar. El stock de BC no cambia.
2. Relanza la carga con *Huecos libres*, primero con **Solo simular**. Solo carga lo que falta por ubicar.

---

## "La carga inicial por huecos libres ha dejado cosas sin cargar"

Al terminar se abre **Resultado de la carga inicial**. La vista **No cargado** enseña lo que se ha quedado fuera, y la columna *Motivo* dice por qué.

| El motivo dice… | Qué pasa | Qué hacer |
|---|---|---|
| *No queda espacio (almacén …): N de M ubicaciones están llenas o sin sitio…* | La mayoría de las ubicaciones no tienen sitio. Sigue un desglose del resto (bloqueadas, con otro producto…) | Libera ubicaciones, amplía su *Capacidad (palés)* o crea más |
| *No hay ninguna ubicación de almacenamiento ni de picking en el almacén …* | Ninguna ubicación tiene tipo | Pon *Tipo ubicación* = *Almacenamiento* o *Picking* a las ubicaciones donde se guarda la mercancía |
| *Ninguna de las N ubicaciones del almacén … sirve para…* | Hay sitio, pero no sirven por otra razón. Dice cuántas por cada una | Según el desglose (ver "En *Ubicar producto* una línea sale como *No se puede ubicar*") |
| … *de picking, porque el producto ya ocupa todas las ubicaciones de picking que se le permiten* | El producto ya llena su cupo de picking y no queda sitio en almacenamiento | Libera almacenamiento o sube *Máx. ubicaciones de picking por producto* |
| *El producto no tiene palé por defecto en su ficha, así que no se puede repartir por huecos…* | Sin palé no se reparte por huecos | Rellena su *Cód. palé por defecto* y relanza la carga: solo carga lo que falta |
| *El producto … no tiene palé en su ficha y la capacidad de las ubicaciones se cuenta en palés…* | Sin palé no se puede medir lo que ocupa | Igual: rellena el *Cód. palé por defecto* |
| *Producto bloqueado.* | | Desbloquéalo si tiene que estar en almacén |

Cómo reparte *Huecos libres*: cada palé completo a un hueco vacío, siguiendo la ruta. Primero picking, sin pasar de *Máx. ubicaciones de picking por producto*, y luego almacenamiento. El resto del lote, junto, a un hueco con sitio, mejor donde ya esté el producto. Las ubicaciones sin tipo no se usan nunca.

Lo que no se carga se ve, lote a lote, en **Pendiente de ubicar**. Desde ahí se ubica a mano (**Ubicar**) o se busca hueco para varias líneas a la vez (**Ubicar seleccionadas**, con opción de simular).

---

## "La ocupación de una ubicación dice 150% y no tiene sentido"

**Síntoma**: *% ocupación* > 100 en una ubicación, o el *Estado* dice *Llena* y aún cabe más.

**Causas posibles**:
1. **Capacidad 0**: sin capacidad declarada, con cualquier cosa dentro sale *Llena* al 100%.
2. **Se dejó por encima de la capacidad**: la carga inicial, un recuento al alza y la regularización de la conciliación no miran la capacidad. Con *Control capacidad* = *Avisar*, una entrada que no cabe se deja si se confirma.
3. **Datos sin recalcular**: se ha cambiado el *Cód. palé por defecto* de un producto que ya está ubicado, y eso cambia cuántos palés cuenta su contenido. La propuesta de hueco usa el estado y el % guardados: hasta recalcular, puede no ofrecer una ubicación que tiene sitio.

**Solución**:
1. Abre la ficha de la ubicación (*Ubicaciones SGA* > pulsa su código).
2. Pulsa **Recalcular ocupación**.
3. Para todo el almacén: *Ubicaciones SGA* > **Recalcular ocupación**.

Si sigue por encima de 100, es que de verdad tiene más de lo que dice su capacidad: traslada lo que sobre.

---

## "¿Dónde está el producto? me devuelve vacío"

**Síntoma**: Buscas un producto que sabes que existe y no aparece nada.

**Causas posibles**:
1. El producto **no está ubicado**: está en BC pero en ninguna ubicación.
2. Tienes marcado *Solo con cantidad disponible*, y todo lo que hay está bloqueado o reservado.
3. Estás filtrando por un *Lote* que no es.
4. Estás filtrando por un *Almacén* y el producto está en otro.

**Solución**:
1. Abre *¿Dónde está el producto?*.
2. Busca el producto sin filtros de *Lote* ni *Almacén* y desmarca *Solo con cantidad disponible*.
3. Si sale algo: está ubicado. Mira si está bloqueado o reservado.
4. Si **no sale nada**: búscalo en **Pendiente de ubicar** y ubícalo desde ahí con **Ubicar**.

---

## "Conciliar dice que falta stock en las ubicaciones"

**Síntoma**: *Conciliar con el stock* enseña una diferencia grande que no esperas.

**Causas posibles**:
1. **Está pendiente en *Ubicar recepciones* o *Ubicar ensamblados***: ha entrado en BC y aún no se ha colocado.
2. **Ha entrado en BC por otra vía**: un diario de producto, un ajuste positivo… Eso no pasa por ninguna pantalla de SGA.

**Solución**:
1. Abre el resultado (*Conciliación con el stock*), vista **Stock sin ubicar**.
2. Mira qué producto es y de dónde viene.
3. Si espera en *Ubicar recepciones* o *Ubicar ensamblados*: ubícalo desde allí.
4. Si no: **no regularices aún**. Ubícalo en su sitio desde *Pendiente de ubicar* > **Ubicar**.
5. Pulsa **Volver a conciliar**.

Si regularizas directamente, todo va a la ubicación de ajustes, y el picking no coge de ella. Luego hay que trasladarlo a su hueco.

---

## "Hay un lote bloqueado y no consigo que se use"

**Síntoma**: Desbloqueas una línea de contenido, pero el picking sigue sin cogerla o no se puede dejar mercancía en esa ubicación.

**Causa**: Hay tres bloqueos distintos: el de la línea, el de la ubicación y el de su zona. Desbloquear uno no desbloquea los otros.

**Solución**:
1. **La línea**: *Contenido de ubicaciones*, filtra por esa ubicación, mira la columna *Bloqueado* y pulsa **Bloquear / desbloquear** sobre esa línea.
2. **La ubicación**: *Ubicaciones SGA*, selecciónala y pulsa **Bloquear / desbloquear**. O en su ficha, desmarca *Bloqueada*. Limpia el *Motivo bloqueo* si ya no aplica.
3. **La zona**: *Zonas*, desmarca *Bloqueada* en su zona.

No se puede bloquear una línea con cantidad reservada: sale *No se puede bloquear: … están reservados por órdenes de picking…*. Antes hay que cancelar esas paradas o buscar en otra ubicación.

---

## "Lancé un traslado y no se hizo"

**Síntoma**: Al trasladar sale un mensaje y la mercancía sigue en el origen.

**Causa**: La ubicación destino no admite la mercancía. Un traslado es todo o nada: si se rechaza, no cambia ni el origen ni el destino.

**Solución**: lee el mensaje y mira "Al dejar mercancía me dice que la ubicación no la admite". Además, en el traslado:
- *La ubicación de destino no puede ser la misma que la de origen.*
- *No puede trasladar más de N unidades.*: es lo disponible en la línea (lo reservado no cuenta).
- Desde el mapa 3D, *La ubicación … es de la zona … y la … de la zona …*: entre zonas se traslada desde *Contenido de ubicaciones* > **Trasladar**.

---

## "El mapa de almacén no muestra todas las estanterías de mi pasillo"

**Síntoma**: Abres el mapa y faltan las estanterías del final, aunque sabes que hay ubicaciones allí.

**Causas**:
1. El mapa dibuja como mucho 32 columnas, una por estantería. Es un límite de pantalla, no de datos. El aviso lo dice: *Hay estanterías hasta la N y la rejilla solo dibuja 32…*.
2. La ubicación no sigue el formato de código `pasillo-estantería-altura` (`101-15-03`). Las que tienen otro formato no salen en el mapa.

**Solución**:
1. Filtra por **Pasillo** para ver ese pasillo de frente.
2. Para las estanterías más allá de la 32 usa el **mapa 3D**, o la lista *Ubicaciones SGA* y, si lo quieres en Excel, *Abrir en Excel*.

**Nota**: el mapa se reconstruye al abrirlo y con **Actualizar**. Si no ves una ubicación recién creada, pulsa *Actualizar*.

---

## "Me ha metido más de un palé en la misma ubicación"

**Causa más probable**: la ubicación tiene *Capacidad (palés)* = 0, que significa *sin límite*. Con la estrategia estándar, SGA consolida el mismo producto donde ya está, y sin límite le caben todos los palés.

**Solución**:
1. Deshaz lo mal ubicado: *Contenido de ubicaciones*, filtra por esa ubicación, selecciona las líneas y pulsa **Quitar de la ubicación**. Quedan pendientes de ubicar.
2. Con la ubicación ya vacía, pon *Capacidad (palés)* = 1 en su ficha. Para muchas a la vez: *Ubicaciones SGA* > **Cambiar en bloque** (las que tengan contenido no se cambian). Al generarlas, rellena *Capacidad (palés)* con 1.
3. Vuelve a ubicar con *Ubicar producto* > **Ubicar todo lo pendiente** > **Proponer ubicación**: ahora irá un palé por hueco.

---

## "En *Ubicar producto* una línea sale como *No se puede ubicar*"

**Síntoma**: En la tabla *Dónde dejarlo*, una línea sale como **No se puede ubicar**.

**Causa**: Ninguna ubicación la admite. La columna *Motivo* dice por qué:

| El motivo dice | Qué hacer |
|---|---|
| *No hay ninguna ubicación de almacenamiento ni de picking en el almacén …* | Pon *Tipo ubicación* = *Almacenamiento* o *Picking* a las ubicaciones donde se guarda la mercancía. |
| *No queda espacio (almacén …): N de M ubicaciones están llenas o sin sitio…* | Libera ubicaciones, amplía su *Capacidad (palés)* o crea más. |
| *El producto … no tiene palé en su ficha y la capacidad de las ubicaciones se cuenta en palés…* | Rellena el *Cód. palé por defecto* del producto. |
| *Ninguna de las N ubicaciones del almacén … sirve para…*, con el desglose: | |
| · *bloqueadas* | Desbloquea la ubicación o su zona. |
| · *reservadas a otro producto ("Producto fijo")* | Son la casa de otro producto. Quita el *Producto fijo* si ya no lo es. |
| · *llenas o sin sitio* | Libera o amplía su *Capacidad (palés)*. |
| · *con otro producto (no aceptan mezcla)* | Elige otra o marca *Permite mezcla de productos* (solo con la ubicación vacía). |
| · *con otro lote (no aceptan mezcla de lotes)* | Igual, con *Permite mezcla de lotes*. |
| · *vacías, esperando una reubicación de otro producto* | Son de picking y esperan su producto. Se liberan al hacer o cancelar esa reubicación. |
| · *con sitio, pero ya propuestas a otras líneas de este reparto* | Confirma las líneas que tienen hueco y vuelve a pulsar *Proponer ubicación*. |
| · *reservadas para otra entrada que se está ubicando* | Espera, o *Ubicaciones SGA* > vista *Reservadas* > **Liberar reserva** si nadie las está usando. |
| *No queda ningún hueco vacío que admita …* | La estrategia es *Solo hueco vacío*: libera un hueco o cambia la estrategia en *Configuración SGA*. |
| *… no tiene ubicación fija con sitio…* | La estrategia es *Solo ubicación fija*: dale casa al producto (*Producto fijo* o *Nº estante*) o cambia la estrategia. |

Después vuelve a pulsar **Proponer ubicación**.

---

## "No me propone una ubicación que existe"

**Causa**: casi siempre, la ubicación **no tiene tipo**. *Sincronizar ubicaciones* da de alta las ubicaciones así; *Generar ubicaciones* les pone el tipo. Una ubicación sin tipo **no se propone nunca**.

Si tiene tipo, puede ser que:
- Está bloqueada, ella o su zona.
- Es la casa de otro producto (*Producto fijo*).
- Está reservada para otra entrada que se está ubicando.
- No tiene sitio, o tiene otro producto o lote y no acepta mezcla.
- Es de picking y espera una reubicación de otro producto.
- Es de picking y hay sitio en almacenamiento: al ubicar se propone primero almacenamiento.
- El producto tiene grupo IIEE con zonas y queda sitio en ellas: se propone primero ahí.

**Solución**: *Ubicaciones SGA* > vista **Sin tipo**. Abre la ficha (pulsa su código) y pon *Tipo ubicación* = *Almacenamiento* o *Picking*. Para muchas a la vez: selecciónalas y pulsa **Cambiar en bloque**.

---

## "Al dejar mercancía me dice que la ubicación no la admite"

**Síntoma**: Al confirmar una ubicación, al trasladar o al ubicar una entrada sale uno de estos mensajes:

| Mensaje | Qué hacer |
|---|---|
| *La ubicación … está bloqueada: …* | Elige otra, o desbloquéala (a ella o a su zona). |
| *La ubicación … está reservada para … (…).* | Está propuesta a otra entrada. Elige otra, o pide que la liberen (*Ubicaciones SGA* > **Liberar reserva**). |
| *La ubicación … está reservada para el producto ….* | Tiene *Producto fijo*: solo admite ese producto. |
| *La ubicación … no permite mezclar productos y ya contiene ….* | Elige otra. *Permite mezcla de productos* solo se cambia con la ubicación vacía. |
| *La ubicación … no permite mezclar lotes y ya contiene el lote ….* | Igual, con *Permite mezcla de lotes*. |
| *La ubicación … no tiene hueco: capacidad …, ocupado …, se intenta añadir ….* | El control de capacidad es *Bloquear*. Elige otra o libera sitio. |
| *La ubicación … se queda por encima de su capacidad (… de …). ¿Desea continuar?* | El control de capacidad es *Avisar*: si confirmas, se deja igualmente. |
| *La ubicación … no está en ninguna zona del grupo IIEE del producto … (…). ¿Desea dejarlo ahí de todos modos?* | Confirma si de verdad va ahí. |

El control de capacidad de cada ubicación está en su ficha (*Control capacidad*). Con *Según configuración* manda el de *Configuración SGA* > *Controles*.

---

## "El mapa 3D sale en blanco"

**Síntoma**: Abres *Mapa 3D de almacén* y el panel aparece vacío.

**Causas por orden de probabilidad**:
1. **No hay almacén seleccionado**: el campo *Almacén* está vacío y el *Resumen* dice *Indique un almacén para dibujar el mapa.* Se rellena con el almacén por defecto de la configuración; si no hay ninguno, elígelo a mano.
2. **Filtro demasiado estrecho**: el mapa se abre con la *Zona por defecto* de la configuración. Si esa zona no tiene ubicaciones, o tienes puesto un pasillo que no existe, no se dibuja nada. Vacía *Zona* y *Pasillo*.
3. **Las ubicaciones no siguen el formato de código**: el mapa saca la posición de cada bloque del código `pasillo-estantería-altura` (`101-15-03`: pasillo de 3 dígitos, estantería de 2 y altura de 2). Las ubicaciones con otro formato (otro número de partes, letras o una cantidad de dígitos distinta) no se dibujan. Compruébalo en la lista de ubicaciones.

---

## "Recuento manual: conté 80 pero el sistema dice que hay 100"

**Síntoma**: Pulsas **Recontar** en una línea de contenido, metes 80 en *Cantidad contada* y la *Diferencia* es -20.

La cantidad va en unidades base. El recuento corrige solo la ubicación: el stock de BC no cambia.

**Soluciones**:
1. **Si falta** (negativo): alguien cogió mercancía o la llevó a otro hueco sin registrarlo.
   - Mete el recuento (80). Queda un movimiento de recuento por -20.
   - Busca dónde está: *¿Dónde está el producto?*.
2. **Si sobra** (positivo): hay más de lo registrado.
   - Mete el recuento. Queda un movimiento de recuento por la diferencia.
   - Investiga de dónde ha salido.

Los recuentos se ven en *Movimientos de ubicación*, vista **Ajustes y recuentos**. Después lanza *Conciliar con el stock* para ver si las ubicaciones cuadran con BC.

---

## "No me deja cambiar la configuración de una ubicación"

**Síntoma**: En la ficha, tipo, capacidad, zona y el resto salen en gris. O al cambiar en bloque dice que *N no se han cambiado porque tienen contenido*.

**Causa**: la configuración de una ubicación solo se cambia **vacía**. Si no, lo que ya hay dentro podría dejar de cumplirla (dos palés en un hueco que pasa a ser de uno, dos productos en uno que deja de aceptar mezcla…).

**Solución**: traslada su contenido a otra ubicación o vacíala, y vuelve a cambiarla. Si lo que quieres es que no se use mientras tanto, **bloquéala**: eso sí se puede con mercancía dentro.

---

## "Quiero bajar la capacidad de una ubicación que está llena"

**Causa**: la capacidad es configuración, y solo se cambia con la ubicación vacía (ver el apartado anterior).

**Solución**: traslada lo que sobre a otra ubicación, vacíala, cambia la capacidad y vuelve a dejar lo que quepa.

---

## "Regularicé y la mercancía está en la ubicación de ajustes"

**Síntoma**: Después de regularizar, el producto sale en la ubicación de ajustes y no en su hueco.

**Causa**: *Regularizar en ubicación de ajustes* deja siempre la diferencia en la *Ubic. ajustes* de la configuración, sin SSCC. El picking no coge de esa ubicación.

**Solución**:
1. Abre *Contenido de ubicaciones* y filtra por la ubicación de ajustes.
2. Selecciona la línea y pulsa **Trasladar** a la ubicación donde está de verdad.

Los movimientos no se modifican ni se borran: lo mal hecho se corrige con otro movimiento.

**Mejor prevención**: en *Conciliación con el stock*, ubica lo que falta en su sitio antes de pensar en regularizar.

---

## "¿Por qué SGA y BC difieren en un lote que no debería existir?"

**Síntoma**: La conciliación enseña un lote con diferencia, pero ese lote está vencido hace meses.

**Causa**: BC y las ubicaciones no tienen lo mismo de ese lote.

**Solución**:
1. En *Conciliación con el stock*, selecciona la línea y pulsa **Movs. producto** para ver los movimientos de BC.
2. Si está en la vista **Stock sin ubicar**: BC tiene stock de ese lote. Si existe, ubícalo desde *Pendiente de ubicar*. Si no existe, hay que corregir el stock en BC.
3. Si está en la vista **Sobra en ubicaciones**: las ubicaciones tienen más que BC. Busca el lote con **Ubicaciones del producto** y haz un **Recontar** con la cantidad real.

---

## "Regularizar no funcionó"

**Síntoma**: Pulsas *Regularizar en ubicación de ajustes* en *Conciliación con el stock* y la diferencia sigue.

**Mensajes y qué hacer**:
- *En esta línea sobra contenido en las ubicaciones…*: lo que sobra no se regulariza. Recuenta las ubicaciones que tienen el producto.
- *Los … sin ubicar de esta línea están pendientes en Ubicar recepciones o Ubicar ensamblados…*: ubícalo desde esas pantallas.
- *Debe configurar la ubicación de ajustes en la configuración de SGA.*: pon la *Ubic. ajustes* en *Configuración SGA* > *Ubicaciones por flujo*.
- *No se puede regularizar en el almacén …: la ubicación de ajustes (…) es del almacén por defecto (…)…*: solo se regulariza en el almacén por defecto. En otro almacén, ubica la mercancía.
- *Esta línea ya cuadra.*: no hay nada que regularizar.

Después pulsa **Volver a conciliar**.

---

## "El contenido de las ubicaciones no cuadra con sus movimientos"

**Síntoma**: La ocupación descuadra o el contenido no se explica con los movimientos de ubicación.

**Causa**: El contenido y los movimientos solo se escriben desde la gestión de contenido de SGA. Cualquier otro intento desde BC da error (*El contenido de ubicación solo se puede modificar desde la gestión de contenido SGA…*). Si aun así descuadra, alguien ha escrito en las tablas por fuera de BC.

**Recuperación**:
1. Abre *Sincronizar ubicaciones*, marca **Reconstruir contenido desde los movimientos** y ejecuta.
   - Borra el contenido por ubicación y lo vuelve a construir desde el diario de movimientos.
   - Las reservas de las órdenes abiertas se vuelven a calcular y los bloqueos se conservan.
2. Después lanza *Conciliar con el stock* para comprobar que cuadra con BC.

---

## "¿Por qué tarda tanto la conciliación?"

**Síntoma**: *Conciliar con el stock* tarda mucho.

**Causa**: Recorre producto a producto todo el stock de BC y todo el contenido de las ubicaciones.

**Solución**:
1. Indica un *Almacén* (en blanco concilia todos).
2. Filtra los productos: por nº, categoría o grupo contable de inventario.
3. Deja sin marcar *Mostrar también las que cuadran*.

---

## "El preparador pulsa *Siguiente orden* y le dice que no tiene órdenes asignadas"

**Mensaje**: *No tiene órdenes de picking asignadas. Pida a su responsable que le asigne alguna.*

**Causa**: está activada *Exigir asignación de picking* y el responsable aún no le ha asignado nada. Las órdenes recién enviadas esperan como *Pendiente de asignar*.

**Solución**: el responsable abre *Asignar órdenes de picking*, vista *Sin asignar*, y las reparte con **Asignar a**. Si no queréis este paso, desmarca la casilla en *Configuración SGA* > *Controles*: las órdenes que estaban esperando pasan a cogerse con *Siguiente orden*.

---

## "Me dice que la orden está asignada a otro y solo la puede preparar el asignado"

**Mensaje**: *La orden … está asignada a …. Solo la puede preparar el preparador asignado.*

**Causa**: con *Exigir asignación de picking*, cada orden es de su preparador, y nadie más puede abrirla ni confirmar paradas.

**Solución**: si hay que cambiar de preparador (por ejemplo, porque el asignado se ha ido), el responsable la reasigna en *Asignar órdenes de picking*. Una orden empezada se puede reasignar, pero no dejar sin nadie.

---

## "Soy responsable y no me deja asignar órdenes"

**Síntoma**: Sale *Solo un responsable de picking puede asignar órdenes o cambiar su prioridad. Pida que le marquen "Responsable picking SGA" en Configuración de usuarios.* al abrir *Asignar órdenes de picking*, al cambiar el preparador o al tocar la prioridad.

**Causa**: con *Exigir asignación de picking* activo, solo pueden repartir los usuarios marcados como responsables. Tener el conjunto de permisos *SGA - Responsable de almacén* no basta.

**Solución**: en *Configuración de usuarios*, crea la línea del usuario si no existe y marca **Responsable picking SGA**.

---

## "No puedo quitar la asignación de una orden"

**Mensaje**: *La orden … ya está empezada. Reasígnela a otro preparador en lugar de dejarla sin asignar.*

**Causa**: la orden ya tiene recogidas (*En proceso*) y se exige asignación. Si se dejara sin nadie, quedaría a medias sin que ningún preparador la viera.

**Solución**: reasígnala a otro preparador.

---

## "Operario dice que no puede hacer picking desde SGA"

**Síntoma**: El operario abre la pantalla de picking y no ve las paradas que espera, o la ubicación no es la esperada.

**Causas comunes**:

1. **No hay orden de picking creada**: el pedido de venta está ahí pero **no se ha enviado** a SGA.
   - **Solución**: lanza el pedido y pulsa *Almacén SGA* > **Enviar a SGA**.

2. **No hay stock ubicado del producto**: si no hay nada ubicado de ningún producto del pedido, no se crea ninguna orden (*No se ha podido generar ninguna parada…*). Si falta solo de algunos, las órdenes se crean con lo que hay y el aviso dice qué falta.
   - **Solución**: ubica lo que hay (*Ubicar recepciones*, *Pendiente de ubicar*). Lo que falta se envía en una segunda ronda.

3. **El stock está bloqueado o en una ubicación que no se coge**: el picking no coge de líneas bloqueadas, de ubicaciones o zonas bloqueadas ni de la ubicación de ajustes.
   - **Solución**: desbloquea lo que proceda o traslada lo de ajustes a su hueco, y vuelve a enviar lo que falte.

4. **La parada se canceló o quedó retenida**: con **Sin stock**, la parada se cancela y lo que faltaba se busca en otra ubicación. Una parada saltada dos veces queda **retenida** y el preparador ya no la ve.
   - **Solución**: abre la ficha de la orden en *Órdenes de picking* y mira el estado de cada parada. Las retenidas se resuelven en *Paradas retenidas* con **Buscar en otra ubicación**.

5. **Hay stock ubicado pero está reservado**: otro pedido ya lo tiene en una orden abierta. En *Contenido de ubicaciones* se ve en *Cantidad reservada*.
   - **Solución**: espera a que se prepare la otra orden, o cancélala si ya no hace falta: al cancelar se libera la reserva.

**PDA**: el preparador entra con el rol **Preparador SGA (PDA)** y pulsa **Preparar pedidos SGA**, que abre la pantalla *Preparar picking SGA* con su siguiente orden. La preparación del terminal está en la guía de uso.

---

## "No me deja enviar el pedido a picking"

**Mensajes y qué hacer**:
- *No se puede enviar el pedido … a SGA* (Estado debe ser igual a «Lanzado»): lánzalo. Un pedido enviado a SGA ya no se puede volver a abrir.
- *El pedido … tiene sin terminar la orden de picking …*: lo que falte se envía cuando estén terminadas todas sus órdenes. Termínala o cancélala desde *Órdenes de picking*.
- *El pedido … no tiene nada pendiente de preparar…*: todo lo que queda por servir ya está recogido. Falta pasarlo al pedido y registrar el envío.
- *Estos productos no tienen palé en su ficha ("Cód. palé por defecto") y SGA prepara por palés…*: rellena el *Cód. palé por defecto* de esos productos.
- *Configure la serie "Nos. orden SGA" en la configuración de SGA…*: pon la serie en *Configuración SGA* > *Numeración*.
- *No se ha podido generar ninguna parada: no hay contenido ubicado disponible de los productos del pedido.*: ubica primero el stock.

---

## "La orden se terminó pero el pedido no tiene la cantidad a enviar ni los lotes"

**Síntoma**: Al terminar, el preparador vio *No se ha podido pasar al pedido …: … Avise a oficina para que lo pase desde la orden.* O la orden sale en la vista *Terminadas sin pasar al pedido*.

**Causas posibles**:
1. **La línea tiene reservas por lote**: alguien reservó un lote concreto en el pedido. SGA no las deshace solo (*La línea … del pedido … tiene reservas por lote. Anúlelas antes de pasar el picking al pedido.*).
2. **BC no acepta la cantidad a enviar o el lote**: el mensaje del preparador trae el error de BC.

**Solución**: corrige la causa y pulsa **Pasar al pedido** en la orden, o **Pasar picking al pedido** en el pedido. Se puede repetir sin miedo: suma lo recogido de todas las órdenes y descuenta lo ya enviado.

---

## "Cambié a mano la cantidad a enviar o los lotes del pedido"

**Qué pasa**: SGA no se entera. Si se envía un lote o una cantidad distinta de lo recogido, BC y las ubicaciones se descuadran. La conciliación lo enseña: el lote recogido sale en *Stock sin ubicar* (ya no está en su hueco, pero BC lo sigue teniendo) y el lote enviado sale en *Sobra en ubicaciones* (BC ya no lo tiene, pero sigue en su hueco).

**Solución**: antes de registrar, vuelve a pulsar **Pasar picking al pedido** para dejar lo recogido. Si ya se registró, recuenta el hueco del lote que sobra y ubica el que falta.

---

## "Registré una compra y no sale en *Ubicar recepciones*"

**Síntoma**: Abres *Ubicar recepciones*, pones la fecha y la recepción no aparece.

**Causas posibles**:
1. **Filtros**: la pantalla busca por la *fecha de registro* del albarán (no por el día en que llegó el camión), por la **Clase de artículo** de la ficha del producto (por defecto *Prod. externo*) y por **Producto** si se ha puesto uno. Deja las fechas y el producto en blanco y pon la clase en *Todas* para verlo todo.
2. **Almacén filtrado**: el albarán es de otro almacén. Vacía el filtro *Almacén*.
3. **Ya está ubicada**: con *Solo lo que falta por ubicar* marcado, lo ya colocado se oculta. Desmárcalo.
4. **Se deshizo la recepción**: si la cantidad neta del albarán es cero, la línea no sale.
5. **No se registró como albarán de compra**: la pantalla lee los movimientos de producto de tipo *Compra* con documento *Albarán compra*. Lo que entre por otra vía (un diario de producto, un ajuste positivo) no aparece. Eso se ubica con *Ubicar producto* > *Ubicar todo lo pendiente*.
6. **Es anterior a la *Fecha inicio SGA***: lo registrado antes de esa fecha no sale nunca. Ya es stock de BC; si no está en ningún hueco, sale en *Pendiente de ubicar*.

**Solución**: revisa 1 a 4. Si es el 5, ubícalo con *Ubicar producto*. Si es el 6, desde *Pendiente de ubicar*.

---

## "Deshice una recepción que ya había ubicado"

**Síntoma**: La línea desaparece de *Ubicar recepciones* (o baja su cantidad), pero la mercancía sigue constando en el hueco.

**Causa**: Deshacer en BC resta la cantidad de la recepción, pero lo que ya estaba colocado no se saca solo de la ubicación. SGA no toca el contenido desde el registro de BC.

**Solución**: entra en *Contenido de ubicaciones*, busca la línea y haz un **Recontar** con la cantidad real. La conciliación lo habría enseñado en *Sobra en ubicaciones*.

---

## "No encuentro *Ubicar ensamblados* en el buscador"

**Causa**: La pantalla sirve para ensamblados y recepciones, y en el buscador (Alt+Q) sale como **Ubicar entradas SGA**. Abierta desde ahí, muestra ensamblados.

**Solución**: busca "Ubicar entradas", o entra por el rol *Almacén SGA*, que tiene una entrada separada para *Ubicar ensamblados* y otra para *Ubicar recepciones*.

---

## "Al ubicar dice que el SSCC ya está en una ubicación"

**Mensaje**: *El SSCC … ya está en la ubicación … con …, lote …. Es un palé que ya entró: revise la etiqueta.*

**Causa**: se ha leído una etiqueta que ya está en el almacén: la de otro palé, o la misma leída dos veces. Una entrada es siempre un palé nuevo.

**Solución**: lee la etiqueta del palé que estás ubicando. Si el palé no tiene etiqueta, deja *SSCC* en blanco y se le da uno nuevo.

---

## "¿Cómo migro desde otra solución SGA?"

SGA no importa ubicaciones de otro sistema. Arranca con la **Carga inicial de contenido**, que reparte el stock que ya tiene BC (ver el [manual de implantación](MANUAL_IMPLANTACION_SGA.md#7-carga-inicial)).

**Pasos**:
1. **Asegúrate de que BC tiene ese stock**, lote a lote.
2. **Crea las ubicaciones** con *Generar ubicaciones* (o *Sincronizar ubicaciones* si ya existen en BC) y ponles tipo y capacidad.
3. Si quieres respetar dónde estaba cada producto, ponle esa ubicación como *Producto fijo* o como *Nº estante* en su ficha, y lanza la carga con *Ubicación fija del producto*. Si no, con *Huecos libres*.
4. **Lanza la carga** primero con *Solo simular*.
5. **Lanza *Conciliar con el stock*** para verificar que BC y las ubicaciones coinciden.

---

## "Necesito un reporte personalizado"

**Usa las listas**: *Contenido de ubicaciones*, *Ubicaciones SGA* y *Movimientos de ubicación* tienen todos los datos. Filtra, pulsa *Abrir en Excel* y personaliza ahí.

---

## Línea de ayuda rápida

| Problema | Acción rápida |
|---|---|
| No encuentro un producto | *¿Dónde está el producto?* sin filtros, o *Pendiente de ubicar* |
| Ocupación incoherente | Ficha ubicación > *Recalcular ocupación* |
| Carga inicial metió todo en un sitio | *Vaciar ubicación* y relanza con *Huecos libres* |
| Diferencia grande en conciliación | *Conciliación con el stock* > vista *Stock sin ubicar* > ubícalo en su sitio |
| Lote desbloqueado que sigue sin usarse | Revisa el bloqueo de la ubicación y de su zona |
| Traslado no funcionó | Lee el mensaje: bloqueo, reserva, producto fijo, mezcla o capacidad del destino |
| Una línea *No se puede ubicar* | Lee el *Motivo*: tipo, espacio, palé del producto o el desglose |
| No se propone una ubicación que existe | Casi siempre no tiene tipo: vista *Sin tipo* y ponlo en su ficha |
| Una recepción no sale para ubicar | Revisa fecha de registro, clase de artículo, almacén y *Solo lo que falta por ubicar* |
| Deshice una recepción ya ubicada | *Contenido de ubicaciones* > *Recontar* |
| No deja enviar a picking | Lanza el pedido y revisa que no tenga otra orden sin terminar |
| El preparador no tiene órdenes asignadas | *Asignar órdenes de picking* > *Asignar a* |
| El responsable no puede asignar | Configuración de usuarios > *Responsable picking SGA* |
| Picking terminado pero el pedido sin lotes | Orden > *Pasar al pedido* |
| Lo regularizado está en ajustes | *Contenido de ubicaciones* > *Trasladar* a su hueco |
| El contenido no cuadra con los movimientos | *Sincronizar ubicaciones* > *Reconstruir contenido desde los movimientos* |
