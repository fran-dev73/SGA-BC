namespace AntonioNadal.SGA;

using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using System.Utilities;

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
    // Codeunit.Run da de alta el palé que trae Rec (ver IntentarAltaStock).
    TableNo = "Movimiento Ubicacion SGA";
    Permissions = tabledata "Contenido Ubicacion SGA" = rimd,
                  tabledata "Movimiento Ubicacion SGA" = rimd,
                  tabledata "Ubicacion SGA" = rimd;

    trigger OnRun()
    begin
        RegistrarAltaStock(Rec."Cod. Almacen", Rec."Cod. Bin Destino", Rec."No. Producto", Rec."No. Lote", Rec.SSCC,
                           Rec."Cod. Unidad Medida", Rec.Cantidad);
    end;

    var
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        cStock: Codeunit "Consulta Stock SGA";
        cUM: Codeunit "Unidades Producto SGA";
        cUOMMgt: Codeunit "Unit of Measure Management";
        cReposiciones: Codeunit "Reposiciones SGA";
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
    /// Deja mercancía en una ubicación. Toda entrada lleva el SSCC de su palé (TestSSCCEntrada).
    /// </summary>
    procedure RegistrarEntrada(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Origen: Enum "Origen Mov. SGA"; prm_NoDocumento: Code[20]; prm_Descripcion: Text)
    begin
        TestSSCCEntrada(prm_Almacen, prm_Producto, prm_SSCC);

        // Las entradas van por documento, no por línea: el nº de línea origen queda a 0.
        AplicarMovimiento("Tipo Mov. Ubicacion SGA"::Entrada, prm_Origen, prm_Almacen, '', prm_Ubicacion,
                          prm_Producto, prm_Lote, prm_SSCC, prm_UM, prm_Cantidad,
                          prm_NoDocumento, 0, prm_Descripcion);
    end;

    /// <summary>
    /// Retira mercancía de una ubicación. Con el SSCC en blanco sale de un palé del lote que haya
    /// en la ubicación (SSCCEnUbicacion).
    /// </summary>
    procedure RegistrarSalida(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Origen: Enum "Origen Mov. SGA"; prm_NoDocumento: Code[20]; prm_NoLinea: Integer; prm_Descripcion: Text)
    begin
        AplicarMovimiento("Tipo Mov. Ubicacion SGA"::Salida, prm_Origen, prm_Almacen, prm_Ubicacion, '',
                          prm_Producto, prm_Lote, prm_SSCC, prm_UM, prm_Cantidad,
                          prm_NoDocumento, prm_NoLinea, prm_Descripcion);
    end;

    /// <summary>
    /// Palé (SSCC) de un lote en una ubicación, cuando no se dice cuál. En un hueco hay un solo
    /// palé o restos de uno, así que es el suyo; el SSCC sirve para localizar, no se lee al
    /// sacar. En blanco si en la ubicación no hay nada del lote.
    /// </summary>
    procedure SSCCEnUbicacion(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Lote: Code[50]): Code[20]
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        rContenido.FiltrarUbicacion(prm_Almacen, prm_Ubicacion);
        rContenido.SetRange("No. Producto", prm_Producto);
        rContenido.SetRange("No. Lote", prm_Lote);
        rContenido.SetLoadFields(SSCC);
        if rContenido.FindFirst() then
            exit(rContenido.SSCC);
        exit('');
    end;

    /// <summary>
    /// Una entrada lleva siempre SSCC, y es un palé nuevo: si su SSCC ya está en el almacén,
    /// con el mismo producto o con otro, es una etiqueta leída dos veces o la de otro palé. (Un
    /// SSCC repartido en varias ubicaciones sale de traslados y salidas, no de entradas.)
    /// </summary>
    local procedure TestSSCCEntrada(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_SSCC: Code[20])
    var
        SSCCObligatorioErr: Label 'Indique el SSCC del palé de %1 que entra.', Comment = '%1 = producto';
    begin
        if prm_SSCC = '' then
            Error(SSCCObligatorioErr, prm_Producto);
        TestSSCCNuevo(prm_Almacen, prm_SSCC);
    end;

    /// <summary>
    /// Error si el SSCC ya está en el almacén, con el mismo producto o con otro: es una etiqueta
    /// leída dos veces o la de otro palé.
    /// </summary>
    local procedure TestSSCCNuevo(prm_Almacen: Code[10]; prm_SSCC: Code[20])
    var
        rContenido: Record "Contenido Ubicacion SGA";
        SSCCYaEnAlmacenErr: Label 'El SSCC %1 ya está en la ubicación %2 con %3, lote %4. Es un palé que ya entró: revise la etiqueta.', Comment = '%1 = SSCC, %2 = ubicación, %3 = producto, %4 = lote';
    begin
        rContenido.SetCurrentKey(SSCC, "Cod. Almacen");
        rContenido.SetRange(SSCC, prm_SSCC);
        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetLoadFields("Cod. Bin", "No. Producto", "No. Lote");
        if rContenido.FindFirst() then
            Error(SSCCYaEnAlmacenErr, prm_SSCC, rContenido."Cod. Bin", rContenido."No. Producto", rContenido."No. Lote");
    end;

    /// <summary>
    /// Saca de su ubicación, enteras, las líneas de contenido del conjunto recibido (filtros o
    /// marcas de la selección) y las deja sin ubicar. El stock de BC no cambia: la mercancía
    /// queda pendiente de ubicar. Todo o nada: si una línea está reservada por una orden de
    /// picking, no se saca ninguna. Devuelve cuántas líneas ha sacado.
    /// </summary>
    local procedure DesubicarLineas(var prm_Contenido: Record "Contenido Ubicacion SGA"): Integer
    var
        TempContenidoCopia: Record "Contenido Ubicacion SGA" temporary;
        lineas: Integer;
        DesubicadoLbl: Label 'Quitado de la ubicación: pendiente de ubicar.';
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
            // Una línea en negativo (con "Permitir cantidad negativa") no tiene nada que sacar:
            // se deja a cero con un recuento.
            if TempContenidoCopia."Cantidad Base" < 0 then
                RegistrarRecuento(TempContenidoCopia."Cod. Almacen", TempContenidoCopia."Cod. Bin", TempContenidoCopia."No. Producto",
                                  TempContenidoCopia."No. Lote", TempContenidoCopia.SSCC, 0, DesubicadoLbl)
            else
                RegistrarSalida(TempContenidoCopia."Cod. Almacen", TempContenidoCopia."Cod. Bin", TempContenidoCopia."No. Producto",
                                TempContenidoCopia."No. Lote", TempContenidoCopia.SSCC, TempContenidoCopia."Cod. Unidad Medida",
                                TempContenidoCopia."Cantidad Base", "Origen Mov. SGA"::Manual, '', 0, DesubicadoLbl);
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
        rContenido.FiltrarUbicacion(prm_Almacen, prm_Ubicacion);
        Page.Run(Page::"Contenido Ubicaciones SGA", rContenido);
    end;

    /// <summary>
    /// Quita de su ubicación, desde una pantalla, las líneas de contenido del conjunto recibido
    /// (una ubicación entera con FiltrarUbicacion, o la selección de una lista): enseña qué hay,
    /// pide confirmación, las saca (todo o nada) y avisa de cuántas quedan sin ubicar. Devuelve 0
    /// si no se confirma.
    /// </summary>
    procedure DesubicarConDialogo(var prm_Contenido: Record "Contenido Ubicacion SGA") lineas: Integer
    var
        cConfirmMgt: Codeunit "Confirm Management";
        detalle: Text;
        NadaQueQuitarErr: Label 'No hay contenido que quitar de su ubicación.';
        LineaDetalleLbl: Label '\  · %1 %2 de %3 (lote %4) en %5', Comment = '%1 = cantidad, %2 = unidad, %3 = producto, %4 = lote, %5 = ubicación';
        MasLineasLbl: Label '\  · y %1 líneas más', Comment = '%1 = líneas que no se enseñan';
        DesubicarQst: Label 'Quitar de su ubicación:%1\\Todo queda sin ubicar, pendiente de volver a ubicar. El stock de BC no cambia. ¿Continuar?', Comment = '%1 = lista del contenido';
        DesubicadasMsg: Label '%1 líneas quitadas de su ubicación: quedan pendientes de ubicar.', Comment = '%1 = líneas';
    begin
        if not prm_Contenido.FindSet() then
            Error(NadaQueQuitarErr);
        repeat
            lineas += 1;
            if lineas <= 10 then
                detalle += StrSubstNo(LineaDetalleLbl, prm_Contenido."Cantidad Base", prm_Contenido."Cod. Unidad Medida",
                                      prm_Contenido."No. Producto", prm_Contenido."No. Lote", prm_Contenido."Cod. Bin");
        until prm_Contenido.Next() = 0;
        if lineas > 10 then
            detalle += StrSubstNo(MasLineasLbl, lineas - 10);

        if not cConfirmMgt.GetResponseOrDefault(StrSubstNo(DesubicarQst, detalle), false) then
            exit(0);

        lineas := DesubicarLineas(prm_Contenido);
        Message(DesubicadasMsg, lineas);
    end;

    /// <summary>
    /// Bloquea la línea de contenido si está libre y la desbloquea si está bloqueada. Al
    /// bloquear, el motivo deja trazado quién y cuándo; el detalle se matiza luego en la línea.
    /// No se bloquea lo que ya está reservado por una orden de picking: la orden mandaría a
    /// recogerlo igual. Antes hay que cancelar o sustituir esas paradas.
    /// </summary>
    procedure AlternarBloqueo(var prm_Contenido: Record "Contenido Ubicacion SGA")
    var
        BloqueadoPorLbl: Label 'Bloqueado por %1 el %2', Comment = '%1 = usuario, %2 = fecha';
        ReservadoNoBloquearErr: Label 'No se puede bloquear: %1 de %2 (lote %3) en %4 están reservados por órdenes de picking. Cancele o busque en otra ubicación esas líneas antes de bloquear.', Comment = '%1 = cantidad reservada, %2 = producto, %3 = lote, %4 = ubicación';
    begin
        if (not prm_Contenido.Bloqueado) and (prm_Contenido."Cantidad Reservada" > 0) then
            Error(ReservadoNoBloquearErr, prm_Contenido."Cantidad Reservada", prm_Contenido."No. Producto",
                  prm_Contenido."No. Lote", prm_Contenido."Cod. Bin");
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
    /// confirma destino, cantidad y motivo, y el diálogo registra el traslado al aceptar. Con
    /// prm_Destino relleno el diálogo sale con ese destino propuesto; al confirmar, prm_Destino
    /// devuelve el destino elegido de verdad. El motivo sale con prm_Motivo.
    /// Con prm_MismaZona el destino tiene que ser de la zona del origen (el mapa 3D no traslada
    /// entre zonas). Devuelve true si se ha trasladado.
    /// </summary>
    procedure TrasladarConDialogo(var prm_Contenido: Record "Contenido Ubicacion SGA"; var prm_Destino: Code[20]; prm_Motivo: Text[100]; prm_MismaZona: Boolean): Boolean
    var
        pMover: Page "Mover Contenido SGA";
    begin
        pMover.Inicializar(prm_Contenido, prm_Destino, prm_Motivo, prm_MismaZona);
        if pMover.RunModal() <> Action::OK then
            exit(false);
        prm_Destino := pMover.DestinoElegido();
        exit(true);
    end;

    /// <summary>
    /// Mueve mercancía de una ubicación a otra dentro del mismo almacén.
    /// No afecta al stock total ni genera movimiento de producto. Lo trasladado sigue siendo del
    /// mismo palé: lleva su SSCC también en el destino.
    /// </summary>
    procedure RegistrarTraslado(prm_Almacen: Code[10]; prm_UbicacionOrigen: Code[20]; prm_UbicacionDestino: Code[20]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Origen: Enum "Origen Mov. SGA"; prm_NoDocumento: Code[20]; prm_NoLinea: Integer; prm_Descripcion: Text): Integer
    var
        MismaUbicacionTrasladoErr: Label 'La ubicación de origen y la de destino de un traslado no pueden ser la misma.';
        UbicacionesTrasladoObligatoriasErr: Label 'Debe indicar la ubicación de origen y la de destino del traslado.';
    begin
        if (prm_UbicacionOrigen = '') or (prm_UbicacionDestino = '') then
            Error(UbicacionesTrasladoObligatoriasErr);
        if prm_UbicacionOrigen = prm_UbicacionDestino then
            Error(MismaUbicacionTrasladoErr);

        exit(AplicarMovimiento("Tipo Mov. Ubicacion SGA"::Traslado, prm_Origen, prm_Almacen,
                               prm_UbicacionOrigen, prm_UbicacionDestino,
                               prm_Producto, prm_Lote, prm_SSCC, prm_UM, prm_Cantidad,
                               prm_NoDocumento, prm_NoLinea, prm_Descripcion));
    end;

    /// <summary>
    /// Mete en una ubicación mercancía que ya está ahí, sin comprobar capacidad ni reglas de
    /// mezcla: la carga inicial y el alta de stock en la PDA (prm_Tipo "Carga Inicial") o lo que
    /// BC tiene y SGA no tiene ubicado, en la ubicación de ajustes (prm_Tipo Ajuste, Regularizar
    /// de la conciliación), que guarda diferencias y no palés. El SSCC es opcional; si viene, no
    /// puede estar ya en el almacén (TestSSCCNuevo).
    /// </summary>
    procedure RegistrarAjuste(prm_Tipo: Enum "Tipo Mov. Ubicacion SGA"; prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Descripcion: Text)
    var
        origen: Enum "Origen Mov. SGA";
    begin
        if prm_SSCC <> '' then
            TestSSCCNuevo(prm_Almacen, prm_SSCC);
        origen := "Origen Mov. SGA"::Manual;
        if prm_Tipo = prm_Tipo::"Carga Inicial" then
            origen := "Origen Mov. SGA"::"Carga Inicial";
        AplicarMovimiento(prm_Tipo, origen, prm_Almacen, '', prm_Ubicacion, prm_Producto, prm_Lote, prm_SSCC, prm_UM,
                          prm_Cantidad, '', 0, prm_Descripcion);
    end;

    /// <summary>
    /// RegistrarAltaStock sin la ventana de error de BC, para la PDA: se lanza con Codeunit.Run
    /// (OnRun), así que si algo falla no queda nada grabado y el texto del error vuelve en
    /// prm_Error para enseñarlo en la propia pantalla. Una confirmación (capacidad que solo
    /// avisa) sigue saliendo como pregunta de BC; si se contesta que no, prm_Error va vacío.
    /// </summary>
    procedure IntentarAltaStock(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal; var prm_Error: Text): Boolean
    var
        TempPale: Record "Movimiento Ubicacion SGA" temporary;
    begin
        TempPale."Cod. Almacen" := prm_Almacen;
        TempPale."Cod. Bin Destino" := prm_Ubicacion;
        TempPale."No. Producto" := prm_Producto;
        TempPale."No. Lote" := prm_Lote;
        TempPale.SSCC := prm_SSCC;
        TempPale."Cod. Unidad Medida" := prm_UM;
        TempPale.Cantidad := prm_Cantidad;
        ClearLastError();
        if Codeunit.Run(Codeunit::"Gestion Contenido SGA", TempPale) then
            exit(true);
        prm_Error := GetLastErrorText();
        exit(false);
    end;

    /// <summary>
    /// Alta de un palé que ya está en su ubicación (pantalla "Alta Stock PDA SGA"): stock de BC
    /// que SGA aún no tiene ubicado y que no se puede colocar con la carga inicial porque el
    /// almacén no se puede vaciar. Se registra como la carga inicial, sin comprobar mezcla ni
    /// bloqueos (la mercancía ya está ahí), pero sin pasar de la capacidad de la ubicación
    /// (TestCapacidadAlta). El SSCC es el de la etiqueta, si la tiene; el lote se exige si el
    /// producto lleva lotes de BC.
    /// </summary>
    local procedure RegistrarAltaStock(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal)
    var
        UbicacionObligatoriaErr: Label 'Lea o teclee la ubicación del palé.';
        AltaStockPDALbl: Label 'Alta de stock en PDA';
    begin
        if prm_Ubicacion = '' then
            Error(UbicacionObligatoriaErr);
        cStock.TestLoteIndicado(prm_Producto, prm_Lote);
        TestCapacidadAlta(prm_Almacen, prm_Ubicacion, prm_Producto, cUM.EnBase(prm_Producto, prm_UM, prm_Cantidad));
        RegistrarAjuste("Tipo Mov. Ubicacion SGA"::"Carga Inicial", prm_Almacen, prm_Ubicacion, prm_Producto, prm_Lote, prm_SSCC,
                        prm_UM, prm_Cantidad, AltaStockPDALbl);
    end;

    /// <summary>
    /// Fija la cantidad contada de una línea de contenido (ubicación, lote y palé) y registra la
    /// diferencia como recuento. La cantidad se indica en unidades base. Devuelve 0 si no había
    /// diferencia.
    /// </summary>
    procedure RegistrarRecuento(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_CantidadContada: Decimal; prm_Descripcion: Text) noMovimiento: Integer
    var
        rContenido: Record "Contenido Ubicacion SGA";
        cPicking: Codeunit "Gestion Picking SGA";
        umBase: Code[10];
        cantidadActual: Decimal;
        reservadaAntes: Decimal;
        diferencia: Decimal;
    begin
        umBase := cUM.UMBase(prm_Producto);

        rContenido.SetLoadFields("Cantidad Base", "Cantidad Reservada");
        if rContenido.Get(prm_Almacen, prm_Ubicacion, prm_Producto, prm_Lote, umBase, prm_SSCC) then begin
            cantidadActual := rContenido."Cantidad Base";
            reservadaAntes := rContenido."Cantidad Reservada";
        end;

        diferencia := Round(prm_CantidadContada - cantidadActual, 0.00001);
        if diferencia = 0 then
            exit(0);

        // Positiva entra en la ubicación; negativa sale de ella.
        if diferencia > 0 then
            noMovimiento := AplicarMovimiento("Tipo Mov. Ubicacion SGA"::Recuento, "Origen Mov. SGA"::Recuento, prm_Almacen, '', prm_Ubicacion,
                                              prm_Producto, prm_Lote, prm_SSCC, umBase, diferencia, '', 0, prm_Descripcion)
        else
            noMovimiento := AplicarMovimiento("Tipo Mov. Ubicacion SGA"::Recuento, "Origen Mov. SGA"::Recuento, prm_Almacen, prm_Ubicacion, '',
                                              prm_Producto, prm_Lote, prm_SSCC, umBase, -diferencia, '', 0, prm_Descripcion);
        // Si queda menos de lo reservado, la reserva se recorta a lo que hay ahora; si entra más,
        // puede cubrir paradas que no tenían todo. Una salida sin nada reservado no cambia nada.
        if (diferencia > 0) or (reservadaAntes > 0) then
            cPicking.RecalcularReserva(prm_Almacen, prm_Ubicacion, prm_Producto, prm_Lote, umBase, prm_SSCC);
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

        if (rContenido."Cantidad Base" = 0) and (rContenido."Cantidad Reservada" = 0) then begin
            rContenido.Delete(true);
            // La línea seguía viva solo por su reserva: sin ella, la ubicación puede quedar vacía.
            RecalcularEstadoUbicacion(rContenido."Cod. Almacen", rContenido."Cod. Bin", false);
        end else
            rContenido.Modify(true);
    end;

    /// <summary>
    /// Vuelve a calcular el estado y la ocupación de una ubicación. Con prm_HayMovimiento anota
    /// además la fecha de último movimiento; sin él (ha cambiado lo que se da por contenido, no
    /// ha habido movimiento), no la toca.
    /// </summary>
    local procedure RecalcularEstadoUbicacion(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_HayMovimiento: Boolean)
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        if rUbicacionSGA.Get(prm_Almacen, prm_Ubicacion) then
            RecalcularEstado(rUbicacionSGA, prm_HayMovimiento);
    end;

    /// <summary>
    /// RecalcularEstadoUbicacion sobre la ubicación ya leída.
    /// </summary>
    local procedure RecalcularEstado(var prm_UbicacionSGA: Record "Ubicacion SGA"; prm_HayMovimiento: Boolean)
    var
        // El bloqueo de la zona se lee en cada registro: no se guarda entre movimientos.
        zonasBloqueadas: Dictionary of [Text, Boolean];
    begin
        prm_UbicacionSGA.RecalcularOcupacion(cUM, zonasBloqueadas);
        if prm_HayMovimiento then
            prm_UbicacionSGA."Fecha Ultimo Movimiento" := CurrentDateTime();
        // RecalcularOcupacion cambia el estado y el % de ocupación; el analizador no lo ve.
