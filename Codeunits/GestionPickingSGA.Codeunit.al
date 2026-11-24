namespace AntonioNadal.SGA;

using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using System.Security.User;
using System.Utilities;

/// <summary>
/// Codeunit Gestion Picking SGA (ID 51104).
/// Motor de picking: convierte un pedido de venta en un recorrido de paradas, reserva en las
/// ubicaciones lo que cada parada va a coger, registra la retirada cuando el preparador
/// confirma y, al terminar, pasa al pedido lo recogido (cantidad a enviar y lotes).
///
/// Las órdenes sirven también para las reubicaciones de almacenamiento a picking (origen
/// Reposicion, AnadirReubicacion): la parada lleva una ubicación destino y, al confirmarla, lo
/// recogido se traslada allí en vez de salir. Qué reubicar lo decide Cod. "Reposiciones SGA".
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
    /// Envía a SGA un pedido de venta lanzado: lo reparte en órdenes de picking de un palé como
    /// mucho, porque el preparador no puede llevar más de uno a la vez. Cada palé completo de
    /// una línea es una orden; lo que sobra de cada línea (unidades sueltas) se junta con lo
    /// suelto de otras líneas en órdenes que no pasan de un palé, contado en fracción del palé de
    /// cada producto. Las líneas de caja (la unidad de venta de la ficha) van aparte: una orden
    /// por producto (ver EnviarCajas). Devuelve cuántas órdenes ha creado.
    ///
    /// Todos los productos deben tener palé en su ficha: sin él no se sabe qué es un palé. Si
    /// alguna línea no se puede cubrir entera con el contenido ubicado, se crean igual las
    /// órdenes con lo que hay; lo que falta va en prm_Faltas, una línea por producto, y se
    /// prepara en la segunda ronda (SegundaRonda) cuando haya stock ubicado.
    ///
    /// No se envía si el pedido tiene alguna orden sin terminar: la segunda ronda espera a que
    /// acaben todas.
    /// </summary>
    procedure EnviarPedidoASGA(prm_NoPedido: Code[20]; var prm_Faltas: Text) creadas: Integer
    var
        rCabVenta: Record "Sales Header";
        rLinVenta: Record "Sales Line";
        rOrdenSueltos: Record "Orden Picking SGA";
        rOrdenPale: Record "Orden Picking SGA";
        TempOrdenPedido: Record "Orden Picking SGA" temporary;
        TempPlantilla: Record "Linea Orden Picking SGA" temporary;
        rConfig: Record "Config. SGA";
        necesidades: Dictionary of [Integer, Decimal];
        cogibles: Dictionary of [Text, Boolean];
        necesidad: Decimal;
        factorPale: Decimal;
        palesCompletos: Integer;
        pale: Integer;
        noLineaPale: Integer;
        noLineaSueltos: Integer;
        resto: Decimal;
        sinCubrir: Decimal;
        ocupadoSueltos: Decimal;
        PedidoSinPendienteErr: Label 'El pedido %1 no tiene nada pendiente de preparar: lo que queda por servir ya está recogido.', Comment = '%1 = nº pedido';
        DescripcionSueltosLbl: Label 'Pedido %1 · sueltos', Comment = '%1 = nº pedido';
        DescripcionPaleLbl: Label 'Pedido %1 · palé completo', Comment = '%1 = nº pedido';
        SinParadasErr: Label 'No se ha podido generar ninguna línea: no hay contenido ubicado disponible de los productos del pedido.';
    begin
        ComprobarPedidoParaEnviar(prm_NoPedido, rCabVenta);
        // La configuración y lo que comparten las órdenes del pedido se leen una vez.
        rConfig.ObtenerConfig();
        DatosOrdenPedido(rCabVenta, rConfig, TempOrdenPedido);

        FiltrarLineasPendientes(rCabVenta."No.", rLinVenta);
        LeerNecesidades(rLinVenta, necesidades);
        if necesidades.Count() = 0 then
            Error(PedidoSinPendienteErr, prm_NoPedido);

        ocupadoSueltos := 0;
        rLinVenta.SetLoadFields(Type, "No.", Description, "Line No.", "Unit of Measure Code", "Qty. per Unit of Measure");
        rLinVenta.FindSet();
        repeat
            // Lo que se prepara por cajas va aparte, por producto (EnviarCajas).
            if necesidades.Get(rLinVenta."Line No.", necesidad) then
                if not cUM.EsCaja(rLinVenta."No.", rLinVenta."Unit of Measure Code") then begin
                    factorPale := cUM.FactorPale(rLinVenta."No.");
                    PlantillaParadas(rLinVenta, TempOrdenPedido."Cod. Almacen", TempPlantilla);
                    palesCompletos := Round(necesidad / factorPale, 1, '<');
                    resto := necesidad - palesCompletos * factorPale;
                    sinCubrir := 0;

                    // Cada palé completo, en su orden.
                    for pale := 1 to palesCompletos do begin
                        NuevaOrden(TempOrdenPedido, StrSubstNo(DescripcionPaleLbl, rCabVenta."No."), rConfig, rOrdenPale);
                        sinCubrir += GenerarParadas(rOrdenPale, TempPlantilla, factorPale, factorPale, rConfig, noLineaPale, cogibles);
                        CerrarOrdenNueva(rOrdenPale, noLineaPale, creadas);
                    end;

                    if resto > 0 then begin
                        // Lo suelto cabe en la orden de sueltos abierta si con él no pasa de un palé.
                        if (rOrdenSueltos."No. Orden" = '') or (ocupadoSueltos + resto / factorPale > 1) then begin
                            CerrarOrdenNueva(rOrdenSueltos, noLineaSueltos, creadas);
                            NuevaOrden(TempOrdenPedido, StrSubstNo(DescripcionSueltosLbl, rCabVenta."No."), rConfig, rOrdenSueltos);
                            ocupadoSueltos := 0;
                        end;
                        sinCubrir += GenerarParadas(rOrdenSueltos, TempPlantilla, resto, factorPale, rConfig, noLineaSueltos, cogibles);
                        ocupadoSueltos += resto / factorPale;
                    end;

                    if sinCubrir > 0 then
                        AnadirFalta(prm_Faltas, rLinVenta, sinCubrir);
                end;
        until rLinVenta.Next() = 0;
        CerrarOrdenNueva(rOrdenSueltos, noLineaSueltos, creadas);
        EnviarCajas(TempOrdenPedido, rConfig, rLinVenta, necesidades, cogibles, prm_Faltas, creadas);

        if creadas = 0 then
            Error(SinParadasErr);
    end;

    /// <summary>
    /// Lo que comparten todas las órdenes que crea un envío del pedido, leído una vez: almacén,
    /// pedido, cliente, fecha de envío, playa por defecto (la del almacén de la configuración) y
    /// prioridad (la que ya tengan sus órdenes de una ronda anterior; sin ellas, la inicial).
    /// </summary>
    local procedure DatosOrdenPedido(var prm_CabVenta: Record "Sales Header"; var prm_Config: Record "Config. SGA"; var prm_Datos: Record "Orden Picking SGA")
    var
        rAnterior: Record "Orden Picking SGA";
    begin
        prm_Datos.Init();
        prm_Datos."Cod. Almacen" := prm_Config.AlmacenODefecto(prm_CabVenta."Location Code");
        prm_Datos."No. Documento Origen" := prm_CabVenta."No.";
        prm_Datos."Nombre Cliente" := prm_CabVenta."Sell-to Customer Name";
        prm_Datos."Fecha Envio" := prm_CabVenta."Shipment Date";
        if prm_Config."Almacen por Defecto" = prm_Datos."Cod. Almacen" then
            prm_Datos.Playa := prm_Config."Playa por Defecto";
        rAnterior.FiltrarPedido(prm_CabVenta."No.");
        rAnterior.SetLoadFields(Prioridad);
        if rAnterior.FindLast() then
            prm_Datos.Prioridad := rAnterior.Prioridad;
    end;

    /// <summary>
    /// Los datos de las paradas que salen de una línea del pedido (ver InsertarParada), con la
    /// descripción de la ficha del producto (la que ya ha leído cUM para el palé).
    /// </summary>
    local procedure PlantillaParadas(var prm_LinVenta: Record "Sales Line"; prm_Almacen: Code[10]; var prm_Plantilla: Record "Linea Orden Picking SGA")
    begin
        Clear(prm_Plantilla);
        prm_Plantilla."Cod. Almacen" := prm_Almacen;
        prm_Plantilla."No. Producto" := prm_LinVenta."No.";
        prm_Plantilla."Descripcion Producto" := CopyStr(cUM.Descripcion(prm_LinVenta."No."), 1, MaxStrLen(prm_Plantilla."Descripcion Producto"));
        prm_Plantilla."No. Documento Origen" := prm_LinVenta."Document No.";
        prm_Plantilla."No. Linea Origen" := prm_LinVenta."Line No.";
        prm_Plantilla."UM Documento" := prm_LinVenta."Unit of Measure Code";
        prm_Plantilla."Ctdad. por UM Documento" := prm_LinVenta."Qty. per Unit of Measure";
    end;

    /// <summary>
    /// Error si el pedido no se puede enviar a SGA: tiene que existir, estar lanzado y no tener
    /// ninguna orden de picking sin terminar.
    /// </summary>
    local procedure ComprobarPedidoParaEnviar(prm_NoPedido: Code[20]; var prm_CabVenta: Record "Sales Header")
    var
        rOrdenAbierta: Record "Orden Picking SGA";
        NoLanzadoErrorInfo: ErrorInfo;
        NoSeEnviaASGAErr: Label 'No se puede enviar el pedido %1 a SGA', Comment = '%1 = nº pedido';
        OrdenYaAbiertaErr: Label 'El pedido %1 tiene sin terminar la orden de picking %2. Lo que falte se envía cuando estén terminadas todas sus órdenes.', Comment = '%1 = nº pedido, %2 = nº orden';
    begin
        // Solo lo que se comprueba aquí y lo que copian las órdenes (DatosOrdenPedido).
        prm_CabVenta.SetLoadFields(Status, "Location Code", "Sell-to Customer Name", "Shipment Date");
        prm_CabVenta.Get(prm_CabVenta."Document Type"::Order, prm_NoPedido);

        // Lanzado: mientras se prepara, el pedido no debe cambiar por debajo. Error estándar de
        // TestField, con el título que dice que es el envío a SGA lo que no se puede hacer.
        NoLanzadoErrorInfo.Title := StrSubstNo(NoSeEnviaASGAErr, prm_NoPedido);
        prm_CabVenta.TestField(Status, prm_CabVenta.Status::Released, NoLanzadoErrorInfo);

        rOrdenAbierta.FiltrarPedido(prm_NoPedido);
        rOrdenAbierta.FiltrarVivas();
        rOrdenAbierta.SetLoadFields("No. Orden");
        if rOrdenAbierta.FindFirst() then
            Error(OrdenYaAbiertaErr, prm_NoPedido, rOrdenAbierta."No. Orden");
        // La serie de órdenes la comprueba InicializarOrden antes de crear la primera.
    end;

    /// <summary>
    /// Una pasada por las líneas pendientes del pedido: lo que le queda por mandar a recoger a
    /// cada una (NecesidadLinea), solo las que tienen algo, por nº de línea. Error si alguno de
    /// esos productos no tiene palé en su ficha, con la lista de todos para corregirlos de una
    /// vez (después del error de pedido sin nada pendiente, que se da antes).
    /// </summary>
    local procedure LeerNecesidades(var prm_LinVenta: Record "Sales Line"; var prm_Necesidades: Dictionary of [Integer, Decimal])
    var
        rLinea: Record "Sales Line";
        vistos: List of [Code[20]];
        necesidad: Decimal;
        sinPale: Text;
        ProductosSinPaleErr: Label 'Estos productos no tienen palé en su ficha ("Cód. palé por defecto") y SGA prepara por palés:\%1', Comment = '%1 = lista de productos';
    begin
        rLinea.CopyFilters(prm_LinVenta);
        rLinea.SetLoadFields(Type, "No.", Description, "Document No.", "Line No.", "Quantity (Base)", "Outstanding Qty. (Base)");
        if rLinea.FindSet() then
            repeat
                necesidad := NecesidadLinea(rLinea);
                if necesidad > 0 then begin
                    prm_Necesidades.Add(rLinea."Line No.", necesidad);
                    if not vistos.Contains(rLinea."No.") then begin
                        vistos.Add(rLinea."No.");
                        if cUM.UMPale(rLinea."No.") = '' then
                            sinPale += '\' + rLinea."No." + ' ' + rLinea.Description;
                    end;
                end;
            until rLinea.Next() = 0;

        // Solo salen productos de líneas con necesidad: si hay alguno, el pedido tiene pendiente.
        if sinPale <> '' then
            Error(ProductosSinPaleErr, sinPale);
    end;

    local procedure UltimaLineaOrden(prm_NoOrden: Code[20]): Integer
    var
        rLinea: Record "Linea Orden Picking SGA";
    begin
        rLinea.SetRange("No. Orden", prm_NoOrden);
        rLinea.SetLoadFields("No. Linea");
        if rLinea.FindLast() then
            exit(rLinea."No. Linea");
        exit(0);
    end;

    /// <summary>
    /// Cabecera de una orden de picking del pedido, con lo que comparten todas las del envío
    /// (prm_Datos, ver DatosOrdenPedido). prm_Descripcion la pone quien la crea (palé, sueltos o
    /// cajas).
    /// </summary>
    local procedure NuevaOrden(var prm_Datos: Record "Orden Picking SGA"; prm_Descripcion: Text[100]; var prm_Config: Record "Config. SGA"; var prm_Orden: Record "Orden Picking SGA")
    begin
        InicializarOrden(prm_Datos."Cod. Almacen", prm_Orden.Origen::Venta, prm_Descripcion, prm_Config, prm_Orden);
        prm_Orden."No. Documento Origen" := prm_Datos."No. Documento Origen";
        prm_Orden."Nombre Cliente" := prm_Datos."Nombre Cliente";
        prm_Orden."Fecha Envio" := prm_Datos."Fecha Envio";
        prm_Orden.Playa := prm_Datos.Playa;
        prm_Orden.Prioridad := prm_Datos.Prioridad;
        prm_Orden.Insert(true);
    end;

    /// <summary>
    /// Prepara la cabecera de una orden nueva (sin insertar): número de la serie de la
    /// configuración (ya leída), almacén, origen, descripción y estado sin empezar. Es el único
    /// sitio que numera órdenes, de venta o de reubicaciones.
    /// </summary>
    local procedure InicializarOrden(prm_Almacen: Code[10]; prm_Origen: Enum "Origen Mov. SGA"; prm_Descripcion: Text[100]; var prm_Config: Record "Config. SGA"; var prm_Orden: Record "Orden Picking SGA")
    var
        cNoSeries: Codeunit "No. Series";
        SerieOrdenSinConfigurarErr: Label 'Configure la serie "Nos. orden SGA" en la configuración de SGA: sin ella no se pueden crear órdenes de picking ni de reposición.';
    begin
        if prm_Config."Nos. Orden SGA" = '' then
            Error(SerieOrdenSinConfigurarErr);
        Clear(prm_Orden);
        prm_Orden.Init();
        prm_Orden."No. Orden" := cNoSeries.GetNextNo(prm_Config."Nos. Orden SGA");
        prm_Orden."Cod. Almacen" := prm_Almacen;
        prm_Orden.Origen := prm_Origen;
        prm_Orden.Descripcion := prm_Descripcion;
        // Con "Exigir asignación" nace pendiente de asignar; si no, abierta para cualquiera.
        prm_Orden.Estado := prm_Orden.EstadoSinEmpezar(prm_Config."Exigir Asignacion Picking");
    end;

    /// <summary>
    /// Pedido de productos que se preparan por cajas (la unidad de venta de la ficha). Una orden
    /// por producto con todas sus cajas, aunque vengan en varias líneas. Al elegir la siguiente
    /// orden (VaAntesQue), entre las de cajas del pedido salen antes las de más volumen, para que
    /// queden abajo al apilar. Lo que no se cubre va en prm_Faltas. prm_Necesidades trae lo que
    /// le queda a cada línea (LeerNecesidades).
    /// </summary>
    local procedure EnviarCajas(var prm_Datos: Record "Orden Picking SGA"; var prm_Config: Record "Config. SGA"; var prm_LinVenta: Record "Sales Line"; var prm_Necesidades: Dictionary of [Integer, Decimal]; var prm_Cogibles: Dictionary of [Text, Boolean]; var prm_Faltas: Text; var prm_Creadas: Integer)
    var
        rLinea: Record "Sales Line";
        rProducto: Record "Sales Line";
        rOrden: Record "Orden Picking SGA";
        TempPlantilla: Record "Linea Orden Picking SGA" temporary;
        productosHechos: List of [Code[20]];
        necesidad: Decimal;
        sinCubrirProducto: Decimal;
        noLinea: Integer;
        DescripcionCajasLbl: Label 'Pedido %1 · cajas', Comment = '%1 = nº pedido';
    begin
        rLinea.CopyFilters(prm_LinVenta);
        rLinea.SetLoadFields(Type, "No.", Description, "Document No.", "Line No.", "Unit of Measure Code", "Qty. per Unit of Measure");
        if not rLinea.FindSet() then
            exit;

        repeat
            if not productosHechos.Contains(rLinea."No.") then
                if cUM.EsCaja(rLinea."No.", rLinea."Unit of Measure Code") then begin
                    productosHechos.Add(rLinea."No.");
                    rProducto.CopyFilters(rLinea);
                    rProducto.SetLoadFields(Type, "No.", Description, "Document No.", "Line No.", "Unit of Measure Code", "Qty. per Unit of Measure");
                    rProducto.SetRange("No.", rLinea."No.");
                    rProducto.FindSet();
                    sinCubrirProducto := 0;
                    repeat
                        if prm_Necesidades.Get(rProducto."Line No.", necesidad) then
                            if cUM.EsCaja(rProducto."No.", rProducto."Unit of Measure Code") then begin
                                if rOrden."No. Orden" = '' then
                                    NuevaOrden(prm_Datos, StrSubstNo(DescripcionCajasLbl, prm_Datos."No. Documento Origen"), prm_Config, rOrden);
                                PlantillaParadas(rProducto, prm_Datos."Cod. Almacen", TempPlantilla);
                                sinCubrirProducto += GenerarParadas(rOrden, TempPlantilla, necesidad, cUM.FactorPale(rProducto."No."), prm_Config, noLinea, prm_Cogibles);
                            end;
                    until rProducto.Next() = 0;
                    CerrarOrdenNueva(rOrden, noLinea, prm_Creadas);

                    if sinCubrirProducto > 0 then
                        // rLinea es también la caja de venta del producto: misma unidad.
                        AnadirFalta(prm_Faltas, rLinea, sinCubrirProducto);
                end;
        until rLinea.Next() = 0;
    end;

    /// <summary>
    /// Añade al aviso de faltas una línea con lo que no se ha podido cubrir del producto de la
    /// línea de venta, pasado de base a la UM de la línea.
    /// </summary>
    local procedure AnadirFalta(var prm_Faltas: Text; var prm_LinVenta: Record "Sales Line"; prm_SinCubrirBase: Decimal)
    var
        cUOMMgt: Codeunit "Unit of Measure Management";
        FaltaLineaTxt: Label '%1 %2: faltan %3 %4', Comment = '%1 = producto, %2 = descripción, %3 = cantidad, %4 = unidad';
    begin
        if prm_Faltas <> '' then
            prm_Faltas += '\';
        prm_Faltas += StrSubstNo(FaltaLineaTxt, prm_LinVenta."No.", prm_LinVenta.Description,
                                 cUOMMgt.CalcQtyFromBase(prm_SinCubrirBase, prm_LinVenta."Qty. per Unit of Measure"), prm_LinVenta."Unit of Measure Code");
    end;

    /// <summary>
    /// Da por hecha una orden recién creada: si no ha cogido ninguna parada (sin stock
    /// ubicado; prm_NoLinea, su última parada, sigue a 0), se borra; si tiene, se cuenta. Deja
    /// prm_Orden vacía y prm_NoLinea a 0 para la siguiente.
    /// </summary>
    local procedure CerrarOrdenNueva(var prm_Orden: Record "Orden Picking SGA"; var prm_NoLinea: Integer; var prm_Creadas: Integer)
    begin
        if prm_Orden."No. Orden" = '' then
            exit;

        if prm_NoLinea = 0 then
            prm_Orden.Delete(true)
        else
            prm_Creadas += 1;
        Clear(prm_Orden);
        prm_NoLinea := 0;
    end;

    /// <summary>
    /// Un pedido enviado a SGA (con alguna orden de picking, en cualquier estado) no se vuelve
    /// a abrir: su picking se ha calculado sobre las líneas lanzadas y la reserva de las
    /// ubicaciones depende de ellas.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Sales Document", OnBeforeManualReOpenSalesDoc, '', false, false)]
    local procedure NoReabrirPedidoEnviado(var SalesHeader: Record "Sales Header"; PreviewMode: Boolean)
    var
        rOrden: Record "Orden Picking SGA";
        PedidoEnviadoErr: Label 'El pedido %1 se ha enviado a SGA y no se puede volver a abrir.', Comment = '%1 = nº pedido';
    begin
        if SalesHeader."Document Type" <> SalesHeader."Document Type"::Order then
            exit;
        rOrden.FiltrarPedido(SalesHeader."No.");
        if not rOrden.IsEmpty() then
            Error(PedidoEnviadoErr, SalesHeader."No.");
    end;

    /// <summary>
    /// Segunda ronda de picking: a cada pedido de venta lanzado que ya pasó por picking, no tiene
    /// orden abierta y aún tiene algo por preparar le crea una orden con lo que falta, si ya hay
    /// contenido ubicado de alguno de esos productos. Lo que sigue sin stock espera a la
    /// siguiente ronda. Cada pedido se envía por separado (Cod. "Enviar Pedido SGA"): uno que
    /// da error no para a los demás y su error sale en el resumen. Devuelve el resumen para
    /// enseñarlo.
    /// </summary>
    procedure SegundaRonda() resumen: Text
    var
        rCabVenta: Record "Sales Header";
        rConfig: Record "Config. SGA";
        cEnviar: Codeunit "Enviar Pedido SGA";
        cogibles: Dictionary of [Text, Boolean];
        productos: List of [Code[20]];
        creadas: Integer;
        esperan: Integer;
        detalle: Text;
        ResumenTxt: Label 'Segunda ronda: %1 órdenes nuevas. %2 pedidos siguen esperando stock ubicado.', Comment = '%1 = órdenes creadas, %2 = pedidos sin stock';
        OrdenesCreadasTxt: Label '%1 → %2 órdenes', Comment = '%1 = nº pedido, %2 = número de órdenes';
        PedidoConErrorTxt: Label '%1 → no enviado: %2', Comment = '%1 = nº pedido, %2 = error';
    begin
        rConfig.ObtenerConfig();
        rCabVenta.SetRange("Document Type", rCabVenta."Document Type"::Order);
        rCabVenta.SetRange(Status, rCabVenta.Status::Released);
        rCabVenta.SetLoadFields("No.", "Location Code");
        if rCabVenta.FindSet() then
            repeat
                if PideSegundaRonda(rCabVenta."No.", productos) then
                    if HayContenidoParaFaltas(rConfig.AlmacenODefecto(rCabVenta."Location Code"), productos, rConfig, cogibles) then begin
                        if cEnviar.Run(rCabVenta) then begin
                            creadas += cEnviar.OrdenesCreadas();
                            detalle += '\' + StrSubstNo(OrdenesCreadasTxt, rCabVenta."No.", cEnviar.OrdenesCreadas());
                        end else
                            detalle += '\' + StrSubstNo(PedidoConErrorTxt, rCabVenta."No.", GetLastErrorText());
                    end else
                        esperan += 1;
            until rCabVenta.Next() = 0;

        resumen := StrSubstNo(ResumenTxt, creadas, esperan) + detalle;
    end;

    /// <summary>
    /// Si el pedido entra en la segunda ronda: ya ha tenido alguna orden de picking, no tiene
    /// ninguna viva y le queda algo por mandar a recoger. Deja en prm_Productos los productos a
    /// los que les falta algo, para buscar su contenido sin volver a calcular las líneas.
    /// </summary>
    local procedure PideSegundaRonda(prm_NoPedido: Code[20]; var prm_Productos: List of [Code[20]]): Boolean
    var
        rOrden: Record "Orden Picking SGA";
        rLinVenta: Record "Sales Line";
    begin
        Clear(prm_Productos);
        rOrden.FiltrarPedido(prm_NoPedido);
        if rOrden.IsEmpty() then
            exit(false);
        rOrden.FiltrarVivas();
        if not rOrden.IsEmpty() then
            exit(false);

        FiltrarLineasPendientes(prm_NoPedido, rLinVenta);
        rLinVenta.SetLoadFields(Type, "No.", "Document No.", "Line No.", "Quantity (Base)", "Outstanding Qty. (Base)");
        if rLinVenta.FindSet() then
            repeat
                if not prm_Productos.Contains(rLinVenta."No.") then
                    if NecesidadLinea(rLinVenta) > 0 then
                        prm_Productos.Add(rLinVenta."No.");
            until rLinVenta.Next() = 0;
        exit(prm_Productos.Count() > 0);
    end;

    /// <summary>
    /// Si hay contenido ubicado disponible en el almacén de alguno de los productos que le faltan
    /// al pedido (PideSegundaRonda). La configuración y lo que se sabe de cada ubicación
    /// (prm_Cogibles) vienen de SegundaRonda, leídos una vez para todos los pedidos.
    /// </summary>
    local procedure HayContenidoParaFaltas(prm_Almacen: Code[10]; var prm_Productos: List of [Code[20]]; var prm_Config: Record "Config. SGA"; var prm_Cogibles: Dictionary of [Text, Boolean]): Boolean
    var
        rContenido: Record "Contenido Ubicacion SGA";
        producto: Code[20];
    begin
        rContenido.SetLoadFields("Cod. Almacen", "Cod. Bin");
        foreach producto in prm_Productos do begin
            rContenido.FiltrarDisponible(prm_Almacen, producto);
            if rContenido.FindSet() then
                repeat
                    if rContenido.SePuedeCoger(prm_Config."Ubic. Ajustes", prm_Cogibles) then
                        exit(true);
                until rContenido.Next() = 0;
        end;
        exit(false);
    end;

    /// <summary>
    /// Las líneas de producto del pedido con algo pendiente de servir.
    /// </summary>
    local procedure FiltrarLineasPendientes(prm_NoPedido: Code[20]; var prm_LinVenta: Record "Sales Line")
    begin
        prm_LinVenta.SetRange("Document Type", prm_LinVenta."Document Type"::Order);
        prm_LinVenta.SetRange("Document No.", prm_NoPedido);
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
        rLinea: Record "Linea Orden Picking SGA";
        necesidad: Decimal;
    begin
        // Solo se prepara lo que SGA ubica: lo demás (no inventariable, "Producto Tianna",
        // categoría excluida) no está en las ubicaciones.
        if not cStock.EsProductoSGA(prm_LinVenta."No.", cUM) then
            exit(0);
        rLinea.FiltrarLineaPedido(prm_LinVenta."Document No.", prm_LinVenta."Line No.");
        rLinea.CalcSums("Cantidad Recogida");
        necesidad := prm_LinVenta."Quantity (Base)" - rLinea."Cantidad Recogida";
        if necesidad > prm_LinVenta."Outstanding Qty. (Base)" then
            necesidad := prm_LinVenta."Outstanding Qty. (Base)";
        if necesidad < 0 then
            necesidad := 0;

        exit(necesidad);
    end;

    /// <summary>
    /// Reparte la cantidad de una línea del pedido entre las ubicaciones que tienen el
    /// producto, creando una parada por cada una, en tres pasadas:
    ///   1. los palés completos, de almacenamiento: no se deshace el palé de picking para servir
    ///      uno entero;
    ///   2. lo demás, de picking, que es de donde se prepara;
    ///   3. lo que no haya en picking, del resto (almacenamiento y ubicaciones sin tipo).
    /// En cada pasada el contenido va en el orden de la estrategia de picking. Llega siempre una
    /// cantidad positiva de un producto con palé (LeerNecesidades lo exige). prm_Plantilla trae
    /// los datos de la línea del pedido (PlantillaParadas) y prm_NoLinea la última parada de la
    /// orden. Reserva al terminar, y no al final del pedido: la siguiente orden tiene que ver ya
    /// descontado lo que coge esta. Devuelve lo que no se ha podido cubrir.
    /// </summary>
    local procedure GenerarParadas(var prm_Orden: Record "Orden Picking SGA"; var prm_Plantilla: Record "Linea Orden Picking SGA"; prm_CantidadBase: Decimal; prm_FactorPale: Decimal; var prm_Config: Record "Config. SGA"; var prm_NoLinea: Integer; var prm_Cogibles: Dictionary of [Text, Boolean]): Decimal
    var
        cogido: Dictionary of [Text, Decimal];
        pendiente: Decimal;
        ultimaAnterior: Integer;
        pasada: Integer;
        ubicaciones: Text;
    begin
        pendiente := prm_CantidadBase;
        ultimaAnterior := prm_NoLinea;
        for pasada := 1 to 3 do
            AnadirParadasPasada(prm_Orden, prm_Plantilla, prm_Config, pasada, prm_FactorPale, cogido, prm_Cogibles, pendiente, prm_NoLinea, ubicaciones);
        if prm_NoLinea > ultimaAnterior then
            RecalcularReservasDesde(prm_Orden, ultimaAnterior);

        exit(pendiente);
    end;

    /// <summary>
    /// Acota el contenido ya filtrado a las ubicaciones de una pasada (1 almacenamiento, 2
    /// picking, 3 el resto) y a un tramo de la estrategia, lo ordena y se sitúa en el primero.
    /// Las reposiciones buscan con la pasada 1 qué traer de almacenamiento.
    /// </summary>
    procedure BuscarEnPasada(var prm_Contenido: Record "Contenido Ubicacion SGA"; prm_Pasada: Integer; prm_Estrategia: Enum "Estrategia Picking SGA"; prm_Tramo: Integer): Boolean
    begin
        case prm_Pasada of
            1:
                prm_Contenido.SetRange("Tipo Ubicacion", prm_Contenido."Tipo Ubicacion"::Almacenamiento);
            2:
                prm_Contenido.SetRange("Tipo Ubicacion", prm_Contenido."Tipo Ubicacion"::Picking);
            else
                prm_Contenido.SetFilter("Tipo Ubicacion", '<>%1', prm_Contenido."Tipo Ubicacion"::Picking);
        end;
        prm_Contenido.SetAutoCalcFields("Secuencia Picking");
        if not OrdenarPorEstrategia(prm_Contenido, prm_Estrategia, prm_Tramo) then
            exit(false);
        exit(prm_Contenido.FindSet());
    end;

    /// <summary>
    /// Una pasada (1 almacenamiento, 2 picking, 3 el resto) de GenerarParadas o de
    /// SustituirParadaSinStock: paradas nuevas del producto con los datos de prm_Plantilla
    /// (documento, unidad del documento, destino si es una reubicación y, al sustituir, la
    /// ubicación vacía que no se vuelve a proponer). Con prm_FactorPale, la pasada 1 coge solo
    /// palés enteros. Lo que ya ha cogido una pasada anterior de cada línea de contenido va en
    /// prm_Cogido: la reserva no se recalcula hasta terminar, así que la disponible aún no lo
    /// descuenta. Las ubicaciones usadas se van añadiendo a prm_Ubicaciones. prm_Cogibles guarda,
    /// para todo el proceso, si de cada ubicación se puede coger (SePuedeCoger).
    /// </summary>
    local procedure AnadirParadasPasada(var prm_Orden: Record "Orden Picking SGA"; prm_Plantilla: Record "Linea Orden Picking SGA"; var prm_Config: Record "Config. SGA"; prm_Pasada: Integer; prm_FactorPale: Decimal; var prm_Cogido: Dictionary of [Text, Decimal]; var prm_Cogibles: Dictionary of [Text, Boolean]; var prm_Pendiente: Decimal; var prm_NoLinea: Integer; var prm_Ubicaciones: Text)
    var
        rContenido: Record "Contenido Ubicacion SGA";
        ubicAjustes: Code[20];
        yaCogido: Decimal;
        coger: Decimal;
        tramo: Integer;
    begin
        rContenido.FiltrarDisponible(prm_Plantilla."Cod. Almacen", prm_Plantilla."No. Producto");
        // Al sustituir una parada, su ubicación (vacía) no se vuelve a proponer.
        if prm_Plantilla."Cod. Bin Propuesto" <> '' then
            rContenido.SetFilter("Cod. Bin", '<>%1', prm_Plantilla."Cod. Bin Propuesto");
        // Una reubicación (con destino) puede salir de la ubicación de ajustes; un picking no.
        if prm_Plantilla."Cod. Bin Destino" = '' then
            ubicAjustes := prm_Config."Ubic. Ajustes";

        for tramo := 1 to 2 do
            if prm_Pendiente > 0 then
                if BuscarEnPasada(rContenido, prm_Pasada, prm_Config."Estrategia Picking", tramo) then
                    repeat
                        if not prm_Cogido.Get(rContenido.GetPosition(), yaCogido) then
                            yaCogido := 0;
                        coger := rContenido."Cantidad Disponible" - yaCogido;
                        if coger > prm_Pendiente then
                            coger := prm_Pendiente;
                        // En la primera pasada de un pedido, solo palés enteros (sin factor, sin redondeo).
                        if (prm_Pasada = 1) and (prm_FactorPale > 0) then
                            coger := Round(coger / prm_FactorPale, 1, '<') * prm_FactorPale;

                        if coger > 0 then
                            if rContenido.SePuedeCoger(ubicAjustes, prm_Cogibles) then begin
                                InsertarParada(prm_Orden, rContenido, coger, prm_Plantilla, prm_NoLinea);
                                prm_Cogido.Set(rContenido.GetPosition(), yaCogido + coger);
                                prm_Pendiente -= coger;
                                if prm_Ubicaciones <> '' then
                                    prm_Ubicaciones += ', ';
                                prm_Ubicaciones += rContenido."Cod. Bin";
                            end;
                    until (rContenido.Next() = 0) or (prm_Pendiente <= 0);
    end;

    /// <summary>
    /// Añade a la orden una parada para recoger prm_Cantidad (en base) de una línea de contenido,
    /// con de prm_Plantilla la descripción del producto, el documento (pedido y línea), su unidad
    /// y factor, y el destino. Con destino es una reposición: lo recogido se deja en esa
    /// ubicación, y el documento va en blanco. prm_Contenido tiene que traer calculada la
    /// "Secuencia Picking".
    /// </summary>
    local procedure InsertarParada(var prm_Orden: Record "Orden Picking SGA"; var prm_Contenido: Record "Contenido Ubicacion SGA"; prm_Cantidad: Decimal; prm_Plantilla: Record "Linea Orden Picking SGA"; var prm_NoLinea: Integer)
    var
        rLinea: Record "Linea Orden Picking SGA";
    begin
        prm_NoLinea += 10000;
        rLinea.Init();
        rLinea."No. Orden" := prm_Orden."No. Orden";
        rLinea."No. Linea" := prm_NoLinea;
        rLinea."Cod. Almacen" := prm_Contenido."Cod. Almacen";
        rLinea."No. Producto" := prm_Contenido."No. Producto";
        rLinea."Descripcion Producto" := prm_Plantilla."Descripcion Producto";
        rLinea."No. Lote" := prm_Contenido."No. Lote";
        rLinea.SSCC := prm_Contenido.SSCC;
        rLinea."Fecha Caducidad" := prm_Contenido."Fecha Caducidad";
        rLinea."Cod. Unidad Medida" := prm_Contenido."Cod. Unidad Medida";
        rLinea."UM Documento" := prm_Plantilla."UM Documento";
        rLinea."Ctdad. por UM Documento" := prm_Plantilla."Ctdad. por UM Documento";
        rLinea."Cantidad a Recoger" := prm_Cantidad;
        rLinea."Cod. Bin Propuesto" := prm_Contenido."Cod. Bin";
        rLinea."Cod. Bin Destino" := prm_Plantilla."Cod. Bin Destino";
        rLinea."Secuencia Picking" := prm_Contenido."Secuencia Picking";
        rLinea."No. Linea Origen" := prm_Plantilla."No. Linea Origen";
        rLinea."No. Documento Origen" := prm_Plantilla."No. Documento Origen";
        rLinea.Estado := rLinea.Estado::Pendiente;
        rLinea.Insert(true);
    end;

    /// <summary>
    /// Planifica una reubicación: una parada que recoge prm_Cantidad (en base) de la línea de
    /// contenido y la deja en la ubicación prm_Destino. Va a la orden de reubicaciones del
    /// almacén que aún no ha empezado nadie (la crea si no hay), y reserva lo que va a coger, como
    /// cualquier parada. Lo que decide qué reubicar y adónde es Cod. "Reposiciones SGA".
    /// </summary>
    procedure AnadirReubicacion(var prm_Contenido: Record "Contenido Ubicacion SGA"; prm_Cantidad: Decimal; prm_Destino: Code[20])
    var
        rOrden: Record "Orden Picking SGA";
        TempPlantilla: Record "Linea Orden Picking SGA" temporary;
        rConfig: Record "Config. SGA";
        noLinea: Integer;
        umPale: Code[10];
        factorPale: Decimal;
        DescripcionReubicacionesLbl: Label 'Reposición de picking';
    begin
        rOrden.SetCurrentKey("Cod. Almacen", Estado);
        rOrden.SetRange("Cod. Almacen", prm_Contenido."Cod. Almacen");
        rOrden.FiltrarSinEmpezar();
        rOrden.SetRange(Origen, rOrden.Origen::Reposicion);
        if not rOrden.FindFirst() then begin
            rConfig.ObtenerConfig();
            InicializarOrden(prm_Contenido."Cod. Almacen", rOrden.Origen::Reposicion, DescripcionReubicacionesLbl, rConfig, rOrden);
            rOrden.Insert(true);
        end;

        noLinea := UltimaLineaOrden(rOrden."No. Orden");

        // Al carretillero se le enseña en palés si es un palé justo; si no, en la unidad base.
        // La "Secuencia Picking" ya viene calculada de la búsqueda del origen (BuscarEnPasada).
        TempPlantilla."Descripcion Producto" := CopyStr(cUM.Descripcion(prm_Contenido."No. Producto"), 1, MaxStrLen(TempPlantilla."Descripcion Producto"));
        TempPlantilla."Cod. Bin Destino" := prm_Destino;
        TempPlantilla."UM Documento" := prm_Contenido."Cod. Unidad Medida";
        TempPlantilla."Ctdad. por UM Documento" := 1;
        cUM.LeerPale(prm_Contenido."No. Producto", umPale, factorPale);
        if (umPale <> '') and (prm_Cantidad = factorPale) then begin
            TempPlantilla."UM Documento" := umPale;
            TempPlantilla."Ctdad. por UM Documento" := prm_Cantidad;
        end;
        InsertarParada(rOrden, prm_Contenido, prm_Cantidad, TempPlantilla, noLinea);

        RecalcularReserva(prm_Contenido."Cod. Almacen", prm_Contenido."Cod. Bin", prm_Contenido."No. Producto",
                          prm_Contenido."No. Lote", prm_Contenido."Cod. Unidad Medida", prm_Contenido.SSCC);
    end;

    /// <summary>
    /// Fija el orden en que se recorre el contenido según la estrategia configurada, en tramos
    /// que se recorren uno detrás de otro (1 y 2). Devuelve false si la estrategia no tiene ese
    /// tramo. FIFO y Por orden de ubicación (código de ubicación) van en un tramo. FEFO va en
    /// dos: primero lo que tiene caducidad, de la más próxima a la más lejana, y después lo que
    /// no la tiene (por la clave, la fecha en blanco iría delante de todas). Al preparador se le
    /// dice el lote concreto de cada parada.
    /// </summary>
    local procedure OrdenarPorEstrategia(var prm_Contenido: Record "Contenido Ubicacion SGA"; prm_Estrategia: Enum "Estrategia Picking SGA"; prm_Tramo: Integer): Boolean
    begin
        case prm_Estrategia of
            prm_Estrategia::FIFO:
                prm_Contenido.SetCurrentKey("Cod. Almacen", "No. Producto", "Fecha Entrada");
            prm_Estrategia::"Orden Ubicacion":
                prm_Contenido.SetCurrentKey("Cod. Almacen", "Cod. Bin");
            else begin
                prm_Contenido.SetCurrentKey("Cod. Almacen", "No. Producto", Bloqueado, "Fecha Caducidad", "Cod. Bin");
                case prm_Tramo of
                    1:
                        prm_Contenido.SetFilter("Fecha Caducidad", '<>%1', 0D);
                    2:
                        prm_Contenido.SetRange("Fecha Caducidad", 0D);
                    else
                        exit(false);
                end;
                exit(true);
            end;
        end;
        exit(prm_Tramo = 1);
    end;

    /// <summary>
    /// Confirma que el preparador ha recogido una cantidad base de una parada. Es el punto en
    /// el que el stock sale de la ubicación y queda la huella en el diario de movimientos.
    /// La ubicación de la que se recoge es siempre obligatoria: se lee de la etiqueta del hueco y
    /// se compara con el que tiene la parada. Ni el producto ni el palé se leen: se da por bueno
    /// que sale del palé de la parada si se coge de su ubicación y, si se coge de otra, del palé
    /// de esa ubicación (Gestion Contenido SGA.SSCCEnUbicacion).
    /// </summary>
    procedure ConfirmarLinea(var prm_Linea: Record "Linea Orden Picking SGA"; prm_Bin: Code[20]; prm_Cantidad: Decimal)
    var
        rOrden: Record "Orden Picking SGA";
        rConfig: Record "Config. SGA";
        cContenido: Codeunit "Gestion Contenido SGA";
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        sscc: Code[20];
        CantidadNoPositivaErr: Label 'La cantidad recogida debe ser mayor que cero.';
        LineaCanceladaErr: Label 'La línea está cancelada.';
        CantidadExcedePendienteErr: Label 'No puede recoger %1: quedan %2 pendientes en esta línea.', Comment = '%1 = cantidad indicada, %2 = cantidad pendiente';
        DesvioNoPermitidoErr: Label 'La configuración no permite recoger de una ubicación distinta de la propuesta (%1).', Comment = '%1 = ubicación propuesta';
        UbicacionNoEscaneadaErr: Label 'Escanee o teclee la ubicación de la que ha recogido.';
        DescripcionSalidaLbl: Label 'Picking %1 del documento %2', Comment = '%1 = nº orden, %2 = documento origen';
        DescripcionReubicacionLbl: Label 'Reposición de picking, orden %1', Comment = '%1 = nº orden';
    begin
        if prm_Cantidad <= 0 then
            Error(CantidadNoPositivaErr);

        if prm_Bin = '' then
            Error(UbicacionNoEscaneadaErr);

        if prm_Linea.Estado = prm_Linea.Estado::Cancelada then
            Error(LineaCanceladaErr);

        prm_Linea.ActualizarPendiente();
        if prm_Cantidad > prm_Linea."Cantidad Pendiente" then
            Error(CantidadExcedePendienteErr, prm_Cantidad, prm_Linea."Cantidad Pendiente");

        rConfig.ObtenerConfig();
        if not rConfig.DesvioPermitido(prm_Linea."Cod. Bin Propuesto", prm_Bin) then
            Error(DesvioNoPermitidoErr, prm_Linea."Cod. Bin Propuesto");

        // Certifica que el hueco leído es una ubicación SGA. Se comprueba aquí y no en la pantalla
        // para que no se pueda saltar.
        cUbicaciones.ComprobarUbicacionExiste(prm_Linea."Cod. Almacen", prm_Bin);

        rOrden.Get(prm_Linea."No. Orden");
        ComprobarPreparador(rOrden, rConfig);

        if prm_Bin = prm_Linea."Cod. Bin Propuesto" then
            sscc := prm_Linea.SSCC
        else
            sscc := cContenido.SSCCEnUbicacion(prm_Linea."Cod. Almacen", prm_Bin, prm_Linea."No. Producto",
                                               prm_Linea."No. Lote");

        // La parada se actualiza antes de la salida para que la reserva del hueco ya esté
        // rebajada cuando la salida lo vacíe.
        prm_Linea."Cod. Bin Confirmado" := prm_Bin;
        prm_Linea."SSCC Recogido" := sscc;
        // Una línea recogida en varias veces es desvío si lo ha sido alguna de ellas.
        if prm_Bin <> prm_Linea."Cod. Bin Propuesto" then
            prm_Linea.Desvio := true;
        prm_Linea."Cantidad Recogida" += prm_Cantidad;
        prm_Linea."Fecha Confirmacion" := CurrentDateTime();
        prm_Linea."Cod. Usuario Confirmacion" := rConfig.UsuarioActual();
        prm_Linea.ActualizarPendiente();
        prm_Linea.Modify();

        // El movimiento va en UM base, la de la parada, y lleva el nº de orden en la descripción.
        // Una reubicación no sale del almacén: se traslada a su ubicación de picking.
        if prm_Linea."Cod. Bin Destino" <> '' then
            cContenido.RegistrarTraslado(prm_Linea."Cod. Almacen", prm_Bin, prm_Linea."Cod. Bin Destino", prm_Linea."No. Producto",
                                         prm_Linea."No. Lote", sscc, prm_Linea."Cod. Unidad Medida",
                                         prm_Cantidad, rOrden.Origen, rOrden."No. Orden", prm_Linea."No. Linea",
                                         StrSubstNo(DescripcionReubicacionLbl, rOrden."No. Orden"))
        else
            cContenido.RegistrarSalida(prm_Linea."Cod. Almacen", prm_Bin, prm_Linea."No. Producto",
                                       prm_Linea."No. Lote", sscc, prm_Linea."Cod. Unidad Medida",
                                       prm_Cantidad, rOrden.Origen, rOrden."No. Documento Origen",
                                       prm_Linea."No. Linea Origen",
                                       StrSubstNo(DescripcionSalidaLbl, rOrden."No. Orden", rOrden."No. Documento Origen"));

        RecalcularReservaParada(prm_Linea);
        if (prm_Bin <> prm_Linea."Cod. Bin Propuesto") or (sscc <> prm_Linea.SSCC) then
            RecalcularReserva(prm_Linea."Cod. Almacen", prm_Bin, prm_Linea."No. Producto", prm_Linea."No. Lote", prm_Linea."Cod. Unidad Medida", sscc);

        rOrden.RecalcularEstado();
        // Lo recién recogido aún no está en el pedido: la orden vuelve a contar como sin pasar.
        if rOrden.Origen = rOrden.Origen::Venta then
            rOrden."Fecha Paso a Documento" := 0DT;
        rOrden.Modify();
    end;

    /// <summary>
    /// Cancela desde una pantalla, tras confirmarlo, una parada que no se va a recoger y libera
    /// su reserva. Lo ya recogido no se deshace: para eso hay que registrar una entrada, que deja
    /// su propia huella en el diario. Devuelve false si no se confirma.
    /// </summary>
    procedure CancelarLineaConDialogo(var prm_Linea: Record "Linea Orden Picking SGA"): Boolean
    var
        rOrden: Record "Orden Picking SGA";
        cConfirmMgt: Codeunit "Confirm Management";
        CancelarParadaQst: Label '¿Cancelar la línea de %1 en %2?', Comment = '%1 = producto, %2 = ubicación';
        CancelarReposicionQst: Label '¿Cancelar la reposición de %1 de %2 a %3?', Comment = '%1 = producto, %2 = ubicación origen, %3 = ubicación destino';
        pregunta: Text;
    begin
        if prm_Linea."Cod. Bin Destino" <> '' then
            pregunta := StrSubstNo(CancelarReposicionQst, prm_Linea."No. Producto", prm_Linea."Cod. Bin Propuesto", prm_Linea."Cod. Bin Destino")
        else
            pregunta := StrSubstNo(CancelarParadaQst, prm_Linea."No. Producto", prm_Linea."Cod. Bin Propuesto");
        if not cConfirmMgt.GetResponseOrDefault(pregunta, false) then
            exit(false);

        CancelarParada(prm_Linea);

        if rOrden.Get(prm_Linea."No. Orden") then begin
            rOrden.RecalcularEstado();
            // RecalcularEstado cambia el estado de la orden; el analizador no lo ve.
