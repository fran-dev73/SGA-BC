namespace AntonioNadal.SGA;

/// <summary>
/// Codeunit Reposiciones SGA (ID 51113).
/// Decide qué hay que llevar de almacenamiento a picking y adónde, siempre que haya stock
/// disponible en almacenamiento. Se planifica:
///   - en cuanto una ubicación de picking se queda a cero de un producto (ReubicarSiSeVacia, que
///     lanza Cod. "Gestion Contenido SGA" con cualquier movimiento que saque de ella): a la
///     misma ubicación si la sigue admitiendo, aunque el producto quede en otra de picking, y
///     salvo que ya tenga una reubicación pendiente hacia ella;
///   - en el proceso periódico (PlanificarAlmacen; OnRun lo lanza desde la cola de proyectos):
///     para los productos que no tienen nada en ninguna ubicación de picking ni reubicación
///     pendiente, también los que nunca han tenido ubicación de picking.
/// Se trae de almacenamiento el primer contenido en el orden de la estrategia de picking (FEFO,
/// FIFO…), un palé como mucho. El destino lo elige la propuesta de siempre limitada a picking
/// (Cod. "Gestion Ubicaciones SGA".ProponerEnPicking, estrategia Estándar): la ubicación fija del
/// producto, si no consolidar y si no la primera libre, con su capacidad, mezcla y bloqueo.
///
/// La reubicación es una parada de una orden de origen Reposicion (Cod. "Gestion Picking SGA".
/// AnadirReubicacion): reserva el stock de origen, se asigna, se prepara y se confirma como
/// cualquier picking, y al confirmarla se traslada el stock al destino.
/// </summary>
codeunit 51113 "Reposiciones SGA"
{
    Access = Public;

    trigger OnRun()
    begin
        PlanificarAlmacen();
    end;

    /// <summary>
    /// Planifica las reubicaciones del almacén por defecto de la configuración: una por cada
    /// producto con stock disponible en almacenamiento y nada en picking que no tenga ya una
    /// pendiente. Devuelve cuántas ha planificado.
    /// </summary>
    procedure PlanificarAlmacen() planificadas: Integer
    var
        rConfig: Record "Config. SGA";
        rContenido: Record "Contenido Ubicacion SGA";
        // Productos que no hay que mirar: los que ya están en picking y los ya vistos.
        descartados: List of [Code[20]];
        almacen: Code[10];
        AlmacenObligatorioErr: Label 'Ponga el almacén por defecto en la configuración de SGA.';
    begin
        almacen := rConfig.AlmacenODefecto('');
        if almacen = '' then
            Error(AlmacenObligatorioErr);

        // Una pasada por el contenido del almacén para saber qué está ya en picking, y otra por
        // lo que hay en almacenamiento: así no se consulta producto a producto.
        rContenido.SetRange("Cod. Almacen", almacen);
        rContenido.SetRange("Tipo Ubicacion", rContenido."Tipo Ubicacion"::Picking);
        rContenido.SetLoadFields("No. Producto");
        if rContenido.FindSet() then
            repeat
                if not descartados.Contains(rContenido."No. Producto") then
                    descartados.Add(rContenido."No. Producto");
            until rContenido.Next() = 0;

        rContenido.SetRange("Tipo Ubicacion", rContenido."Tipo Ubicacion"::Almacenamiento);
        rContenido.FiltrarCogible();
        if rContenido.FindSet() then
            repeat
                if not descartados.Contains(rContenido."No. Producto") then begin
                    descartados.Add(rContenido."No. Producto");
                    if Planificar(almacen, rContenido."No. Producto", '') then
                        planificadas += 1;
                end;
            until rContenido.Next() = 0;
    end;

    /// <summary>
    /// Después de sacar de prm_Ubicacion: si es de picking y se ha quedado a cero del producto,
    /// planifica traerlo de almacenamiento, a la misma ubicación si la sigue admitiendo. Una
    /// línea a cero que sigue existiendo (porque aún tenía reserva) cuenta como vacía.
    /// </summary>
    procedure ReubicarSiSeVacia(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20])
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        rUbicacionSGA.SetLoadFields("Tipo Ubicacion");
        if not rUbicacionSGA.Get(prm_Almacen, prm_Ubicacion) then
            exit;
        if rUbicacionSGA."Tipo Ubicacion" <> rUbicacionSGA."Tipo Ubicacion"::Picking then
            exit;

        rContenido.FiltrarUbicacion(prm_Almacen, prm_Ubicacion);
        rContenido.SetRange("No. Producto", prm_Producto);
        rContenido.SetFilter("Cantidad Base", '>%1', 0);
        if not rContenido.IsEmpty() then
            exit;

        if Planificar(prm_Almacen, prm_Producto, prm_Ubicacion) then;
    end;

    /// <summary>
    /// Planifica la reubicación de un producto si la necesita (ver el resumen del codeunit) y
    /// hay adónde llevarla. prm_Preferida es la ubicación de picking que se acaba de quedar a
    /// cero: se repone aunque el producto siga en otra de picking, se usa como destino si la
    /// admite y solo se descarta si ya hay una reubicación pendiente hacia ella. Sin
    /// prm_Preferida (proceso periódico), solo si el producto no tiene nada en picking ni
    /// reubicación pendiente. Devuelve true si la ha planificado.
    /// </summary>
    local procedure Planificar(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Preferida: Code[20]): Boolean
    var
        rContenido: Record "Contenido Ubicacion SGA";
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        cPicking: Codeunit "Gestion Picking SGA";
        destino: Code[20];
        cantidad: Decimal;
        factorPale: Decimal;
        motivo: Text;
    begin
        // Sin prm_Preferida, PlanificarAlmacen ya ha descartado lo que tiene algo en picking.
        if ReubicacionPendiente(prm_Almacen, prm_Producto, prm_Preferida) then
            exit(false);
        if not BuscarOrigen(prm_Almacen, prm_Producto, rContenido) then
            exit(false);

        // Un palé como mucho: es lo que cabe en un picking de un palé y lo que lleva un viaje.
        // Sin palé (FactorPale da 1) no se limita.
        cantidad := rContenido."Cantidad Disponible";
        factorPale := cUM.FactorPale(prm_Producto);
        if (factorPale > 1) and (cantidad > factorPale) then
            cantidad := factorPale;

        if prm_Preferida <> '' then
            if cUbicaciones.AdmiteEnPicking(prm_Almacen, prm_Preferida, prm_Producto, rContenido."No. Lote", cantidad) then
                destino := prm_Preferida;
        if destino = '' then
            destino := cUbicaciones.ProponerEnPicking(prm_Almacen, prm_Producto, rContenido."No. Lote", rContenido."Cod. Unidad Medida", cantidad, motivo);
        if destino = '' then
            exit(false);
        // Si va a otra ubicación que la vaciada, tampoco se duplica la que ya va hacia allí.
        if (destino <> prm_Preferida) and (prm_Preferida <> '') then
            if ReubicacionPendiente(prm_Almacen, prm_Producto, destino) then
                exit(false);

        cPicking.AnadirReubicacion(rContenido, cantidad, destino);
        exit(true);
    end;

    /// <summary>
    /// El contenido de almacenamiento que se trae: el primero con algo disponible en el orden
    /// de la estrategia de picking de la configuración.
    /// </summary>
    local procedure BuscarOrigen(prm_Almacen: Code[10]; prm_Producto: Code[20]; var prm_Contenido: Record "Contenido Ubicacion SGA"): Boolean
    var
        rConfig: Record "Config. SGA";
        cPicking: Codeunit "Gestion Picking SGA";
        tramo: Integer;
    begin
        rConfig.ObtenerConfig();
        prm_Contenido.Reset();
        prm_Contenido.FiltrarDisponible(prm_Almacen, prm_Producto);
        prm_Contenido.SetRange("Tipo Ubicacion", prm_Contenido."Tipo Ubicacion"::Almacenamiento);
        // El primero que se pueda coger: no de una ubicación o zona bloqueada.
        for tramo := 1 to 2 do
            if cPicking.OrdenarPorEstrategia(prm_Contenido, rConfig."Estrategia Picking", tramo) then
                if prm_Contenido.FindSet() then
                    repeat
                        if prm_Contenido.SePuedeCoger(false) then
                            exit(true);
                    until prm_Contenido.Next() = 0;
        exit(false);
    end;

    /// <summary>
    /// Si el producto ya tiene una reubicación sin terminar en el almacén: hacia prm_Destino o,
    /// con prm_Destino en blanco, hacia cualquier ubicación.
    /// </summary>
    local procedure ReubicacionPendiente(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Destino: Code[20]): Boolean
    var
        rLinea: Record "Linea Orden Picking SGA";
    begin
        rLinea.SetCurrentKey("No. Producto", "No. Lote");
        rLinea.SetRange("No. Producto", prm_Producto);
        rLinea.SetRange("Cod. Almacen", prm_Almacen);
        if prm_Destino <> '' then
            rLinea.SetRange("Cod. Bin Destino", prm_Destino)
        else
            rLinea.SetFilter("Cod. Bin Destino", '<>%1', '');
        rLinea.FiltrarPendientes();
        exit(not rLinea.IsEmpty());
    end;

    var
        cUM: Codeunit "Unidades Producto SGA";
}
