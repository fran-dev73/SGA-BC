namespace AntonioNadal.SGA;

/// <summary>
/// Page Ubicaciones Producto FactBox (ID 51109).
/// Factbox para la ficha y la lista de productos: en qué ubicaciones está el producto
/// y cuánto hay en cada una.
/// </summary>
page 51109 "Ubicaciones Producto FactBox"
{
    Caption = 'Ubicaciones del producto SGA';
    PageType = ListPart;
    SourceTable = "Contenido Ubicacion SGA";
    ApplicationArea = All;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    SourceTableView = sorting("Cod. Almacen", "No. Producto", "Cod. Variante", Bloqueado, "Fecha Caducidad", "Cod. Bin");

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Cod. Almacen"; Rec."Cod. Almacen")
                {
                    ToolTip = 'Almacén en el que está la mercancía.';
                    ApplicationArea = All;
                }
                field("Cod. Bin"; Rec."Cod. Bin")
                {
                    ToolTip = 'Ubicación en la que está la mercancía.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field("No. Lote"; Rec."No. Lote")
                {
                    ToolTip = 'Lote que hay en esta ubicación.';
                    ApplicationArea = All;
                }
                field(SSCC; Rec.SSCC)
                {
                    ApplicationArea = All;
                }
                field("Fecha Caducidad"; Rec."Fecha Caducidad")
                {
                    ToolTip = 'Caducidad del lote.';
                    ApplicationArea = All;
                }
                field("Cantidad Base"; Rec."Cantidad Base")
                {
                    ToolTip = 'Unidades base que hay en esta ubicación.';
                    ApplicationArea = All;
                }
                field("Cantidad Disponible"; Rec."Cantidad Disponible")
                {
                    ToolTip = 'Unidades libres para recoger.';
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(VerTodas)
            {
                Caption = 'Ver todas';
                ToolTip = 'Abre la consulta completa de ubicaciones del producto.';
                ApplicationArea = All;
                Image = BinContent;

                trigger OnAction()
                var
                    rContenido: Record "Contenido Ubicacion SGA";
                begin
                    // Los filtros del enlace con la página que contiene el FactBox van en el grupo 4.
                    Rec.FilterGroup(4);
                    rContenido.CopyFilters(Rec);
                    Rec.FilterGroup(0);
                    Page.Run(Page::"Contenido Ubicaciones SGA", rContenido);
                end;
            }
        }
    }

    var
        EstiloFila: Text;

    trigger OnAfterGetRecord()
    begin
        EstiloFila := Rec.EstiloContenido();
    end;
}
