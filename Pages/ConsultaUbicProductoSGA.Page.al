namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;

/// <summary>
/// Page Consulta Ubic. Producto SGA (ID 51108).
/// Responde a "¿dónde está este producto?": lista las ubicaciones que lo contienen,
/// ordenadas por caducidad y por recorrido, para decir al operario a dónde ir a recogerlo.
/// </summary>
page 51108 "Consulta Ubic. Producto SGA"
{
    Caption = '¿Dónde está el producto?';
    PageType = List;
    SourceTable = "Contenido Ubicacion SGA";
    UsageCategory = Tasks;
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
            group(Filtros)
            {
                Caption = 'Búsqueda';

                field(FiltroProducto; FiltroProducto)
                {
                    Caption = 'Producto';
                    ToolTip = 'Producto que se quiere localizar.';
                    ApplicationArea = All;
                    TableRelation = Item;

                    trigger OnValidate()
                    begin
                        AplicarFiltros();
                    end;
                }
                field(FiltroAlmacen; FiltroAlmacen)
                {
                    Caption = 'Almacén';
                    ToolTip = 'Almacén en el que buscar. En blanco busca en todos.';
                    ApplicationArea = All;
                    TableRelation = Location;

                    trigger OnValidate()
                    begin
                        AplicarFiltros();
                    end;
                }
                field(FiltroLote; FiltroLote)
                {
                    Caption = 'Lote';
                    ToolTip = 'Lote concreto que se quiere localizar. En blanco busca todos los lotes.';
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        AplicarFiltros();
                    end;
                }
                field(SoloDisponible; SoloDisponible)
                {
                    Caption = 'Solo con cantidad disponible';
                    ToolTip = 'Oculta las ubicaciones bloqueadas y las que tienen todo reservado.';
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        AplicarFiltros();
                    end;
                }
                field(TotalUbicado; TotalUbicado)
                {
                    Caption = 'Total ubicado';
                    ToolTip = 'Suma en unidades base de todas las ubicaciones que cumplen la búsqueda.';
                    ApplicationArea = All;
                    Editable = false;
                    DecimalPlaces = 0 : 5;
                }
            }
            repeater(General)
            {
                field("Cod. Almacen"; Rec."Cod. Almacen")
                {
                    ToolTip = 'Almacén en el que está la mercancía.';
                    ApplicationArea = All;
                }
                field("Cod. Bin"; Rec."Cod. Bin")
                {
                    ToolTip = 'Ubicación a la que hay que ir.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field("Cod. Zona SGA"; Rec."Cod. Zona SGA")
                {
                    ToolTip = 'Zona de la ubicación.';
                    ApplicationArea = All;
                }
                field("Tipo Ubicacion"; Rec."Tipo Ubicacion")
                {
                    ToolTip = 'Uso funcional de la ubicación: primero conviene servir desde picking.';
                    ApplicationArea = All;
                }
                field("Secuencia Picking"; Rec."Secuencia Picking")
                {
                    ToolTip = 'Orden de recorrido físico de la ubicación.';
                    ApplicationArea = All;
                }
                field("No. Producto"; Rec."No. Producto")
                {
                    ToolTip = 'Producto localizado.';
                    ApplicationArea = All;
                }
                field(Descripcion; Rec.Descripcion)
                {
                    ToolTip = 'Descripción del producto.';
                    ApplicationArea = All;
                }
                field("No. Lote"; Rec."No. Lote")
                {
                    ToolTip = 'Lote que hay en esta ubicación.';
                    ApplicationArea = All;
                }
                field("Fecha Caducidad"; Rec."Fecha Caducidad")
                {
                    ToolTip = 'Caducidad del lote. Con estrategia FEFO se sirve primero el más próximo a caducar.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
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
                field(Bloqueado; Rec.Bloqueado)
                {
                    ToolTip = 'Si está activo, no se debe recoger de aquí.';
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(VerUbicacion)
            {
                Caption = 'Ficha de la ubicación';
                ToolTip = 'Abre la ficha SGA de la ubicación.';
                ApplicationArea = All;
                Image = BinContent;
                RunObject = page "Ficha Ubicacion SGA";
                RunPageLink = "Cod. Almacen" = field("Cod. Almacen"),
                              "Cod. Bin" = field("Cod. Bin");
            }
            action(VerMovimientos)
            {
                Caption = 'Movimientos';
                ToolTip = 'Muestra los movimientos de ubicación de este producto y lote.';
                ApplicationArea = All;
                Image = Entries;
                RunObject = page "Movs. Ubicacion SGA";
                RunPageLink = "No. Producto" = field("No. Producto"),
                              "No. Lote" = field("No. Lote");
            }
        }
        area(Promoted)
        {
            group(Category_Navigate)
            {
                Caption = 'Ubicación';

                actionref(VerUbicacion_Promoted; VerUbicacion)
                {
                }
                actionref(VerMovimientos_Promoted; VerMovimientos)
                {
                }
            }
        }
    }

    var
        FiltroProducto: Code[20];
        FiltroAlmacen: Code[10];
        FiltroLote: Code[50];
        SoloDisponible: Boolean;
        TotalUbicado: Decimal;
        EstiloFila: Text;

    trigger OnOpenPage()
    var
        rConfig: Record "Config. SGA";
    begin
        // Recojo el filtro que traiga quien me abre y, si no viene almacén, propongo el de la configuración.
        FiltroProducto := CopyStr(Rec.GetFilter("No. Producto"), 1, MaxStrLen(FiltroProducto));
        FiltroAlmacen := CopyStr(Rec.GetFilter("Cod. Almacen"), 1, MaxStrLen(FiltroAlmacen));
        FiltroLote := CopyStr(Rec.GetFilter("No. Lote"), 1, MaxStrLen(FiltroLote));

        if FiltroAlmacen = '' then begin
            rConfig.ObtenerConfig();
            FiltroAlmacen := rConfig."Almacen por Defecto";
        end;

        SoloDisponible := true;
        AplicarFiltros();
    end;

    trigger OnAfterGetRecord()
    begin
        EstiloFila := Rec.EstiloContenido();
    end;

    local procedure AplicarFiltros()
    var
        rTotal: Record "Contenido Ubicacion SGA";
    begin
        if FiltroProducto <> '' then
            Rec.SetRange("No. Producto", FiltroProducto)
        else
            Rec.SetRange("No. Producto");

        if FiltroAlmacen <> '' then
            Rec.SetRange("Cod. Almacen", FiltroAlmacen)
        else
            Rec.SetRange("Cod. Almacen");

        if FiltroLote <> '' then
            Rec.SetRange("No. Lote", FiltroLote)
        else
            Rec.SetRange("No. Lote");

        if SoloDisponible then begin
            Rec.SetRange(Bloqueado, false);
            Rec.SetFilter("Cantidad Disponible", '>%1', 0);
        end else begin
            Rec.SetRange(Bloqueado);
            Rec.SetRange("Cantidad Disponible");
        end;

        rTotal.CopyFilters(Rec);
        rTotal.CalcSums("Cantidad Base");
        TotalUbicado := rTotal."Cantidad Base";

        CurrPage.Update(false);
    end;
}
