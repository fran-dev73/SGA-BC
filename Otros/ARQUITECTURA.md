# Arquitectura SGA — Cómo está hecho por dentro

Este documento es para quien quiera entender **cómo funciona SGA internamente**: qué tablas existen, quién escribe en ellas, cómo se valida, y por qué se diseñó así.

---

## Dónde está cada cosa

Los objetos están agrupados por tipo dentro de `SGA/`:

```
Tables/           13 tablas: zonas, ubicaciones, contenido, movimientos, órdenes, ABC y buffers
Pages/            31 páginas: listas, fichas, diálogos, factboxes y rol center
PageExtensions/    8 extensiones: ficha y lista de producto, almacén, pedido de venta (ficha, líneas y lista), rol y usuarios
Codeunits/        13 codeunits: la puerta de escritura, los motores, las unidades del producto, la carga inicial, el ABC, la ventana de progreso, el borrado de una ubicación y los dos que abren Ubicar entradas desde los menús
Reports/           6 informes: generación y sincronización, carga inicial y puesta a cero, conciliación y etiquetas
Enums/            12 enums: tipos, estados, orígenes, estrategias, clase de unidad, clase ABC y preparación del pedido
ControlAddIns/     1 control: el lienzo del mapa 3D
TableExtensions/   2 extensiones: responsable de picking (Configuración de usuarios) y cantidad preparada (línea de venta)
PermissionSets/    2 conjuntos de permisos: general (preparadores) y responsable
Otros/             lo que no es un objeto AL: los manuales, los recursos del add-in y el mapa de
                   llamadas entre objetos (MAPA_LLAMADAS.md, que genera GenerarMapaLlamadas.ps1)
```

A AL le da igual la carpeta —compila todos los `.al` del proyecto—, así que mover objetos es
seguro. **La excepción son las rutas de recursos**: las del control add-in se escriben desde
la raíz del proyecto y hay que mantenerlas a mano si los `.js` o el `.css` cambian de sitio.

### Convenciones (las de Microsoft, CodeCop/UICop)

SGA sigue las reglas de los analizadores de Microsoft para poder separarse como aplicación
propia sin retoques. En el resto del proyecto no se aplican todas, así que SGA no se parece en
estos puntos al código de fuera:

- **Namespace** `AntonioNadal.SGA` en todos los objetos, con los `using` de lo que usa de la
  base (`Microsoft.Inventory.Item`, `Microsoft.Warehouse.Structure`…) y del proyecto
  (`AntonioNadal.Produccion` para *Tareas Produccion*).
- **Nombre de fichero** `<NombreObjeto>.<Tipo>.al` (`GestionContenidoSGA.Codeunit.al`,
  `ItemCardSGA.PageExt.al`), no `Cod51100.…`. El número de objeto se ve dentro del fichero.
- **Etiquetas** con nombre descriptivo y sufijo según su uso: `Err` (Error), `Msg` (Message),
  `Qst` (Confirm), `Tok` (bloqueadas), `Lbl`/`Txt` (el resto), y `Comment` en todo `%1`.
- **Variables temporales** con prefijo `Temp`.
- **Ubicaciones siempre `Code[20]`**, como `Bin.Code`: parámetros, variables y los campos
  *Ubic.* de la configuración.
- Se verifica compilando con `/analyzer:` CodeCop, UICop y PerTenantExtensionCop. Quedan sin
  tocar a propósito los avisos informativos AA0232 (marca un índice SIFT que ya existe) y AW0006
  (fichas que se abren desde otra página y no deben salir en el buscador).

---

## Principio fundamental: una puerta única de escritura

**Todas** las escrituras en SGA pasan por un solo codeunit: `Cod51100.GestionContenidoSGA`. Nadie (ni el operario, ni otro codeunit) puede tocar directamente las tablas de contenido o movimientos.

¿Por qué? Porque cada escritura tiene que:
1. Validar que sea legal (capacidad, mezcla de productos, etc.).
2. Aplicar el cambio (delta).
3. Registrar en el diario.
4. Recalcular la ocupación de la ubicación.

Si alguien tocara la tabla sin pasar por ahí, los cuatro pasos se desincronizarían.

---

## Las tablas: estructura de datos

### 1. **Zona SGA** (Tab51100)
```
PK: Cod. Zona
   Descripcion
   Tipo Ubicacion (por defecto)
   Zona de Picking        (otra zona, para consolidar antes de picking)
   Prioridad Ubicacion    (si hay varias libres, cuál preferir)
   Prioridad Picking      (si hay el producto en varias, cuál coger primero)
   Bloqueada              (si está true, no se puede colocar nada en esta zona)
```

Es un agrupador lógico. Cuando creas una ubicación, le asignas una zona, y hereda su tipo por defecto.

### 2. **Ubicacion SGA** (Tab51101)
```
PK: Cod. Almacen + Cod. Ubicacion
   Cod. Zona SGA                  (FK a Zona)
   
   Tipo Ubicacion (enum)          (Picking, Reserva, Producción, etc.)
   Secuencia Picking              (orden en que preguntar en pick)
   
   CAPACIDAD (opcional):
   - Capacidad Uds
   - Capacidad Palets
   - Capacidad Volumen
   - Capacidad Peso
   
   ESTADO (persistido, no FlowField):
   - Estado SGA                   (Vacia / Parcial / Llena / Bloqueada)
   - % Ocupacion                  (0-100)
   
   REGLAS:
   - Bloqueada                    (si true, no se puede meter ni sacar nada)
   - Motivo Bloqueo               (ej: "Esperando QC")
   - Permite Mezcla Producto      (si false, solo un producto)
   - Permite Mezcla Lote          (si false, solo un lote)
   - Producto Fijo                (PK de Item, si está restringida a uno)
   
   CONTROL:
   - Cantidad Minima Reposicion
   - Cantidad Maxima Reposicion
   
   AUDITORIA:
   - Fecha Ultimo Movimiento
   - Hora Ultimo Movimiento
```

Es el "perfil de gestión" de cada ubicación. Se crea una vez en la sincronización topológica y se mantiene.

Las reglas del propio hueco son métodos de la tabla, para que la propuesta (`Cod51101`), el
registro (`Cod51100`), la carga inicial y el ABC lean lo mismo:

```
Methods:
├─ EsUtilizable() -> Boolean             — ni ella ni su zona están bloqueadas
├─ OcupadoEnUMHueco() -> Decimal         — lo que hay, contado en la clase del hueco (redondeado a 0,00001); lee el factor de cada producto una vez
├─ CabeEntrada(Entrada) -> Boolean       — ¿caben Entrada más (en la clase del hueco)? Parte del estado y del % guardados; solo suma el contenido si queda en el borde
├─ EnUMHueco(Producto, CantidadBase)     — una cantidad base de un producto, en la clase del hueco (sin redondear)
├─ ContenidoQueImpideMezcla(Producto, Lote) -> 0 / 5 otro producto / 6 otro lote  — solo mira si existe (IsEmpty)
├─ ContenidoQueImpideMezcla(Producto, Lote, var Contenido) -> igual, y deja en Contenido la línea que choca
├─ FiltrarDeAlmacenaje()                 — filtra Tipo Ubicacion = Picking|Reserva
├─ EsDeAlmacenaje() -> Boolean           — Tipo Ubicacion es Picking o Reserva
├─ DigitoControlCorrecto(Digito) -> Boolean
├─ TestDigitoControl(Almacen, Bin, Digito) — error si el dígito no es el del hueco (lo llama el picking)
└─ EstiloEstado() -> Text                — color según Estado SGA
```

Cada llamante decide el orden de sus comprobaciones y qué hace con cada resultado: el registro
lanza el error de cada caso y la propuesta lo convierte en un motivo de rechazo.

**Importante**: también tiene FlowFields que leen desde la tabla topológica `Ubicacion Almacen` (Pasillo, Estantería, Altura).

### 3. **Contenido Ubicacion SGA** (Tab51102)
```
PK: Cod. Almacen + Cod. Ubicacion + Cod. Producto + Cod. Variante 
    + Cod. Lote + Fecha Caducidad + UM Base
    
   Cantidad Base                  (en UM base, siempre)
   Cantidad Reservada             (cantidad cogida pero no enviada aún)
   Cantidad Disponible (calc)     = Cantidad Base - Cantidad Reservada
   
   Fecha Caducidad
   Fecha Ultima Entrada
   Fecha Ultima Salida
   Hora Ultima Entrada
   Hora Ultima Salida
   
   Bloqueado                      (si true, no se puede picking)
   Motivo Bloqueo                 (ej: "Lote rechazado")
```

Esta tabla es el **estado actual**: qué hay ahora en cada ubicación. Las inserciones/borrados/modificaciones solo los hace `Cod51100.GestionContenidoSGA`.

Un **OnDelete/OnModify/OnRename** en los triggers previene que alguien la edite directamente: devuelve error si no viene de `Cod51100`.

### 4. **Movimiento Ubicacion SGA** (Tab51103)
```
PK: No. Movimiento              (AutoIncrement, inmutable)

   Tipo Movimiento (enum)       (Entrada, Salida, Traslado, Ajuste, Recuento, Carga Inicial)
   Origen (enum)                (Manual, Compra, Produccion, Venta, DocAlmacen, etc.)
   
   Cod. Almacen
   Cod. Ubicacion Origen
   Cod. Ubicacion Destino
   
   Cod. Producto
   Cod. Variante
   Cod. Lote
   UM                           (la que usó el operario)
   Cantidad Base                (en UM base)
   
   No. Documento Origen         (ej: PO123, SO456)
   No. Orden SGA                (para la Fase 2)
   
   Fecha Registro
   Hora Registro
   Fecha Hora Registro          (combinada, para ordenar)
   
   Cod. Usuario                 (quién lo hizo)
   Descripcion                  (nota del operario)
   
   Fecha Caducidad              (copia del lote)
```

Este diario es **inmutable**: `OnModify`, `OnDelete` y `OnRename` lanzan error. Es la fuente de verdad.

Todos los índices para lectura rápida:
- Índice en `Fecha Hora Registro` (para mostrar últimos movimientos en factbox).
- Índice en `Ubicacion Origen` + `Ubicacion Destino` (para filtrar rápido).

### 5. **Config. SGA** (Tab51104)
```
PK: Almacen            (una sola fila por almacén, típicamente "PRINCIPAL")

UBICACIONES DE FLUJO:
   Ubicacion Recepcion Compras
   Ubicacion Entrada Produccion
   Ubicacion Expedicion
   Ubicacion Desbordamiento
   Ubicacion Ajustes

ESTRATEGIAS:
   Estrategia Ubicacion (enum)    (para Fase 2)
   Estrategia Picking (enum)      (para Fase 2)

CONTROLES:
   Control Capacidad (enum)       (Avisar / Bloquear, por defecto Bloquear; "No comprobar"
                                   ya no se ofrece y, si está guardado, bloquea)
   Permitir Cantidad Negativa      (si true, "fuerza" y luego ajusta)
   Exigir Confirmar Ubicacion      (para PDA)
   Permitir Desvio Ubicacion       (si false, solo la que sugiere el motor)

OTROS:
   Dias Aviso Caducidad
   Numeros Orden SGA              (serie de numeración para Fase 2)
```

Tabla de **configuración única** del módulo. Se crea automáticamente la primera vez que se abre `Config. SGA`.

Métodos:
- `ObtenerConfig()`: lee la configuración y la crea vacía la primera vez.
- `TestUbicacionConfigurada(Ubicacion, NombreCampo)`: error si una ubicación de flujo no está configurada.
- `DesvioPermitido(Propuesta, Confirmada): Boolean`: regla de desvío única. Devuelve verdadero si
  la ubicación confirmada es la propuesta o si `Permitir Desvio Ubicacion` está activo. Trabaja sobre
  la configuración ya leída con `ObtenerConfig`. La usan `Cod51101.ConfirmarReparto` (solo en líneas con
  propuesta), `Cod51104.ConfirmarLinea` (error) y `Pag51121.ComprobarUbicacion` (aviso en pantalla);
  cada uno con su propio mensaje.

### 6. **Cue SGA** (Tab51105)
```
PK: Cod. Almacen

FlowFields que cuentan:
   Total Ubicaciones
   Ubicaciones Vacias
   Ubicaciones Parciales
   Ubicaciones Llenas
   Ubicaciones Bloqueadas
   
   Total Lineas Contenido
   Lineas Reservadas
   Lineas Bloqueadas
   
   Movimientos Periodo (últimos 30 días)
```

Tabla de **KPIs**: números agregados para el rol center, que los muestra como mosaicos.

### 7. **Buffer Mapa SGA** (Tab51106)
```
Tabla temporal (SourceTableTemporary = true)

Una fila por cada altura de cada pasillo; una columna por estantería.

PK: Cod. Almacen + Pasillo + Orden   (Orden = 100 - Altura: la altura más alta arriba)

   Pasillo, Altura                (Integer)
   Columna 01 .. Columna 32       (caption E01..E32: resumen de la celda de esa estantería)
   Estilo 01 .. Estilo 32         (color: Verde / Amarillo / Rojo / Gris)
```

La rellenan cada vez que se abre el *Mapa de almacén*. Es un buffer transitorio para renderizar la rejilla.

### 8. **Buffer Conciliacion SGA** (Tab51107)
```
Tabla real, con scope por usuario (CodUsuario es parte de la PK)

PK: Cod. Usuario + Cod. Producto + Cod. Variante + Cod. Almacen + Cod. Lote

   Stock BC               (total del Item Ledger Entry por lote)
   Stock SGA              (suma de Contenido por lote)
   Diferencia             (Stock BC - Stock SGA, redondeada; la calcula ActualizarEstado)
   Estado                 (Cuadra / SinUbicar / SobraEnSGA)
   UM Base
   Descripcion            (FlowField: descripción del producto)

   Solo en temporal (Pendiente de ubicar y carga inicial):
   90 Fecha Caducidad     (CaducidadLote de Cod51103)
   91 En Documentos       (pendiente en Ubicar recepciones / ensamblados)
   92 A Ubicar            (Diferencia - En Documentos)
   93 Desglose            (A Ubicar en palés, cajas y sueltas)

Methods:
├─ ActualizarEstado()       — Diferencia y Estado
├─ FiltrarUsuarioActual()   — SetRange del usuario actual, sin Reset ni
│                             FilterGroup (la página lo llama en su FilterGroup 2)
├─ EstiloConciliacion()
└─ EstiloEnDocumentos()     — ámbar si hay En Documentos (Pendiente de ubicar)
```

