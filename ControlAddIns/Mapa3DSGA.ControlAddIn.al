namespace AntonioNadal.SGA;

/// <summary>
/// ControlAddIn Mapa 3D SGA.
/// Lienzo que dibuja el almacén dentro de Business Central, en tres vistas: 3D, planta y frente
/// de una estantería, coloreadas por estado, rotación ABC o caducidad, y con búsqueda.
///
/// El render vive en JavaScript porque BC no tiene ningún control nativo capaz de dibujar
/// así; AL se limita a mandarle los datos y a recoger lo que hace el operario.
///
/// Los recursos son locales a propósito: la política de contenido del cliente bloquea los
/// scripts de fuera, así que una librería traída de un CDN dejaría el panel en blanco.
/// </summary>
controladdin "Mapa 3D SGA"
{
    // Las rutas van desde la raíz del proyecto, donde está app.json, no desde este fichero:
    // mover este .al no las cambia, pero mover los recursos sí.
    Scripts = './SGA/Otros/Add-in/Mapa3DSGA.js';
    StartupScript = './SGA/Otros/Add-in/Startup.js';
    StyleSheets = './SGA/Otros/Add-in/Mapa3DSGA.css';

    RequestedHeight = 900;
    MinimumHeight = 560;
    RequestedWidth = 1200;
    MinimumWidth = 320;
    VerticalStretch = true;
    HorizontalStretch = true;

    /// <summary>
    /// Manda al lienzo las ubicaciones que tiene que dibujar, en JSON.
    /// </summary>
    procedure Dibujar(prm_DatosJson: Text);

    /// <summary>
    /// Igual que Dibujar, pero sin tocar la vista: conserva la vista elegida, el giro, el zoom,
    /// la estantería, el color y la búsqueda. Se usa tras un traslado, para que el operario
    /// siga donde estaba.
    /// </summary>
    procedure Actualizar(prm_DatosJson: Text);

    /// <summary>
    /// Deja elegido el criterio de color ('estado', 'posicion', 'abc' o 'caducidad') y un texto buscado
    /// (producto o ubicación), como si el operario los hubiera puesto en la barra.
    /// </summary>
    procedure Preparar(prm_Criterio: Text; prm_Busqueda: Text);

    /// <summary>
    /// El lienzo avisa de que ya está montado y puede recibir datos.
    /// </summary>
    event ControlListo();

    /// <summary>
    /// El operario ha pulsado una ubicación en el mapa.
    /// </summary>
    event CeldaPulsada(prm_CodBin: Text);

    /// <summary>
    /// El operario ha elegido un pasillo en el mapa (aislado en la 3D o visto de frente), o ha
    /// vuelto a verlos todos (pasillo en blanco). Sirve para que la página acompañe la vista y
    /// sus acciones trabajen sobre el pasillo que se está mirando.
    /// </summary>
    event PasilloSeleccionado(prm_Pasillo: Text);

    /// <summary>
    /// El operario ha arrastrado una ubicación con contenido hasta otra, en cualquier vista. El
    /// lienzo no mueve nada: la página pregunta qué y cuánto, y registra.
    /// </summary>
    event TrasladoSolicitado(prm_Origen: Text; prm_Destino: Text);

    /// <summary>
    /// El operario ha pedido vaciar una ubicación con clic derecho sobre su bloque. La página
    /// confirma y deja el contenido sin ubicar.
    /// </summary>
    event VaciarSolicitado(prm_CodBin: Text);
}
