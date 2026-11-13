# Estrategias de ubicación

Documento de decisión: cómo decide SGA hoy dónde deja la mercancía, por qué está así y qué habría que cambiar si cambia el almacén. Para el uso diario, ver la [guía de uso](GUIA_USO_SGA.md). El detalle técnico está en la [documentación técnica](DOCUMENTACION_TECNICA_SGA.md).

## 1. Cómo decide

SGA decide en **dos pasos**:

1. **Qué tipo de hueco.** Cada ubicación tiene un tipo: *Almacenamiento*, *Picking* o *sin tipo*. Solo se proponen las de almacenamiento y de picking. Las de muelles, ajustes u otras sin tipo nunca se proponen.
2. **Cuál de esos huecos.** La estrategia decide en qué orden se buscan.

Antes de esos dos pasos, la mercancía se parte en **trozos** (`Repartir`, de *Unidades Producto SGA*):

- **Palés completos**, de la unidad *Cód. palé por defecto* de la ficha.
- **Un resto** en la unidad de venta (caja) si el producto la tiene, y si no, en unidades.

Cada trozo busca hueco por separado. Un hueco de palé se ocupa con un trozo de palé.

**Orden de tipos.** Por defecto se busca primero en almacenamiento y luego en picking. En la carga inicial con destino *Huecos libres* el orden es el contrario: primero picking, para que el picking se llene desde el principio.

## 2. Reglas que se aplican siempre

Antes de cualquier estrategia, cada ubicación pasa por la misma criba (`MotivoRechazo`). Si una ubicación no sirve, la propuesta sigue con la siguiente y el motivo queda registrado.

| Código | Motivo |
|---|---|
| 0 | Sí admite la mercancía |
| 1 | Bloqueada, o su zona está bloqueada |
| 2 | Tiene producto fijo de otro producto |
| 3 | Es de otro tipo, no tiene tipo o está fuera de la zona indicada |
| 4 | No cabe: la capacidad en palés no da para la entrada |
| 5 | Tiene otro producto y no acepta mezcla de productos |
| 6 | Tiene otro lote y no acepta mezcla de lotes |
| 7 | Está vacía, pero es el destino de una reubicación pendiente de otro producto |
| 8 | Es de picking y el producto ya ocupa todas las ubicaciones de picking que se le permiten (solo en la carga inicial) |
| 9 | Está reservada para otra entrada que aún no se ha ubicado |

**Grupo IIEE.** Si el producto tiene grupo IIEE y ese grupo tiene zonas en el almacén, la búsqueda se hace **primero dentro de esas zonas** y, si no hay hueco, en todo el almacén. El motivo dice en cuál ha salido. Es una preferencia, no una reserva.

## 3. Las cinco estrategias

Así se llaman en *Configuración SGA* y así se comportan en el código (`ProponerDeTipo`). En todas, los huecos se recorren por **secuencia de picking**, de menor a mayor, que es la ruta física del almacén.

| Estrategia | Orden de búsqueda |
|---|---|
| **Estándar** | 1. Ubicación fija del producto. 2. Consolidar: un hueco que ya tenga ese producto y variante. 3. Primer hueco con sitio en la ruta. |
| **Priorizar consolidación** | 1. Consolidar. 2. Primer hueco con sitio en la ruta. |
| **Solo ubicación fija** | Solo la ubicación fija del producto. Si no tiene, o no cabe, *No se puede ubicar*. |
| **Primera libre por ruta** | Primer hueco con sitio en la ruta. |
| **Solo hueco vacío** | Primer hueco totalmente vacío en la ruta. |

**Ubicación fija del producto.** Es un hueco con *Producto Fijo* igual al producto. Si no hay ninguno, se usa el *Nº de estante* de la ficha del producto, si ese hueco existe y admite la entrada.

**Consolidar.** Entre los huecos que ya tienen el producto y admiten la entrada, elige el de **menor secuencia de picking**. No elige el que más cabe.