Se rellena cuando lanzas el informe *Conciliar con el stock*. Cada usuario ve sus propios resultados (scoped).

Es también la única tabla de stock por lote en memoria: *Pendiente de ubicar* (Pag51131, con
`SourceTableTemporary`) y la carga inicial la usan como temporal. `CargarPendienteUbicar` exige que
el registro sea temporal (`IsTemporary`), porque lo vacía entero sin mirar el usuario.

### 9. **Orden Picking SGA** (Tab51108) — FASE 2

Cabecera de una orden de preparación: qué documento hay que preparar, quién lo prepara, en qué estado va.

```
Claves:
├─ PK: No. Orden
├─ Estado: Almacen, Estado
└─ Asignada: Cod. Usuario Asignado, Estado

Campos clave:
├─ No. Orden (Code[20])              — ID único de la orden
├─ Cod. Almacen (Code[10])           — Almacén donde se prepara
├─ No. Documento Origen (Code[20])   — Pedido de venta o documento que genera la orden
├─ Origen (Enum)                     — De dónde viene (Venta, Compra, etc.)
├─ Estado (Enum)                     — Abierta / En Proceso / Finalizada / Cancelada
├─ Cod. Usuario Asignado (Code[50])  — Preparador asignado
├─ Fecha Creacion (DateTime)         — Cuándo se creó (auto)
├─ Fecha Finalizacion (DateTime)     — Cuándo terminó de prepararse
└─ No. Lineas (FlowField)            — Cuántas paradas tiene

Triggers:
├─ OnInsert: Fija Fecha Creacion y usuario creador
├─ OnDelete: No permite si hay líneas ya recogidas
└─ (OnModify: permite editar Descripcion y usuario asignado)

Methods:
├─ RecalcularEstado()        — Recalcula el estado desde las líneas
├─ Progreso(var Hechas, var Total) — Paradas recogidas de las no canceladas; solo usa
│                              No. Orden (la pantalla del preparador no lee la orden)
├─ EstiloEstado() -> Text    — Color para la UI (Favorable si Finalizada, etc.)
└─ EstiloFechaEnvio() -> Text — En rojo si la fecha de envío ya ha llegado
```

El FlowField `Lineas Pendientes` lleva escrito el filtro `Pendiente|Parcial`, el mismo de
`Linea Orden Picking SGA.FiltrarPendientes`: una `CalcFormula` no puede llamar a un procedimiento.

Una orden es el **guion del recorrido**: dónde ir, qué coger, cuánto. **No mueve stock**: lo mueve `ConfirmarLinea` al confirmar cada parada.

### 10. **Linea Orden Picking SGA** (Tab51109) — FASE 2

Cada parada del recorrido: ubicación, producto, lote, cantidad, estado.

```
Claves:
├─ PK: No. Orden + No. Linea
├─ Recorrido: No. Orden, Estado, Secuencia Picking
└─ Producto: No. Producto, No. Lote

Campos clave:
├─ No. Orden (Code[20])                 — Orden a la que pertenece
├─ No. Linea (Integer)                  — 10000, 20000, 30000, ... (para insertar entre)
├─ Cod. Almacen (Code[10])              — Almacén
├─ No. Producto (Code[20])              — Qué recoger
├─ Cod. Variante (Code[10])             — Variante del producto
├─ No. Lote (Code[50])                  — Lote concreto
├─ Fecha Caducidad (Date)               — Caducidad del lote
├─ Cantidad a Recoger (Decimal)         — Cuánto hay que recoger
├─ Cantidad Recogida (Decimal, readonly)— Cuánto se ha recogido ya
├─ Cantidad Pendiente (Decimal, readonly)— Lo que falta
├─ Cod. Bin Propuesto (Code[20])        — Ubicación calculada de dónde coger
├─ Cod. Bin Confirmado (Code[20])       — Ubicación real de dónde se cogió
├─ Estado (Enum, readonly)              — Pendiente / Parcial / Recogida / Cancelada
├─ Secuencia Picking (Integer)          — Orden de recorrido (pasillo×10000 + estantería×100 + altura)
├─ No. Linea Origen (Integer)           — Línea del documento origen que la generó
└─ Fecha Confirmacion (DateTime)        — Cuándo se confirmó

Triggers:
└─ OnInsert: Llama ActualizarPendiente() para calcular Cantidad Pendiente

Methods:
├─ ActualizarPendiente()       — Recalcula Cantidad Pendiente y Estado
├─ FiltrarPendientes()         — Estado Pendiente|Parcial; no toca la clave ni el resto
│                                de filtros. Es el único sitio con ese filtro en código
├─ CantidadBaseDesdeDocumento(Cantidad, PendienteDocumento) -> Decimal
│                              — Lo tecleado en la UM del pedido, en base; si es lo
│                                pendiente, el pendiente exacto (sin restos de redondeo)
├─ EstiloEstado() -> Text      — Color para UI
├─ HayDesvio() -> Boolean      — ¿Se recogió de otra ubicación?
└─ EstiloUbicacionConfirmada() -> Text — Resaltada si hay desvío
```

Una línea es **una parada**: ir a una ubicación, coger un producto y lote específicos en una cantidad. Si la ubicación tiene 100 cajas del mismo lote, es una parada. Si después hay 50 cajas del mismo producto pero lote diferente en otra ubicación, es otra parada.

**Cantidad preparada en el pedido.** Cada parada guarda también el pedido (`No. Documento Origen`)
y lo recogido en la UM de la línea del pedido (`Cantidad Recogida UM Pedido`, que calcula
`ActualizarPendiente`). Con eso, la extensión de `Sales Line` (Tab-Ext 51102) tiene el FlowField
**Cantidad Preparada SGA**: suma lo recogido de todas las órdenes de esa línea, con la clave
`LineaPedido` y su SIFT. Se enseña en las líneas del pedido (Pag-Ext 51107) delante de *Cantidad a
enviar*, que se rellena después, al terminar la orden.

**Estado de preparación del pedido.** `EstadoPreparacionVenta` (Cod. Gestion Picking SGA) mira las
líneas de producto con *Outstanding Quantity* > 0 y compara lo recogido sin enviar (`Cantidad
Preparada SGA` − *Quantity Shipped*) con lo pendiente: todas completas → *Preparado*; alguna con
algo → *Parcial*; ninguna → *Sin preparar*; sin nada pendiente → en blanco. Se calcula al momento
y no se guarda: guardarlo obligaría a recalcularlo al registrar envíos de BC, y SGA no se engancha
al registro. Por eso en la lista de pedidos (Pag-Ext 51108) no se filtra con los filtros
estándar: las acciones *Ver preparados* / *Ver preparados en parte* llaman a
`Cod51104.MarcarVentasPorEstado` con el `Rec` de la lista, que marca los pedidos (`Mark` +
`MarkedOnly`). Coste: en la lista se calcula por cada pedido que se pinta.

### Navegación: sin menú propio

Hubo una tabla `Menu SGA` (Tab51120) y una página *Centro SGA* (Pag51116) que hacían de
índice del módulo. **Se retiraron el 2026-09-10**: duplicaban lo que BC ya hace con el rol
center y el buscador, y obligaban a mantener a mano una lista de opciones que se desincronizaba
en cuanto se añadía una página.

La navegación es la estándar:

- **Rol center** `Pag51112 "Rol Center Almacen SGA"` y menú SGA del Procesador de Pedidos
  (`Pag-Ext51103`): los dos llevan **los mismos cinco grupos**, con las mismas opciones y en el
  mismo orden, para que se encuentre todo en el mismo sitio: *Almacén SGA* (día a día),
  *- Ventas y compras* (productos, pedidos, históricos de albaranes), *- Consultas*,
  *- Informes* y *- Configuración* (con la puesta en marcha). Si se toca uno, se toca el otro.
  El rol center añade un `Embedding` con productos, pedidos y albaranes.
- **Perfil** `profile "ALMACEN SGA"` (`SGA/Profiles/AlmacenSGA.Profile.al`): publica el rol
  center para que se pueda elegir o asignar. Sin perfil, BC no lo ofrece.
- **Buscador (Tell Me)**: cada página o informe que es punto de entrada declara
  `UsageCategory` y `ApplicationArea`. Lo que no lo declara es porque no debe salir: subpáginas,
  factboxes, diálogos y fichas que se abren desde su lista.

**Al añadir una página nueva** basta con ponerle `UsageCategory` para que se encuentre, y
colgarla del rol center si es de uso frecuente. No hay ninguna lista central que actualizar.

Los IDs **page 51116** y **table 51120** quedan libres.

---

## Los codeunits: la lógica

### Cod51100: GestionContenidoSGA — La puerta única

```
PUBLIC PROCEDURES (son los puntos de entrada):
├─ RegistrarEntrada(Almacen, Ubicacion, Producto, Variante, Lote, 
                    Caducidad, UM, CantidadBase, Origen, NoDocumentoOrigen)
│  └─ Alguien trae mercancía: la metes en SGA.
│
├─ RegistrarSalida(Almacen, Ubicacion, Producto, Variante, Lote, 
                   Caducidad, UM, CantidadBase, Origen, NoDocumentoOrigen)
│  └─ Sacas mercancía de una ubicación (pickup, devolución, etc.).
│
├─ RegistrarTraslado(AlmacenOrigen, UbicacionOrigen, AlmacenDestino, 
                     UbicacionDestino, Producto, Variante, Lote, 
                     Caducidad, UM, CantidadBase, MotivoCambio)
│  └─ Mueves de una ubicación a otra (reorganización).
│
├─ RegistrarAjuste(Almacen, Ubicacion, Producto, Variante, Lote, 
                   Caducidad, UM, CantidadBase, Motivo)
│  └─ Corriges un error (sobra/falta detectado en recuento).
│
├─ RegistrarRecuento(Almacen, Ubicacion, Producto, Variante, Lote, 
                     Caducidad, UM, CantidadBruta, CantidadContada, Motivo)
│  └─ Operario contó lo que hay; SGA calcula la diferencia y ajusta.
│
├─ RegistrarCargaInicial(Almacen, Ubicacion, Producto, Variante, Lote, 
                         Caducidad, UM, CantidadBase, Origen)
│  └─ Solo en la carga inicial: distribuye el stock que BC tenía.
│
├─ Desubicar(var Contenido) -> NoMovimiento
│  └─ Saca una línea entera de su ubicación y la deja sin ubicar. Error si
│     tiene reserva de picking.
│
├─ DesubicarLineas(var Contenido) -> Lineas
│  └─ Lo mismo para todo el conjunto recibido (filtros o marcas de la
│     selección). Todo o nada: comprueba las reservas de todas antes de tocar
│     ninguna. Lo usa "Quitar de la ubicación" de Contenido Ubicaciones SGA.
│
├─ VaciarUbicacion(Almacen, Ubicacion) -> Lineas
│  └─ Error si la ubicación tiene algo reservado; si no, DesubicarLineas con
│     todo su contenido. Lo usan la ficha de la ubicación y el mapa 3D.
│
├─ AlternarBloqueo(var Contenido)
│  └─ Bloquea la línea (motivo "Bloqueado por usuario el fecha") o la
│     desbloquea. El bloqueo lo escribe el procedimiento local BloquearContenido.
│
├─ TrasladarConDialogo(var Contenido, var Destino, DescripcionPorDefecto, MismaZona)
│                     -> NoMovimiento
│  └─ Con MismaZona, el destino tiene que ser de la zona del origen (mapa 3D).
│  └─ Abre "Mover Contenido SGA" (con el destino propuesto si viene) y
│     registra con RegistrarTraslado, origen Manual. Motivo vacío: la
│     descripción por defecto. Devuelve en Destino el elegido; 0 si se cancela.
│
├─ FijarModoSilencioso(Silencioso)
│  └─ Sin diálogos de confirmación (procesos por lotes).
│
├─ FijarReserva(Almacen, Ubicacion, Producto, Variante, Lote, 
                Caducidad, CantidadReservada)
│  └─ Marca cantidad como "cogida pero no enviada" (para picking).
│
├─ ReconstruirContenido(Almacen)
│  └─ CUIDADO: borra todo el contenido y lo regenera desde el diario 
│     de movimientos. Solo si algo se rompió.
│
└─ Inicializar(Almacen, VistaProductos)
   └─ Puesta a cero (Rep51107 "Inicializar Contenido SGA"): borra contenido, movimientos y
      órdenes de picking sin terminar (Cod51104.EliminarOrdenesSinTerminar) del almacén, o
      de los productos de la vista. Sin triggers y sin movimiento que lo registre. Las
      ubicaciones se quedan; al final RecalcularReservasAlmacen y RecalcularEstados. Para
      borrarlas también, el informe llama después a Cod51101.EliminarUbicaciones.

PRIVATE PROCEDURES:
├─ AplicarDelta()
│  └─ Valida (capacidad, mezcla, fijo, bloqueo), modifica/inserta/borra 
│     en Contenido, calcula nuevo estado de ocupación.
│
├─ TestUbicacionAdmite()
│  └─ Comprueba todas las reglas de una ubicación:
│     - ¿Está llena? (por capacidad)
│     - ¿Está bloqueada?
│     - ¿Permite mezcla de productos?
│     - ¿Permite mezcla de lotes?
│     - ¿Es producto fijo y no coincide?
│     - ¿Hay capacidad negativa permitida o bloqueada?
│
├─ InsertarMovimiento()
│  └─ Crea la fila en el diario con todos los datos.
│
├─ LimpiarContenidoVacio()
│  └─ Borra líneas de Contenido que quedaron con cantidad 0.
│
└─ AcumularSinValidar()  (privada, solo usada por ReconstruirContenido)
   └─ Aplica delta sin pasar validaciones. Reconstrucción de emergencia.
```

**Flujo de un `RegistrarEntrada`**:
1. Valida que la ubicación existe y es utilizable.
2. Comprueba si ya existe la línea (producto+variante+lote+caducidad+UM).
3. Si existe, suma cantidad. Si no, inserta nueva.
4. Llama a `AplicarDelta()`.
5. `AplicarDelta()` valida y modifica Contenido.
6. Inserta fila en el diario de movimientos.
7. Recalcula `Estado SGA` y `% Ocupacion` de la ubicación.
8. Retorna (sin commit, el llamador hace Commit).

### Cod51101: GestionUbicacionesSGA — Ciclo de vida de ubicaciones

