namespace AntonioNadal.SGA;

/// <summary>
/// ControlAddIn Mapa 3D SGA.
/// Lienzo que dibuja el almacén en tres dimensiones dentro de Business Central.
///
/// El render vive en JavaScript porque BC no tiene ningún control nativo capaz de dibujar
/// volumen; AL se limita a mandarle los datos y a recoger el clic sobre una ubicación.
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
    /// Igual que Dibujar, pero sin tocar la vista: conserva el giro, el zoom y el pasillo
    /// aislado. Se usa tras un traslado, para que el operario siga donde estaba.
    /// </summary>
    procedure Actualizar(prm_DatosJson: Text);

    /// <summary>
    /// El lienzo avisa de que ya está montado y puede recibir datos.
    /// </summary>
    event ControlListo();

    /// <summary>
    /// El operario ha pulsado una ubicación en el mapa.
    /// </summary>
    event CeldaPulsada(prm_CodBin: Text);

    /// <summary>
    /// El operario ha aislado un pasillo en el mapa, o ha vuelto a verlos todos (estantería
    /// en blanco). Sirve para que la página acompañe la vista y sus acciones trabajen sobre
    /// el pasillo que se está mirando.
    /// </summary>
    event PasilloSeleccionado(prm_Estanteria: Text);

    /// <summary>
    /// El operario ha arrastrado una ubicación con contenido hasta otra (modo Trasladar o
    /// Ctrl+arrastrar). El lienzo no mueve nada: la página pregunta qué y cuánto, y registra.
    /// </summary>
    event TrasladoSolicitado(prm_Origen: Text; prm_Destino: Text);

    /// <summary>
    /// El operario ha pedido vaciar una ubicación con clic derecho sobre su bloque. La página
    /// confirma y deja el contenido sin ubicar.
    /// </summary>
    event VaciarSolicitado(prm_CodBin: Text);
}
