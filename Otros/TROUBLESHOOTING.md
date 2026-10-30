# Troubleshooting SGA — Casos comunes y cómo resolverlos

---

## "Lancé la carga inicial y todo metió en una sola ubicación"

**Síntoma**: Después de ejecutar *Carga inicial de contenido*, todo el stock aparece en la misma ubicación (normalmente la de ajustes).

**Causa**: Se lanzó con *Ubicación de destino* = "Ubicación indicada" o "Ubicación fija del producto". En esos modos todo el lote va a un único sitio y los productos sin casa van a la indicada (por defecto, la de ajustes).

**Solución**: usa **Huecos libres**, que reparte cada palé a su hueco. Si ya cargaste, reparte lo de la ubicación de paso con *Trasladar*, o vacía el contenido y vuelve a cargar con *Huecos libres* (primero en simulación).

---

## "La carga inicial por huecos libres ha dejado cosas sin cargar"

Al terminar, el mensaje ya resume **cuánto se ha quedado fuera por cada motivo**. El detalle está en la vista **No cargado** del resultado: la columna *Motivo* empieza siempre por la causa y sigue con qué hacer.

| El motivo empieza por… | Qué pasa | Qué hacer |
|---|---|---|
| *No queda espacio en ubicaciones de Palé / Caja / Unidad…* | Hay ubicaciones de esa clase, pero (casi) todas están llenas o sin sitio. Sigue un desglose del resto (bloqueadas, con otro producto…) | Falta espacio: libera ubicaciones o configura más de esa clase (*Admite*) |
| *No hay ninguna ubicación de Palé / Caja / Unidad en el almacén* | No hay ni una ubicación configurada para esa clase | Configura alguna: ficha de la ubicación, *Admite* y *Capacidad* |
| *Las N ubicaciones de … son de muelle, cuarentena…* | Existen, pero no son de *Picking* ni *Reserva* | Cambia su *Tipo ubicación* |
| *Ninguna de las N ubicaciones de … sirve…* | Hay sitio, pero no sirven por otra razón, y dice cuántas por cada una: bloqueadas, reservadas a otro producto (*Producto fijo*), con otro producto, con otro lote | Según el desglose: desbloquear, quitar el producto fijo, permitir mezcla… |
| *La unidad … no es el palé, la caja ni la unidad del producto* | La ficha del producto no tiene bien sus unidades | Revisa *Cód. palé por defecto* y *Unidad de medida de venta* |
| *El producto no tiene palé por defecto en su ficha* | Sin palé no se puede repartir por huecos | Rellena el *Cód. palé por defecto* y relanza con *Omitir productos que ya están ubicados* |
| *El producto no tiene caja* | Su *Unidad de medida de venta* está vacía, es la base o es tan grande como el palé | Corrígela en la ficha del producto |
| *Producto bloqueado* | | Desbloquéalo si tiene que estar en almacén |

Recuerda las reglas de cada clase: los palés van a huecos de *Palé*; las cajas, a *Caja* si son menos de 10 y a *Palé* si son 10 o más; las botellas que no llegan a una caja, a huecos de *Unidad*. Las ubicaciones con *Admite* en blanco no se usan nunca.

Lo que no se carga se ve, lote a lote, en **Pendiente de ubicar**, desde donde se puede ubicar a mano o volver a buscar hueco para varias líneas a la vez (con simulación).

---

## "La ocupación de una ubicación dice 150% y no tiene sentido"

**Síntoma**: `% Ocupacion` > 100 en una ubicación, o el `Estado SGA` dice "Llena" pero quedaría un 20% libre.

**Causa**: La ocupación se calculó con datos obsoletos, o las capacidades cambiaron sin recalcular.

**Solución**:
1. Abre la ficha de la ubicación (`Ubicaciones SGA` > pulsa en la ubicación).
2. Pulsa la acción *Recalcular estado*.
3. Se recalcula en el momento.

**Si aun así sigue mal**: puede haber líneas de contenido con cantidad 0 (fantasma). Entra en el contenido de esa ubicación y mira si hay líneas vacías. Si las hay, traslada manualmente o bórralas.

