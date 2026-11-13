namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;

/// <summary>
/// Codeunit Gestion Contenido SGA (ID 51100).
/// Puerta única de escritura del contenido por ubicación. Todo lo que entra, sale o se
/// mueve entre ubicaciones pasa por aquí: valida, aplica el delta al contenido, inserta
/// el movimiento en el diario y refresca el estado de ocupación de la ubicación.
///
/// Invariante de la Fase 1: el contenido se guarda siempre en la unidad de medida base
/// del producto. El diario de movimientos conserva la unidad y la cantidad con las que
/// trabajó el operario, así que no se pierde información y las comparaciones contra el
/// stock de BC son siempre directas.
///
/// Un traslado entre ubicaciones NO genera movimiento de producto: el stock total lo
/// siguen gobernando los flujos existentes de BC.
/// </summary>
codeunit 51100 "Gestion Contenido SGA"
{
    Permissions = tabledata "Contenido Ubicacion SGA" = rimd,
                  tabledata "Movimiento Ubicacion SGA" = rimd,
                  tabledata "Ubicacion SGA" = rimd;

    var
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        cStock: Codeunit "Consulta Stock SGA";
        cUM: Codeunit "Unidades Producto SGA";
        ParaReserva: Text;

    /// <summary>
    /// Entrada para la que se registra a partir de ahora: puede usar los huecos reservados para
    /// ella (Cod. "Gestion Ubicaciones SGA".ReservarHueco). En blanco, ningún hueco reservado.
    /// </summary>
    procedure FijarReserva(prm_Para: Text)
    begin
        ParaReserva := prm_Para;
    end;

    /// <summary>
    /// Deja mercancía en una ubicación. Devuelve el nº de movimiento registrado. Toda entrada
    /// lleva el SSCC de su palé (TestSSCCEntrada).
    /// </summary>
    procedure RegistrarEntrada(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Origen: Enum "Origen Mov. SGA"; prm_NoDocumento: Code[20]; prm_NoLinea: Integer; prm_Descripcion: Text): Integer
    var
        CantidadEntradaNoPositivaErr: Label 'La cantidad de una entrada debe ser mayor que cero.';
    begin
        if prm_Cantidad <= 0 then
            Error(CantidadEntradaNoPositivaErr);
        TestSSCCEntrada(prm_Almacen, prm_Producto, prm_Variante, prm_Lote, prm_SSCC);

        exit(AplicarMovimiento("Tipo Mov. Ubicacion SGA"::Entrada, prm_Origen, prm_Almacen, '', prm_Ubicacion,
                               prm_Producto, prm_Variante, prm_Lote, prm_SSCC, prm_UM, prm_Cantidad,
                               prm_NoDocumento, prm_NoLinea, prm_Descripcion));
    end;

    /// <summary>
    /// Retira mercancía de una ubicación. Devuelve el nº de movimiento registrado. Con el SSCC en
    /// blanco sale de un palé del lote que haya en la ubicación (SSCCEnUbicacion).
    /// </summary>
    procedure RegistrarSalida(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Origen: Enum "Origen Mov. SGA"; prm_NoDocumento: Code[20]; prm_NoLinea: Integer; prm_Descripcion: Text): Integer
    var
        CantidadSalidaNoPositivaErr: Label 'La cantidad de una salida debe ser mayor que cero.';
    begin
        if prm_Cantidad <= 0 then
            Error(CantidadSalidaNoPositivaErr);

        exit(AplicarMovimiento("Tipo Mov. Ubicacion SGA"::Salida, prm_Origen, prm_Almacen, prm_Ubicacion, '',
                               prm_Producto, prm_Variante, prm_Lote, prm_SSCC, prm_UM, prm_Cantidad,
                               prm_NoDocumento, prm_NoLinea, prm_Descripcion));
    end;

    /// <summary>
    /// Palé (SSCC) de un lote en una ubicación, cuando no se dice cuál. En un hueco hay un solo
    /// palé o restos de uno, así que es el suyo; el SSCC sirve para localizar, no se lee al
    /// sacar. En blanco si en la ubicación no hay nada del lote.
    /// </summary>
    procedure SSCCEnUbicacion(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]): Code[20]
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetRange("Cod. Bin", prm_Ubicacion);
        rContenido.SetRange("No. Producto", prm_Producto);
        rContenido.SetRange("Cod. Variante", prm_Variante);
        rContenido.SetRange("No. Lote", prm_Lote);
        rContenido.SetLoadFields(SSCC);
        if rContenido.FindFirst() then
            exit(rContenido.SSCC);
        exit('');
    end;

    /// <summary>
    /// Una entrada lleva siempre SSCC, y un SSCC es de un solo producto y lote: si ya está en el
    /// almacén con otro, es otro palé leído por error.
    /// </summary>
    local procedure TestSSCCEntrada(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_SSCC: Code[20])
    var
        rContenido: Record "Contenido Ubicacion SGA";
        SSCCObligatorioErr: Label 'Indique el SSCC del palé de %1 que entra.', Comment = '%1 = producto';
        SSCCDeOtroErr: Label 'El SSCC %1 ya está en la ubicación %2 con %3, lote %4. Revise la etiqueta del palé.', Comment = '%1 = SSCC, %2 = ubicación, %3 = producto, %4 = lote';
    begin
        if prm_SSCC = '' then
            Error(SSCCObligatorioErr, prm_Producto);

        rContenido.SetCurrentKey(SSCC, "Cod. Almacen");
        rContenido.SetRange(SSCC, prm_SSCC);
        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetLoadFields("Cod. Bin", "No. Producto", "Cod. Variante", "No. Lote");
        if rContenido.FindFirst() then
            if (rContenido."No. Producto" <> prm_Producto) or (rContenido."Cod. Variante" <> prm_Variante) or (rContenido."No. Lote" <> prm_Lote) then
                Error(SSCCDeOtroErr, prm_SSCC, rContenido."Cod. Bin", rContenido."No. Producto", rContenido."No. Lote");
    end;

    /// <summary>
    /// Saca una línea de contenido entera de su ubicación y la deja sin ubicar. El stock de BC
    /// no cambia: la mercancía queda pendiente de ubicar (Ubicar producto, conciliación).
    /// Quien llama ya ha comprobado que no está reservada (DesubicarLineas).
    /// </summary>
    local procedure Desubicar(var prm_Contenido: Record "Contenido Ubicacion SGA"): Integer
    var
        DesubicadoLbl: Label 'Quitado de la ubicación: pendiente de ubicar.';
    begin
        exit(RegistrarSalida(prm_Contenido."Cod. Almacen", prm_Contenido."Cod. Bin", prm_Contenido."No. Producto",
                             prm_Contenido."Cod. Variante", prm_Contenido."No. Lote", prm_Contenido.SSCC,
                             prm_Contenido."Cod. Unidad Medida", prm_Contenido."Cantidad Base", "Origen Mov. SGA"::Manual, '', 0, DesubicadoLbl));
    end;

    /// <summary>
    /// Saca de su ubicación, enteras, las líneas de contenido del conjunto recibido (filtros o
    /// marcas de la selección) y las deja sin ubicar. Todo o nada: si una línea está reservada
    /// por una orden de picking, no se saca ninguna. Devuelve cuántas líneas ha sacado.
    /// </summary>
    procedure DesubicarLineas(var prm_Contenido: Record "Contenido Ubicacion SGA"): Integer
    var
        TempContenidoCopia: Record "Contenido Ubicacion SGA" temporary;
        lineas: Integer;
    begin
        if not prm_Contenido.FindSet() then
            exit(0);

        // Primero se comprueba todo y se copia a una temporal: cada salida borra su línea al
        // dejarla a cero, y recorrer la tabla real mientras se borra podría saltarse líneas.
        repeat
            ComprobarSinReserva(prm_Contenido);
            TempContenidoCopia := prm_Contenido;
            TempContenidoCopia.Insert();
        until prm_Contenido.Next() = 0;

        TempContenidoCopia.FindSet();
        repeat
            Desubicar(TempContenidoCopia);
            lineas += 1;
        until TempContenidoCopia.Next() = 0;

        exit(lineas);
    end;

    /// <summary>
    /// Abre la lista del contenido de una ubicación.
    /// </summary>
    procedure MostrarContenidoUbicacion(prm_Almacen: Code[10]; prm_Ubicacion: Code[20])
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetRange("Cod. Bin", prm_Ubicacion);
        Page.Run(Page::"Contenido Ubicaciones SGA", rContenido);
    end;

    /// <summary>
    /// VaciarUbicacion desde una pantalla: enseña qué hay, pide confirmación y avisa de cuántas
    /// líneas quedan sin ubicar. Devuelve 0 si no había nada o no se confirma.
    /// </summary>
    procedure VaciarUbicacionConDialogo(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]) lineas: Integer
    var
        rContenido: Record "Contenido Ubicacion SGA";
        detalle: Text;
        LineaDetalleLbl: Label '\  · %1 %2 de %3 (lote %4)', Comment = '%1 = cantidad, %2 = unidad, %3 = producto, %4 = lote';
        VaciarUbicacionQst: Label 'Vaciar la ubicación %1:%2\\Todo queda sin ubicar, pendiente de volver a ubicar. El stock de BC no cambia. ¿Continuar?', Comment = '%1 = ubicación, %2 = lista del contenido';
        UbicacionVaciadaMsg: Label 'Ubicación %1 vaciada: %2 líneas quedan pendientes de ubicar.', Comment = '%1 = ubicación, %2 = líneas';
    begin
        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetRange("Cod. Bin", prm_Ubicacion);
        rContenido.SetLoadFields("Cantidad Base", "Cod. Unidad Medida", "No. Producto", "No. Lote");
        if not rContenido.FindSet() then
            exit(0);
        repeat
            detalle += StrSubstNo(LineaDetalleLbl, rContenido."Cantidad Base", rContenido."Cod. Unidad Medida",
                                  rContenido."No. Producto", rContenido."No. Lote");
        until rContenido.Next() = 0;

        if not Confirm(VaciarUbicacionQst, false, prm_Ubicacion, detalle) then
            exit(0);

        lineas := VaciarUbicacion(prm_Almacen, prm_Ubicacion);
        Message(UbicacionVaciadaMsg, prm_Ubicacion, lineas);
    end;

    /// <summary>
    /// Vacía una ubicación: saca todo su contenido y lo deja sin ubicar. Todo o nada: si una
    /// línea está reservada, no se saca ninguna. Devuelve cuántas líneas ha sacado.
    /// </summary>
    procedure VaciarUbicacion(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]): Integer
    var
        rContenido: Record "Contenido Ubicacion SGA";
        UbicacionReservadaErr: Label 'La ubicación %1 tiene contenido reservado por órdenes de picking. Cancele antes esas órdenes o paradas.', Comment = '%1 = ubicación';
    begin
        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetRange("Cod. Bin", prm_Ubicacion);
        rContenido.SetFilter("Cantidad Reservada", '>%1', 0);
        if not rContenido.IsEmpty() then
            Error(UbicacionReservadaErr, prm_Ubicacion);
        rContenido.SetRange("Cantidad Reservada");

        exit(DesubicarLineas(rContenido));
    end;

    /// <summary>
    /// Bloquea la línea de contenido si está libre y la desbloquea si está bloqueada. Al
    /// bloquear, el motivo deja trazado quién y cuándo; el detalle se matiza luego en la línea.
    /// </summary>
    procedure AlternarBloqueo(var prm_Contenido: Record "Contenido Ubicacion SGA")
    var
        BloqueadoPorLbl: Label 'Bloqueado por %1 el %2', Comment = '%1 = usuario, %2 = fecha';
    begin
        prm_Contenido.Bloqueado := not prm_Contenido.Bloqueado;
        if prm_Contenido.Bloqueado then
            prm_Contenido."Motivo Bloqueo" := CopyStr(StrSubstNo(BloqueadoPorLbl, UserId(), Format(Today())), 1, MaxStrLen(prm_Contenido."Motivo Bloqueo"))
        else
            prm_Contenido."Motivo Bloqueo" := '';
        prm_Contenido.AutorizarEscritura();
        prm_Contenido.Modify(true);
    end;

    /// <summary>
    /// Traslada una línea de contenido con el diálogo "Mover Contenido SGA": el operario
    /// confirma destino, cantidad y motivo. Con prm_Destino relleno el diálogo sale con ese
    /// destino propuesto; al confirmar, prm_Destino devuelve el destino elegido de verdad.
    /// Si el motivo va vacío, el movimiento lleva prm_DescripcionPorDefecto.
    /// Con prm_MismaZona el destino tiene que ser de la zona del origen (el mapa 3D no traslada
    /// entre zonas). Devuelve el nº de movimiento, o 0 si el operario cancela.
    /// </summary>
    procedure TrasladarConDialogo(var prm_Contenido: Record "Contenido Ubicacion SGA"; var prm_Destino: Code[20]; prm_DescripcionPorDefecto: Text; prm_MismaZona: Boolean): Integer
    var
        pMover: Page "Mover Contenido SGA";
        descripcion: Text;
    begin
        pMover.Inicializar(prm_Contenido);
        if prm_MismaZona then
            pMover.LimitarAMismaZona();
        if prm_Destino <> '' then
            pMover.FijarDestino(prm_Destino);
        if pMover.RunModal() <> Action::OK then
            exit(0);

        prm_Destino := pMover.ObtenerDestino();
        descripcion := pMover.ObtenerMotivo();
        if descripcion = '' then
            descripcion := prm_DescripcionPorDefecto;

        exit(RegistrarTraslado(prm_Contenido."Cod. Almacen", prm_Contenido."Cod. Bin", prm_Destino,
                               prm_Contenido."No. Producto", prm_Contenido."Cod. Variante", prm_Contenido."No. Lote",
                               prm_Contenido.SSCC, prm_Contenido."Cod. Unidad Medida", pMover.ObtenerCantidad(),
                               "Origen Mov. SGA"::Manual, '', 0, descripcion));
    end;

    /// <summary>
    /// Mueve mercancía de una ubicación a otra dentro del mismo almacén.
    /// No afecta al stock total ni genera movimiento de producto. Lo trasladado sigue siendo del
    /// mismo palé: lleva su SSCC también en el destino.
    /// </summary>
    procedure RegistrarTraslado(prm_Almacen: Code[10]; prm_UbicacionOrigen: Code[20]; prm_UbicacionDestino: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Origen: Enum "Origen Mov. SGA"; prm_NoDocumento: Code[20]; prm_NoLinea: Integer; prm_Descripcion: Text): Integer
    var
        CantidadTrasladoNoPositivaErr: Label 'La cantidad de un traslado debe ser mayor que cero.';
        MismaUbicacionTrasladoErr: Label 'La ubicación de origen y la de destino de un traslado no pueden ser la misma.';
        UbicacionesTrasladoObligatoriasErr: Label 'Debe indicar la ubicación de origen y la de destino del traslado.';
    begin
        if prm_Cantidad <= 0 then
            Error(CantidadTrasladoNoPositivaErr);
        if (prm_UbicacionOrigen = '') or (prm_UbicacionDestino = '') then
            Error(UbicacionesTrasladoObligatoriasErr);
        if prm_UbicacionOrigen = prm_UbicacionDestino then
            Error(MismaUbicacionTrasladoErr);

        exit(AplicarMovimiento("Tipo Mov. Ubicacion SGA"::Traslado, prm_Origen, prm_Almacen,
                               prm_UbicacionOrigen, prm_UbicacionDestino,
                               prm_Producto, prm_Variante, prm_Lote, prm_SSCC, prm_UM, prm_Cantidad,
                               prm_NoDocumento, prm_NoLinea, prm_Descripcion));
    end;

    /// <summary>
    /// Ajusta la cantidad de una ubicación. Cantidad positiva suma, negativa resta. Es el único
    /// movimiento que puede entrar sin SSCC: la ubicación de ajustes no guarda palés, guarda
    /// diferencias.
    /// </summary>
    procedure RegistrarAjuste(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Descripcion: Text): Integer
    var
        AjusteCeroErr: Label 'El ajuste no puede ser de cantidad cero.';
    begin
        if prm_Cantidad = 0 then
            Error(AjusteCeroErr);

        exit(AplicarConSigno("Tipo Mov. Ubicacion SGA"::Ajuste, "Origen Mov. SGA"::Manual, prm_Almacen, prm_Ubicacion,
                             prm_Producto, prm_Variante, prm_Lote, prm_SSCC, prm_UM, prm_Cantidad, prm_Descripcion));
    end;

    /// <summary>
    /// Carga inicial de contenido al arrancar el módulo. Registra la entrada sin
    /// comprobar capacidad ni reglas de mezcla, porque refleja lo que ya hay físicamente.
    /// No lleva SSCC.
    /// </summary>
    procedure RegistrarCargaInicial(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Descripcion: Text): Integer
    var
        CantidadCargaInicialNoPositivaErr: Label 'La cantidad de la carga inicial debe ser mayor que cero.';
    begin
        if prm_Cantidad <= 0 then
            Error(CantidadCargaInicialNoPositivaErr);

        exit(AplicarMovimiento("Tipo Mov. Ubicacion SGA"::"Carga Inicial", "Origen Mov. SGA"::"Carga Inicial",
                               prm_Almacen, '', prm_Ubicacion, prm_Producto, prm_Variante, prm_Lote, '', prm_UM,
                               prm_Cantidad, '', 0, prm_Descripcion));
    end;

    /// <summary>
    /// Fija la cantidad contada de una línea de contenido (ubicación, lote y palé) y registra la
    /// diferencia como recuento. La cantidad se indica en unidades base. Devuelve 0 si no había
    /// diferencia.
    /// </summary>
    procedure RegistrarRecuento(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_CantidadContada: Decimal; prm_Descripcion: Text): Integer
    var
        rContenido: Record "Contenido Ubicacion SGA";
        umBase: Code[10];
        cantidadActual: Decimal;
        diferencia: Decimal;
    begin
        umBase := cUM.UMBase(prm_Producto);

        if rContenido.Get(prm_Almacen, prm_Ubicacion, prm_Producto, prm_Variante, prm_Lote, umBase, prm_SSCC) then
            cantidadActual := rContenido."Cantidad Base";

        diferencia := Round(prm_CantidadContada - cantidadActual, 0.00001);
        if diferencia = 0 then
            exit(0);

        exit(AplicarConSigno("Tipo Mov. Ubicacion SGA"::Recuento, "Origen Mov. SGA"::Recuento, prm_Almacen, prm_Ubicacion,
                             prm_Producto, prm_Variante, prm_Lote, prm_SSCC, umBase, diferencia, prm_Descripcion));
    end;

    /// <summary>
    /// Un movimiento de cantidad con signo sobre una ubicación (ajuste, recuento): positiva entra
    /// en ella, negativa sale de ella.
    /// </summary>
    local procedure AplicarConSigno(prm_Tipo: Enum "Tipo Mov. Ubicacion SGA"; prm_Origen: Enum "Origen Mov. SGA"; prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Descripcion: Text): Integer
    begin
        if prm_Cantidad > 0 then
            exit(AplicarMovimiento(prm_Tipo, prm_Origen, prm_Almacen, '', prm_Ubicacion, prm_Producto, prm_Variante, prm_Lote,
                                   prm_SSCC, prm_UM, prm_Cantidad, '', 0, prm_Descripcion));

        exit(AplicarMovimiento(prm_Tipo, prm_Origen, prm_Almacen, prm_Ubicacion, '', prm_Producto, prm_Variante, prm_Lote,
                               prm_SSCC, prm_UM, -prm_Cantidad, '', 0, prm_Descripcion));
    end;

    /// <summary>
    /// Fija la cantidad base comprometida por órdenes de picking pendientes.
    /// La calcula Cod. "Gestion Picking SGA" a partir de las paradas abiertas.
    ///
    /// Una salida deja viva la línea mientras le quede reserva; cuando la reserva baja a cero y
    /// ya no queda cantidad, la línea se borra aquí, igual que haría AplicarDelta.
    /// </summary>
    procedure FijarReserva(var rContenido: Record "Contenido Ubicacion SGA"; prm_CantidadReservada: Decimal)
    var
        ReservaSuperaCantidadErr: Label 'No se puede reservar %1 en la ubicación %2: solo hay %3 unidades.', Comment = '%1 = cantidad a reservar, %2 = ubicación, %3 = cantidad disponible';
    begin
        if prm_CantidadReservada > rContenido."Cantidad Base" then
            Error(ReservaSuperaCantidadErr, prm_CantidadReservada, rContenido."Cod. Bin", rContenido."Cantidad Base");

        rContenido."Cantidad Reservada" := prm_CantidadReservada;
        rContenido.ActualizarCantidades();
        rContenido.AutorizarEscritura();

        if (rContenido."Cantidad Base" = 0) and (rContenido."Cantidad Reservada" = 0) then
            rContenido.Delete(true)
        else
            rContenido.Modify(true);
    end;

    /// <summary>
    /// Reconstruye el contenido de un almacén replicando el diario de movimientos.
    /// Es la red de seguridad del módulo: si el contenido se desalinea, esto lo devuelve
    /// al estado que dictan los movimientos registrados.
    ///
    /// Las reservas no salen del diario: son estado de las órdenes abiertas, así que al final
    /// se vuelven a fijar desde sus paradas pendientes.
    /// </summary>
    procedure ReconstruirContenido(prm_Almacen: Code[10]) movimientosProcesados: Integer
    var
        rContenido: Record "Contenido Ubicacion SGA";
        rMovimiento: Record "Movimiento Ubicacion SGA";
        cPicking: Codeunit "Gestion Picking SGA";
    begin
        if prm_Almacen <> '' then
            rContenido.SetRange("Cod. Almacen", prm_Almacen);
        // DeleteAll sin triggers a propósito: es una reconstrucción completa, no una edición.
        rContenido.DeleteAll(false);

        if prm_Almacen <> '' then
            rMovimiento.SetRange("Cod. Almacen", prm_Almacen);

        if rMovimiento.FindSet() then
            repeat
                if rMovimiento."Cod. Bin Origen" <> '' then
                    AcumularSinValidar(rMovimiento, rMovimiento."Cod. Bin Origen", -rMovimiento."Cantidad Base");
                if rMovimiento."Cod. Bin Destino" <> '' then
                    AcumularSinValidar(rMovimiento, rMovimiento."Cod. Bin Destino", rMovimiento."Cantidad Base");
                movimientosProcesados += 1;
            until rMovimiento.Next() = 0;

        LimpiarContenidoVacio(prm_Almacen);
        cPicking.RecalcularReservasAlmacen(prm_Almacen);
        cUbicaciones.RecalcularEstados(prm_Almacen);
    end;

    /// <summary>
    /// Deja un almacén sin nada ubicado, para volver a empezar (por ejemplo, repetir la carga
    /// inicial): borra el contenido, el diario de movimientos y las órdenes de picking sin
    /// terminar. Las ubicaciones se quedan, con su configuración: solo se recalcula su estado.
    /// No queda movimiento que lo registre: es una puesta a cero, no un traslado.
    ///
    /// prm_VistaProductos (GetView de Item) limita a esos productos; en blanco o sin filtros,
    /// todo el almacén. Al ser por producto, contenido y movimientos siguen cuadrando:
    /// ReconstruirContenido daría lo mismo después.
    /// </summary>
    procedure Inicializar(prm_Almacen: Code[10]; prm_VistaProductos: Text)
    var
        rItem: Record Item;
        cPicking: Codeunit "Gestion Picking SGA";
        AlmacenObligatorioErr: Label 'Indique el almacén.';
    begin
        if prm_Almacen = '' then
            Error(AlmacenObligatorioErr);

        if prm_VistaProductos <> '' then
            rItem.SetView(prm_VistaProductos);
        if rItem.GetFilters() = '' then
            InicializarProducto(cPicking, prm_Almacen, '')
        else begin
            rItem.SetLoadFields("No.");
            if rItem.FindSet() then
                repeat
                    InicializarProducto(cPicking, prm_Almacen, rItem."No.");
                until rItem.Next() = 0;
        end;

        cPicking.RecalcularReservasAlmacen(prm_Almacen);
        cUbicaciones.RecalcularEstados(prm_Almacen);
    end;

    /// <summary>
    /// Lo de Inicializar para un producto, o para todos con prm_Producto en blanco.
    /// </summary>
    local procedure InicializarProducto(var prm_Picking: Codeunit "Gestion Picking SGA"; prm_Almacen: Code[10]; prm_Producto: Code[20])
    var
        rContenido: Record "Contenido Ubicacion SGA";
        rMovimiento: Record "Movimiento Ubicacion SGA";
    begin
        prm_Picking.EliminarOrdenesSinTerminar(prm_Almacen, prm_Producto);

        // DeleteAll sin triggers a propósito, como en ReconstruirContenido: es una puesta a
        // cero, no una edición.
        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        if prm_Producto <> '' then
            rContenido.SetRange("No. Producto", prm_Producto);
        rContenido.DeleteAll(false);

        rMovimiento.SetRange("Cod. Almacen", prm_Almacen);
        if prm_Producto <> '' then
            rMovimiento.SetRange("No. Producto", prm_Producto);
        rMovimiento.DeleteAll(false);
    end;

    /// <summary>
    /// Una línea con cantidad reservada por una orden de picking no se puede sacar de su
    /// ubicación: la orden se quedaría sin el stock que tiene que recoger.
    /// </summary>
    local procedure ComprobarSinReserva(var prm_Contenido: Record "Contenido Ubicacion SGA")
    var
        LineaReservadaErr: Label 'La línea de %1 en %2 tiene %3 reservadas por una orden de picking. Cancele antes la orden o la parada.', Comment = '%1 = producto, %2 = ubicación, %3 = cantidad reservada';
    begin
        if prm_Contenido."Cantidad Reservada" > 0 then
            Error(LineaReservadaErr, prm_Contenido."No. Producto", prm_Contenido."Cod. Bin", prm_Contenido."Cantidad Reservada");
    end;

    /// <summary>
    /// Lo que sale de una ubicación sin decir de qué palé sale de uno del lote (SSCCEnUbicacion).
    /// </summary>
    local procedure AplicarMovimiento(prm_Tipo: Enum "Tipo Mov. Ubicacion SGA"; prm_Origen: Enum "Origen Mov. SGA"; prm_Almacen: Code[10]; prm_UbicacionOrigen: Code[20]; prm_UbicacionDestino: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_NoDocumento: Code[20]; prm_NoLinea: Integer; prm_Descripcion: Text) noMovimiento: Integer
    var
        rItem: Record Item;
        cReubicaciones: Codeunit "Reubicaciones SGA";
        umUsada: Code[10];
        umBase: Code[10];
        factor: Decimal;
        cantidadBase: Decimal;
        caducidad: Date;
        AlmacenObligatorioErr: Label 'Debe indicar el almacén.';
        ProductoObligatorioErr: Label 'Debe indicar el producto.';
        ProductoBloqueadoErr: Label 'El producto %1 está bloqueado.', Comment = '%1 = producto';
    begin
        if prm_Almacen = '' then
            Error(AlmacenObligatorioErr);
        if prm_Producto = '' then
            Error(ProductoObligatorioErr);

        rItem.SetLoadFields(Blocked, "Base Unit of Measure");
        rItem.Get(prm_Producto);
        if rItem.Blocked then
            Error(ProductoBloqueadoErr, prm_Producto);

        // La UM en blanco es la base del producto; cualquier otra tiene que ser suya.
        umBase := rItem."Base Unit of Measure";
        umUsada := prm_UM;
        if umUsada = '' then
            umUsada := umBase;
        factor := cUM.TestUMProducto(prm_Producto, umUsada);
        cantidadBase := Round(prm_Cantidad * factor, 0.00001);
        caducidad := cStock.CaducidadLote(prm_Producto, prm_Variante, prm_Lote);
        if (prm_SSCC = '') and (prm_UbicacionOrigen <> '') then
            prm_SSCC := SSCCEnUbicacion(prm_Almacen, prm_UbicacionOrigen, prm_Producto, prm_Variante, prm_Lote);

        // Salida primero: si no hay existencias en el origen no llego a tocar el destino.
        if prm_UbicacionOrigen <> '' then
            AplicarDelta(prm_Almacen, prm_UbicacionOrigen, prm_Producto, prm_Variante, prm_Lote, prm_SSCC, umBase,
                         -cantidadBase, caducidad, false);

        if prm_UbicacionDestino <> '' then
            AplicarDelta(prm_Almacen, prm_UbicacionDestino, prm_Producto, prm_Variante, prm_Lote, prm_SSCC, umBase,
                         cantidadBase, caducidad,
                         prm_Tipo <> "Tipo Mov. Ubicacion SGA"::"Carga Inicial");

        noMovimiento := InsertarMovimiento(prm_Tipo, prm_Origen, prm_Almacen, prm_UbicacionOrigen, prm_UbicacionDestino,
                                           prm_Producto, prm_Variante, prm_Lote, prm_SSCC, caducidad, umUsada, factor,
                                           prm_Cantidad, cantidadBase, prm_NoDocumento, prm_NoLinea, prm_Descripcion);

        // Una ubicación de picking que se queda a cero de un producto pide reposición, sea cual
        // sea el movimiento que la vacía: picking, traslado, vaciado o ajuste.
        if prm_UbicacionOrigen <> '' then
            cReubicaciones.ReubicarSiSeVacia(prm_Almacen, prm_UbicacionOrigen, prm_Producto, prm_Variante);
    end;

    local procedure AplicarDelta(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UMBase: Code[10]; prm_DeltaBase: Decimal; prm_Caducidad: Date; prm_ValidarEntrada: Boolean)
    var
        rContenido: Record "Contenido Ubicacion SGA";
        rUbicacionSGA: Record "Ubicacion SGA";
        rConfig: Record "Config. SGA";
        existe: Boolean;
        ExistenciasInsuficientesErr: Label 'En la ubicación %1 solo hay %2 unidades de %3 (lote %4) y se intentan retirar %5.', Comment = '%1 = ubicación, %2 = cantidad disponible, %3 = producto, %4 = lote, %5 = cantidad a retirar';
        SinExistenciasErr: Label 'En la ubicación %1 no hay existencias de %2 (lote %3, SSCC %4).', Comment = '%1 = ubicación, %2 = producto, %3 = lote, %4 = SSCC';
    begin
        // Una ubicación creada en BC por fuera se da de alta en SGA la primera vez que se usa.
        if not rUbicacionSGA.Get(prm_Almacen, prm_Ubicacion) then begin
            cUbicaciones.SincronizarTopologia(prm_Almacen);
            rUbicacionSGA.Get(prm_Almacen, prm_Ubicacion);
        end;

        if prm_ValidarEntrada and (prm_DeltaBase > 0) then
            TestUbicacionAdmite(rUbicacionSGA, prm_Producto, prm_Lote, prm_DeltaBase);

        existe := rContenido.Get(prm_Almacen, prm_Ubicacion, prm_Producto, prm_Variante, prm_Lote, prm_UMBase, prm_SSCC);

        if not existe then begin
            if prm_DeltaBase < 0 then begin
                rConfig.ObtenerConfig();
                if not rConfig."Permitir Cantidad Negativa" then
                    Error(SinExistenciasErr, prm_Ubicacion, prm_Producto, prm_Lote, prm_SSCC);
            end;

            NuevaLineaContenido(rContenido, prm_Almacen, prm_Ubicacion, prm_Producto, prm_Variante, prm_Lote, prm_SSCC, prm_UMBase);
        end;

        if (prm_DeltaBase < 0) and (rContenido."Cantidad Base" + prm_DeltaBase < 0) then begin
            rConfig.ObtenerConfig();
            if not rConfig."Permitir Cantidad Negativa" then
                Error(ExistenciasInsuficientesErr, prm_Ubicacion, rContenido."Cantidad Base", prm_Producto, prm_Lote, -prm_DeltaBase);
        end;

        rContenido."Cantidad Base" := rContenido."Cantidad Base" + prm_DeltaBase;
        if prm_Caducidad <> 0D then
            rContenido."Fecha Caducidad" := prm_Caducidad;

        if prm_DeltaBase > 0 then
            rContenido."Fecha Ultima Entrada" := CurrentDateTime()
        else
            rContenido."Fecha Ultima Salida" := CurrentDateTime();

        rContenido.ActualizarCantidades();
        rContenido.AutorizarEscritura();

        case true of
            (rContenido."Cantidad Base" = 0) and (rContenido."Cantidad Reservada" = 0) and existe:
                rContenido.Delete(true);
            existe:
                rContenido.Modify(true);
            else
                rContenido.Insert(true);
        end;

        RefrescarUbicacion(rUbicacionSGA);
    end;

    local procedure AcumularSinValidar(var rMovimiento: Record "Movimiento Ubicacion SGA"; prm_Ubicacion: Code[20]; prm_DeltaBase: Decimal)
    var
        rContenido: Record "Contenido Ubicacion SGA";
        umBase: Code[10];
        existe: Boolean;
    begin
        umBase := cUM.UMBase(rMovimiento."No. Producto");

        existe := rContenido.Get(rMovimiento."Cod. Almacen", prm_Ubicacion, rMovimiento."No. Producto",
                                 rMovimiento."Cod. Variante", rMovimiento."No. Lote", umBase, rMovimiento.SSCC);

        if not existe then
            NuevaLineaContenido(rContenido, rMovimiento."Cod. Almacen", prm_Ubicacion, rMovimiento."No. Producto",
                                rMovimiento."Cod. Variante", rMovimiento."No. Lote", rMovimiento.SSCC, umBase);

        rContenido."Cantidad Base" := rContenido."Cantidad Base" + prm_DeltaBase;
        if rMovimiento."Fecha Caducidad" <> 0D then
            rContenido."Fecha Caducidad" := rMovimiento."Fecha Caducidad";

        if prm_DeltaBase > 0 then
            rContenido."Fecha Ultima Entrada" := rMovimiento."Fecha-Hora Registro"
        else
            rContenido."Fecha Ultima Salida" := rMovimiento."Fecha-Hora Registro";

        rContenido.ActualizarCantidades();
        rContenido.AutorizarEscritura();

        if existe then
            rContenido.Modify(false)
        else
            rContenido.Insert(false);
    end;

    /// <summary>
    /// Línea de contenido nueva, sin insertar y a cero, en la unidad base del producto.
    /// </summary>
    local procedure NuevaLineaContenido(var rContenido: Record "Contenido Ubicacion SGA"; prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UMBase: Code[10])
    begin
        rContenido.Init();
        rContenido."Cod. Almacen" := prm_Almacen;
        rContenido."Cod. Bin" := prm_Ubicacion;
        rContenido."No. Producto" := prm_Producto;
        rContenido."Cod. Variante" := prm_Variante;
        rContenido."No. Lote" := prm_Lote;
        rContenido.SSCC := prm_SSCC;
        rContenido."Cod. Unidad Medida" := prm_UMBase;
        rContenido."Cantidad Base" := 0;
    end;

    local procedure LimpiarContenidoVacio(prm_Almacen: Code[10])
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        if prm_Almacen <> '' then
            rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetRange("Cantidad Base", 0);
        rContenido.SetRange("Cantidad Reservada", 0);
        rContenido.DeleteAll(false);
    end;

    local procedure TestUbicacionAdmite(var rUbicacionSGA: Record "Ubicacion SGA"; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_CantidadBase: Decimal)
    var
        rContenido: Record "Contenido Ubicacion SGA";
        ocupado: Decimal;
        entrada: Decimal;
        grupoIIEE: Code[20];
        FueraZonaGrupoQst: Label 'La ubicación %1 no está en ninguna zona del grupo IIEE del producto %2 (%3). ¿Desea dejarlo ahí de todos modos?', Comment = '%1 = ubicación, %2 = producto, %3 = grupo IIEE';
        UbicacionBloqueadaErr: Label 'La ubicación %1 está bloqueada: %2', Comment = '%1 = ubicación, %2 = motivo de bloqueo';
        UbicacionProductoFijoErr: Label 'La ubicación %1 está reservada para el producto %2.', Comment = '%1 = ubicación, %2 = producto fijo';
        MezclaProductoErr: Label 'La ubicación %1 no permite mezclar productos y ya contiene %2.', Comment = '%1 = ubicación, %2 = producto que ya contiene';
        MezclaLoteErr: Label 'La ubicación %1 no permite mezclar lotes y ya contiene el lote %2.', Comment = '%1 = ubicación, %2 = lote que ya contiene';
        SinCapacidadErr: Label 'La ubicación %1 no tiene hueco: capacidad %2, ocupado %3, se intenta añadir %4.', Comment = '%1 = ubicación, %2 = capacidad, %3 = ocupado, %4 = cantidad que se intenta añadir';
        SuperaCapacidadQst: Label 'La ubicación %1 se queda por encima de su capacidad (%2 de %3). ¿Desea continuar?', Comment = '%1 = ubicación, %2 = ocupación resultante, %3 = capacidad';
        UbicacionReservadaErr: Label 'La ubicación %1 está reservada para %2 (%3).', Comment = '%1 = ubicación, %2 = entrada, %3 = usuario';
    begin
        if not rUbicacionSGA.EsUtilizable() then
            Error(UbicacionBloqueadaErr, rUbicacionSGA."Cod. Bin", rUbicacionSGA."Motivo Bloqueo");

        if rUbicacionSGA.ReservadaParaOtro(ParaReserva) then
            Error(UbicacionReservadaErr, rUbicacionSGA."Cod. Bin", rUbicacionSGA."Reservada Para", rUbicacionSGA."Reservada Por");

        if (rUbicacionSGA."Producto Fijo" <> '') and (rUbicacionSGA."Producto Fijo" <> prm_Producto) then
            Error(UbicacionProductoFijoErr, rUbicacionSGA."Cod. Bin", rUbicacionSGA."Producto Fijo");

        case rUbicacionSGA.ContenidoQueImpideMezcla(prm_Producto, prm_Lote, rContenido) of
            5:
                Error(MezclaProductoErr, rUbicacionSGA."Cod. Bin", rContenido."No. Producto");
            6:
                Error(MezclaLoteErr, rUbicacionSGA."Cod. Bin", rContenido."No. Lote");
        end;

        // Fuera de las zonas de su grupo IIEE se puede dejar, pero avisando. Sin interfaz se deja pasar.
        if GuiAllowed() then
            if cUbicaciones.FueraDeZonasGrupoIIEE(rUbicacionSGA, prm_Producto, grupoIIEE) then
                if not Confirm(FueraZonaGrupoQst, false, rUbicacionSGA."Cod. Bin", prm_Producto, grupoIIEE) then
                    Error('');

        if rUbicacionSGA."Capacidad Uds." <= 0 then
            exit;

        // La capacidad se declara en palés. Lo que hay se cuenta con el palé de cada producto y
        // lo que entra, con el de este producto: así caben juntos palés de 200 y de 300.
        ocupado := rUbicacionSGA.OcupadoEnPales();
        entrada := Round(cUM.EnPales(prm_Producto, prm_CantidadBase), 0.00001);

        if ocupado + entrada <= rUbicacionSGA."Capacidad Uds." then
            exit;

        // La capacidad se controla siempre: solo si la ubicación (o la configuración, si ella no
        // dice nada) avisa se puede pasar, confirmándolo. Si no, se bloquea.
        if not rUbicacionSGA.SoloAvisaCapacidad() then
            Error(SinCapacidadErr, rUbicacionSGA."Cod. Bin", rUbicacionSGA."Capacidad Uds.", ocupado, entrada);

        // Avisar: sin interfaz se deja pasar y queda el registro del movimiento.
        if not GuiAllowed() then
            exit;

        if not Confirm(SuperaCapacidadQst, false, rUbicacionSGA."Cod. Bin", ocupado + entrada, rUbicacionSGA."Capacidad Uds.") then
            Error('');
    end;

    local procedure InsertarMovimiento(prm_Tipo: Enum "Tipo Mov. Ubicacion SGA"; prm_Origen: Enum "Origen Mov. SGA"; prm_Almacen: Code[10]; prm_UbicacionOrigen: Code[20]; prm_UbicacionDestino: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_Caducidad: Date; prm_UM: Code[10]; prm_Factor: Decimal; prm_Cantidad: Decimal; prm_CantidadBase: Decimal; prm_NoDocumento: Code[20]; prm_NoLinea: Integer; prm_Descripcion: Text): Integer
    var
        rMovimiento: Record "Movimiento Ubicacion SGA";
    begin
        rMovimiento.Init();
        rMovimiento."Tipo Movimiento" := prm_Tipo;
        rMovimiento.Origen := prm_Origen;
        rMovimiento."Cod. Almacen" := prm_Almacen;
        rMovimiento."Cod. Bin Origen" := prm_UbicacionOrigen;
        rMovimiento."Cod. Bin Destino" := prm_UbicacionDestino;
        rMovimiento."No. Producto" := prm_Producto;
        rMovimiento."Cod. Variante" := prm_Variante;
        rMovimiento."No. Lote" := prm_Lote;
        rMovimiento.SSCC := prm_SSCC;
        rMovimiento."Fecha Caducidad" := prm_Caducidad;
        rMovimiento."Cod. Unidad Medida" := prm_UM;
        rMovimiento."Ctdad. por Unidad Medida" := prm_Factor;
        rMovimiento.Cantidad := prm_Cantidad;
        rMovimiento."Cantidad Base" := prm_CantidadBase;
        rMovimiento."No. Documento Origen" := prm_NoDocumento;
        rMovimiento."No. Linea Origen" := prm_NoLinea;
        rMovimiento."Fecha Registro" := WorkDate();
        rMovimiento."Fecha-Hora Registro" := CurrentDateTime();
        rMovimiento."Cod. Usuario" := CopyStr(UserId(), 1, MaxStrLen(rMovimiento."Cod. Usuario"));
        rMovimiento.Descripcion := CopyStr(prm_Descripcion, 1, MaxStrLen(rMovimiento.Descripcion));
        rMovimiento.AutorizarEscritura();
        rMovimiento.Insert(true);

        exit(rMovimiento."No. Movimiento");
    end;

    local procedure RefrescarUbicacion(var rUbicacionSGA: Record "Ubicacion SGA")
    begin
        if not rUbicacionSGA.Get(rUbicacionSGA."Cod. Almacen", rUbicacionSGA."Cod. Bin") then
            exit;

        rUbicacionSGA.RecalcularOcupacion();
        rUbicacionSGA."Fecha Ultimo Movimiento" := CurrentDateTime();
        rUbicacionSGA.Modify(false);
    end;
}
