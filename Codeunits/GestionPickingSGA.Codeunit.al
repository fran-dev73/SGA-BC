namespace AntonioNadal.SGA;

using Microsoft.Foundation.NoSeries;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;

/// <summary>
/// Codeunit Gestion Picking SGA (ID 51104).
/// Motor de picking: convierte un pedido de venta en un recorrido de paradas, reserva en las
/// ubicaciones lo que cada parada va a coger, registra la retirada cuando el preparador
/// confirma y, al terminar, pasa al pedido lo recogido (cantidad a enviar y lotes).
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
    /// igual con lo que hay y se avisa: es preferible preparar lo que existe que no preparar nada.
    /// </summary>
    procedure CrearOrdenDesdeVenta(prm_NoPedido: Code[20]): Code[20]
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
        totalSinCubrir: Decimal;
        PedidoNoExisteErr: Label 'No existe el pedido de venta %1.', Comment = '%1 = nº pedido';
        SerieOrdenSinConfigurarErr: Label 'Configure la serie "Nos. orden SGA" en la configuración de SGA antes de crear órdenes de picking.';
        PedidoSinPendienteErr: Label 'El pedido %1 no tiene nada pendiente de preparar: lo que queda por servir ya está recogido.', Comment = '%1 = nº pedido';
        DescripcionOrdenLbl: Label 'Picking del pedido %1', Comment = '%1 = nº pedido';
        ContenidoInsuficienteMsg: Label 'No hay contenido ubicado suficiente: han quedado %1 unidades sin asignar a ninguna ubicación.', Comment = '%1 = cantidad sin cubrir';
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

        rLinVenta.SetRange("Document Type", rCabVenta."Document Type"::Order);
        rLinVenta.SetRange("Document No.", prm_NoPedido);
        rLinVenta.SetRange(Type, rLinVenta.Type::Item);
        rLinVenta.SetFilter("Outstanding Qty. (Base)", '>%1', 0);
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
                totalSinCubrir += sinCubrir;
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

        if totalSinCubrir > 0 then
            if GuiAllowed() then
                Message(ContenidoInsuficienteMsg, totalSinCubrir);

        exit(rOrden."No. Orden");
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
    /// producto, creando una parada por cada una. Devuelve lo que no se ha podido cubrir.
    /// </summary>
    local procedure GenerarParadas(var prm_Orden: Record "Orden Picking SGA"; var prm_LinVenta: Record "Sales Line"; prm_CantidadBase: Decimal; var prm_NoLinea: Integer): Decimal
    var
        rContenido: Record "Contenido Ubicacion SGA";
        rLinea: Record "Linea Orden Picking SGA";
        rConfig: Record "Config. SGA";
        rItem: Record Item;
        pendiente: Decimal;
        coger: Decimal;
    begin
        pendiente := prm_CantidadBase;
        if pendiente <= 0 then
            exit(0);

        rConfig.ObtenerConfig();
        if rItem.Get(prm_LinVenta."No.") then;

        rContenido.SetRange("Cod. Almacen", prm_Orden."Cod. Almacen");
        rContenido.SetRange("No. Producto", prm_LinVenta."No.");
        rContenido.SetRange("Cod. Variante", prm_LinVenta."Variant Code");
        rContenido.SetRange(Bloqueado, false);
        rContenido.SetFilter("Cantidad Disponible", '>%1', 0);
        OrdenarPorEstrategia(rContenido, rConfig."Estrategia Picking");

        if rContenido.FindSet() then
            repeat
                coger := rContenido."Cantidad Disponible";
                if coger > pendiente then
                    coger := pendiente;

                if coger > 0 then begin
                    prm_NoLinea += 10000;

                    rLinea.Init();
                    rLinea."No. Orden" := prm_Orden."No. Orden";
                    rLinea."No. Linea" := prm_NoLinea;
                    rLinea."Cod. Almacen" := rContenido."Cod. Almacen";
                    rLinea."No. Producto" := rContenido."No. Producto";
                    rLinea."Descripcion Producto" := CopyStr(rItem.Description, 1, MaxStrLen(rLinea."Descripcion Producto"));
                    rLinea."Cod. Variante" := rContenido."Cod. Variante";
                    rLinea."No. Lote" := rContenido."No. Lote";
                    rLinea."Fecha Caducidad" := rContenido."Fecha Caducidad";
                    rLinea."Cod. Unidad Medida" := rContenido."Cod. Unidad Medida";
                    rLinea."UM Documento" := prm_LinVenta."Unit of Measure Code";
                    rLinea."Ctdad. por UM Documento" := prm_LinVenta."Qty. per Unit of Measure";
                    rLinea."Cantidad a Recoger" := coger;
                    rLinea."Cod. Bin Propuesto" := rContenido."Cod. Bin";
                    rLinea."Secuencia Picking" := rContenido."Secuencia Picking";
                    rLinea."No. Linea Origen" := prm_LinVenta."Line No.";
                    rLinea."No. Documento Origen" := prm_LinVenta."Document No.";
                    rLinea.Estado := rLinea.Estado::Pendiente;
                    rLinea.Insert(true);

                    pendiente -= coger;
                end;
            until (rContenido.Next() = 0) or (pendiente <= 0);

        exit(pendiente);
    end;

    /// <summary>
    /// Fija el orden en que se recorre el contenido según la estrategia configurada.
    /// "Lote exacto" no tiene lote de referencia al generar la orden, así que se comporta
    /// como FEFO: al preparador se le sigue diciendo el lote concreto de cada parada.
    /// </summary>
    local procedure OrdenarPorEstrategia(var prm_Contenido: Record "Contenido Ubicacion SGA"; prm_Estrategia: Enum "Estrategia Picking SGA")
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
    /// Con prm_Bin en blanco se da por buena la ubicación propuesta.
    /// </summary>
    procedure ConfirmarLinea(var prm_Linea: Record "Linea Orden Picking SGA"; prm_Bin: Code[20]; prm_Cantidad: Decimal; prm_DigitoControl: Text)
    var
        rOrden: Record "Orden Picking SGA";
        rConfig: Record "Config. SGA";
        cContenido: Codeunit "Gestion Contenido SGA";
        binReal: Code[20];
        CantidadNoPositivaErr: Label 'La cantidad recogida debe ser mayor que cero.';
        LineaCanceladaErr: Label 'La línea está cancelada.';
        CantidadExcedePendienteErr: Label 'No puede recoger %1: quedan %2 pendientes en esta parada.', Comment = '%1 = cantidad indicada, %2 = cantidad pendiente';
        DesvioNoPermitidoErr: Label 'La configuración no permite recoger de una ubicación distinta de la propuesta (%1).', Comment = '%1 = ubicación propuesta';
        UbicacionNoIndicadaErr: Label 'Indique de qué ubicación ha recogido la mercancía.';
        DescripcionSalidaLbl: Label 'Picking %1 del documento %2', Comment = '%1 = nº orden, %2 = documento origen';
    begin
        if prm_Cantidad <= 0 then
            Error(CantidadNoPositivaErr);

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

        rConfig.ObtenerConfig();
        if (binReal <> prm_Linea."Cod. Bin Propuesto") and (not rConfig."Permitir Desvio Ubicacion") then
            Error(DesvioNoPermitidoErr, prm_Linea."Cod. Bin Propuesto");

        // Certifica que el preparador está delante del hueco del que recoge: el dígito solo
        // está en la etiqueta. Se comprueba aquí y no en la pantalla para que no se pueda saltar.
        if rConfig."Exigir Digito Control" then
            ComprobarDigitoControl(prm_Linea."Cod. Almacen", binReal, prm_DigitoControl);

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

        // La salida va en UM base: es la de la parada. El nº de orden viaja en la descripción
        // porque la puerta única de escritura no expone todavía el campo "No. Orden SGA".
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
    end;

    /// <summary>
    /// Comprueba el dígito de control de la etiqueta del hueco.
    /// </summary>
    procedure ComprobarDigitoControl(prm_Almacen: Code[10]; prm_Bin: Code[20]; prm_Digito: Text)
    var
        rUbicacion: Record "Ubicacion SGA";
        DigitoNoIndicadoErr: Label 'Teclee el dígito de control de la etiqueta de la ubicación %1.', Comment = '%1 = ubicación';
        DigitoIncorrectoErr: Label 'El dígito de control no corresponde a la ubicación %1. Compruebe que está recogiendo del hueco correcto.', Comment = '%1 = ubicación';
        UbicacionSinDigitoErr: Label 'La ubicación %1 no tiene dígito de control. Genérelo e imprima su etiqueta desde la lista de ubicaciones.', Comment = '%1 = ubicación';
    begin
        if DelChr(prm_Digito, '<>', ' ') = '' then
            Error(DigitoNoIndicadoErr, prm_Bin);

        if not rUbicacion.Get(prm_Almacen, prm_Bin) then
            Error(DigitoIncorrectoErr, prm_Bin);

        if rUbicacion."Digito Control" = '' then
            Error(UbicacionSinDigitoErr, prm_Bin);

        if not rUbicacion.DigitoControlCorrecto(prm_Digito) then
            Error(DigitoIncorrectoErr, prm_Bin);
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
    /// Cancela la orden entera y todas sus paradas pendientes, y libera sus reservas.
    /// </summary>
    procedure CancelarOrden(var prm_Orden: Record "Orden Picking SGA")
    var
        rLinea: Record "Linea Orden Picking SGA";
    begin
        rLinea.SetRange("No. Orden", prm_Orden."No. Orden");
        rLinea.SetFilter(Estado, '%1|%2', rLinea.Estado::Pendiente, rLinea.Estado::Parcial);
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
    /// Devuelve la siguiente orden que le toca al usuario actual: primero las suyas sin
    /// terminar, por prioridad. Si no tiene y la configuración no exige asignación, coge la
    /// siguiente sin asignar y se la queda. Devuelve false si no hay ninguna.
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

    local procedure UsuarioActual(): Code[50]
    begin
        exit(CopyStr(UserId(), 1, 50));
    end;

    /// <summary>
    /// Pasa al pedido de venta lo recogido: por cada línea de producto, la cantidad a enviar
    /// y el seguimiento por lote con los lotes que han salido de las ubicaciones.
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
    /// Sustituye el seguimiento por lote de una línea de venta por los lotes recogidos.
    /// Solo toca el seguimiento sin reserva (excedente): si la línea tiene reservas contra
    /// lotes concretos, se para, porque deshacerlas es una decisión de oficina.
    /// </summary>
    local procedure EscribirSeguimientoLotes(var prm_LinVenta: Record "Sales Line"; var prm_Lotes: Dictionary of [Code[50], Decimal]; var prm_Caducidades: Dictionary of [Code[50], Date])
    var
        rReserva: Record "Reservation Entry";
        rSeguimiento: Record "Reservation Entry";
        cCrearReserva: Codeunit "Create Reserv. Entry";
        lote: Code[50];
        cantidadBase: Decimal;
        caducidad: Date;
        hayLotes: Boolean;
        LineaConReservasErr: Label 'La línea %1 del pedido %2 tiene reservas por lote. Anúlelas antes de pasar el picking al pedido.', Comment = '%1 = nº línea, %2 = nº pedido';
    begin
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
        rItem: Record Item;
        cContenido: Codeunit "Gestion Contenido SGA";
        reserva: Decimal;
    begin
        if (prm_Bin = '') or (prm_Producto = '') then
            exit;

        if not rItem.Get(prm_Producto) then
            exit;

        if not rContenido.Get(prm_Almacen, prm_Bin, prm_Producto, prm_Variante, prm_Lote, rItem."Base Unit of Measure") then
            exit;

        rLinea.SetCurrentKey("No. Producto", "No. Lote");
        rLinea.SetRange("No. Producto", prm_Producto);
        rLinea.SetRange("No. Lote", prm_Lote);
        rLinea.SetRange("Cod. Variante", prm_Variante);
        rLinea.SetRange("Cod. Almacen", prm_Almacen);
        rLinea.SetRange("Cod. Bin Propuesto", prm_Bin);
        rLinea.SetFilter(Estado, '%1|%2', rLinea.Estado::Pendiente, rLinea.Estado::Parcial);
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
        rLinea.SetFilter(Estado, '%1|%2', rLinea.Estado::Pendiente, rLinea.Estado::Parcial);
        if rLinea.FindSet() then
            repeat
                RecalcularReserva(rLinea."Cod. Almacen", rLinea."Cod. Bin Propuesto", rLinea."No. Producto", rLinea."Cod. Variante", rLinea."No. Lote");
            until rLinea.Next() = 0;
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
