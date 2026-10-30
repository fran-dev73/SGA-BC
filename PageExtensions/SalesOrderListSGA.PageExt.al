namespace AntonioNadal.SGA;

using Microsoft.Sales.Document;

/// <summary>
/// PageExtension Sales Order List SGA (ID 51108) extends Page "Sales Order List".
/// Enseña en la lista de pedidos cuánto está preparado en picking (Estado preparación SGA) y
/// deja ver solo los preparados o los parciales.
///
/// El estado se calcula al momento (ver EstadoPreparacionVenta) y no es un campo de la tabla,
/// así que no se puede filtrar con los filtros de la lista: las acciones marcan los pedidos que
/// cumplen y enseñan solo esos.
/// </summary>
pageextension 51108 "Sales Order List SGA" extends "Sales Order List"
{
    layout
    {
        addafter(Status)
        {
            field(EstadoPreparacionSGA; EstadoPreparacion)
            {
                Caption = 'Estado preparación SGA';
                ToolTip = 'Cuánto está preparado en picking de lo que queda por enviar: sin preparar, parcial o preparado. En blanco si no queda nada por enviar.';
                ApplicationArea = All;
                Editable = false;
                StyleExpr = EstiloPreparacion;
            }
        }
    }

    actions
    {
        addlast(processing)
        {
            group(SGA)
            {
                Caption = 'Almacén SGA';
                Image = Warehouse;

                action(VerPreparadosSGA)
                {
                    Caption = 'Ver preparados';
                    ToolTip = 'Enseña solo los pedidos con todo lo pendiente de enviar ya preparado en picking: listos para registrar el envío.';
                    ApplicationArea = All;
                    Image = FilterLines;

                    trigger OnAction()
                    begin
                        MostrarSoloEstado("Estado Preparacion SGA"::Preparado);
                    end;
                }
                action(VerParcialesSGA)
                {
                    Caption = 'Ver preparados en parte';
                    ToolTip = 'Enseña solo los pedidos con algo preparado en picking, pero no todo.';
                    ApplicationArea = All;
                    Image = FilterLines;

                    trigger OnAction()
                    begin
                        MostrarSoloEstado("Estado Preparacion SGA"::Parcial);
                    end;
                }
                action(VerTodosSGA)
                {
                    Caption = 'Ver todos';
                    ToolTip = 'Quita el filtro de preparación y vuelve a enseñar todos los pedidos.';
                    ApplicationArea = All;
                    Image = ClearFilter;

                    trigger OnAction()
                    begin
                        Rec.ClearMarks();
                        Rec.MarkedOnly(false);
                        CurrPage.Update(false);
                    end;
                }
            }
        }
        addafter(Category_Process)
        {
            group(Category_SGA)
            {
                Caption = 'Almacén SGA';

                actionref(VerPreparadosSGA_Promoted; VerPreparadosSGA)
                {
                }
                actionref(VerParcialesSGA_Promoted; VerParcialesSGA)
                {
                }
                actionref(VerTodosSGA_Promoted; VerTodosSGA)
                {
                }
            }
        }
    }

    var
        EstadoPreparacion: Enum "Estado Preparacion SGA";
        EstiloPreparacion: Text;

    trigger OnAfterGetRecord()
    var
        cPicking: Codeunit "Gestion Picking SGA";
    begin
        EstadoPreparacion := cPicking.EstadoPreparacionVenta(Rec);
        EstiloPreparacion := cPicking.EstiloEstadoPreparacion(EstadoPreparacion);
    end;

    /// <summary>
    /// Marca los pedidos de la vista actual que están en ese estado y enseña solo esos.
    /// </summary>
    local procedure MostrarSoloEstado(prm_Estado: Enum "Estado Preparacion SGA")
    var
        cPicking: Codeunit "Gestion Picking SGA";
    begin
        cPicking.MarcarVentasPorEstado(Rec, prm_Estado);
        CurrPage.Update(false);
    end;
}
