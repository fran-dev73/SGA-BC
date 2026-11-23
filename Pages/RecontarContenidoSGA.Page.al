namespace AntonioNadal.SGA;

/// <summary>
/// Page Recontar Contenido SGA (ID 51115).
/// Diálogo de recuento de una línea de contenido: muestra lo que consta, pide lo que se ha
/// contado realmente y al aceptar registra la diferencia (RegistrarRecuento de Cod. "Gestion
/// Contenido SGA"). Si no se puede, da el error y el diálogo sigue abierto.
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
                field(SSCC; SSCC)
                {
                    Caption = 'SSCC';
                    ToolTip = 'Palé que se está recontando.';
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
        Almacen: Code[10];
        Ubicacion: Code[20];
        Producto: Code[20];
        Lote: Code[50];
        SSCC: Code[20];
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
        Almacen := rContenido."Cod. Almacen";
        Ubicacion := rContenido."Cod. Bin";
        Producto := rContenido."No. Producto";
        Lote := rContenido."No. Lote";
        SSCC := rContenido.SSCC;
        CantidadRegistrada := rContenido."Cantidad Base";
        CantidadContada := rContenido."Cantidad Base";
        Motivo := RecuentoManualLbl;
        CalcularDiferencia();
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        cContenido: Codeunit "Gestion Contenido SGA";
        SinDiferenciaMsg: Label 'No había diferencia: la cantidad contada coincide con la registrada.';
    begin
        if CloseAction <> Action::OK then
            exit(true);
        if cContenido.RegistrarRecuento(Almacen, Ubicacion, Producto, Lote, SSCC, CantidadContada, Motivo) = 0 then
            Message(SinDiferenciaMsg);
        exit(true);
    end;

    local procedure CalcularDiferencia()
    begin
        Diferencia := Round(CantidadContada - CantidadRegistrada, 0.00001);
    end;
}
