namespace AntonioNadal.SGA;

using Microsoft.Inventory.Ledger;

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
                    ToolTip = 'Descripción del producto.';
                    ApplicationArea = All;
                }
                field("Cod. Variante"; Rec."Cod. Variante")
                {
                    ToolTip = 'Variante del producto.';
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
                field(Estado; Rec.Estado)
                {
                    ToolTip = 'Cuadra, hay stock sin ubicar, o sobra contenido en las ubicaciones.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field("Stock BC"; Rec."Stock BC")
                {
                    ToolTip = 'Existencias según los movimientos de producto, en unidades base.';
                    ApplicationArea = All;
                }
                field("Stock SGA"; Rec."Stock SGA")
                {
                    ToolTip = 'Suma del contenido de todas las ubicaciones, en unidades base.';
                    ApplicationArea = All;
                }
                field(Diferencia; Rec.Diferencia)
                {
                    ToolTip = 'Stock BC menos stock SGA. Positivo significa que hay stock sin ubicar.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field("Unidad Medida Base"; Rec."Unidad Medida Base")
                {
                    ToolTip = 'Unidad de medida base del producto.';
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
                begin
                    RegularizarLinea();
                end;
            }
        }
        area(Navigation)
        {
            action(VerUbicaciones)
            {
                Caption = 'Ubicaciones del producto';
                ToolTip = 'Muestra en qué ubicaciones está el producto de la línea.';
                ApplicationArea = All;
                Image = BinContent;
                RunObject = page "Contenido Ubicaciones SGA";
                RunPageLink = "No. Producto" = field("No. Producto"),
                              "Cod. Almacen" = field("Cod. Almacen");
            }
            action(VerMovsProducto)
            {
                Caption = 'Movs. producto';
                ToolTip = 'Abre los movimientos de producto de BC del producto de la línea.';
                ApplicationArea = All;
                Image = Entries;
                RunObject = page "Item Ledger Entries";
                RunPageLink = "Item No." = field("No. Producto"),
                              "Location Code" = field("Cod. Almacen");
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
            group(Category_Navigate)
            {
                Caption = 'Producto';

                actionref(VerUbicaciones_Promoted; VerUbicaciones)
                {
                }
                actionref(VerMovsProducto_Promoted; VerMovsProducto)
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
            Filters = where(Estado = const("Sin Ubicar"));
        }
        view(SobraEnSGA)
        {
            Caption = 'Sobra en ubicaciones';
            Filters = where(Estado = const("Sobra en SGA"));
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

    local procedure RegularizarLinea()
    var
        cStock: Codeunit "Consulta Stock SGA";
    begin
        if cStock.RegularizarConciliacion(Rec) then
            CurrPage.Update(false);
    end;
}