**Secuencia de picking.** Cada ubicación tiene su número de ruta. Al generar las ubicaciones sale de pasillo, estantería y altura. Si una ubicación no lo tiene, toma la prioridad de su zona.

## 4. Qué estrategia usa cada pantalla

| Pantalla o proceso | Estrategia | Por defecto |
|---|---|---|
| Ubicar recepciones | *Estrategia ubic. compras* | Estándar |
| Ubicar ensamblados | *Estrategia ubic. ensamblados* | Solo hueco vacío |
| Imprimir y ubicar palés (producción) | *Estrategia ubic. ensamblados* | Solo hueco vacío |
| Ubicar producto | *Estrategia ubicación* | Estándar |
| Mover contenido a otra zona | *Estrategia ubicación*, dentro de la zona elegida | Estándar |
| Reubicaciones a picking | Estándar, limitada a huecos de picking | Fija |
| Carga inicial, *Huecos libres* | Palés: primer hueco vacío sin producto fijo, en el orden de tipos. Resto: Priorizar consolidación | Fija |
| Carga inicial, ubicación fija o indicada | Sin estrategia: la ubicación fija del producto o la indicada | Fija |
| Ubicar seleccionadas | Igual que la carga inicial, en modo pendientes | Fija |

Las dos estrategias de ensamblados y compras se configuran en *Configuración SGA*, pestaña *Estrategias*.

## 5. Decisiones vigentes y por qué

- **Ensamblados y palés de producción: Solo hueco vacío.** Lo que sale de producción son palés completos. Cada palé va a un hueco limpio, sin mezclar lotes. No necesita datos ni mantenimiento.
- **Compras: Estándar.** Un producto que ya tiene casa se queda en su casa. Si no, se junta con lo que ya hay. Es la opción que mejor encaja con la reserva en almacenamiento.
- **Un palé por hueco.** Es la regla de trabajo. Hoy el sistema no la impone, ver el punto 7.

## 6. Lo que no hace hoy

- **El análisis ABC no influye en la ubicación.** Solo clasifica y observa. Por rotación no se decide nada.
- **Consolidar no busca el hueco más lleno.** Elige el de menor secuencia de picking que admita la entrada. Puede dejar un hueco casi lleno y otro casi vacío.
- **La capacidad se mide en cantidad, no en palés distintos.** Medio palé ocupa 0,5. Por eso los restos de dos palés distintos pueden caber en un hueco de capacidad 1.
- **Sin capacidad por volumen ni peso.** La capacidad de una ubicación solo se mide en palés.
- **No reparte entre pasillos ni hace cross-docking.**

## 7. Pendiente de decidir

- **Límite de palés distintos por hueco.** Se quiere que la ubicación pueda limitar cuántos palés (SSCC) distintos admite, y no solo la cantidad. Por ahora se mantiene la capacidad actual. Cuando se decida, cambia la criba de la regla 4 y el campo de capacidad de la ubicación.

## 8. Cuándo replantear

| Si pasa esto | Valorar |
|---|---|
| Los huecos de un producto quedan repartidos por el almacén y cuesta encontrarlos | Priorizar consolidación en compras |
| Hay huecos de consolidación casi llenos mientras otros del mismo producto quedan casi vacíos | Cambiar *Consolidar* para elegir el hueco más lleno (cambio de código) |
| Pocos productos concentran casi todas las salidas y los recorridos son largos | Usar el ABC en la propuesta (cambio de código, y hay que clasificar los huecos) |
| Varias personas ubicando a la vez se pisan | La reserva ya lo evita; si aun así molesta, repartir por pasillos (cambio de código) |
| La ocupación media pasa del 85-90 % | Ninguna estrategia nueva da más sitio: el problema es de espacio |
| Hay que separar mercancía por normativa o propios y externos | Usar zonas por grupo IIEE, que ya existen |
