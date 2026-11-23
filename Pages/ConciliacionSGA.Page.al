namespace AntonioNadal.SGA;

/// <summary>
/// Page Conciliacion SGA (ID 51113).
/// Resultado de la última conciliación: qué stock de BC no está ubicado en ninguna parte
/// y qué contenido sobra en las ubicaciones respecto a las existencias reales.
///
/// Es el control que evita que la capa de ubicaciones se degrade con el tiempo.
/// </summary>
page 51113 "Conciliacion SGA"
{
    Caption = 'Conciliación SGA vs stock';
    PageType = List;
    SourceTable = "Buffer Conciliacion SGA";
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    SourceTableView = sorting("Cod. Usuario", Diferencia);

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("No. Producto"; Rec."No. Producto")
                {
                    ToolTip = 'Producto con diferencia entre el stock de BC y el contenido de ubicaciones.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field(Descripcion; Rec.Descripcion)
                {
                    ApplicationArea = All;
                }
                field("Cod. Almacen"; Rec."Cod. Almacen")
                {
                    ToolTip = 'Almacén al que corresponde la diferencia.';
                    ApplicationArea = All;
                }
                field("No. Lote"; Rec."No. Lote")
                {
                    ToolTip = 'Lote al que corresponde la diferencia.';
                    ApplicationArea = All;
                }
                field("Stock BC"; Rec."Stock BC")
                {
                    ApplicationArea = All;
                    ToolTip = 'Existencias del lote en BC, en el almacén. Pulse para ver los movimientos de producto abiertos de los que sale.';

                    trigger OnDrillDown()
                    var
                        cStock: Codeunit "Consulta Stock SGA";
                    begin
                        cStock.MostrarStockBC(Rec);
                    end;
                }
                field("Stock SGA"; Rec."Stock SGA")
                {
                    ApplicationArea = All;
                    ToolTip = 'Lo que hay del lote en ubicaciones de SGA. Pulse para ver en qué ubicaciones está.';

                    trigger OnDrillDown()
                    var
                        cStock: Codeunit "Consulta Stock SGA";
                    begin
                        cStock.ConsultarUbicacionesProducto(Rec."No. Producto", Rec."Cod. Almacen", Rec."No. Lote");
                    end;
                }
                field(Diferencia; Rec.Diferencia)
                {
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field("Unidad Medida Base"; Rec."Unidad Medida Base")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(VolverAConciliar)
            {
                Caption = 'Volver a conciliar';
                ToolTip = 'Ejecuta de nuevo la comparación entre el stock de BC y el contenido de ubicaciones.';
                ApplicationArea = All;
                Image = Balance;
                RunObject = report "Conciliacion SGA vs Stock";
            }
            action(Regularizar)
            {
                Caption = 'Regularizar en ubicación de ajustes';
                ToolTip = 'Cuadra la línea seleccionada moviendo la diferencia contra la ubicación de ajustes configurada. Solo afecta a la capa de ubicaciones: no genera movimiento de producto ni cambia el stock de BC.';
                ApplicationArea = All;
                Image = AdjustEntries;

                trigger OnAction()
                var
                    cStock: Codeunit "Consulta Stock SGA";
                begin
                    if cStock.RegularizarConciliacion(Rec) then
                        CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(VolverAConciliar_Promoted; VolverAConciliar)
                {
                }
                actionref(Regularizar_Promoted; Regularizar)
                {
                }
            }
        }
    }

    views
    {
        view(SinUbicar)
        {
            Caption = 'Stock sin ubicar';
            Filters = where(Diferencia = filter(> 0));
        }
        view(SobraEnSGA)
        {
            Caption = 'Sobra en ubicaciones';
            Filters = where(Diferencia = filter(< 0));
        }
    }

    var
        EstiloFila: Text;

    trigger OnOpenPage()
    begin
        Rec.FilterGroup(2);
        Rec.FiltrarUsuarioActual();
        Rec.FilterGroup(0);
    end;

    trigger OnAfterGetRecord()
    begin
        EstiloFila := Rec.EstiloConciliacion();
    end;
}
