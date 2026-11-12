# Documentación técnica de SGA

Para el programador que llega nuevo: cómo está montado SGA, por qué, y qué decisiones de almacén
hay detrás. Lo que hace cada procedimiento está en sus comentarios `///`; aquí va lo que no se
deduce leyendo el código. Para usarlo, la [guía de uso](GUIA_USO_SGA.md); para configurarlo, el
[manual de implantación](MANUAL_IMPLANTACION_SGA.md).

## Índice

- [Parte I. Arquitectura](#parte-i-arquitectura)
  1. [Qué es y dónde está cada cosa](#1-qué-es-y-dónde-está-cada-cosa)
  2. [Modelo de datos](#2-modelo-de-datos)
  3. [Las reglas que sostienen el diseño](#3-las-reglas-que-sostienen-el-diseño)
  4. [Flujos](#4-flujos)
  5. [Problemas conocidos y pendientes de probar](#5-problemas-conocidos-y-pendientes-de-probar)
  6. [Rangos de IDs](#6-rangos-de-ids)
- [Parte II. Decisiones de almacén](#parte-ii-decisiones-de-almacén)
  - [Dónde se ubica](#dónde-se-ubica)
  - [De dónde se recoge](#de-dónde-se-recoge)
  - [Cómo se repone el picking](#cómo-se-repone-el-picking)
  - [Alternativas valoradas](#alternativas-valoradas)
  - [Plan ABC por fases](#plan-abc-por-fases)
  - [Puntos abiertos](#puntos-abiertos)
  - [Estudios en que se apoyan](#estudios-en-que-se-apoyan)

---

# Parte I. Arquitectura

## 1. Qué es y dónde está cada cosa

SGA reparte el stock de BC entre ubicaciones físicas (huecos de estantería), por producto,
variante y lote. **No es un stock paralelo**: la cantidad total la siguen gobernando los
movimientos de producto de BC; SGA solo dice dónde está. Encima de eso: propuesta de hueco,
picking de venta, reposición del picking, conciliación con BC, análisis ABC y mapas.

| Carpeta | Contenido |
|---|---|
| `Tables`, `TableExtensions` | Modelo de datos (sección 2) |
| `Codeunits` | Toda la lógica. Las páginas llaman, no calculan |
| `Pages`, `PageExtensions` | Listas, fichas, diálogos, rol center y acciones en producto, pedido de venta, almacén y usuarios |
| `Reports` | Generar y sincronizar ubicaciones, carga inicial, puesta a cero, conciliación y etiquetas |
| `Enums`, `PermissionSets`, `Profiles`, `ControlAddIns` | Lo que su nombre dice; el perfil `ALMACEN SGA` publica el rol center y `PREPARADOR SGA` el de la PDA |
| `Otros` | Lo que no es AL: la documentación, `Add-in/` (JS y CSS del mapa 3D y de la pantalla de picking), `Layouts/` (RDLC de etiquetas) y los scripts `GenerarManualSGA.ps1` y `GenerarMapaLlamadas.ps1` |

**Convenciones** (las de los analizadores de Microsoft, para poder separar SGA como app):

- Namespace `AntonioNadal.SGA` en todos los objetos, con sus `using`.
- Fichero `NombreObjeto.Tipo.al` (`GestionContenidoSGA.Codeunit.al`); el ID va dentro.
- Toda pantalla lleva "SGA" en su `Caption`, para que el usuario distinga lo propio del estándar de BC.
- Etiquetas con sufijo `Err`/`Msg`/`Qst`/`Tok`/`Lbl`/`Txt` y `Comment` en todo `%1`; temporales con prefijo `Temp`; ubicaciones siempre `Code[20]`.
- Se compila con CodeCop, UICop y PerTenantExtensionCop sin avisos. Quedan a propósito dos informativos: AA0232 (índice SIFT que ya existe) y AW0006 (fichas que se abren desde su lista).

**Autocontenido.** Nada de SGA se mezcla con objetos del proyecto: tiene sus propias extensiones de `User Setup`, su rol center y sus permisos. Lo que hoy lo ata al proyecto, y habría que resolver al separarlo, está en las entradas de producción: `Tareas Produccion` (`AntonioNadal.Produccion`), los campos propios de `Assembly Header` (`Tipo documento`, `Lote`, `Linked Tarea`), `Item."Clase de articulo"`, el report `Etiqueta Producto A5` y la configuración de BarTender. `Item."Cod. Pale por Defecto"`, del que depende la capacidad, también es un campo del proyecto.

**Navegación.** Sin menú propio: el rol center `Rol Center Almacen SGA` (P51112) y el menú SGA del procesador de pedidos (`Order Processor SGA`, PE51103) llevan los mismos grupos en el mismo orden: si se toca uno, se toca el otro.

## 2. Modelo de datos

| Objeto | ID | Para qué | Quién escribe |
|---|---|---|---|
| `Zona SGA` | T51100 | Agrupa ubicaciones de un almacén; tipo por defecto, grupo IIEE, prioridades y bloqueo de la zona entera. Una zona marcada *Playa* (sin tipo) tiene una ubicación por playa; su *Ubicación por defecto* (`PlayaPorDefecto`) es la playa que la PDA indica en las paradas de venta y al terminar la orden. Solo se indica: el stock sale de SGA al recoger, como siempre | El usuario (`Zonas SGA`) |
| `Ubicacion SGA` | T51101 | Compañera 1:1 de `Bin`: tipo, capacidad en palés, mezclas, producto fijo, bloqueo, reserva para una entrada y el estado y % de ocupación persistidos | `Gestion Ubicaciones SGA` (alta, generar, sincronizar, cambio en bloque y borrado, un hueco por transacción con su `OnRun`); `Gestion Contenido SGA` (estado y %); la ficha (configuración, solo vacía) |
| `Contenido Ubicacion SGA` | T51102 | Lo que hay ahora en cada hueco por producto, variante y lote, en UM base, con su reserva de picking | **Solo** `Gestion Contenido SGA` |
| `Movimiento Ubicacion SGA` | T51103 | Diario inmutable de todo lo que entra, sale o se mueve | **Solo** `Gestion Contenido SGA` |
| `Config. SGA` | T51104 | Una sola fila: almacén por defecto, ubicación de ajustes, estrategias, controles, serie de órdenes, parámetros ABC, campo del grupo IIEE | El usuario (`Config. SGA`) |
| `Cue SGA` | T51105 | Pilas de los rol center de almacén (`Cue SGA`, P51111) y del preparador (`Cue Preparador SGA`, P51135), todas FlowField `count` | Solo se crea la fila (`ObtenerCue`); los datos se calculan con los FlowFilter que pone `FiltrarCue` |
| `Buffer Mapa SGA` | T51106 | Temporal: la rejilla del mapa (una fila por pasillo y altura, 32 columnas) | `Gestion Mapa SGA` |
| `Buffer Conciliacion SGA` | T51107 | Stock por lote BC frente a SGA. Real, por usuario, en la conciliación; temporal en *Pendiente de ubicar* y en la carga inicial | `Consulta Stock SGA` |
| `Orden Picking SGA` | T51108 | Cabecera de una orden: de venta (`Origen` Venta) o de reubicaciones (`Origen` Reposicion) | `Gestion Picking SGA` |
| `Linea Orden Picking SGA` | T51109 | Una parada: hueco, producto, lote, cantidad en base. Con `Cod. Bin Destino`, es una reubicación | `Gestion Picking SGA` |
| `Calculo ABC SGA` | T51112 | Cabecera de cada cálculo ABC, con parámetros y resumen | `Analisis ABC SGA` |
| `Clasificacion ABC SGA` | T51113 | Una línea por producto y cálculo | `Analisis ABC SGA` |
| `Linea Ubicacion SGA` | T51114 | Temporal compartida (`Origen` dice el uso): reparto de *Ubicar producto*, resultado de la carga inicial y filas de *Ubicar entradas* | `Unidades Producto SGA.Repartir`, `Gestion Ubicaciones SGA`, `Carga Inicial SGA`, `Gestion Entradas SGA` |
| `Sales Line SGA` | TE51102 | FlowField `Cantidad Preparada SGA`: lo recogido de esa línea en todas sus órdenes | — |
| `User Setup SGA` | TE51100 | `Responsable Picking SGA` y `Carretillero SGA` | El usuario (`User Setup SGA`, PE51105) |

## 3. Las reglas que sostienen el diseño

**Puerta única de escritura.** Solo Cod. `Gestion Contenido SGA` (51100) inserta, modifica o borra contenido y movimientos, con sus `Registrar*`. Cada escritura valida el hueco (`TestUbicacionAdmite`), aplica el delta, escribe el diario y refresca la ocupación: si alguien tocara la tabla por otro lado, los cuatro pasos se descuadrarían. Lo imponen los triggers de las dos tablas, que exigen `AutorizarEscritura()` en la instancia del registro. No hace `Commit`: lo decide quien llama. El resto de codeunits deciden dónde y cuánto, pero escriben a través de él.

**Diario inmutable y reconstrucción.** `Movimiento Ubicacion SGA` no se modifica ni se renombra nunca; un error se corrige con otro movimiento (recuento, traslado, ajuste). El contenido es un agregado del diario: `ReconstruirContenido` (Rep. `Sincronizar Ubicaciones SGA`, opción *Reconstruir contenido*) lo borra, lo rehace sin validar y vuelve a calcular reservas y estados. La única puerta que borra el diario es `Inicializar` (Rep. `Inicializar Contenido SGA`): borra a la vez contenido, movimientos y órdenes sin terminar del almacén o de los productos filtrados, así que lo que queda sigue cuadrando.

**Contenido en UM base.** `AplicarMovimiento` pasa la cantidad a base (`TestUMProducto` valida la UM y da el factor) y el contenido se acumula siempre en la UM base del producto, aunque la clave lleve `Cod. Unidad Medida`. El diario guarda además la UM y la cantidad con las que trabajó el operario. Así la comparación con el stock de BC es directa y un traslado no depende de la unidad. Las conversiones de un documento (línea de venta, parada, ensamblado) usan el factor guardado en él, no el de la ficha, que puede haber cambiado.

**Ocupación y estado persistidos.** `Estado SGA` y `% Ocupacion` de `Ubicacion SGA` son campos normales, no FlowFields: se filtran y cuentan sin recorrer el contenido, y la propuesta (`CabeEntrada`) mira cientos de huecos sin sumar el de cada uno. Los deja al día cada movimiento (`RecalcularOcupacion`). Si cambia algo que no es un movimiento (el palé por defecto de un producto ya ubicado), se corrigen con *Recalcular estado* en la ficha o con *Sincronizar*.

**Reserva recalculada, no acumulada.** `Cantidad Reservada` de una línea de contenido es siempre la suma de lo pendiente de las paradas abiertas que la recogen (`Gestion Picking SGA.RecalcularReserva` → `FijarReserva`), recortada a lo que hay. Nunca se suma ni se resta sobre la marcha: así se corrige sola al cancelar, al recoger de otro hueco o al reconstruir. La reserva empieza al enviar a picking, no al asignar.

**No engancharse al registro de BC.** SGA no se suscribe a ningún evento de registro. Las validaciones de la puerta única lanzan error, y dentro de un registro un hueco lleno haría fallar el albarán; además, al registrar aún no se sabe en qué hueco se deja la mercancía. Por eso **las entradas se ubican después**, leyendo lo registrado (pendiente = registrado − lo que ya está en el diario para ese documento), y **las salidas de venta pasan por picking** desde el pedido lanzado: la orden escribe en el pedido la cantidad a enviar y los lotes, y el envío se registra como siempre. SGA nunca escribe movimientos de producto; un traslado entre huecos no genera ninguno. Lo que se haga en BC fuera de estos caminos lo enseña la conciliación.

**Tipos de ubicación y capacidad en palés.** `Tipo Ubicacion` (enum 51100) dice para qué se usa el hueco: *Almacenamiento* (la reserva), *Picking* (de donde se prepara) o en blanco (muelles, ajustes…). Uno en blanco no se propone ni se repone nunca, pero el registro manual lo admite y el picking coge de él en su última pasada. `Capacidad Uds.` (caption *Capacidad (palés)*, 0 = sin límite) cuenta palés: lo que hay se pasa a palés línea a línea con el palé por defecto de cada producto (`OcupadoEnPales`, `Unidades Producto SGA.EnPales`), así conviven palés de 200 y de 300. Un producto sin palé se cuenta en unidades base y casi nunca cabe. La capacidad se controla siempre: solo avisa si la ubicación, o la configuración con *Según configuración*, dice *Avisar* (`SoloAvisaCapacidad`).

**Propuesta de hueco.** `Gestion Ubicaciones SGA.ProponerUbicacionCon` es la única puerta: primero las ubicaciones de Almacenamiento y, si ninguna sirve, las de Picking; dentro de cada tipo, la estrategia (enum 51104). `ProponerEnTipo` la limita a un tipo (reubicaciones) y `ProponerEnZona`, a una zona (traslado entre zonas). `MotivoRechazo` es la regla única de si un hueco sirve (1 bloqueado, 2 producto fijo de otro, 3 otro tipo/sin tipo/otra zona, 4 sin sitio, 5 otro producto, 6 otro lote, 7 espera una reubicación de otro producto, 8 picking completo para el producto): la usan la propuesta y `ExplicarSinHuecoLote`, así que el motivo que lee el usuario es siempre el que ha aplicado la propuesta. La validación al registrar (`TestUbicacionAdmite`) es más amplia a propósito: no mira el tipo. Los repartos van acumulando exclusiones (`AnadirExclusion`) para no dar un hueco dos veces.

**Zonas por grupo IIEE.** `Zona SGA."Grupo IIEE"` asigna zonas a un grupo. El grupo del producto se lee con `Config. SGA.GrupoIIEEProducto`, por RecordRef sobre el campo de Item que diga `"Campo Grupo IIEE"` (nº de campo): así SGA no depende de la extensión que lo define. Sin `ProponerEnZona`, `ProponerUbicacionCon` hace dos vueltas: la primera con `ZonasGrupo` cargada (filtra `FiltrarCandidatas` y descarta `MotivoRechazo` con 3), la segunda en todo el almacén; el motivo dice en cuál ha salido. Es preferencia, no reserva: una zona de un grupo admite cualquier producto. `TestUbicacionAdmite` pide confirmación (`FueraDeZonasGrupoIIEE`) si el hueco queda fuera de las zonas del grupo; en modo silencioso o sin interfaz deja pasar. `ProponerHuecoPaleRuta` (carga inicial, *Ubicar seleccionadas*) no mira el grupo: su cursor por tipo da por hecho que un hueco vacío sirve a cualquiera.

**Configuración solo con la ubicación vacía.** Los campos de configuración de `Ubicacion SGA` (zona, tipo, secuencia, capacidades, control de capacidad, mezclas, producto fijo, cantidades mínima y máxima) llaman a `TestVacia`; la ficha los deja editables solo vacía y el cambio en bloque salta las que tienen contenido. Así lo que hay dentro siempre cumple su configuración. Bloquear sí se puede con mercancía dentro.

**Ubicación leída en la etiqueta.** La etiqueta del hueco lleva el código de la ubicación con su código de barras Code 128. El picking lo lee para confirmar que el preparador está delante del hueco de la parada: `ComprobarUbicacionLeida` da error si la ubicación leída no es una ubicación SGA del almacén. La comprobación contra la propuesta y el desvío se hacen en `ConfirmarLinea`.

## 4. Flujos

**Entradas (recepciones y ensamblados).** `Gestion Entradas SGA` (C51105) carga, propone y confirma; la pantalla es `Ubicar Entradas SGA` (P51123), la misma para los dos orígenes. Compras: movimientos de producto *Purchase* de albaranes de compra (el lote solo está en el movimiento), una fila por albarán, producto, variante, lote y UM. Ensamblados: `Posted Assembly Header` de tipo Embotellado; el lote lo decide `LotesEnsamblado` según el producto use lotes de BC (`Consulta Stock SGA.LoteEstandar`) o el campo propio `Lote`. Lo ya ubicado se lee del diario por origen y documento, por eso `ConfirmarFila` pasa siempre el nº de documento. El origen lo fija quien abre la página: los menús con `RunPageView = where(Origen = const(Compra))` (o `Produccion`), que la página lee del grupo de filtros 3 al abrirse (`OrigenDelMenu`), y *Pendiente de ubicar* con `Preparar`. La estrategia sale de `Estrategia Ubic. Compras` o `Estrategia Ubic. Ensamblados`.

**Huecos reservados.** El hueco propuesto a una entrada (recepción, ensamblado o palé de *Imprimir y ubicar palés*) queda reservado en `Ubicacion SGA` ("Reservada Para", "Reservada Por", "Fecha Reserva", "Sesion Reserva") a nombre de la fila (`Linea Ubicacion SGA.ReservaFila`: origen, documento y línea) y de la sesión. `ProponerParaFila` propone con `FijarReserva` (las reservas propias no cuentan como ocupadas) y reserva con `ReservarHueco`, que bloquea el registro y suelta los demás huecos de la misma fila; si otra sesión se le ha adelantado, prueba otro (hasta cinco). `MotivoRechazo` devuelve 9 para un hueco reservado para otro, así que ninguna propuesta lo da (tampoco la carga inicial ni las reubicaciones), y `Gestion Contenido SGA.TestUbicacionAdmite` impide registrar en él salvo con su `FijarReserva`. Se suelta con `LiberarReservas`: al confirmar la fila, al proponer otro, al escribir otro hueco a mano (`OnValidate` de "Ubicacion Confirmada", que da error si el nuevo es de otra entrada), al recargar la lista o el palé y en el `OnClosePage` de las dos pantallas. Si una pantalla no se cierra bien, la acción *Liberar reserva* de `Ubicaciones SGA` (`LiberarReservasSeleccion`) la quita a mano. En los mapas: el 2D pinta la celda con estilo `StrongAccent` y *RESERV* si está vacía (`Gestion Mapa SGA.Pintar`); el 3D recibe la clave `v` (para quién y de quién) y, coloreando por estado, la pinta en `COLOR_RESERVADA` salvo que esté bloqueada.

**Imprimir y ubicar palés** (`Ubicar Palets Linea SGA`, P51127). Imprimir la etiqueta del palé de una tarea y ubicarlo son un paso. `PrepararPaleTarea` busca el ensamblado enlazado (`Linked Tarea`) y decide si el palé es completo o el último con lo que quede; `ImprimirYUbicarPale` comprueba todo, imprime (BarTender; en Sandbox, etiqueta A5), hace `Commit` y llama a `ConfirmarFila`. Si la ubicación falla después de imprimir, la etiqueta queda contada y el palé pendiente en *Ubicar ensamblados*. Por el `Commit`, no se llama dentro de un registro.

**Ubicar producto y pendiente de ubicar.** `Ubicar Producto SGA` (P51117): `ProponerReparto` parte la cantidad con `Unidades Producto SGA.Repartir` (un trozo por palé completo y uno solo con el resto) y propone un hueco por trozo; `ConfirmarReparto` registra. `Pendiente Ubicar SGA` (P51131) calcula con `Consulta Stock SGA.CargarPendienteUbicar` el stock de BC por lote menos lo ubicado, y aparta lo que está pendiente en *Ubicar entradas* para no ubicarlo dos veces. *Ubicar seleccionadas* es la carga inicial por huecos libres con esas cantidades (`FijarPendientes`).

**Carga inicial.** Rep. `Carga Inicial Contenido SGA` → `Codeunit.Run` de `Carga Inicial SGA` (C51106), con destino *Ubicación fija*, *Ubicación indicada* o *Huecos libres*. En huecos libres cada palé va a un hueco vacío (`ProponerHuecoPaleRuta`, con un cursor por tipo que solo avanza: un hueco vacío sin producto fijo admite a cualquiera, así que el que se salta no le sirve a nadie) y el resto, con *Priorizar consolidación*. La carga inicial llama antes a `FijarPickingPrimero(true, máx)`, que invierte `TipoPorOrden` en esa instancia: palés y resto van primero a picking y luego a almacenamiento. `máx` (campo del informe, por defecto 1) son las ubicaciones de picking que puede ocupar cada producto: al empezar cada propuesta, `PickingDelProductoCompleto` cuenta las que ya ocupa (contenido con `Tipo Ubicacion` = Picking) y, si llega, `MotivoRechazo` devuelve 8 en las de picking salvo las suyas reservadas o donde ya está, y `ProponerHuecoPaleRuta` no avanza el cursor de picking (el hueco sigue valiendo para el siguiente producto). En *solo pendientes* (*Ubicar seleccionadas*) no se fija nada, y queda el orden de siempre sin límite. Escribe con `RegistrarCargaInicial`, que no valida capacidad.

**La simulación es la carga real deshecha**: `OnRun` acaba con `Error` de una marca que el llamante reconoce con `EsFinSimulacion`. Así cada propuesta ve los huecos que han ocupado las anteriores; el resultado sobrevive porque va en la temporal `Linea Ubicacion SGA`. Todo o nada.

**Picking de venta.** *Enviar a SGA* (`Sales Order SGA`, PE51104) → `EnviarPedidoASGA`: pedido lanzado, sin órdenes sin terminar (`ComprobarPedidoParaEnviar`) y con palé en la ficha de todos los productos (`TestPaleProductos`). El pedido se reparte en **órdenes de un palé como mucho**: por cada línea, una orden por palé completo (`AnadirOrdenPale`) y el resto a una orden de sueltos que se comparte entre líneas mientras la suma, en fracción del palé de cada producto, no pase de 1; si pasa, se abre otra. Cada orden reserva al crearse, para que la siguiente vea descontado lo que coge; la que no consigue ninguna parada se borra (`CerrarOrdenNueva`). Un pedido con alguna orden de venta, en cualquier estado (`PedidoEnviadoASGA`), no se puede volver a abrir: lo impide el suscriptor de `Release Sales Document.OnBeforeManualReOpenSalesDoc`. `GenerarParadas` recorre el contenido disponible en **tres pasadas**: palés completos de Almacenamiento (si el producto tiene palé), Picking, y el resto (Almacenamiento y sin tipo); cada una en el orden de la estrategia de picking. La reserva se recalcula al acabar cada línea del pedido. Lo que no se cubre vuelve en `prm_Faltas` (una línea por producto, en la UM del pedido) y la orden se crea con lo que hay.

**Segunda ronda.** Como `NecesidadLinea` ya descuenta lo recogido y lo que está en órdenes, volver a llamar a `EnviarPedidoASGA` manda solo lo que falta. `SegundaRonda` lo hace para cada pedido lanzado que ya tuvo orden, no tiene ninguna viva (`PideSegundaRonda`) y tiene contenido disponible de algo que le falta (`HayContenidoParaFaltas`), con `Commit` por pedido.

**Asignación.** Con `Exigir Asignacion Picking` la orden nace *Pendiente Asignar* y la reparte un responsable (`Responsable Picking SGA`) en `Asignar Ordenes Picking SGA` (P51124); si no, cada uno la toma con *Siguiente orden* (`TomarSiguienteOrden`).

**Recogida** en `Preparar Picking SGA` (P51121) → `ConfirmarLinea`. Qué se exige lo decide `ParadaCompleta` (también la pantalla): siempre la ubicación, y el producto si lo pide la configuración (`ExigeEscanearProducto`). Cada lectura puede ser un escaneo o teclearse. Luego: ubicación leída, desvío según `DesvioPermitido`, **producto leído** (`TestProductoLeido` con Cod. `Lectura Codigos SGA`, C51114: referencia de código de barras, GTIN, nº o GS1-128 con lote; el evento `OnBuscarProducto` deja a otra extensión resolver códigos propios), `RegistrarSalida` y reserva.

**Sin stock** (`SustituirParadaSinStock`): cancela la parada y crea paradas nuevas de la misma línea del documento desde otro contenido del producto, excluida la ubicación vacía, en el orden de la estrategia de picking (picking y luego el resto; en una reubicación, almacenamiento con el mismo destino); devuelve el texto que la pantalla enseña como aviso. No corrige el contenido del hueco vacío.

**Saltar y paradas retenidas** (`SaltarParada`): cada Saltar suma uno a `"Veces Saltada"` de la parada; a la segunda queda `Retenida`, con `"Fecha Retencion"` y `"Retenida por"`. La pantalla pasa a la siguiente con `Next` y, al final del recorrido, vuelve a cargar la primera pendiente, que es una saltada. El recorrido del preparador usa `FiltrarParaPreparar` (pendientes y no retenidas); el resto del motor (reservas, estado de la orden, `"Lineas Pendientes"`) sigue usando `FiltrarPendientes`, así que una retenida conserva su reserva y deja la orden en proceso. Cuando solo quedan retenidas, `TerminarOrden` pasa lo recogido al pedido y avisa de cuántas quedan; `BuscarMasPrioritaria` no vuelve a ofrecer una orden sin paradas para el preparador (`"Orden Picking SGA".TieneParadasParaPreparar`). El jefe de almacén las ve en `"Paradas Picking SGA"` (página 51134, vista *Retenidas*), en la pila *Paradas retenidas* de `"Cue SGA"` y en el FlowField `"Paradas Retenidas"` de la orden (columna y vista *Con paradas retenidas*), y las resuelve con *Buscar en otra ubicación*, que es `SustituirParadaSinStock`: las paradas nuevas no están retenidas y vuelven al preparador de la orden.

**Pilas de picking.** Son FlowField `count` de `"Cue SGA"` sobre `"Orden Picking SGA"` y `"Linea Orden Picking SGA"`, no código que cuente: la página calcula todos sus FlowFields al leer el registro, cada uno es un `SELECT COUNT` que resuelve la base de datos con sus índices, y el drill-down abre la lista con los mismos filtros sin programarlo. Lo que depende del momento va en FlowFilter que pone `FiltrarCue`: `"Filtro Usuario"` (usuario actual), `"Filtro Momento"` (el día de trabajo entero, para lo terminado o confirmado hoy) y `"Filtro Fecha Envio"` (fechas de envío hasta hoy, sin las vacías). Un `CalcFormula` no compara dos campos, así que el desvío de ubicación se guarda al confirmar (`Desvio`, en `ConfirmarLinea`) para poder contarlo; la clave `Desvios` de la parada lo indexa. Almacén: pendientes de asignar, sin empezar, en proceso, envío vencido, paradas retenidas, terminadas sin pasar al pedido, reubicaciones pendientes (paradas con destino), terminadas hoy y desvíos de hoy; las de órdenes no cuentan reposiciones. Preparador: mis órdenes, mis reubicaciones y disponibles (solo sin asignación exigida). Los pedidos que esperan segunda ronda no tienen pila: dependen de cálculos por pedido (`PideSegundaRonda`) que un FlowField no puede hacer.

**Pantalla.** P51121 no tiene campos de BC; la dibuja el control add-in `Picking PDA SGA` (`SGA/Otros/Add-in/PickingPDASGA.js/.css`), con letra y botones grandes para el terminal. La página le manda la parada en un `JsonObject` (`Pintar`) y atiende sus eventos (`Lectura`, `Cantidad`, `Accion`); la cantidad se manda antes que cualquier otro evento para que una lectura que confirma no adelante a la cantidad tecleada. Los errores de lectura se prueban con `TryFunction` y salen en la propia pantalla con pitido, sin ventana; los de `ConfirmarLinea` siguen siendo errores (escribe, no se puede envolver).

**PDA.** P51121 lleva además `BarcodeScannerProviderAddIn` (System Application), que en la app móvil recibe las lecturas por *intent* sin depender del foco. La pantalla tiene una casilla por paso, en orden: ubicación y, si se exige, producto. El foco va solo a la primera pendiente (para el lector que teclea); si el preparador toca una casilla para teclear, el foco se queda en ella hasta que la manda o hasta que su lectura llega por otra vía. Con escáner por *intent* las casillas llevan `inputmode="none"` para que Android no abra el teclado hasta que se toquen. Lo que llega lo clasifica AL por su contenido, no por la casilla: según `EsUbicacion` es ubicación o producto, y la parada se confirma sola cuando `ParadaCompleta`, venga de donde venga. Rol `Rol Center Preparador SGA` (P51133, perfil `PREPARADOR SGA`).

**En turno.** P51121 abierta sin filtro de orden (rol center, *Siguiente orden* de `Ordenes Picking SGA`, ambos con `RunObject`) queda en turno: toma la orden con `SiguienteOrdenPreparar` (`TomarSiguienteOrden` + `Commit`) y, al terminarla, deja el resultado como aviso y carga la siguiente sin cerrarse; sin órdenes, lo dice y ofrece volver a buscar. Abierta desde una orden (`AbrirPreparacion`), trabaja esa y se cierra.

**Paso al pedido.** Al terminar, `Commit` y `Codeunit.Run` de `Gestion Picking SGA` (`PasarAPedido`): escribe `Qty. to Ship` y, solo si el producto lleva lotes de BC, el seguimiento. Es idempotente (recogido en todas las órdenes − enviado) y, si falla, lo confirmado se queda; se repite desde la orden o el pedido. El estado de preparación del pedido se calcula al vuelo (`EstadoPreparacionVenta`): guardarlo obligaría a engancharse al registro.

**Reubicaciones (almacenamiento → picking).** Cod. `Reubicaciones SGA` (C51113) decide qué y adónde; `Gestion Picking SGA.AnadirReubicacion` lo escribe. Una reubicación es una parada de una orden de origen `Reposicion` con `Cod. Bin Destino`: reserva, se asigna, se prepara como cualquier picking; al confirmarla, `ConfirmarLinea` hace `RegistrarTraslado` en vez de `RegistrarSalida`. Se planifica en cuanto una ubicación de picking se queda a cero de un producto (`ReubicarSiSeVacia`, que lanza `Gestion Contenido SGA.AplicarMovimiento` con cualquier movimiento que tenga esa ubicación de origen; una línea a cero que sigue existiendo por su reserva cuenta como vacía; se repone aunque el producto quede en otra de picking, salvo reubicación pendiente hacia ese destino) y con `PlanificarAlmacen` (acción de `Reubicaciones SGA`, P51132, y `OnRun` para la cola de proyectos). Hay una sola orden de reubicaciones sin empezar por almacén. El carretillero las recibe con *Siguiente orden*: si `User Setup."Carretillero SGA"` (`EsCarretillero`), `TomarSiguienteOrden` le da reubicaciones; si no, pedidos. Lo que un responsable asigna llega siempre.

**Conciliación.** Rep. `Conciliacion SGA vs Stock` → `Consulta Stock SGA` (stock de BC por lote, contenido ubicado, clasificar) → `Conciliacion SGA` (P51113). *Regularizar* solo corrige faltas, con `RegistrarAjuste` en `Config. SGA."Ubic. Ajustes"`; una sobra en SGA se corrige con un recuento.

**Análisis ABC (solo observa).** `Analisis ABC SGA` (C51107, `OnRun` para la cola) clasifica productos por palés salidos y huecos por altura y secuencia; escribe solo en T51112 y T51113 y no cambia ninguna estrategia. Se guarda cada cálculo para poder exigir, más adelante, varios seguidos en una clase. Páginas `Analisis ABC SGA` (P51128) y `Calculos ABC SGA` (P51129). Criterio y fases, en la [parte II](#plan-abc-por-fases).

**Mapa y mapa 3D.** El mapa (`Mapa Almacen SGA`, P51107) es una rejilla sobre `Buffer Mapa SGA`. El 3D (`Mapa 3D Almacen SGA`, P51122) es el control add-in `Mapa 3D SGA`: un `canvas` 2D con la proyección escrita a mano, **sin librerías externas**, porque la política de contenido del cliente bloquea scripts de fuera y el panel saldría en blanco sin error. Sus recursos (`Otros/Add-in/`) se declaran **desde la raíz del proyecto** (`./SGA/Otros/Add-in/...`), no desde el `.al`: si se mueven los JS o el CSS hay que cambiar las rutas, y el compilador no avisa. La página dibuja cuando el lienzo dispara `ControlListo`, no en `OnOpenPage`. `Gestion Mapa SGA.DatosMapa3D` manda un JSON con claves cortas; la posición sale del código `pasillo-estantería-altura` (3, 2 y 2 dígitos, `TrocearCodigo`) y los códigos con otra forma no se dibujan. El lienzo no mueve nada: arrastrar o vaciar solo dispara eventos, y AL hace el traslado (`TrasladarConDialogo`, nunca entre zonas) y repinta con `Actualizar`, que conserva la vista (`Dibujar` la reinicia).

## 5. Problemas conocidos y pendientes de probar

**Pendientes de probar en sandbox** (el compilador no los comprueba):

1. Registrar el envío de un pedido pasado desde picking con lotes: que BC acepte el seguimiento y el lote del movimiento sea el recogido. Y una línea en cajas (factor ≠ 1): que cantidad y seguimiento cuadren sin restos de redondeo.
2. Envío parcial y nueva orden del mismo pedido: solo se manda a recoger lo que falta. Y la segunda ronda con varios pedidos a la vez.
3. Los menús *Ubicar recepciones* / *Ubicar ensamblados* (`RunPageView` por `Origen`) abren su origen.
4. Una recepción deshecha del todo desaparece de *Ubicar recepciones*; deshecha en parte, enseña la neta.
5. Un palé de otro código (PALE200, EUROPALE…) cuenta bien en la capacidad, en proporción al palé por defecto del producto.
6. `Linked Tarea` pasa al `Posted Assembly Header` al registrar; si no, los palés ubicados después no encuentran su ensamblado.
7. Etiqueta de ubicación (Rep. 51106): que los dos códigos de barras, a 10 pt, quepan en sus columnas (3,9 cm el de la ubicación más larga) y se lea; si no, bajar la fuente o pasar a `IDAutomationC128XS`.
8. Lectura de las etiquetas en la PDA: que `EsUbicacion` reconozca la ubicación con el lector real.

**Conocidos:**

- Almacén con *Require Shipment*: `Validate("Qty. to Ship")` falla por diseño de BC y el paso al pedido no sirve tal cual.
- Deshacer una recepción ya ubicada no saca la mercancía del hueco: se corrige con un recuento (la conciliación lo enseña como *SobraEnSGA*). Igual si se cambian a mano los lotes o la cantidad a enviar del pedido.
- `Movimiento Ubicacion SGA."No. Orden SGA"` no se rellena: la puerta única no lo recibe. El nº de orden va en la descripción del movimiento (venta) o en `No. Documento Origen` (reubicación).
- La protección de escritura evita errores de programación, no es seguridad: `AutorizarEscritura` es pública. Si el contenido se descuadra, *Reconstruir contenido*.
- El estado de preparación se calcula por cada pedido que pinta la lista de pedidos.
- La rejilla del mapa llega a la estantería 32. El JSON del 3D crece con el almacén: si pesara demasiado, el siguiente paso es mandar el contenido solo del pasillo aislado.
- La etiqueta A5 solo se usa en Sandbox; en producción sale por BarTender.
- Las dos rondas de picking son manuales: la segunda no se lanza sola.

## 6. Rangos de IDs

| Tipo | En uso | Libres |
|---|---|---|
| Table | 51100–51109, 51112–51114 | 51110–51111, 51115+ |
| Table Extension | 51100 (User Setup), 51102 (Sales Line) | 51101, 51103+ |
| Page | 51100–51115, 51117–51135 | 51116, 51136+ |
| Page Extension | 51100–51108 | 51109+ |
| Codeunit | 51100–51109, 51111, 51113–51114 | 51110, 51112, 51115+ |
| Report | 51100–51103, 51106–51107 | 51104–51105, 51108+ |
| Enum | 51100–51108, 51110–51112 | 51109, 51113+ |
| Permission Set | 51100 (general), 51101 (responsable) | 51102+ |

El control add-in y los perfiles no llevan ID. Todo SGA está en el bloque 511xx del rango de la app (`app.json`: 50000–51999).

---

# Parte II. Decisiones de almacén

Las decisiones vigentes sobre **dónde se ubica**, **de dónde se recoge** y **cómo se repone el picking**: qué se decidió, por qué y qué haría replantearlo. Es para volver a él cuando cambie el almacén.

El punto de partida que condiciona casi todo: **huecos de un palé, y lo que entra de producción son palés completos**.

## Dónde se ubica

| Decisión | Por qué | Replantear si |
|---|---|---|
| Cada ubicación tiene un **tipo según su uso**: Almacenamiento, Picking o sin tipo. Se propone **primero almacenamiento** y, si no queda sitio, picking | Lo que distingue un hueco es si guarda o prepara, no la unidad que le cabe. Lo nuevo va a la reserva y el picking se llena con las reubicaciones | El picking se llena con lo que entra porque no queda sitio en almacenamiento: faltan huecos de almacenamiento |
| Un hueco **sin tipo no se propone nunca** (tampoco en la carga inicial) | Solo entra en las propuestas un hueco del que alguien ha dicho para qué es; si no, se propondrían muelles o la ubicación de ajustes | — |
| **Capacidad en palés**, contando cada producto con su palé por defecto. Un producto sin palé se cuenta en unidades base | El palé ya está en la ficha y es lo que mueve la carretilla. Una sola medida para todos los huecos es más fácil de entender que una capacidad por clase de unidad | Se pasa a huecos de varios palés: subir su capacidad y recuperar *consolidar* |
| **La propuesta es estricta y la validación al registrar, amplia**: el registro no mira el tipo | La propuesta orienta; el registro solo impide lo que rompe una regla (bloqueo, producto fijo, mezcla, capacidad). No se bloquea el trabajo del operario | — |
| **Reparto**: cada palé completo por separado y **una sola línea con el resto**, en cajas si son exactas y si no en unidad base | El resto es un solo bulto físico y va a un solo hueco | Un producto se vende en una unidad intermedia que debería ser la caja: cambiar su unidad de venta |
| Estrategia de ensamblados: **Solo hueco vacío** (primer hueco vacío por *Secuencia picking*). Compras y el resto: **Estándar** (fija → consolidar → primer hueco con sitio) | Moviendo palés completos, las estrategias apenas se diferencian; con el almacén lleno todas acaban en el hueco libre más cercano. No necesita datos ni mantenimiento y es predecible. Basta con que la *Secuencia picking* empiece por los mejores huecos. **Coste aceptado**: los palés de una tirada no quedan necesariamente juntos | Las tiradas quedan repartidas y cuesta encontrar o recontar un lote: *Junto al mismo producto* |
| El palé de una etiqueta de producción es **completo salvo el último de la tarea** | La tarea ya tiene el plan; pedir al operario cuánto lleva cada palé sería lento. **Límite**: si los litros o el volumen de la tarea no cuadran, el último palé sale mal calculado | Hay muchas botellas sueltas de producción: revisar los datos de la tarea |
| **Sin muelle de recepción**: del albarán directo al hueco | Un muelle obligaría a meter la mercancía en él al registrar, que es engancharse al registro de BC. Si hiciera falta, sería un traslado desde una ubicación sin tipo | Se quiere controlar lo recibido y aún sin colocar |
| La **configuración de una ubicación solo se cambia vacía**; bloquearla, siempre | Lo que hay dentro cumple siempre su configuración; un hueco roto se bloquea con la mercancía dentro | — |

## De dónde se recoge

| Decisión | Por qué | Replantear si |
|---|---|---|
| **Tres pasadas**: palés completos de almacenamiento; luego picking; luego lo que falte del resto (almacenamiento y sin tipo) | No se deshace el picking para servir un palé entero; el picking es de donde se prepara; lo demás, como último recurso | Se pica casi todo en palés completos o casi todo en cajas |
| Dentro de cada pasada, la **Estrategia picking** de la configuración: FIFO (por defecto), FEFO, *Lote exacto* (se comporta como FEFO) o *Vaciar ubicación* (por código de ubicación) | Un solo criterio de orden para el picking y para elegir qué se repone | Productos con caducidad corta: FEFO |
| **La reserva empieza al enviar a picking**, no al asignar | Una orden que espera preparador ya tiene su stock apartado; dos pedidos no se pisan | — |
| **Ubicación siempre** en cada parada; *Exigir confirmar ubicación* solo afecta a la tarea de ubicar mercancía | La etiqueta del hueco lleva el código de la ubicación; el picking la lee y la compara con la del hueco de la parada | — |
| **Escanear el producto** (opción de configuración): referencia de código de barras, GTIN, nº de producto o GS1-128; si trae lote, debe ser el de la parada | Certifica que se coge lo que toca, no solo de dónde. Solo se usan campos estándar; los códigos propios de la ficha los resuelve otra extensión con `OnBuscarProducto` | Productos con el código de barras en un campo propio y sin referencia |
| **PDA con la app móvil de BC** y el escáner por *intent* (`BarcodeScannerProviderAddIn`) sobre la misma página de preparación, con rol propio | Sin app ni licencias aparte; la lectura no depende del foco y la página es la misma en escritorio y PDA. Las soluciones de AppSource trabajan sobre los documentos de almacén estándar, que SGA no usa | Hace falta trabajar sin cobertura |
| En la PDA la parada **se confirma sola** cuando tiene lo exigido (`ParadaCompleta`) | Un toque menos por parada; la cantidad se cambia antes del último paso | Errores por confirmar antes de ajustar la cantidad |
| El desvío a otro hueco y escanear la ubicación son **opciones de configuración** | Depende de la disciplina del almacén; el desvío queda registrado en la parada | — |
| El **paso al pedido** suma lo recogido en todas las órdenes y descuenta lo enviado; los lotes solo se escriben si el producto usa lotes de BC | Se puede repetir sin duplicar; un lote propio del ensamblado es solo de SGA y BC no lo espera | Un producto pasa a lotes de BC: empieza a escribirse sin tocar nada |
| **Sin stock** busca el producto en otra ubicación antes de cancelar | Lo que falta vuelve al recorrido mientras el preparador sigue; el hueco vacío se queda sin corregir a propósito, para que lo recuente quien lo ve | Si se pierde mucho tiempo buscando: bloquear el hueco al marcar *Sin stock* |
| **Primera ronda con lo que hay; segunda ronda con lo que falta** | Un pedido incompleto no espera a que llegue todo: el preparador trabaja mientras la compra llega. Lo que falta se prepara cuando haya stock ubicado | Los pedidos incompletos se acumulan: lanzar la segunda ronda en automático |

## Cómo se repone el picking

- **Cuándo**: en cuanto una ubicación de picking se queda a cero de un producto, con cualquier movimiento (recogida, traslado, vaciado, desubicar o ajuste), aunque el producto quede en otra ubicación de picking y salvo que ya haya una reubicación pendiente hacia ella. Además, al planificar el almacén entero (a mano o desde la cola de proyectos), para los productos sin nada en picking ni reubicación pendiente, también los que nunca han tenido picking. En los dos casos hace falta stock disponible en almacenamiento.
- **Qué**: el primer contenido de almacenamiento en el orden de la *Estrategia picking*, **un palé como mucho**.
- **Adónde**: al mismo hueco que se ha vaciado si lo sigue admitiendo; si no, la propuesta de siempre limitada a picking (fija → consolidar → primero libre). El hueco destino queda **reservado**: vacío, no se propone a otro producto.
- **Quién**: es una parada de picking con ubicación destino, en una orden de reubicaciones. La recibe con *Siguiente orden* el usuario marcado como **carretillero**; los demás reciben pedidos. Lo que asigna un responsable llega siempre.

**Por qué al quedar a cero:** no hay que configurar nada por ubicación, nunca se lleva un palé a un picking que aún tiene y cada hueco de picking que se vacía pide su reposición en el momento. **Coste aceptado:** entre que se vacía y llega la reubicación, una venta de ese producto coge de almacenamiento (tercera pasada).

## Alternativas valoradas

| Alternativa | Qué haría | Por qué no ahora |
|---|---|---|
| Junto al mismo producto | Hueco vacío más cercano a donde ya está el producto (mismo lote primero) | Mejora el orden (tiradas juntas), no los recorridos. **Primera candidata** si hace falta cambiar |
| Reponer por mínimo | Reponer el picking antes de vaciarse, o mandar ahí el palé que entra | Exige poner mínimo y máximo en los huecos de picking. Rinde con mucha venta en cajas sueltas |
| Por zona | Cada familia de producto a sus zonas | Exige una tabla familia → zona. Útil para segregar por normativa o separar propios y externos. En parte ya está con el grupo IIEE |
| Por rotación (ABC) | Lo que más sale, abajo y cerca de la salida | Ver el plan por fases |
| Consolidar o ubicación fija como principal | — | No encajan con huecos de un palé |
| Cross-docking, repartir entre pasillos | — | Cuando el picking esté rodado / con varias carretillas ubicando a la vez |
| Peso y volumen | Filtro para todas las estrategias | Los campos existen en la ubicación y no se usan |

Si se combinan varias, la idea es pasar a **plantillas de ubicación**: pasos que se prueban en orden ("junto al mismo lote", "reponer picking", "primer hueco vacío"), asignables por tipo de entrada. Si la **ocupación media** pasa del 85-90 %, ninguna estrategia nueva rinde: el problema es de espacio.

## Plan ABC por fases

Calcular el ABC es barato; mover palés no (cada movimiento es un viaje de carretilla que no factura). Cada fase solo se hace si la anterior lo justifica con datos.

| Fase | Qué es | Estado |
|---|---|---|
| **1. Observar** | Clasificar productos y huecos y guardar cada cálculo (*Análisis ABC*). No cambia nada | **Hecha** |
| 2. Ubicar según el ABC | Primer hueco vacío **de su clase**; si no hay, el de la clase más cercana. El almacén se ordena solo según rota | Si la fase 1 muestra ventas concentradas |
| 3. Propuestas de reubicación | Lista de movimientos por ganancia ("este palé C ocupa un hueco A"), en ratos muertos, con límite por turno y solo para productos que lleven varios cálculos seguidos en su nueva clase | Si tras la fase 2 siguen muchos palés fuera de su clase |

**Criterio de la fase 1:** rotación = **palés salidos** (ventas netas de los últimos *Días de ventas del análisis ABC*, 90 por defecto, pasadas a palés): con palés completos, cada palé es un viaje. Productos de más a menos: A hasta el 80 % acumulado, B hasta el 95 %, C el resto (cortes en la configuración). Huecos de mejor a peor por altura y *Secuencia picking*: tantos huecos A como palés A en almacén, y así.

**Para decidir la fase 2**: el *% de salidas del 20 % que más sale* y su evolución. Alrededor del 50 %, ventas repartidas y el ABC rendirá poco; por encima del 70-80 % **y** con recorridos largos, compensa, con **2 clases**, no más.

## Puntos abiertos

1. **Reponer por mínimo** en vez de al vaciarse. Los campos *Ctdad. mínima* y *Ctdad. máxima* de la ubicación existen y no se usan.
2. **Qué productos reponer primero** cuando no hay huecos de picking para todos: se planifican en el orden en que aparecen y el que no encuentra destino se queda sin planificar.
3. **Salidas en palé completo frente a cajas sueltas**: es el dato que falta para revisar estas decisiones y no se calcula.
4. **Lanzar la segunda ronda de picking en automático** o mantenerla a mano.

## Estudios en que se apoyan

- Con el almacén muy lleno, la estrategia importa poco: [Hausman et al. y trabajos posteriores](https://repub.eur.nl/pub/86663/REPUB_86663.pdf).
- Moviendo palés completos, las diferencias entre estrategias son pequeñas; se gana en el picking de cajas: [modelo de colas](https://arxiv.org/pdf/2503.04448).
- Con pocos productos, más de 2 o 3 clases ABC no mejora: [Yu y De Koster](https://www.researchgate.net/publication/269776808_Class-Based_Storage_with_a_Finite_Number_of_Items_Using_More_Classes_is_not_Always_Better).
