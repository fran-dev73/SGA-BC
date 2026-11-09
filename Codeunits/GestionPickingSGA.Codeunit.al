namespace AntonioNadal.SGA;

using Microsoft.Foundation.NoSeries;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using System.Security.User;

/// <summary>
/// Codeunit Gestion Picking SGA (ID 51104).
/// Motor de picking: convierte un pedido de venta en un recorrido de paradas, reserva en las
/// ubicaciones lo que cada parada va a coger, registra la retirada cuando el preparador
/// confirma y, al terminar, pasa al pedido lo recogido (cantidad a enviar y lotes).
///
/// Las órdenes sirven también para las reubicaciones de almacenamiento a picking (origen
/// Reposicion, AnadirReubicacion): la parada lleva una ubicación destino y, al confirmarla, lo
/// recogido se traslada allí en vez de salir. Qué reubicar lo decide Cod. "Reubicaciones SGA".
///
/// Las paradas guardan las cantidades en unidad de medida base, igual que el resto del módulo.
/// La UM de la línea del pedido viaja en la parada solo para enseñársela al preparador.
///
/// La reserva no se suma ni se resta sobre la marcha: se recalcula desde las paradas abiertas
/// de cada hueco (RecalcularReserva). Así no hay forma de que se quede descuadrada si una
/// parada se cancela, se recoge de otro hueco o la orden se cancela entera.
///
/// El movimiento lo escribe Cod. "Gestion Contenido SGA": este codeunit decide de dónde
/// coger, pero no toca las tablas de contenido ni el diario.
///
/// OnRun pasa una orden al pedido. Existe para poder llamarlo con Codeunit.Run al terminar
/// el recorrido: si el pedido no acepta los datos, el preparador no pierde lo confirmado.
/// </summary>
codeunit 51104 "Gestion Picking SGA"
{
    Access = Public;
    TableNo = "Orden Picking SGA";

    trigger OnRun()
    begin
        PasarAPedido(Rec);
    end;

    /// <summary>
    /// Crea la orden de picking de un pedido de venta lanzado. Devuelve el nº de orden creada.
    /// Si alguna línea no se puede cubrir entera con el contenido ubicado, la orden se crea
    /// igual con lo que hay: es preferible preparar lo que existe que no preparar nada. Lo que
    /// falta va en prm_Faltas, una línea por producto, y se prepara en la segunda ronda
    /// (SegundaRonda) cuando haya stock ubicado.
    /// </summary>
    procedure CrearOrdenDesdeVenta(prm_NoPedido: Code[20]; var prm_Faltas: Text): Code[20]
    var
        rCabVenta: Record "Sales Header";
        rLinVenta: Record "Sales Line";
        rOrden: Record "Orden Picking SGA";
        rOrdenAbierta: Record "Orden Picking SGA";
        rConfig: Record "Config. SGA";
        almacen: Code[10];
        noLinea: Integer;
        necesidad: Decimal;
        sinCubrir: Decimal;
        FaltaLineaTxt: Label '%1 %2: faltan %3 %4', Comment = '%1 = producto, %2 = descripción, %3 = cantidad, %4 = unidad';
        PedidoNoExisteErr: Label 'No existe el pedido de venta %1.', Comment = '%1 = nº pedido';
        SerieOrdenSinConfigurarErr: Label 'Configure la serie "Nos. orden SGA" en la configuración de SGA antes de crear órdenes de picking.';
        PedidoSinPendienteErr: Label 'El pedido %1 no tiene nada pendiente de preparar: lo que queda por servir ya está recogido.', Comment = '%1 = nº pedido';
        DescripcionOrdenLbl: Label 'Picking del pedido %1', Comment = '%1 = nº pedido';
        SinParadasErr: Label 'No se ha podido generar ninguna parada: no hay contenido ubicado disponible de los productos del pedido.';
        PedidoNoLanzadoErr: Label 'El pedido %1 debe estar lanzado para enviarlo a picking.', Comment = '%1 = nº pedido';
        OrdenYaAbiertaErr: Label 'El pedido %1 ya tiene abierta la orden de picking %2. Termínela o cancélela antes de crear otra.', Comment = '%1 = nº pedido, %2 = nº orden';
    begin
        if not rCabVenta.Get(rCabVenta."Document Type"::Order, prm_NoPedido) then
            Error(PedidoNoExisteErr, prm_NoPedido);

        // Lanzado: mientras se prepara, el pedido no debe cambiar por debajo.
        if rCabVenta.Status <> rCabVenta.Status::Released then
            Error(PedidoNoLanzadoErr, prm_NoPedido);

        // Una sola orden viva por pedido. Con dos, los preparadores se pisarían el stock.
        rOrdenAbierta.SetCurrentKey("No. Documento Origen");
        rOrdenAbierta.SetRange("No. Documento Origen", prm_NoPedido);
        rOrdenAbierta.SetRange(Origen, rOrdenAbierta.Origen::Venta);
        rOrdenAbierta.SetFilter(Estado, '%1|%2|%3', rOrdenAbierta.Estado::"Pendiente Asignar",
                                rOrdenAbierta.Estado::Abierta, rOrdenAbierta.Estado::"En Proceso");
        if rOrdenAbierta.FindFirst() then
            Error(OrdenYaAbiertaErr, prm_NoPedido, rOrdenAbierta."No. Orden");

        rConfig.ObtenerConfig();
        if rConfig."Nos. Orden SGA" = '' then
            Error(SerieOrdenSinConfigurarErr);

        almacen := rCabVenta."Location Code";
        if almacen = '' then
            almacen := rConfig."Almacen por Defecto";

        FiltrarLineasPendientes(rCabVenta, rLinVenta);
        if not HayNecesidad(rLinVenta) then
            Error(PedidoSinPendienteErr, prm_NoPedido);

        rOrden.Init();
        rOrden."No. Orden" := SiguienteNoOrden(rConfig."Nos. Orden SGA");
        rOrden."Cod. Almacen" := almacen;
        rOrden.Origen := rOrden.Origen::Venta;
        rOrden."No. Documento Origen" := prm_NoPedido;
        rOrden."Nombre Cliente" := rCabVenta."Sell-to Customer Name";
        rOrden."Fecha Envio" := rCabVenta."Shipment Date";
        // Con "Exigir asignación" nace pendiente de asignar; si no, abierta para cualquiera.
        rOrden.Estado := rOrden.EstadoSinEmpezar();
        rOrden.Descripcion := CopyStr(StrSubstNo(DescripcionOrdenLbl, prm_NoPedido), 1, MaxStrLen(rOrden.Descripcion));
        rOrden.Insert(true);

        rLinVenta.FindSet();
        repeat
            necesidad := NecesidadLinea(rLinVenta);
            if necesidad > 0 then begin
                sinCubrir := GenerarParadas(rOrden, rLinVenta, necesidad, noLinea);
                if sinCubrir > 0 then begin
                    if prm_Faltas <> '' then
                        prm_Faltas += '\';
                    prm_Faltas += StrSubstNo(FaltaLineaTxt, rLinVenta."No.", rLinVenta.Description,
                                             Round(sinCubrir / rLinVenta."Qty. per Unit of Measure", 0.00001), rLinVenta."Unit of Measure Code");
                end;
                // Se reserva línea a línea y no al final: si dos líneas del pedido piden el
                // mismo producto, la segunda tiene que ver ya descontado lo que coge la primera.
                RecalcularReservasOrden(rOrden);
            end;
        until rLinVenta.Next() = 0;

        rOrden.CalcFields("No. Lineas");
        if rOrden."No. Lineas" = 0 then begin
            rOrden.Delete(true);
            Error(SinParadasErr);
        end;

        exit(rOrden."No. Orden");
    end;

    /// <summary>
    /// Segunda ronda de picking: a cada pedido de venta lanzado que ya pasó por picking, no tiene
    /// orden abierta y aún tiene algo por preparar le crea una orden con lo que falta, si ya hay
    /// contenido ubicado de alguno de esos productos. Lo que sigue sin stock espera a la
    /// siguiente ronda. Devuelve el resumen para enseñarlo.
    /// </summary>
    procedure SegundaRonda() resumen: Text
    var
        rCabVenta: Record "Sales Header";
        creadas: Integer;
        esperan: Integer;
        faltas: Text;
        noOrden: Code[20];
        detalle: Text;
        ResumenTxt: Label 'Segunda ronda: %1 órdenes nuevas. %2 pedidos siguen esperando stock ubicado.', Comment = '%1 = órdenes creadas, %2 = pedidos sin stock';
        OrdenCreadaTxt: Label '%1 → orden %2', Comment = '%1 = nº pedido, %2 = nº orden';
    begin
        rCabVenta.SetRange("Document Type", rCabVenta."Document Type"::Order);
        rCabVenta.SetRange(Status, rCabVenta.Status::Released);
        rCabVenta.SetLoadFields("No.", "Location Code");
        if rCabVenta.FindSet() then
            repeat
                if PideSegundaRonda(rCabVenta) then
                    if HayContenidoParaFaltas(rCabVenta) then begin
                        faltas := '';
                        noOrden := CrearOrdenDesdeVenta(rCabVenta."No.", faltas);
                        Commit();
                        creadas += 1;
                        detalle += '\' + StrSubstNo(OrdenCreadaTxt, rCabVenta."No.", noOrden);
                    end else
                        esperan += 1;
            until rCabVenta.Next() = 0;

        resumen := StrSubstNo(ResumenTxt, creadas, esperan) + detalle;
    end;

    /// <summary>
    /// Si el pedido entra en la segunda ronda: ya ha tenido alguna orden de picking, no tiene
    /// ninguna viva y le queda algo por mandar a recoger.
    /// </summary>
    local procedure PideSegundaRonda(var prm_CabVenta: Record "Sales Header"): Boolean
    var
        rOrden: Record "Orden Picking SGA";
        rLinVenta: Record "Sales Line";
    begin
        rOrden.SetCurrentKey("No. Documento Origen");
        rOrden.SetRange("No. Documento Origen", prm_CabVenta."No.");
        rOrden.SetRange(Origen, rOrden.Origen::Venta);
        if rOrden.IsEmpty() then
            exit(false);
        rOrden.SetFilter(Estado, '%1|%2|%3', rOrden.Estado::"Pendiente Asignar", rOrden.Estado::Abierta, rOrden.Estado::"En Proceso");
        if not rOrden.IsEmpty() then
            exit(false);

        FiltrarLineasPendientes(prm_CabVenta, rLinVenta);
        exit(HayNecesidad(rLinVenta));
    end;

    /// <summary>
    /// Si hay contenido ubicado disponible de algún producto que al pedido le falta por preparar.
    /// </summary>
    local procedure HayContenidoParaFaltas(var prm_CabVenta: Record "Sales Header"): Boolean
    var
        rLinVenta: Record "Sales Line";
        rContenido: Record "Contenido Ubicacion SGA";
        rConfig: Record "Config. SGA";
        almacen: Code[10];
    begin
        almacen := prm_CabVenta."Location Code";
        if almacen = '' then begin
            rConfig.ObtenerConfig();
            almacen := rConfig."Almacen por Defecto";
        end;

        FiltrarLineasPendientes(prm_CabVenta, rLinVenta);
        if rLinVenta.FindSet() then
            repeat
                if NecesidadLinea(rLinVenta) > 0 then begin
                    rContenido.SetRange("Cod. Almacen", almacen);
                    rContenido.SetRange("No. Producto", rLinVenta."No.");
                    rContenido.SetRange("Cod. Variante", rLinVenta."Variant Code");
                    rContenido.SetRange(Bloqueado, false);
                    rContenido.SetFilter("Cantidad Disponible", '>%1', 0);
                    if not rContenido.IsEmpty() then
                        exit(true);
                end;
            until rLinVenta.Next() = 0;
        exit(false);
    end;

    /// <summary>
    /// Las líneas de producto del pedido con algo pendiente de servir.
    /// </summary>
    local procedure FiltrarLineasPendientes(var prm_CabVenta: Record "Sales Header"; var prm_LinVenta: Record "Sales Line")
    begin
        prm_LinVenta.SetRange("Document Type", prm_LinVenta."Document Type"::Order);
        prm_LinVenta.SetRange("Document No.", prm_CabVenta."No.");
        prm_LinVenta.SetRange(Type, prm_LinVenta.Type::Item);
        prm_LinVenta.SetFilter("Outstanding Qty. (Base)", '>%1', 0);
    end;

    /// <summary>
    /// Cantidad base de una línea del pedido que todavía hay que mandar a recoger: lo pedido
    /// menos lo ya recogido en órdenes anteriores, sin pasar de lo que queda por servir.
    /// Se apoya en que toda salida de venta pasa por picking.
    /// </summary>
    local procedure NecesidadLinea(var prm_LinVenta: Record "Sales Line"): Decimal
    var
        recogido: Dictionary of [Code[50], Decimal];
        caducidades: Dictionary of [Code[50], Date];
        necesidad: Decimal;
    begin
        necesidad := prm_LinVenta."Quantity (Base)" - RecogidoPorLote(prm_LinVenta."Document No.", prm_LinVenta."Line No.", recogido, caducidades);
        if necesidad > prm_LinVenta."Outstanding Qty. (Base)" then
            necesidad := prm_LinVenta."Outstanding Qty. (Base)";
        if necesidad < 0 then
            necesidad := 0;

        exit(necesidad);
    end;

    local procedure HayNecesidad(var prm_LinVenta: Record "Sales Line"): Boolean
    var
        rLinea: Record "Sales Line";
    begin
        rLinea.CopyFilters(prm_LinVenta);
        if rLinea.FindSet() then
            repeat
                if NecesidadLinea(rLinea) > 0 then
                    exit(true);
            until rLinea.Next() = 0;

        exit(false);
    end;

    /// <summary>
    /// Reparte la cantidad de una línea del pedido entre las ubicaciones que tienen el
    /// producto, creando una parada por cada una, en tres pasadas:
    ///   1. los palés completos, de almacenamiento: no se deshace el palé de picking para servir
    ///      uno entero;
    ///   2. lo demás, de picking, que es de donde se prepara;
    ///   3. lo que no haya en picking, del resto (almacenamiento y ubicaciones sin tipo).
    /// En cada pasada el contenido va en el orden de la estrategia de picking. Devuelve lo que no
    /// se ha podido cubrir.
    /// </summary>
    local procedure GenerarParadas(var prm_Orden: Record "Orden Picking SGA"; var prm_LinVenta: Record "Sales Line"; prm_CantidadBase: Decimal; var prm_NoLinea: Integer): Decimal
    var
        rConfig: Record "Config. SGA";
        cUM: Codeunit "Unidades Producto SGA";
        cogido: Dictionary of [Text, Decimal];
        pendiente: Decimal;
        factorPale: Decimal;
        pasada: Integer;
    begin
        pendiente := prm_CantidadBase;
        if pendiente <= 0 then
            exit(0);

        rConfig.ObtenerConfig();
        factorPale := cUM.FactorPale(prm_LinVenta."No.");
        // Sin palé en la ficha no hay palés completos que coger: se empieza por picking.
        for pasada := 1 to 3 do
            if (pasada > 1) or (factorPale > 1) then
                AnadirParadasPasada(prm_Orden, prm_LinVenta, rConfig."Estrategia Picking", pasada, factorPale, cogido, pendiente, prm_NoLinea);

        exit(pendiente);
    end;

    /// <summary>
    /// Una pasada de GenerarParadas (1 palés de almacenamiento, 2 picking, 3 el resto). Lo que ya
    /// ha cogido una pasada anterior de cada línea de contenido va en prm_Cogido: la reserva no
    /// se recalcula hasta terminar la línea del pedido, así que la disponible aún no lo descuenta.
    /// </summary>
    local procedure AnadirParadasPasada(var prm_Orden: Record "Orden Picking SGA"; var prm_LinVenta: Record "Sales Line"; prm_Estrategia: Enum "Estrategia Picking SGA"; prm_Pasada: Integer; prm_FactorPale: Decimal; var prm_Cogido: Dictionary of [Text, Decimal]; var prm_Pendiente: Decimal; var prm_NoLinea: Integer)
    var
        rContenido: Record "Contenido Ubicacion SGA";
        yaCogido: Decimal;
        coger: Decimal;
    begin
        if prm_Pendiente <= 0 then
            exit;

        rContenido.SetRange("Cod. Almacen", prm_Orden."Cod. Almacen");
        rContenido.SetRange("No. Producto", prm_LinVenta."No.");
        rContenido.SetRange("Cod. Variante", prm_LinVenta."Variant Code");
        rContenido.SetRange(Bloqueado, false);
        rContenido.SetFilter("Cantidad Disponible", '>%1', 0);
        case prm_Pasada of
            1:
                rContenido.SetRange("Tipo Ubicacion", rContenido."Tipo Ubicacion"::Almacenamiento);
            2:
                rContenido.SetRange("Tipo Ubicacion", rContenido."Tipo Ubicacion"::Picking);
            else
                rContenido.SetFilter("Tipo Ubicacion", '<>%1', rContenido."Tipo Ubicacion"::Picking);
        end;
        rContenido.SetAutoCalcFields("Secuencia Picking");
        OrdenarPorEstrategia(rContenido, prm_Estrategia);
        if not rContenido.FindSet() then
            exit;

        repeat
            if not prm_Cogido.Get(rContenido.GetPosition(), yaCogido) then
                yaCogido := 0;
            coger := rContenido."Cantidad Disponible" - yaCogido;
            if coger > prm_Pendiente then
                coger := prm_Pendiente;
            // En la primera pasada, solo palés enteros.
            if prm_Pasada = 1 then
                coger := Round(coger / prm_FactorPale, 1, '<') * prm_FactorPale;

            if coger > 0 then begin
                InsertarParada(prm_Orden, rContenido, coger, '', prm_LinVenta."Line No.", prm_LinVenta."Document No.",
                               prm_LinVenta."Unit of Measure Code", prm_LinVenta."Qty. per Unit of Measure", prm_NoLinea);
                prm_Cogido.Set(rContenido.GetPosition(), yaCogido + coger);
                prm_Pendiente -= coger;
            end;
        until (rContenido.Next() = 0) or (prm_Pendiente <= 0);
    end;

    /// <summary>
    /// Añade a la orden una parada para recoger prm_Cantidad (en base) de una línea de contenido.
    /// Con prm_Destino es una reubicación: lo recogido se deja en esa ubicación. La línea del
    /// documento y su UM van en blanco en las reubicaciones, que no salen de ningún pedido.
    /// prm_Contenido tiene que traer calculada la "Secuencia Picking".
    /// </summary>
    local procedure InsertarParada(var prm_Orden: Record "Orden Picking SGA"; var prm_Contenido: Record "Contenido Ubicacion SGA"; prm_Cantidad: Decimal; prm_Destino: Code[20]; prm_NoLineaDocumento: Integer; prm_NoDocumento: Code[20]; prm_UMDocumento: Code[10]; prm_FactorDocumento: Decimal; var prm_NoLinea: Integer)
    var
        rLinea: Record "Linea Orden Picking SGA";
        rItem: Record Item;
    begin
        rItem.SetLoadFields(Description);
        if rItem.Get(prm_Contenido."No. Producto") then;

        prm_NoLinea += 10000;
        rLinea.Init();
        rLinea."No. Orden" := prm_Orden."No. Orden";
        rLinea."No. Linea" := prm_NoLinea;
        rLinea."Cod. Almacen" := prm_Contenido."Cod. Almacen";
        rLinea."No. Producto" := prm_Contenido."No. Producto";
        rLinea."Descripcion Producto" := CopyStr(rItem.Description, 1, MaxStrLen(rLinea."Descripcion Producto"));
        rLinea."Cod. Variante" := prm_Contenido."Cod. Variante";
        rLinea."No. Lote" := prm_Contenido."No. Lote";
        rLinea."Fecha Caducidad" := prm_Contenido."Fecha Caducidad";
        rLinea."Cod. Unidad Medida" := prm_Contenido."Cod. Unidad Medida";
        rLinea."UM Documento" := prm_UMDocumento;
        rLinea."Ctdad. por UM Documento" := prm_FactorDocumento;
        rLinea."Cantidad a Recoger" := prm_Cantidad;
        rLinea."Cod. Bin Propuesto" := prm_Contenido."Cod. Bin";
        rLinea."Cod. Bin Destino" := prm_Destino;
        rLinea."Secuencia Picking" := prm_Contenido."Secuencia Picking";
        rLinea."No. Linea Origen" := prm_NoLineaDocumento;
        rLinea."No. Documento Origen" := prm_NoDocumento;
        rLinea.Estado := rLinea.Estado::Pendiente;
        rLinea.Insert(true);
    end;

    /// <summary>
    /// Planifica una reubicación: una parada que recoge prm_Cantidad (en base) de la línea de
    /// contenido y la deja en la ubicación prm_Destino. Va a la orden de reubicaciones del
    /// almacén que aún no ha empezado nadie (la crea si no hay), y reserva lo que va a coger, como
    /// cualquier parada. Lo que decide qué reubicar y adónde es Cod. "Reubicaciones SGA".
    /// </summary>
    procedure AnadirReubicacion(var prm_Contenido: Record "Contenido Ubicacion SGA"; prm_Cantidad: Decimal; prm_Destino: Code[20])
    var
        rOrden: Record "Orden Picking SGA";
        rLinea: Record "Linea Orden Picking SGA";
        rConfig: Record "Config. SGA";
        cUM: Codeunit "Unidades Producto SGA";
        noLinea: Integer;
        umPale: Code[10];
        DescripcionReubicacionesLbl: Label 'Reubicaciones a picking';
        SerieOrdenSinConfigurarErr: Label 'Configure la serie "Nos. orden SGA" en la configuración de SGA antes de planificar reubicaciones.';
    begin
        rOrden.SetCurrentKey("Cod. Almacen", Estado);
        rOrden.SetRange("Cod. Almacen", prm_Contenido."Cod. Almacen");
        rOrden.SetFilter(Estado, '%1|%2', rOrden.Estado::"Pendiente Asignar", rOrden.Estado::Abierta);
        rOrden.SetRange(Origen, rOrden.Origen::Reposicion);
        if not rOrden.FindFirst() then begin
            rConfig.ObtenerConfig();
            if rConfig."Nos. Orden SGA" = '' then
                Error(SerieOrdenSinConfigurarErr);
            rOrden.Init();
            rOrden."No. Orden" := SiguienteNoOrden(rConfig."Nos. Orden SGA");
            rOrden."Cod. Almacen" := prm_Contenido."Cod. Almacen";
            rOrden.Origen := rOrden.Origen::Reposicion;
            rOrden.Estado := rOrden.EstadoSinEmpezar();
            rOrden.Descripcion := DescripcionReubicacionesLbl;
            rOrden.Insert(true);
        end;

        rLinea.SetRange("No. Orden", rOrden."No. Orden");
        if rLinea.FindLast() then
            noLinea := rLinea."No. Linea";

        // Al carretillero se le enseña en palés si es un palé justo; si no, en la unidad base.
        prm_Contenido.CalcFields("Secuencia Picking");
        umPale := cUM.UMPale(prm_Contenido."No. Producto");
        if (umPale <> '') and (prm_Cantidad = cUM.FactorPale(prm_Contenido."No. Producto")) then
            InsertarParada(rOrden, prm_Contenido, prm_Cantidad, prm_Destino, 0, '', umPale, prm_Cantidad, noLinea)
        else
            InsertarParada(rOrden, prm_Contenido, prm_Cantidad, prm_Destino, 0, '', prm_Contenido."Cod. Unidad Medida", 1, noLinea);

        RecalcularReserva(prm_Contenido."Cod. Almacen", prm_Contenido."Cod. Bin", prm_Contenido."No. Producto",
                          prm_Contenido."Cod. Variante", prm_Contenido."No. Lote");
    end;

    /// <summary>
    /// Fija el orden en que se recorre el contenido según la estrategia configurada.
    /// "Lote exacto" no tiene lote de referencia al generar la orden, así que se comporta
    /// como FEFO: al preparador se le sigue diciendo el lote concreto de cada parada.
    /// Las reubicaciones eligen con el mismo orden qué traer de almacenamiento.
    /// </summary>
    procedure OrdenarPorEstrategia(var prm_Contenido: Record "Contenido Ubicacion SGA"; prm_Estrategia: Enum "Estrategia Picking SGA")
    begin
        case prm_Estrategia of
            prm_Estrategia::FIFO:
                prm_Contenido.SetCurrentKey("Cod. Almacen", "No. Producto", "Fecha Ultima Entrada");
            prm_Estrategia::"Vaciar Ubicacion":
                prm_Contenido.SetCurrentKey("Cod. Almacen", "Cod. Bin");
            else
                prm_Contenido.SetCurrentKey("Cod. Almacen", "No. Producto", "Cod. Variante", Bloqueado, "Fecha Caducidad", "Cod. Bin");
        end;
    end;

    /// <summary>
    /// Confirma que el preparador ha recogido una cantidad base de una parada. Es el punto en
    /// el que el stock sale de la ubicación y queda la huella en el diario de movimientos.
    /// Con "Exigir Confirmar Ubicacion" la ubicación de la que se recoge es obligatoria; sin
    /// ella, prm_Bin en blanco da por buena la ubicación propuesta. prm_ProductoLeido es lo
    /// escaneado del producto; obligatorio con "Exigir Escanear Producto".
    /// </summary>
    procedure ConfirmarLinea(var prm_Linea: Record "Linea Orden Picking SGA"; prm_Bin: Code[20]; prm_Cantidad: Decimal; prm_DigitoControl: Text; prm_ProductoLeido: Text)
    var
        rOrden: Record "Orden Picking SGA";
        rConfig: Record "Config. SGA";
        rUbicacion: Record "Ubicacion SGA";
        cContenido: Codeunit "Gestion Contenido SGA";
        cReubicaciones: Codeunit "Reubicaciones SGA";
        binReal: Code[20];
        exigeUbicacion: Boolean;
        exigeDigito: Boolean;
        exigeProducto: Boolean;
        CantidadNoPositivaErr: Label 'La cantidad recogida debe ser mayor que cero.';
        LineaCanceladaErr: Label 'La línea está cancelada.';
        CantidadExcedePendienteErr: Label 'No puede recoger %1: quedan %2 pendientes en esta parada.', Comment = '%1 = cantidad indicada, %2 = cantidad pendiente';
        DesvioNoPermitidoErr: Label 'La configuración no permite recoger de una ubicación distinta de la propuesta (%1).', Comment = '%1 = ubicación propuesta';
        UbicacionNoIndicadaErr: Label 'Indique de qué ubicación ha recogido la mercancía.';
        UbicacionNoEscaneadaErr: Label 'Escanee o teclee la ubicación de la que ha recogido.';
        DescripcionSalidaLbl: Label 'Picking %1 del documento %2', Comment = '%1 = nº orden, %2 = documento origen';
        DescripcionReubicacionLbl: Label 'Reubicación a picking, orden %1', Comment = '%1 = nº orden';
    begin
        if prm_Cantidad <= 0 then
            Error(CantidadNoPositivaErr);

        rConfig.ObtenerConfig();
        QueExige(prm_Linea, prm_Bin, exigeUbicacion, exigeDigito, exigeProducto);
        if exigeUbicacion and (prm_Bin = '') then
            Error(UbicacionNoEscaneadaErr);

        if prm_Linea.Estado = prm_Linea.Estado::Cancelada then
            Error(LineaCanceladaErr);

        prm_Linea.ActualizarPendiente();
        if prm_Cantidad > prm_Linea."Cantidad Pendiente" then
            Error(CantidadExcedePendienteErr, prm_Cantidad, prm_Linea."Cantidad Pendiente");

        binReal := prm_Bin;
        if binReal = '' then
            binReal := prm_Linea."Cod. Bin Propuesto";
        if binReal = '' then
            Error(UbicacionNoIndicadaErr);

        if not rConfig.DesvioPermitido(prm_Linea."Cod. Bin Propuesto", binReal) then
            Error(DesvioNoPermitidoErr, prm_Linea."Cod. Bin Propuesto");

        // Certifica que el preparador está delante del hueco del que recoge: el dígito solo
        // está en la etiqueta. Se comprueba aquí y no en la pantalla para que no se pueda saltar.
        if exigeDigito then
            rUbicacion.TestDigitoControl(prm_Linea."Cod. Almacen", binReal, prm_DigitoControl);

        // Certifica que lo que coge es el producto de la parada. Lo leído se comprueba siempre,
        // aunque no se exija.
        if exigeProducto or (prm_ProductoLeido <> '') then
            TestProductoLeido(prm_Linea, prm_ProductoLeido);

        rOrden.Get(prm_Linea."No. Orden");
        ComprobarPreparador(rOrden);

        // La parada se actualiza antes de la salida para que la reserva del hueco ya esté
        // rebajada cuando la salida lo vacíe.
        prm_Linea."Cod. Bin Confirmado" := binReal;
        prm_Linea."Cantidad Recogida" += prm_Cantidad;
        prm_Linea."Fecha Confirmacion" := CurrentDateTime();
        prm_Linea."Cod. Usuario Confirmacion" := CopyStr(UserId(), 1, MaxStrLen(prm_Linea."Cod. Usuario Confirmacion"));
        prm_Linea.ActualizarPendiente();
        prm_Linea.Modify();

        // El movimiento va en UM base: es la de la parada. El nº de orden viaja en la descripción
        // porque la puerta única de escritura no expone todavía el campo "No. Orden SGA".
        // Una reubicación no sale del almacén: se traslada a su ubicación de picking.
        if prm_Linea."Cod. Bin Destino" <> '' then
            cContenido.RegistrarTraslado(prm_Linea."Cod. Almacen", binReal, prm_Linea."Cod. Bin Destino", prm_Linea."No. Producto",
                                         prm_Linea."Cod. Variante", prm_Linea."No. Lote", prm_Linea."Cod. Unidad Medida",
                                         prm_Cantidad, rOrden.Origen, rOrden."No. Orden", prm_Linea."No. Linea",
                                         StrSubstNo(DescripcionReubicacionLbl, rOrden."No. Orden"))
        else
            cContenido.RegistrarSalida(prm_Linea."Cod. Almacen", binReal, prm_Linea."No. Producto",
                                       prm_Linea."Cod. Variante", prm_Linea."No. Lote", prm_Linea."Cod. Unidad Medida",
                                       prm_Cantidad, rOrden.Origen, rOrden."No. Documento Origen",
                                       prm_Linea."No. Linea Origen",
                                       StrSubstNo(DescripcionSalidaLbl, rOrden."No. Orden", rOrden."No. Documento Origen"));

        RecalcularReserva(prm_Linea."Cod. Almacen", prm_Linea."Cod. Bin Propuesto", prm_Linea."No. Producto", prm_Linea."Cod. Variante", prm_Linea."No. Lote");
        if binReal <> prm_Linea."Cod. Bin Propuesto" then
            RecalcularReserva(prm_Linea."Cod. Almacen", binReal, prm_Linea."No. Producto", prm_Linea."Cod. Variante", prm_Linea."No. Lote");

        rOrden.RecalcularEstado();
        rOrden.Modify();

        // Si el picking ha dejado sin el producto una ubicación de picking, se planifica traerlo
        // de almacenamiento.
        if prm_Linea."Cod. Bin Destino" = '' then
            cReubicaciones.ReubicarSiSeVacia(prm_Linea."Cod. Almacen", binReal, prm_Linea."No. Producto", prm_Linea."Cod. Variante");
    end;

    /// <summary>
    /// Comprueba que lo leído por el escáner es el producto de la parada y, si la lectura
    /// trae lote (GS1-128 con (10)), que es su lote. Da error si no.
    /// </summary>
    procedure TestProductoLeido(var prm_Linea: Record "Linea Orden Picking SGA"; prm_Lectura: Text)
    var
        cLectura: Codeunit "Lectura Codigos SGA";
        producto: Code[20];
        variante: Code[10];
        lote: Code[50];
        ProductoNoEscaneadoErr: Label 'Escanee el producto que recoge.';
        ProductoDesconocidoErr: Label 'El código %1 no corresponde a ningún producto.', Comment = '%1 = código leído';
        ProductoDistintoErr: Label 'Ha escaneado %1 y esta parada es de %2.', Comment = '%1 = producto leído, %2 = producto de la parada';
        LoteDistintoErr: Label 'Ha escaneado el lote %1 y esta parada es del lote %2.', Comment = '%1 = lote leído, %2 = lote de la parada';
    begin
        if prm_Lectura = '' then
            Error(ProductoNoEscaneadoErr);

        if not cLectura.LeerProducto(prm_Lectura, producto, variante, lote) then
            Error(ProductoDesconocidoErr, prm_Lectura);

        if (producto <> prm_Linea."No. Producto") or ((variante <> '') and (variante <> prm_Linea."Cod. Variante")) then
            Error(ProductoDistintoErr, producto, prm_Linea."No. Producto");

        if (lote <> '') and (prm_Linea."No. Lote" <> '') and (lote <> prm_Linea."No. Lote") then
            Error(LoteDistintoErr, lote, prm_Linea."No. Lote");
    end;

    /// <summary>
    /// Cancela una parada que no se va a recoger y libera su reserva. Lo ya recogido no se
    /// deshace: para eso hay que registrar una entrada, que deja su propia huella en el diario.
    /// </summary>
    procedure CancelarLinea(var prm_Linea: Record "Linea Orden Picking SGA")
    var
        rOrden: Record "Orden Picking SGA";
    begin
        prm_Linea.Estado := prm_Linea.Estado::Cancelada;
        prm_Linea."Cantidad Pendiente" := 0;
        prm_Linea.Modify();

        RecalcularReserva(prm_Linea."Cod. Almacen", prm_Linea."Cod. Bin Propuesto", prm_Linea."No. Producto", prm_Linea."Cod. Variante", prm_Linea."No. Lote");

        if rOrden.Get(prm_Linea."No. Orden") then begin
            rOrden.RecalcularEstado();
            // RecalcularEstado cambia el estado de la orden; el analizador no lo ve.
#pragma warning disable AA0214
            rOrden.Modify();
#pragma warning restore AA0214
        end;
    end;

    /// <summary>
    /// El preparador no encuentra la mercancía en la ubicación de la parada ("Sin stock"): se
    /// cancela la parada y lo que le quedaba se busca en otras ubicaciones del mismo producto,
    /// en el orden de la estrategia de picking, primero en picking y luego en el resto; con una
    /// parada nueva por ubicación, para que el preparador no pierda la cantidad. La ubicación
    /// vacía queda descartada para esta parada. Si es una reubicación, solo en almacenamiento y
    /// con el mismo destino. Devuelve lo que ha pasado, para enseñárselo al preparador, y en
    /// prm_Cubierta si se ha encontrado todo.
    /// </summary>
    procedure SustituirParadaSinStock(var prm_Linea: Record "Linea Orden Picking SGA"; var prm_Cubierta: Boolean) resultado: Text
    var
        rOrden: Record "Orden Picking SGA";
        rUltima: Record "Linea Orden Picking SGA";
        rConfig: Record "Config. SGA";
        pendiente: Decimal;
        sinCubrir: Decimal;
        noLinea: Integer;
        pasada: Integer;
        ubicaciones: Text;
        OtraUbicacionTxt: Label 'No estaba en %1. Se recoge de otra ubicación: %2.', Comment = '%1 = ubicación vacía, %2 = ubicaciones nuevas';
        ParteTxt: Label 'No estaba en %1. Se recoge de otra ubicación (%2), pero no hay para todo: faltan %3 %4.', Comment = '%1 = ubicación vacía, %2 = ubicaciones nuevas, %3 = cantidad que falta, %4 = unidad';
        NingunaTxt: Label 'No estaba en %1 y no hay %2 en ninguna otra ubicación: la parada queda cancelada.', Comment = '%1 = ubicación vacía, %2 = producto';
    begin
        pendiente := prm_Linea."Cantidad Pendiente";
        CancelarLinea(prm_Linea);
        rOrden.Get(prm_Linea."No. Orden");

        rUltima.SetRange("No. Orden", prm_Linea."No. Orden");
        rUltima.SetLoadFields("No. Linea");
        if rUltima.FindLast() then
            noLinea := rUltima."No. Linea";

        rConfig.ObtenerConfig();
        sinCubrir := pendiente;
        // Reubicación: de almacenamiento (pasada 1 sin redondeo a palés); pedido: picking y resto.
        if prm_Linea."Cod. Bin Destino" <> '' then
            SustituirEnPasada(rOrden, prm_Linea, rConfig."Estrategia Picking", 1, sinCubrir, noLinea, ubicaciones)
        else
            for pasada := 2 to 3 do
                SustituirEnPasada(rOrden, prm_Linea, rConfig."Estrategia Picking", pasada, sinCubrir, noLinea, ubicaciones);

        if sinCubrir < pendiente then begin
            RecalcularReservasOrden(rOrden);
            rOrden.RecalcularEstado();
            // RecalcularEstado cambia el estado de la orden; el analizador no lo ve.
#pragma warning disable AA0214
            rOrden.Modify();
#pragma warning restore AA0214
        end;

        prm_Cubierta := sinCubrir <= 0;
        case true of
            sinCubrir = pendiente:
                resultado := StrSubstNo(NingunaTxt, prm_Linea."Cod. Bin Propuesto", prm_Linea."No. Producto");
            sinCubrir > 0:
                resultado := StrSubstNo(ParteTxt, prm_Linea."Cod. Bin Propuesto", ubicaciones, prm_Linea.EnUMDocumento(sinCubrir), prm_Linea.UMVisible());
            else
                resultado := StrSubstNo(OtraUbicacionTxt, prm_Linea."Cod. Bin Propuesto", ubicaciones);
        end;
    end;

    /// <summary>
    /// Una pasada de SustituirParadaSinStock (1 almacenamiento, 2 picking, 3 el resto): paradas
    /// nuevas de la misma línea del documento, desde el contenido disponible del producto que no
    /// está en la ubicación que se ha encontrado vacía.
    /// </summary>
    local procedure SustituirEnPasada(var prm_Orden: Record "Orden Picking SGA"; var prm_Linea: Record "Linea Orden Picking SGA"; prm_Estrategia: Enum "Estrategia Picking SGA"; prm_Pasada: Integer; var prm_Pendiente: Decimal; var prm_NoLinea: Integer; var prm_Ubicaciones: Text)
    var
        rContenido: Record "Contenido Ubicacion SGA";
        coger: Decimal;
    begin
        if prm_Pendiente <= 0 then
            exit;

        rContenido.SetRange("Cod. Almacen", prm_Linea."Cod. Almacen");
        rContenido.SetRange("No. Producto", prm_Linea."No. Producto");
        rContenido.SetRange("Cod. Variante", prm_Linea."Cod. Variante");
        rContenido.SetFilter("Cod. Bin", '<>%1', prm_Linea."Cod. Bin Propuesto");
        rContenido.SetRange(Bloqueado, false);
        rContenido.SetFilter("Cantidad Disponible", '>%1', 0);
        case prm_Pasada of
            1:
                rContenido.SetRange("Tipo Ubicacion", rContenido."Tipo Ubicacion"::Almacenamiento);
            2:
                rContenido.SetRange("Tipo Ubicacion", rContenido."Tipo Ubicacion"::Picking);
            else
                rContenido.SetFilter("Tipo Ubicacion", '<>%1', rContenido."Tipo Ubicacion"::Picking);
        end;
        rContenido.SetAutoCalcFields("Secuencia Picking");
        OrdenarPorEstrategia(rContenido, prm_Estrategia);
        if not rContenido.FindSet() then
            exit;

        repeat
            coger := rContenido."Cantidad Disponible";
            if coger > prm_Pendiente then
                coger := prm_Pendiente;
            InsertarParada(prm_Orden, rContenido, coger, prm_Linea."Cod. Bin Destino", prm_Linea."No. Linea Origen", prm_Linea."No. Documento Origen",
                           prm_Linea."UM Documento", prm_Linea."Ctdad. por UM Documento", prm_NoLinea);
            prm_Pendiente -= coger;
            if prm_Ubicaciones <> '' then
                prm_Ubicaciones += ', ';
            prm_Ubicaciones += rContenido."Cod. Bin";
        until (rContenido.Next() = 0) or (prm_Pendiente <= 0);
    end;

    /// <summary>
    /// Cancela la orden entera y todas sus paradas pendientes, y libera sus reservas.
    /// </summary>
    procedure CancelarOrden(var prm_Orden: Record "Orden Picking SGA")
    var
        rLinea: Record "Linea Orden Picking SGA";
    begin
        rLinea.SetRange("No. Orden", prm_Orden."No. Orden");
        rLinea.FiltrarPendientes();
        if rLinea.FindSet() then
            repeat
                rLinea.Estado := rLinea.Estado::Cancelada;
                rLinea."Cantidad Pendiente" := 0;
                rLinea.Modify();
            until rLinea.Next() = 0;

        prm_Orden.Estado := prm_Orden.Estado::Cancelada;
        prm_Orden.Modify();

        RecalcularReservasOrden(prm_Orden);
    end;

    /// <summary>
    /// Qué hay que leer para confirmar la parada, recogiendo de prm_Bin (en blanco, la
    /// propuesta). Es la única regla: la usan ConfirmarLinea, ParadaCompleta y la pantalla.
    ///   - Dígito: si la configuración lo exige y el hueco ya lo tiene colocado ("Digito
    ///     Colocado"). Mientras se van poniendo, un hueco sin él no lo pide: el almacén sigue
    ///     funcionando con solo el producto.
    ///   - Ubicación: con "Exigir Confirmar Ubicacion" y sin "Exigir Digito Control". Con el
    ///     dígito exigido no se pide nunca: o la certifica el dígito o el hueco aún no tiene
    ///     etiqueta que escanear.
    ///   - Producto: con "Exigir Escanear Producto".
    /// </summary>
    procedure QueExige(var prm_Linea: Record "Linea Orden Picking SGA"; prm_Bin: Code[20]; var prm_Ubicacion: Boolean; var prm_Digito: Boolean; var prm_Producto: Boolean)
    var
        rConfig: Record "Config. SGA";
        rUbicacion: Record "Ubicacion SGA";
    begin
        rConfig.ObtenerConfig();
        if prm_Bin = '' then
            prm_Bin := prm_Linea."Cod. Bin Propuesto";
        prm_Digito := false;
        if rConfig."Exigir Digito Control" then begin
            rUbicacion.SetLoadFields("Digito Colocado");
            if rUbicacion.Get(prm_Linea."Cod. Almacen", prm_Bin) then
                prm_Digito := rUbicacion."Digito Colocado";
        end;
        prm_Ubicacion := rConfig."Exigir Confirmar Ubicacion" and not rConfig."Exigir Digito Control";
        prm_Producto := rConfig."Exigir Escanear Producto";
    end;

    /// <summary>
    /// Devuelve true si la parada tiene todo lo que QueExige para confirmarla. No comprueba que
    /// sea correcto; eso lo hace ConfirmarLinea.
    /// </summary>
    procedure ParadaCompleta(var prm_Linea: Record "Linea Orden Picking SGA"; prm_Bin: Code[20]; prm_DigitoControl: Text; prm_ProductoLeido: Text): Boolean
    var
        exigeUbicacion: Boolean;
        exigeDigito: Boolean;
        exigeProducto: Boolean;
    begin
        QueExige(prm_Linea, prm_Bin, exigeUbicacion, exigeDigito, exigeProducto);
        if exigeUbicacion and (prm_Bin = '') then
            exit(false);
        if exigeDigito and (DelChr(prm_DigitoControl, '<>', ' ') = '') then
            exit(false);
        if exigeProducto and (prm_ProductoLeido = '') then
            exit(false);
        exit(true);
    end;

    /// <summary>
    /// Toma la siguiente orden que le toca al usuario (TomarSiguienteOrden) y la guarda, para
    /// que la pantalla del preparador la abra. Si no hay ninguna devuelve false, con el porqué
    /// en prm_Motivo.
    /// </summary>
    procedure SiguienteOrdenPreparar(var prm_Orden: Record "Orden Picking SGA"; var prm_Motivo: Text): Boolean
    var
        rConfig: Record "Config. SGA";
        SinOrdenesPendientesTxt: Label 'No hay órdenes de picking pendientes.';
        SinOrdenesAsignadasTxt: Label 'No tiene órdenes de picking asignadas. Pida a su responsable que le asigne alguna.';
    begin
        prm_Motivo := '';
        if TomarSiguienteOrden(prm_Orden) then begin
            Commit();
            exit(true);
        end;

        rConfig.ObtenerConfig();
        if rConfig."Exigir Asignacion Picking" then
            prm_Motivo := SinOrdenesAsignadasTxt
        else
            prm_Motivo := SinOrdenesPendientesTxt;
        exit(false);
    end;

    /// <summary>
    /// Devuelve la siguiente orden que le toca al usuario actual: primero las suyas sin
    /// terminar, por prioridad. Si no tiene y la configuración no exige asignación, coge la
    /// siguiente sin asignar y se la queda: una reubicación si el usuario es carretillero
    /// (EsCarretillero) y un pedido si no. Devuelve false si no hay ninguna.
    /// </summary>
    procedure TomarSiguienteOrden(var prm_Orden: Record "Orden Picking SGA"): Boolean
    var
        rConfig: Record "Config. SGA";
        usuario: Code[50];
    begin
        usuario := UsuarioActual();
        rConfig.ObtenerConfig();

        prm_Orden.Reset();
        prm_Orden.SetFilter(Estado, '%1|%2', prm_Orden.Estado::Abierta, prm_Orden.Estado::"En Proceso");
        prm_Orden.SetRange("Cod. Usuario Asignado", usuario);
        if BuscarMasPrioritaria(prm_Orden) then
            exit(true);

        // Con asignación exigida, el preparador solo hace lo que le reparten.
        if rConfig."Exigir Asignacion Picking" then
            exit(false);

        // Las pendientes de asignar entran por si la configuración se desactivó con órdenes en espera.
        prm_Orden.SetFilter(Estado, '%1|%2', prm_Orden.Estado::Abierta, prm_Orden.Estado::"Pendiente Asignar");
        prm_Orden.SetRange("Cod. Usuario Asignado", '');
        // El carretillero coge las reubicaciones; los demás, lo que no lo es.
        if EsCarretillero() then
            prm_Orden.SetRange(Origen, prm_Orden.Origen::Reposicion)
        else
            prm_Orden.SetFilter(Origen, '<>%1', prm_Orden.Origen::Reposicion);
        if not BuscarMasPrioritaria(prm_Orden) then
            exit(false);

        AsignarOrden(prm_Orden, usuario);
        exit(true);
    end;

    /// <summary>
    /// Deja en prm_Orden la de mayor prioridad entre las filtradas y, a igual prioridad, la
    /// más antigua. Se recorre a mano porque una clave descendente en prioridad también
    /// invertiría el orden de antigüedad.
    /// </summary>
    local procedure BuscarMasPrioritaria(var prm_Orden: Record "Orden Picking SGA"): Boolean
    var
        rCandidata: Record "Orden Picking SGA";
        mejor: Code[20];
        mejorPrioridad: Integer;
    begin
        rCandidata.CopyFilters(prm_Orden);
        rCandidata.SetCurrentKey("No. Orden");
        if not rCandidata.FindSet() then
            exit(false);

        mejor := rCandidata."No. Orden";
        mejorPrioridad := rCandidata.Prioridad;
        while rCandidata.Next() <> 0 do
            if rCandidata.Prioridad > mejorPrioridad then begin
                mejor := rCandidata."No. Orden";
                mejorPrioridad := rCandidata.Prioridad;
            end;

        exit(prm_Orden.Get(mejor));
    end;

    /// <summary>
    /// Asigna una orden a un preparador, o la deja sin asignar con prm_Usuario en blanco.
    /// El cambio de estado (pendiente de asignar / abierta) lo resuelve la propia tabla.
    /// </summary>
    procedure AsignarOrden(var prm_Orden: Record "Orden Picking SGA"; prm_Usuario: Code[50])
    begin
        prm_Orden.Validate("Cod. Usuario Asignado", prm_Usuario);
        prm_Orden.Modify(true);
    end;

    /// <summary>
    /// Asigna (o desasigna, con prm_Usuario en blanco) todas las órdenes del conjunto recibido
    /// (filtros o marcas de la selección). Devuelve cuántas ha tocado.
    /// </summary>
    procedure AsignarOrdenes(var prm_Orden: Record "Orden Picking SGA"; prm_Usuario: Code[50]): Integer
    var
        hechas: Integer;
    begin
        // Por la clave primaria: asignar cambia el estado, que encabeza la clave de la página,
        // y recorrer por ella mientras se modifica saltaría órdenes.
        prm_Orden.SetCurrentKey("No. Orden");
        if prm_Orden.FindSet(true) then
            repeat
                AsignarOrden(prm_Orden, prm_Usuario);
                hechas += 1;
            until prm_Orden.Next() = 0;

        exit(hechas);
    end;

    /// <summary>
    /// Suma prm_Delta a la prioridad de las órdenes del conjunto recibido, sin bajar de cero.
    /// </summary>
    procedure CambiarPrioridad(var prm_Orden: Record "Orden Picking SGA"; prm_Delta: Integer)
    begin
        // Por la clave primaria: la prioridad forma parte de la clave de la página, y recorrer
        // por ella mientras se modifica podría visitar dos veces la misma orden.
        prm_Orden.SetCurrentKey("No. Orden");
        if prm_Orden.FindSet(true) then
            repeat
                if prm_Orden.Prioridad + prm_Delta < 0 then
                    prm_Orden.Validate(Prioridad, 0)
                else
                    prm_Orden.Validate(Prioridad, prm_Orden.Prioridad + prm_Delta);
                prm_Orden.Modify(true);
            until prm_Orden.Next() = 0;
    end;

    /// <summary>
    /// Con "Exigir Asignacion Picking", solo un responsable de picking (marcado en
    /// Configuración de usuarios) puede repartir órdenes o cambiar su prioridad. Sin ella, el
    /// reparto es libre, igual que el preparador se asigna solo las que coge.
    ///
    /// Se comprueba por código y no solo con el conjunto de permisos porque los conjuntos
    /// estándar de BC suelen dar ejecución sobre todas las páginas.
    /// </summary>
    procedure ComprobarResponsablePicking()
    var
        rConfig: Record "Config. SGA";
        rUserSetup: Record "User Setup";
        NoResponsablePickingErr: Label 'Solo un responsable de picking puede asignar órdenes o cambiar su prioridad. Pida que le marquen "Responsable picking SGA" en Configuración de usuarios.';
    begin
        rConfig.ObtenerConfig();
        if not rConfig."Exigir Asignacion Picking" then
            exit;

        rUserSetup.SetLoadFields("Responsable Picking SGA");
        if rUserSetup.Get(UserId()) then
            if rUserSetup."Responsable Picking SGA" then
                exit;

        Error(NoResponsablePickingErr);
    end;

    /// <summary>
    /// Deja que el usuario actual prepare la orden, o se para. Con asignación exigida solo
    /// puede el asignado. Sin ella, una orden sin preparador pasa a ser suya, y una de otro
    /// se la queda si confirma. Devuelve false si el usuario no confirma.
    /// </summary>
    procedure TomarParaPreparar(var prm_Orden: Record "Orden Picking SGA"): Boolean
    var
        usuario: Code[50];
        OrdenDeOtroUsuarioQst: Label 'La orden %1 la tiene asignada %2. ¿Quiere prepararla usted?', Comment = '%1 = nº orden, %2 = usuario';
    begin
        usuario := UsuarioActual();
        ComprobarPreparador(prm_Orden);

        if prm_Orden."Cod. Usuario Asignado" = usuario then
            exit(true);

        if prm_Orden."Cod. Usuario Asignado" <> '' then
            if not Confirm(OrdenDeOtroUsuarioQst, false, prm_Orden."No. Orden", prm_Orden."Cod. Usuario Asignado") then
                exit(false);

        AsignarOrden(prm_Orden, usuario);
        exit(true);
    end;

    /// <summary>
    /// Abre la pantalla del preparador sobre las paradas pendientes de la orden. Quien abre la
    /// preparación pasa a ser el preparador, para que otro no la coja a la vez; con asignación
    /// exigida, solo entra el asignado. Se guarda antes de abrir, porque la pantalla se abre
    /// sin esperar y el preparador confirma parada a parada.
    /// </summary>
    procedure AbrirPreparacion(var prm_Orden: Record "Orden Picking SGA")
    var
        rLinea: Record "Linea Orden Picking SGA";
        SinParadasPendientesErr: Label 'La orden %1 no tiene paradas pendientes.', Comment = '%1 = nº orden';
    begin
        rLinea.SetRange("No. Orden", prm_Orden."No. Orden");
        rLinea.FiltrarPendientes();
        if rLinea.IsEmpty() then
            Error(SinParadasPendientesErr, prm_Orden."No. Orden");

        // Se lee la orden de nuevo: la que llega de la página puede no estar al día.
        prm_Orden.Get(prm_Orden."No. Orden");
        if not TomarParaPreparar(prm_Orden) then
            exit;
        Commit();

        Page.Run(Page::"Preparar Picking SGA", rLinea);
    end;

    /// <summary>
    /// Con asignación exigida, solo el preparador asignado puede trabajar la orden. Sin ella,
    /// basta con que la orden siga viva.
    /// </summary>
    procedure ComprobarPreparador(var prm_Orden: Record "Orden Picking SGA")
    var
        rConfig: Record "Config. SGA";
        OrdenPendienteAsignarErr: Label 'La orden %1 está pendiente de asignar. Pida a su responsable que se la asigne.', Comment = '%1 = nº orden';
        OrdenAsignadaOtroErr: Label 'La orden %1 está asignada a %2. Solo la puede preparar el preparador asignado.', Comment = '%1 = nº orden, %2 = usuario';
        OrdenNoVivaErr: Label 'La orden %1 está %2.', Comment = '%1 = nº orden, %2 = estado';
    begin
        if not prm_Orden.EstaViva() then
            Error(OrdenNoVivaErr, prm_Orden."No. Orden", prm_Orden.Estado);

        rConfig.ObtenerConfig();
        if not rConfig."Exigir Asignacion Picking" then
            exit;

        if prm_Orden."Cod. Usuario Asignado" = '' then
            Error(OrdenPendienteAsignarErr, prm_Orden."No. Orden");

        if prm_Orden."Cod. Usuario Asignado" <> UsuarioActual() then
            Error(OrdenAsignadaOtroErr, prm_Orden."No. Orden", prm_Orden."Cod. Usuario Asignado");
    end;

    /// <summary>
    /// Si el usuario actual es carretillero (User Setup."Carretillero SGA"): con "Siguiente
    /// orden" recibe las reubicaciones en vez de los pedidos.
    /// </summary>
    procedure EsCarretillero(): Boolean
    var
        rUserSetup: Record "User Setup";
    begin
        rUserSetup.SetLoadFields("Carretillero SGA");
        if rUserSetup.Get(UserId()) then
            exit(rUserSetup."Carretillero SGA");
        exit(false);
    end;

    /// <summary>
    /// Usuario actual tal como se guarda en "Cod. Usuario Asignado" de la orden.
    /// </summary>
    procedure UsuarioActual(): Code[50]
    var
        rOrden: Record "Orden Picking SGA";
    begin
        exit(CopyStr(UserId(), 1, MaxStrLen(rOrden."Cod. Usuario Asignado")));
    end;

    /// <summary>
    /// Pasa al pedido de venta lo recogido: por cada línea de producto, la cantidad a enviar
    /// y, si el producto lleva lotes estándar, el seguimiento por lote con los lotes que han
    /// salido de las ubicaciones.
    ///
    /// Se calcula sobre todas las órdenes del pedido, no solo esta, descontando lo ya enviado.
    /// Así se puede repetir sin duplicar nada, y una línea sin recoger queda con cantidad a
    /// enviar cero: lo que no ha pasado por picking no sale.
    /// </summary>
    procedure PasarAPedido(var prm_Orden: Record "Orden Picking SGA")
    var
        rCabVenta: Record "Sales Header";
        rLinVenta: Record "Sales Line";
        recogido: Dictionary of [Code[50], Decimal];
        enviado: Dictionary of [Code[50], Decimal];
        caducidades: Dictionary of [Code[50], Date];
        aEnviar: Dictionary of [Code[50], Decimal];
        lote: Code[50];
        cantidadLote: Decimal;
        cantidadEnviada: Decimal;
        totalBase: Decimal;
        restante: Decimal;
        SoloOrdenesVentaErr: Label 'Solo se pueden pasar al pedido órdenes de venta.';
        PedidoNoExisteErr: Label 'No existe el pedido de venta %1.', Comment = '%1 = nº pedido';
    begin
        if prm_Orden.Origen <> prm_Orden.Origen::Venta then
            Error(SoloOrdenesVentaErr);

        if not rCabVenta.Get(rCabVenta."Document Type"::Order, prm_Orden."No. Documento Origen") then
            Error(PedidoNoExisteErr, prm_Orden."No. Documento Origen");

        rLinVenta.SetRange("Document Type", rCabVenta."Document Type");
        rLinVenta.SetRange("Document No.", rCabVenta."No.");
        rLinVenta.SetRange(Type, rLinVenta.Type::Item);
        rLinVenta.SetFilter("Outstanding Qty. (Base)", '>%1', 0);
        if rLinVenta.FindSet(true) then
            repeat
                Clear(recogido);
                Clear(enviado);
                Clear(caducidades);
                Clear(aEnviar);
                totalBase := 0;
                restante := rLinVenta."Outstanding Qty. (Base)";

                RecogidoPorLote(rLinVenta."Document No.", rLinVenta."Line No.", recogido, caducidades);
                EnviadoPorLote(rLinVenta."Document No.", rLinVenta."Line No.", enviado);

                foreach lote in recogido.Keys() do begin
                    cantidadLote := recogido.Get(lote);
                    if enviado.Get(lote, cantidadEnviada) then
                        cantidadLote -= cantidadEnviada;
                    if cantidadLote > restante then
                        cantidadLote := restante;
                    if cantidadLote > 0 then begin
                        aEnviar.Add(lote, cantidadLote);
                        totalBase += cantidadLote;
                        restante -= cantidadLote;
                    end;
                end;

                EscribirSeguimientoLotes(rLinVenta, aEnviar, caducidades);

                rLinVenta.Validate("Qty. to Ship", Round(totalBase / QtyPorUM(rLinVenta), 0.00001));
                rLinVenta.Modify(true);
            until rLinVenta.Next() = 0;

        prm_Orden."Fecha Paso a Documento" := CurrentDateTime();
        prm_Orden.Modify();
    end;

    /// <summary>
    /// Pasa al pedido de venta lo recogido en sus órdenes de picking. Basta con una orden: el
    /// paso al pedido suma todas las del pedido.
    /// </summary>
    procedure PasarAPedidoDeVenta(prm_NoPedido: Code[20])
    var
        rOrden: Record "Orden Picking SGA";
        PedidoSinOrdenesErr: Label 'El pedido %1 no tiene órdenes de picking.', Comment = '%1 = nº pedido';
    begin
        rOrden.SetCurrentKey("No. Documento Origen");
        rOrden.SetRange("No. Documento Origen", prm_NoPedido);
        rOrden.SetRange(Origen, rOrden.Origen::Venta);
        if not rOrden.FindLast() then
            Error(PedidoSinOrdenesErr, prm_NoPedido);

        PasarAPedido(rOrden);
    end;

    /// <summary>
    /// Sustituye el seguimiento por lote de una línea de venta por los lotes recogidos.
    /// Solo si el producto lleva lotes estándar (LoteEstandar): sin código de seguimiento por
    /// lote, BC no espera lotes en la línea y el lote del hueco es solo de SGA.
    /// Solo toca el seguimiento sin reserva (excedente): si la línea tiene reservas contra
    /// lotes concretos, se para, porque deshacerlas es una decisión de oficina.
    /// </summary>
    local procedure EscribirSeguimientoLotes(var prm_LinVenta: Record "Sales Line"; var prm_Lotes: Dictionary of [Code[50], Decimal]; var prm_Caducidades: Dictionary of [Code[50], Date])
    var
        rReserva: Record "Reservation Entry";
        rSeguimiento: Record "Reservation Entry";
        cCrearReserva: Codeunit "Create Reserv. Entry";
        cStock: Codeunit "Consulta Stock SGA";
        lote: Code[50];
        cantidadBase: Decimal;
        caducidad: Date;
        hayLotes: Boolean;
        LineaConReservasErr: Label 'La línea %1 del pedido %2 tiene reservas por lote. Anúlelas antes de pasar el picking al pedido.', Comment = '%1 = nº línea, %2 = nº pedido';
    begin
        if not cStock.LoteEstandar(prm_LinVenta."No.") then
            exit;

        foreach lote in prm_Lotes.Keys() do
            if lote <> '' then
                hayLotes := true;

        rReserva.SetSourceFilter(Database::"Sales Line", prm_LinVenta."Document Type".AsInteger(), prm_LinVenta."Document No.", prm_LinVenta."Line No.", true);
        rReserva.SetSourceFilter('', 0);
        rReserva.SetFilter("Lot No.", '<>%1', '');

        // Sin lotes recogidos y sin seguimiento previo no hay nada que tocar: producto sin lote.
        if (not hayLotes) and rReserva.IsEmpty() then
            exit;

        rReserva.SetRange("Reservation Status", rReserva."Reservation Status"::Reservation);
        if not rReserva.IsEmpty() then
            Error(LineaConReservasErr, prm_LinVenta."Line No.", prm_LinVenta."Document No.");

        rReserva.SetFilter("Reservation Status", '%1|%2', rReserva."Reservation Status"::Surplus, rReserva."Reservation Status"::Prospect);
        rReserva.DeleteAll(true);

        foreach lote in prm_Lotes.Keys() do
            if lote <> '' then begin
                cantidadBase := prm_Lotes.Get(lote);
                if not prm_Caducidades.Get(lote, caducidad) then
                    caducidad := 0D;

                Clear(cCrearReserva);
                rSeguimiento.Init();
                rSeguimiento."Lot No." := lote;
                cCrearReserva.CreateReservEntryFor(Database::"Sales Line", prm_LinVenta."Document Type".AsInteger(),
                                                   prm_LinVenta."Document No.", '', 0, prm_LinVenta."Line No.",
                                                   QtyPorUM(prm_LinVenta),
                                                   Round(cantidadBase / QtyPorUM(prm_LinVenta), 0.00001),
                                                   cantidadBase, rSeguimiento);
                if caducidad <> 0D then
                    cCrearReserva.SetDates(0D, caducidad);
                cCrearReserva.CreateEntry(prm_LinVenta."No.", prm_LinVenta."Variant Code", prm_LinVenta."Location Code",
                                          prm_LinVenta.Description, 0D, prm_LinVenta."Shipment Date", 0,
                                          "Reservation Status"::Surplus);
            end;
    end;

    /// <summary>
    /// Lo recogido de una línea del pedido, por lote y en UM base, sumando todas sus órdenes.
    /// Cuenta también las paradas canceladas: se cancelan con lo ya recogido dentro.
    /// Devuelve el total.
    /// </summary>
    local procedure RecogidoPorLote(prm_NoPedido: Code[20]; prm_NoLineaPedido: Integer; var prm_Recogido: Dictionary of [Code[50], Decimal]; var prm_Caducidades: Dictionary of [Code[50], Date]): Decimal
    var
        rOrden: Record "Orden Picking SGA";
        rLinea: Record "Linea Orden Picking SGA";
        acumulado: Decimal;
        total: Decimal;
    begin
        rOrden.SetCurrentKey("No. Documento Origen");
        rOrden.SetRange("No. Documento Origen", prm_NoPedido);
        rOrden.SetRange(Origen, rOrden.Origen::Venta);
        if not rOrden.FindSet() then
            exit(0);

        repeat
            rLinea.SetRange("No. Orden", rOrden."No. Orden");
            rLinea.SetRange("No. Linea Origen", prm_NoLineaPedido);
            rLinea.SetFilter("Cantidad Recogida", '>%1', 0);
            if rLinea.FindSet() then
                repeat
                    if prm_Recogido.Get(rLinea."No. Lote", acumulado) then
                        prm_Recogido.Set(rLinea."No. Lote", acumulado + rLinea."Cantidad Recogida")
                    else
                        prm_Recogido.Add(rLinea."No. Lote", rLinea."Cantidad Recogida");

                    if (rLinea."Fecha Caducidad" <> 0D) and (not prm_Caducidades.ContainsKey(rLinea."No. Lote")) then
                        prm_Caducidades.Add(rLinea."No. Lote", rLinea."Fecha Caducidad");

                    total += rLinea."Cantidad Recogida";
                until rLinea.Next() = 0;
        until rOrden.Next() = 0;

        exit(total);
    end;

    /// <summary>
    /// Lo ya enviado de una línea del pedido, por lote y en UM base, leído de los movimientos
    /// de producto de sus albaranes. Deshacer un envío deja un movimiento positivo en el
    /// mismo albarán, así que se descuenta solo.
    /// </summary>
    local procedure EnviadoPorLote(prm_NoPedido: Code[20]; prm_NoLineaPedido: Integer; var prm_Enviado: Dictionary of [Code[50], Decimal])
    var
        rLinAlbaran: Record "Sales Shipment Line";
        rItemLedgEntry: Record "Item Ledger Entry";
        acumulado: Decimal;
    begin
        rLinAlbaran.SetRange("Order No.", prm_NoPedido);
        rLinAlbaran.SetRange("Order Line No.", prm_NoLineaPedido);
        rLinAlbaran.SetRange(Type, rLinAlbaran.Type::Item);
        if not rLinAlbaran.FindSet() then
            exit;

        repeat
            rItemLedgEntry.SetRange("Document Type", rItemLedgEntry."Document Type"::"Sales Shipment");
            rItemLedgEntry.SetRange("Document No.", rLinAlbaran."Document No.");
            rItemLedgEntry.SetRange("Document Line No.", rLinAlbaran."Line No.");
            if rItemLedgEntry.FindSet() then
                repeat
                    if prm_Enviado.Get(rItemLedgEntry."Lot No.", acumulado) then
                        prm_Enviado.Set(rItemLedgEntry."Lot No.", acumulado - rItemLedgEntry.Quantity)
                    else
                        prm_Enviado.Add(rItemLedgEntry."Lot No.", -rItemLedgEntry.Quantity);
                until rItemLedgEntry.Next() = 0;
        until rLinAlbaran.Next() = 0;
    end;

    /// <summary>
    /// Ajusta la reserva de un hueco a lo que piden sus paradas abiertas. Nunca reserva más de
    /// lo que hay: si alguien se ha desviado y ha cogido de aquí, la reserva se recorta.
    /// </summary>
    procedure RecalcularReserva(prm_Almacen: Code[10]; prm_Bin: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50])
    var
        rLinea: Record "Linea Orden Picking SGA";
        rContenido: Record "Contenido Ubicacion SGA";
        cContenido: Codeunit "Gestion Contenido SGA";
        cUM: Codeunit "Unidades Producto SGA";
        reserva: Decimal;
    begin
        if (prm_Bin = '') or (prm_Producto = '') then
            exit;

        // El contenido va siempre en la unidad base; sin producto, UMBase da '' y no se encuentra.
        if not rContenido.Get(prm_Almacen, prm_Bin, prm_Producto, prm_Variante, prm_Lote, cUM.UMBase(prm_Producto)) then
            exit;

        rLinea.SetCurrentKey("No. Producto", "No. Lote");
        rLinea.SetRange("No. Producto", prm_Producto);
        rLinea.SetRange("No. Lote", prm_Lote);
        rLinea.SetRange("Cod. Variante", prm_Variante);
        rLinea.SetRange("Cod. Almacen", prm_Almacen);
        rLinea.SetRange("Cod. Bin Propuesto", prm_Bin);
        rLinea.FiltrarPendientes();
        rLinea.CalcSums("Cantidad Pendiente");
        reserva := rLinea."Cantidad Pendiente";

        if reserva > rContenido."Cantidad Base" then
            reserva := rContenido."Cantidad Base";
        if reserva < 0 then
            reserva := 0;

        if reserva <> rContenido."Cantidad Reservada" then
            cContenido.FijarReserva(rContenido, reserva);
    end;

    /// <summary>
    /// Recalcula la reserva de todos los huecos que toca una orden.
    /// </summary>
    procedure RecalcularReservasOrden(var prm_Orden: Record "Orden Picking SGA")
    var
        rLinea: Record "Linea Orden Picking SGA";
    begin
        rLinea.SetRange("No. Orden", prm_Orden."No. Orden");
        if rLinea.FindSet() then
            repeat
                RecalcularReserva(rLinea."Cod. Almacen", rLinea."Cod. Bin Propuesto", rLinea."No. Producto", rLinea."Cod. Variante", rLinea."No. Lote");
            until rLinea.Next() = 0;
    end;

    /// <summary>
    /// Vuelve a fijar todas las reservas de un almacén desde cero: libera las que ya no tienen
    /// paradas detrás y fija las de las paradas abiertas. Lo usa la reconstrucción de contenido.
    /// </summary>
    procedure RecalcularReservasAlmacen(prm_Almacen: Code[10])
    var
        rContenido: Record "Contenido Ubicacion SGA";
        rReservado: Record "Contenido Ubicacion SGA";
        rLinea: Record "Linea Orden Picking SGA";
    begin
        if prm_Almacen <> '' then
            rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetFilter("Cantidad Reservada", '>%1', 0);
        if rContenido.FindSet() then
            repeat
                // Copia para recalcular: el registro del bucle está filtrado por la reserva
                // que se va a cambiar.
                rReservado := rContenido;
                RecalcularReserva(rReservado."Cod. Almacen", rReservado."Cod. Bin", rReservado."No. Producto", rReservado."Cod. Variante", rReservado."No. Lote");
            until rContenido.Next() = 0;

        if prm_Almacen <> '' then
            rLinea.SetRange("Cod. Almacen", prm_Almacen);
        rLinea.FiltrarPendientes();
        if rLinea.FindSet() then
            repeat
                RecalcularReserva(rLinea."Cod. Almacen", rLinea."Cod. Bin Propuesto", rLinea."No. Producto", rLinea."Cod. Variante", rLinea."No. Lote");
            until rLinea.Next() = 0;
    end;

    /// <summary>
    /// Borra las órdenes sin terminar de un almacén (abiertas, en proceso o pendientes de
    /// asignar) con sus paradas, aunque lleven algo recogido: es para dejar el almacén a cero
    /// (Inicializar de Cod. "Gestion Contenido SGA"). Con prm_Producto, solo las que llevan ese
    /// producto en alguna parada. Las finalizadas y canceladas se quedan como historial.
    /// No recalcula las reservas: lo hace quien llama, al terminar.
    /// </summary>
    procedure EliminarOrdenesSinTerminar(prm_Almacen: Code[10]; prm_Producto: Code[20])
    var
        rOrden: Record "Orden Picking SGA";
        rLinea: Record "Linea Orden Picking SGA";
        ordenes: List of [Code[20]];
        noOrden: Code[20];
    begin
        rOrden.SetCurrentKey("Cod. Almacen", Estado);
        rOrden.SetRange("Cod. Almacen", prm_Almacen);
        rOrden.SetFilter(Estado, '%1|%2|%3', rOrden.Estado::Abierta, rOrden.Estado::"En Proceso", rOrden.Estado::"Pendiente Asignar");
        rOrden.SetLoadFields("No. Orden");
        if not rOrden.FindSet() then
            exit;

        // Primero se eligen y luego se borran, para no borrar sobre el recorrido.
        repeat
            rLinea.SetRange("No. Orden", rOrden."No. Orden");
            if prm_Producto <> '' then
                rLinea.SetRange("No. Producto", prm_Producto);
            if (prm_Producto = '') or not rLinea.IsEmpty() then
                ordenes.Add(rOrden."No. Orden");
        until rOrden.Next() = 0;

        rLinea.Reset();
        foreach noOrden in ordenes do begin
            rLinea.SetRange("No. Orden", noOrden);
            rLinea.DeleteAll(false);
            // Sin triggers a propósito: el de la orden no deja borrar con algo recogido.
            if rOrden.Get(noOrden) then
                rOrden.Delete(false);
        end;
    end;

    /// <summary>
    /// Cuánto está preparado de lo que queda por enviar del pedido de venta, mirando sus
    /// líneas de producto con algo pendiente:
    ///   - Preparado: todas tienen recogido, y aún sin enviar, al menos lo que les queda.
    ///   - Parcial: alguna tiene algo recogido sin enviar, pero no todas lo tienen completo.
    ///   - Sin preparar: ninguna tiene nada recogido sin enviar.
    ///   - En blanco: no queda nada pendiente de enviar.
    /// Lo recogido sin enviar es la cantidad preparada menos la ya enviada, porque la preparada
    /// suma todo lo recogido del pedido, también lo que salió en envíos anteriores.
    /// Se calcula siempre al momento: guardarlo obligaría a recalcularlo al registrar envíos
    /// de BC, y SGA no se engancha al registro.
    /// </summary>
    procedure EstadoPreparacionVenta(prm_Cabecera: Record "Sales Header"): Enum "Estado Preparacion SGA"
    var
        rLinVenta: Record "Sales Line";
        preparadaSinEnviar: Decimal;
        lineas: Integer;
        completas: Integer;
        conAlgo: Integer;
    begin
        rLinVenta.SetRange("Document Type", prm_Cabecera."Document Type");
        rLinVenta.SetRange("Document No.", prm_Cabecera."No.");
        rLinVenta.SetRange(Type, rLinVenta.Type::Item);
        rLinVenta.SetFilter("Outstanding Quantity", '>0');
        rLinVenta.SetAutoCalcFields("Cantidad Preparada SGA");
        if not rLinVenta.FindSet() then
            exit("Estado Preparacion SGA"::" ");

        repeat
            lineas += 1;
            preparadaSinEnviar := rLinVenta."Cantidad Preparada SGA" - rLinVenta."Quantity Shipped";
            if preparadaSinEnviar > 0 then
                conAlgo += 1;
            if preparadaSinEnviar >= rLinVenta."Outstanding Quantity" then
                completas += 1;
        until rLinVenta.Next() = 0;

        if completas = lineas then
            exit("Estado Preparacion SGA"::Preparado);
        if conAlgo > 0 then
            exit("Estado Preparacion SGA"::Parcial);
        exit("Estado Preparacion SGA"::"Sin Preparar");
    end;

    /// <summary>
    /// Marca los pedidos del conjunto recibido (sus filtros) que están en ese estado de
    /// preparación y deja ver solo esos. El estado no es un campo de la tabla y no se puede
    /// filtrar: se marca. Trabaja sobre las marcas del propio registro, así que la lista pasa
    /// su Rec.
    /// </summary>
    procedure MarcarVentasPorEstado(var prm_Venta: Record "Sales Header"; prm_Estado: Enum "Estado Preparacion SGA")
    var
        rCabecera: Record "Sales Header";
    begin
        prm_Venta.ClearMarks();
        prm_Venta.MarkedOnly(false);
        rCabecera.CopyFilters(prm_Venta);
        if rCabecera.FindSet() then
            repeat
                if EstadoPreparacionVenta(rCabecera) = prm_Estado then begin
                    prm_Venta.Get(rCabecera."Document Type", rCabecera."No.");
                    prm_Venta.Mark(true);
                end;
            until rCabecera.Next() = 0;
        prm_Venta.MarkedOnly(true);
    end;

    /// <summary>
    /// Estilo con el que se pinta el estado de preparación en las páginas del pedido.
    /// </summary>
    procedure EstiloEstadoPreparacion(prm_Estado: Enum "Estado Preparacion SGA"): Text
    begin
        case prm_Estado of
            prm_Estado::Preparado:
                exit('Favorable');
            prm_Estado::Parcial:
                exit('Ambiguous');
            prm_Estado::"Sin Preparar":
                exit('Subordinate');
        end;
        exit('Standard');
    end;

    local procedure QtyPorUM(var prm_LinVenta: Record "Sales Line"): Decimal
    begin
        if prm_LinVenta."Qty. per Unit of Measure" <= 0 then
            exit(1);

        exit(prm_LinVenta."Qty. per Unit of Measure");
    end;

    /// <summary>
    /// Siguiente número de la serie configurada.
    /// </summary>
    local procedure SiguienteNoOrden(prm_Serie: Code[20]): Code[20]
    var
        cNoSeries: Codeunit "No. Series";
    begin
        exit(cNoSeries.GetNextNo(prm_Serie));
    end;
}