#pragma warning disable AA0214
            rOrden.Modify();
#pragma warning restore AA0214
        end;
        exit(true);
    end;

    /// <summary>
    /// Deja la parada cancelada y libera su reserva, sin tocar el estado de la orden: quien
    /// llama la recalcula cuando toca.
    /// </summary>
    local procedure CancelarParada(var prm_Linea: Record "Linea Orden Picking SGA")
    var
        ParadaNoPendienteErr: Label 'La línea de %1 en %2 ya está %3: solo se cancela una línea pendiente o a medias.', Comment = '%1 = producto, %2 = ubicación, %3 = estado';
    begin
        if not (prm_Linea.Estado in [prm_Linea.Estado::Pendiente, prm_Linea.Estado::Parcial]) then
            Error(ParadaNoPendienteErr, prm_Linea."No. Producto", prm_Linea."Cod. Bin Propuesto", prm_Linea.Estado);
        prm_Linea.Estado := prm_Linea.Estado::Cancelada;
        prm_Linea."Cantidad Pendiente" := 0;
        prm_Linea.Modify();

        RecalcularReservaParada(prm_Linea);
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
        rConfig: Record "Config. SGA";
        cogido: Dictionary of [Text, Decimal];
        cogibles: Dictionary of [Text, Boolean];
        pendiente: Decimal;
        sinCubrir: Decimal;
        ultimaAnterior: Integer;
        noLinea: Integer;
        pasada: Integer;
        ubicaciones: Text;
        OtraUbicacionTxt: Label 'No estaba en %1. Se recoge de otra ubicación: %2.', Comment = '%1 = ubicación vacía, %2 = ubicaciones nuevas';
        ParteTxt: Label 'No estaba en %1. Se recoge de otra ubicación (%2), pero no hay para todo: faltan %3 %4.', Comment = '%1 = ubicación vacía, %2 = ubicaciones nuevas, %3 = cantidad que falta, %4 = unidad';
        NingunaTxt: Label 'No estaba en %1 y no hay %2 en ninguna otra ubicación: la línea queda cancelada.', Comment = '%1 = ubicación vacía, %2 = producto';
    begin
        pendiente := prm_Linea."Cantidad Pendiente";
        // El estado de la orden se recalcula al final, con las paradas nuevas ya dentro: si se
        // recalculara ahora, una orden de una sola parada quedaría cancelada.
        CancelarParada(prm_Linea);
        rOrden.Get(prm_Linea."No. Orden");
        ultimaAnterior := UltimaLineaOrden(prm_Linea."No. Orden");
        noLinea := ultimaAnterior;

        rConfig.ObtenerConfig();
        sinCubrir := pendiente;
        // Reubicación: de almacenamiento (pasada 1 sin redondeo a palés); pedido: picking y resto.
        if prm_Linea."Cod. Bin Destino" <> '' then
            AnadirParadasPasada(rOrden, prm_Linea, rConfig, 1, 0, cogido, cogibles, sinCubrir, noLinea, ubicaciones)
        else
            for pasada := 2 to 3 do
                AnadirParadasPasada(rOrden, prm_Linea, rConfig, pasada, 0, cogido, cogibles, sinCubrir, noLinea, ubicaciones);

        // Solo las paradas nuevas: la cancelada ya liberó su reserva en CancelarParada.
        if sinCubrir < pendiente then
            RecalcularReservasDesde(rOrden, ultimaAnterior);
        rOrden.RecalcularEstado();
        // RecalcularEstado cambia el estado de la orden; el analizador no lo ve.