---

## "¿Dónde está el producto? me devuelve vacío"

**Síntoma**: Buscas un producto que sabes que existe y no aparece nada.

**Causas posibles**:
1. El producto **no está ubicado** (está en BC pero fuera de SGA).
2. El producto **está bloqueado** en todas partes.
3. Estás filtrando por `Lote` incorrecto (si el lote no coincide, no aparece).
4. Estás filtrando por `Almacen` y el producto está en otro.

**Solución**:
1. Abre la página *¿Dónde está el producto?*.
2. Busca el producto (sin filtros adicionales).
3. Si sale algo: está ubicado. Mira si está bloqueado o si tienes el lote correcto.
4. Si **no sale nada**: entra en *Carga inicial* (sin simular), selecciona ese producto, y ejecúta. Lo dejará en su ubicación fija o, si no tiene, en la ubicación indicada (por defecto, la de ajustes).
5. Después lanza *Conciliar* para asegurar que BC y SGA ahora coinciden.

---

## "Conciliar dice que falta stock y me mete 500 cajas en ajustes"

**Síntoma**: Ejecutas *Conciliar con el stock* y de repente aparece una diferencia grande que no esperas.

**Causas posibles**:
1. **Alguien tocó BC sin avisar**: compra recibida, producción cerrada, ajuste en IIEE, etc.
2. **Elemento recién creado**: Item nuevo que no estaba en la carga inicial.
3. **Variante nueva**: producto existente pero con una variante que SGA no conoce.

**Solución**:
1. Abre el resultado de la conciliación (`Conciliación SGA vs stock`).
2. Filtra por `Estado = SinUbicar`.
3. Mira qué producto es. Pregunta: ¿esto acaba de llegar o de crearse?
4. Si es algo que acaba de llegar: **no regularices aún**. Primero mételo manualmente en la ubicación correcta.
   - Abre *Contenido de ubicaciones*.
   - Añade una fila (o usa la acción correspondiente).
   - Mete el producto en la ubicación de recepción.
   - Vuelve a lanzar *Conciliar*.
5. Si regularizas directamente, todo irá a `Ubicacion Ajustes`, que luego tendrás que redirigir manualmente.

---

## "Hay un lote bloqueado y no puedo desbloquearlo"

**Síntoma**: Una línea de contenido está bloqueada, pulsas *Alternar bloqueo* pero sigue bloqueada.

**Causa**: Posiblemente la ubicación completa está bloqueada (no solo la línea).

**Solución**:
1. Abre *Contenido de ubicaciones*, filtra por esa ubicación.
2. Mira si la línea está marcada como `Bloqueado = Yes`.
3. Si es la línea: pulsa *Alternar bloqueo* sobre esa línea (no sobre la ubicación).
4. Si es la ubicación: entra en *Ubicaciones SGA*, busca la ubicación, abre su ficha, y pulsa *Alternar bloqueo*.
5. Limpia el motivo de bloqueo si ya no aplica.

**Si aun así no puedes**: puede haber un bug. Prueba:
1. Abre la ficha de la ubicación.
2. En el campo `Bloqueada`, pon `No` manualmente.
3. Pulsa guardar.
4. Intenta la acción de nuevo.

---

## "Lancé un traslado y la cantidad no cambió en la ubicación destino"

**Síntoma**: Trasladas 50 cajas de A a B, la ubicación A pierde 50, pero la ubicación B no las recibe.

**Causa**: El traslado intentó pero no pudo a causa de una validación (capacidad, bloqueo, mezcla).

**Solución**:
1. Abre la ficha de la ubicación **destino**.
2. Mira el `Motivo Bloqueo` (si está bloqueada).
3. Mira la `Capacidad` vs ocupación actual.
4. Mira la regla de `PermiteMezclaProducto` (¿ya hay otro producto ahí?).
5. Si la ubicación destino tiene un `Producto Fijo` asignado, ¿coincide con el que trasladas?
6. Si todo eso está OK, prueba de nuevo.

Si ves un error específico en pantalla, cópialo y pregunta. Probablemente sea una validación que le pega al traslado.

---

