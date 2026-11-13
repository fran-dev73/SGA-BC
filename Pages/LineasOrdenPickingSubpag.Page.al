namespace AntonioNadal.SGA;

/// <summary>
/// Page Lineas Orden Picking Subpag (ID 51120).
/// Paradas de una orden de picking, en el orden en que hay que recorrerlas.
/// </summary>
page 51120 "Lineas Orden Picking Subpag"
{
    Caption = 'Paradas SGA';
    PageType = ListPart;
    SourceTable = "Linea Orden Picking SGA";
    AutoSplitKey = false;
    DelayedInsert = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    Editable = false;
    SourceTableView = sorting("No. Orden", Estado, "Secuencia Picking");

    layout
    {
        area(Content)
        {
            repeater(Paradas)
            {
                field("Secuencia Picking"; Rec."Secuencia Picking")
                {
                    ToolTip = 'Orden de recorrido físico de la parada.';
                    ApplicationArea = All;
                }
                field("Cod. Bin Propuesto"; Rec."Cod. Bin Propuesto")
                {
                    ToolTip = 'Ubicación a la que hay que ir a recoger.';
                    ApplicationArea = All;
                    Style = Strong;
                }
                field("Cod. Bin Destino"; Rec."Cod. Bin Destino")
                {
                    ApplicationArea = All;
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
                    ToolTip = 'Lote concreto que hay que recoger.';
                    ApplicationArea = All;
                }
                field(SSCC; Rec.SSCC)
                {
                    ApplicationArea = All;
                }
                field("SSCC Recogido"; Rec."SSCC Recogido")
                {
                    ApplicationArea = All;
                    Visible = false;
                }
                field("Fecha Caducidad"; Rec."Fecha Caducidad")
                {
                    ToolTip = 'Caducidad del lote.';
                    ApplicationArea = All;
                }
                field("Cantidad a Recoger"; Rec."Cantidad a Recoger")
                {
                    ToolTip = 'Cantidad que hay que recoger en esta parada.';
                    ApplicationArea = All;
                }
                field("Cantidad Recogida"; Rec."Cantidad Recogida")
                {
                    ToolTip = 'Cantidad ya recogida.';
                    ApplicationArea = All;
                }
                field("Cantidad Pendiente"; Rec."Cantidad Pendiente")
                {
                    ToolTip = 'Cantidad que queda por recoger.';
                    ApplicationArea = All;
                }
                field("Cod. Unidad Medida"; Rec."Cod. Unidad Medida")
                {
                    Caption = 'UM base';
                    ToolTip = 'Unidad de medida base, en la que van las cantidades de la parada.';
                    ApplicationArea = All;
                }
                field(PendienteDocumento; Rec.EnUMDocumento(Rec."Cantidad Pendiente"))
                {
                    Caption = 'Pendiente (UM pedido)';
                    ToolTip = 'Lo que queda por recoger, en la unidad de medida del pedido. Es lo que ve el preparador.';
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 5;
                    Editable = false;
                }
                field("UM Documento"; Rec."UM Documento")
                {
                    ToolTip = 'Unidad de medida de la línea del pedido.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Estado; Rec.Estado)
                {
                    ToolTip = 'Situación de la parada.';
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
                    Visible = false;
                }
                field("Cod. Bin Confirmado"; Rec."Cod. Bin Confirmado")
                {
                    ToolTip = 'Ubicación de la que se ha recogido realmente.';
                    ApplicationArea = All;
                    StyleExpr = EstiloDesvio;
                }
                field("Cod. Usuario Confirmacion"; Rec."Cod. Usuario Confirmacion")
                {
                    ToolTip = 'Preparador que confirmó la parada.';
                    ApplicationArea = All;
                }
                field("Fecha Confirmacion"; Rec."Fecha Confirmacion")
                {
                    ToolTip = 'Momento en que se confirmó la parada.';
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CancelarParada)
            {
                Caption = 'Cancelar parada';
                ToolTip = 'Marca la parada como cancelada. Lo ya recogido no se deshace.';
                ApplicationArea = All;
                Image = Cancel;

                trigger OnAction()
                var
                    cPicking: Codeunit "Gestion Picking SGA";
                    CancelarParadaQst: Label '¿Cancelar la parada de %1 en %2?', Comment = '%1 = producto, %2 = ubicación';
                begin
                    if not Confirm(CancelarParadaQst, false, Rec."No. Producto", Rec."Cod. Bin Propuesto") then
                        exit;
                    cPicking.CancelarLinea(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        EstiloFila: Text;
        EstiloDesvio: Text;

    trigger OnAfterGetRecord()
    begin
        EstiloFila := Rec.EstiloEstado();
        EstiloDesvio := Rec.EstiloUbicacionConfirmada();
    end;
}