#pragma warning disable AA0214
        rOrden.Modify();
#pragma warning restore AA0214

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
    /// El preparador pulsa Saltar en una parada: se cuenta y, a la segunda, la parada queda
    /// retenida. Una retenida sigue pendiente (no libera su reserva ni deja terminar la orden),
    /// pero sale del recorrido del preparador hasta que la resuelva el jefe de almacén.
    /// Devuelve true si ha quedado retenida.
    /// </summary>
    procedure SaltarParada(var prm_Linea: Record "Linea Orden Picking SGA"): Boolean
    var
        rConfig: Record "Config. SGA";
    begin
        prm_Linea."Veces Saltada" += 1;
        if prm_Linea."Veces Saltada" >= 2 then begin
            prm_Linea.Retenida := true;
            prm_Linea."Fecha Retencion" := CurrentDateTime();
            prm_Linea."Retenida por" := rConfig.UsuarioActual();
        end;
        prm_Linea.Modify();
        exit(prm_Linea.Retenida);
    end;

    /// <summary>
    /// Cancelar orden desde una pantalla: solo una orden sin terminar. Pregunta antes y, si ya
    /// tenía algo recogido, lo dice; al cancelar, lo recogido de una orden de venta se pasa al
    /// pedido, porque ya está fuera de las ubicaciones. Devuelve false si no se cancela.
    /// </summary>
    procedure CancelarOrdenConDialogo(var prm_Orden: Record "Orden Picking SGA"): Boolean
    var
        cConfirmMgt: Codeunit "Confirm Management";
        hayRecogido: Boolean;
        OrdenTerminadaErr: Label 'La orden %1 ya está %2: no se puede cancelar.', Comment = '%1 = nº orden, %2 = estado';
        CancelarOrdenQst: Label '¿Cancelar la orden %1 y todas sus líneas pendientes?', Comment = '%1 = nº orden';
        CancelarConRecogidoQst: Label 'La orden %1 ya tiene líneas recogidas: esa mercancía ya no está en sus ubicaciones y se pasa al pedido. Las líneas pendientes se cancelan. ¿Continuar?', Comment = '%1 = nº orden';
    begin
        if not prm_Orden.EstaViva() then
            Error(OrdenTerminadaErr, prm_Orden."No. Orden", prm_Orden.Estado);

        hayRecogido := prm_Orden.TieneRecogido();
        if hayRecogido then begin
            if not cConfirmMgt.GetResponseOrDefault(StrSubstNo(CancelarConRecogidoQst, prm_Orden."No. Orden"), false) then
                exit(false);
        end else
            if not cConfirmMgt.GetResponseOrDefault(StrSubstNo(CancelarOrdenQst, prm_Orden."No. Orden"), false) then
                exit(false);

        CancelarOrden(prm_Orden);
        if hayRecogido and (prm_Orden.Origen = prm_Orden.Origen::Venta) then
            PasarAPedido(prm_Orden);
        exit(true);
    end;

    /// <summary>
    /// Cancela la orden entera y todas sus paradas pendientes, y libera sus reservas.
    /// </summary>
    local procedure CancelarOrden(var prm_Orden: Record "Orden Picking SGA")
    var
        rLinea: Record "Linea Orden Picking SGA";
    begin
        rLinea.SetRange("No. Orden", prm_Orden."No. Orden");
        rLinea.FiltrarPendientes();
        if rLinea.FindSet() then
            repeat
                CancelarParada(rLinea);
            until rLinea.Next() = 0;

        prm_Orden.Estado := prm_Orden.Estado::Cancelada;
        prm_Orden.Modify();
    end;

    /// <summary>
    /// Deja en prm_Orden la siguiente orden que le toca al usuario actual, para que la pantalla
    /// del preparador la abra: primero las suyas sin terminar, por prioridad. Si no tiene y la
    /// configuración no exige asignación, coge la siguiente sin asignar y se la queda (una
    /// reposición si el usuario es carretillero, EsCarretillero, y un pedido si no). Si no hay
    /// ninguna devuelve false, con el porqué en prm_Motivo.
    /// </summary>
    procedure SiguienteOrdenPreparar(var prm_Orden: Record "Orden Picking SGA"; var prm_Motivo: Text): Boolean
    var
        rConfig: Record "Config. SGA";
        usuario: Code[50];
        SinOrdenesPendientesTxt: Label 'No hay órdenes de picking pendientes.';
        SinOrdenesAsignadasTxt: Label 'No tiene órdenes de picking asignadas. Pida a su responsable que le asigne alguna.';
    begin
        prm_Motivo := '';
        usuario := rConfig.UsuarioActual();
        rConfig.ObtenerConfig();

        prm_Orden.Reset();
        prm_Orden.SetFilter(Estado, '%1|%2', prm_Orden.Estado::Abierta, prm_Orden.Estado::"En Proceso");
        prm_Orden.SetRange("Cod. Usuario Asignado", usuario);
        if BuscarMasPrioritaria(prm_Orden) then
            exit(true);

        // Con asignación exigida, el preparador solo hace lo que le reparten.
        if rConfig."Exigir Asignacion Picking" then begin
            prm_Motivo := SinOrdenesAsignadasTxt;
            exit(false);
        end;

        // Las pendientes de asignar entran por si la configuración se desactivó con órdenes en espera.
        prm_Orden.FiltrarSinEmpezar();
        prm_Orden.SetRange("Cod. Usuario Asignado", '');
        // El carretillero coge las reposiciones; los demás, lo que no lo es.
        if EsCarretillero() then
            prm_Orden.SetRange(Origen, prm_Orden.Origen::Reposicion)
        else
            prm_Orden.SetFilter(Origen, '<>%1', prm_Orden.Origen::Reposicion);
        if not BuscarMasPrioritaria(prm_Orden) then begin
            prm_Motivo := SinOrdenesPendientesTxt;
            exit(false);
        end;

        AsignarOrden(prm_Orden, usuario);
        Commit();
        exit(true);
    end;

    /// <summary>
    /// Deja en prm_Orden la que va antes entre las filtradas, con el orden de VaAntesQue
    /// (prioridad del pedido, pedido, y dentro de él palé, cajas y sueltos). Se recorre a mano
    /// porque ese orden no es una clave. Se saltan las órdenes que solo tienen paradas
    /// retenidas: esas esperan al jefe de almacén, no al preparador.
    /// </summary>
    local procedure BuscarMasPrioritaria(var prm_Orden: Record "Orden Picking SGA"): Boolean
    var
        rCandidata: Record "Orden Picking SGA";
        rMejor: Record "Orden Picking SGA";
        hayMejor: Boolean;
        claseMejor: Boolean;
        rangoMejor: Integer;
        volumenMejor: Decimal;
        rangoCandidata: Integer;
        volumenCandidata: Decimal;
    begin
        rCandidata.CopyFilters(prm_Orden);
        rCandidata.SetCurrentKey("No. Orden");
        if rCandidata.FindSet() then
            repeat
                // Las paradas solo se miran de la que ganaría: es la consulta más cara.
                if VaAntesQue(rCandidata, rMejor, hayMejor, claseMejor, rangoMejor, volumenMejor, rangoCandidata, volumenCandidata) then
                    if rCandidata.TieneParadasParaPreparar() then begin
                        rMejor := rCandidata;
                        hayMejor := true;
                        // La clase de la nueva mejor, si se ha calculado al compararla, se guarda.
                        claseMejor := rangoCandidata >= 0;
                        rangoMejor := rangoCandidata;
                        volumenMejor := volumenCandidata;
                    end;
            until rCandidata.Next() = 0;

        if not hayMejor then
            exit(false);
        // rMejor ya está leída entera.
        prm_Orden := rMejor;
        exit(true);
    end;

    /// <summary>
    /// Si la orden A se prepara antes que la mejor hasta ahora (B; sin ella, sí): primero la
    /// prioridad manual del pedido, luego el pedido (sus órdenes van juntas), dentro del pedido
    /// palé, cajas y sueltos, y entre cajas la de más volumen. La clase de cada orden
    /// (ClaseOrden) solo se calcula si hace falta, y la de B una vez: prm_ClaseB dice si ya está
    /// en prm_RangoB y prm_VolumenB. La de A queda en prm_RangoA y prm_VolumenA (rango -1 si
    /// no se ha calculado).
    /// </summary>
    local procedure VaAntesQue(rA: Record "Orden Picking SGA"; rB: Record "Orden Picking SGA"; prm_HayB: Boolean; var prm_ClaseB: Boolean; var prm_RangoB: Integer; var prm_VolumenB: Decimal; var prm_RangoA: Integer; var prm_VolumenA: Decimal): Boolean
    begin
        prm_RangoA := -1;
        prm_VolumenA := 0;
        if not prm_HayB then
            exit(true);
        if rA.Prioridad <> rB.Prioridad then
            exit(rA.Prioridad > rB.Prioridad);
        if rA."No. Documento Origen" <> rB."No. Documento Origen" then
            exit(rA."No. Documento Origen" < rB."No. Documento Origen");
        ClaseOrden(rA, prm_RangoA, prm_VolumenA);
        if not prm_ClaseB then begin
            ClaseOrden(rB, prm_RangoB, prm_VolumenB);
            prm_ClaseB := true;
        end;
        if prm_RangoA <> prm_RangoB then
            exit(prm_RangoA < prm_RangoB);
        if prm_VolumenA <> prm_VolumenB then
            exit(prm_VolumenA > prm_VolumenB);
        exit(rA."No. Orden" < rB."No. Orden");
    end;

    /// <summary>
    /// Tipo de una orden: 1 cajas (con su volumen en litros) si sus paradas son en la caja de
    /// venta; 0 palé completo si lo que recoge de un producto es exactamente un palé, se pida en
    /// palés o en unidades; 2 sueltos en otro caso. De las paradas canceladas solo cuenta lo que
    /// ya se había recogido: una sustituida por "Sin stock" pasa lo que le quedaba a sus
    /// paradas nuevas.
    /// </summary>
    local procedure ClaseOrden(prm_Orden: Record "Orden Picking SGA"; var prm_Rango: Integer; var prm_Volumen: Decimal)
    var
        rLinea: Record "Linea Orden Picking SGA";
        rCancelada: Record "Linea Orden Picking SGA";
        factorPale: Decimal;
    begin
        prm_Rango := 2;
        prm_Volumen := 0;
        rLinea.SetLoadFields("No. Producto", "UM Documento", "Cantidad a Recoger");
        rLinea.SetRange("No. Orden", prm_Orden."No. Orden");
        rLinea.FiltrarNoCanceladas();
        if not rLinea.FindFirst() then
            exit;
        if cUM.EsCaja(rLinea."No. Producto", rLinea."UM Documento") then begin
            prm_Rango := 1;
            prm_Volumen := cUM.VolumenUM(rLinea."No. Producto", rLinea."UM Documento");
            exit;
        end;
        factorPale := cUM.FactorPale(rLinea."No. Producto");
        if factorPale > 1 then begin
            rLinea.SetRange("No. Producto", rLinea."No. Producto");
            rLinea.CalcSums("Cantidad a Recoger");
            rCancelada.SetRange("No. Orden", prm_Orden."No. Orden");
            rCancelada.SetRange("No. Producto", rLinea."No. Producto");
            rCancelada.SetRange(Estado, rCancelada.Estado::Cancelada);
            rCancelada.CalcSums("Cantidad Recogida");
            if rLinea."Cantidad a Recoger" + rCancelada."Cantidad Recogida" = factorPale then
                prm_Rango := 0;
        end;
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
    /// Asigna todas las órdenes del conjunto recibido (filtros o marcas de la selección), o, con
    /// prm_Usuario en blanco, quita la asignación de las que no se han empezado: una empezada
    /// se puede pasar a otro preparador, pero no dejar sin nadie. Devuelve cuántas ha tocado.
    /// </summary>
    procedure AsignarOrdenes(var prm_Orden: Record "Orden Picking SGA"; prm_Usuario: Code[50]): Integer
    var
        hechas: Integer;
    begin
        if prm_Usuario = '' then
            prm_Orden.FiltrarSinEmpezar();
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
    /// Suma prm_Delta a la prioridad del pedido de cada orden del conjunto recibido, sin bajar de
    /// cero: cambia a la vez todas sus órdenes. Las de reubicación no tienen pedido y cambian solas.
    /// </summary>
    procedure CambiarPrioridad(var prm_Orden: Record "Orden Picking SGA"; prm_Delta: Integer)
    var
        rOrden: Record "Orden Picking SGA";
        pedidosHechos: Dictionary of [Code[20], Boolean];
    begin
        if prm_Orden.FindSet(false) then
            repeat
                if prm_Orden."No. Documento Origen" = '' then begin
                    // La orden ya está leída entera en prm_Orden.
                    rOrden := prm_Orden;
                    AplicarDelta(rOrden, prm_Delta);
                end else
                    if not pedidosHechos.ContainsKey(prm_Orden."No. Documento Origen") then begin
                        pedidosHechos.Add(prm_Orden."No. Documento Origen", true);
                        rOrden.FiltrarPedido(prm_Orden."No. Documento Origen");
                        if rOrden.FindSet(true) then
                            repeat
                                AplicarDelta(rOrden, prm_Delta);
                            until rOrden.Next() = 0;
                    end;
            until prm_Orden.Next() = 0;
    end;

    /// <summary>
    /// Pide una playa del almacén de la primera orden del conjunto recibido y la pone en las
    /// órdenes de venta de ese almacén que aún no se han empezado. Las demás se quedan como
    /// están y el mensaje dice cuántas.
    /// </summary>
    procedure CambiarPlaya(var prm_Orden: Record "Orden Picking SGA")
    var
        rZona: Record "Zona SGA";
        total: Integer;
        cambiadas: Integer;
        resultado: Text;
        SinPlayasErr: Label 'El almacén %1 no tiene ninguna zona marcada como playa.', Comment = '%1 = almacén';
        PlayaCambiadaMsg: Label 'Playa %1 puesta en %2 órdenes.', Comment = '%1 = playa, %2 = número de órdenes';
        OrdenesSinCambiarMsg: Label '%1 órdenes no se han cambiado: ya están empezadas, terminadas o canceladas, o no son de venta del almacén %2.', Comment = '%1 = número de órdenes, %2 = almacén';
    begin
        if not prm_Orden.FindFirst() then
            exit;
        total := prm_Orden.Count();

        rZona.SetRange("Cod. Almacen", prm_Orden."Cod. Almacen");
        rZona.SetRange(Playa, true);
        if rZona.IsEmpty() then
            Error(SinPlayasErr, prm_Orden."Cod. Almacen");
        if Page.RunModal(0, rZona) <> Action::LookupOK then
            exit;

        prm_Orden.SetRange("Cod. Almacen", rZona."Cod. Almacen");
        prm_Orden.SetRange(Origen, prm_Orden.Origen::Venta);
        prm_Orden.FiltrarSinEmpezar();
        if prm_Orden.FindSet(true) then
            repeat
                prm_Orden.Playa := rZona.Code;
                prm_Orden.Modify(true);
                cambiadas += 1;
            until prm_Orden.Next() = 0;

        resultado := StrSubstNo(PlayaCambiadaMsg, rZona.Code, cambiadas);
        if cambiadas < total then
            resultado += ' ' + StrSubstNo(OrdenesSinCambiarMsg, total - cambiadas, rZona."Cod. Almacen");
        Message(resultado);
    end;

    local procedure AplicarDelta(var prm_Orden: Record "Orden Picking SGA"; prm_Delta: Integer)
    begin
        if prm_Orden.Prioridad + prm_Delta < 0 then
            prm_Orden.Validate(Prioridad, 0)
        else
            prm_Orden.Validate(Prioridad, prm_Orden.Prioridad + prm_Delta);
        prm_Orden.Modify(true);
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
    local procedure TomarParaPreparar(var prm_Orden: Record "Orden Picking SGA"): Boolean
    var
        rConfig: Record "Config. SGA";
        cConfirmMgt: Codeunit "Confirm Management";
        usuario: Code[50];
        OrdenDeOtroUsuarioQst: Label 'La orden %1 la tiene asignada %2. ¿Quiere prepararla usted?', Comment = '%1 = nº orden, %2 = usuario';
    begin
        usuario := rConfig.UsuarioActual();
        rConfig.ObtenerConfig();
        ComprobarPreparador(prm_Orden, rConfig);

        if prm_Orden."Cod. Usuario Asignado" = usuario then
            exit(true);

        if prm_Orden."Cod. Usuario Asignado" <> '' then
            if not cConfirmMgt.GetResponseOrDefault(StrSubstNo(OrdenDeOtroUsuarioQst, prm_Orden."No. Orden", prm_Orden."Cod. Usuario Asignado"), false) then
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
        SinParadasPendientesErr: Label 'La orden %1 no tiene líneas pendientes.', Comment = '%1 = nº orden';
    begin
        // Las retenidas no se preparan: sin otras, la pantalla saldría vacía.
        if not prm_Orden.TieneParadasParaPreparar() then
            Error(SinParadasPendientesErr, prm_Orden."No. Orden");
        rLinea.SetRange("No. Orden", prm_Orden."No. Orden");
        rLinea.FiltrarPendientes();

        // Se lee la orden de nuevo: la que llega de la página puede no estar al día.
        prm_Orden.Get(prm_Orden."No. Orden");
        if not TomarParaPreparar(prm_Orden) then
            exit;
        Commit();

        Page.Run(Page::"Preparar Picking SGA", rLinea);
    end;

    /// <summary>
    /// Con asignación exigida, solo el preparador asignado puede trabajar la orden. Sin ella,
    /// basta con que la orden siga viva. prm_Config llega ya leída.
    /// </summary>
    local procedure ComprobarPreparador(var prm_Orden: Record "Orden Picking SGA"; var prm_Config: Record "Config. SGA")
    var
        OrdenPendienteAsignarErr: Label 'La orden %1 está pendiente de asignar. Pida a su responsable que se la asigne.', Comment = '%1 = nº orden';
        OrdenAsignadaOtroErr: Label 'La orden %1 está asignada a %2. Solo la puede preparar el preparador asignado.', Comment = '%1 = nº orden, %2 = usuario';
        OrdenNoVivaErr: Label 'La orden %1 está %2.', Comment = '%1 = nº orden, %2 = estado';
    begin
        if not prm_Orden.EstaViva() then
            Error(OrdenNoVivaErr, prm_Orden."No. Orden", prm_Orden.Estado);

        if not prm_Config."Exigir Asignacion Picking" then
            exit;

        if prm_Orden."Cod. Usuario Asignado" = '' then
            Error(OrdenPendienteAsignarErr, prm_Orden."No. Orden");

        if prm_Orden."Cod. Usuario Asignado" <> prm_Config.UsuarioActual() then
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
    /// Pasa al pedido de venta lo recogido: por cada línea de un producto que SGA ubica
    /// (ProductoSGA; las demás se quedan como estén), la cantidad a enviar
    /// y, si el producto lleva lotes estándar, el seguimiento por lote con los lotes que han
    /// salido de las ubicaciones.
    ///
    /// Se calcula sobre todas las órdenes del pedido, no solo esta, descontando lo ya enviado.
    /// Así se puede repetir sin duplicar nada, y una línea sin recoger queda con cantidad a
    /// enviar cero: lo que no ha pasado por picking no sale.
    /// </summary>
    procedure PasarAPedido(var prm_Orden: Record "Orden Picking SGA")
    var
        rOrden: Record "Orden Picking SGA";
        rCabVenta: Record "Sales Header";
        rLinVenta: Record "Sales Line";
        cUOMMgt: Codeunit "Unit of Measure Management";
        recogido: Dictionary of [Code[50], Decimal];
        enviado: Dictionary of [Code[50], Decimal];
        caducidades: Dictionary of [Code[50], Date];
        aEnviar: Dictionary of [Code[50], Decimal];
        lote: Code[50];
        cantidadLote: Decimal;
        cantidadEnviada: Decimal;
        totalBase: Decimal;
        restante: Decimal;
        loteEstandar: Boolean;
        SoloOrdenesVentaErr: Label 'Solo se pueden pasar al pedido órdenes de venta.';
        PedidoNoExisteErr: Label 'No existe el pedido de venta %1.', Comment = '%1 = nº pedido';
    begin
        if prm_Orden.Origen <> prm_Orden.Origen::Venta then
            Error(SoloOrdenesVentaErr);

        // Solo se comprueba que existe.
        rCabVenta.SetLoadFields("No.");
        if not rCabVenta.Get(rCabVenta."Document Type"::Order, prm_Orden."No. Documento Origen") then
            Error(PedidoNoExisteErr, prm_Orden."No. Documento Origen");

        FiltrarLineasPendientes(rCabVenta."No.", rLinVenta);
        if rLinVenta.FindSet(true) then
            repeat
                // Los productos que SGA no ubica no pasan por picking: se dejan como estén en el pedido.
                if cStock.EsProductoSGA(rLinVenta."No.", cUM) then begin
                    Clear(recogido);
                    Clear(enviado);
                    Clear(caducidades);
                    Clear(aEnviar);
                    totalBase := 0;
                    restante := rLinVenta."Outstanding Qty. (Base)";
                    loteEstandar := cStock.LoteEstandar(rLinVenta."No.");

                    RecogidoPorLote(rLinVenta."Document No.", rLinVenta."Line No.", recogido, caducidades);
                    EnviadoPorLote(rLinVenta."Document No.", rLinVenta."Line No.", enviado);
                    // Sin lotes de BC, los envíos llevan el lote en blanco aunque SGA sepa el suyo:
                    // lo enviado se descuenta del total de la línea y no lote a lote.
                    if not loteEstandar then
                        DescontarEnviadoSinLote(recogido, enviado);

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

                    if loteEstandar then
                        EscribirSeguimientoLotes(rLinVenta, aEnviar, caducidades);

                    rLinVenta.Validate("Qty. to Ship", cUOMMgt.CalcQtyFromBase(totalBase, rLinVenta."Qty. per Unit of Measure"));
                    rLinVenta.Modify(true);
                end;
            until rLinVenta.Next() = 0;

        // El paso es del pedido entero: se sellan todas sus órdenes terminadas.
        rOrden.FiltrarPedido(prm_Orden."No. Documento Origen");
        rOrden.SetRange(Estado, rOrden.Estado::Finalizada);
        rOrden.ModifyAll("Fecha Paso a Documento", CurrentDateTime());
        prm_Orden.Get(prm_Orden."No. Orden");
        if prm_Orden."Fecha Paso a Documento" = 0DT then begin
            prm_Orden."Fecha Paso a Documento" := CurrentDateTime();
            prm_Orden.Modify();
        end;
    end;

    /// <summary>
    /// Para un producto sin lotes de BC: reparte lo ya enviado (todo con el lote en blanco)
    /// entre los lotes recogidos, quitándolo de ellos por orden hasta agotarlo. Deja prm_Enviado
    /// vacío, para que el cálculo por lote no vuelva a descontarlo.
    /// </summary>
    local procedure DescontarEnviadoSinLote(var prm_Recogido: Dictionary of [Code[50], Decimal]; var prm_Enviado: Dictionary of [Code[50], Decimal])
    var
        lote: Code[50];
        porDescontar: Decimal;
        cantidad: Decimal;
    begin
        foreach lote in prm_Enviado.Keys() do
            porDescontar += prm_Enviado.Get(lote);
        Clear(prm_Enviado);

        foreach lote in prm_Recogido.Keys() do
            if porDescontar > 0 then begin
                cantidad := prm_Recogido.Get(lote);
                if cantidad > porDescontar then begin
                    prm_Recogido.Set(lote, cantidad - porDescontar);
                    porDescontar := 0;
                end else begin
                    prm_Recogido.Set(lote, 0);
                    porDescontar -= cantidad;
                end;
            end;
    end;

    /// <summary>
    /// El preparador ha recorrido la orden (Preparar Picking SGA): guarda lo confirmado y pasa lo
    /// recogido al pedido. Se guarda antes (Commit): si el pedido no acepta los datos, el
    /// preparador no pierde su trabajo y oficina lo repite desde la orden con "Pasar al pedido";
    /// entonces prm_Fallo vuelve a true. Si quedan paradas retenidas, la orden sigue en proceso
    /// para el jefe de almacén, pero lo recogido ya pasa al pedido: el paso se puede repetir sin
    /// duplicar cuando se resuelvan. Devuelve el texto para el preparador: terminada o con
    /// retenidas, la playa donde dejarla y si está en el pedido.
    /// </summary>
    procedure TerminarRecorrido(prm_NoOrden: Code[20]; var prm_Fallo: Boolean) resultado: Text
    var
        rOrden: Record "Orden Picking SGA";
        OrdenTerminadaMsg: Label 'Orden %1 terminada.', Comment = '%1 = nº orden';
        DejarEnPlayaMsg: Label 'Déjela en la playa %1.', Comment = '%1 = playa (zona)';
        OrdenConRetenidasMsg: Label 'Orden %1 recorrida. %2 líneas quedan retenidas para el jefe de almacén.', Comment = '%1 = nº orden, %2 = número de líneas retenidas';
        PasadaAlPedidoMsg: Label 'Lo recogido ya está en el pedido %1.', Comment = '%1 = nº pedido';
        SinPasarAlPedidoMsg: Label 'No se ha podido pasar al pedido %1: %2 Avise a oficina para que lo pase desde la orden.', Comment = '%1 = nº pedido, %2 = error';
    begin
        Commit();
        prm_Fallo := false;
        resultado := StrSubstNo(OrdenTerminadaMsg, prm_NoOrden);
        rOrden.SetAutoCalcFields("Paradas Retenidas");
        if not rOrden.Get(prm_NoOrden) then
            exit;
        if rOrden."Paradas Retenidas" > 0 then
            resultado := StrSubstNo(OrdenConRetenidasMsg, rOrden."No. Orden", rOrden."Paradas Retenidas");
        if rOrden.Origen <> rOrden.Origen::Venta then
            exit;
        if rOrden.Playa <> '' then
            resultado += ' ' + StrSubstNo(DejarEnPlayaMsg, rOrden.Playa);
        // En su propia transacción (OnRun): un error del pedido no deshace lo recogido.
        if Codeunit.Run(Codeunit::"Gestion Picking SGA", rOrden) then
            resultado += ' ' + StrSubstNo(PasadaAlPedidoMsg, rOrden."No. Documento Origen")
        else begin
            resultado += ' ' + StrSubstNo(SinPasarAlPedidoMsg, rOrden."No. Documento Origen", GetLastErrorText());
            prm_Fallo := true;
        end;
    end;

    /// <summary>
    /// "Pasar al pedido" desde una pantalla: PasarAPedido y el aviso de que está hecho. Desde el
    /// pedido de venta (prm_Orden en blanco y prm_NoPedido) vale cualquiera de sus órdenes: el
    /// paso al pedido suma todas.
    /// </summary>
    procedure PasarAPedidoConMensaje(var prm_Orden: Record "Orden Picking SGA"; prm_NoPedido: Code[20])
    var
        rOrden: Record "Orden Picking SGA";
        PedidoSinOrdenesErr: Label 'El pedido %1 no tiene órdenes de picking.', Comment = '%1 = nº pedido';
        PickingPasadoMsg: Label 'Lo recogido se ha pasado al pedido %1.', Comment = '%1 = nº pedido';
    begin
        rOrden := prm_Orden;
        if rOrden."No. Orden" = '' then begin
            rOrden.FiltrarPedido(prm_NoPedido);
            if not rOrden.FindLast() then
                Error(PedidoSinOrdenesErr, prm_NoPedido);
        end;
        PasarAPedido(rOrden);
        Message(PickingPasadoMsg, rOrden."No. Documento Origen");
    end;

    /// <summary>
    /// Sustituye el seguimiento por lote de una línea de venta por los lotes recogidos.
    /// Se llama solo si el producto lleva lotes estándar (LoteEstandar): sin código de
    /// seguimiento por lote, BC no espera lotes en la línea y el lote del hueco es solo de SGA.
    /// Solo toca el seguimiento sin reserva (excedente): si la línea tiene reservas contra
    /// lotes concretos, se para, porque deshacerlas es una decisión de oficina.
    /// </summary>
    local procedure EscribirSeguimientoLotes(var prm_LinVenta: Record "Sales Line"; var prm_Lotes: Dictionary of [Code[50], Decimal]; var prm_Caducidades: Dictionary of [Code[50], Date])
    var
        rReserva: Record "Reservation Entry";
        rSeguimiento: Record "Reservation Entry";
        cCrearReserva: Codeunit "Create Reserv. Entry";
        cUOMMgt: Codeunit "Unit of Measure Management";
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
                                                   prm_LinVenta."Qty. per Unit of Measure",
                                                   cUOMMgt.CalcQtyFromBase(cantidadBase, prm_LinVenta."Qty. per Unit of Measure"),
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
    /// </summary>
    local procedure RecogidoPorLote(prm_NoPedido: Code[20]; prm_NoLineaPedido: Integer; var prm_Recogido: Dictionary of [Code[50], Decimal]; var prm_Caducidades: Dictionary of [Code[50], Date])
    var
        rLinea: Record "Linea Orden Picking SGA";
        acumulado: Decimal;
    begin
        rLinea.FiltrarLineaPedido(prm_NoPedido, prm_NoLineaPedido);
        rLinea.SetFilter("Cantidad Recogida", '>%1', 0);
        rLinea.SetLoadFields("No. Lote", "Cantidad Recogida", "Fecha Caducidad");
        if rLinea.FindSet() then
            repeat
                // Set añade la clave si aún no está.
                if not prm_Recogido.Get(rLinea."No. Lote", acumulado) then
                    acumulado := 0;
                prm_Recogido.Set(rLinea."No. Lote", acumulado + rLinea."Cantidad Recogida");

                if (rLinea."Fecha Caducidad" <> 0D) and (not prm_Caducidades.ContainsKey(rLinea."No. Lote")) then
                    prm_Caducidades.Add(rLinea."No. Lote", rLinea."Fecha Caducidad");
            until rLinea.Next() = 0;
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
        rLinAlbaran.SetLoadFields("Document No.", "Line No.");
        if not rLinAlbaran.FindSet() then
            exit;

        repeat
            rLinAlbaran.FilterPstdDocLnItemLedgEntries(rItemLedgEntry);
            // Después del filtro: el estándar hace Reset.
            rItemLedgEntry.SetLoadFields("Lot No.", Quantity);
            if rItemLedgEntry.FindSet() then
                repeat
                    if not prm_Enviado.Get(rItemLedgEntry."Lot No.", acumulado) then
                        acumulado := 0;
                    prm_Enviado.Set(rItemLedgEntry."Lot No.", acumulado - rItemLedgEntry.Quantity);
                until rItemLedgEntry.Next() = 0;
        until rLinAlbaran.Next() = 0;
    end;

    /// <summary>
    /// RecalcularReserva de la línea de contenido de la que coge una parada (su ubicación
    /// propuesta, lote y palé).
    /// </summary>
    local procedure RecalcularReservaParada(var prm_Linea: Record "Linea Orden Picking SGA")
    begin
        RecalcularReserva(prm_Linea."Cod. Almacen", prm_Linea."Cod. Bin Propuesto", prm_Linea."No. Producto",
                          prm_Linea."No. Lote", prm_Linea."Cod. Unidad Medida", prm_Linea.SSCC);
    end;

    /// <summary>
    /// Ajusta la reserva de una línea de contenido (hueco, lote y palé) a lo que piden sus paradas
    /// abiertas. Nunca reserva más de lo que hay: si alguien se ha desviado y ha cogido de aquí,
    /// la reserva se recorta.
    /// </summary>
    procedure RecalcularReserva(prm_Almacen: Code[10]; prm_Bin: Code[20]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_UMBase: Code[10]; prm_SSCC: Code[20])
    var
        rLinea: Record "Linea Orden Picking SGA";
        rContenido: Record "Contenido Ubicacion SGA";
        cContenido: Codeunit "Gestion Contenido SGA";
        reserva: Decimal;
    begin
        if (prm_Bin = '') or (prm_Producto = '') then
            exit;

        // El contenido va siempre en la unidad base, que da quien llama: la del contenido o la
        // de la parada, que la copia del contenido.
        if not rContenido.Get(prm_Almacen, prm_Bin, prm_Producto, prm_Lote, prm_UMBase, prm_SSCC) then
            exit;

        rLinea.SetCurrentKey("No. Producto", "No. Lote");
        rLinea.SetRange("No. Producto", prm_Producto);
        rLinea.SetRange("No. Lote", prm_Lote);
        rLinea.SetRange("Cod. Almacen", prm_Almacen);
        rLinea.SetRange("Cod. Bin Propuesto", prm_Bin);
        rLinea.SetRange(SSCC, prm_SSCC);
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
    /// Recalcula la reserva de los huecos de las paradas de la orden posteriores a
    /// prm_DesdeLinea: al añadir paradas, solo las nuevas cambian lo reservado.
    /// </summary>
    local procedure RecalcularReservasDesde(var prm_Orden: Record "Orden Picking SGA"; prm_DesdeLinea: Integer)
    var
        rLinea: Record "Linea Orden Picking SGA";
    begin
        rLinea.SetRange("No. Orden", prm_Orden."No. Orden");
        rLinea.SetFilter("No. Linea", '>%1', prm_DesdeLinea);
        rLinea.SetLoadFields("Cod. Almacen", "Cod. Bin Propuesto", "No. Producto", "No. Lote", "Cod. Unidad Medida", SSCC);
        if rLinea.FindSet() then
            repeat
                RecalcularReservaParada(rLinea);
            until rLinea.Next() = 0;
    end;

    /// <summary>
    /// Vuelve a fijar todas las reservas de un almacén desde cero: libera las que ya no tienen
    /// paradas detrás y fija las de las paradas abiertas. Lo usa la reconstrucción de contenido.
    /// </summary>
    procedure RecalcularReservasAlmacen(prm_Almacen: Code[10])
    var
        rContenido: Record "Contenido Ubicacion SGA";
        rLinea: Record "Linea Orden Picking SGA";
    begin
        if prm_Almacen <> '' then
            rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetFilter("Cantidad Reservada", '>%1', 0);
        rContenido.SetLoadFields("Cod. Almacen", "Cod. Bin", "No. Producto", "No. Lote", "Cod. Unidad Medida", SSCC);
        if rContenido.FindSet() then
            repeat
                // RecalcularReserva lee y modifica el contenido en su propia variable: el
                // registro del bucle, filtrado por la reserva que cambia, no se toca.
                RecalcularReserva(rContenido."Cod. Almacen", rContenido."Cod. Bin", rContenido."No. Producto", rContenido."No. Lote", rContenido."Cod. Unidad Medida", rContenido.SSCC);
            until rContenido.Next() = 0;

        if prm_Almacen <> '' then
            rLinea.SetRange("Cod. Almacen", prm_Almacen);
        rLinea.FiltrarPendientes();
        rLinea.SetLoadFields("Cod. Almacen", "Cod. Bin Propuesto", "No. Producto", "No. Lote", "Cod. Unidad Medida", SSCC);
        if rLinea.FindSet() then
            repeat
                RecalcularReservaParada(rLinea);
            until rLinea.Next() = 0;
    end;

    /// <summary>
    /// Borra las órdenes sin terminar de un almacén (abiertas, en proceso o pendientes de
    /// asignar) con sus paradas, aunque lleven algo recogido: es para dejar el almacén a cero
    /// (Inicializar de Cod. "Gestion Contenido SGA"). Con prm_Producto, solo las paradas de ese
    /// producto: las de otros productos de la misma orden se quedan, y la orden solo se borra si
    /// se queda sin paradas. Las finalizadas y canceladas se quedan como historial.
    /// No recalcula las reservas: lo hace quien llama, al terminar.
    /// </summary>
    procedure EliminarOrdenesSinTerminar(prm_Almacen: Code[10]; prm_Producto: Code[20])
    var
        rOrdenViva: Record "Orden Picking SGA";
        rOrden: Record "Orden Picking SGA";
        rLinea: Record "Linea Orden Picking SGA";
        ordenes: List of [Code[20]];
        noOrden: Code[20];
    begin
        // Primero se eligen y luego se borran, para no borrar sobre el recorrido. La búsqueda
        // solo lee el nº; la orden que se borra o modifica se lee entera aparte. Sin producto
        // entran todas, también las que aún no tienen paradas.
        rOrdenViva.SetCurrentKey("Cod. Almacen", Estado);
        rOrdenViva.SetRange("Cod. Almacen", prm_Almacen);
        rOrdenViva.FiltrarVivas();
        rOrdenViva.SetLoadFields("No. Orden");
        if rOrdenViva.FindSet() then
            repeat
                if prm_Producto = '' then
                    ordenes.Add(rOrdenViva."No. Orden")
                else begin
                    rLinea.SetRange("No. Orden", rOrdenViva."No. Orden");
                    rLinea.SetRange("No. Producto", prm_Producto);
                    if not rLinea.IsEmpty() then
                        ordenes.Add(rOrdenViva."No. Orden");
                end;
            until rOrdenViva.Next() = 0;

        foreach noOrden in ordenes do begin
            rLinea.SetRange("No. Orden", noOrden);
            if prm_Producto <> '' then
                rLinea.SetRange("No. Producto", prm_Producto);
            rLinea.DeleteAll(false);
            rLinea.SetRange("No. Producto");
            if rOrden.Get(noOrden) then
                if rLinea.IsEmpty() then
                    // Sin triggers a propósito: el de la orden no deja borrar con algo recogido.
                    rOrden.Delete(false)
                else begin
                    rOrden.RecalcularEstado();
                    // RecalcularEstado cambia el estado de la orden; el analizador no lo ve.