## "El mapa de almacén no muestra todos los huecos de mi pasillo"

**Síntoma**: Abres el mapa y ves celdas en blanco a la derecha, aunque sabes que hay ubicaciones allí.

**Causa**: El mapa dibuja hasta 32 columnas (es un límite de pantalla, no de datos: SGA guarda las que haya). Por defecto viene configurado a 31, que es lo que ocupa un pasillo estándar.

**Solución**:
1. Abre *Configuración SGA* y sube `Columnas mapa` hasta 32.
2. Filtra por **Estantería** para ver ese pasillo de frente: es la vista de alzado y entra entera en pantalla.
3. Si un pasillo tiene más de 32 huecos, el mapa te avisa con el número real. Para verlo completo usa la lista (`Ubicaciones SGA`) o el Excel de `Ocupación de ubicaciones`.

**Nota**: el mapa se reconstruye al abrirlo, así que los cambios de estanterías aparecen solos. Si no ves una ubicación recién creada, cierra y vuelve a abrir.

---

## "Me ha metido más de un palé en la misma ubicación"

**Causa más probable**: la ubicación tiene **Capacidad = 0**, que significa *sin límite*. Con la estrategia estándar, SGA consolida el mismo producto donde ya está, y sin límite le caben todos los palés.

**Solución**:
1. Deshaz lo mal ubicado: *Contenido de ubicaciones*, filtra por esa ubicación, selecciona las líneas y pulsa **Quitar de la ubicación**. Quedan pendientes de ubicar.
2. Pon **Capacidad = 1** en las ubicaciones de palé (ficha o lista de ubicaciones). Al generarlas, rellena *Capacidad uds.* con 1.
3. Vuelve a ubicar con *Ubicar producto* > *Ubicar todo lo pendiente* > *Proponer ubicación*: ahora irá un palé por hueco.

---

## "Ubico palés y cajas y no me propone sitio para las cajas"

**Síntoma**: En *Ubicar producto*, la línea de las cajas sale en la tabla como **No se puede ubicar**.

**Causa**: las cajas van a ubicaciones de **Caja** si son menos de 10, y de **Palé** (de esa misma referencia) si son 10 o más. Los huecos sin configurar (*Admite* en blanco) no se proponen nunca. El motivo de la línea dice cuál de estos casos es:

| El motivo dice | Qué hacer |
|---|---|
| *No hay ninguna ubicación de caja* | Crear una: ficha de una ubicación de tipo *Picking* o *Reserva* → *Admite* = Caja, marcar *Acepta múltiples productos*, *Capacidad* en cajas (por ejemplo 72). |
| *No hay ninguna ubicación de palé* | Con 10 o más cajas se busca un hueco de palé libre: genera más o pon *Admite* = Palé en alguno. |
| *…pero son de muelle, cuarentena, ajustes u otro uso* | Cambiar el *Tipo ubicación* de alguna a *Picking* o *Reserva*. |
| *…pero ninguna tiene sitio* | Liberar una, ampliar su *Capacidad* o configurar más ubicaciones de esa clase. |
| *La unidad … no es ni el palé por defecto, ni la unidad de venta, ni la unidad base* | Ubica en una de esas tres unidades del producto, o revisa su ficha (*Unidad de medida de venta*, *Cód. palé por defecto*). |

Si quieres mover el corte de las 10 cajas: *Configuración SGA* > **Cajas mínimas para hueco de palé**.

Después vuelve a pulsar *Proponer ubicación*: la pantalla conserva lo que falta por ubicar.

---

## "Me propone botellas en una ubicación de palé" o "no me propone una ubicación que existe"

**Causa**: casi siempre, la ubicación tiene **Admite en blanco**. *Sincronizar ubicaciones* da de alta los huecos así; solo *Generar ubicaciones* les pone el tipo. Un hueco en blanco **no se propone nunca**, y desde el 2026-10-30 tampoco acepta botellas sueltas.

**Solución**: abre la ficha de la ubicación (pulsa su código en *Ubicaciones SGA*) y pon *Admite* = Palé, Caja o Unidad. Para muchas a la vez: *Ubicaciones SGA* > **Cambiar ubicaciones en bloque**.

