namespace AntonioNadal.SGA;

/// <summary>
/// Page Cambiar Ubicaciones SGA (ID 51126).
/// Diálogo para cambiar de golpe los datos de gestión de muchas ubicaciones: capacidad, qué
/// admiten, tipo de uso, zona y mezcla de productos. Lo abre la lista de ubicaciones con las
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
        Resumen: Text;
        CambiarCapacidad: Boolean;
        Capacidad: Decimal;
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
        conContenidoNum := ConContenido(rSeleccion);
        if conContenidoNum > 0 then
            Resumen += StrSubstNo(ConContenidoLbl, conContenidoNum);
    end;

    /// <summary>
    /// Aplica lo marcado. Primero qué admite y luego la mezcla, porque la mezcla depende de que
    /// el hueco sea de caja. Devuelve cuántas ubicaciones se han cambiado.
    /// Las que tienen contenido se saltan: su configuración solo se cambia vacías (TestVacia de
    /// la tabla). Cuántas y cuáles se saltaron lo dice Omitidas.
    /// </summary>
    procedure Aplicar(): Integer
    var
        rUbicacion: Record "Ubicacion SGA";
        hechas: Integer;
        NadaQueCambiarErr: Label 'No ha marcado nada que cambiar.';
    begin
        if not (CambiarCapacidad or CambiarAdmite or CambiarMezcla or CambiarTipoUbicacion or CambiarZona) then
            Error(NadaQueCambiarErr);

        Omitidas := 0;
        OmitidasEjemplo := '';
        rUbicacion.Copy(rSeleccion);
        if not rUbicacion.FindSet(true) then
            exit(0);

        repeat
            if rUbicacion.EstaVacia() then begin
                if CambiarAdmite then
                    rUbicacion.Validate("Tipo UM Admitida", Admite);
                if CambiarMezcla then
                    rUbicacion.Validate("Permite Mezcla Producto", Mezcla);
                if CambiarCapacidad then
                    rUbicacion.Validate("Capacidad Uds.", Capacidad);
                if CambiarTipoUbicacion then
                    rUbicacion.Validate("Tipo Ubicacion", TipoUbicacion);
                if CambiarZona then
                    rUbicacion."Cod. Zona SGA" := Zona;
                // Con capacidad o clase nuevas, el % de ocupación y el estado cambian.
                rUbicacion.RecalcularOcupacion();
                rUbicacion.Modify(true);
                hechas += 1;
            end else begin
                Omitidas += 1;
                if Omitidas <= 5 then begin
                    if OmitidasEjemplo <> '' then
                        OmitidasEjemplo += ', ';
                    OmitidasEjemplo += rUbicacion."Cod. Bin";
                end;
            end;
        until rUbicacion.Next() = 0;

        exit(hechas);
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

    local procedure ConContenido(var prm_Seleccion: Record "Ubicacion SGA"): Integer
    var
        rUbicacion: Record "Ubicacion SGA";
        n: Integer;
    begin
        rUbicacion.Copy(prm_Seleccion);
        if rUbicacion.FindSet() then
            repeat
                if not rUbicacion.EstaVacia() then
                    n += 1;
            until rUbicacion.Next() = 0;
        exit(n);
    end;
}
