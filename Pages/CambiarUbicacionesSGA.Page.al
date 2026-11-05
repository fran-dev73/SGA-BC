namespace AntonioNadal.SGA;

/// <summary>
/// Page Cambiar Ubicaciones SGA (ID 51126).
/// Diálogo para cambiar de golpe los datos de gestión de muchas ubicaciones: capacidad, control
/// de capacidad, qué admiten, tipo de uso, zona y mezcla de productos. Lo abre la lista de ubicaciones con las
/// líneas seleccionadas.
///
/// Cada dato lleva su casilla "Cambiar": solo se toca lo marcado. Hace falta porque 0 o
/// "en blanco" son valores válidos (capacidad sin límite, admite cualquiera) y no sirven para
/// decir "no cambiar".
/// </summary>
page 51126 "Cambiar Ubicaciones SGA"
{
    Caption = 'Cambiar ubicaciones en bloque';
    PageType = StandardDialog;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Alcance)
            {
                Caption = 'A qué ubicaciones';

                field(Resumen; Resumen)
                {
                    Caption = 'Se cambiarán';
                    ToolTip = 'Ubicaciones seleccionadas en la lista.';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                }
            }
            group(Datos)
            {
                Caption = 'Qué se cambia (solo lo marcado)';

                field(CambiarCapacidad; CambiarCapacidad)
                {
                    Caption = 'Cambiar capacidad';
                    ToolTip = 'Marque para cambiar la capacidad.';
                    ApplicationArea = All;
                }
                field(Capacidad; Capacidad)
                {
                    Caption = 'Capacidad';
                    ToolTip = 'Cuánto cabe, en la clase que admite el hueco: 1 = un palé (lleve lo que lleve), 72 = setenta y dos cajas. 0 = sin límite.';
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 5;
                    MinValue = 0;
                    Editable = CambiarCapacidad;
                }
                field(CambiarControlCapacidad; CambiarControlCapacidad)
                {
                    Caption = 'Cambiar control de capacidad';
                    ToolTip = 'Marque para cambiar qué pasa cuando algo no cabe en la ubicación.';
                    ApplicationArea = All;
                }
                field(ControlCapacidad; ControlCapacidad)
                {
                    Caption = 'Control capacidad';
                    ToolTip = 'Qué hacer cuando una entrada no cabe: lo que diga la configuración de SGA, avisar (y dejar seguir si se confirma) o bloquear.';
                    ApplicationArea = All;
                    Editable = CambiarControlCapacidad;
                }
                field(CambiarAdmite; CambiarAdmite)
                {
                    Caption = 'Cambiar qué admite';
                    ToolTip = 'Marque para cambiar qué admite el hueco.';
                    ApplicationArea = All;
                }
                field(Admite; Admite)
                {
                    Caption = 'Admite';
                    ToolTip = 'Palé (el palé del producto y cajas de una referencia), Caja (cajas sueltas), Unidad (botellas sueltas) o en blanco (sin configurar: no se propone). Caja y Unidad marcan "Acepta múltiples productos"; Palé lo quita.';
                    ApplicationArea = All;
                    Editable = CambiarAdmite;
                }
                field(CambiarMezcla; CambiarMezcla)
                {
                    Caption = 'Cambiar mezcla de productos';
                    ToolTip = 'Marque para cambiar si aceptan varios productos.';
                    ApplicationArea = All;
                }
                field(Mezcla; Mezcla)
                {
                    Caption = 'Acepta múltiples productos';
                    ToolTip = 'Solo se puede marcar en ubicaciones que admiten Caja (las mixtas).';
                    ApplicationArea = All;
                    Editable = CambiarMezcla;
                }
                field(CambiarTipoUbicacion; CambiarTipoUbicacion)
                {
                    Caption = 'Cambiar tipo de ubicación';
                    ToolTip = 'Marque para cambiar el uso de la ubicación.';
                    ApplicationArea = All;
                }
                field(TipoUbicacion; TipoUbicacion)
                {
                    Caption = 'Tipo ubicación';
                    ToolTip = 'Uso de la ubicación. Solo las de Picking y Reserva se proponen al ubicar.';
                    ApplicationArea = All;
                    Editable = CambiarTipoUbicacion;
                }
                field(CambiarZona; CambiarZona)
                {
                    Caption = 'Cambiar zona';
                    ToolTip = 'Marque para cambiar la zona.';
                    ApplicationArea = All;
                }
                field(Zona; Zona)
                {
                    Caption = 'Zona';
                    ToolTip = 'Zona a la que pasan las ubicaciones.';
                    ApplicationArea = All;
                    TableRelation = "Zona SGA".Code;
                    Editable = CambiarZona;
                }
            }
        }
    }

    var
        rSeleccion: Record "Ubicacion SGA";
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        Resumen: Text;
        CambiarCapacidad: Boolean;
        Capacidad: Decimal;
        CambiarControlCapacidad: Boolean;
        ControlCapacidad: Enum "Control Capacidad Ubic. SGA";
        CambiarAdmite: Boolean;
        Admite: Enum "Tipo UM SGA";
        CambiarMezcla: Boolean;
        Mezcla: Boolean;
        CambiarTipoUbicacion: Boolean;
        TipoUbicacion: Enum "Tipo Ubicacion SGA";
        CambiarZona: Boolean;
        Zona: Code[10];
        Omitidas: Integer;
        OmitidasEjemplo: Text;

    /// <summary>
    /// Recibe las ubicaciones a cambiar (con sus filtros de selección).
    /// </summary>
    procedure Inicializar(var prm_Seleccion: Record "Ubicacion SGA")
    var
        conContenidoNum: Integer;
        NumUbicacionesLbl: Label '%1 ubicaciones', Comment = '%1 = número';
        ConContenidoLbl: Label ' (%1 con contenido: no se cambiarán)', Comment = '%1 = número';
    begin
        rSeleccion.Copy(prm_Seleccion);
        Resumen := StrSubstNo(NumUbicacionesLbl, rSeleccion.Count());
        conContenidoNum := cUbicaciones.ContarConContenido(rSeleccion);
        if conContenidoNum > 0 then
            Resumen += StrSubstNo(ConContenidoLbl, conContenidoNum);
    end;

    /// <summary>
    /// Aplica lo marcado a la selección con Cod. "Gestion Ubicaciones SGA". Devuelve cuántas
    /// ubicaciones se han cambiado; las que tienen contenido se saltan y lo dice
    /// UbicacionesOmitidas.
    /// </summary>
    procedure Aplicar(): Integer
    var
        TempPlantilla: Record "Ubicacion SGA" temporary;
    begin
        // La plantilla solo lleva los valores: se asignan sin validar, porque las validaciones
        // de la tabla son para una ubicación de verdad.
        TempPlantilla."Tipo UM Admitida" := Admite;
        TempPlantilla."Permite Mezcla Producto" := Mezcla;
        TempPlantilla."Capacidad Uds." := Capacidad;
        TempPlantilla."Control Capacidad" := ControlCapacidad;
        TempPlantilla."Tipo Ubicacion" := TipoUbicacion;
        TempPlantilla."Cod. Zona SGA" := Zona;

        exit(cUbicaciones.AplicarCambiosUbicaciones(rSeleccion, TempPlantilla, CambiarCapacidad, CambiarControlCapacidad,
                                                    CambiarAdmite, CambiarMezcla, CambiarTipoUbicacion, CambiarZona,
                                                    Omitidas, OmitidasEjemplo));
    end;

    /// <summary>
    /// Ubicaciones de la selección que no se han cambiado por tener contenido, y las primeras
    /// de ellas (hasta 5) para decírselo al usuario.
    /// </summary>
    procedure UbicacionesOmitidas(var prm_Ejemplo: Text): Integer
    begin
        prm_Ejemplo := OmitidasEjemplo;
        exit(Omitidas);
    end;
}