```
PUBLIC:
├─ ObtenerOCrear(Almacen, CodigoUbicacion)
│  └─ Si la ubicacion SGA no existe, la crea si Config.CrearUbicacionSGAAuto = true.
│
├─ SincronizarTopologia(Almacen)
│  └─ Lee Ubicacion Almacen, crea SGA records para las que falten,
│     respeta las que ya existen.
│
├─ RecalcularEstados(Almacen)
│  └─ Para cada ubicacion SGA, suma el contenido de sus líneas,
│     calcula % ocupacion y Estado.
│
├─ GenerarUbicaciones(Almacen, PasilloDesde, PasilloHasta, EstanteriaDesde,
│                     EstanteriaHasta, AlturaDesde, AlturaHasta, Zona, Tipo,
│                     Capacidad)
│  └─ Crea de golpe N ubicaciones. Idempotente. El código lo compone
│     ComponerCodigoUbicacion y la secuencia es pasillo×10000 + estantería×100
│     + altura. Las nuevas nacen en la zona indicada; las existentes no cambian.
│     El informe (Rep51100) pide la zona entre las del almacén y propone su
│     tipo de ubicación.
│
├─ EliminarUbicaciones(Almacen, var NoEliminadas, var Ejemplos, var Motivo) -> Eliminadas
│  └─ Borra todas las ubicaciones del almacén (ficha SGA y Bin) para volver a
│     generarlas. La llama Rep51107 con "Eliminar también las ubicaciones",
│     después de Cod51100.Inicializar. Hace Commit y borra cada hueco con
│     Codeunit.Run de Cod51112 "Eliminar Ubicacion SGA" (Delete(true) de la
│     ficha y del Bin): el que BC no deja borrar (stock en Warehouse Entry,
│     documentos o diario de almacén) se queda entero y se cuenta. Al final
│     borra las fichas SGA sin Bin y deja en blanco las ubicaciones por defecto
│     de Config. SGA que ya no existen.
│
├─ ComponerCodigoUbicacion(Pasillo, Estanteria, Altura: Integer) -> Code[20]
│  └─ Formato pasillo-estantería-altura con ceros a la izquierda: pasillo a
│     tres dígitos, estantería y altura a dos (1, 5, 2 → 001-05-02). Lo usan
│     GenerarUbicaciones y la celda del mapa (Cod51102.AbrirContenidoCelda).
│
├─ TrocearCodigo(Codigo, var Pasillo, var Estanteria, var Altura: Integer)
│                -> Boolean
│  └─ Lo contrario: false si no tiene tres partes numéricas de 3, 2 y 2
│     dígitos. Lo usan el mapa (rejilla y 3D), que no dibuja esos códigos, y el
│     análisis ABC (altura del hueco; sin formato cuenta como la peor).
│
├─ AplicarCambiosUbicaciones(var Seleccion, var TempPlantilla, CambiarCapacidad,
│                            CambiarAdmite, CambiarMezcla, CambiarTipo,
│                            CambiarZona, var Omitidas, var Ejemplos) -> Hechas
│  └─ "Cambiar en bloque": solo lo marcado, con el valor de la plantilla, y solo
│     en ubicaciones vacías. Orden: Admite, Mezcla, Capacidad, Tipo (con
│     Validate); la zona se asigna sin validar; RecalcularOcupacion y
│     Modify(true). Las que tienen contenido se cuentan en Omitidas y las
│     cinco primeras van en Ejemplos.
│
├─ ContarConContenido(var Seleccion) -> Integer
│  └─ Cuántas de la selección tienen contenido (las que el cambio se salta).
│
├─ RegenerarDigitos(var Seleccion) -> Hechas
│  └─ Dígito de control nuevo para la selección (Modify sin triggers).
│
├─ ContarUbicaciones(Almacen, Zona, Estado) -> Integer
│  └─ Cuántas ubicaciones del almacén (o de la zona, si no va en blanco) están en ese estado.
│
├─ ResumenUbicaciones(Almacen, Zona) -> Texto
│  └─ "N ubicaciones: X vacías, Y llenas, Z bloqueadas." (resumen del mapa 3D, del almacén
│     o de la zona).
│
├─ TestMismaZona(Almacen, Origen, Destino)
│  └─ Error si son de zonas distintas: el mapa 3D no traslada entre zonas.
│
├─ TestUbicacionEnZona(Almacen, Ubicacion, Zona)
│  └─ Error si la ubicación no es de la zona (zona en blanco: no exige nada).
│
├─ ProponerEnZona(Almacen, Zona, Origen, Producto, Variante, Lote, UM, Cantidad, var Motivo)
│                -> Ubicacion
│  └─ ProponerUbicacionCon limitado a la zona y sin el origen: hueco para un traslado
│     entre zonas (diálogo Mover Contenido).
│
├─ UbicacionFijaProducto(Producto) -> Ubicacion
│  └─ Si el producto tiene Shelf No. en su ficha, retorna eso.
│     Si no, retorna el campo "Producto Fijo" de la Ubicacion SGA.
│
├─ ProponerUbicacionCon(Estrategia, Excluidas, Almacen, Producto, Variante,
│                       Lote, UM, Cantidad, var Motivo) -> Ubicacion
│  └─ Única puerta para proponer hueco. Con hueco, Motivo dice por qué ese
│     (fija, consolidación, primer hueco libre o vacío); sin hueco, la causa
│     y qué hacer (ExplicarSinHuecoLote, con el lote).
│
├─ ExplicarSinHuecoLote(Almacen, Producto, Lote, UM, Cantidad) -> Texto
│  └─ Por qué no hay hueco, contando los de la clase destino por motivo.
│     La carga inicial la usa directamente para el motivo de palé.
│
├─ AnadirExclusion(Filtro, Codigo) -> Filtro
│  └─ Suma un hueco al filtro de exclusiones de la propuesta ('<>A&<>B').
│     Un código en blanco no añade nada.
│
├─ ProponerReubicacionABC(Almacen, Producto, UM, Cantidad, Excluidas, var Origen, var Destino) -> Boolean
│  └─ Solo con "Reubicar Pale A por ABC" de la configuración y una entrada de palé de un
│     producto que no es A. Destino = el primer hueco de palé vacío de la ruta; Origen = el
│     palé A más lejano en la ruta que cabe en él (solo en su hueco, sin reservar ni bloquear,
│     fuera de ubicación fija). Las clases salen del último cálculo de Cod51107.
│
├─ ProponerReparto(Estrategia, Almacen, Producto, Variante, Lote,
│                  CantidadBase, var TempLinea)
│  └─ Ubicación guiada: Cod51108.Repartir con el palé de la ficha y, línea a
│     línea en orden, ProponerUbicacionCon con las exclusiones acumuladas.
│     Pendiente (propuesta = confirmada) o "Sin Sitio" con el motivo.
│     Como mucho 200 líneas: el tope se pasa a Repartir, que no crea más.
│
├─ ConfirmarReparto(var TempLinea, Linea, Almacen, Producto, Variante,
│                   Lote) -> RestoBase
│  └─ Valida todas (ubicación existe, "Exigir confirmar ubicación",
│     "Permitir desvío ubicación") y luego registra con Cod51100.
│     Linea = 0: todas las que tienen ubicación (salta las que no);
│     una línea sin ubicación da error. Devuelve lo que queda sin ubicar.
│
└─ ComprobarUbicacionExiste(Almacen, Ubicacion)
   └─ Error si la ubicación no existe en el almacén. Con el almacén o la
      ubicación en blanco no comprueba nada. La usan ConfirmarReparto, el
      OnValidate de "Ubicacion Confirmada" en la tabla Linea Ubicacion SGA
      (51114) e ImprimirYUbicarPale de la página Imprimir y ubicar palés,
      que la vuelve a comprobar antes de imprimir la etiqueta. La pregunta
      sin error es UbicacionExiste.
```

### Cod51102: GestionMapaSGA — Render del mapa

```
PUBLIC:
├─ ConstruirMapa(var Buffer, Almacen): Integer
│  └─ Lee Ubicacion SGA, agrupa por (Pasillo, Altura) y rellena BufferMapa
│     con una columna por estantería (E01..E32). Devuelve la última estantería
│     encontrada: si pasa de la 32, la página avisa. Los códigos sin formato
│     no se dibujan.
│
├─ AbrirContenidoCelda(BufferRec, NumColumna)
│  └─ Abre la página de Contenido filtrada por esa ubicación; el código lo
│     compone Cod51101.ComponerCodigoUbicacion.
│
├─ PintarCelda(BufferRec, NumColumna) -> ResumenTexto, EstiloColor
│  └─ Retorna lo que va dentro de la celda (ej: "5 prod (150 ud)")
│     y el color (Verde / Amarillo / Rojo / Gris).
│
├─ ResumenUbicacion(Ubicacion) -> Texto
│  └─ Formatea para mostrar: "BLOQ" si está bloqueada,
│     "-" si vacía, nombre de producto si mono, "N productos" si multi.
│
└─ ValorNumerico / PadNumero  (utilidades)
```

### Cod51103: ConsultaStockSGA — Decomposición por lote

```
PUBLIC:
├─ AcumularStockPorLote(Almacen, ItemFilter) 
│  └─ Lee Item Ledger Entry, agrupa por (Item, Variant, Lote),
│     llena BufferConciliacion con lo que BC cree que hay.
│
├─ AcumularContenidoUbicado(Almacen, ItemFilter)
│  └─ Lee Contenido SGA, agrupa por (Producto, Variante, Lote),
│     suma cantidades por ubicación.
│     Actualiza las filas de BufferConciliacion con lo que realmente hay.
│
├─ ClasificarYFiltrar(Almacen, SoloDiferencias)
│  └─ Para cada fila de BufferConciliacion:
│     - Si BC = SGA: Estado = "Cuadra".
│     - Si BC > SGA: Estado = "SinUbicar" (falta meter en ubicaciones).
│     - Si SGA > BC: Estado = "SobraEnSGA" (hay más de lo que dice BC).
│     Si SoloDiferencias = true, borra las que cuadran.
│
├─ LimpiarBuffer(var rStock: BufferConciliacion)
│  └─ Borra las filas del usuario actual (FiltrarUsuarioActual) de BufferConciliacion.
│
├─ RegularizarConciliacion(var Fila) -> Boolean
│  └─ "Regularizar en ubicación de ajustes" de la conciliación. Diferencia 0:
│     avisa de que cuadra. Negativa (sobra en ubicaciones): avisa y no hace
│     nada. Positiva: error si no hay ubicación de ajustes, Confirm y
│     Cod51100.RegistrarAjuste; con movimiento, la fila queda con Stock SGA =
│     Stock BC. True si ha registrado.
│
├─ CargarPendienteUbicar(Almacen, var Pendiente temporal) -> Lineas
│  └─ Una línea de BufferConciliacion (temporal) por lote con Diferencia > 0,
│     con En Documentos, A Ubicar, Desglose (Cod51108.Desglose) y caducidad.
│     Ventana de progreso (Cod51111, solo con interfaz): la lectura del
│     almacén y luego producto y barra, refrescada como mucho cada 300 ms.
│
├─ MostrarEnDocumentos(var Linea) / MostrarStockBC(var Linea)
│  └─ Navegación de Pendiente de ubicar: abre Ubicar recepciones o ensamblados
│     (Pag. Ubicar Entradas SGA.Preparar: origen, almacén y producto, sin fechas
│     ni clase; si el lote está en los dos, StrMenu) o los movimientos de
│     producto abiertos del lote. "Ubicado" usa ConsultarUbicacionesProducto.
│
├─ TotalUbicadoProducto(Almacen, Producto, Variante, Lote) -> Decimal
│  └─ CalcSums de "Cantidad Base" del contenido; cada filtro solo si viene.
│
├─ PendienteDeUbicar(Almacen, Producto, Variante, Lote, var Stock, var Ubicado)
│  └─ Item.Inventory con sus filtros menos TotalUbicadoProducto. No descuenta
│     lo que está en documentos. Lo usa Ubicar producto.
│
├─ ConsultarUbicacionesProducto(Producto, Variante, Almacen, Lote)
│  └─ Abre "Consulta Ubic. Producto SGA" con los filtros que vengan.
│     La usan las acciones de la ficha y la lista de productos.
│
├─ CaducidadLote(Producto, Variante, Lote) -> Date
│  └─ La del último movimiento de producto del lote con fecha, en cualquier
│     almacén; la variante solo filtra si viene. Única regla: la usan el
│     registro de movimientos (Cod51100) y Pendiente de ubicar.
│
└─ LoteEstandar(Producto) -> Boolean
   └─ Si el producto tiene código de seguimiento con "Seguim. específico
      lote". Única regla de "lotes de BC o lote propio": la usan el lote de
      los ensamblados (Cod51105.LotesEnsamblado) y el paso al pedido
      (Cod51104.EscribirSeguimientoLotes).
```

### Cod51108: UnidadesProductoSGA — Las unidades del producto

Reúne lo que SGA sabe de las unidades de medida del producto: factor, unidad base, validación
y clase (palé, caja o unidad). El registro de movimientos (Cod51100), el motor de propuestas y la
tabla de ubicaciones (Cod51101, Tab Ubicacion SGA) sacan de aquí el factor de la ficha. Quedan
lecturas directas de "Item Unit of Measure" en estos sitios:

- `Cod51102 GestionMapaSGA`: cuántas unidades lleva el palé por defecto del producto (`gf` del
  mapa), en la unidad que se muestra; y, en `UnidadParaMostrar`, los factores del palé por
  defecto y de la unidad de venta de la ficha para elegir en qué unidad se enseña cada línea.
- `Cod51105 GestionEntradasSGA` (`PrepararPaleTarea`): que el palé de la tarea existe en el
  producto y su factor, para saber cuánto lleva la etiqueta. El reparto de ese palé lo hace
  `Repartir`.

