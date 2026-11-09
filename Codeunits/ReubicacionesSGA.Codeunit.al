namespace AntonioNadal.SGA;

/// <summary>
/// Codeunit Reubicaciones SGA (ID 51113).
/// Decide qué hay que llevar de almacenamiento a picking y adónde. Un producto necesita una
/// reubicación cuando tiene stock disponible en almacenamiento y nada en ninguna ubicación de
/// picking, y no tiene ya una reubicación pendiente. Se planifica:
///   - al vaciar un picking (ReubicarSiSeVacia, desde la confirmación de cada parada): a la
///     misma ubicación si la sigue admitiendo;
///   - en el proceso periódico (PlanificarAlmacen; OnRun lo lanza desde la cola de proyectos):
///     para todos los productos que estén en esa situación, también los que nunca han tenido
///     ubicación de picking.
/// Se trae de almacenamiento el primer contenido en el orden de la estrategia de picking (FEFO,
/// FIFO…), un palé como mucho. El destino lo elige la propuesta de siempre limitada a picking
/// (Cod. "Gestion Ubicaciones SGA".ProponerEnTipo, estrategia Estándar): la ubicación fija del
/// producto, si no consolidar y si no la primera libre, con su capacidad, mezcla y bloqueo.
///
/// La reubicación es una parada de una orden de origen Reposicion (Cod. "Gestion Picking SGA".
/// AnadirReubicacion): reserva el stock de origen, se asigna, se prepara y se confirma como
/// cualquier picking, y al confirmarla se traslada el stock al destino.
/// </summary>
codeunit 51113 "Reubicaciones SGA"
{
    Access = Public;

    trigger OnRun()
    var
        rConfig: Record "Config. SGA";
    begin
        rConfig.ObtenerConfig();
        PlanificarAlmacen(rConfig."Almacen por Defecto");
    end;

    /// <summary>
    /// Planifica las reubicaciones de un almacén: una por cada producto (y variante) con stock
    /// disponible en almacenamiento y nada en picking que no tenga ya una pendiente. Devuelve
    /// cuántas ha planificado.
    /// </summary>
    procedure PlanificarAlmacen(prm_Almacen: Code[10]) planificadas: Integer
    var
        rContenido: Record "Contenido Ubicacion SGA";
        enPicking: List of [Text];
        vistos: List of [Text];
        clave: Text;
        AlmacenObligatorioErr: Label 'Indique el almacén, o póngalo como almacén por defecto en la configuración de SGA.';
    begin
        if prm_Almacen = '' then
            Error(AlmacenObligatorioErr);

        // Una pasada por el contenido del almacén para saber qué está ya en picking, y otra por
        // lo que hay en almacenamiento: así no se consulta producto a producto.
        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetRange("Tipo Ubicacion", rContenido."Tipo Ubicacion"::Picking);
        rContenido.SetLoadFields("No. Producto", "Cod. Variante");
        if rContenido.FindSet() then
            repeat
                clave := ClaveProducto(rContenido."No. Producto", rContenido."Cod. Variante");
                if not enPicking.Contains(clave) then
                    enPicking.Add(clave);
            until rContenido.Next() = 0;

        rContenido.SetRange("Tipo Ubicacion", rContenido."Tipo Ubicacion"::Almacenamiento);
        rContenido.SetRange(Bloqueado, false);
        rContenido.SetFilter("Cantidad Disponible", '>%1', 0);
        if rContenido.FindSet() then
            repeat
                clave := ClaveProducto(rContenido."No. Producto", rContenido."Cod. Variante");
                if not enPicking.Contains(clave) and not vistos.Contains(clave) then begin
                    vistos.Add(clave);
                    if Planificar(prm_Almacen, rContenido."No. Producto", rContenido."Cod. Variante", '') then
                        planificadas += 1;
                end;
            until rContenido.Next() = 0;
    end;

    /// <summary>
    /// Después de recoger de prm_Ubicacion: si es de picking y se ha quedado sin el producto,
    /// planifica traerlo de almacenamiento, a la misma ubicación si la sigue admitiendo.
    /// </summary>
    procedure ReubicarSiSeVacia(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Variante: Code[10])
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        rUbicacionSGA.SetLoadFields("Tipo Ubicacion");
        if not rUbicacionSGA.Get(prm_Almacen, prm_Ubicacion) then
            exit;
        if rUbicacionSGA."Tipo Ubicacion" <> rUbicacionSGA."Tipo Ubicacion"::Picking then
            exit;

        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetRange("Cod. Bin", prm_Ubicacion);
        rContenido.SetRange("No. Producto", prm_Producto);
        rContenido.SetRange("Cod. Variante", prm_Variante);
        if not rContenido.IsEmpty() then
            exit;

        if Planificar(prm_Almacen, prm_Producto, prm_Variante, prm_Ubicacion) then;
    end;

    /// <summary>
    /// Planifica la reubicación de un producto si la necesita (ver el resumen del codeunit) y
    /// hay adónde llevarla. prm_Preferida es la ubicación de picking que se acaba de vaciar: se
    /// usa si la admite. Devuelve true si la ha planificado.
    /// </summary>
    local procedure Planificar(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Variante: Code[10]; prm_Preferida: Code[20]): Boolean
    var
        rContenido: Record "Contenido Ubicacion SGA";
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        cPicking: Codeunit "Gestion Picking SGA";
        destino: Code[20];
        cantidad: Decimal;
        motivo: Text;
    begin
        if ReubicacionPendiente(prm_Almacen, prm_Producto, prm_Variante) then
            exit(false);
        if HayEnPicking(prm_Almacen, prm_Producto, prm_Variante) then
            exit(false);
        if not BuscarOrigen(prm_Almacen, prm_Producto, prm_Variante, rContenido) then
            exit(false);

        // Un palé como mucho: es lo que cabe en un picking de un palé y lo que lleva un viaje.
        cantidad := rContenido."Cantidad Disponible";
        if cantidad > cUM.FactorPale(prm_Producto) then
            if cUM.UMPale(prm_Producto) <> '' then
                cantidad := cUM.FactorPale(prm_Producto);

        if prm_Preferida <> '' then
            if cUbicaciones.AdmiteEnTipo(prm_Almacen, prm_Preferida, "Tipo Ubicacion SGA"::Picking, prm_Producto, rContenido."No. Lote", cantidad) then
                destino := prm_Preferida;
        if destino = '' then
            destino := cUbicaciones.ProponerEnTipo("Tipo Ubicacion SGA"::Picking, "Estrategia Ubicacion SGA"::Estandar, '', prm_Almacen,
                                                   prm_Producto, prm_Variante, rContenido."No. Lote", rContenido."Cod. Unidad Medida", cantidad, motivo);
        if destino = '' then
            exit(false);

        cPicking.AnadirReubicacion(rContenido, cantidad, destino);
        exit(true);
    end;

    /// <summary>
    /// El contenido de almacenamiento que se trae: el primero con algo disponible en el orden
    /// de la estrategia de picking de la configuración.
    /// </summary>
    local procedure BuscarOrigen(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Variante: Code[10]; var prm_Contenido: Record "Contenido Ubicacion SGA"): Boolean
    var
        rConfig: Record "Config. SGA";
        cPicking: Codeunit "Gestion Picking SGA";
    begin
        rConfig.ObtenerConfig();
        prm_Contenido.Reset();
        prm_Contenido.SetRange("Cod. Almacen", prm_Almacen);
        prm_Contenido.SetRange("No. Producto", prm_Producto);
        prm_Contenido.SetRange("Cod. Variante", prm_Variante);
        prm_Contenido.SetRange(Bloqueado, false);
        prm_Contenido.SetFilter("Cantidad Disponible", '>%1', 0);
        prm_Contenido.SetRange("Tipo Ubicacion", prm_Contenido."Tipo Ubicacion"::Almacenamiento);
        cPicking.OrdenarPorEstrategia(prm_Contenido, rConfig."Estrategia Picking");
        exit(prm_Contenido.FindFirst());
    end;

    /// <summary>
    /// Si el producto tiene algo en alguna ubicación de picking del almacén, aunque esté
    /// reservado: entonces aún no se ha vaciado.
    /// </summary>
    local procedure HayEnPicking(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Variante: Code[10]): Boolean
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetRange("No. Producto", prm_Producto);
        rContenido.SetRange("Cod. Variante", prm_Variante);
        rContenido.SetRange("Tipo Ubicacion", rContenido."Tipo Ubicacion"::Picking);
        exit(not rContenido.IsEmpty());
    end;

    /// <summary>
    /// Si el producto ya tiene una reubicación sin terminar en el almacén.
    /// </summary>
    local procedure ReubicacionPendiente(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Variante: Code[10]): Boolean
    var
        rLinea: Record "Linea Orden Picking SGA";
    begin
        rLinea.SetCurrentKey("No. Producto", "No. Lote");
        rLinea.SetRange("No. Producto", prm_Producto);
        rLinea.SetRange("Cod. Variante", prm_Variante);
        rLinea.SetRange("Cod. Almacen", prm_Almacen);
        rLinea.SetFilter("Cod. Bin Destino", '<>%1', '');
        rLinea.FiltrarPendientes();
        exit(not rLinea.IsEmpty());
    end;

    local procedure ClaveProducto(prm_Producto: Code[20]; prm_Variante: Code[10]): Text
    begin
        exit(prm_Producto + '|' + prm_Variante);
    end;

    var
        cUM: Codeunit "Unidades Producto SGA";
}
