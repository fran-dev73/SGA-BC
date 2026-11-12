namespace AntonioNadal.SGA;

/// <summary>
/// ControlAddIn Picking PDA SGA.
/// Pantalla del preparador dibujada a medida para un terminal de mano: letra grande, la
/// ubicación y la cantidad bien visibles, botones grandes y los pasos que faltan para
/// confirmar. Funciona igual en el navegador.
///
/// No decide nada: AL le manda la parada con Mostrar y ella devuelve lo que hace el
/// preparador (lecturas, cantidad y botones). Toda la lógica sigue en la página
/// "Preparar Picking SGA" y en Cod. "Gestion Picking SGA".
/// </summary>
controladdin "Picking PDA SGA"
{
    // Las rutas van desde la raíz del proyecto, donde está app.json.
    StartupScript = './SGA/Otros/Add-in/PickingPDASGA.js';
    StyleSheets = './SGA/Otros/Add-in/PickingPDASGA.css';

    RequestedHeight = 640;
    MinimumHeight = 480;
    MinimumWidth = 280;
    VerticalStretch = true;
    HorizontalStretch = true;

    /// <summary>
    /// Pinta la parada actual y el estado de lo capturado. Con "vacia" a true, que no hay
    /// paradas pendientes.
    /// </summary>
    procedure Mostrar(prm_Datos: JsonObject);

    /// <summary>
    /// Pitido y vibración: 'ok' al aceptar una lectura o confirmar, 'error' al rechazarla.
    /// </summary>
    procedure Senal(prm_Tipo: Text);

    /// <summary>
    /// La pantalla está montada y puede recibir la parada.
    /// </summary>
    event Listo();

    /// <summary>
    /// Código escaneado o tecleado en el campo de lectura: una ubicación o un producto.
    /// </summary>
    event Lectura(prm_Texto: Text);

    /// <summary>
    /// Cantidad recogida, en la unidad del pedido y con punto decimal.
    /// </summary>
    event Cantidad(prm_Valor: Text);

    /// <summary>
    /// Botón pulsado: confirmar, saltar, sinstock o siguiente (buscar otra orden).
    /// </summary>
    event Accion(prm_Accion: Text);
}