```
PUBLIC:
├─ FactorUM(Producto, UM) -> Decimal
│  └─ Unidades base de la UM. 1 si el producto o la UM van en blanco, si el
│     producto no tiene esa UM o si su factor no es positivo.
│
├─ UMBase(Producto) -> UM
│  └─ Unidad base del producto; en blanco si el producto no existe.
│
├─ LeerUMBase(Producto, var UMBase) -> Boolean
│  └─ La de UMBase, leída de la ficha una vez por producto en cada instancia
│     del codeunit (UMBase la usa). False si el producto no existe. Es la que
│     usan los recorridos largos (Cod51103 al acumular stock y contenido).
│
├─ TestUMProducto(Producto, UM) -> Decimal
│  └─ Error "La unidad de medida %1 no está definida para el producto %2"
│     si la UM no es la base ni una de sus unidades. Error estándar si el
│     producto no existe. Si la UM vale, devuelve su factor (1 la base o un
│     factor no positivo), y así el registro de movimientos la lee una vez.
│
├─ TipoUMProducto(Producto, UM) -> Palé / Caja / Unidad / en blanco
├─ UMAdmitida(Producto, Tipo, UM) -> Boolean
├─ TipoHuecoDestino(Producto, UM, Cantidad) -> Palé / Caja / Unidad / en blanco
├─ UMProductoDeTipo(Producto, Tipo) -> UM
├─ CantidadEnClase(Producto, Tipo, CantidadBase) -> Decimal
├─ FactorClase(Producto, Tipo) -> Decimal
│
├─ Repartir(Producto, CantidadBase, UMPale, MaxLineas, var TempLinea)
│  └─ El reparto único, en líneas de Tab51114: una por palé completo
│     ("Palé n de N", cantidad 1), una con las cajas completas ("Unidades de
│     venta") y una con las sueltas ("Unidades sueltas", UM base). Sin líneas
│     a cero; sin caja, todo lo que no llega a un palé va en la de sueltas.
│     UMPale en blanco: palé y caja de la ficha (UMProductoDeTipo). Con un
│     palé indicado (el de la tarea): ese palé y la unidad de venta como caja
│     si su factor es > 1 y menor que el del palé. MaxLineas > 0: no crea
│     más líneas que esas (las primeras del reparto); 0 reparte entero.
│     Borra antes TempLinea y solo rellena producto, UM, cantidades y Paso.
│     Lo usan ProponerReparto (Cod51101, con tope de 200), la carga inicial
│     por huecos libres (Cod51106) y el palé de tarea (Cod51105), sin tope.
│
└─ Desglose(Producto, CantidadBase) -> Texto
   └─ "1 PALE, 12 CAJA12, 6 BOTELLA" con las unidades de Repartir (palé de la
      ficha), dividiendo y sin límite de palés. Vacío si el producto va en
      blanco o la cantidad no es positiva. Lo usan Ubicar producto (Equivale
      a) y Pendiente de ubicar (Desglose).
```

Las funciones de clase (TipoUMProducto, UMAdmitida, TipoHuecoDestino, UMProductoDeTipo) se
explican en "Unidad de medida por ubicación".

Las conversiones con el factor guardado en el propio documento (línea de venta, ensamblado,
línea de picking) no pasan por aquí: usan el de su registro, porque la ficha puede haber cambiado
después.

---

## Validaciones: la puerta única asegura que no se rompa nada

Cada vez que entra un movimiento, se valida:

### 1. Ubicación válida
- ¿Existe?
- ¿Está activa (no marcada para eliminación)?
- ¿Pertenece al almacén correcto?

### 2. Capacidad
- ¿La ubicación tiene capacidad configurada?
- ¿Cabe el movimiento? (si no, avisa o bloquea según `ControlCapacidad`).

### 3. Mezcla de productos
- Si `PermiteMezclaProducto = false`, ¿ya hay otro producto en la ubicación?
- Si `ProductoFijo` está asignado, ¿coincide?

### 4. Mezcla de lotes
- Si `PermiteMezclaLote = false`, ¿ya hay otro lote en la ubicación?

### 5. Bloqueo
- ¿La ubicación está bloqueada?
- ¿La línea de contenido está bloqueada?

### 6. Cantidades
- ¿Hay cantidad negativa? (si `PermitirCantidadNegativa = false`, error).
- ¿La cantidad reservada no supera la disponible?

Si algo falla, se retorna un error y **no se hace commit**.

---

## Ocupación: persisted vs FlowField

Originalmente se consideró hacer `% Ocupacion` y `Estado SGA` como FlowFields (calculados). **Se decidió persistirlos** porque:

1. **Rendimiento**: con 5000 ubicaciones, calcular % ocupacion en tiempo real escaneando todas sus líneas es lento.
2. **Filtrado**: si % Ocupacion es FlowField, no puedes filtrar "solo las ubicaciones que están entre 50-80% llenas".
3. **Confiabilidad**: si la ocupación se persiste, sabes exactamente cuál era en cada momento.

Se recalculan **bajo demanda**:
- Cada movimiento recalcula la ubicación afectada.
- La acción "Recalcular estado" en la ficha recalcula una.
- El informe "Sincronizar" recalcula todas.

---

## Diario inmutable: auditoría y reconstrucción

El diario `Movimiento Ubicacion SGA` **no se puede tocar**. Los triggers lanzan error si alguien intenta `OnModify`, `OnDelete` o `OnRename`.

¿Por qué inmutable?
- **Auditoría legal**: "¿Quién tocó qué lote en 2026-09-15 a las 14:23?". Debe ser imposible cubrir huellas.
- **Reconstrucción**: si la tabla de Contenido se corrompe (bug, query manual, lo que sea), se regenera reproduceando el diario desde el primer movimiento.

El procedimiento `ReconstruirContenido` hace:
1. Borra toda la tabla `Contenido SGA`.
2. Lee el diario desde el movimiento más antiguo.
3. Aplica **cada movimiento sin validación** (porque están validados, y el diario dice la verdad).
4. Recalcula ocupaciones.

La única puerta que borra el diario es `Cod51100.Inicializar` (Rep51107), una puesta a cero para
repetir la carga inicial: `DeleteAll(false)`, sin pasar por los triggers. Borra por almacén y
producto a la vez el contenido y sus movimientos, así que lo que queda sigue cuadrando con el
diario.

---

## Flow de los procesos de Fase 1

### Carga inicial
```
Report 51102 "Carga Inicial Contenido SGA"     (solo pide opciones y filtro de productos)
  └─ Cod51106 "Carga Inicial SGA".Run()
     └─ Para cada Item (filtro del informe, Type = Inventory):
        └─ Cod51103.AcumularStockPorLote()       (producto + variante + lote, en UM base)
        └─ según Destino:
           ├─ Ubicación fija / indicada: todo el lote a un sitio
           └─ Huecos libres: Cod51108.Repartir (palé y caja de la ficha)
              ├─ cada palé       → Cod51101.ProponerHuecoPaleRuta (vacío, uno por palé; sin
              │                    hueco, los que quedan se anotan juntos como no cargados)
              ├─ cajas           → Cod51101.ProponerUbicacionCon(Priorizar Consolidacion, UM caja)
              ├─ sueltas         → Cod51101.ProponerUbicacionCon(Priorizar Consolidacion, UM base)
              └─ sin caja / sin hueco → no se carga, con el motivo
        └─ Cod51100.RegistrarCargaInicial()      (sin validar capacidad ni UM: ya se ha elegido)
  └─ Pag51125 "Resultado Carga Inicial SGA"      (una fila por palé, grupo de cajas o no cargado;
                                                   líneas de Tab51114 con Origen "Carga Inicial")
```

**Decisiones de la carga inicial**:
- **La simulación es la carga real deshecha.** `OnRun` termina con `Error(MarcaSimulacionTxt)`
  y el informe distingue esa marca con `EsFinSimulacion`. Así cada propuesta ve los huecos que
  han ocupado las anteriores, cosa que una simulación "sin escribir" no podría. El resultado
  sobrevive porque va en una tabla temporal (Tab51114 "Linea Ubicacion SGA"), que no entra en la
  vuelta atrás. Cargado es Estado Ubicado (con su ubicación); no cargado, Estado "Sin Sitio"
  (con el motivo). La página pinta en rojo lo no cargado con `EstiloCargaInicial` de la tabla.
- **Todo o nada.** Si algo falla a mitad, se deshace la carga entera. Los productos bloqueados se
  apartan antes (salen como no cargados) porque `AplicarMovimiento` los rechaza con error.
- **Cursor de huecos de palé.** El hueco de cada palé lo busca `ProponerHuecoPaleRuta` del motor de
  propuesta (Cod51101), no la carga. Los huecos vacíos sin producto fijo se recorren una sola vez
  en orden de ruta (`HuecoRuta`, solo avanza, guardado en la instancia del codeunit): vacío y sin
  producto fijo, un hueco admite a cualquiera, así que el que se salta no le sirve a nadie
  después. Los huecos con `Producto Fijo` se miran aparte, por producto. Sin esto, cada palé
  recorrería la nave entera. La carga hace `Clear` de su instancia al empezar, y el cursor arranca
  de cero.
- **Hueco de palé válido**: el de `FiltrarCandidatas` (Picking/Reserva, sin bloquear,
  `Tipo UM Admitida` = Palé), sin contenido (`VaciaYAdmite`, contado en el contenido y no en el
  estado guardado, porque el cursor lee los huecos por adelantado) y que pase `MotivoRechazo` con
  un palé: su zona sin bloquear, sin producto fijo de otro y con capacidad 0 (sin límite) o ≥ 1.
- **Respuestas del usuario (2026-10-28)**: el resto en cajas va a huecos mixtos de caja; un
  producto sin unidad de palé, a la ubicación indicada; lo que no cabe no se carga.


### Pendiente de ubicar (Pag51131)

Lo calcula `CargarPendienteUbicar` (Cod. Consulta Stock SGA) al abrir: stock de BC por lote menos
lo ubicado, con las mismas funciones y la misma tabla que la conciliación (Tab51107 en temporal;
lo sin ubicar es su `Diferencia`). `AcumularStockPorLote` y `AcumularContenidoUbicado` con el
producto en blanco leen todo el almacén de una vez (dos consultas, no dos por producto). Solo
cuentan los productos de tipo Inventario cuyas existencias en el almacén (la suma de sus lotes,
igual a su `Inventory`) son positivas. La caducidad es la de `CaducidadLote`, la misma que se guarda al
ubicar: el último movimiento del lote con fecha, en cualquier almacén. De lo sin ubicar separa lo que está
pendiente en *Ubicar recepciones* / *Ubicar ensamblados* (`CargarEntradasLote` de Cod51105: sin fechas
y filtrado por el producto, la variante y el lote de cada línea con algo sin ubicar, en unidad
base; así no repasa todos los ensamblados de la historia del producto): eso se ubica desde allí, porque esas
pantallas cuentan lo ubicado por su documento y lo volverían a pedir. Lo que queda (*A ubicar
aquí*) es lo que se ubica desde esta página:
- **Ubicar**: abre *Ubicar producto* con `Preparar` (almacén, producto, variante, lote, caducidad y
  cantidad en unidad base).
- **Ubicar seleccionadas**: la carga inicial en modo `FijarPendientes`: huecos libres, con la
  cantidad *A ubicar* de cada lote en vez del stock entero, sin omitir productos con contenido. Se
  puede simular. Los movimientos van como carga inicial con la descripción "Ubicación de stock
  pendiente SGA".
### Conciliación
```
Report "Conciliacion SGA vs Stock"
  └─ Llama Cod51103.AcumularStockPorLote()
     (¿cuánto dice BC que hay?)
  └─ Llama Cod51103.AcumularContenidoUbicado()
     (¿cuánto hay realmente en ubicaciones?)
  └─ Llama Cod51103.ClasificarYFiltrar()
     (compara, calcula Estado)
  └─ Abre página "Conciliacion SGA" con los resultados.

Página "Conciliacion SGA", acción "Regularizar en ubicación de ajustes"
  └─ Llama Cod51103.RegularizarConciliacion(fila)
     └─ "SinUbicar" (falta): Confirm y Cod51100.RegistrarAjuste()
        (lo mete en la ubicación de ajustes; la fila queda cuadrada)
     └─ "SobraEnSGA" (exceso): avisa pero no regulariza
        (hay que recontar las ubicaciones).
```

---

## Límites arquitectónicos (por diseño)

### No toca Item Ledger Entry
SGA **nunca** toca IIEE. El stock en BC sigue siendo la verdad. SGA solo reparte esa verdad entre ubicaciones.

### Un traslado no genera IIEE
Trasladar desde ubicación A a B no genera IIEE: es reorganización interna.

### Movimientos de producto vienen de fuera (Fase 2)
Cuando un picking se confirma o una compra llega, el codeunit de ese flujo llama a `Cod51100.RegistrarSalida` o `RegistrarEntrada`: `Cod51104` para el picking y `Cod51105` para las recepciones y los ensamblados. Ninguno se dispara desde el registro de BC (ver *Entradas*).

### Ninguna lógica de decisión (Fase 2)
No hay motores que decidan "mete aquí" o "coge de ahí". Eso viene en Fase 2.

---

## Seguridad: la puerta única

La tabla `Contenido Ubicacion SGA` y `Movimiento Ubicacion SGA` tienen triggers en `OnModify`, `OnDelete` y `OnRename`:

```al
trigger OnModify()
begin
    if not CheckEditableByCod51100() then
        Error('Esta tabla solo puede ser editada por Cod51100.');
end;
```

`CheckEditableByCod51100()` comprueba que la llamada viene del codeunit 51100. Si alguien intenta SQL directo o una query manual, se bloquea.

**Nota**: el trigger se puede bypassear con `CHANGECOMPANY` o acceso directo a BD. Pero dentro de AL, es imposible.

---

## Los codeunits de Fase 2: picking y ubicación

### Cod51104: GestionPickingSGA — Motores de decisión

