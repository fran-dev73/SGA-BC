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
        rConfig: Record "Config. SGA";
        rBuffer: Record "Buffer Conciliacion SGA";
        cContenido: Codeunit "Gestion Contenido SGA";
        noMovimiento: Integer;
        LineaYaCuadraMsg: Label 'Esta línea ya cuadra.';
        UbicAjustesSinConfigurarErr: Label 'Debe configurar la ubicación de ajustes en la configuración de SGA.';
        ColocarEnAjustesQst: Label 'Se van a colocar %1 unidades de %2 en la ubicación de ajustes %3, para que dejen de estar sin ubicar. El stock de BC no cambia. ¿Desea continuar?', Comment = '%1 = diferencia, %2 = producto, %3 = ubicación de ajustes';
        RegularizacionConciliacionLbl: Label 'Regularización conciliación';
        SobraContenidoMsg: Label 'En esta línea sobra contenido en las ubicaciones (%1 unidades de más). No se puede regularizar automáticamente, porque hay que decidir de qué ubicación sale el exceso: recuente las ubicaciones que contienen el producto.', Comment = '%1 = exceso';
    begin
        if Rec.Diferencia = 0 then begin
            Message(LineaYaCuadraMsg);
            exit;
        end;

        // El exceso en ubicaciones no se puede cuadrar solo: no sabemos de qué hueco sale.
        if Rec.Diferencia < 0 then begin
            Message(SobraContenidoMsg, -Rec.Diferencia);
            exit;
        end;

        rConfig.ObtenerConfig();
        if rConfig."Ubic. Ajustes" = '' then
            Error(UbicAjustesSinConfigurarErr);

        if not Confirm(ColocarEnAjustesQst, false, Rec.Diferencia, Rec."No. Producto", rConfig."Ubic. Ajustes") then
            exit;

        // El stock que BC tiene y SGA no aparece en la ubicación de ajustes hasta que
        // alguien lo coloque físicamente donde le corresponde.
        noMovimiento := cContenido.RegistrarAjuste(Rec."Cod. Almacen", rConfig."Ubic. Ajustes", Rec."No. Producto",
                                                   Rec."Cod. Variante", Rec."No. Lote", Rec."Unidad Medida Base",
                                                   Rec.Diferencia, RegularizacionConciliacionLbl);
        if noMovimiento = 0 then
            exit;

        if rBuffer.Get(Rec."Cod. Usuario", Rec."No. Producto", Rec."Cod. Variante", Rec."Cod. Almacen", Rec."No. Lote") then begin
            rBuffer."Stock SGA" := rBuffer."Stock BC";
            rBuffer.ActualizarEstado();
            rBuffer.Modify();
        end;

        CurrPage.Update(false);
    end;
}
