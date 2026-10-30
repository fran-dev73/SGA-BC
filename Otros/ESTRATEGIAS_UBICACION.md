# Ubicación: decisiones y reflexión

Documento de decisión: recoge cómo decide SGA dónde
va la mercancía, qué alternativas se valoraron y qué haría replantearlo. Sirve para volver a él
cuando cambie el almacén, no como manual de uso (eso está en [MANUAL_SGA.md](MANUAL_SGA.md)); el
detalle técnico está en [ARQUITECTURA.md](ARQUITECTURA.md).

SGA decide la ubicación en **dos pasos**, y este documento trata los dos:

1. **Qué clase de hueco le toca**: palé, caja o unidad, según qué es y cuánto es
   (ver [Parte 1](#parte-1-qué-clase-de-hueco-le-toca)).
2. **Cuál de esos huecos**: la estrategia, que dice en qué orden se prueban
   (ver [Parte 2](#parte-2-estrategia-cuál-de-esos-huecos)).

---

## Parte 1: qué clase de hueco le toca

### Las tres clases de mercancía

Cada producto se maneja en tres unidades, todas de su ficha. No hace falta configurar nada: SGA
las reconoce solo.

| Clase | Qué unidad es | Ejemplo |
|---|---|---|
| **Palé** | *Cód. palé por defecto* (y cualquier unidad igual de grande o mayor) | PALE: 540 botellas |
| **Caja** | *Unidad de medida de venta*: la unidad mínima en que se vende | CAJA12 |
| **Unidad** | *Unidad de medida base*: lo que no llega a una caja | BOTELLA |

Otras unidades intermedias del producto (una CAJA6 en un producto que se vende en CAJA12) no tienen
clase y no entran en el reparto.

**Por qué así:** la ficha del producto ya está dada de alta y es lo que usa el resto de BC, así que
no hace falta ninguna configuración más. Una sola fuente es más fácil de entender y de mantener.

### El reparto de una cantidad

Una cantidad se reparte de mayor a menor con esas tres unidades: **cada palé completo por
separado**, luego **las cajas que sobren, juntas**, y al final **las unidades que no llegan a una
caja**. 690 botellas con palé de 540 y CAJA12 son *1 PALE, 12 CAJA12, 6 BOTELLA*.

En *Ubicar producto* el resultado sale en una tabla, una línea por parte, con su hueco o, si no lo
hay, marcada como *No se puede ubicar* y el motivo.

Es el mismo reparto en todas partes: *Ubicar producto*, *Equivale a* y el desglose de *Pendiente de
ubicar*, la carga inicial por *Huecos libres*, *Ubicar seleccionadas* y el palé de una tarea en
*Imprimir y ubicar palés*. En este último el palé es el de la tarea y no el de la ficha, y la caja
es la unidad de venta si es más pequeña que ese palé. Lo que cambia entre ellos es qué se hace con
cada parte:

- *Equivale a* y el desglose de *Pendiente de ubicar* solo muestran el reparto; no buscan hueco.
- *Ubicar producto*, *Huecos libres* y *Ubicar seleccionadas* buscan un hueco para cada parte.
- En la carga inicial, un producto sin caja no ubica las sueltas: quedan como no cargadas.
- *Imprimir y ubicar palés* ubica solo el palé de la tarea; las sueltas que sobran de las cajas
  quedan pendientes, con aviso.

### Qué admite cada hueco

Cada ubicación dice qué admite (campo *Admite* de su ficha). Hay **dos reglas distintas**, a
propósito:

| Admite | Qué se le **propone** | Qué **acepta** si el operario lo elige | Varios productos |
|---|---|---|---|
| **Palé** | Palés, y cajas de una referencia **a partir de 10** | Palés y cajas | No |
| **Caja** | Cajas sueltas, **menos de 10** | Solo cajas | Sí |
| **Unidad** | Unidades sueltas | Solo unidades sueltas | Sí |
| *(en blanco)* | **Nada** | Palés y cajas, nunca unidades | No |

- **La propuesta es estricta**: a cada parte se le propone una sola clase de hueco. Así los
  huecos de caja quedan para lo que de verdad son cajas sueltas de muchas referencias, y no se
  llenan con medio palé.
- **La validación es más amplia**: si el operario deja algo en otro hueco que también sirve, se
  admite. La propuesta orienta; no bloquea el trabajo.

**Por qué cada regla:**

- **Las unidades sueltas solo van a huecos de Unidad.** Una botella suelta en un hueco de palé
  inutiliza el hueco y luego nadie la encuentra. Por eso tampoco entran en huecos sin configurar.
- **Las cajas de una referencia pueden ir a palé.** Un palé incompleto (el último de una tirada,
  un resto de picking) sigue siendo un palé físico de un solo producto y ocupa un hueco de palé.
  Como los huecos de palé no aceptan mezcla, nunca se juntan dos referencias.
- **El corte de 10 cajas.** Por debajo, son cajas sueltas que se recogen a mano: van a huecos de
  caja, compartidos entre referencias. A partir de 10, ya es un palé incompleto que se mueve con
  carretilla y va a un hueco de palé. El número se cambia en *Configuración SGA* > **Cajas mínimas
  para hueco de palé**.
- **Un hueco sin configurar no se propone nunca.** Un hueco solo entra en las propuestas cuando
  alguien ha dicho qué es; si no, se podrían proponer botellas sueltas en un hueco que en realidad es
  de palé. *Sincronizar ubicaciones* da de alta los huecos sin configurar, así que hay que ponerles
  *Admite*. Tampoco los usa la carga inicial.

### Las etiquetas de la línea: palé completo o incompleto

En *Imprimir y ubicar palés* cada etiqueta es un palé, y hay que saber si va completo para ubicarlo
como palé o como cajas. **Lo dice la tarea**, que es de donde sale la etiqueta: la tarea planifica
cuántas botellas se embotellan y cuánto lleva un palé. Si después de las etiquetas ya impresas aún
queda al menos un palé por hacer, el que sale es **completo**; si no, es el **último**, con lo que
quede.

- **Completo**: se ubica como palé, en un hueco de palé.
- **Incompleto**: se ubica en cajas, con la regla de las 10 cajas. Si sobran botellas que no llegan
  a una caja, la pantalla avisa y quedan para *Ubicar producto*.
- Nunca se ubica más de lo que falta del ensamblado enlazado.

**Por qué así:** no hay forma de saber en la pantalla cuánto lleva físicamente cada palé, y pedirlo
al operario por etiqueta sería lento. La tarea ya tiene el plan de producción, así que el único
palé dudoso es el último. **Límite conocido:** las botellas planificadas salen de los litros y del
volumen del producto; si esos datos de la tarea no cuadran, el último palé saldrá mal calculado.

*Ubicar ensamblados* ubica en la unidad del ensamblado. Lo ya ubicado de un ensamblado se cuenta en
unidades base, sumando todas las unidades, porque las etiquetas lo pueden haber ubicado en palés y
cajas; así *Ubicar ensamblados* no vuelve a pedir los palés ubicados con las etiquetas.

### Cuándo replantear las clases

| Si pasa esto | Valorar |
|---|---|
| Los huecos de caja se llenan con restos grandes, o los de palé con pocas cajas | Mover el corte de **Cajas mínimas para hueco de palé** |
| Se pasa a huecos de **varios palés** | Contar la capacidad en palés y permitir consolidar (ver Parte 2) |
| Hay muchas botellas sueltas de producción | Revisar los datos de la tarea (litros, volumen, palé por defecto) |
| Un producto se vende en una unidad intermedia que debería ser la caja | Cambiar su *Unidad de medida de venta* en la ficha del producto |

### La configuración de las ubicaciones

- La configuración de una ubicación (*Admite*, capacidad, mezclas, zona, tipo, secuencia, producto
  fijo, reposición) solo se cambia con la ubicación **vacía**, en la ficha y en bloque: así lo que
  hay dentro siempre la cumple. Bloquearla sí se puede siempre: un hueco roto o con una incidencia se
  bloquea con la mercancía dentro.
- Al poner *Admite* = Caja o Unidad se marcan *Acepta múltiples productos* y *Acepta múltiples
  lotes*; con Palé, un solo producto.

### Cuando no se puede ubicar

El motivo dice la causa concreta, siempre en la primera frase: no hay ubicaciones de esa clase,
no queda espacio en ellas, o las hay pero no sirven (con cuántas por cada motivo: bloqueadas,
reservadas a otro producto, con otro producto, con otro lote). La carga inicial resume lo no
cargado por causa, y lo que queda sin ubicar se ve y se ubica desde *Pendiente de ubicar*.

---

## Parte 2: estrategia (cuál de esos huecos)

Una vez se sabe la clase de hueco, la estrategia decide en qué orden se prueban los huecos de esa
clase.

### Decisión

Se mantiene **"Primer hueco vacío"** (*Solo hueco vacío* en la configuración) como estrategia de
ubicación para las entradas de producción (palés de la línea y ensamblados).

> Cada palé va al **primer hueco vacío** de tipo *Picking* o *Reserva*, no bloqueado, siguiendo la
> **Secuencia picking** (pasillo, hueco y nivel). *Otra ubicación* salta al siguiente.

**Por qué:**

- Los huecos son de **un solo palé** y lo que entra de producción son **palés completos**. Los
  estudios coinciden en que, moviendo palés completos, las diferencias entre estrategias son
  pequeñas (ver *Qué dicen los estudios*, punto 5).
- Con el almacén lleno, cualquier estrategia acaba en el hueco libre más cercano (punto 1): lo que
  añaden las demás solo se nota con mucho hueco libre donde elegir.
- **No necesita datos ni mantenimiento**: ni huecos de picking por producto, ni zonas por familia,
  ni clasificación ABC que recalcular. Funciona con lo que ya se da de alta al generar ubicaciones.
- Es **predecible** para el operario: sabe hacia dónde le va a mandar el sistema.
- Basta con que la **Secuencia picking** refleje bien el recorrido físico, empezando por los huecos
  mejores (abajo y cerca de la salida). Así el primer hueco vacío ya es el mejor disponible.

**Estado:** implementada. Es el valor por defecto de `Estrategia Ubic. Ensamblados` en
Configuración SGA y la que usan *Ubicar ensamblados* y *Imprimir y ubicar palés*. No hay que tocar
código.

**Coste aceptado:** los palés de una misma tirada no quedan necesariamente juntos. Si los huecos
del principio de la ruta se van liberando a saltos, una tirada puede repartirse entre pasillos. Es
lo primero que mejoraría *Junto al mismo producto* si llega a hacer falta.

### Estrategias que existen hoy

Están en `ProponerUbicacionCon` de [GestionUbicacionesSGA.Codeunit.al](../Codeunits/GestionUbicacionesSGA.Codeunit.al),
que es la única puerta para proponer: cuando no encuentra hueco, devuelve también el motivo
(`ExplicarSinHuecoLote`, con el lote de la mercancía).
Todas recorren los huecos de tipo *Picking* o *Reserva* (`Ubicacion SGA.FiltrarDeAlmacenaje`), no
bloqueados, por **Secuencia picking**.

| Estrategia | Qué hace | Con huecos de un palé |
|---|---|---|
| Estándar | Ubicación fija → consolidar → primer hueco con sitio | Equivale a ubicación fija + primer hueco |
| Priorizar consolidación | Consolidar → primer hueco con sitio | Consolidar no aplica |
| Solo ubicación fija | Solo la ubicación fija del producto | Demasiado rígida para producción |
| Primera libre por ruta | Primer hueco con sitio | Igual que *Solo hueco vacío* |
| Solo hueco vacío | Primer hueco vacío | **Elegida** |

### Alternativas valoradas

| Estrategia | Qué hace | Por qué no ahora |
|---|---|---|
| **Primer hueco vacío** | Primer hueco vacío por ruta | **Elegida** |
| Junto al mismo producto | Hueco vacío más cercano a donde ya está el producto (mismo lote primero); si no está en ningún sitio, primer hueco vacío | Mejora sobre todo el orden (tiradas juntas), no los recorridos. Sin datos nuevos: la posición sale del código de ubicación (Nave-Estantería-Columna-Altura). Es la primera candidata si hace falta cambiar |
| Reponer picking | Si el hueco de picking del producto está bajo mínimo, el palé va ahí; si no, a reserva | Requiere dar de alta huecos de picking por producto con *Ctdad. mínima/máxima*. Rinde si hay mucha venta en cajas sueltas |
| Por zona | Cada familia de producto (clase, tipo de alcohol) va a sus zonas | Requiere una tabla familia → zona. Útil si hay que segregar (normativa, inflamables) o separar propios/externos |
| Por rotación (ABC) | Lo que más se vende va abajo y cerca de la salida | Requiere clasificar productos y huecos y recalcularlo periódicamente. Solo compensa con ventas muy concentradas y recorridos largos |

Descartadas para este almacén:

- **Consolidar** y **ubicación fija** como estrategia principal: no encajan con huecos de un palé.
- **Cross-docking** (palé directo a muelle si hay un pedido esperándolo): a valorar cuando el
  picking esté rodado.
- **Repartir entre pasillos**: solo compensa con varias carretillas ubicando a la vez.
- **Peso y volumen**: no es una estrategia sino un filtro que deberían aplicar todas. Los campos
  *Capacidad peso* y *Capacidad volumen* ya existen en la ubicación, pero no se usan.

### Qué dicen los estudios

No se ha encontrado ningún estudio que relacione directamente el **número de palés** del almacén
con la estrategia a usar. El tamaño influye a través de otros factores:

1. **Con el almacén muy lleno, la estrategia importa poco.** Si queda poco hueco libre, no hay dónde
   elegir y cualquier estrategia acaba en el hueco libre más cercano.
   ([resumen de Hausman et al. y trabajos posteriores](https://repub.eur.nl/pub/86663/REPUB_86663.pdf))
2. **Reservar huecos fijos por producto ocupa más espacio** que la ubicación libre: hay que
   dimensionar para el máximo de cada producto, no para el máximo del total.
   ([Racklify](https://racklify.com/encyclopedia/putaway-strategy-%E2%80%94-design-and-optimization-for-high%E2%80%91density-warehouses/))
3. **ABC ahorra más cuanto más concentradas están las ventas.** Con 2 clases se obtiene en torno al
   75 % de la mejora posible y con 3 en torno al 90 %; en algún caso hasta un 40 % menos de
   recorrido frente a ubicar al azar. Dato de un almacén semiautomático, no de palés con carretilla.
   ([Amazon Science](https://cdn.amazon.science/d9/2c/9a434b16416684fbbd3446aa1bc1/velocity-based-storage-assignment-in-semi-automated-storage-systems.pdf))
4. **Con pocos productos, más clases no es mejor**: cada clase necesita su espacio y pasadas 2 o 3
   los recorridos vuelven a crecer.
   ([Yu y De Koster](https://www.researchgate.net/publication/269776808_Class-Based_Storage_with_a_Finite_Number_of_Items_Using_More_Classes_is_not_Always_Better))
5. **Si se mueven palés completos, las diferencias entre estrategias son pequeñas.** Donde se gana
   de verdad es en el picking de cajas sueltas.
   ([modelo de colas](https://arxiv.org/pdf/2503.04448), [revisión de la literatura](https://www.scitepress.org/Papers/2019/79524/79524.pdf))
6. **El picking es en torno al 55 % del coste de un almacén**, y cerca de la mitad de ese tiempo es
   andar.
   ([De Koster et al., citado aquí](https://www.researchgate.net/publication/398081633_Optimization_of_Warehouse_Performance_through_Class-Based_Storage_based_FSN_Analysis_for_Travel_Efficiency_and_Cost_Reduction))
7. **La regla del 80/20** (el 20 % de productos hace el 80 % de las salidas) es una referencia de
   proveedores, no un dato: hay que comprobarla con las ventas propias.
   ([Mecalux](https://www.mecalux.com/blog/sku-velocity-slotting), [Kardex](https://www.kardex.com/en-us/blog/sku-management-best-practices))

### Cuándo replantear la decisión

| Si pasa esto | Valorar |
|---|---|
| Las tiradas quedan **repartidas por el almacén** y cuesta encontrar un lote o recontarlo | **Junto al mismo producto** |
| Crece la venta en **cajas sueltas** y la reposición de picking da trabajo | **Reponer picking** delante de *Primer hueco vacío* |
| Pocos productos concentran la mayoría de salidas (p. ej. 20 % de productos ≥ 70-80 % de palés) **y** los recorridos son largos (varias naves o pasillos largos) | **ABC con 2 clases**, no más |
| Hay que separar mercancía por **normativa** o por propios/externos | **Por zona** |
| La **ocupación media** pasa del 85-90 % | Ninguna estrategia nueva rinde: el problema es de espacio. Refuerza la decisión actual |
| Se pasa a **huecos de varios palés** | Recuperar **consolidar** |
| Varias carretillas ubicando a la vez se estorban | Repartir entre pasillos |

Si se combinan varias, la idea es pasar a **plantillas de ubicación**: una lista de pasos que se
prueban en orden ("junto al mismo lote", "reponer picking", "hueco vacío en su zona", "primer hueco
vacío"), asignable por tipo de entrada, como las plantillas de ubicación del almacén avanzado de
BC. Las estrategias actuales pasarían a ser plantillas predefinidas.

### Plan ABC por fases

Se decide **observar antes de cambiar nada**. Calcular el ABC es barato; mover palés no (cada
reubicación es un viaje de carretilla que no factura), así que cada fase solo se hace si la
anterior lo justifica con datos.

| Fase | Qué es | Estado |
|---|---|---|
| **1. Observar** | Clasificar productos (A/B/C por palés salidos) y huecos, y guardar cada cálculo. Pantalla *Análisis ABC* | **Hecha** |
| 2. Ubicar según el ABC | Estrategia nueva: primer hueco vacío **de su clase**; si no hay, el de la clase más cercana. Sin movimientos extra: el almacén se ordena solo según rota | Si la fase 1 muestra ventas concentradas |
| 3. Propuestas de reubicación | Lista de movimientos ordenada por ganancia ("este palé C ocupa un hueco A"), a hacer en ratos muertos, nunca forzados al principio | Si tras la fase 2 siguen muchos palés fuera de su clase |
| 4. Aprovechar huecos que se liberan | Al quedar libre un hueco A, proponer traer el mejor candidato (un palé A en un hueco malo) | Junto con la 3 |

Precauciones para las fases 3 y 4: un producto solo cambia de clase si lleva varios cálculos
seguidos en la nueva (por eso se guarda el historial), y límite de movimientos por día o turno.

**Criterio de la fase 1** (Cod. `Analisis ABC SGA`):

- **Rotación = palés salidos**: ventas netas de los últimos *Días de ventas del análisis ABC* (90
  por defecto) en el almacén, pasadas a palés con la unidad de palé del producto. Con palés
  completos, cada palé es un viaje. Se descartó la cantidad vendida (mezcla palés de distinto
  tamaño) y el nº de pedidos (es el criterio cuando se pica en cajas).
- **Clases de producto**: de más a menos salidas, A hasta el 80 % acumulado, B hasta el 95 %, el
  resto C. Los cortes están en *Configuración SGA*. Sin ventas, C.
- **Clases de hueco**: los de Picking y Reserva no bloqueados, del mejor al peor por altura
  (más baja mejor) y *Secuencia picking*. Hay tantos huecos A como palés A en almacén, luego tantos
  B como palés B, y el resto C.
- **Qué mirar para decidir la fase 2**: el *% de salidas del 20 % que más sale* y su evolución
  en *Cálculos anteriores*. Si se queda alrededor del 50 %, las ventas están repartidas y el ABC
  rendirá poco; por encima del 70-80 %, compensa.

### Datos para revisar la decisión

Para saber si alguno de los supuestos de arriba se cumple, hacen falta:

1. **Huecos de palé y ocupación media** (de SGA: *Ubicaciones SGA* y *Cue SGA*).
2. **Productos activos** en el último año.
3. **Concentración de ventas**: % de palés vendidos que se lleva el 20 % de productos que más sale.
4. **Salidas en palé completo frente a cajas sueltas.**

Los puntos 1 a 3 los da ya la pantalla *Análisis ABC* (fase 1). El punto 4 todavía no se
calcula.