---

## "Me dice que la ubicación admite otra cosa"

**Síntoma**: Al confirmar sale *"La ubicación A-01-15-3 admite Palé y no se puede dejar mercancía en BOTELLA en ella…"*.

**Causa**: lo que se deja no es de la clase que admite el hueco:
- Un hueco de **Palé** acepta palés y cajas de una referencia, pero no botellas sueltas.
- Un hueco de **Caja** acepta solo cajas.
- Un hueco de **Unidad** acepta solo botellas sueltas.

**Solución**, según lo que quieras:
1. **Llevarlo al hueco que toca**: vuelve a pedir propuesta.
2. **Si el hueco debería admitir eso**: abre su ficha y cambia *Admite*. Ajusta la *Capacidad* a esa clase (palés, cajas o unidades).
3. **Si lo que está mal es la unidad tecleada**: corrige el campo *Unidad de medida* de la pantalla.

**Si la unidad sí es la que corresponde y aun así sale el mensaje**: revisa la ficha del producto. La caja es su *Unidad de medida de venta* y el palé su *Cód. palé por defecto*.

---

## "No me deja marcar 'Acepta múltiples productos' en una ubicación"

**Síntoma**: Marcas la casilla y salta *"Solo las ubicaciones de caja o de unidades sueltas pueden aceptar varios productos"*.

**Causa**: Solo los huecos de **Caja** y de **Unidad** se comparten entre productos. Un hueco de palé es de una referencia, también cuando guarda un palé incompleto en cajas.

**Solución**: comprueba que esa ubicación tiene *Admite* = Caja o Unidad.

---

## "El mapa 3D sale en blanco"

**Síntoma**: Abres *Mapa 3D de almacén* y el panel aparece vacío o no aparece nada.

**Causas por orden de probabilidad**:
1. **No hay almacén seleccionado**: el campo *Almacén* está vacío. Se rellena con el almacén por defecto de la configuración; si no hay ninguno configurado, elígelo a mano.
2. **Las ubicaciones no siguen el formato de código**: el mapa deduce la posición de cada bloque del código `nave-estantería-columna-altura` (`A-01-15-3`). Las ubicaciones con otro formato no se pueden colocar y no se dibujan. Compruébalo en la lista de ubicaciones.
3. **La estantería o la altura no son numéricas**: si el código trae letras donde debería ir el número de estantería o de altura, ese bloque se salta.
4. **Filtro demasiado estrecho**: tienes puesta una nave o una estantería que no existe. Vacía los filtros.

---

## "Recuento manual: conté 80 pero el sistema dice que hay 100"

**Síntoma**: Abres *Recontar* en una línea de contenido, metes 80, y ves que la diferencia es -20.

**¿Es un error?** No necesariamente:
- Si la diferencia es negativa (falta), **alguien cogió 20 cajas que SGA no registró**.
- Si la diferencia es positiva (sobra), **hay 20 de más de las que se conoce**.

**Soluciones**:
1. **Si falta** (negativo): Alguien hizo picking manual o traslado sin avisar.
   - Mete el recuento (80).
   - SGA crea un movimiento de ajuste por los -20.
   - Pregunta quién las cogió.

2. **Si sobra** (positivo): Hay un error en la entrada.
   - Mete el recuento (80).
   - SGA registra un ajuste +20.
   - Investiga: ¿se metieron 20 de más? ¿llegaron con error de BC?

Luego, lanza *Conciliar* para que regularice de acuerdo.

---

## "Dos usuarios están editando el mapa simultáneamente"

**Síntoma**: Usuario A abre el mapa, lo edita. Usuario B abre el mapa al mismo tiempo. Cuando B guarda, sobrescribe los cambios de A (o falla).

**Realidad**: El mapa es de **solo lectura**. No se puede editar desde ahí. Si ves un error de "locked record", es posible que:
1. El buffer se está rellenando.
2. Otra persona tiene un informe corriendo.

**Solución**:
1. Espera un momento.
2. Recarga la página (F5 o botón atrás).
3. Intenta de nuevo.