```
PUBLIC:
├─ CrearOrdenDesdeVenta(NoPedido) -> NoOrden
│  └─ Convierte un pedido de venta LANZADO en paradas. Error si ya
│     tiene una orden Abierta/En proceso. Por línea manda a recoger
│     min(Cantidad base − ya recogido en órdenes anteriores,
│     Pendiente base). Reserva tras cada línea del pedido.
│     Si hay stock insuficiente, crea la orden igual y avisa.
│
├─ ConfirmarLinea(var Linea, BinConfirmado, CantidadBase, DigitoControl)
│  └─ El preparador confirma haber recogido de una parada:
│     - Cantidad > 0; con "Exigir Confirmar Ubicacion", la ubicación
│       escaneada es obligatoria (sin ella, en blanco = la propuesta).
│     - Parada no cancelada y cantidad dentro de lo pendiente.
│     - Desvío según config y dígito de control del hueco real.
│     - Actualiza la parada y luego llama a RegistrarSalida.
│     - Recalcula la reserva del hueco propuesto (y del real).
│     - Recalcula estado de la orden.
│
├─ CancelarLinea / CancelarOrden
│  └─ Cancela y libera la reserva. Lo ya recogido no se deshace.
│
├─ TomarSiguienteOrden(var Orden) -> Boolean
│  └─ Las del usuario abiertas; si no, la más antigua sin asignar,
│     que pasa a ser suya.
│
├─ TomarParaPreparar(var Orden) -> Boolean / ComprobarPreparador(var Orden)
│  └─ Ver "Asignación: el paso intermedio".
│
├─ AbrirPreparacion(var Orden)
│  └─ Error si la orden no tiene paradas pendientes; vuelve a leer la
│     orden y TomarParaPreparar (si no confirma, no abre); Commit y abre
│     "Preparar Picking SGA" con sus paradas pendientes. Lo usan la lista
│     y la ficha de órdenes.
│
├─ AsignarOrden(var Orden, Usuario) / AsignarOrdenes(var Orden, Usuario)
│                                     -> Hechas
│  └─ Validate + Modify(true) de una orden o de toda la selección (por
│     clave primaria, porque asignar cambia el estado de la clave de la página).
│
├─ CambiarPrioridad(var Orden, Delta)
│  └─ Suma Delta a la prioridad de la selección, sin bajar de cero, por
│     clave primaria (la prioridad está en la clave de la página).
│
├─ ComprobarResponsablePicking()
│  └─ Con "Exigir Asignacion Picking", error si el usuario no es
│     responsable de picking (User Setup."Responsable Picking SGA").
│
├─ UsuarioActual() -> Code[50]
│  └─ El usuario tal como se guarda en "Cod. Usuario Asignado".
│
├─ PasarAPedido(var Orden)          (también OnRun, TableNo = Orden)
│  └─ Escribe en el pedido Qty. to Ship y, si el producto lleva lotes
│     estándar, el seguimiento por lote.
│
├─ PasarAPedidoDeVenta(NoPedido)
│  └─ PasarAPedido con la última orden de venta del pedido (basta una:
│     suma todas las del pedido). Error si no tiene ninguna.
│
├─ EstadoPreparacionVenta(Cabecera) / EstiloEstadoPreparacion(Estado)
│  └─ Ver "Estado de preparación del pedido".
│
├─ MarcarVentasPorEstado(var Venta, Estado)
│  └─ Marca los pedidos de la vista en ese estado y deja MarkedOnly.
│
├─ RecalcularReserva / RecalcularReservasOrden / RecalcularReservasAlmacen
│  └─ Reserva de un hueco = Σ Cantidad Pendiente de sus paradas
│     abiertas, recortada a lo que hay. Vía Cod51100.FijarReserva.
│
└─ EliminarOrdenesSinTerminar(Almacen, Producto)
   └─ Borra, sin triggers, las órdenes abiertas, en proceso o pendientes de asignar
      (con sus paradas, aunque tengan algo recogido); con producto, solo las que lo
      llevan. Solo para Cod51100.Inicializar; no recalcula reservas.

PRIVATE:
├─ GenerarParadas(var Orden, LineaVenta, CantidadBase, NoLinea)
│  └─ Reparte la cantidad entre las ubicaciones con disponible
│     (cantidad − reservada), una parada por cada una, guardando
│     la UM y el factor de la línea del pedido.
│
├─ RecogidoPorLote / EnviadoPorLote
│  └─ Recogido: Cantidad Recogida de todas las órdenes del pedido.
│     Enviado: movimientos de producto de sus albaranes de venta.
│
├─ EscribirSeguimientoLotes(LineaVenta, Lotes, Caducidades)
│  └─ Solo con Cod51103.LoteEstandar del producto; sin él no hace nada.
│     Borra el seguimiento Surplus/Prospect con lote de la línea y
│     lo crea con Create Reserv. Entry. Error si hay Reservation.
│
├─ OrdenarPorEstrategia(var Contenido, Estrategia)
│  └─ Fija el orden en que se recorre el contenido según 
│     FEFO, FIFO o Vaciar.
│
└─ SiguienteNoOrden(Serie) -> Code[20]
   └─ Obtiene el siguiente número de la serie de órdenes.
```

**Cómo funciona el picking**:
1. Oficina lanza el pedido de venta y pulsa *Enviar a picking* (`Pag-Ext51104`).
2. `CrearOrdenDesdeVenta` comprueba que el pedido está lanzado y que no tiene otra orden viva.
3. Por cada línea, `GenerarParadas` busca dónde está el stock:
   - Busca en `Contenido Ubicacion SGA` el producto y la variante con disponible > 0.
   - Ordena por estrategia (FEFO primero caduca, FIFO primero entra, etc.).
   - Crea una parada por cada ubicación y lote.
4. Tras cada línea del pedido se reserva (`RecalcularReservasOrden`), para que la línea siguiente no vea ese stock.
5. El preparador pulsa *Siguiente orden* (o *Preparar*) y la orden pasa a ser suya.
6. Ve cada parada en la UM del pedido: ubicación, producto, lote y cantidad.
7. Escanea la ubicación y pulsa *Confirmar recogida*. La página pasa la cantidad a base con
   `CantidadBaseDesdeDocumento` de la parada.
8. `ConfirmarLinea` comprueba la ubicación (obligatoria con *Exigir confirmar ubicación*), actualiza la parada, llama a `RegistrarSalida` y recalcula la reserva.
9. Al acabar la última parada, `Pag51121.TerminarOrden` hace `Commit` y lanza
   `Codeunit.Run(Gestion Picking SGA, Orden)`, que es `PasarAPedido`. Si falla, se avisa, pero lo
   confirmado ya está guardado. Se repite con *Pasar al pedido* desde la orden o desde el pedido.

### Asignación: el paso intermedio

```
Enviar a picking ──> Pendiente de asignar ──(responsable asigna)──> Abierta ──> En proceso ──> Finalizada
                 └──> Abierta  (sin "Exigir asignación")
```

- **`Config. SGA."Exigir Asignacion Picking"`** (campo 45) decide si el paso es obligatorio.
- **Estado `Pendiente Asignar`** (ordinal 4 de `Estado Orden SGA`, al final para no mover los
  valores guardados). Lo calcula `Orden Picking SGA.EstadoSinEmpezar()`: pendiente de asignar
  si la configuración lo exige y no hay preparador, abierta en otro caso. Lo usan la creación,
  `RecalcularEstado` y el `OnValidate` de `Cod. Usuario Asignado` (`ValidarAsignacion`).
- **Asignar es validar el campo.** `Cod51104.AsignarOrden` solo hace `Validate` + `Modify`, así
  que teclear el preparador en una línea o usar la acción hace lo mismo. Una orden *En proceso*
  se puede reasignar, pero no dejar sin preparador si se exige asignación. Una finalizada o
  cancelada no se puede asignar.
- **Quién puede preparar**: `Cod51104.ComprobarPreparador`. Lo llaman `TomarParaPreparar` (al
  abrir la preparación) y `ConfirmarLinea` (cada recogida). Con asignación exigida solo pasa el
  asignado. Sin ella, quien abre la orden se la queda, preguntando si era de otro.
- **`TomarSiguienteOrden`**: las del usuario *Abierta* o *En proceso*, la de mayor `Prioridad`
  y, a igual prioridad, la de menor número. Si no tiene y no se exige asignación, toma una sin
  asignar (*Abierta* o *Pendiente de asignar*, por si se desactivó la configuración con órdenes
  en espera). La prioridad se recorre a mano (`BuscarMasPrioritaria`) porque una clave
  descendente invertiría también la antigüedad.
- **La reserva de stock empieza al enviar a picking**, no al asignar. Una orden en espera de
  asignación ya tiene su stock apartado.
- **Pantalla del responsable**: `Pag51124 "Asignar Ordenes Picking SGA"`, con selección
  múltiple, *Asignar a* (página `User Lookup`), *Quitar asignación* y *Subir/Bajar prioridad*.
  La orden guarda el cliente y la fecha de envío del pedido (`Nombre Cliente`, `Fecha Envio`)
  para no tener que abrirlo al repartir.
- **Quién reparte**, en dos capas:
  1. **Casilla `User Setup."Responsable Picking SGA"`** (`Tab-Ext51100`, visible en
     Configuración de usuarios con `Pag-Ext51105`). `Cod51104.ComprobarResponsablePicking()`
     la exige al abrir `Pag51124`, al validar `Cod. Usuario Asignado` y al validar `Prioridad`.
     Solo se comprueba con *Exigir asignación* activo: sin ella el reparto es libre, igual que
     el preparador se asigna solo lo que coge. Es la capa que manda.
  2. **Conjunto de permisos `SGA-Responsable` (51101)**: incluye `PermissionSet-SGA` y
     añade la página de asignación, que ya no está en el general. Sirve para ordenar, pero no
     basta solo: los conjuntos estándar de BC suelen dar ejecución sobre todas las páginas.
- **Extensiones de User Setup propias** (`Tab-Ext51100`, `Pag-Ext51105`) y no las del proyecto
  (`Tab-Ext50110`, `Pag-Ext50054`), para que el módulo siga siendo autocontenido.

### Certificación del hueco: etiqueta y dígito de control

- **`Ubicacion SGA."Digito Control"`** (campo 114, Code[2], 10–99). Lo asigna `GenerarDigitoControl()`
  al crear la ubicación (`OnInsert`, `GenerarUbicaciones`, `SincronizarTopologia`) y, si falta,
  el informe de etiquetas al imprimir. Sale de un GUID y no de `Random`: sin sembrar, `Random`
  repite serie en cada sesión, y sembrado por hora daría el mismo número a una tirada entera.
- **Va fuera del código de barras a propósito.** Si estuviera dentro, bastaría con escanear un
  listado impreso; así solo se sabe estando delante de la etiqueta.
- **`Config. SGA."Exigir Digito Control"`** (campo 46). La comprobación está en el motor,
  `Cod51104.ConfirmarLinea` → `Ubicacion SGA.TestDigitoControl`, no en la página: no se puede
  saltar. Una ubicación sin datos SGA da el mismo error que un dígito incorrecto.
  Se comprueba contra el hueco **real** (el escaneado), así un desvío permitido exige el dígito
  del hueco al que se ha ido.
- **Etiqueta**: `Rep51106 "Etiquetas Ubicaciones SGA"`, layout propio
  `SGA/Otros/Layouts/Rep51106.EtiquetasUbicacionesSGA.rdlc`, página de 7 × 3,5 cm, una
  etiqueta por página (grupo por almacén+ubicación con salto entre grupos). Barras con el
  proveedor estándar `Barcode Font Provider::IDAutomation1D`, simbología Code 128, fuente
  `IDAutomationC128S` en el layout. No usa nada de los informes de etiquetas del proyecto.
- **Pendiente de probar** en la impresora real: que el código de barras de los códigos más
  largos quepa en los 6,7 cm y se lea bien a 12 pt. Si no, bajar el tamaño de la fuente o pasar
  a `IDAutomationC128XS`.

### Decisiones del picking

- **La reserva se recalcula, no se acumula.** `Cantidad Reservada` de un hueco es siempre la
  suma de lo pendiente de sus paradas abiertas. Así se corrige sola tras cancelar, desviarse o
  reconstruir el contenido (`ReconstruirContenido` llama a `RecalcularReservasAlmacen`). Se
  recorta a la cantidad del hueco para que `FijarReserva` no falle si alguien se desvió y cogió
  de un hueco reservado para otra orden.
- **`FijarReserva` borra la línea de contenido** cuando queda a cero de cantidad y de reserva.
  `AplicarDelta` no la borra mientras tenga reserva, así que sin esto quedarían líneas vacías
  tras la última recogida.
- **Las paradas siguen en UM base.** La UM y el factor de la línea del pedido (`UM Documento`,
  `Ctdad. por UM Documento`) solo se usan para enseñar y teclear. Si lo tecleado es el pendiente
  exacto, se toma el pendiente base, para no arrastrar restos de redondeo.
- **El paso al pedido es idempotente.** Suma lo recogido en todas las órdenes del pedido y
  descuenta lo ya enviado, leído de los movimientos de producto de los albaranes. Repetirlo no
  duplica nada. Las líneas de producto sin recoger quedan con `Qty. to Ship` = 0.
- **Seguimiento solo en productos con lotes estándar.** Si el producto no tiene código de
  seguimiento con *Seguim. específico lote* (`Cod51103.LoteEstandar`), el paso al pedido solo pone
  `Qty. to Ship`: BC no espera lotes en esa línea, y el lote del hueco (por ejemplo, el propio del
  ensamblado) es solo de SGA. Al poner el código de seguimiento a un producto, el seguimiento
  empieza a escribirse sin más cambios.
- **Solo se toca el seguimiento Surplus/Prospect con lote.** Si la línea tiene una reserva
  (`Reservation Status` = Reservation) contra un lote, se para con error: deshacerla es una
  decisión de oficina. El signo de la cantidad lo pone BC (`Create Reserv. Entry.SignFactor`).
- **Permisos**: `PermissionSet-SGA` incluye `Sales Line` = RM y `Reservation Entry` = RIMD,
  porque el preparador dispara el paso al pedido al terminar.

**Pendiente de probar en sandbox**:
1. Registrar el envío de un pedido pasado desde picking con producto con lote: que BC acepte el
   seguimiento creado y que el lote del movimiento de producto sea el recogido.
2. Una línea en cajas con factor ≠ 1: cantidad a enviar y seguimiento cuadran (redondeos).
3. Almacén con *Require Shipment*: `Validate("Qty. to Ship")` falla ahí por diseño de BC. Si el
   almacén lo tiene activo, el paso al pedido no sirve tal cual.
4. Envío parcial y nueva orden del mismo pedido: solo se manda a recoger lo que falta.

---

## Entradas: ubicar lo recibido y lo producido

```
SGA/Tables/LineaUbicacionSGA.Table.al        las filas, líneas de Tab51114 con Origen Compra o Produccion
SGA/Codeunits/GestionEntradasSGA.Codeunit.al    carga, propone y confirma; prepara el palé de tarea,
                                                saca y anota su etiqueta y lo ubica
SGA/Pages/UbicarEntradasSGA.Page.al         la pantalla, la misma para los dos orígenes
SGA/Pages/UbicarPaletsLineaSGA.Page.al      imprimir la etiqueta de un palé de la línea y ubicarlo
```

### Las filas: Tab51114 con Origen Compra o Produccion

