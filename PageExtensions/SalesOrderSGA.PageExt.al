namespace AntonioNadal.SGA;

using Microsoft.Sales.Document;

/// <summary>
/// PageExtension Sales Order SGA (ID 51104) extends Page "Sales Order".
/// Permite enviar un pedido de venta a SGA (sus órdenes de picking), ver en la cabecera cuánto
/// está preparado (Estado preparación SGA) y consultar lo que ya se ha recogido.
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

                action(EnviarASGA)
                {
                    Caption = 'Enviar a SGA';
                    ToolTip = 'Genera las órdenes de picking del pedido, de un palé como mucho cada una: una por palé completo y las cajas y unidades sueltas juntas hasta llenar un palé. Dice de qué ubicación y qué lote coger cada producto y lo reserva. El pedido debe estar lanzado y, una vez enviado, ya no se puede volver a abrir.';
                    ApplicationArea = All;
                    Image = CreateWarehousePick;

                    trigger OnAction()
                    var
                        rOrden: Record "Orden Picking SGA";
                        cPicking: Codeunit "Gestion Picking SGA";
                        creadas: Integer;
                        faltas: Text;
                        OrdenesCreadasMsg: Label 'Se han creado %1 órdenes de picking.', Comment = '%1 = número de órdenes';
                        OrdenesConFaltasMsg: Label 'Se han creado %1 órdenes de picking con lo que hay ubicado. Falta:\%2\\Lo que falta se prepara en una segunda ronda, cuando haya stock ubicado y estén terminadas estas órdenes: vuelva a pulsar Enviar a SGA, o use Segunda ronda de picking en Órdenes de picking SGA.', Comment = '%1 = número de órdenes, %2 = lista de faltas';
                    begin
                        CurrPage.SaveRecord();
                        creadas := cPicking.EnviarPedidoASGA(Rec."No.", faltas);

                        if faltas = '' then
                            Message(OrdenesCreadasMsg, creadas)
                        else
                            Message(OrdenesConFaltasMsg, creadas, faltas);

                        rOrden.SetRange("No. Documento Origen", Rec."No.");
                        rOrden.SetRange(Origen, rOrden.Origen::Venta);
                        Page.Run(Page::"Ordenes Picking SGA", rOrden);
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
                        cPicking: Codeunit "Gestion Picking SGA";
                        PickingPasadoMsg: Label 'Lo recogido se ha pasado al pedido.';
                    begin
                        CurrPage.SaveRecord();
                        cPicking.PasarAPedidoDeVenta(Rec."No.");
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
        // estándar, que en SGA no se usan: la salida siempre va por "Enviar a SGA".
        addafter(Category_Process)
        {
            group(Category_SGA)
            {
                Caption = 'Almacén SGA';

                actionref(EnviarASGA_Promoted; EnviarASGA)
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
