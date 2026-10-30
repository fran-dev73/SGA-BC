namespace AntonioNadal.SGA;

using Microsoft.Sales.Document;

/// <summary>
/// PageExtension Sales Order SGA (ID 51104) extends Page "Sales Order".
/// Permite lanzar el picking de un pedido de venta, ver en la cabecera cuánto está preparado
/// (Estado preparación SGA) y consultar lo que ya se ha recogido.
///
/// Se hace en una extensión propia dentro de SGA, en lugar de tocar Pag-Ext50012
/// "Sales Order", para que el módulo siga siendo autocontenido.
/// </summary>
pageextension 51104 "Sales Order SGA" extends "Sales Order"
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

                action(CrearOrdenPickingSGA)
                {
                    Caption = 'Enviar a picking';
                    ToolTip = 'Genera la orden de picking del pedido: de qué ubicación y qué lote hay que coger cada producto, y lo reserva en las ubicaciones. El pedido debe estar lanzado y no tener otra orden abierta.';
                    ApplicationArea = All;
                    Image = CreateWarehousePick;

                    trigger OnAction()
                    var
                        rOrden: Record "Orden Picking SGA";
                        cPicking: Codeunit "Gestion Picking SGA";
                        noOrden: Code[20];
                        OrdenPickingCreadaMsg: Label 'Se ha creado la orden de picking %1.', Comment = '%1 = nº orden';
                    begin
                        CurrPage.SaveRecord();
                        noOrden := cPicking.CrearOrdenDesdeVenta(Rec."No.");

                        Message(OrdenPickingCreadaMsg, noOrden);

                        if rOrden.Get(noOrden) then
                            Page.Run(Page::"Ficha Orden Picking SGA", rOrden);
                    end;
                }
                action(PasarPickingAPedidoSGA)
                {
                    Caption = 'Pasar picking al pedido';
                    ToolTip = 'Rellena la cantidad a enviar y los lotes de las líneas con lo recogido en las órdenes de picking. Se hace solo al terminar cada orden; úselo si entonces falló.';
                    ApplicationArea = All;
                    Image = TransferOrder;

                    trigger OnAction()
                    var
                        rOrden: Record "Orden Picking SGA";
                        cPicking: Codeunit "Gestion Picking SGA";
                        PedidoSinOrdenesErr: Label 'El pedido %1 no tiene órdenes de picking.', Comment = '%1 = nº pedido';
                        PickingPasadoMsg: Label 'Lo recogido se ha pasado al pedido.';
                    begin
                        CurrPage.SaveRecord();
                        rOrden.SetCurrentKey("No. Documento Origen");
                        rOrden.SetRange("No. Documento Origen", Rec."No.");
                        rOrden.SetRange(Origen, rOrden.Origen::Venta);
                        if not rOrden.FindLast() then
                            Error(PedidoSinOrdenesErr, Rec."No.");

                        // Basta con una: el paso al pedido suma todas las órdenes del pedido.
                        cPicking.PasarAPedido(rOrden);
                        CurrPage.Update(false);
                        Message(PickingPasadoMsg);
                    end;
                }
                action(VerOrdenesPickingSGA)
                {
                    Caption = 'Órdenes de picking';
                    ToolTip = 'Órdenes de preparación creadas para este pedido.';
                    ApplicationArea = All;
                    Image = Warehouse;
                    RunObject = page "Ordenes Picking SGA";
                    RunPageLink = "No. Documento Origen" = field("No.");
                }
                action(VerMovimientosSGA)
                {
                    Caption = 'Movimientos de ubicación';
                    ToolTip = 'Qué se ha sacado, de qué ubicación y quién lo hizo al preparar este pedido.';
                    ApplicationArea = All;
                    Image = Journals;
                    RunObject = page "Movs. Ubicacion SGA";
                    RunPageLink = "No. Documento Origen" = field("No.");
                }
            }
        }
        // Pestaña propia en la barra de acciones, junto a "Proceso". Sin promocionar, el grupo
        // quedaba escondido en "Más opciones" y el usuario solo veía las acciones de almacén
        // estándar, que en SGA no se usan: la salida siempre va por "Enviar a picking".
        addafter(Category_Process)
        {
            group(Category_SGA)
            {
                Caption = 'Almacén SGA';

                actionref(CrearOrdenPickingSGA_Promoted; CrearOrdenPickingSGA)
                {
                }
                actionref(VerOrdenesPickingSGA_Promoted; VerOrdenesPickingSGA)
                {
                }
                actionref(PasarPickingAPedidoSGA_Promoted; PasarPickingAPedidoSGA)
                {
                }
                actionref(VerMovimientosSGA_Promoted; VerMovimientosSGA)
                {
                }
            }
        }
    }

    var
        EstadoPreparacion: Enum "Estado Preparacion SGA";
        EstiloPreparacion: Text;

    trigger OnAfterGetCurrRecord()
    var
        cPicking: Codeunit "Gestion Picking SGA";
    begin
        EstadoPreparacion := cPicking.EstadoPreparacionVenta(Rec);
        EstiloPreparacion := cPicking.EstiloEstadoPreparacion(EstadoPreparacion);
    end;
}
