namespace AntonioNadal.SGA;

using Microsoft.Inventory.Location;
using System.Security.AccessControl;

/// <summary>
/// Table Orden Picking SGA (ID 51108).
/// Cabecera de una orden de trabajo de almacén: qué documento hay que preparar, quién lo
/// prepara y en qué estado va.
///
/// La orden no mueve stock por sí misma. Quien mueve es Cod. "Gestion Contenido SGA" cuando
/// el preparador confirma cada línea, de modo que la orden es solo el guion del recorrido.
/// </summary>
table 51108 "Orden Picking SGA"
{
    Caption = 'Orden de picking SGA';
    DataClassification = ToBeClassified;
    LookupPageId = "Ordenes Picking SGA";
    DrillDownPageId = "Ordenes Picking SGA";

    fields
    {
        field(10; "No. Orden"; Code[20])
        {
            Caption = 'Nº orden';
            DataClassification = ToBeClassified;
            NotBlank = true;
        }
        field(20; "Cod. Almacen"; Code[10])
        {
            Caption = 'Cód. almacén';
            DataClassification = ToBeClassified;
            TableRelation = Location;
        }
        field(30; "Origen"; Enum "Origen Mov. SGA")
        {
            Caption = 'Origen';
            DataClassification = ToBeClassified;
            ToolTip = 'Flujo del que procede la orden. Se traslada al diario de movimientos al confirmar.';
        }
        field(31; "No. Documento Origen"; Code[20])
        {
            Caption = 'Nº documento origen';
            DataClassification = ToBeClassified;
            ToolTip = 'Documento que hay que preparar, por ejemplo el pedido de venta.';
        }
        field(40; Estado; Enum "Estado Orden SGA")
        {
            Caption = 'Estado';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(50; "Cod. Usuario Asignado"; Code[50])
        {
            Caption = 'Asignada a';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = User."User Name";
            ValidateTableRelation = false;
            ToolTip = 'Preparador que tiene asignada la orden.';

            trigger OnValidate()
            begin
                ValidarAsignacion();
            end;
        }
        field(51; Prioridad; Integer)
        {
            Caption = 'Prioridad';
            DataClassification = ToBeClassified;
            MinValue = 0;
            ToolTip = 'Cuanto mayor, antes le sale al preparador con "Siguiente orden". A igual prioridad, la más antigua primero.';

            trigger OnValidate()
            var
                cPicking: Codeunit "Gestion Picking SGA";
            begin
                cPicking.ComprobarResponsablePicking();
            end;
        }
        field(60; Descripcion; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = ToBeClassified;
        }
        field(61; "Nombre Cliente"; Text[100])
        {
            Caption = 'Cliente';
            DataClassification = ToBeClassified;
            Editable = false;
            ToolTip = 'Cliente del pedido de venta, copiado al crear la orden.';
        }
        field(62; "Fecha Envio"; Date)
        {
            Caption = 'Fecha envío';
            DataClassification = ToBeClassified;
            Editable = false;
            ToolTip = 'Fecha de envío del pedido de venta, copiada al crear la orden. Sirve para decidir qué preparar antes.';
        }
        field(70; "Fecha Creacion"; DateTime)
        {
            Caption = 'Fecha creación';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(71; "Fecha Finalizacion"; DateTime)
        {
            Caption = 'Fecha finalización';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(80; "Cod. Usuario Creacion"; Code[50])
        {
            Caption = 'Creada por';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
        }
        field(90; "Fecha Paso a Documento"; DateTime)
        {
            Caption = 'Pasada al pedido';
            DataClassification = ToBeClassified;
            Editable = false;
            ToolTip = 'Última vez que lo recogido se pasó al pedido de venta (cantidad a enviar y lotes). En blanco si todavía no se ha pasado.';
        }
        field(100; "No. Lineas"; Integer)
        {
            Caption = 'Nº líneas';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Linea Orden Picking SGA" where("No. Orden" = field("No. Orden")));
        }
        field(101; "Lineas Pendientes"; Integer)
        {
            Caption = 'Líneas pendientes';
            Editable = false;
            FieldClass = FlowField;
            // El mismo filtro que "Linea Orden Picking SGA".FiltrarPendientes: una CalcFormula
            // no puede llamar a un procedimiento.
            CalcFormula = count("Linea Orden Picking SGA" where("No. Orden" = field("No. Orden"),
                                                                Estado = filter(Pendiente | Parcial)));
        }
        field(102; "Cantidad Pendiente"; Decimal)
        {
            Caption = 'Unidades pendientes';
            Editable = false;
            FieldClass = FlowField;
            DecimalPlaces = 0 : 5;
            CalcFormula = sum("Linea Orden Picking SGA"."Cantidad Pendiente" where("No. Orden" = field("No. Orden")));
            ToolTip = 'Suma de lo que queda por recoger, en unidades base. Da idea del trabajo que queda en la orden.';
        }
    }

    keys
    {
        key(PK; "No. Orden")
        {
            Clustered = true;
        }
        key(Estado; "Cod. Almacen", Estado)
        {
        }
        key(Asignada; "Cod. Usuario Asignado", Estado)
        {
        }
        key(Reparto; Estado, Prioridad, "No. Orden")
        {
        }
        key(Documento; "No. Documento Origen")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No. Orden", "No. Documento Origen", Estado)
        {
        }
        fieldgroup(Brick; "No. Orden", "No. Documento Origen", Estado, "Lineas Pendientes")
        {
        }
    }

    trigger OnInsert()
    begin
        "Fecha Creacion" := CurrentDateTime();
        "Cod. Usuario Creacion" := CopyStr(UserId(), 1, MaxStrLen("Cod. Usuario Creacion"));
    end;

    trigger OnDelete()
    var
        rLinea: Record "Linea Orden Picking SGA";
        OrdenConRecogidasErr: Label 'No se puede eliminar la orden %1 porque ya tiene líneas recogidas. Cancélela en su lugar.', Comment = '%1 = nº orden';
    begin
        rLinea.SetRange("No. Orden", "No. Orden");
        rLinea.SetFilter("Cantidad Recogida", '>%1', 0);
        if not rLinea.IsEmpty() then
            Error(OrdenConRecogidasErr, "No. Orden");

        rLinea.Reset();
        rLinea.SetRange("No. Orden", "No. Orden");
        rLinea.DeleteAll(true);
    end;

    /// <summary>
    /// Recalcula el estado a partir de sus líneas. No hace Modify: decide el llamante.
    /// </summary>
    procedure RecalcularEstado()
    var
        rLinea: Record "Linea Orden Picking SGA";
        pendientes: Integer;
        recogidas: Integer;
    begin
        if Estado = Estado::Cancelada then
            exit;

        rLinea.SetRange("No. Orden", "No. Orden");
        rLinea.SetFilter(Estado, '<>%1', rLinea.Estado::Cancelada);
        if rLinea.IsEmpty() then begin
            Estado := EstadoSinEmpezar();
            exit;
        end;

        rLinea.FiltrarPendientes();
        pendientes := rLinea.Count();

        rLinea.SetRange(Estado, rLinea.Estado::Recogida);
        recogidas := rLinea.Count();

        case true of
            pendientes = 0:
                begin
                    Estado := Estado::Finalizada;
                    if "Fecha Finalizacion" = 0DT then
                        "Fecha Finalizacion" := CurrentDateTime();
                end;
            recogidas > 0:
                Estado := Estado::"En Proceso";
            else
                Estado := EstadoSinEmpezar();
        end;
    end;

    /// <summary>
    /// Avance del recorrido: paradas ya recogidas de las que cuentan, que son todas menos las
    /// canceladas. Solo usa "No. Orden", así que sirve sin leer la orden.
    /// </summary>
    procedure Progreso(var prm_Hechas: Integer; var prm_Total: Integer)
    var
        rLinea: Record "Linea Orden Picking SGA";
    begin
        rLinea.SetRange("No. Orden", "No. Orden");
        rLinea.SetFilter(Estado, '<>%1', rLinea.Estado::Cancelada);
        prm_Total := rLinea.Count();

        rLinea.SetRange(Estado, rLinea.Estado::Recogida);
        prm_Hechas := rLinea.Count();
    end;

    /// <summary>
    /// Estado de una orden que todavía no se ha empezado a recoger: pendiente de asignar si la
    /// configuración exige asignación y nadie la tiene; abierta en cualquier otro caso.
    /// </summary>
    procedure EstadoSinEmpezar(): Enum "Estado Orden SGA"
    var
        rConfig: Record "Config. SGA";
    begin
        rConfig.ObtenerConfig();
        if rConfig."Exigir Asignacion Picking" and ("Cod. Usuario Asignado" = '') then
            exit(Estado::"Pendiente Asignar");

        exit(Estado::Abierta);
    end;

    /// <summary>
    /// Indica si la orden sigue viva: pendiente de asignar, abierta o en proceso.
    /// </summary>
    procedure EstaViva(): Boolean
    begin
        exit(Estado in [Estado::"Pendiente Asignar", Estado::Abierta, Estado::"En Proceso"]);
    end;

    /// <summary>
    /// Al cambiar el preparador, una orden sin empezar pasa de pendiente de asignar a abierta
    /// o al revés. Una orden ya empezada se puede reasignar, pero no dejar sin nadie si la
    /// configuración exige asignación: quedaría a medias sin que nadie la vea.
    /// </summary>
    local procedure ValidarAsignacion()
    var
        rConfig: Record "Config. SGA";
        cPicking: Codeunit "Gestion Picking SGA";
        OrdenNoAsignableErr: Label 'La orden %1 está %2 y ya no se puede asignar.', Comment = '%1 = nº orden, %2 = estado';
        OrdenEmpezadaSinAsignarErr: Label 'La orden %1 ya está empezada. Reasígnela a otro preparador en lugar de dejarla sin asignar.', Comment = '%1 = nº orden';
    begin
        cPicking.ComprobarResponsablePicking();

        if not EstaViva() then
            Error(OrdenNoAsignableErr, "No. Orden", Estado);

        if Estado = Estado::"En Proceso" then begin
            rConfig.ObtenerConfig();
            if rConfig."Exigir Asignacion Picking" and ("Cod. Usuario Asignado" = '') then
                Error(OrdenEmpezadaSinAsignarErr, "No. Orden");
            exit;
        end;

        Estado := EstadoSinEmpezar();
    end;

    /// <summary>
    /// Estilo de la fecha de envío: en rojo si ya ha llegado o ha pasado.
    /// </summary>
    procedure EstiloFechaEnvio(): Text
    begin
        if ("Fecha Envio" <> 0D) and ("Fecha Envio" <= WorkDate()) then
            exit('Unfavorable');

        exit('Standard');
    end;

    /// <summary>
    /// Expresión de estilo para las páginas.
    /// </summary>
    procedure EstiloEstado(): Text
    begin
        case Estado of
            Estado::"Pendiente Asignar":
                exit('Attention');
            Estado::Abierta:
                exit('Standard');
            Estado::"En Proceso":
                exit('Ambiguous');
            Estado::Finalizada:
                exit('Favorable');
            Estado::Cancelada:
                exit('Subordinate');
        end;

        exit('Standard');
    end;
}