Cada fila es una línea de `Linea Ubicacion SGA` (la misma tabla temporal del reparto y de la carga
inicial). Usa los campos comunes (producto, variante, lote, unidad, almacén, ubicación propuesta y
confirmada, `Motivo`) y los propios de las entradas: `No. Documento`, `Documento Relacionado`,
`Descripcion Origen` (*Procedencia*), `Fecha Registro`, `Cantidad Entrada` y `Cantidad Ya Ubicada`.
`Cantidad` es lo que se va a ubicar ahora (*A ubicar*, por defecto `Pendiente()`).
`Estado` es Ubicado cuando ya no queda nada y Pendiente si no; en las entradas no se usa
"Sin Sitio": sin hueco la fila sigue Pendiente, con el motivo. La casilla *Ubicado* de la
pantalla es una variable de página calculada con `Estado`. `EstiloEstado` pinta verde lo
ubicado, rojo lo "Sin Sitio", destacado lo que no tiene hueco propuesto y normal el resto.

- **Clave y orden.** La clave primaria es `Linea`, que numera `Cod51105` al cargar. La clave
  `Documento` (Origen, documento, producto, variante, lote, UM) da el orden de la pantalla:
  `CargarEntradas` la fija después de vaciar la tabla, porque el `Reset` quita el
  `SourceTableView` de la página. `CargarRecepciones` busca la fila del movimiento por esa clave
  en una copia (`Copy(..., true)`), para no dejar filtros en la lista, y asegura así que no hay dos
  filas con el mismo documento, producto, variante, lote y UM. `ProponerParaTodos` y
  `ConfirmarTodas` recorren por ella porque no cambia dentro del bucle.
- **Ubicación confirmada.** El campo tiene `TableRelation` a `Bin` salvo en las líneas de
  entradas (`Origen` Compra o Produccion): en *Ubicar producto* da la búsqueda de huecos y la
  validación estándar de la relación. En *Ubicar entradas* e *Imprimir y ubicar palés* no hay
  búsqueda: el hueco se escanea o se teclea. El `OnValidate` del campo en la tabla llama a
  `Cod51101.ComprobarUbicacionExiste`, que no mira nada si la línea no tiene almacén. Su mensaje de
  SGA solo se ve en *Ubicar entradas* e *Imprimir y ubicar palés*: en *Ubicar producto* BC comprueba
  antes la relación con `Bin` y, si el hueco no existe, da su error estándar.
- **Traslado ABC.** `Traslado Origen`, `Traslado Destino` y `Aceptar Traslado` llevan la
  propuesta de `ProponerReubicacionABC`. `ProponerParaTodos` la pide antes de buscar el hueco de
  la fila y excluye sus dos huecos para esa fila y las siguientes (`ExclusionesTraslado`, también
  en `ExclusionesDeOtrasFilas`), así que la entrada nunca se propone en el hueco del palé A.
  `ConfirmarFila` hace el traslado aceptado (`HacerTrasladoABC`, con `RegistrarTraslado` del palé
  entero) antes de `RegistrarEntrada`: si falla, el error deshace las dos cosas. La pantalla solo
  enseña las tres columnas con la opción activada.

### Por qué no se engancha al registro de BC

Lo directo sería suscribirse al registro de compras y llamar a `RegistrarEntrada`. No se hace:
las validaciones de `Cod51100` lanzan error, y dentro del registro un hueco lleno **haría fallar
el albarán**. Además, al registrar todavía no se sabe en qué hueco se va a dejar la mercancía.
BC registra como siempre y SGA va detrás: pendiente = lo registrado − lo que ya está en el diario.

### De dónde sale cada origen

| Origen | Fuente | Una fila por |
|---|---|---|
| `Produccion` | `Posted Assembly Header` de tipo Embotellado | ensamblado + lote |
| `Compra` | `Item Ledger Entry` de tipo Purchase / Purchase Receipt | albarán + producto + variante + lote + UM |

**El lote de un ensamblado** lo da `LotesEnsamblado`, el único sitio que lo decide, y lo decide el
producto (`Cod51103.LoteEstandar`), no si un campo está relleno:
- **Con lotes estándar**, del seguimiento de BC: los movimientos de producto *Salida ensamblado*
  del registrado o, si aún no está registrado, el seguimiento del pedido de ensamblado
  (`Reservation Entry` de `Assembly Header`). Puede haber varios lotes (una fila por cada uno) o
  ninguno si aún no se ha puesto. Con `CargarEntradasLote` los ensamblados del lote se buscan en los
  movimientos de producto (`EnsambladosDelLote`), porque el lote no está en la cabecera.
- **Sin ellos**, el campo propio `Lote` de la cabecera, con toda la cantidad. Es el campo que se
  deja de usar en cuanto el producto pasa a lotes estándar.

Las compras se leen del movimiento de producto y no de la línea del albarán porque **el lote
solo está en el movimiento**. La cantidad se pasa a la UM del albarán (`Quantity / Qty. per
Unit of Measure`). Deshacer una recepción deja un movimiento negativo en el mismo albarán, y al
sumar por documento se descuenta solo.

Lo ya ubicado se lee del diario filtrando por `Origen`, `No. Documento Origen`, producto,
variante, lote y UM. Por eso `ConfirmarFila` pasa siempre el nº de documento a `RegistrarEntrada`.

### Cómo llega el origen a la página

La página no tiene selector: el origen lo fija quien la abre, llamando a `FijarOrigen` (o a
`Preparar`, desde *Pendiente de ubicar*) antes de abrirla. Un `RunPageView` sobre `Origen` **no
sirve**: probado en sandbox, la página (temporal) se abría siempre en ensamblados. Como un rol
center no admite código en sus acciones, cada entrada de menú es un `RunObject` a un codeunit
que solo abre la página en su origen: `Cod51109 "Abrir Ubicar Recepciones SGA"` y
`Cod51110 "Abrir Ubicar Ensamblados SGA"`, los dos con `Cod51105.AbrirUbicarEntradas`. Están en
el rol center, en `Pag-Ext51103` y en *Pendiente de ubicar*. Sin origen, se abre en ensamblados
(el buscador). En `OnOpenPage` todavía se lee un filtro sobre `Origen`, por si alguien la abre
con `SetTableView`.

La estrategia también depende del origen: `Estrategia Ubic. Compras` (campo 35 de la
configuración, por defecto Estándar) y `Estrategia Ubic. Ensamblados` (por defecto Solo hueco vacío).

### Palés ubicados al imprimir la etiqueta (Pag51127)

Copia de `Pag50250` (*Impresión Etiquetas Producción*) en la que imprimir y ubicar son un solo
paso. `Pag50250` no se toca.

La página solo captura la tarea y la ubicación y enseña la situación del palé (texto y estilo).
El trabajo es de `Cod51105 Gestion Entradas SGA`, dueño del palé de tarea:
- `PrepararPaleTarea(Tarea, var Fila, var Aviso)`: el siguiente palé y su hueco.
- `ImprimirYUbicarPale(var Tarea, var Pale)`: comprueba la etiqueta (`ComprobarEtiqueta`), la
  saca (`EnviarEtiqueta` a BarTender o `ImprimirEtiquetaA5` en Sandbox), hace `Commit` y llama a
  `ConfirmarFila`. Hace `Commit`, así que no se llama dentro de un registro ni desde una
  TryFunction. Antes de llamar, la página comprueba que hay palé, que la ubicación no está en
  blanco y que existe (`Cod51101.ComprobarUbicacionExiste`), y guarda la ubicación y la cantidad
  para el texto de *Último palé* (al ubicar, la fila pasa a llevar lo pendiente). Después relee
  la tarea.
- `AnotarEtiquetaImpresa` (local): con la etiqueta ya contada, hora de la primera y, con la
  última, hora y tarea *Finalizado*. BarTender suma la etiqueta y la anota antes de subir el
  fichero; en A5 la suma el report y solo se anota.
- `AjustarEtiquetasImpresas(var Tarea)`: la acción *Ajustar impr. etiquetas* (después de su
  Confirm en la página). Iguala impresas con totales y pone *Finalizado*, sin tocar horas.

- **A qué entrada se apunta el palé.** `PrepararPaleTarea` busca el `Assembly Header` con
  `Linked Tarea` = la tarea y registra con su nº de pedido. Si ya está registrado, usa el
  `Posted Assembly Header` con la misma tarea y su `Order No.`. Sin ensamblado enlazado no se
  ubica: no habría con qué cuadrarlo después.
- **Lote del palé.** El de `LotesEnsamblado`: si el ensamblado tiene un solo lote, ese; si tiene
  varios, el de la tarea (el que lleva la etiqueta). Si no tiene ninguno, o ninguno es el de la
  tarea, no se ubica y el aviso lo dice: con lotes estándar, hay que ponerlo antes en las líneas
  de seguimiento del ensamblado.
- **Cómo no se ubica dos veces.** La fila lleva `Documento Relacionado`. En
  `CargarEnsamblados` es el `Order No.` del registrado, y `CalcularPendiente` suma lo ubicado con
  los dos números. Por eso *Ubicar ensamblados* da por colocados los palés de la línea.
- **Un palé** es una unidad de `Cod. Pale Defecto`, completa salvo la última de la tarea (ver
  *Palé completo o incompleto en las etiquetas*). El completo se registra en la UM de palé y el
  incompleto en cajas o unidades. Nunca se ubica más de lo que falta del ensamblado. Si al
  registrar se baja la cantidad a la producción real, lo de más queda ubicado y la conciliación
  lo enseña como *SobraEnSGA*.
- **Orden de los pasos.** Primero se comprueba todo lo que puede impedir ubicar, luego sale la
  etiqueta, luego `Commit` y al final `ConfirmarFila`. Si la ubicación falla después de imprimir,
  la etiqueta queda contada y el palé pendiente: se ubica desde *Ubicar ensamblados*.
- **Respecto a `Pag50250`:** la etiqueta se monta en un solo procedimiento (estaba repetido para
  *Todo el día*, y esa rama escribía en un `OutStream` sin abrir). De `Barras128` solo queda lo
  que llega a la etiqueta, que es el código del palé. No se deja imprimir más etiquetas que las
  planificadas (comparaba con `>`).
- **Sandbox: etiqueta A5.** En Sandbox no se sube nada al FTP de BarTender, que es el de
  producción. Se lanza `Rep50237` sin request page (directo a la impresora de *Selección de
  impresoras*, Universal Print), con `Commit` antes porque un report no se abre con transacción
  viva. El report suma la impresa solo si no es vista previa. Si el contador no sube, se da error
  y no se ubica. `AnotarEtiquetaImpresa` completa lo que el report no hace: horas y estado *Finalizado*. Cada
  A5 consume un SSCC de la serie de *Inventory Setup*. Por ahora la A5 es solo para Sandbox:
  pasarla a producción es cambiar la condición de `ImprimirYUbicarPale`.

### Decisiones y puntos abiertos

- **`Ubic. Recepcion Compras` no se usa.** Para usarla habría que meter la mercancía en el
  muelle al registrar el albarán, que es justo el enganche al registro que se ha descartado.
  Las recepciones van directas del albarán a su hueco. El campo queda en la configuración por
  si más adelante se quiere un flujo con muelle intermedio, y entonces la ubicación sería un
  `RegistrarTraslado` desde el muelle.
- **Se leen los albaranes de compra estándar** (`Entry Type` Purchase + `Document Type`
  Purchase Receipt), que es como se recibe en real (confirmado el 2026-10-28). SGA no depende
  de ninguna personalización de almacén del proyecto: solo de documentos estándar de BC.
- **Deshacer una recepción ya ubicada no saca la mercancía del hueco.** Se descuenta de lo
  pendiente, pero el contenido se corrige a mano con un recuento. La conciliación lo detecta
  como *SobraEnSGA*.
- **En el buscador sale como "Ubicar entradas"** y se abre en ensamblados: el buscador abre la
  página sin origen.

**Pendiente de probar en sandbox**, porque el compilador no lo comprueba:
1. Que cada entrada de menú (Cod51109 / Cod51110) abra el origen correcto.
2. Que una recepción deshecha del todo desaparezca de la lista, y que una deshecha en parte
   enseñe la cantidad neta.
3. Que una recepción en un palé de cualquier código (PALE200, EUROPALE…) proponga huecos de palé
   y que la confirmación no choque con `TestUMAdmitida` (el código debe ser el *Cód. palé por defecto* del producto).
4. Pag51127: que `Linked Tarea` pase al `Posted Assembly Header` al registrar. Si no pasa, los
   palés ubicados después de registrar no encuentran su ensamblado. Probar también que un
   ensamblado con palés ya ubicados desde la línea salga en *Ubicar ensamblados* solo con lo
   que falta.

---

## El mapa 3D: control add-in

Business Central no tiene ningún control nativo capaz de dibujar volumen, así que el mapa 3D
es un **control add-in**: un lienzo HTML dentro de la página, con el render en JavaScript.

```
SGA/ControlAddIns/Mapa3DSGA.ControlAddIn.al   declaración del control (procedures y events)
SGA/Otros/Add-in/Startup.js               monta el lienzo, estira el iframe hasta el fondo de la ventana y avisa a AL de que está listo
SGA/Otros/Add-in/Mapa3DSGA.js             el render sobre canvas 2D: vista 3D isométrica, planta y frente
SGA/Otros/Add-in/Mapa3DSGA.css            estilos de la barra y del lienzo
SGA/Pages/Mapa3DAlmacenSGA.Page.al    la página que lo aloja y le pasa los datos
```

**Sin librerías externas, a propósito.** La política de contenido del cliente de BC bloquea
los scripts de fuera: cargar Three.js desde un CDN dejaría el panel en blanco sin dar ningún
error visible. Por eso la proyección isométrica está escrita a mano sobre `canvas` 2D.

**Las rutas de los recursos van desde la raíz del proyecto** (donde está `app.json`), no desde
el `.al` que declara el control. De ahí el `./SGA/Otros/Add-in/...`. Mover el `.al` no las
afecta, pero mover los `.js` o el `.css` obliga a actualizarlas: el compilador no avisa de que
apuntan a un sitio donde ya no hay nada, y el panel sale en blanco en ejecución.

### El diálogo entre AL y el lienzo