Si el error persiste: hay un bloqueo de base de datos. En ese caso, el administrador tendrá que revisar SQL (probablemente un informe que tardó más de lo esperado).

---

## "No me deja cambiar la configuración de una ubicación"

**Síntoma**: En la ficha, *Admite*, capacidad, zona y el resto salen en gris; o al cambiar en bloque dice que *N no se han cambiado porque tienen contenido*.

**Causa**: la configuración de una ubicación solo se cambia **vacía**. Si no, lo que ya hay dentro podría dejar de cumplirla (un palé en un hueco que pasa a ser de cajas, dos referencias en uno que deja de aceptar mezcla…).

**Solución**: traslada su contenido a otra ubicación o vacíala, y vuelve a cambiarla. Si lo que quieres es que no se use mientras tanto, **bloquéala**: eso sí se puede con mercancía dentro.

---

## "Quiero bajar la capacidad de una ubicación que está llena"

**Causa**: la capacidad es configuración, y solo se cambia con la ubicación vacía (ver el apartado anterior). Así no puede quedar una ubicación con más dentro de lo que dice su capacidad.

**Solución**: traslada lo que sobre a otra ubicación, vacíala, cambia la capacidad y vuelve a dejar lo que quepa.

---

## "La conciliación regularizó mal y ahora hay diferencias que no existían"

**Síntoma**: Después de regularizar una diferencia, la siguiente conciliación muestra nuevas diferencias.

**Causa**: Posiblemente el movimiento de ajuste se registró en la ubicación equivocada.

**Solución**:
1. Abre *Movimientos de ubicación*.
2. Filtra por los últimos movimientos (debe haber un "Ajuste" de hace poco).
3. Verifica que la ubicación origen/destino son correctas.
4. Si está mal: **no hay marcha atrás fácil**. El diario es inmutable. Tienes que registrar un **movimiento de traslado inverso** (desde la ubicación equivocada a la correcta).

**Mejor prevención**: No regularices directamente sin revisión. En *Conciliación SGA*, mira bien dónde va cada cosa antes de pulsar *Regularizar*.

---

## "¿Por qué SGA y BC difieren en un lote que no debería existir?"

**Síntoma**: Conciliar reporta un lote con diferencia, pero ese lote está vencido hace meses.

**Causa**: El Item Ledger Entry en BC tiene un lote/caducidad que SGA no vio en la carga inicial (posiblemente porque estaba en un almacén diferente o llegó después de la carga).

**Solución**:
1. Abre *Item Ledger Entry* en BC (módulo Inventario).
2. Filtra por ese producto y ese lote.
3. ¿Cuál es el `Remaining Quantity`?
4. Si es > 0: ese stock existe y hay que ubicarlo. Lanza *Carga inicial* solo para ese producto.
5. Si es <= 0: fue consumido y no debería estar. Pregunta a administrador por qué el IIEE no se cerró.

---

## "Regularizar no funcionó"

**Síntoma**: Ejecutas *Regularizar* en *Conciliación SGA vs stock*, pero cuando vuelves a conciliar aparece la misma diferencia.

**Causas posibles**:
1. **No hizo commit**: regularizaste pero no guardaste. Pulsa Guardar después.
2. **Ubicación destino no existe**: el ajuste intentó meterse en la ubicación de ajustes, pero esa no está configurada.
3. **Diferencia es negativa**: regularizar solo funciona para faltas (Stock BC > Stock SGA). Para excesos, requiere recuento.

**Solución**:
1. Abre *Configuración SGA*.
2. Verifica que `Ubicacion Ajustes` está asignada y existe.
3. Si no existe: crea esa ubicación primero, asígnaIa en config, y vuelve a intentar.
4. Asegúrate de guardar después de regularizar.

---

## "Alguien buscó en la base de datos y metió datos directamente"

**Síntoma**: Contenido SGA cambió de forma que SGA no puede explicar. Ocupación descuadra, movimientos no coinciden.

**Causa**: Alguien corrió una query SQL directa, burlando `Cod51100`.

