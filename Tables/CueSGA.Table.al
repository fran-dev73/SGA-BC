namespace AntonioNadal.SGA;

using Microsoft.Inventory.Location;

/// <summary>
/// Table Cue SGA (ID 51105).
/// Origen de las pilas de los rol center de almacén y del preparador. Todos los contadores
/// son FlowField count sobre las tablas de SGA, filtrados por los FlowFilter de almacén,
/// fecha, momento, fecha de envío y usuario (FiltrarCue): la base de datos los cuenta con sus
/// índices y la página los calcula todos a la vez al leer el registro, sin código que recorra.
/// </summary>
table 51105 "Cue SGA"
{
    Caption = 'Cue SGA';
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Clave primaria';
            DataClassification = ToBeClassified;
        }
        field(10; "Ubicaciones Totales"; Integer)
        {
            Caption = 'Ubicaciones totales';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen")));
        }
        field(11; "Ubicaciones Vacias"; Integer)
        {
            Caption = 'Ubicaciones vacías';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                      "Estado SGA" = const(Vacia)));
        }
        field(12; "Ubicaciones Parciales"; Integer)
        {
            Caption = 'Ubicaciones parciales';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                      "Estado SGA" = const(Parcial)));
        }
        field(13; "Ubicaciones Llenas"; Integer)
        {
            Caption = 'Ubicaciones llenas';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                      "Estado SGA" = const(Llena)));
        }
        field(14; "Ubicaciones Bloqueadas"; Integer)
        {
            Caption = 'Ubicaciones bloqueadas';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                      "Estado SGA" = const(Bloqueada)));
        }
        field(20; "Lineas Contenido"; Integer)
        {
            Caption = 'Líneas de contenido';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Contenido Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen")));
        }
        field(21; "Contenido Bloqueado"; Integer)
        {
            Caption = 'Contenido bloqueado';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Contenido Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                                Bloqueado = const(true)));
        }
        field(22; "Contenido Reservado"; Integer)
        {
            Caption = 'Contenido reservado';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Contenido Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                                "Cantidad Reservada" = filter(> 0)));
        }
        field(30; "Movimientos Periodo"; Integer)
        {
            Caption = 'Movimientos del periodo';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Movimiento Ubicacion SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                                 "Fecha Registro" = field("Filtro Fecha")));
        }
        field(40; "Paradas Retenidas"; Integer)
        {
            Caption = 'Paradas retenidas';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Linea Orden Picking SGA" where(Retenida = const(true),
                                                                "Cod. Almacen" = field("Filtro Almacen"),
                                                                Estado = filter(Pendiente | Parcial)));
        }
        // Picking del jefe de almacén. Las reubicaciones tienen su propia pila.
        field(41; "Ordenes Sin Asignar"; Integer)
        {
            Caption = 'Pendientes de asignar';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Orden Picking SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                          Estado = const("Pendiente Asignar"),
                                                          Origen = filter(<> Reposicion)));
        }
        field(42; "Ordenes Sin Empezar"; Integer)
        {
            Caption = 'Sin empezar';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Orden Picking SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                          Estado = const(Abierta),
                                                          Origen = filter(<> Reposicion)));
        }
        field(43; "Ordenes En Proceso"; Integer)
        {
            Caption = 'En proceso';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Orden Picking SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                          Estado = const("En Proceso"),
                                                          Origen = filter(<> Reposicion)));
        }
        field(44; "Ordenes Envio Vencido"; Integer)
        {
            Caption = 'Envío vencido';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Orden Picking SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                          Estado = filter("Pendiente Asignar" | Abierta | "En Proceso"),
                                                          Origen = filter(<> Reposicion),
                                                          "Fecha Envio" = field("Filtro Fecha Envio")));
        }
        field(45; "Ordenes Sin Pasar Pedido"; Integer)
        {
            Caption = 'Terminadas sin pasar al pedido';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Orden Picking SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                          Estado = const(Finalizada),
                                                          Origen = const(Venta),
                                                          "Fecha Paso a Documento" = const(0DT)));
        }
        field(46; "Ordenes Terminadas Hoy"; Integer)
        {
            Caption = 'Terminadas hoy';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Orden Picking SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                          Estado = const(Finalizada),
                                                          Origen = filter(<> Reposicion),
                                                          "Fecha Finalizacion" = field("Filtro Momento")));
        }
        field(47; "Reubicaciones Pendientes"; Integer)
        {
            Caption = 'Reubicaciones pendientes';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Linea Orden Picking SGA" where("Cod. Almacen" = field("Filtro Almacen"),
                                                                "Cod. Bin Destino" = filter(<> ''),
                                                                Estado = filter(Pendiente | Parcial)));
        }
        field(48; "Desvios Hoy"; Integer)
        {
            Caption = 'Desvíos de ubicación hoy';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Linea Orden Picking SGA" where(Desvio = const(true),
                                                                "Cod. Almacen" = field("Filtro Almacen"),
                                                                "Fecha Confirmacion" = field("Filtro Momento")));
        }
        // Picking del preparador: lo suyo, por "Filtro Usuario".
        field(60; "Mis Ordenes"; Integer)
        {
            Caption = 'Mis órdenes';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Orden Picking SGA" where("Cod. Usuario Asignado" = field("Filtro Usuario"),
                                                          Estado = filter(Abierta | "En Proceso"),
                                                          Origen = filter(<> Reposicion)));
        }
        field(61; "Mis Reubicaciones"; Integer)
        {
            Caption = 'Mis reubicaciones';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Orden Picking SGA" where("Cod. Usuario Asignado" = field("Filtro Usuario"),
                                                          Estado = filter(Abierta | "En Proceso"),
                                                          Origen = const(Reposicion)));
        }
        field(62; "Ordenes Disponibles"; Integer)
        {
            Caption = 'Disponibles';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Orden Picking SGA" where("Cod. Usuario Asignado" = const(''),
                                                          Estado = filter("Pendiente Asignar" | Abierta),
                                                          Origen = filter(<> Reposicion)));
        }
        field(90; "Filtro Almacen"; Code[10])
        {
            Caption = 'Filtro almacén';
            FieldClass = FlowFilter;
            TableRelation = Location;
        }
        field(91; "Filtro Fecha"; Date)
        {
            Caption = 'Filtro fecha';
            FieldClass = FlowFilter;
        }
        field(92; "Filtro Fecha Envio"; Date)
        {
            Caption = 'Filtro fecha envío';
            FieldClass = FlowFilter;
        }
        field(93; "Filtro Momento"; DateTime)
        {
            Caption = 'Filtro momento';
            FieldClass = FlowFilter;
        }
        field(94; "Filtro Usuario"; Code[50])
        {
            Caption = 'Filtro usuario';
            FieldClass = FlowFilter;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    /// <summary>
    /// Devuelve el registro de cues, creándolo la primera vez.
    /// </summary>
    procedure ObtenerCue()
    begin
        if not Get() then begin
            Init();
            Insert();
        end;
    end;

    /// <summary>
    /// Pone los filtros de las pilas: el almacén por defecto de la configuración, el usuario
    /// actual, la fecha de trabajo (movimientos), todo el día de trabajo (lo terminado o
    /// confirmado hoy) y las fechas de envío ya llegadas.
    /// </summary>
    procedure FiltrarCue()
    var
        rConfig: Record "Config. SGA";
        cPicking: Codeunit "Gestion Picking SGA";
    begin
        rConfig.ObtenerConfig();
        if rConfig."Almacen por Defecto" <> '' then
            SetRange("Filtro Almacen", rConfig."Almacen por Defecto");

        SetRange("Filtro Usuario", cPicking.UsuarioActual());
        SetRange("Filtro Fecha", WorkDate());
        SetRange("Filtro Momento", CreateDateTime(WorkDate(), 0T), CreateDateTime(WorkDate(), 235959.999T));
        // Sin fecha de envío no cuenta como vencida.
        SetFilter("Filtro Fecha Envio", '<>%1&<=%2', 0D, WorkDate());
    end;
}
