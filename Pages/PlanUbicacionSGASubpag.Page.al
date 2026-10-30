namespace AntonioNadal.SGA;

/// <summary>
/// Page Plan Ubicacion SGA Subpag (ID 51130).
/// Tabla de "Ubicar producto" con el reparto propuesto: un trozo por línea, su hueco y si se ha
/// podido ubicar o por qué no. Comparte la tabla temporal con la página madre (Cargar), así que
/// lo que se cambia aquí lo ve ella al confirmar.
/// </summary>
page 51130 "Plan Ubicacion SGA Subpag"
{
    Caption = 'Reparto';
    PageType = ListPart;
    SourceTable = "Linea Plan Ubicacion SGA";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lineas)
            {
                field(Paso; Rec.Paso)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Qué parte de la mercancía es: cada palé, las cajas o las unidades sueltas.';
                }
                field(Cantidad; Rec.Cantidad)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Cuánto, en la unidad de la línea.';
                }
                field("Cod. Unidad Medida"; Rec."Cod. Unidad Medida")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Unidad en la que se ubica: palé, unidad de venta o unidad base.';
                }
                field("Ubicacion Propuesta"; Rec."Ubicacion Propuesta")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Hueco que propone el sistema.';
                }
                field("Ubicacion Confirmada"; Rec."Ubicacion Confirmada")
                {
                    ApplicationArea = All;
                    Editable = Rec.Estado <> Rec.Estado::Ubicado;
                    Style = Strong;
                    ToolTip = 'Hueco en el que se deja. Sale el propuesto; escanee o teclee otro si lo deja en otro sitio.';
                }
                field(Estado; Rec.Estado)
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = EstiloEstado;
                    ToolTip = 'Pendiente de confirmar, ya ubicado o sin sitio.';
                }
                field(Motivo; Rec.Motivo)
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = EstiloEstado;
                    ToolTip = 'Por qué se propone ese hueco o por qué no se puede ubicar.';
                }
            }
        }
    }

    var
        EstiloEstado: Text;

    trigger OnAfterGetRecord()
    begin
        case Rec.Estado of
            Rec.Estado::Ubicado:
                EstiloEstado := 'Favorable';
            Rec.Estado::"Sin Sitio":
                EstiloEstado := 'Unfavorable';
            else
                EstiloEstado := 'Standard';
        end;
    end;

    /// <summary>
    /// Enseña las líneas de la madre compartiendo su tabla temporal.
    /// </summary>
    procedure Cargar(var prm_Lineas: Record "Linea Plan Ubicacion SGA")
    begin
        Rec.Copy(prm_Lineas, true);
        Rec.Reset();
        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    /// <summary>
    /// Línea seleccionada. 0 si no hay ninguna.
    /// </summary>
    procedure LineaActual(): Integer
    begin
        exit(Rec.Linea);
    end;
}