**Recuperación**:
1. **Mejor opción**: Abre *Sincronizar ubicaciones* > marca *Reconstruir contenido* > ejecuta.
   - Esto **borra todo** el contenido y lo regenera desde el diario.
   - Toma tiempo (lee todos los movimientos), pero garantiza consistencia.
2. **Después**: Lanza *Conciliar* para comprobar que todo cuadra.

**Prevención**: Quita permisos directos a la BD a quien no los necesite. SGA debe ser el único que toque esas tablas.

---

## "¿Por qué tardó tanto la conciliación?"

**Síntoma**: *Conciliar con el stock* tarda > 1 minuto incluso con pocos movimientos.

**Causas posibles**:
1. **Muchos Items/Lotes**: si tienes 10.000+ combinaciones de producto+variante+lote, es lógico.
2. **Índices débiles**: la query de Item Ledger Entry o Contenido SGA está haciendo table scan.
3. **Base de datos lenta**: I/O saturado.

**Solución**:
1. Filtra por `Almacen` específico en la conciliación (no hagas "todo a la vez").
2. Si es recurrente: pídele al administrador que verifique índices en las tablas grandes.
3. Si es la primera conciliación y es lenta porque hay millones de IIEE: es normal. Espera.

---

## "El preparador pulsa *Siguiente orden* y le dice que no tiene órdenes asignadas"

**Causa**: está activada *Exigir asignación de picking* y el responsable aún no le ha asignado nada. Las órdenes recién enviadas esperan en *Pendiente de asignar*.

**Solución**: el responsable abre *Asignar órdenes de picking*, vista *Sin asignar*, y las reparte con *Asignar a*. Si no queréis este paso, desactiva la casilla en *Configuración SGA* > *Controles*: las órdenes que estaban esperando pasan a cogerse con *Siguiente orden*.

---

## "Me dice que la orden está asignada a otro y solo la puede preparar el asignado"

**Causa**: con *Exigir asignación*, cada orden es de su preparador, y nadie más puede abrirla ni confirmar paradas.

**Solución**: si hay que cambiar de preparador (por ejemplo, porque el asignado se ha ido), el responsable la reasigna en *Asignar órdenes de picking*. Una orden empezada se puede reasignar, pero no dejar sin nadie.

---

## "Soy responsable y no me deja asignar órdenes"

**Síntoma**: Sale *"Solo un responsable de picking puede asignar órdenes o cambiar su prioridad"* al abrir *Asignar órdenes de picking*, al cambiar el preparador o al tocar la prioridad.

**Causa**: con *Exigir asignación de picking* activo, solo pueden repartir los usuarios marcados como responsables. Tener el conjunto de permisos *SGA - Responsable de almacén* no basta.

**Solución**: en *Configuración de usuarios*, crea la línea del usuario si no existe y marca **Responsable picking SGA**.

---

## "No puedo quitar la asignación de una orden"

**Causa**: la orden ya tiene recogidas (*En proceso*) y se exige asignación. Si se dejara sin nadie, quedaría a medias sin que ningún preparador la viera.

**Solución**: reasígnala a otro preparador.

---

## "Operario dice que no puede hacer picking desde SGA"

**Síntoma**: El operario abre la página de picking y dice que no ve las paradas correctas o que la ubicación no es la esperada.

**Causas comunes**:

1. **No hay orden de picking creada**: El pedido de venta está ahí pero **no se ha enviado** a picking. El operario no ve nada porque no hay paradas.
   - **Solución**: Lanza el pedido y pulsa *Almacén SGA > Enviar a picking*.

2. **Hay stock en BC pero no está ubicado**: El sistema genera la orden pero sin paradas: significa que no hay contenido ubicado del producto.
   - **Solución**: Lanza *Ubicar producto* para las cantidades que tienes, o *Carga inicial* si es la primera vez.

3. **No hay capacidad en las ubicaciones propuestas**: SGA propone un hueco pero descarta otros por capacidad llena.
   - **Solución**: Bloquea los llenos y relanza el picking, o revisa la estrategia de picking.

4. **El producto está bloqueado en todas las ubicaciones**: Marcaste "No hay stock aquí" porque no encontrabas el producto, y eso canceló la parada.
   - **Solución**: Abre *Órdenes de picking*, ve la ficha de la orden, y verás qué paradas están canceladas.