#pragma warning disable AA0214
                    rOrden.Modify();
#pragma warning restore AA0214
                end;
        end;
    end;

    /// <summary>
    /// Cuánto está preparado de lo que queda por enviar del pedido de venta, mirando sus
    /// líneas con algo pendiente de productos que SGA ubica (ProductoSGA):
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
        FiltrarLineasPendientes(prm_Cabecera."No.", rLinVenta);
        rLinVenta.SetLoadFields(Type, "No.", "Quantity Shipped", "Outstanding Quantity");
        rLinVenta.SetAutoCalcFields("Cantidad Preparada SGA");
        if not rLinVenta.FindSet() then
            exit("Estado Preparacion SGA"::" ");

        repeat
            if cStock.EsProductoSGA(rLinVenta."No.", cUM) then begin
                lineas += 1;
                preparadaSinEnviar := rLinVenta."Cantidad Preparada SGA" - rLinVenta."Quantity Shipped";
                if preparadaSinEnviar > 0 then
                    conAlgo += 1;
                if preparadaSinEnviar >= rLinVenta."Outstanding Quantity" then
                    completas += 1;
            end;
        until rLinVenta.Next() = 0;

        if lineas = 0 then
            exit("Estado Preparacion SGA"::" ");
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
        rCabecera.SetLoadFields("Document Type", "No.");
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

    var
        // Una instancia para todo el proceso: guarda lo leído de cada producto y unidad.
        cUM: Codeunit "Unidades Producto SGA";
        cStock: Codeunit "Consulta Stock SGA";
}
