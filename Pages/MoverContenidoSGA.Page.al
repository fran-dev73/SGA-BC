namespace AntonioNadal.SGA;

using Microsoft.Warehouse.Structure;

/// <summary>
/// Page Mover Contenido SGA (ID 51114).
/// Diálogo de traslado: pregunta a dónde y cuánto se mueve, partiendo de una línea de
/// contenido concreta. No registra nada; el traslado lo hace Cod. "Gestion Contenido SGA".
/// </summary>
page 51114 "Mover Contenido SGA"
{
    Caption = 'Trasladar contenido';
    PageType = StandardDialog;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Origen)
            {
                Caption = 'Origen';

                field(Almacen; Almacen)
                {
                    Caption = 'Almacén';
                    ToolTip = 'Almacén en el que se hace el traslado.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(UbicacionOrigen; UbicacionOrigen)
                {
                    Caption = 'Ubicación origen';
                    ToolTip = 'Ubicación de la que se saca la mercancía.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Producto; Producto)
                {
                    Caption = 'Producto';
                    ToolTip = 'Producto que se traslada.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Lote; Lote)
                {
                    Caption = 'Lote';
                    ToolTip = 'Lote que se traslada.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(CantidadDisponible; CantidadDisponible)
                {
                    Caption = 'Cantidad disponible';
                    ToolTip = 'Cantidad libre en la ubicación de origen.';
                    ApplicationArea = All;
                    Editable = false;
                }
            }
            group(Destino)
            {
                Caption = 'Destino';

                field(UbicacionDestino; UbicacionDestino)
                {
                    Caption = 'Ubicación destino';
                    ToolTip = 'Ubicación a la que se lleva la mercancía.';
                    ApplicationArea = All;
                    ShowMandatory = true;
                    TableRelation = Bin;

                    trigger OnValidate()
                    var
                        MismaUbicacionErr: Label 'La ubicación de destino no puede ser la misma que la de origen.';
                    begin
                        if UbicacionDestino = UbicacionOrigen then
                            Error(MismaUbicacionErr);
                    end;
                }
                field(Cantidad; Cantidad)
                {
                    Caption = 'Cantidad';
                    ToolTip = 'Cantidad, en unidades base, que se traslada.';
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 5;
                    MinValue = 0;
                    ShowMandatory = true;

                    trigger OnValidate()
                    var
                        CantidadExcesivaErr: Label 'No puede trasladar más de %1 unidades.', Comment = '%1 = cantidad disponible';
                    begin
                        if Cantidad > CantidadDisponible then
                            Error(CantidadExcesivaErr, CantidadDisponible);
                    end;
                }
                field(Motivo; Motivo)
                {
                    Caption = 'Motivo';
                    ToolTip = 'Nota que queda registrada en el movimiento.';
                    ApplicationArea = All;
                }
            }
        }
    }

    var
        Almacen: Code[10];
        UbicacionOrigen: Code[20];
        UbicacionDestino: Code[20];
        Producto: Code[20];
        Lote: Code[50];
        CantidadDisponible: Decimal;
        Cantidad: Decimal;
        Motivo: Text[100];

    /// <summary>
    /// Carga el diálogo desde una línea de contenido y propone trasladarlo entero.
    /// </summary>
    procedure Inicializar(var rContenido: Record "Contenido Ubicacion SGA")
    begin
        Almacen := rContenido."Cod. Almacen";
        UbicacionOrigen := rContenido."Cod. Bin";
        Producto := rContenido."No. Producto";
        Lote := rContenido."No. Lote";
        CantidadDisponible := rContenido."Cantidad Disponible";
        Cantidad := rContenido."Cantidad Disponible";
    end;

    /// <summary>
    /// Deja propuesto el destino. Lo usa el mapa 3D, donde el destino ya se ha elegido
    /// arrastrando; el operario solo confirma la cantidad.
    /// </summary>
    procedure FijarDestino(prm_Destino: Code[20])
    var
        MismaUbicacionErr: Label 'La ubicación de destino no puede ser la misma que la de origen.';
    begin
        if prm_Destino = UbicacionOrigen then
            Error(MismaUbicacionErr);

        UbicacionDestino := prm_Destino;
    end;

    procedure ObtenerDestino(): Code[20]
    var
        DestinoObligatorioErr: Label 'Debe indicar la ubicación de destino.';
    begin
        if UbicacionDestino = '' then
            Error(DestinoObligatorioErr);

        exit(UbicacionDestino);
    end;

    procedure ObtenerCantidad(): Decimal
    var
        CantidadNoPositivaErr: Label 'Debe indicar una cantidad mayor que cero.';
    begin
        if Cantidad <= 0 then
            Error(CantidadNoPositivaErr);

        exit(Cantidad);
    end;

    procedure ObtenerMotivo(): Text[100]
    begin
        exit(Motivo);
    end;
}