5. **Hay stock ubicado pero está reservado**: otro pedido ya lo tiene en una orden abierta. En *Contenido de ubicaciones* se ve en *Cantidad reservada*.
   - **Solución**: espera a que se prepare la otra orden, o cancélala si ya no hace falta: al cancelar se libera la reserva.

**PDA**: Por ahora SGA es escritorio. La Fase 3 añadirá una página de PDA con soporte de escáner.

---

## "No me deja enviar el pedido a picking"

**Mensajes y qué hacer**:
- *"El pedido debe estar lanzado"*: lánzalo. Mientras se prepara, el pedido no debe cambiar.
- *"Ya tiene abierta la orden de picking X"*: solo puede haber una orden viva por pedido. Termínala o cancélala desde *Órdenes de picking*.
- *"No tiene nada pendiente de preparar"*: todo lo que queda por servir ya está recogido en órdenes anteriores. Falta pasarlo al pedido y registrar el envío.

---

## "La orden se terminó pero el pedido no tiene la cantidad a enviar ni los lotes"

**Síntoma**: Al terminar, el preparador vio *"Orden terminada, pero no se ha podido pasar al pedido"*. O la orden sale en la vista *Terminadas sin pasar al pedido*.

**Causas posibles**:
1. **La línea tiene reservas por lote**: alguien reservó un lote concreto en el pedido. SGA no las deshace solo.
2. **El almacén exige envío de almacén** (*Require Shipment*): BC no deja poner a mano la cantidad a enviar en esos almacenes.
3. **Redondeo de la unidad de medida**: lo recogido en unidades no da un número válido de cajas según la precisión de redondeo del producto.
4. **Permisos**: el usuario no puede modificar líneas de venta o movimientos de reserva.

**Solución**: corrige la causa y pulsa *Pasar al pedido* en la orden, o *Pasar picking al pedido* en el pedido. Se puede repetir sin miedo: suma lo recogido de todas las órdenes y descuenta lo ya enviado.

---

## "Cambié a mano la cantidad a enviar o los lotes del pedido"

**Qué pasa**: SGA no se entera. Si se envía un lote o una cantidad distinta de lo recogido, BC y las ubicaciones se descuadran. La conciliación lo enseñará (*SobraEnSGA* en el lote recogido, *SinUbicar* o negativo en el otro).

**Solución**: antes de registrar, vuelve a *Pasar picking al pedido* para dejar lo recogido. Si ya se registró, corrige las ubicaciones con un recuento.

---

## "El preparador ve las cantidades en unidades y no en cajas"

**Causa**: la orden se creó antes de este cambio, cuando las paradas no guardaban la unidad del pedido. En ese caso enseña la unidad base.

**Solución**: cancela la orden y vuelve a enviar el pedido a picking.

---

## "Registré una compra y no sale en *Ubicar recepciones*"

**Síntoma**: Abres *Ubicar recepciones*, pones la fecha y la recepción no aparece.

**Causas posibles**:
1. **Filtros**: la pantalla busca por la *fecha de registro* del albarán (no por el día en que llegó el camión) y por la **Clase de artículo** de la ficha del producto (por defecto *Prod. externo*), y por **Producto** si se ha puesto uno. Deja las fechas y el producto en blanco y pon la clase en *Todas* para verlo todo. Sin fecha *desde*, solo salen las recepciones que aún tienen stock.
2. **Almacén filtrado**: el albarán es de otro almacén. Vacía el filtro *Almacén*.
3. **Ya está ubicada**: con *Solo lo que falta por ubicar* marcado, lo ya colocado se oculta. Desmárcalo.
4. **Se deshizo la recepción**: si la cantidad neta del albarán es cero, la línea no sale.
5. **No se registró como albarán de compra**: la pantalla lee los movimientos de producto de tipo *Compra* con documento *Albarán compra*. Lo que entre por otra vía (un diario de producto, un ajuste positivo) no aparece. Eso se ubica con *Ubicar producto* > *Ubicar todo lo pendiente*.

