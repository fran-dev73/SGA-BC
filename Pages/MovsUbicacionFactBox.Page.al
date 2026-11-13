namespace AntonioNadal.SGA;

/// <summary>
/// Page Movs. Ubicacion FactBox (ID 51110).
/// Factbox con los últimos movimientos de ubicación, del más reciente al más antiguo.
/// </summary>
page 51110 "Movs. Ubicacion FactBox"
{
    Caption = 'Últimos movimientos SGA';
    PageType = ListPart;
    SourceTable = "Movimiento Ubicacion SGA";
    ApplicationArea = All;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    SourceTableView = sorting("No. Movimiento") order(descending);

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Fecha-Hora Registro"; Rec."Fecha-Hora Registro")
                {
                    ToolTip = 'Momento exacto en que se registró el movimiento.';
                    ApplicationArea = All;
                }
                field("Tipo Movimiento"; Rec."Tipo Movimiento")
                {
                    ToolTip = 'Naturaleza del movimiento.';
                    ApplicationArea = All;
                }
                field(Recorrido; RecorridoTexto)
                {
                    Caption = 'Recorrido';
                    ToolTip = 'Ubicación de origen y de destino del movimiento.';
                    ApplicationArea = All;
                }
                field("No. Producto"; Rec."No. Producto")
                {
                    ToolTip = 'Producto movido.';
                    ApplicationArea = All;
                }
                field("No. Lote"; Rec."No. Lote")
                {
                    ToolTip = 'Lote movido.';
                    ApplicationArea = All;
                }
                field("Cantidad Base"; Rec."Cantidad Base")
                {
                    ToolTip = 'Cantidad aplicada al contenido, en unidades base.';
                    ApplicationArea = All;
                }
                field("Cod. Usuario"; Rec."Cod. Usuario")
                {
                    ToolTip = 'Usuario que registró el movimiento.';
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(VerTodos)
            {
                Caption = 'Ver todos';
                ToolTip = 'Abre el diario de movimientos de ubicación con el mismo filtro que el FactBox.';
                ApplicationArea = All;
                Image = Entries;

                trigger OnAction()
                var
                    rMovimiento: Record "Movimiento Ubicacion SGA";
                begin
                    // Los filtros del enlace con la página que contiene el FactBox van en el grupo 4.
                    Rec.FilterGroup(4);
                    rMovimiento.CopyFilters(Rec);
                    Rec.FilterGroup(0);
                    Page.Run(Page::"Movs. Ubicacion SGA", rMovimiento);
                end;
            }
        }
    }

    var
        RecorridoTexto: Text;

    trigger OnAfterGetRecord()
    begin
        RecorridoTexto := Rec.Recorrido();
    end;
}
