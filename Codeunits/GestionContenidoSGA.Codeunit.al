namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;

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
        ModoSilencioso: Boolean;

    /// <summary>
    /// Desactiva los diálogos de confirmación. Se usa en procesos por lotes
    /// (carga inicial, reconstrucción, importaciones).
    /// </summary>
    procedure FijarModoSilencioso(prm_Silencioso: Boolean)
    begin
        ModoSilencioso := prm_Silencioso;
    end;

    /// <summary>
    /// Deja mercancía en una ubicación. Devuelve el nº de movimiento registrado.
    /// </summary>
    procedure RegistrarEntrada(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Origen: Enum "Origen Mov. SGA"; prm_NoDocumento: Code[20]; prm_NoLinea: Integer; prm_Descripcion: Text): Integer
    var
        CantidadEntradaNoPositivaErr: Label 'La cantidad de una entrada debe ser mayor que cero.';
    begin
        if prm_Cantidad <= 0 then
            Error(CantidadEntradaNoPositivaErr);

        exit(AplicarMovimiento("Tipo Mov. Ubicacion SGA"::Entrada, prm_Origen, prm_Almacen, '', prm_Ubicacion,
                               prm_Producto, prm_Variante, prm_Lote, prm_UM, prm_Cantidad,
                               prm_NoDocumento, prm_NoLinea, prm_Descripcion));
    end;

    /// <summary>
    /// Retira mercancía de una ubicación. Devuelve el nº de movimiento registrado.
    /// </summary>
    procedure RegistrarSalida(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Origen: Enum "Origen Mov. SGA"; prm_NoDocumento: Code[20]; prm_NoLinea: Integer; prm_Descripcion: Text): Integer
    var
        CantidadSalidaNoPositivaErr: Label 'La cantidad de una salida debe ser mayor que cero.';
    begin
        if prm_Cantidad <= 0 then
            Error(CantidadSalidaNoPositivaErr);

        exit(AplicarMovimiento("Tipo Mov. Ubicacion SGA"::Salida, prm_Origen, prm_Almacen, prm_Ubicacion, '',
                               prm_Producto, prm_Variante, prm_Lote, prm_UM, prm_Cantidad,
                               prm_NoDocumento, prm_NoLinea, prm_Descripcion));
    end;

    /// <summary>
    /// Saca una línea de contenido entera de su ubicación y la deja sin ubicar. El stock de BC
    /// no cambia: la mercancía queda pendiente de ubicar (Ubicar producto, conciliación).
    /// No se permite con cantidad reservada por una orden de picking: la orden se quedaría sin
    /// el stock que tiene que recoger.
    /// </summary>
    procedure Desubicar(var prm_Contenido: Record "Contenido Ubicacion SGA"): Integer
    var
        LineaReservadaErr: Label 'La línea de %1 en %2 tiene %3 reservadas por una orden de picking. Cancele antes la orden o la parada.', Comment = '%1 = producto, %2 = ubicación, %3 = cantidad reservada';
        DesubicadoLbl: Label 'Quitado de la ubicación: pendiente de ubicar.';
    begin
        if prm_Contenido."Cantidad Reservada" > 0 then
            Error(LineaReservadaErr, prm_Contenido."No. Producto", prm_Contenido."Cod. Bin", prm_Contenido."Cantidad Reservada");

        exit(RegistrarSalida(prm_Contenido."Cod. Almacen", prm_Contenido."Cod. Bin", prm_Contenido."No. Producto",
                             prm_Contenido."Cod. Variante", prm_Contenido."No. Lote", prm_Contenido."Cod. Unidad Medida",
                             prm_Contenido.Cantidad, "Origen Mov. SGA"::Manual, '', 0, DesubicadoLbl));
    end;

    /// <summary>
    /// Vacía una ubicación: saca todo su contenido y lo deja sin ubicar. Todo o nada: si una
    /// línea está reservada, no se saca ninguna. Devuelve cuántas líneas ha sacado.
    /// </summary>
    procedure VaciarUbicacion(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]): Integer
    var
        rContenido: Record "Contenido Ubicacion SGA";
        TempContenidoCopia: Record "Contenido Ubicacion SGA" temporary;
        lineas: Integer;
        UbicacionReservadaErr: Label 'La ubicación %1 tiene contenido reservado por órdenes de picking. Cancele antes esas órdenes o paradas.', Comment = '%1 = ubicación';
    begin
        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetRange("Cod. Bin", prm_Ubicacion);
        rContenido.SetFilter("Cantidad Reservada", '>%1', 0);
        if not rContenido.IsEmpty() then
            Error(UbicacionReservadaErr, prm_Ubicacion);
        rContenido.SetRange("Cantidad Reservada");

        // Copia antes de sacar: cada salida borra su línea al dejarla a cero.
        if rContenido.FindSet() then
            repeat
                TempContenidoCopia := rContenido;
                TempContenidoCopia.Insert();
            until rContenido.Next() = 0;

        if TempContenidoCopia.FindSet() then
            repeat
                Desubicar(TempContenidoCopia);
                lineas += 1;
            until TempContenidoCopia.Next() = 0;

        exit(lineas);
    end;

    /// <summary>
    /// Mueve mercancía de una ubicación a otra dentro del mismo almacén.
    /// No afecta al stock total ni genera movimiento de producto.
    /// </summary>
    procedure RegistrarTraslado(prm_Almacen: Code[10]; prm_UbicacionOrigen: Code[20]; prm_UbicacionDestino: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Origen: Enum "Origen Mov. SGA"; prm_NoDocumento: Code[20]; prm_NoLinea: Integer; prm_Descripcion: Text): Integer
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
                               prm_Producto, prm_Variante, prm_Lote, prm_UM, prm_Cantidad,
                               prm_NoDocumento, prm_NoLinea, prm_Descripcion));
    end;

    /// <summary>
    /// Ajusta la cantidad de una ubicación. Cantidad positiva suma, negativa resta.
    /// </summary>
    procedure RegistrarAjuste(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Descripcion: Text): Integer
    var
        AjusteCeroErr: Label 'El ajuste no puede ser de cantidad cero.';
    begin
        if prm_Cantidad = 0 then
            Error(AjusteCeroErr);

        if prm_Cantidad > 0 then
            exit(AplicarMovimiento("Tipo Mov. Ubicacion SGA"::Ajuste, "Origen Mov. SGA"::Manual, prm_Almacen,
                                   '', prm_Ubicacion, prm_Producto, prm_Variante, prm_Lote, prm_UM,
                                   prm_Cantidad, '', 0, prm_Descripcion));

        exit(AplicarMovimiento("Tipo Mov. Ubicacion SGA"::Ajuste, "Origen Mov. SGA"::Manual, prm_Almacen,
                               prm_Ubicacion, '', prm_Producto, prm_Variante, prm_Lote, prm_UM,
                               -prm_Cantidad, '', 0, prm_Descripcion));
    end;

    /// <summary>
    /// Carga inicial de contenido al arrancar el módulo. Registra la entrada sin
    /// comprobar capacidad ni reglas de mezcla, porque refleja lo que ya hay físicamente.
    /// </summary>
    procedure RegistrarCargaInicial(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_Descripcion: Text): Integer
    var
        CantidadCargaInicialNoPositivaErr: Label 'La cantidad de la carga inicial debe ser mayor que cero.';
    begin
        if prm_Cantidad <= 0 then
            Error(CantidadCargaInicialNoPositivaErr);

        exit(AplicarMovimiento("Tipo Mov. Ubicacion SGA"::"Carga Inicial", "Origen Mov. SGA"::"Carga Inicial",
                               prm_Almacen, '', prm_Ubicacion, prm_Producto, prm_Variante, prm_Lote, prm_UM,
                               prm_Cantidad, '', 0, prm_Descripcion));
    end;

    /// <summary>
    /// Fija la cantidad contada de una ubicación y registra la diferencia como recuento.
    /// La cantidad se indica en unidades base. Devuelve 0 si no había diferencia.
    /// </summary>
    procedure RegistrarRecuento(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_CantidadContada: Decimal; prm_Descripcion: Text): Integer
    var
        rContenido: Record "Contenido Ubicacion SGA";
        umBase: Code[10];
        cantidadActual: Decimal;
        diferencia: Decimal;
    begin
        umBase := UnidadMedidaBase(prm_Producto);

        if rContenido.Get(prm_Almacen, prm_Ubicacion, prm_Producto, prm_Variante, prm_Lote, umBase) then
            cantidadActual := rContenido."Cantidad Base";

        diferencia := Round(prm_CantidadContada - cantidadActual, 0.00001);
        if diferencia = 0 then
            exit(0);

        if diferencia > 0 then
            exit(AplicarMovimiento("Tipo Mov. Ubicacion SGA"::Recuento, "Origen Mov. SGA"::Recuento, prm_Almacen,
                                   '', prm_Ubicacion, prm_Producto, prm_Variante, prm_Lote, umBase,
                                   diferencia, '', 0, prm_Descripcion));

        exit(AplicarMovimiento("Tipo Mov. Ubicacion SGA"::Recuento, "Origen Mov. SGA"::Recuento, prm_Almacen,
                               prm_Ubicacion, '', prm_Producto, prm_Variante, prm_Lote, umBase,
                               -diferencia, '', 0, prm_Descripcion));
    end;

    /// <summary>
    /// Bloquea o desbloquea una línea de contenido.
    /// </summary>
    procedure BloquearContenido(var rContenido: Record "Contenido Ubicacion SGA"; prm_Bloquear: Boolean; prm_Motivo: Text[50])
    begin
        rContenido.Bloqueado := prm_Bloquear;
        if prm_Bloquear then
            rContenido."Motivo Bloqueo" := prm_Motivo
        else
            rContenido."Motivo Bloqueo" := '';

        rContenido.AutorizarEscritura();
        rContenido.Modify(true);
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

        if (rContenido.Cantidad = 0) and (rContenido."Cantidad Reservada" = 0) then
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

    local procedure AplicarMovimiento(prm_Tipo: Enum "Tipo Mov. Ubicacion SGA"; prm_Origen: Enum "Origen Mov. SGA"; prm_Almacen: Code[10]; prm_UbicacionOrigen: Code[20]; prm_UbicacionDestino: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_NoDocumento: Code[20]; prm_NoLinea: Integer; prm_Descripcion: Text): Integer
    var
        rItem: Record Item;
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

        rItem.Get(prm_Producto);
        if rItem.Blocked then
            Error(ProductoBloqueadoErr, prm_Producto);

        umUsada := prm_UM;
        factor := ObtenerFactorUM(prm_Producto, umUsada);
        umBase := rItem."Base Unit of Measure";
        cantidadBase := Round(prm_Cantidad * factor, 0.00001);
        caducidad := ObtenerCaducidadLote(prm_Producto, prm_Variante, prm_Lote);

        // La UM la fija la ubicación de destino: una ubicación de palés no admite cajas y al
        // revés. Se comprueba contra la UM que usa el operario, no contra la base del producto.
        if (prm_UbicacionDestino <> '') and (prm_Tipo <> "Tipo Mov. Ubicacion SGA"::"Carga Inicial") then
            TestUMAdmitida(prm_Almacen, prm_UbicacionDestino, prm_Producto, umUsada,
                           prm_Tipo = "Tipo Mov. Ubicacion SGA"::Traslado);

        // Salida primero: si no hay existencias en el origen no llego a tocar el destino.
        if prm_UbicacionOrigen <> '' then
            AplicarDelta(prm_Almacen, prm_UbicacionOrigen, prm_Producto, prm_Variante, prm_Lote, umBase,
                         -cantidadBase, caducidad, false);

        if prm_UbicacionDestino <> '' then
            AplicarDelta(prm_Almacen, prm_UbicacionDestino, prm_Producto, prm_Variante, prm_Lote, umBase,
                         cantidadBase, caducidad,
                         prm_Tipo <> "Tipo Mov. Ubicacion SGA"::"Carga Inicial");

        exit(InsertarMovimiento(prm_Tipo, prm_Origen, prm_Almacen, prm_UbicacionOrigen, prm_UbicacionDestino,
                                prm_Producto, prm_Variante, prm_Lote, caducidad, umUsada, factor,
                                prm_Cantidad, cantidadBase, prm_NoDocumento, prm_NoLinea, prm_Descripcion));
    end;

    local procedure AplicarDelta(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_UMBase: Code[10]; prm_DeltaBase: Decimal; prm_Caducidad: Date; prm_ValidarEntrada: Boolean)
    var
        rContenido: Record "Contenido Ubicacion SGA";
        rUbicacionSGA: Record "Ubicacion SGA";
        rConfig: Record "Config. SGA";
        existe: Boolean;
        ExistenciasInsuficientesErr: Label 'En la ubicación %1 solo hay %2 unidades de %3 (lote %4) y se intentan retirar %5.', Comment = '%1 = ubicación, %2 = cantidad disponible, %3 = producto, %4 = lote, %5 = cantidad a retirar';
        SinExistenciasErr: Label 'En la ubicación %1 no hay existencias de %2 (lote %3).', Comment = '%1 = ubicación, %2 = producto, %3 = lote';
    begin
        cUbicaciones.ObtenerOCrear(prm_Almacen, prm_Ubicacion);
        rUbicacionSGA.Get(prm_Almacen, prm_Ubicacion);

        if prm_ValidarEntrada and (prm_DeltaBase > 0) then
            TestUbicacionAdmite(rUbicacionSGA, prm_Producto, prm_Lote, prm_DeltaBase);

        existe := rContenido.Get(prm_Almacen, prm_Ubicacion, prm_Producto, prm_Variante, prm_Lote, prm_UMBase);

        if not existe then begin
            if prm_DeltaBase < 0 then begin
                rConfig.ObtenerConfig();
                if not rConfig."Permitir Cantidad Negativa" then
                    Error(SinExistenciasErr, prm_Ubicacion, prm_Producto, prm_Lote);
            end;

            rContenido.Init();
            rContenido."Cod. Almacen" := prm_Almacen;
            rContenido."Cod. Bin" := prm_Ubicacion;
            rContenido."No. Producto" := prm_Producto;
            rContenido."Cod. Variante" := prm_Variante;
            rContenido."No. Lote" := prm_Lote;
            rContenido."Cod. Unidad Medida" := prm_UMBase;
            rContenido."Ctdad. por Unidad Medida" := 1;
            rContenido.Cantidad := 0;
        end;

        if (prm_DeltaBase < 0) and (rContenido.Cantidad + prm_DeltaBase < 0) then begin
            rConfig.ObtenerConfig();
            if not rConfig."Permitir Cantidad Negativa" then
                Error(ExistenciasInsuficientesErr, prm_Ubicacion, rContenido.Cantidad, prm_Producto, prm_Lote, -prm_DeltaBase);
        end;

        rContenido.Cantidad := rContenido.Cantidad + prm_DeltaBase;
        if prm_Caducidad <> 0D then
            rContenido."Fecha Caducidad" := prm_Caducidad;

        if prm_DeltaBase > 0 then
            rContenido."Fecha Ultima Entrada" := CurrentDateTime()
        else
            rContenido."Fecha Ultima Salida" := CurrentDateTime();

        rContenido.ActualizarCantidades();
        rContenido.AutorizarEscritura();

        case true of
            (rContenido.Cantidad = 0) and (rContenido."Cantidad Reservada" = 0) and existe:
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
        umBase := UnidadMedidaBase(rMovimiento."No. Producto");

        existe := rContenido.Get(rMovimiento."Cod. Almacen", prm_Ubicacion, rMovimiento."No. Producto",
                                 rMovimiento."Cod. Variante", rMovimiento."No. Lote", umBase);

        if not existe then begin
            rContenido.Init();
            rContenido."Cod. Almacen" := rMovimiento."Cod. Almacen";
            rContenido."Cod. Bin" := prm_Ubicacion;
            rContenido."No. Producto" := rMovimiento."No. Producto";
            rContenido."Cod. Variante" := rMovimiento."Cod. Variante";
            rContenido."No. Lote" := rMovimiento."No. Lote";
            rContenido."Cod. Unidad Medida" := umBase;
            rContenido."Ctdad. por Unidad Medida" := 1;
            rContenido.Cantidad := 0;
        end;

        rContenido.Cantidad := rContenido.Cantidad + prm_DeltaBase;
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

    local procedure LimpiarContenidoVacio(prm_Almacen: Code[10])
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        if prm_Almacen <> '' then
            rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetRange(Cantidad, 0);
        rContenido.SetRange("Cantidad Reservada", 0);
        rContenido.DeleteAll(false);
    end;

    local procedure TestUbicacionAdmite(var rUbicacionSGA: Record "Ubicacion SGA"; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_CantidadBase: Decimal)
    var
        rContenido: Record "Contenido Ubicacion SGA";
        rConfig: Record "Config. SGA";
        umHueco: Code[10];
        factorHueco: Decimal;
        ocupado: Decimal;
        entrada: Decimal;
        UbicacionBloqueadaErr: Label 'La ubicación %1 está bloqueada: %2', Comment = '%1 = ubicación, %2 = motivo de bloqueo';
        UbicacionProductoFijoErr: Label 'La ubicación %1 está reservada para el producto %2.', Comment = '%1 = ubicación, %2 = producto fijo';
        MezclaProductoErr: Label 'La ubicación %1 no permite mezclar productos y ya contiene %2.', Comment = '%1 = ubicación, %2 = producto que ya contiene';
        MezclaLoteErr: Label 'La ubicación %1 no permite mezclar lotes y ya contiene el lote %2.', Comment = '%1 = ubicación, %2 = lote que ya contiene';
        SinCapacidadErr: Label 'La ubicación %1 no tiene hueco: capacidad %2, ocupado %3, se intenta añadir %4.', Comment = '%1 = ubicación, %2 = capacidad, %3 = ocupado, %4 = cantidad que se intenta añadir';
        SuperaCapacidadQst: Label 'La ubicación %1 se queda por encima de su capacidad (%2 de %3). ¿Desea continuar?', Comment = '%1 = ubicación, %2 = ocupación resultante, %3 = capacidad';
    begin
        if not rUbicacionSGA.EsUtilizable() then
            Error(UbicacionBloqueadaErr, rUbicacionSGA."Cod. Bin", rUbicacionSGA."Motivo Bloqueo");

        if (rUbicacionSGA."Producto Fijo" <> '') and (rUbicacionSGA."Producto Fijo" <> prm_Producto) then
            Error(UbicacionProductoFijoErr, rUbicacionSGA."Cod. Bin", rUbicacionSGA."Producto Fijo");

        rContenido.SetRange("Cod. Almacen", rUbicacionSGA."Cod. Almacen");
        rContenido.SetRange("Cod. Bin", rUbicacionSGA."Cod. Bin");

        if not rUbicacionSGA."Permite Mezcla Producto" then begin
            rContenido.SetFilter("No. Producto", '<>%1', prm_Producto);
            if rContenido.FindFirst() then
                Error(MezclaProductoErr, rUbicacionSGA."Cod. Bin", rContenido."No. Producto");
            rContenido.SetRange("No. Producto");
        end;

        if not rUbicacionSGA."Permite Mezcla Lote" then begin
            rContenido.SetFilter("No. Lote", '<>%1', prm_Lote);
            if rContenido.FindFirst() then
                Error(MezclaLoteErr, rUbicacionSGA."Cod. Bin", rContenido."No. Lote");
            rContenido.SetRange("No. Lote");
        end;

        if rUbicacionSGA."Capacidad Uds." <= 0 then
            exit;

        rConfig.ObtenerConfig();
        if rConfig."Control Capacidad" = "Control Capacidad SGA"::"No Comprobar" then
            exit;

        // La capacidad se declara en la clase que admite la ubicación ("1 palé", "72 cajas").
        // Todo se cuenta en esa clase: lo que hay, convirtiendo cada línea con el palé o la caja
        // de su producto, y lo que entra, con el de este producto. Así caben juntos palés de
        // 200 y de 300, o cajas de 6 y de 12.
        ocupado := rUbicacionSGA.OcupadoEnUMHueco();
        factorHueco := 1;
        umHueco := rConfig.UMCapacidadProducto(prm_Producto, rUbicacionSGA."Tipo UM Admitida");
        if umHueco <> '' then
            // Copia local: ObtenerFactorUM recibe la UM por referencia y puede cambiarla.
            factorHueco := ObtenerFactorUM(prm_Producto, umHueco);
        entrada := Round(prm_CantidadBase / factorHueco, 0.00001);

        if ocupado + entrada <= rUbicacionSGA."Capacidad Uds." then
            exit;

        if rConfig."Control Capacidad" = "Control Capacidad SGA"::Bloquear then
            Error(SinCapacidadErr, rUbicacionSGA."Cod. Bin", rUbicacionSGA."Capacidad Uds.", ocupado, entrada);

        // Avisar: en proceso por lotes o sin interfaz se deja pasar y queda el registro del movimiento.
        if ModoSilencioso or not GuiAllowed() then
            exit;

        if not Confirm(SuperaCapacidadQst, false, rUbicacionSGA."Cod. Bin", ocupado + entrada, rUbicacionSGA."Capacidad Uds.") then
            Error('');
    end;

    /// <summary>
    /// Comprueba que la UM en la que se mueve la mercancía es la que acepta la ubicación.
    /// Una ubicación de palés no admite cajas y al revés; con "Admite" en blanco
    /// la ubicación admite cualquiera. Los palés de distinto tamaño (PALE, PALE200…) cuentan
    /// todos como palé.
    ///
    /// Un traslado mueve mercancía que ya está ubicada y viaja en UM base (lo que hay en el
    /// hueco). Ahí basta con que el producto tenga una unidad de la clase que admite el destino:
    /// mover el palé de A a B es mover un palé aunque se exprese en botellas.
    /// </summary>
    local procedure TestUMAdmitida(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_UM: Code[10]; prm_EsTraslado: Boolean)
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        rConfig: Record "Config. SGA";
        UMNoAdmitidaErr: Label 'La ubicación %1 admite %2 y no se puede dejar mercancía en %3 en ella. Las unidades sueltas solo van a ubicaciones de Unidad, y las cajas a ubicaciones de Caja o de Palé.', Comment = '%1 = ubicación, %2 = qué admite (Palé/Caja/Unidad), %3 = UM usada';
        ProductoSinUMAdmitidaErr: Label 'La ubicación %1 admite %2 y el producto %3 no tiene ninguna unidad de esa clase.', Comment = '%1 = ubicación, %2 = qué admite (Palé/Caja/Unidad), %3 = producto';
    begin
        if not rUbicacionSGA.Get(prm_Almacen, prm_Ubicacion) then
            exit;

        if rConfig.UMAdmitida(prm_Producto, rUbicacionSGA."Tipo UM Admitida", prm_UM) then
            exit;

        if prm_EsTraslado then begin
            if rConfig.UMProductoDeTipo(prm_Producto, rUbicacionSGA."Tipo UM Admitida") <> '' then
                exit;
            Error(ProductoSinUMAdmitidaErr, prm_Ubicacion, rUbicacionSGA."Tipo UM Admitida", prm_Producto);
        end;

        Error(UMNoAdmitidaErr, prm_Ubicacion, rUbicacionSGA."Tipo UM Admitida", prm_UM);
    end;

    local procedure InsertarMovimiento(prm_Tipo: Enum "Tipo Mov. Ubicacion SGA"; prm_Origen: Enum "Origen Mov. SGA"; prm_Almacen: Code[10]; prm_UbicacionOrigen: Code[20]; prm_UbicacionDestino: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]; prm_Caducidad: Date; prm_UM: Code[10]; prm_Factor: Decimal; prm_Cantidad: Decimal; prm_CantidadBase: Decimal; prm_NoDocumento: Code[20]; prm_NoLinea: Integer; prm_Descripcion: Text): Integer
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
        rMovimiento."Fecha Caducidad" := prm_Caducidad;
        rMovimiento."Cod. Unidad Medida" := prm_UM;
        rMovimiento."Ctdad. por Unidad Medida" := prm_Factor;
        rMovimiento.Cantidad := prm_Cantidad;
        rMovimiento."Cantidad Base" := prm_CantidadBase;
        rMovimiento."No. Documento Origen" := prm_NoDocumento;
        rMovimiento."No. Linea Origen" := prm_NoLinea;
        rMovimiento."Fecha Registro" := WorkDate();
        rMovimiento."Hora Registro" := Time();
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

    local procedure ObtenerFactorUM(prm_Producto: Code[20]; var prm_UM: Code[10]): Decimal
    var
        rItem: Record Item;
        rItemUM: Record "Item Unit of Measure";
        UMNoDefinidaErr: Label 'La unidad de medida %1 no está definida para el producto %2.', Comment = '%1 = unidad de medida, %2 = producto';
    begin
        rItem.Get(prm_Producto);

        if prm_UM = '' then
            prm_UM := rItem."Base Unit of Measure";

        if prm_UM = rItem."Base Unit of Measure" then
            exit(1);

        if not rItemUM.Get(prm_Producto, prm_UM) then
            Error(UMNoDefinidaErr, prm_UM, prm_Producto);

        if rItemUM."Qty. per Unit of Measure" <= 0 then
            exit(1);

        exit(rItemUM."Qty. per Unit of Measure");
    end;

    local procedure UnidadMedidaBase(prm_Producto: Code[20]): Code[10]
    var
        rItem: Record Item;
    begin
        if not rItem.Get(prm_Producto) then
            exit('');

        exit(rItem."Base Unit of Measure");
    end;

    local procedure ObtenerCaducidadLote(prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Lote: Code[50]): Date
    var
        rItemLedgEntry: Record "Item Ledger Entry";
    begin
        if prm_Lote = '' then
            exit(0D);

        // La caducidad se toma de los movimientos de producto del lote, que es donde ya
        // la registran los flujos de compra y de fabricación.
        rItemLedgEntry.SetRange("Item No.", prm_Producto);
        rItemLedgEntry.SetRange("Lot No.", prm_Lote);
        if prm_Variante <> '' then
            rItemLedgEntry.SetRange("Variant Code", prm_Variante);
        rItemLedgEntry.SetFilter("Expiration Date", '<>%1', 0D);
        if rItemLedgEntry.FindLast() then
            exit(rItemLedgEntry."Expiration Date");

        exit(0D);
    end;
}