```
        AL                                   JavaScript
        │                                        │
        │                    ControlListo()      │  el lienzo ya está montado:
        │ <───────────────────────────────────── │  antes no había dónde pintar
        │                                        │
        │  Dibujar(json)                         │
        │ ─────────────────────────────────────> │  proyecta y pinta los cubos
        │                                        │
        │                 CeldaPulsada(codBin)   │  clic en un bloque
        │ <───────────────────────────────────── │
        │  abre Contenido Ubicaciones SGA        │
        │                                        │
        │      TrasladoSolicitado(origen, dest.) │  arrastrar un bloque con
        │ <───────────────────────────────────── │  contenido y soltarlo en otro
        │  elige línea, diálogo Mover Contenido, │
        │  RegistrarTraslado                     │
        │  Actualizar(json)                      │
        │ ─────────────────────────────────────> │  repinta sin tocar giro/zoom/pasillo
```

**Vaciar desde el mapa**: clic derecho (`contextmenu`) sobre un cubo con `l` > 0 → evento
`VaciarSolicitado(codBin)` → `Pag51122.Vaciar` enseña el contenido, confirma y llama a
`Cod51100.VaciarUbicacion`, que comparten la ficha de la ubicación y el mapa. *Quitar de la
ubicación* en *Contenido de ubicaciones* usa `Cod51100.DesubicarLineas` con la selección, que es
lo mismo con todo o nada. Sin contenido, el clic derecho no hace nada (y no abre el menú del
navegador).

**Traslado arrastrando**: el lienzo no mueve nada, solo avisa con los dos códigos. Pulsar sobre
un cubo con contenido lo "coge"; pasa a traslado al mover más de `UMBRAL_ARRASTRE` píxeles (con
menos, al soltar es un clic y abre el contenido). Fuera de un cubo, o sobre uno vacío, arrastrar
gira; Alt gira siempre y Mayús desplaza. Esc suelta sin trasladar. Solo deja
empezar desde un cubo con `l` > 0 (líneas de contenido, que manda `DatosMapa3D`; el color no
basta porque *bloqueada* tapa a *llena*). `Pag51122.Trasladar` pide la línea si hay varias
(`Contenido Ubicaciones SGA` en modo lookup) y llama a `Cod51100.TrasladarConDialogo` con el
destino del arrastre y "Traslado desde el mapa 3D" como descripción si no se pone motivo. El
diálogo `Mover Contenido SGA` sale con ese destino (`FijarDestino`) y el operario lo puede
cambiar: el mensaje final lleva el destino que devuelve `TrasladarConDialogo`. Si se cancela no
se repinta. Después llama a `Actualizar`, no a `Dibujar`, porque `Dibujar` reinicia la vista. El
resumen de la cabecera sale de `Cod51101.ResumenUbicaciones` (del almacén o de la zona filtrada).
*Trasladar* y *Bloquear / desbloquear* de *Contenido de ubicaciones* (lista y subpágina) usan los
mismos `TrasladarConDialogo` y `AlternarBloqueo`.

**Zonas**: el filtro *Zona* de la página pasa a `DatosMapa3D`, que solo manda las ubicaciones de
esa zona, y cada ubicación lleva su zona en `z`. El mapa **no traslada entre zonas**: el lienzo
no acepta como destino una ubicación de otra zona (cursor de prohibido y aviso en la barra), y AL
lo comprueba igualmente con `Cod51101.TestMismaZona`, antes del diálogo y en el propio diálogo
(`TrasladarConDialogo` con `prm_MismaZona` → `Mover Contenido SGA.LimitarAMismaZona`), por si el
operario cambia el destino; ahí la zona destino es la del origen y no se puede cambiar. Una
ubicación sin zona solo casa con otra sin zona.

**Traslado entre zonas** (*Contenido de ubicaciones* › *Trasladar*): el diálogo `Mover Contenido
SGA` tiene *Zona destino*. Al elegirla llama a `Cod51101.ProponerEnZona`, que es
`ProponerUbicacionCon` con la estrategia de la configuración, sin la ubicación de origen y con la
global `ZonaDestino` puesta mientras dura: `FiltrarCandidatas` filtra por ella, `MotivoRechazo`
descarta las de otra zona (motivo 3, para la casa del producto y la consolidación, que no pasan
por `FiltrarCandidatas`) y `ExplicarSinHuecoLote` cuenta solo las de la zona y dice "almacén X,
zona Y". La ubicación destino se busca entre las de la zona y `TestUbicacionEnZona` rechaza las
de otra. Si cambia la cantidad y el destino es el propuesto (no elegido a mano), se vuelve a
proponer.

Un traslado viaja en UM base (lo que hay en el hueco). Para no chocar con huecos de palé o de
caja, `TestUMAdmitida` acepta un traslado si el producto **tiene** una unidad de la clase del
destino, aunque la cantidad vaya en base. Esto vale también para *Trasladar* desde
*Contenido de ubicaciones*.

El orden importa: la página **no dibuja en `OnOpenPage`**, sino cuando el lienzo dispara
`ControlListo`. Si mandara los datos antes, llegarían a un canvas que todavía no existe.

### De dónde salen las coordenadas

`Cod51102.DatosMapa3D(Almacen, Zona, Pasillo)` recorre las ubicaciones y trocea su código
`pasillo-estantería-altura` (`TrocearCodigo`) para sacar la posición del bloque. Las ubicaciones
cuyo código no tenga tres partes numéricas de 3, 2 y 2 dígitos **no se dibujan**: no hay forma
de saber dónde colocarlas. Con `Pasillo` distinto de 0 solo manda ese pasillo.

El JSON usa claves cortas (`b`, `d`, `e`, `c`, `a`, `s`, `o`, `m`, `l`, `k`, `pp`, `fc`, `r`) porque viaja entero al
navegador y un almacén son más de mil ubicaciones. La posición va en números: `e` = pasillo,
`c` = estantería, `a` = altura.

### Ocupación en el mapa

- `o` es el *% Ocupacion* guardado, **redondeado hacia abajo**, para que el número no diga 100 %
  de un hueco que aún tiene sitio (el color sale del estado, que mira lo ocupado exacto).
- **Sin medir** (`s` = 4, `o` = -1, `m` = el porqué): con contenido y sin capacidad declarada
  (el *% Ocupacion* de la tabla diría 100 % y el estado *Llena*), o en un hueco de palé o de
  caja con capacidad en el que algún producto no tiene esa unidad en su ficha
  (`UMProductoDeTipo` en blanco): su contenido se contaría en unidades base como palés o cajas.
  `ContenidoParaMapa` mira todas las líneas para eso, no solo las 8 que envía, con lo ya mirado
  de cada producto y clase guardado para todo el mapa. Bloqueada sigue mandando sobre esto.
  Solo cambia lo que enseña el mapa: la tabla y la lista *Ubicaciones SGA* no cambian.
- **Nivel en el cubo**: las caras laterales llevan el color del estado entero, en tono oscuro
  desde abajo hasta `o` (tope 100 %) y en tono claro lo libre (`libreIzq`/`libreDer` de
  `PALETA`); el techo dice el estado. Con
  contenido y `o` = 0 se pinta un mínimo (`NIVEL_MINIMO`) para que no parezca vacío; sin medir
  se pinta entero. En un traslado, origen y destino van enteros en azul y amarillo. Por encima
  de 100 la ficha dice "sobrepasada".
- **Separación entre ubicaciones**: se pinta el sitio entero del cubo en `COLOR_SEPARACION`
  (gris oscuro) y encima el cubo, un `RENDIJA` (8 %) más pequeño. Lo que queda alrededor es una
  línea opaca con sus vecinos y con las alturas de arriba y de abajo; una rendija transparente
  dejaba ver el cubo de detrás y la separación tomaba el color de otra ubicación. Además lleva
  marcados el contorno y las tres aristas de delante (más gruesas con zoom, en azul la que está
  bajo el ratón). Con el cubo diminuto no hay separación ni aristas. La posición y la zona que se
  puede pulsar siguen siendo el sitio entero.

### Contenido y zoom por pasillo

- **El contenido viaja con el mapa** (clave `k`, `Cod51102.ContenidoParaMapa`): producto `p`,
  descripción `t`, lote `l`, caducidad `f`, cantidad `q`, unidad `u`, bloqueado `x`, palé por
  defecto del producto `g` (`Item."Cod. Pale por Defecto"`) y sus unidades `gf`. Solo en
  las ubicaciones con contenido y como mucho 8 líneas por ubicación (`l` dice cuántas hay). Se
  descartó pedirlo a BC al pasar el ratón: una ida y vuelta por bloque haría la ficha lenta. Si
  el JSON pesara demasiado en almacenes muy grandes, el siguiente paso sería mandarlo solo con
  un pasillo aislado.
- **Ficha flotante** (`mostrarFicha`, div `.sga3d-tip`): sigue al ratón, `pointer-events: none`
  para no robar el ratón al lienzo, y se esconde mientras se gira, desplaza o traslada.
- **Encuadre** (`encuadrar`): proyecta a escala 1, mide la caja de los cubos visibles y saca la
  escala que la hace caber (92 % de ancho, 88 % de alto, entre 0,15 y 12). Lo llaman aislar un
  pasillo, *Centrar* y la primera carga; **no** lo llama `refrescar`, para no mover la vista
  tras un traslado.
- **Zoom con la rueda hacia el ratón**: como las posiciones de los cubos son proporcionales a la
  escala alrededor del centro de pantalla, basta con corregir `panX/panY` en
  `(ratón − centro) × (1 − factor)`.
- **Producto sobre el cubo**: a partir de 34 px de ancho de cubo se escribe el primer producto
  (y "+N") en la arista frontal.

### Vistas, color y búsqueda

Las tres vistas usan los mismos datos (`ubicaciones`) y las mismas acciones: ficha flotante,
clic (`CeldaPulsada`), clic derecho (`VaciarSolicitado`) y arrastrar (`TrasladoSolicitado`).
Lo que cambia es cómo se coloca y se busca lo que hay bajo el ratón (`elementoEn`: `cuboEn` en
la 3D, `rectEn` en las planas).

- **3D** (`proyectar3D`, `pintar3D`): la de siempre.
- **Planta** y **frente** (`maquetarPlano`, `pintarPlano`): rectángulos en coordenadas propias
  con su zoom y desplazamiento (`escala2`, `pan2X/pan2Y`), aparte de los de la 3D para que cada
  vista conserve el suyo. Frente: el pasillo elegido, estantería × altura, casillas de
  104 × 74 con código, %, producto y el dato del criterio (`pintarTextosCasilla`, texto con halo
  blanco para leerse sobre cualquier color). Planta: fila por pasillo, columna por estantería,
  la estantería partida en una franja por altura. Rótulos: "Pas. 101" para cada pasillo y
  "Est. 05" para cada estantería en el frente. Doble clic en la planta abre el frente; *Todos* en el
  frente vuelve a la planta. En las planas, arrastrar fuera de una ubicación desplaza.
- **Colorear por** (`CRITERIOS`, `colorDe`): estado (`PALETA`, la de siempre, más
  *sobrepasada*, `PALETA[5]`, que no manda AL: la decide `colorDe` con `o` > 100 salvo bloqueada
  o sin medir), rotación ABC (`r`) o caducidad (`fc` contra hoy: caducado, ≤30, ≤90, >90). No
  hay criterio de ocupación aparte: se confundía con el estado, y cuánto está lleno ya lo dice
  el relleno de cada ubicación. Los tonos (techo, laterales, libre) salen de un color base (`paleta`). Con
  contenido y sin el dato, `COLOR_SIN_DATO`.
- **Buscar** (`coincide`): código de ubicación, productos de todas las líneas (`pp`) o
  descripción de las líneas enviadas (`k`). Lo que no coincide se pinta al 18 % de opacidad y lo
  que sí, con borde naranja.

`refrescar` (tras un traslado o un vaciado) conserva vista, giro, zoom, pasillo, color y
búsqueda. Como la página filtra los datos por el pasillo que se mira (evento
`PasilloSeleccionado(Pasillo: Text)`), `refrescar` cambia solo los pasillos que llegan y deja
los demás: así el selector y **<** **>** siguen llevando a
todos.

Los datos para colorear y buscar los añade `Cod51102.DatosMapa3D` de todas las líneas de cada
ubicación con contenido: `pp` (productos sin repetir), `fc` (caducidad más próxima) y `r` (mejor
clase de sus productos según `Cod51107.ClasesUltimoCalculo`, el último cálculo ABC del almacén,
leído una vez para todo el mapa).

---

## Unidad de medida por ubicación

**Palé, caja y unidad son clases, no códigos.** La clase de cada unidad (enum 51109) sale de la
ficha del producto, sin configurar nada en *Unidades de medida*. Cada ubicación declara la
clase que admite, no un código:

```
Ubicacion SGA."Tipo UM Admitida"  Palé / Caja / Unidad / en blanco = sin configurar   (campo 113)
Ubicacion SGA."Capacidad Uds."    cuántos caben, EN ESA CLASE: 1 palé, 72 cajas
Ubicacion SGA."Permite Mezcla Producto"   solo si admite Caja o Unidad
Config. SGA."Tipo Ubic. Nuevas"        clase con la que nacen al generar (Palé)
```

Así un hueco de palé admite PALE, PALE200, EUROPALE… sin listarlos en ningún sitio.

### De dónde sale la clase

`TipoUMProducto(producto, UM)`, de `Cod51108 "Unidades Producto SGA"`, es la que usan todos los
procesos (propuesta, `UMAdmitida`, `UMProductoDeTipo`, `ExplicarSinHuecoLote`). Mira solo la ficha y las `Item Unit of Measure` del
producto: factor ≤ 1 → Unidad; el `Cod. Pale por Defecto`, o cualquier UM con factor ≥ el suyo →
Palé; la `Sales Unit of Measure` → Caja; cualquier otra → sin clase (no se propone hueco).
`UMProductoDeTipo` devuelve la UM de cada clase con la misma regla: palé por defecto, unidad de
venta o unidad base.

No hay ninguna configuración por código de unidad: la ficha del producto es la única fuente.

### Qué se propone y qué se admite

Son dos reglas distintas, a propósito. El porqué de cada regla y su historial están en
[ESTRATEGIAS_UBICACION.md](ESTRATEGIAS_UBICACION.md); aquí solo dónde vive en el código:

- **Propuesta** (`UbicacionAdmite` → `TipoHuecoDestino` de `Unidades Producto SGA`): un solo tipo
  de hueco por cantidad. Palé → Palé; Unidad → Unidad; Caja → Caja si son menos de *Cajas Minimas
  Hueco Pale* (10), Palé si son esas o más (palé incompleto de una referencia). Esas cajas o más
  de un producto sin palé no tienen hueco: sin su tamaño no se puede medir cuánto ocupan en uno
  de palé, y `ExplicarSinHuecoLote` pide completar la ficha. Los huecos con
  *Admite* en blanco no se proponen nunca, tampoco en la carga inicial (`ProponerHuecoPaleRuta`). Solo
  se proponen huecos de Picking o Reserva (`Ubicacion SGA.FiltrarDeAlmacenaje`).
- **Validación al registrar** (`UMAdmitida`, desde `TestUMAdmitida`): más amplia, para que el
  operario pueda dejarlo en otro hueco que también sirva. Palé acepta palés y cajas (una sola
  referencia, porque los de palé no aceptan mezcla); Caja solo cajas; Unidad solo unidades; en
  blanco todo menos unidades. Las unidades sueltas solo entran en huecos de Unidad. A un hueco
  de Unidad no entra un palé entero: si la cantidad base del movimiento llega al palé de la ficha
  (`UMProductoDeTipo` Palé), error, también en traslados y con la cantidad en unidad base, que
  `UMAdmitida` no detecta. La capacidad (`TestUbicacionAdmite`) se controla siempre: avisa (y se
  confirma) solo si `Ubicacion SGA.SoloAvisaCapacidad`, que mira el *Control capacidad* propio de
  la ubicación (campo 74, enum 51112: *Según configuración* / *Avisar* / *Bloquear*) y, con
  *Según configuración*, el de `Config. SGA`; si no, bloquea. La carga inicial no pasa por aquí.
- **Una sola regla para proponer y para explicar**: `MotivoRechazo` devuelve por qué un hueco no sirve (bloqueado, reservado a otro producto, otra clase o sin configurar, sin sitio, otro producto, otro lote). La clase de hueco (`TipoHuecoDestino`) y lo que ocupa la cantidad en ella (`EntradaEnClase`) los calcula una vez quien llama (`ProponerUbicacionCon`, `ExplicarSinHuecoLote`) y se los pasa: no dependen del hueco. `BuscarLibre` y `BuscarVacia` filtran ya por esa clase (`FiltrarCandidatas`). La capacidad la mira `Ubicacion SGA.CabeEntrada`, que parte del estado y del *% Ocupacion* guardados (los deja al día cada movimiento, `RecalcularOcupacion`): *Llena* es "sin sitio", y si no, lo ocupado sale del %; solo cuando el resultado queda a menos del redondeo del % de la capacidad suma el contenido (`OcupadoEnUMHueco`). Una ubicación *Vacía* no consulta su contenido para la mezcla. Si no, la mezcla la mira `Ubicacion SGA.ContenidoQueImpideMezcla` (la variante sin contenido, que solo mira si existe una línea que choca). Así recorrer muchos huecos no suma el contenido de cada uno; el registro (`Cod51100.TestUbicacionAdmite`) sí cuenta siempre el contenido. `UbicacionAdmite` es "motivo = 0", y `ExplicarSinHuecoLote` cuenta los huecos de la clase destino por motivo y lo dice en el mensaje ("No queda espacio en ubicaciones de Palé…: 40 de 42 sin sitio…"). `ProponerUbicacionCon` devuelve ya ese motivo cuando no hay hueco, calculado con el lote. La primera frase del motivo es siempre la causa. Lo usan *Ubicar producto*, *Ubicar entradas*, *Imprimir y ubicar palés* y la carga inicial.
- **Solo con la ubicación vacía**: los campos de configuración de `Ubicacion SGA` (40, 50, 60, 70-74, 90, 91, 100, 110, 111, 113) llaman a `TestVacia` en su `OnValidate`. La ficha los pone `Editable = EsVacia` y `Cambiar ubicaciones en bloque` se salta las que tienen contenido (`UbicacionesOmitidas`). *Bloqueada*, *Motivo bloqueo* y *Descripción* quedan libres. *Generar* y *Sincronizar* solo rellenan ubicaciones nuevas, que están vacías.

### Palé completo o incompleto en las etiquetas

`PrepararPaleTarea` lo decide con la tarea: la etiqueta n (n = impresas + 1) es completa si a
`NumBotellas` le queda al menos un palé tras las n-1 anteriores; si no, es el último, con lo que
quede. Nunca más de lo pendiente del ensamblado. Lo que lleva la etiqueta se reparte con
`Repartir` de Cod51108 y el palé de la tarea, y se ubica el primer trozo: el completo, en la UM de
palé; el incompleto, en la unidad de venta si es más pequeña que el palé de la tarea (las botellas
que no llegan a una caja quedan pendientes y se avisa) o, si no llega a una caja, en la unidad
base. La fila se pasa entera a esa UM.

Como un ensamblado puede quedar ubicado en varias UM (palé, cajas…), `CantidadYaUbicada` en
**producción** suma en unidad base todas las UM y lo devuelve en la de la fila; así *Ubicar
ensamblados* no vuelve a pedir lo ubicado con las etiquetas. En **compras** sigue filtrando por UM,
porque un albarán puede traer el mismo lote en cajas y en palés en filas distintas.

### Las funciones de clase (`Unidades Producto SGA`)

| Función | Qué hace | Quién la usa |
|---|---|---|
| `TipoUMProducto(producto, UM)` | Clase de una UM para ese producto: Palé, Caja, Unidad o en blanco (sin clase, o UM que el producto no tiene) | las demás |
| `UMAdmitida(producto, tipo, UM)` | ¿El hueco de esa clase admite esa UM? En blanco = cualquiera menos unidades; UM en blanco = base del producto | `Cod51100.TestUMAdmitida` |
| `TipoHuecoDestino(producto, UM, cantidad)` | Clase de hueco que se propone: el palé a Palé, las unidades a Unidad, las cajas a Caja o a Palé según *Cajas Minimas Hueco Pale* | `Cod51101.ProponerUbicacionCon`, `Cod51101.ExplicarSinHuecoLote` |
| `UMProductoDeTipo(producto, tipo)` | La UM del producto de esa clase: palé por defecto, unidad de venta o unidad base, si es de esa clase; si no, en blanco. Es también la UM en la que se mide "1" de capacidad de un hueco de esa clase para ese producto | `Cod51100.TestUMAdmitida`, `CantidadEnClase`, carga inicial, ABC, `Repartir` y `Desglose` |
| `CantidadEnClase(producto, tipo, cantidadBase)` | Una cantidad base contada en esa clase (palés, cajas) con la UM de `UMProductoDeTipo`; sin clase, en unidades base. Sin redondear | `Ubicacion SGA.EnUMHueco` (capacidad en `Cod51100`), `Cod51101.EntradaEnClase` (propuesta) |
| `FactorClase(producto, tipo)` | Unidades base de la UM de esa clase del producto (`FactorUM(UMProductoDeTipo)`); 1 si no la tiene. Nunca cero | `CantidadEnClase`, `Ubicacion SGA.OcupadoEnUMHueco` (una vez por producto) |

### Dónde se valida, y por qué ahí

La comprobación de la UM está en `Cod51100.AplicarMovimiento`, **no** en
`TestUbicacionAdmite`. El motivo es que `AplicarDelta` recibe siempre la **UM base del
producto** (`umBase := rItem."Base Unit of Measure"`), no la que usa el operario. Validar ahí
compararía contra la unidad equivocada: una ubicación de palés rechazaría un palé de un
producto cuya base fuera la caja.

### La ocupación se cuenta en la clase del hueco

El contenido se acumula en UM base, pero la capacidad está en palés o cajas, y en un mismo hueco
pueden convivir palés de 200 y de 300, o cajas de 6 y de 12. Por eso no se pasa la capacidad a
base: se pasa **lo que hay** a la clase del hueco, línea a línea, con el palé o la caja de su
producto (`Ubicacion SGA.OcupadoEnUMHueco`). Lo que entra se convierte igual con el de su
producto:

```al
ocupado := rUbicacion.OcupadoEnUMHueco();                  // Σ EnUMHueco(producto de cada línea, su cantidad base)
entrada := rUbicacion.EnUMHueco(producto, cantidadBase);   // CantidadEnClase: cantidadBase / FactorUM(UMProductoDeTipo(producto, tipo))
if ocupado + entrada > "Capacidad Uds." then ...           // Cod51100 (registro) y Cod51101 (propuesta)
```

`EnUMHueco` y `CantidadEnClase` no redondean: el registro (`Cod51100`) redondea la entrada a
0,00001 y la propuesta no. La propuesta calcula la entrada una vez (`EntradaEnClase`), porque
todos los huecos que mira son de la misma clase.
`RecalcularOcupacion` (% y estado) usa el mismo cálculo, así que el % se mide en la clase del
hueco y no en unidades base.

Que un hueco de palé admita **cualquier** palé, y no solo el de un producto, es lo que permite
a la carga inicial recorrer los huecos libres con un cursor que solo avanza.

---

## Análisis ABC (solo observa)

```
SGA/Enums/ClaseABCSGA.Enum.al                 A / B / C
SGA/Tables/CalculoABCSGA.Table.al               cabecera de cada cálculo: parámetros y resumen
SGA/Tables/ClasificacionABCSGA.Table.al         una línea por producto y cálculo
SGA/Codeunits/AnalisisABCSGA.Codeunit.al           el cálculo; OnRun para la cola de proyectos
SGA/Pages/AnalisisABCSGA.Page.al               resumen + clasificación de un cálculo
SGA/Pages/CalculosABCSGA.Page.al               historial de cálculos
```

Es la fase 1 del plan de [ESTRATEGIAS_UBICACION.md](ESTRATEGIAS_UBICACION.md), donde está el
criterio de cálculo. Puntos de diseño:

- **No toca nada.** Lee movimientos de producto (ventas), contenido y ubicaciones, y escribe solo
  en sus dos tablas. No cambia la estrategia de ubicar.
- **Se guarda cada cálculo**, no solo el último: el historial es lo que permitirá, en las fases
  siguientes, exigir que un producto lleve varios cálculos en una clase antes de moverlo.
  Borrar un cálculo borra sus líneas (`OnDelete` de la cabecera).
- **Un palé por producto y hueco**: los huecos son de un palé, así que se cuentan huecos, no
  cantidades. Si algún día hay huecos de varios palés, hay que contar con la UM de palé.
- **Clase de hueco sin guardar**: se calcula en cada ejecución ordenando una copia temporal de
  `Ubicacion SGA` (altura del código × 1.000.000 + secuencia picking). La altura sale de
  `TrocearCodigo` de `Gestion Ubicaciones SGA`, la misma que usa el mapa. Un código sin la forma
  Pasillo-Estantería-Altura (3, 2 y 2 dígitos) cuenta como la peor altura.
- **Ventas por almacén**: filtra `Location Code` del movimiento. Ventas netas: las devoluciones
  restan.
- **Productos sin unidad de palé**: no se pueden pasar a palés; quedan C y se avisan en el resumen.
- **La página solo enseña.** `Calculo ABC SGA` da el último cálculo de un almacén
  (`UltimoDelAlmacen`) y los textos del resumen (`TextosResumen`); `Clasificacion ABC SGA`, el
  estilo de cada columna (`EstiloClaseABC`, `EstiloClaseAnterior`, `EstiloHuecoSuClase`,
  `EstiloUnidadPale`).

---

## ID ranges y futuro

```
EN USO:
51100-51112: Enums           (51110 clase ABC, 51111 estado de preparación del pedido, 51112 control de capacidad de la ubicación)
51100-51114: Tables          (51107 stock por lote: conciliación y pendiente de ubicar, 51108-51109 órdenes de picking, 51110-51111 libres, 51112-51113 análisis ABC, 51114 línea de ubicación: reparto, carga inicial y entradas)
51100-51112: Codeunits       (51104 picking, 51105 entradas, 51106 carga inicial, 51107 análisis ABC, 51108 unidades del producto, 51109-51110 abrir Ubicar recepciones / Ubicar ensamblados desde los menús, 51111 ventana de progreso, 51112 eliminar una ubicación)
51100-51131: Pages           (51116 libre; 51127 imprimir y ubicar palés; 51128-51129 análisis ABC; 51130 reparto de Ubicar producto; 51131 pendiente de ubicar)
51100-51107: Reports         (51104-51105 libres, 51106 etiquetas de ubicación, 51107 inicializar contenido)
51100-51108: Page Extensions (51105 Configuración de usuarios, 51106 libre, 51107 líneas del pedido de venta, 51108 lista de pedidos de venta)
51100-51102: Table Extensions (51100 User Setup, 51101 libre, 51102 Sales Line)
51100-51101: Permission Sets (general y responsable)
51100:       Control Add-in

LIBRES:
Tables 51110-51111, 51115+ · Codeunits 51112+ · Pages 51116 y 51132+
Enums 51113+ · Reports 51104-51105 y 51108+ · Page Extensions 51109+ · Table Extensions 51103+
Permission Sets 51102+

RESERVADO PARA FASE 3 (PDA):
(pendiente de definir)
```

---

## Performance: consideraciones

- **Lookup de Contenido**: PK es (Almacen, Ubicacion, Producto, Variante, Lote, UM, Caducidad). Es larga pero especificidad es buena.
- **Índice de Movimientos**: el diario tiene índice en `Fecha Hora Registro` para que los factbox sean rápidos.
- **Ocupación persistida**: permite filtros rápidos en "muéstrame solo parciales" sin escanear todas las líneas de contenido.
- **BufferMapa**: temporal, se rellena una sola vez al abrir la página.

Si tienes 10.000+ ubicaciones, es posible que necesites índices adicionales. Avisa si lo detectas.

---

## Testing: cómo verificar que anda

Sin un framework de testing integrado, prueba así:
1. Abre *Configuración SGA* > rellena datos mínimos.
2. Abre *Zonas SGA* > crea una zona.
3. Abre *Generar ubicaciones* > crea 10 ubicaciones.
4. Abre *Sincronizar* > da de alta en SGA.
5. Abre *Carga inicial* en modo simulación > verifica qué va dónde.
6. Abre *Carga inicial* en serio > ejecuta.
7. Abre *Ubicaciones SGA* > comprueba que el contenido es correcto.
8. Abre *Conciliar* > verifica que BC y SGA coinciden.
9. Abre *¿Dónde está el producto?* > busca un producto y verifica que te dice dónde está.
10. Abre *Mapa* > mira si la vista coincide con la realidad.

Si todo esto funciona, el módulo está vivo.