**Solución**: revisa 1 a 4. Si es el 5, ubícalo con *Ubicar producto*.

---

## "Deshice una recepción que ya había ubicado"

**Síntoma**: La línea desaparece de *Ubicar recepciones* (o baja su cantidad), pero la mercancía sigue constando en el hueco.

**Causa**: Deshacer en BC resta la cantidad de la recepción, pero lo que ya estaba colocado no se saca solo de la ubicación. SGA no toca el contenido desde el registro de BC.

**Solución**: entra en *Contenido de ubicaciones*, busca la línea y haz un *Recontar* con la cantidad real. La conciliación lo habría enseñado como *SobraEnSGA*.

---

## "No encuentro *Ubicar ensamblados* en el buscador"

**Causa**: La pantalla ahora sirve para ensamblados y recepciones, y en el buscador (Alt+Q) sale como **Ubicar entradas**. Abierta desde ahí, muestra ensamblados.

**Solución**: busca "Ubicar entradas", o entra por el rol *Almacén SGA*, que tiene una entrada separada para *Ubicar ensamblados* y otra para *Ubicar recepciones*.

---

## "¿Cómo migro desde otra solución SGA?"

**Escenario**: Tenías otro sistema y quieres cambiar a SGA.

**Pasos**:
1. **Exporta el contenido del viejo sistema**: producto, ubicación, lote, cantidad.
2. **Asegúrate de que BC tiene ese stock** (debe coincidir el total).
3. **Sincroniza ubicaciones** en SGA.
4. **Lanza *Carga inicial*** con los datos del viejo sistema (o mejor, importa manualmente vía una página de "Carga manual" que tendrás que crear).
5. **Lanza *Conciliar*** para verificar que BC y SGA coinciden.

La Fase 1 no tiene herramientas de importación masiva, así que tendrás que:
- O crear una página de importación específica.
- O hacerlo línea por línea.
- O pedirme que extienda `Cod51100.RegistrarCargaInicial` con un parámetro de "importa desde tabla temporal".

---

## "Necesito un reporte personalizado (no está en los 6 que hay)"

**Opciones**:
1. **Usa los que hay**: *Inventario por ubicación* y *Ocupación de ubicaciones* son bastante completos. Descarga a Excel y personaliza ahí.
2. **Crea un reporte propio**: Basándote en `Contenido SGA` y `Ubicacion SGA`. Puedo ayudarte si necesitas una query específica.
3. **Pide funcionalidad**: Si es algo que repetirás cada semana, mejor integrado. Avisa qué necesitas.

---

## Línea de ayuda rápida

| Problema | Acción rápida |
|---|---|
| No encuentro un producto | *¿Dónde está el producto?* o *Conciliar* |
| Ocupación incoherente | Ficha ubicación > *Recalcular estado* |
| Carga inicial metió todo en un sitio | Revisa `Shelf No.` de productos |
| Diferencia grande en conciliación | Busca en *Conciliación SGA* > investiga |
| Ubicación bloqueada, no puedo desbloquearla | Ficha > campo `Bloqueada` > pon No |
| Traslado no funcionó | Revisa capacidad y reglas de destino |
| Una recepción no sale para ubicar | Revisa fecha de registro, almacén y *Solo lo que falta* |
| Deshice una recepción ya ubicada | *Contenido de ubicaciones* > *Recontar* |
| No deja enviar a picking | Lanza el pedido y revisa que no tenga otra orden abierta |
| El preparador no tiene órdenes asignadas | *Asignar órdenes de picking* > *Asignar a* |
| El responsable no puede asignar | Configuración de usuarios > *Responsable picking SGA* |
| Un hueco rechaza lo que intento dejar | Ver "Me dice que la ubicación admite otra cosa": palé acepta palés y cajas; caja, solo cajas; unidad, solo botellas |
| No se propone una ubicación que existe | Tiene *Admite* en blanco: configúralo en su ficha |
| Picking terminado pero el pedido sin lotes | Orden > *Pasar al pedido* |
| Todo se rompió y no sé qué pasó | *Sincronizar* > *Reconstruir contenido* |

