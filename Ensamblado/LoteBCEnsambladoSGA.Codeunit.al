namespace AntonioNadal.SGA;

using Microsoft.Assembly.Document;
using Microsoft.Assembly.Posting;
using Microsoft.Inventory.Tracking;

/// <summary>
/// Codeunit Lote BC Ensamblado SGA (ID 51109).
/// Lleva el lote propio del ensamblado ("Lote") al seguimiento estándar de BC de su salida,
/// para que el producto fabricado entre en el almacén con lote de BC y el picking lo pase a
/// los pedidos. Solo actúa si el producto fabricado tiene código de seguimiento por lote
/// ("Consulta Stock SGA".LoteEstandar); si no, el ensamblado funciona igual que siempre.
/// Los consumos (líneas) no se tocan. La caducidad se deja en blanco: la pone BC al registrar,
/// con la fórmula de caducidad del producto o la que ya tenga el lote.
/// </summary>
codeunit 51109 "Lote BC Ensamblado SGA"
{
    [EventSubscriber(ObjectType::Table, Database::"Assembly Header", 'OnAfterValidateEvent', 'Lote', false, false)]
    local procedure AlValidarLote(var Rec: Record "Assembly Header")
    begin
        Sincronizar(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Assembly Header", 'OnAfterValidateEvent', 'Item No.', false, false)]
    local procedure AlValidarProducto(var Rec: Record "Assembly Header")
    begin
        Sincronizar(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Assembly Header", 'OnAfterValidateEvent', 'Quantity', false, false)]
    local procedure AlValidarCantidad(var Rec: Record "Assembly Header")
    begin
        Sincronizar(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Assembly Header", 'OnAfterValidateEvent', 'Quantity to Assemble', false, false)]
    local procedure AlValidarCantidadEnsamblar(var Rec: Record "Assembly Header")
    begin
        Sincronizar(Rec);
    end;

    /// <summary>
    /// Red de seguridad antes de registrar: el lote puede haberse puesto sin validarlo.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Assembly-Post", 'OnBeforeOnRun', '', false, false)]
    local procedure AntesDeRegistrar(var AssemblyHeader: Record "Assembly Header")
    begin
        Sincronizar(AssemblyHeader);
    end;

    /// <summary>
    /// Deja el seguimiento de la salida del ensamblado en una sola línea: el lote propio, por
    /// lo que queda por ensamblar, con lo que se ensambla ahora como cantidad a registrar. Si
    /// ya está así no toca nada. Sin lote o sin cantidad, quita el seguimiento por lote que
    /// hubiera. No toca la salida si tiene reservas (ensamblar contra pedido): esas las lleva
    /// el pedido.
    /// </summary>
    local procedure Sincronizar(var prm_Cab: Record "Assembly Header")
    var
        rSeguimiento: Record "Reservation Entry";
        rNuevo: Record "Reservation Entry";
        cStock: Codeunit "Consulta Stock SGA";
        cCrearReserva: Codeunit "Create Reserv. Entry";
    begin
        if (prm_Cab."Document Type" <> prm_Cab."Document Type"::Order) or (prm_Cab."No." = '') or (prm_Cab."Item No." = '') then
            exit;
        if not cStock.LoteEstandar(prm_Cab."Item No.") then
            exit;

        rSeguimiento.SetSourceFilter(Database::"Assembly Header", prm_Cab."Document Type".AsInteger(), prm_Cab."No.", 0, true);
        rSeguimiento.SetSourceFilter('', 0);
        rSeguimiento.SetRange("Reservation Status", rSeguimiento."Reservation Status"::Reservation);
        if not rSeguimiento.IsEmpty() then
            exit;

        rSeguimiento.SetFilter("Reservation Status", '%1|%2', rSeguimiento."Reservation Status"::Surplus, rSeguimiento."Reservation Status"::Prospect);
        rSeguimiento.SetFilter("Lot No.", '<>%1', '');
        if YaSincronizado(rSeguimiento, prm_Cab) then
            exit;
        rSeguimiento.DeleteAll(true);

        if (prm_Cab.Lote = '') or (prm_Cab."Remaining Quantity (Base)" <= 0) then
            exit;

        rNuevo."Lot No." := prm_Cab.Lote;
        cCrearReserva.CreateReservEntryFor(Database::"Assembly Header", prm_Cab."Document Type".AsInteger(), prm_Cab."No.", '', 0, 0,
                                           prm_Cab."Qty. per Unit of Measure", prm_Cab."Remaining Quantity", prm_Cab."Remaining Quantity (Base)", rNuevo);
        cCrearReserva.SetQtyToHandleAndInvoice(prm_Cab."Quantity to Assemble (Base)", prm_Cab."Quantity to Assemble (Base)");
        cCrearReserva.CreateEntry(prm_Cab."Item No.", prm_Cab."Variant Code", prm_Cab."Location Code", prm_Cab.Description,
                                  prm_Cab."Due Date", 0D, 0, "Reservation Status"::Surplus);
    end;

    /// <summary>
    /// Si el seguimiento por lote de la salida ya es una sola línea con el lote propio, lo que
    /// queda por ensamblar y lo que se ensambla ahora.
    /// </summary>
    local procedure YaSincronizado(var prm_Seguimiento: Record "Reservation Entry"; var prm_Cab: Record "Assembly Header"): Boolean
    begin
        if prm_Cab.Lote = '' then
            exit(prm_Seguimiento.IsEmpty());
        if prm_Seguimiento.Count() <> 1 then
            exit(false);
        prm_Seguimiento.FindFirst();
        exit((prm_Seguimiento."Lot No." = prm_Cab.Lote) and
             (prm_Seguimiento."Quantity (Base)" = prm_Cab."Remaining Quantity (Base)") and
             (prm_Seguimiento."Qty. to Handle (Base)" = prm_Cab."Quantity to Assemble (Base)"));
    end;
}
