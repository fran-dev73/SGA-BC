namespace AntonioNadal.SGA;

using System.Utilities;

/// <summary>
/// Page Lineas Picking SGA (ID 51134).
/// Paradas de picking de todas las órdenes, para que el jefe de almacén vea lo que necesita
/// atención. Se abre desde las pilas, con su filtro:
///   - Retenidas: el preparador las ha saltado dos veces porque algo impide recogerlas.
///     Siguen pendientes y su orden no se termina hasta que se resuelven con Buscar en otra
///     ubicación.
///   - Desvíos: recogidas de una ubicación distinta de la propuesta.
/// </summary>
page 51134 "Lineas Picking SGA"
{
    Caption = 'Líneas de picking SGA';
    PageType = List;
    SourceTable = "Linea Orden Picking SGA";
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Paradas)
            {
                field("No. Orden"; Rec."No. Orden")
                {
                    ToolTip = 'Orden de picking de la línea.';
                    ApplicationArea = All;
                }
                field("No. Documento Origen"; Rec."No. Documento Origen")
                {
                    ApplicationArea = All;
                }
                field("Cod. Almacen"; Rec."Cod. Almacen")
                {
                    ToolTip = 'Almacén de la línea.';
                    ApplicationArea = All;
                }
                field("Cod. Bin Propuesto"; Rec."Cod. Bin Propuesto")
                {
                    Style = Strong;
                    ApplicationArea = All;
                }
                field("Cod. Bin Confirmado"; Rec."Cod. Bin Confirmado")
                {
                    ApplicationArea = All;
                    StyleExpr = EstiloDesvio;
                }
                field("No. Producto"; Rec."No. Producto")
                {
                    ToolTip = 'Producto que hay que recoger.';
                    ApplicationArea = All;
                }
                field("Descripcion Producto"; Rec."Descripcion Producto")
                {
                    ToolTip = 'Descripción del producto.';
                    ApplicationArea = All;
                }
                field("No. Lote"; Rec."No. Lote")
                {
                    ToolTip = 'Lote que hay que recoger.';
                    ApplicationArea = All;
                }
                field(SSCC; Rec.SSCC)
                {
                    ApplicationArea = All;
                }
                field("Cantidad Pendiente"; Rec."Cantidad Pendiente")
                {
                    ToolTip = 'Cantidad que queda por recoger, en unidades base.';
                    ApplicationArea = All;
                }
                field("Cod. Unidad Medida"; Rec."Cod. Unidad Medida")
                {
                    Caption = 'UM base';
                    ToolTip = 'Unidad de medida base, en la que van las cantidades de la línea.';
                    ApplicationArea = All;
                }
                field(Estado; Rec.Estado)
                {
                    ToolTip = 'Situación de la línea.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field(Retenida; Rec.Retenida)
                {
                    ApplicationArea = All;
                }
                field("Veces Saltada"; Rec."Veces Saltada")
                {
                    ApplicationArea = All;
                }
                field("Retenida por"; Rec."Retenida por")
                {
                    ApplicationArea = All;
                }
                field("Fecha Retencion"; Rec."Fecha Retencion")
                {
                    ApplicationArea = All;
                }
                field(Desvio; Rec.Desvio)
                {
                    ApplicationArea = All;
                }
                field("Cod. Usuario Confirmacion"; Rec."Cod. Usuario Confirmacion")
                {
                    ToolTip = 'Preparador que confirmó la línea.';
                    ApplicationArea = All;
                }
                field("Fecha Confirmacion"; Rec."Fecha Confirmacion")
                {
                    ToolTip = 'Momento en que se confirmó la línea.';
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(BuscarOtraUbicacion)
            {
                Caption = 'Buscar en otra ubicación';
                ToolTip = 'Para una línea retenida: la cancela y crea líneas nuevas para lo que faltaba en otras ubicaciones con stock del producto, como el botón Sin stock de la PDA. Las nuevas vuelven al recorrido del preparador de la orden.';
                ApplicationArea = All;
                Image = Reuse;
                Enabled = EsRetenidaPendiente;

                trigger OnAction()
                var
                    cPicking: Codeunit "Gestion Picking SGA";
                    cConfirmMgt: Codeunit "Confirm Management";
                    cubierta: Boolean;
                    BuscarOtraUbicacionQst: Label '¿Cancelar la línea de %1 en %2 y buscar el producto en otra ubicación?', Comment = '%1 = producto, %2 = ubicación';
                begin
                    if not cConfirmMgt.GetResponseOrDefault(StrSubstNo(BuscarOtraUbicacionQst, Rec."No. Producto", Rec."Cod. Bin Propuesto"), false) then
                        exit;

                    Message(cPicking.SustituirParadaSinStock(Rec, cubierta));
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(VerOrden)
            {
                Caption = 'Orden de picking';
                ToolTip = 'Abre la orden de picking de la línea.';
                ApplicationArea = All;
                Image = Document;
                RunObject = page "Ficha Orden Picking SGA";
                RunPageLink = "No. Orden" = field("No. Orden");
            }
            action(VerContenido)
            {
                Caption = 'Contenido de la ubicación';
                ToolTip = 'Muestra qué hay en la ubicación propuesta de la línea según SGA.';
                ApplicationArea = All;
                Image = ItemLines;
                RunObject = page "Contenido Ubicaciones SGA";
                RunPageLink = "Cod. Almacen" = field("Cod. Almacen"),
                              "Cod. Bin" = field("Cod. Bin Propuesto");
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(BuscarOtraUbicacion_Promoted; BuscarOtraUbicacion) { }
                actionref(VerOrden_Promoted; VerOrden) { }
                actionref(VerContenido_Promoted; VerContenido) { }
            }
        }
    }

    views
    {
        view(Retenidas)
        {
            Caption = 'Retenidas';
            Filters = where(Retenida = const(true), Estado = filter(Pendiente | Parcial));
        }
        view(Desvios)
        {
            Caption = 'Desvíos';
            Filters = where(Desvio = const(true));
        }
    }

    var
        EstiloFila: Text;
        EstiloDesvio: Text;
        EsRetenidaPendiente: Boolean;

    trigger OnAfterGetCurrRecord()
    begin
        EsRetenidaPendiente := Rec.Retenida and (Rec.Estado in [Rec.Estado::Pendiente, Rec.Estado::Parcial]);
    end;

    trigger OnAfterGetRecord()
    begin
        EstiloFila := Rec.EstiloEstado();
        EstiloDesvio := Rec.EstiloUbicacionConfirmada();
    end;
}