#pragma warning disable AA0214
        prm_UbicacionSGA.Modify(false);
#pragma warning restore AA0214
    end;

    /// <summary>
    /// Reconstruye el contenido de un almacén replicando el diario de movimientos.
    /// Es la red de seguridad del módulo: si el contenido se desalinea, esto lo devuelve
    /// al estado que dictan los movimientos registrados.
    ///
    /// Las reservas no salen del diario: son estado de las órdenes abiertas, así que al final
    /// se vuelven a fijar desde sus paradas pendientes. Los bloqueos de las líneas (lote en
    /// cuarentena, etc.) tampoco: se guardan antes de borrar y se vuelven a poner al final.
    /// </summary>
    procedure ReconstruirContenido(prm_Almacen: Code[10])
    var
        rContenido: Record "Contenido Ubicacion SGA";
        rMovimiento: Record "Movimiento Ubicacion SGA";
        TempBloqueadas: Record "Contenido Ubicacion SGA" temporary;
        cPicking: Codeunit "Gestion Picking SGA";
        umBase: Code[10];
        fechaEntrada: DateTime;
        entradaOrigen: DateTime;
    begin
        if prm_Almacen <> '' then
            rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetRange(Bloqueado, true);
        if rContenido.FindSet() then
            repeat
                TempBloqueadas := rContenido;
                TempBloqueadas.Insert();
            until rContenido.Next() = 0;
        rContenido.SetRange(Bloqueado);
        // DeleteAll sin triggers a propósito: es una reconstrucción completa, no una edición.
        rContenido.DeleteAll(false);

        if prm_Almacen <> '' then
            rMovimiento.SetRange("Cod. Almacen", prm_Almacen);

        if rMovimiento.FindSet() then
            repeat
                umBase := cUM.UMBase(rMovimiento."No. Producto");
                fechaEntrada := rMovimiento.SystemCreatedAt;
                if rMovimiento."Cod. Bin Origen" <> '' then begin
                    // Lo que se mueve conserva la fecha de entrada que tenía en el origen.
                    entradaOrigen := AcumularSinValidar(rMovimiento, rMovimiento."Cod. Bin Origen", umBase, -rMovimiento."Cantidad Base", rMovimiento.SystemCreatedAt);
                    if entradaOrigen <> 0DT then
                        fechaEntrada := entradaOrigen;
                end;
                if rMovimiento."Cod. Bin Destino" <> '' then
                    AcumularSinValidar(rMovimiento, rMovimiento."Cod. Bin Destino", umBase, rMovimiento."Cantidad Base", fechaEntrada);
            until rMovimiento.Next() = 0;

        // Fuera las líneas que han quedado a cero (rContenido sigue filtrado por el almacén).
        rContenido.SetRange("Cantidad Base", 0);
        rContenido.SetRange("Cantidad Reservada", 0);
        rContenido.DeleteAll(false);

        // Los bloqueos vuelven a las líneas que siguen existiendo (misma ubicación, producto,
        // lote y palé).
        if TempBloqueadas.FindSet() then
            repeat
                if rContenido.Get(TempBloqueadas."Cod. Almacen", TempBloqueadas."Cod. Bin", TempBloqueadas."No. Producto",
                                  TempBloqueadas."No. Lote", TempBloqueadas."Cod. Unidad Medida",
                                  TempBloqueadas.SSCC)
                then begin
                    rContenido.Bloqueado := true;
                    rContenido."Motivo Bloqueo" := TempBloqueadas."Motivo Bloqueo";
                    rContenido.AutorizarEscritura();
                    rContenido.Modify(false);
                end;
            until TempBloqueadas.Next() = 0;

        cPicking.RecalcularReservasAlmacen(prm_Almacen);
        cUbicaciones.RecalcularEstados(prm_Almacen, '');
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
        cUbicaciones.RecalcularEstados(prm_Almacen, '');
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
        LineaReservadaErr: Label 'La línea de %1 en %2 tiene %3 reservadas por una orden de picking. Cancele antes la orden o la línea de picking.', Comment = '%1 = producto, %2 = ubicación, %3 = cantidad reservada';
    begin
        if prm_Contenido."Cantidad Reservada" > 0 then
            Error(LineaReservadaErr, prm_Contenido."No. Producto", prm_Contenido."Cod. Bin", prm_Contenido."Cantidad Reservada");
    end;

    /// <summary>
    /// Lo que sale de una ubicación sin decir de qué palé sale de uno del lote (SSCCEnUbicacion).
    /// </summary>
    local procedure AplicarMovimiento(prm_Tipo: Enum "Tipo Mov. Ubicacion SGA"; prm_Origen: Enum "Origen Mov. SGA"; prm_Almacen: Code[10]; prm_UbicacionOrigen: Code[20]; prm_UbicacionDestino: Code[20]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_NoDocumento: Code[20]; prm_NoLinea: Integer; prm_Descripcion: Text) noMovimiento: Integer
    var
        rItem: Record Item;
        rOrigen: Record "Ubicacion SGA";
        rDestino: Record "Ubicacion SGA";
        umUsada: Code[10];
        umBase: Code[10];
        factor: Decimal;
        cantidadBase: Decimal;
        caducidad: Date;
        fechaEntrada: DateTime;
        entradaOrigen: DateTime;
        AlmacenObligatorioErr: Label 'Indique el almacén.';
        ProductoObligatorioErr: Label 'Debe indicar el producto.';
        CantidadNoPositivaErr: Label 'La cantidad de un movimiento de %1 debe ser mayor que cero.', Comment = '%1 = tipo de movimiento';
        ProductoBloqueadoErr: Label 'El producto %1 está bloqueado.', Comment = '%1 = producto';
    begin
        if prm_Almacen = '' then
            Error(AlmacenObligatorioErr);
        if prm_Producto = '' then
            Error(ProductoObligatorioErr);
        if prm_Cantidad <= 0 then
            Error(CantidadNoPositivaErr, prm_Tipo);

        rItem.SetLoadFields(Blocked, "Base Unit of Measure", Type, "Producto Tianna", "Item Category Code");
        rItem.Get(prm_Producto);
        // En las ubicaciones solo entran los productos que SGA ubica. Lo que ya está dentro se
        // puede mover y sacar.
        if (prm_UbicacionOrigen = '') and (prm_UbicacionDestino <> '') then
            cStock.TestProductoSGA(rItem);
        // Un producto bloqueado no entra ni sale a un pedido, pero sí se puede mover, recontar,
        // regularizar o sacar de su ubicación: es cuando más falta hace (retirada, calidad).
        if rItem.Blocked then
            if (prm_Tipo = "Tipo Mov. Ubicacion SGA"::Entrada) or (prm_Origen = "Origen Mov. SGA"::Venta) then
                Error(ProductoBloqueadoErr, prm_Producto);

        // La UM en blanco es la base del producto; cualquier otra tiene que ser suya.
        umBase := rItem."Base Unit of Measure";
        umUsada := prm_UM;
        if umUsada = '' then
            umUsada := umBase;
        factor := cUOMMgt.GetQtyPerUnitOfMeasure(rItem, umUsada);
        cantidadBase := cUOMMgt.CalcBaseQty(prm_Cantidad, factor);
        caducidad := cStock.CaducidadLote(prm_Producto, prm_Lote);
        if (prm_SSCC = '') and (prm_UbicacionOrigen <> '') then
            prm_SSCC := SSCCEnUbicacion(prm_Almacen, prm_UbicacionOrigen, prm_Producto, prm_Lote);

        // Salida primero: si no hay existencias en el origen no llego a tocar el destino. Lo que
        // se mueve entre ubicaciones conserva su fecha de entrada al almacén (FIFO).
        fechaEntrada := CurrentDateTime();
        if prm_UbicacionOrigen <> '' then begin
            entradaOrigen := AplicarDelta(rOrigen, prm_Almacen, prm_UbicacionOrigen, prm_Producto, prm_Lote, prm_SSCC, umBase,
                                          -cantidadBase, caducidad, false, CurrentDateTime());
            if entradaOrigen <> 0DT then
                fechaEntrada := entradaOrigen;
        end;

        // La carga inicial, un recuento al alza y un ajuste reflejan mercancía que ya está ahí:
        // no se comprueba si la ubicación la admite (capacidad, mezcla, bloqueo, reserva).
        if prm_UbicacionDestino <> '' then
            AplicarDelta(rDestino, prm_Almacen, prm_UbicacionDestino, prm_Producto, prm_Lote, prm_SSCC, umBase,
                         cantidadBase, caducidad,
                         not (prm_Tipo in ["Tipo Mov. Ubicacion SGA"::"Carga Inicial", "Tipo Mov. Ubicacion SGA"::Recuento, "Tipo Mov. Ubicacion SGA"::Ajuste]),
                         fechaEntrada);

        noMovimiento := InsertarMovimiento(prm_Tipo, prm_Origen, prm_Almacen, prm_UbicacionOrigen, prm_UbicacionDestino,
                                           prm_Producto, prm_Lote, prm_SSCC, caducidad, umUsada,
                                           prm_Cantidad, cantidadBase, prm_NoDocumento, prm_NoLinea, prm_Descripcion);

        // Una ubicación de picking que se queda a cero de un producto pide reposición, sea cual
        // sea el movimiento que la vacía: picking, traslado, vaciado o ajuste.
        if prm_UbicacionOrigen <> '' then
            cReposiciones.ReubicarSiSeVacia(rOrigen, prm_Producto);
    end;

    /// <summary>
    /// Suma prm_DeltaBase a la línea de contenido de la ubicación (la crea o la borra si queda
    /// a cero) y recalcula el estado de la ubicación, que deja leída en prm_UbicacionSGA.
    /// Devuelve la "Fecha Entrada" que tenía la línea antes (0DT si es nueva o no la tenía).
    /// </summary>
    local procedure AplicarDelta(var prm_UbicacionSGA: Record "Ubicacion SGA"; prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UMBase: Code[10]; prm_DeltaBase: Decimal; prm_Caducidad: Date; prm_ValidarEntrada: Boolean; prm_Fecha: DateTime) fechaEntradaAnterior: DateTime
    var
        rContenido: Record "Contenido Ubicacion SGA";
        rConfig: Record "Config. SGA";
        existe: Boolean;
        ExistenciasInsuficientesErr: Label 'En la ubicación %1 solo hay %2 unidades de %3 (lote %4) y se intentan retirar %5.', Comment = '%1 = ubicación, %2 = cantidad disponible, %3 = producto, %4 = lote, %5 = cantidad a retirar';
        SinExistenciasErr: Label 'En la ubicación %1 no hay existencias de %2 (lote %3, SSCC %4).', Comment = '%1 = ubicación, %2 = producto, %3 = lote, %4 = SSCC';
    begin
        LeerUbicacionSGA(prm_Almacen, prm_Ubicacion, prm_UbicacionSGA);

        if prm_ValidarEntrada and (prm_DeltaBase > 0) then
            TestUbicacionAdmite(prm_UbicacionSGA, prm_Producto, prm_Lote, prm_DeltaBase);

        existe := rContenido.Get(prm_Almacen, prm_Ubicacion, prm_Producto, prm_Lote, prm_UMBase, prm_SSCC);
        if existe then
            fechaEntradaAnterior := rContenido."Fecha Entrada";

        if not existe then begin
            if prm_DeltaBase < 0 then begin
                rConfig.ObtenerConfig();
                if not rConfig."Permitir Cantidad Negativa" then
                    Error(SinExistenciasErr, prm_Ubicacion, prm_Producto, prm_Lote, prm_SSCC);
            end;

            NuevaLineaContenido(rContenido, prm_Almacen, prm_Ubicacion, prm_Producto, prm_Lote, prm_SSCC, prm_UMBase);
        end;

        if (prm_DeltaBase < 0) and (rContenido."Cantidad Base" + prm_DeltaBase < 0) then begin
            rConfig.ObtenerConfig();
            if not rConfig."Permitir Cantidad Negativa" then
                Error(ExistenciasInsuficientesErr, prm_Ubicacion, rContenido."Cantidad Base", prm_Producto, prm_Lote, -prm_DeltaBase);
        end;

        SumarALinea(rContenido, prm_DeltaBase, prm_Caducidad, prm_Fecha);

        case true of
            (rContenido."Cantidad Base" = 0) and (rContenido."Cantidad Reservada" = 0) and existe:
                rContenido.Delete(true);
            existe:
                rContenido.Modify(true);
            else
                rContenido.Insert(true);
        end;

        // La ubicación ya está leída: el contenido no la modifica.
        RecalcularEstado(prm_UbicacionSGA, true);
    end;

    /// <summary>
    /// Suma prm_DeltaBase a una línea de contenido (leída o nueva, sin guardar): cantidad,
    /// caducidad si llega, fecha y cantidades derivadas. Quien llama la guarda. En una entrada
    /// prm_Fecha es la fecha de entrada al almacén de lo que llega, y la línea se queda con la
    /// más antigua de las dos; en una salida, el momento de la salida.
    /// </summary>
    local procedure SumarALinea(var prm_Contenido: Record "Contenido Ubicacion SGA"; prm_DeltaBase: Decimal; prm_Caducidad: Date; prm_Fecha: DateTime)
    begin
        if prm_DeltaBase > 0 then begin
            if (prm_Contenido."Cantidad Base" <= 0) or (prm_Contenido."Fecha Entrada" = 0DT) or (prm_Fecha < prm_Contenido."Fecha Entrada") then
                prm_Contenido."Fecha Entrada" := prm_Fecha;
        end else
            prm_Contenido."Fecha Ultima Salida" := prm_Fecha;

        prm_Contenido."Cantidad Base" := prm_Contenido."Cantidad Base" + prm_DeltaBase;
        if prm_Caducidad <> 0D then
            prm_Contenido."Fecha Caducidad" := prm_Caducidad;

        prm_Contenido.ActualizarCantidades();
        prm_Contenido.AutorizarEscritura();
    end;

    /// <summary>
    /// Suma al contenido sin validar nada (reconstrucción). Devuelve la "Fecha Entrada" que tenía
    /// la línea antes (0DT si es nueva o no la tenía).
    /// </summary>
    local procedure AcumularSinValidar(var rMovimiento: Record "Movimiento Ubicacion SGA"; prm_Ubicacion: Code[20]; prm_UMBase: Code[10]; prm_DeltaBase: Decimal; prm_Fecha: DateTime) fechaEntradaAnterior: DateTime
    var
        rContenido: Record "Contenido Ubicacion SGA";
        existe: Boolean;
    begin
        existe := rContenido.Get(rMovimiento."Cod. Almacen", prm_Ubicacion, rMovimiento."No. Producto",
                                 rMovimiento."No. Lote", prm_UMBase, rMovimiento.SSCC);
        if existe then
            fechaEntradaAnterior := rContenido."Fecha Entrada";

        if not existe then
            NuevaLineaContenido(rContenido, rMovimiento."Cod. Almacen", prm_Ubicacion, rMovimiento."No. Producto",
                                rMovimiento."No. Lote", rMovimiento.SSCC, prm_UMBase);

        SumarALinea(rContenido, prm_DeltaBase, rMovimiento."Fecha Caducidad", prm_Fecha);

        if existe then
            rContenido.Modify(false)
        else
            rContenido.Insert(false);
    end;

    /// <summary>
    /// Línea de contenido nueva, sin insertar y a cero, en la unidad base del producto.
    /// </summary>
    local procedure NuevaLineaContenido(var rContenido: Record "Contenido Ubicacion SGA"; prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_UMBase: Code[10])
    begin
        rContenido.Init();
        rContenido."Cod. Almacen" := prm_Almacen;
        rContenido."Cod. Bin" := prm_Ubicacion;
        rContenido."No. Producto" := prm_Producto;
        rContenido."No. Lote" := prm_Lote;
        rContenido.SSCC := prm_SSCC;
        rContenido."Cod. Unidad Medida" := prm_UMBase;
        rContenido."Cantidad Base" := 0;
    end;

    /// <summary>
    /// Comprueba, sin registrar nada, que una entrada cabría en la ubicación con las mismas
    /// reglas que al registrarla (bloqueo, reserva, producto fijo, mezcla, capacidad).
    /// La usa "Imprimir y ubicar" antes de imprimir, para no dejar un palé etiquetado sin hueco.
    /// prm_Para es la entrada para la que se puede usar un hueco reservado.
    /// </summary>
    procedure TestEntradaAdmitida(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Para: Text)
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        LeerUbicacionSGA(prm_Almacen, prm_Ubicacion, rUbicacionSGA);
        FijarReserva(prm_Para);
        TestUbicacionAdmite(rUbicacionSGA, prm_Producto, prm_Lote, cUM.EnBase(prm_Producto, prm_UM, prm_Cantidad));
    end;

    /// <summary>
    /// La ficha SGA de una ubicación. Sin ficha no es una ubicación SGA: el error es el de
    /// ComprobarUbicacionExiste. Quien llama no pasa nunca la ubicación en blanco.
    /// </summary>
    local procedure LeerUbicacionSGA(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; var prm_UbicacionSGA: Record "Ubicacion SGA")
    begin
        if not prm_UbicacionSGA.Get(prm_Almacen, prm_Ubicacion) then
            cUbicaciones.ComprobarUbicacionExiste(prm_Almacen, prm_Ubicacion);
    end;

    /// <summary>
    /// La regla de la ubicación (Ubicacion SGA.MotivoRechazoEntrada, la misma que la propuesta)
    /// con el contenido real, convertida en error. Sin sitio, solo se deja pasar confirmándolo
    /// si la ubicación o la configuración solo avisan.
    /// </summary>
    local procedure TestUbicacionAdmite(var rUbicacionSGA: Record "Ubicacion SGA"; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_CantidadBase: Decimal)
    var
        rContenido: Record "Contenido Ubicacion SGA";
        // El bloqueo de la zona se lee en cada registro: no se guarda entre movimientos.
        zonasBloqueadas: Dictionary of [Text, Boolean];
        entrada: Decimal;
        UbicacionBloqueadaErr: Label 'La ubicación %1 está bloqueada: %2', Comment = '%1 = ubicación, %2 = motivo de bloqueo';
        UbicacionProductoFijoErr: Label 'La ubicación %1 está reservada para el producto %2.', Comment = '%1 = ubicación, %2 = producto fijo';
        MezclaProductoErr: Label 'La ubicación %1 no permite mezclar productos y ya contiene %2.', Comment = '%1 = ubicación, %2 = producto que ya contiene';
        MezclaLoteErr: Label 'La ubicación %1 no permite mezclar lotes y ya contiene el lote %2.', Comment = '%1 = ubicación, %2 = lote que ya contiene';
    begin
        entrada := EntradaEnPales(prm_Producto, prm_CantidadBase);
        case rUbicacionSGA.MotivoRechazoEntrada(prm_Producto, prm_Lote, entrada, ParaReserva, true, zonasBloqueadas, cUM, rContenido) of
            0:
                exit;
            1:
                Error(UbicacionBloqueadaErr, rUbicacionSGA."Cod. Bin", rUbicacionSGA."Motivo Bloqueo");
            9:
                rUbicacionSGA.ErrorReservada();
            2:
                Error(UbicacionProductoFijoErr, rUbicacionSGA."Cod. Bin", rUbicacionSGA."Producto Fijo");
            5:
                Error(MezclaProductoErr, rUbicacionSGA."Cod. Bin", rContenido."No. Producto");
            6:
                Error(MezclaLoteErr, rUbicacionSGA."Cod. Bin", rContenido."No. Lote");
        end;
        // Sin sitio (4).
        RechazarPorCapacidad(rUbicacionSGA, entrada);
    end;

    /// <summary>
    /// La capacidad se declara en palés. Lo que hay se cuenta con el palé de cada producto y lo
    /// que entra, con el de este producto: así caben juntos palés de 200 y de 300.
    /// </summary>
    local procedure EntradaEnPales(prm_Producto: Code[20]; prm_CantidadBase: Decimal): Decimal
    begin
        exit(Round(cUM.EnPales(prm_Producto, prm_CantidadBase), 0.00001));
    end;

    /// <summary>
    /// Ubicación sin sitio para prm_Entrada palés: error, salvo que la ubicación (o la
    /// configuración, si ella no dice nada) solo avise; entonces se deja pasar confirmándolo.
    /// </summary>
    local procedure RechazarPorCapacidad(var rUbicacionSGA: Record "Ubicacion SGA"; prm_Entrada: Decimal)
    var
        cConfirmMgt: Codeunit "Confirm Management";
        ocupado: Decimal;
        SinCapacidadErr: Label 'La ubicación %1 no tiene hueco: capacidad %2, ocupado %3, se intenta añadir %4.', Comment = '%1 = ubicación, %2 = capacidad, %3 = ocupado, %4 = cantidad que se intenta añadir';
        SuperaCapacidadQst: Label 'La ubicación %1 se queda por encima de su capacidad (%2 de %3). ¿Desea continuar?', Comment = '%1 = ubicación, %2 = ocupación resultante, %3 = capacidad';
    begin
        // Lo ocupado solo se calcula para el mensaje.
        ocupado := rUbicacionSGA.OcupadoEnPales(cUM);

        // La capacidad se controla siempre: solo si la ubicación (o la configuración, si ella no
        // dice nada) avisa se puede pasar, confirmándolo. Si no, se bloquea.
        if not rUbicacionSGA.SoloAvisaCapacidad() then
            Error(SinCapacidadErr, rUbicacionSGA."Cod. Bin", rUbicacionSGA."Capacidad Uds.", ocupado, prm_Entrada);

        // Avisar: sin interfaz se deja pasar y queda el registro del movimiento.
        if not GuiAllowed() then
            exit;

        if not cConfirmMgt.GetResponseOrDefault(StrSubstNo(SuperaCapacidadQst, rUbicacionSGA."Cod. Bin", ocupado + prm_Entrada, rUbicacionSGA."Capacidad Uds."), false) then
            Error('');
    end;

    /// <summary>
    /// El alta de stock (RegistrarAltaStock) solo comprueba la capacidad de la ubicación: la
    /// mercancía ya está ahí, así que ni mezcla ni bloqueos impiden darla de alta, pero no
    /// puede pasar de lo que cabe (o, si la ubicación solo avisa, confirmándolo).
    /// </summary>
    local procedure TestCapacidadAlta(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_CantidadBase: Decimal)
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        entrada: Decimal;
    begin
        LeerUbicacionSGA(prm_Almacen, prm_Ubicacion, rUbicacionSGA);
        entrada := EntradaEnPales(prm_Producto, prm_CantidadBase);
        if rUbicacionSGA.SuperaCapacidad(entrada, cUM) then
            RechazarPorCapacidad(rUbicacionSGA, entrada);
    end;

    local procedure InsertarMovimiento(prm_Tipo: Enum "Tipo Mov. Ubicacion SGA"; prm_Origen: Enum "Origen Mov. SGA"; prm_Almacen: Code[10]; prm_UbicacionOrigen: Code[20]; prm_UbicacionDestino: Code[20]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_SSCC: Code[20]; prm_Caducidad: Date; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_CantidadBase: Decimal; prm_NoDocumento: Code[20]; prm_NoLinea: Integer; prm_Descripcion: Text): Integer
    var
        rMovimiento: Record "Movimiento Ubicacion SGA";
        rConfig: Record "Config. SGA";
    begin
        rMovimiento.Init();
        rMovimiento."Tipo Movimiento" := prm_Tipo;
        rMovimiento.Origen := prm_Origen;
        rMovimiento."Cod. Almacen" := prm_Almacen;
        rMovimiento."Cod. Bin Origen" := prm_UbicacionOrigen;
        rMovimiento."Cod. Bin Destino" := prm_UbicacionDestino;
        rMovimiento."No. Producto" := prm_Producto;
        rMovimiento."No. Lote" := prm_Lote;
        rMovimiento.SSCC := prm_SSCC;
        rMovimiento."Fecha Caducidad" := prm_Caducidad;
        rMovimiento."Cod. Unidad Medida" := prm_UM;
        rMovimiento.Cantidad := prm_Cantidad;
        rMovimiento."Cantidad Base" := prm_CantidadBase;
        rMovimiento."No. Documento Origen" := prm_NoDocumento;
        rMovimiento."No. Linea Origen" := prm_NoLinea;
        rMovimiento."Fecha Registro" := WorkDate();
        rMovimiento."Cod. Usuario" := rConfig.UsuarioActual();
        rMovimiento.Descripcion := CopyStr(prm_Descripcion, 1, MaxStrLen(rMovimiento.Descripcion));
        rMovimiento.AutorizarEscritura();
        rMovimiento.Insert(true);

        exit(rMovimiento."No. Movimiento");
    end;

}
