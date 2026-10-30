namespace AntonioNadal.SGA;

/// <summary>
/// Page Resultado Carga Inicial SGA (ID 51125).
/// Qué ha hecho (o haría, en simulación) la carga inicial: dónde ha ido cada palé y cada grupo
/// de cajas, y qué se ha quedado sin cargar y por qué. La abre el informe al terminar.
/// Las líneas son de "Linea Ubicacion SGA": cargado es Estado Ubicado; no cargado, "Sin Sitio".
/// </summary>
page 51125 "Resultado Carga Inicial SGA"
{
    Caption = 'Resultado de la carga inicial';
    PageType = List;
    SourceTable = "Linea Ubicacion SGA";
    SourceTableTemporary = true;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lineas)
            {
                field("No. Producto"; Rec."No. Producto")
                {
                    ToolTip = 'Producto.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field("Descripcion Producto"; Rec."Descripcion Producto")
                {
                    ToolTip = 'Descripción del producto.';
                    ApplicationArea = All;
                }
                field("Cod. Variante"; Rec."Cod. Variante")
                {
                    ToolTip = 'Variante del producto.';
                    ApplicationArea = All;
                    Visible = false;
                }
                field("No. Lote"; Rec."No. Lote")
                {
                    ToolTip = 'Lote.';
                    ApplicationArea = All;
                }
                field("Cod. Bin"; Rec."Ubicacion Confirmada")
                {
                    Caption = 'Ubicación';
                    ToolTip = 'Ubicación en la que se ha dejado. En blanco si no se ha cargado.';
                    ApplicationArea = All;
                    Style = Strong;
                    // Aquí es solo un dato que se lee: sin enlace a la ubicación de BC.
                    Lookup = false;
                    DrillDown = false;
                }
                field(Cantidad; Rec.Cantidad)
                {
                    ToolTip = 'Cantidad, en la unidad de medida de la línea.';
                    ApplicationArea = All;
                }
                field("Cod. Unidad Medida"; Rec."Cod. Unidad Medida")
                {
                    Caption = 'Unidad de medida';
                    ToolTip = 'Unidad de medida: palé, caja o la base del producto.';
                    ApplicationArea = All;
                }
                field("Cantidad Base"; Rec."Cantidad Base")
                {
                    ToolTip = 'La misma cantidad en la unidad de medida base.';
                    ApplicationArea = All;
                }
                field(Cargado; Cargado)
                {
                    Caption = 'Cargado';
                    ToolTip = 'Marcado si se ha dejado en una ubicación. Lo que no se carga sale en la conciliación como sin ubicar.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field(Motivo; Rec.Motivo)
                {
                    ToolTip = 'Por qué ha ido a esa ubicación, o por qué no se ha cargado.';
                    ApplicationArea = All;
                }
            }
        }
    }

    views
    {
        view(NoCargado)
        {
            Caption = 'No cargado';
            Filters = where(Estado = const("Sin Sitio"));
        }
        view(SoloCargado)
        {
            Caption = 'Cargado';
            Filters = where(Estado = const(Ubicado));
        }
    }

    var
        Cargado: Boolean;
        EstiloFila: Text;

    trigger OnAfterGetRecord()
    begin
        Cargado := Rec.Estado = Rec.Estado::Ubicado;
        EstiloFila := Rec.EstiloCargaInicial();
    end;

    /// <summary>
    /// Copia el resultado que ha preparado la carga inicial.
    /// </summary>
    procedure Rellenar(var prm_Resultado: Record "Linea Ubicacion SGA")
    begin
        Rec.Copy(prm_Resultado, true);
        Rec.Reset();
        if Rec.FindFirst() then;
    end;
}
