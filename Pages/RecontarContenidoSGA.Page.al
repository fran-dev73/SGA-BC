namespace AntonioNadal.SGA;

/// <summary>
/// Page Recontar Contenido SGA (ID 51115).
/// Diálogo de recuento de una línea de contenido: muestra lo que consta y pide lo que
/// se ha contado realmente. No registra nada; el ajuste lo hace Cod. "Gestion Contenido SGA".
/// </summary>
page 51115 "Recontar Contenido SGA"
{
    Caption = 'Recontar contenido SGA';
    PageType = StandardDialog;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Contexto)
            {
                Caption = 'Línea que se recuenta';

                field(Ubicacion; Ubicacion)
                {
                    Caption = 'Ubicación';
                    ToolTip = 'Ubicación que se está recontando.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Producto; Producto)
                {
                    Caption = 'Producto';
                    ToolTip = 'Producto que se está recontando.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Lote; Lote)
                {
                    Caption = 'Lote';
                    ToolTip = 'Lote que se está recontando.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(CantidadRegistrada; CantidadRegistrada)
                {
                    Caption = 'Cantidad registrada';
                    ToolTip = 'Cantidad que consta actualmente en SGA, en unidades base.';
                    ApplicationArea = All;
                    Editable = false;
                    DecimalPlaces = 0 : 5;
                }
            }
            group(Recuento)
            {
                Caption = 'Recuento';

                field(CantidadContada; CantidadContada)
                {
                    Caption = 'Cantidad contada';
                    ToolTip = 'Cantidad que hay realmente en la ubicación, en unidades base.';
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 5;
                    MinValue = 0;
                    ShowMandatory = true;

                    trigger OnValidate()
                    begin
                        CalcularDiferencia();
                    end;
                }
                field(Diferencia; Diferencia)
                {
                    Caption = 'Diferencia';
                    ToolTip = 'Diferencia que se va a registrar como movimiento de recuento.';
                    ApplicationArea = All;
                    Editable = false;
                    DecimalPlaces = 0 : 5;
                }
                field(Motivo; Motivo)
                {
                    Caption = 'Motivo';
                    ToolTip = 'Nota que queda registrada en el movimiento de recuento.';
                    ApplicationArea = All;
                }
            }
        }
    }

    var
        Ubicacion: Code[20];
        Producto: Code[20];
        Lote: Code[50];
        CantidadRegistrada: Decimal;
        CantidadContada: Decimal;
        Diferencia: Decimal;
        Motivo: Text[100];

    /// <summary>
    /// Carga el diálogo desde una línea de contenido, proponiendo la cantidad que ya consta.
    /// </summary>
    procedure Inicializar(var rContenido: Record "Contenido Ubicacion SGA")
    var
        RecuentoManualLbl: Label 'Recuento manual';
    begin
        Ubicacion := rContenido."Cod. Bin";
        Producto := rContenido."No. Producto";
        Lote := rContenido."No. Lote";
        CantidadRegistrada := rContenido."Cantidad Base";
        CantidadContada := rContenido."Cantidad Base";
        Motivo := RecuentoManualLbl;
        CalcularDiferencia();
    end;

    procedure ObtenerCantidadContada(): Decimal
    begin
        exit(CantidadContada);
    end;

    procedure ObtenerMotivo(): Text[100]
    begin
        exit(Motivo);
    end;

    local procedure CalcularDiferencia()
    begin
        Diferencia := Round(CantidadContada - CantidadRegistrada, 0.00001);
    end;
}
