namespace AntonioNadal.SGA;

using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Warehouse.Structure;
using System.Text;

/// <summary>
/// Codeunit Gestion Ubicaciones SGA (ID 51101).
/// Se ocupa de los huecos:
///   - Topología sobre el Bin estándar: creación y sincronización, generación en masa,
///     recálculo de estados, formato del código pasillo-estantería-altura (componerlo y
///     trocearlo), cambios en bloque y recuentos por estado.
///   - Motor de propuesta: en qué hueco dejar un producto (primero almacenamiento, luego
///     picking), por qué no hay hueco y la ubicación guiada de un reparto.
///
/// OnRun borra un hueco entero (Rec): el Bin estándar, con el borrado de BC (que se lleva el
/// contenido de ubicación de BC y no deja borrar un hueco con stock o con documentos
/// pendientes), y con él su ficha SGA (BorrarFichaConBin). Existe para lanzarlo con
/// Codeunit.Run desde EliminarUbicaciones, un hueco por transacción: el que no se puede borrar
/// se queda entero y no tumba el resto.
/// </summary>
codeunit 51101 "Gestion Ubicaciones SGA"
{
    Access = Public;
    TableNo = Bin;

    trigger OnRun()
    begin
        Rec.Delete(true);
    end;

    /// <summary>
    /// Sincroniza la topología estándar (tabla Bin) con SGA, creando filas en
    /// "Ubicacion SGA" para los Bins que aún no las tienen.
    /// </summary>
    procedure SincronizarTopologia(prm_Almacen: Code[10])
    var
        rBin: Record Bin;
        rUbicacionSGA: Record "Ubicacion SGA";
        pasillo: Integer;
        estanteria: Integer;
        altura: Integer;
        secuencia: Integer;
    begin
        if prm_Almacen <> '' then
            rBin.SetRange("Location Code", prm_Almacen);

        if not rBin.FindSet() then
            exit;

        repeat
            if not rUbicacionSGA.Get(rBin."Location Code", rBin.Code) then begin
                // Con un código pasillo-estantería-altura, la ruta sale de él como al generarlas;
                // si no, queda a 0.
                secuencia := 0;
                if TrocearCodigo(rBin.Code, pasillo, estanteria, altura) then
                    secuencia := SecuenciaDesde(pasillo, estanteria, altura);
                NuevaUbicacionSGA(rUbicacionSGA, rBin."Location Code", rBin.Code, not rBin.Dedicated, secuencia);
                rUbicacionSGA.Insert();
            end;
        until rBin.Next() = 0;
    end;

    /// <summary>
    /// Recalcula el estado y el porcentaje de ocupación de las ubicaciones del almacén, o solo
    /// de una zona si prm_Zona no va en blanco. Devuelve cuántas filas ha actualizado.
    /// </summary>
    procedure RecalcularEstados(prm_Almacen: Code[10]; prm_Zona: Code[10]) actualizadas: Integer
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        estadoAnterior: Enum "Estado Ubicacion SGA";
        ocupacionAnterior: Decimal;
    begin
        if prm_Almacen <> '' then
            rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        if prm_Zona <> '' then
            rUbicacionSGA.SetRange("Cod. Zona SGA", prm_Zona);

        if not rUbicacionSGA.FindSet() then
            exit(0);

        repeat
            estadoAnterior := rUbicacionSGA."Estado SGA";
            ocupacionAnterior := rUbicacionSGA."% Ocupacion";

            rUbicacionSGA.RecalcularOcupacion();

            if (estadoAnterior <> rUbicacionSGA."Estado SGA") or (ocupacionAnterior <> rUbicacionSGA."% Ocupacion") then begin
                rUbicacionSGA.Modify();
                actualizadas += 1;
            end;
        until rUbicacionSGA.Next() = 0;
    end;

    /// <summary>
    /// Cambio en bloque de los datos de gestión de las ubicaciones de la selección (con sus
    /// filtros y marcas). Solo se toca lo marcado con prm_Cambiar*, con el valor de la plantilla,
    /// validado como en la ficha. Devuelve cuántas ubicaciones ha cambiado.
    /// Las que tienen contenido se saltan: su configuración solo se cambia vacías (TestVacia de
    /// la tabla). Cuántas se saltan sale en prm_Omitidas y las primeras (hasta 5) en prm_Ejemplos.
    /// </summary>
    procedure AplicarCambiosUbicaciones(var prm_Seleccion: Record "Ubicacion SGA"; var TempPlantilla: Record "Ubicacion SGA" temporary; prm_CambiarCapacidad: Boolean; prm_CambiarControlCapacidad: Boolean; prm_CambiarMezcla: Boolean; prm_CambiarTipo: Boolean; prm_CambiarZona: Boolean; var prm_Omitidas: Integer; var prm_Ejemplos: Text) hechas: Integer
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        NadaQueCambiarErr: Label 'No ha marcado nada que cambiar.';
    begin
        if not (prm_CambiarCapacidad or prm_CambiarControlCapacidad or prm_CambiarMezcla or prm_CambiarTipo or prm_CambiarZona) then
            Error(NadaQueCambiarErr);

        prm_Omitidas := 0;
        prm_Ejemplos := '';
        // Copy y no CopyFilters: la selección de la lista viaja en marcas.
        rUbicacionSGA.Copy(prm_Seleccion);
        if not rUbicacionSGA.FindSet(true) then
            exit(0);

        repeat
            if rUbicacionSGA.EstaVacia() then begin
                if prm_CambiarMezcla then
                    rUbicacionSGA.Validate("Permite Mezcla Producto", TempPlantilla."Permite Mezcla Producto");
                if prm_CambiarCapacidad then
                    rUbicacionSGA.Validate("Capacidad Uds.", TempPlantilla."Capacidad Uds.");
                if prm_CambiarControlCapacidad then
                    rUbicacionSGA.Validate("Control Capacidad", TempPlantilla."Control Capacidad");
                if prm_CambiarTipo then
                    rUbicacionSGA.Validate("Tipo Ubicacion", TempPlantilla."Tipo Ubicacion");
                if prm_CambiarZona then
                    // Con Validate hereda de la zona la secuencia si aún no la tiene.
                    rUbicacionSGA.Validate("Cod. Zona SGA", TempPlantilla."Cod. Zona SGA");
                // La ocupación la recalcula la validación de "Capacidad Uds."; vacía, nada más la cambia.
                rUbicacionSGA.Modify(true);
                hechas += 1;
            end else begin
                prm_Omitidas += 1;
                AnadirEjemplo(prm_Ejemplos, prm_Omitidas, rUbicacionSGA."Cod. Bin");
            end;
        until rUbicacionSGA.Next() = 0;
    end;

    /// <summary>
    /// Cuántas ubicaciones de la selección (con sus filtros y marcas) tienen contenido. Son las
    /// que un cambio en bloque se salta.
    /// </summary>
    procedure ContarConContenido(var prm_Seleccion: Record "Ubicacion SGA") conContenido: Integer
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        rUbicacionSGA.Copy(prm_Seleccion);
        if rUbicacionSGA.FindSet() then
            repeat
                if not rUbicacionSGA.EstaVacia() then
                    conContenido += 1;
            until rUbicacionSGA.Next() = 0;
    end;

    /// <summary>
    /// Resumen de ocupación de un almacén, o de una de sus zonas si prm_Zona no va en blanco:
    /// cuántas ubicaciones tiene y cuántas están vacías, llenas o bloqueadas (ella o su zona:
    /// el estado ya lo recoge).
    /// </summary>
    procedure ResumenUbicaciones(prm_Almacen: Code[10]; prm_Zona: Code[10]): Text
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        total: Integer;
        vacias: Integer;
        llenas: Integer;
        bloqueadas: Integer;
        ResumenLbl: Label '%1 ubicaciones: %2 vacías, %3 llenas, %4 bloqueadas.', Comment = '%1 = total, %2 = vacías, %3 = llenas, %4 = bloqueadas';
    begin
        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        if prm_Zona <> '' then
            rUbicacionSGA.SetRange("Cod. Zona SGA", prm_Zona);
        total := rUbicacionSGA.Count();
        rUbicacionSGA.SetRange("Estado SGA", rUbicacionSGA."Estado SGA"::Vacia);
        vacias := rUbicacionSGA.Count();
        rUbicacionSGA.SetRange("Estado SGA", rUbicacionSGA."Estado SGA"::Llena);
        llenas := rUbicacionSGA.Count();
        rUbicacionSGA.SetRange("Estado SGA", rUbicacionSGA."Estado SGA"::Bloqueada);
        bloqueadas := rUbicacionSGA.Count();

        exit(StrSubstNo(ResumenLbl, total, vacias, llenas, bloqueadas));
    end;

    /// <summary>
    /// Los traslados entre zonas no se hacen arrastrando en el mapa: error si el origen y el
    /// destino son de zonas distintas. Una ubicación sin zona solo casa con otra sin zona.
    /// </summary>
    procedure TestMismaZona(prm_Almacen: Code[10]; prm_Origen: Code[20]; prm_Destino: Code[20])
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        zonaOrigen: Code[10];
        zonaFinal: Code[10];
        OtraZonaErr: Label 'La ubicación %1 es de la zona "%2" y la %3 de la zona "%4". Los traslados entre zonas no se hacen desde el mapa: use Trasladar en Contenido de ubicaciones.', Comment = '%1 = origen, %2 = zona origen, %3 = destino, %4 = zona destino';
    begin
        zonaOrigen := rUbicacionSGA.ZonaDe(prm_Almacen, prm_Origen);
        zonaFinal := rUbicacionSGA.ZonaDe(prm_Almacen, prm_Destino);
        if zonaFinal <> zonaOrigen then
            Error(OtraZonaErr, prm_Origen, zonaOrigen, prm_Destino, zonaFinal);
    end;

    /// <summary>
    /// Borra todas las ubicaciones del almacén, ficha SGA y Bin, para montarlo de nuevo con
    /// GenerarUbicaciones. Se llama con el almacén ya vacío en SGA (Inicializar de Cod.
    /// "Gestion Contenido SGA"): una ficha con contenido no se deja borrar.
    ///
    /// Cada hueco se borra en su propia transacción (el OnRun de este codeunit), así que
    /// empieza confirmando con Commit lo que lleve hecho el llamante. El que BC no deja borrar
    /// (stock en almacén o documentos pendientes) se queda entero: cuántos en prm_NoEliminadas,
    /// los primeros (hasta 5) en prm_Ejemplos y el primer motivo en prm_Motivo.
    ///
    /// Al final quita de la configuración la ubicación de ajustes si ya no existe y borra las
    /// fichas SGA que se hubieran quedado sin Bin. Devuelve cuántas ubicaciones ha borrado.
    /// </summary>
    procedure EliminarUbicaciones(prm_Almacen: Code[10]; var prm_NoEliminadas: Integer; var prm_Ejemplos: Text; var prm_Motivo: Text) eliminadas: Integer
    var
        rBin: Record Bin;
        rUbicacionSGA: Record "Ubicacion SGA";
        rConfig: Record "Config. SGA";
        cVentana: Codeunit "Ventana Progreso SGA";
        codigos: List of [Code[20]];
        codBin: Code[20];
        AlmacenObligatorioErr: Label 'Indique el almacén.';
        EliminandoLbl: Label 'Eliminando ubicaciones';
    begin
        if prm_Almacen = '' then
            Error(AlmacenObligatorioErr);

        prm_NoEliminadas := 0;
        prm_Ejemplos := '';
        prm_Motivo := '';
        Commit();

        // Primero los códigos y luego el borrado: cada Codeunit.Run confirma su transacción y
        // no se borra sobre el mismo recorrido que se está leyendo.
        rBin.SetRange("Location Code", prm_Almacen);
        rBin.SetLoadFields(Code);
        if rBin.FindSet() then
            repeat
                codigos.Add(rBin.Code);
            until rBin.Next() = 0;

        cVentana.Abrir(EliminandoLbl, codigos.Count());
        foreach codBin in codigos do begin
            cVentana.Avanzar(codBin);
            rBin.Get(prm_Almacen, codBin);
            ClearLastError();
            if Codeunit.Run(Codeunit::"Gestion Ubicaciones SGA", rBin) then
                eliminadas += 1
            else begin
                prm_NoEliminadas += 1;
                if prm_Motivo = '' then
                    prm_Motivo := GetLastErrorText();
                AnadirEjemplo(prm_Ejemplos, prm_NoEliminadas, codBin);
            end;
        end;
        cVentana.Cerrar();

        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        if rUbicacionSGA.FindSet() then
            repeat
                if not UbicacionExiste(prm_Almacen, rUbicacionSGA."Cod. Bin") then
                    rUbicacionSGA.Delete(true);
            until rUbicacionSGA.Next() = 0;

        if rConfig.Get() and (rConfig."Almacen por Defecto" = prm_Almacen) then
            if not UbicacionExiste(prm_Almacen, rConfig."Ubic. Ajustes") then begin
                rConfig."Ubic. Ajustes" := '';
                rConfig.Modify();
            end;
    end;

    /// <summary>
    /// Genera ubicaciones en masa recorriendo los rangos de pasillo, estantería y altura, con
    /// las alturas que da AlturasDelRango (00, 10, 20…).
    /// Crea el Bin estándar si no existe y su fila de datos SGA, en ese orden.
    /// Es idempotente: lo que ya existe no se toca, así que se puede reejecutar para ampliar.
    /// Las posiciones de un fondo de pasillo se saltan, porque no tienen alturas: cuántas, en
    /// prm_EnFondo.
    /// </summary>
    procedure GenerarUbicaciones(prm_Almacen: Code[10]; prm_PasilloDesde: Integer; prm_PasilloHasta: Integer; prm_EstanteriaDesde: Integer; prm_EstanteriaHasta: Integer; prm_AlturaDesde: Integer; prm_AlturaHasta: Integer; prm_Zona: Code[10]; prm_Tipo: Enum "Tipo Ubicacion SGA"; prm_Capacidad: Decimal; var prm_EnFondo: Integer) creadas: Integer
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        rZona: Record "Zona SGA";
        alturas: List of [Integer];
        pasillo: Integer;
        estanteria: Integer;
        altura: Integer;
        codBin: Code[20];
    begin
        rZona.ComprobarAdmiteUbicaciones(prm_Almacen, prm_Zona);
        prm_EnFondo := 0;
        alturas := AlturasDelRango(prm_AlturaDesde, prm_AlturaHasta);
        for pasillo := prm_PasilloDesde to prm_PasilloHasta do
            for estanteria := prm_EstanteriaDesde to prm_EstanteriaHasta do
                foreach altura in alturas do begin
                    codBin := ComponerCodigoUbicacion(pasillo, estanteria, altura);

                    // La posición de un fondo de pasillo no tiene alturas: se salta.
                    if FondoEnPosicion(prm_Almacen, codBin) <> '' then
                        prm_EnFondo += 1
                    else begin
                        CrearBinSiFalta(prm_Almacen, codBin);

                        if not rUbicacionSGA.Get(prm_Almacen, codBin) then begin
                            // Nacen de un solo producto, como un hueco de palé. Las estanterías de
                            // picking con varias referencias se marcan después.
                            NuevaUbicacionSGA(rUbicacionSGA, prm_Almacen, codBin, false, SecuenciaDesde(pasillo, estanteria, altura));
                            rUbicacionSGA."Cod. Zona SGA" := prm_Zona;
                            rUbicacionSGA."Tipo Ubicacion" := prm_Tipo;
                            rUbicacionSGA."Capacidad Uds." := prm_Capacidad;
                            rUbicacionSGA.Insert();
                            creadas += 1;
                        end;
                    end;
                end;
    end;

    /// <summary>
    /// Al insertar una ubicación SGA (OnInsert de la tabla): crea su Bin si aún no existe, que
    /// es el caso del alta a mano, y le pone la secuencia de picking (la del código
    /// pasillo-estantería-altura si va a 0).
    /// </summary>
    procedure CompletarAlta(var prm_Ubicacion: Record "Ubicacion SGA")
    var
        pasillo: Integer;
        estanteria: Integer;
        altura: Integer;
    begin
        if prm_Ubicacion."Secuencia Picking" = 0 then
            if TrocearCodigo(prm_Ubicacion."Cod. Bin", pasillo, estanteria, altura) then
                prm_Ubicacion."Secuencia Picking" := SecuenciaDesde(pasillo, estanteria, altura);
        CrearBinSiFalta(prm_Ubicacion."Cod. Almacen", prm_Ubicacion."Cod. Bin");
    end;

    /// <summary>
    /// Crea la ubicación estándar de BC si no existe, con el código como descripción. La
    /// descripción es solo la del Bin: la ficha SGA la enseña (Descripcion es un FlowField).
    /// </summary>
    local procedure CrearBinSiFalta(prm_Almacen: Code[10]; prm_Bin: Code[20])
    var
        rBin: Record Bin;
    begin
        if rBin.Get(prm_Almacen, prm_Bin) then
            exit;
        rBin.Init();
        rBin."Location Code" := prm_Almacen;
        rBin.Code := prm_Bin;
        rBin.Description := prm_Bin;
        rBin.Insert(true);
    end;

    /// <summary>
    /// Alturas que se numeran en cada estantería: de 10 en 10 desde prm_Desde sin pasar de
    /// prm_Hasta (de 00 a 30: 00, 10, 20 y 30).
    /// </summary>
    procedure AlturasDelRango(prm_Desde: Integer; prm_Hasta: Integer) alturas: List of [Integer]
    var
        altura: Integer;
    begin
        altura := prm_Desde;
        while altura <= prm_Hasta do begin
            alturas.Add(altura);
            altura += 10;
        end;
    end;

    /// <summary>
    /// Compone el código de ubicación con el formato pasillo-estantería-altura (101-15-03): el
    /// pasillo a tres dígitos y la estantería y la altura a dos, con ceros a la izquierda. Es el
    /// único sitio que conoce el formato al componerlo; TrocearCodigo hace lo contrario.
    /// </summary>
    procedure ComponerCodigoUbicacion(prm_Pasillo: Integer; prm_Estanteria: Integer; prm_Altura: Integer): Code[20]
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        exit(CopyStr(ConCeros(prm_Pasillo, 3) + '-' + ConCeros(prm_Estanteria, 2) + '-' + ConCeros(prm_Altura, 2),
                     1, MaxStrLen(rUbicacionSGA."Cod. Bin")));
    end;

    /// <summary>
    /// Parte un código pasillo-estantería-altura (p. ej. 101-05-02). Devuelve false si el código
    /// no sigue el formato (tres partes numéricas de tres, dos y dos dígitos), para que el
    /// llamante lo descarte en lugar de colocarlo en una posición falsa.
    /// </summary>
    procedure TrocearCodigo(prm_Codigo: Code[20]; var prm_Pasillo: Integer; var prm_Estanteria: Integer; var prm_Altura: Integer): Boolean
    var
        partes: List of [Text];
        texto: Text;
    begin
        texto := prm_Codigo;
        partes := texto.Split('-');
        if partes.Count() <> 3 then
            exit(false);

        exit(LeerParte(partes.Get(1), 3, prm_Pasillo) and
             LeerParte(partes.Get(2), 2, prm_Estanteria) and
             LeerParte(partes.Get(3), 2, prm_Altura));
    end;

    /// <summary>
    /// Para marcar una ubicación como fondo de pasillo: su código tiene que ser
    /// pasillo-estantería-altura (para dibujarla en el mapa y saber cuál es su posición) y en
    /// esa posición no puede haber otra ubicación, porque un fondo no tiene alturas.
    /// </summary>
    procedure ComprobarPuedeSerFondo(prm_Almacen: Code[10]; prm_Bin: Code[20])
    var
        rBin: Record Bin;
        filtro: Text;
        FondoSinFormatoErr: Label 'Para ser fondo de pasillo, el código de la ubicación %1 tiene que ser pasillo-estantería-altura (por ejemplo 101-31-01).', Comment = '%1 = ubicación';
        FondoConAlturasErr: Label 'La posición de %1 ya tiene otra ubicación (%2). Un fondo de pasillo no tiene alturas: bórrela antes de marcarlo.', Comment = '%1 = ubicación, %2 = otra ubicación de la misma posición';
    begin
        if not FiltroOtrasDePosicion(prm_Bin, filtro) then
            Error(FondoSinFormatoErr, prm_Bin);
        rBin.SetRange("Location Code", prm_Almacen);
        rBin.SetFilter(Code, filtro);
        rBin.SetLoadFields(Code);
        if rBin.FindFirst() then
            Error(FondoConAlturasErr, prm_Bin, rBin.Code);
    end;

    /// <summary>
    /// El fondo de pasillo que ocupa la posición (pasillo y estantería) del código prm_Bin, sin
    /// contar el propio prm_Bin. En blanco si no hay o si el código no sigue el formato.
    /// </summary>
    procedure FondoEnPosicion(prm_Almacen: Code[10]; prm_Bin: Code[20]): Code[20]
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        filtro: Text;
    begin
        if not FiltroOtrasDePosicion(prm_Bin, filtro) then
            exit('');
        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        rUbicacionSGA.SetRange(Fondo, true);
        rUbicacionSGA.SetFilter("Cod. Bin", filtro);
        rUbicacionSGA.SetLoadFields("Cod. Bin");
        if rUbicacionSGA.FindFirst() then
            exit(rUbicacionSGA."Cod. Bin");
    end;

    /// <summary>
    /// Filtro de las demás ubicaciones de la misma posición que prm_Bin (101-31-* menos ella).
    /// False si el código no es pasillo-estantería-altura. El código validado solo lleva cifras
    /// y guiones, así que no trae caracteres de filtro.
    /// </summary>
    local procedure FiltroOtrasDePosicion(prm_Bin: Code[20]; var prm_Filtro: Text): Boolean
    var
        pasillo: Integer;
        estanteria: Integer;
        altura: Integer;
    begin
        if not TrocearCodigo(prm_Bin, pasillo, estanteria, altura) then
            exit(false);
        prm_Filtro := ConCeros(pasillo, 3) + '-' + ConCeros(estanteria, 2) + '-*&<>' + prm_Bin;
        exit(true);
    end;

    /// <summary>
    /// Ninguna ubicación nueva, se cree desde donde se cree, puede caer en la posición de un
    /// fondo de pasillo.
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::Bin, OnBeforeInsertEvent, '', false, false)]
    local procedure NoCrearEnPosicionFondo(var Rec: Record Bin)
    var
        fondo: Code[20];
        PosicionDeFondoErr: Label 'No se puede crear la ubicación %1: su posición es la del fondo de pasillo %2, que no tiene alturas.', Comment = '%1 = ubicación nueva, %2 = fondo de pasillo';
    begin
        if Rec.IsTemporary() then
            exit;
        fondo := FondoEnPosicion(Rec."Location Code", Rec.Code);
        if fondo <> '' then
            Error(PosicionDeFondoErr, Rec.Code, fondo);
    end;

    /// <summary>
    /// Una ubicación es su Bin más su ficha SGA: se borran juntos, se borre por donde se borre.
    /// Al borrar el Bin (desde BC estándar o desde SGA) se borra su ficha, que no deja si tiene
    /// contenido y lo deshace todo.
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::Bin, OnAfterDeleteEvent, '', false, false)]
    local procedure BorrarFichaConBin(var Rec: Record Bin)
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        if Rec.IsTemporary() then
            exit;
        if rUbicacionSGA.Get(Rec."Location Code", Rec.Code) then
            rUbicacionSGA.Delete(true);
    end;

    /// <summary>
    /// Al borrar la ficha SGA (con sus triggers) se borra su Bin, con las comprobaciones del
    /// estándar (stock de BC en la ubicación…), que paran el borrado de los dos.
    /// </summary>
    [EventSubscriber(ObjectType::Table, Database::"Ubicacion SGA", OnAfterDeleteEvent, '', false, false)]
    local procedure BorrarBinConFicha(var Rec: Record "Ubicacion SGA"; RunTrigger: Boolean)
    var
        rBin: Record Bin;
    begin
        if Rec.IsTemporary() or not RunTrigger then
            exit;
        if rBin.Get(Rec."Cod. Almacen", Rec."Cod. Bin") then
            rBin.Delete(true);
    end;

    /// <summary>
    /// Error si el código no es pasillo-estantería-altura con los rangos de Generar ubicaciones:
    /// pasillo de 001 a 999, estantería de 01 a 99 y altura de 00 a 99.
    /// </summary>
    procedure ComprobarCodigoUbicacion(prm_Codigo: Code[20])
    var
        pasillo: Integer;
        estanteria: Integer;
        altura: Integer;
        CodigoUbicacionErr: Label 'El código %1 no es válido. Tiene que ser pasillo-estantería-altura: pasillo de 001 a 999, estantería de 01 a 99 y altura de 00 a 99 (por ejemplo 101-15-10).', Comment = '%1 = código tecleado';
    begin
        if not TrocearCodigo(prm_Codigo, pasillo, estanteria, altura) then
            Error(CodigoUbicacionErr, prm_Codigo);
        if (pasillo < 1) or (estanteria < 1) then
            Error(CodigoUbicacionErr, prm_Codigo);
    end;

    /// <summary>
    /// Una parte del código: exactamente prm_Digitos cifras.
    /// </summary>
    local procedure LeerParte(prm_Parte: Text; prm_Digitos: Integer; var prm_Valor: Integer): Boolean
    begin
        if StrLen(prm_Parte) <> prm_Digitos then
            exit(false);
        if DelChr(prm_Parte, '=', '0123456789') <> '' then
            exit(false);
        exit(Evaluate(prm_Valor, prm_Parte));
    end;

    /// <summary>
    /// Formatea un entero a prm_Digitos cifras con ceros a la izquierda, con el formato
    /// estándar de la plataforma (Integer,N con Filler Character 0).
    /// </summary>
    procedure ConCeros(prm_Valor: Integer; prm_Digitos: Integer): Text
    var
        FormatoCerosTok: Label '<Integer,%1><Filler Character,0>', Locked = true, Comment = '%1 = nº de cifras';
    begin
        exit(Format(prm_Valor, 0, StrSubstNo(FormatoCerosTok, prm_Digitos)));
    end;

    /// <summary>
    /// Añade un código a la lista de ejemplos de un aviso, separados por coma, hasta 5: prm_Cuantas
    /// es cuántas van ya contando esta.
    /// </summary>
    local procedure AnadirEjemplo(var prm_Ejemplos: Text; prm_Cuantas: Integer; prm_Codigo: Code[20])
    begin
        if prm_Cuantas > 5 then
            exit;
        if prm_Ejemplos <> '' then
            prm_Ejemplos += ', ';
        prm_Ejemplos += prm_Codigo;
    end;

    /// <summary>
    /// Deja preparada, sin insertar, la ficha SGA de una ubicación nueva, que admite mezcla de
    /// lotes. Quien llama completa el resto e inserta.
    /// </summary>
    local procedure NuevaUbicacionSGA(var prm_Ubicacion: Record "Ubicacion SGA"; prm_Almacen: Code[10]; prm_Bin: Code[20]; prm_PermiteMezclaProducto: Boolean; prm_Secuencia: Integer)
    begin
        prm_Ubicacion.Init();
        prm_Ubicacion."Cod. Almacen" := prm_Almacen;
        prm_Ubicacion."Cod. Bin" := prm_Bin;
        prm_Ubicacion."Permite Mezcla Producto" := prm_PermiteMezclaProducto;
        prm_Ubicacion."Secuencia Picking" := prm_Secuencia;
    end;

    /// <summary>
    /// Orden de recorrido físico: primero el pasillo, luego la estantería y luego la altura.
    /// </summary>
    local procedure SecuenciaDesde(prm_Pasillo: Integer; prm_Estanteria: Integer; prm_Altura: Integer): Integer
    begin
        exit(prm_Pasillo * 10000 + prm_Estanteria * 100 + prm_Altura);
    end;

    /// <summary>
    /// Única puerta para proponer en qué ubicación dejar un producto. Busca primero en las de
    /// almacenamiento y, si ninguna sirve, en las de picking; dentro de cada tipo, con la
    /// estrategia que elige quien llama (normalmente la que diga "Config. SGA" para su caso).
    /// Las ubicaciones sin tipo no se proponen. Devuelve '' si no hay ninguna que lo admita.
    ///
    /// En prm_Motivo sale el porqué: con hueco, el tipo y si le mandan a la casa del producto, a
    /// consolidar o a un hueco libre; sin hueco, la causa y qué hacer (ExplicarSinHuecoLote).
    ///
    /// prm_Excluidas es un filtro de AL ya montado sobre "Cod. Bin" (por ejemplo
    /// '&lt;&gt;101-01-01&amp;&lt;&gt;101-02-01', ver AnadirExclusion). Sirve para dos cosas: que el
    /// operario pueda pedir "otra ubicación" descartando la que se le acaba de ofrecer, y que al
    /// proponer en bloque no se asigne el mismo hueco vacío a dos cosas distintas.
    /// </summary>
    procedure ProponerUbicacionCon(prm_Estrategia: Enum "Estrategia Ubicacion SGA"; prm_Excluidas: Text; prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; var prm_Motivo: Text): Code[20]
    var
        codigo: Code[20];
        entrada: Decimal;
        SinHuecoVacioTxt: Label 'No queda ningún hueco vacío que admita %1. La estrategia de esta entrada ("Solo hueco vacío") no usa huecos a medias: libere un hueco o cambie la estrategia en la configuración.', Comment = '%1 = producto';
        SinUbicacionFijaTxt: Label '%1 no tiene ubicación fija con sitio ("Producto fijo" en la ubicación o "Nº estantería" en la ficha). La estrategia de esta entrada ("Solo ubicación fija") no busca en otras.', Comment = '%1 = producto';
    begin
        prm_Motivo := '';
        // Lo que ocupa la cantidad, en palés, depende solo del producto: se calcula una vez y
        // no en cada ubicación que se mira.
        entrada := EntradaEnPales(prm_Producto, prm_UM, prm_Cantidad);
        PickingCompleto := PickingDelProductoCompleto(prm_Almacen, prm_Producto);

        codigo := ProponerPorTipos(prm_Estrategia, prm_Excluidas, prm_Almacen, prm_Producto, prm_Lote, entrada, prm_Motivo);

        // Sin hueco, el porqué depende de la estrategia: las que solo miran una clase de hueco
        // dicen eso, no el recuento general (que contaría como válidos huecos que no buscan).
        if codigo = '' then
            case prm_Estrategia of
                prm_Estrategia::"Solo Hueco Vacio":
                    prm_Motivo := StrSubstNo(SinHuecoVacioTxt, prm_Producto);
                prm_Estrategia::"Solo Ubicacion Fija":
                    prm_Motivo := StrSubstNo(SinUbicacionFijaTxt, prm_Producto);
                else
                    prm_Motivo := ExplicarSinHuecoLote(prm_Almacen, prm_Producto, prm_Lote, prm_UM, prm_Cantidad, false);
            end;

        exit(codigo);
    end;

    /// <summary>
    /// La búsqueda por tipos de ProponerUbicacionCon: un tipo y, si no hay hueco, el otro, en el
    /// orden de TipoPorOrden (almacenamiento primero, o picking con FijarPickingPrimero); o solo
    /// picking con ProponerEnPicking. Sin hueco devuelve '' sin explicar el porqué.
    /// </summary>
    local procedure ProponerPorTipos(prm_Estrategia: Enum "Estrategia Ubicacion SGA"; prm_Excluidas: Text; prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50]; entrada: Decimal; var prm_Motivo: Text) codigo: Code[20]
    var
        PrimerTipoTxt: Label '%1. %2', Comment = '%1 = tipo de ubicación, %2 = por qué ese hueco';
        SegundoTipoTxt: Label '%1: no queda sitio en %2. %3', Comment = '%1 = tipo de ubicación elegido, %2 = tipo en el que no quedaba sitio, %3 = por qué ese hueco';
    begin
        if TipoForzado <> TipoForzado::" " then
            codigo := ProponerDeTipo(TipoForzado, prm_Estrategia, prm_Excluidas, prm_Almacen, prm_Producto, prm_Lote, entrada, prm_Motivo)
        else begin
            codigo := ProponerDeTipo(TipoPorOrden(1), prm_Estrategia, prm_Excluidas, prm_Almacen, prm_Producto, prm_Lote, entrada, prm_Motivo);
            if codigo <> '' then
                prm_Motivo := StrSubstNo(PrimerTipoTxt, TipoPorOrden(1), prm_Motivo)
            else begin
                codigo := ProponerDeTipo(TipoPorOrden(2), prm_Estrategia, prm_Excluidas, prm_Almacen, prm_Producto, prm_Lote, entrada, prm_Motivo);
                if codigo <> '' then
                    prm_Motivo := StrSubstNo(SegundoTipoTxt, TipoPorOrden(2), LowerCase(Format(TipoPorOrden(1))), prm_Motivo);
            end;
        end;
    end;

    /// <summary>
    /// Con true, las propuestas de esta instancia buscan primero en picking y luego en
    /// almacenamiento (carga inicial: llenar antes los huecos de picking). prm_MaxPickingProducto
    /// limita cuántas ubicaciones de picking puede ocupar cada producto, para que picking no se
    /// llene de palés de uno solo: alcanzado el límite, solo se le propone picking donde ya está
    /// o en sus huecos reservados, y lo demás va a almacenamiento. 0, sin límite. Se fija antes
    /// de la primera propuesta y dura lo que la instancia.
    /// </summary>
    procedure FijarPickingPrimero(prm_PickingPrimero: Boolean; prm_MaxPickingProducto: Integer)
    begin
        PickingPrimero := prm_PickingPrimero;
        MaxPickingProducto := prm_MaxPickingProducto;
    end;

    /// <summary>
    /// Si el producto ya ocupa en el almacén tantas ubicaciones de picking como permite
    /// FijarPickingPrimero. Se calcula una vez por propuesta, no por hueco mirado.
    /// </summary>
    local procedure PickingDelProductoCompleto(prm_Almacen: Code[10]; prm_Producto: Code[20]): Boolean
    var
        rContenido: Record "Contenido Ubicacion SGA";
        huecos: List of [Code[20]];
    begin
        if MaxPickingProducto <= 0 then
            exit(false);
        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetRange("No. Producto", prm_Producto);
        rContenido.SetRange("Tipo Ubicacion", rContenido."Tipo Ubicacion"::Picking);
        rContenido.SetLoadFields("Cod. Bin");
        if rContenido.FindSet() then
            repeat
                if not huecos.Contains(rContenido."Cod. Bin") then
                    huecos.Add(rContenido."Cod. Bin");
            until rContenido.Next() = 0;
        exit(huecos.Count() >= MaxPickingProducto);
    end;

    /// <summary>
    /// Si el producto ya está en la ubicación: con el picking del producto completo, es la única
    /// ubicación de picking (aparte de las reservadas) que se le puede proponer.
    /// </summary>
    local procedure ProductoEnUbicacion(var prm_Ubicacion: Record "Ubicacion SGA"; prm_Producto: Code[20]): Boolean
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        rContenido.FiltrarUbicacion(prm_Ubicacion."Cod. Almacen", prm_Ubicacion."Cod. Bin");
        rContenido.SetRange("No. Producto", prm_Producto);
        exit(not rContenido.IsEmpty());
    end;

    /// <summary>
    /// ProponerUbicacionCon limitado a las ubicaciones de picking, con la estrategia estándar y
    /// sin exclusiones. Es la de las reubicaciones. Sin hueco devuelve '' y en prm_Motivo el
    /// porqué, contado sobre las de picking.
    /// </summary>
    procedure ProponerEnPicking(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; var prm_Motivo: Text): Code[20]
    var
        codigo: Code[20];
    begin
        TipoForzado := TipoForzado::Picking;
        codigo := ProponerUbicacionCon("Estrategia Ubicacion SGA"::Estandar, '', prm_Almacen, prm_Producto, prm_Lote, prm_UM, prm_Cantidad, prm_Motivo);
        TipoForzado := TipoForzado::" ";
        exit(codigo);
    end;

    /// <summary>
    /// Si la ubicación prm_Ubicacion, que tiene que ser de picking, puede recibir
    /// prm_CantidadBase del producto con las mismas reglas que la propuesta (MotivoRechazo).
    /// </summary>
    procedure AdmiteEnPicking(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_CantidadBase: Decimal): Boolean
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        if not rUbicacionSGA.Get(prm_Almacen, prm_Ubicacion) then
            exit(false);
        exit(UbicacionAdmite(rUbicacionSGA, prm_Producto, prm_Lote, rUbicacionSGA."Tipo Ubicacion"::Picking, cUM.EnPales(prm_Producto, prm_CantidadBase)));
    end;

    /// <summary>
    /// La estrategia dentro de las ubicaciones de un tipo. prm_Entrada es lo que ocupa la
    /// cantidad, en palés. Con hueco, prm_Motivo dice cómo se ha elegido.
    /// </summary>
    local procedure ProponerDeTipo(prm_Tipo: Enum "Tipo Ubicacion SGA"; prm_Estrategia: Enum "Estrategia Ubicacion SGA"; prm_Excluidas: Text; prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_Entrada: Decimal; var prm_Motivo: Text) codigo: Code[20]
    var
        MotivoFijaTxt: Label 'Ubicación fija del producto.';
        MotivoConsolidacionTxt: Label 'Ya hay este producto ahí: se consolida.';
        MotivoPrimeraLibreTxt: Label 'Primer hueco con sitio en el orden de recorrido (pasillo, hueco y nivel, según la "Secuencia picking" de cada ubicación).';
        MotivoPrimeraVaciaTxt: Label 'Primer hueco vacío en el orden de recorrido (pasillo, hueco y nivel, según la "Secuencia picking" de cada ubicación).';
    begin
        prm_Motivo := '';
        case prm_Estrategia of
            prm_Estrategia::"Solo Ubicacion Fija":
                begin
                    codigo := BuscarFija(prm_Almacen, prm_Producto, prm_Lote, prm_Tipo, prm_Entrada, prm_Excluidas);
                    if codigo <> '' then
                        prm_Motivo := MotivoFijaTxt;
                end;
            prm_Estrategia::"Solo Hueco Vacio":
                begin
                    codigo := BuscarVacia(prm_Almacen, prm_Producto, prm_Lote, prm_Tipo, prm_Entrada, prm_Excluidas);
                    if codigo <> '' then
                        prm_Motivo := MotivoPrimeraVaciaTxt;
                end;
            prm_Estrategia::"Primera Libre por Ruta":
                begin
                    codigo := BuscarLibre(prm_Almacen, prm_Producto, prm_Lote, prm_Tipo, prm_Entrada, prm_Excluidas);
                    if codigo <> '' then
                        prm_Motivo := MotivoPrimeraLibreTxt;
                end;
            else begin
                // Estándar: su casa, si no consolidar, si no el primer hueco por ruta.
                // Priorizar consolidación: lo mismo sin mirar su casa.
                if prm_Estrategia <> prm_Estrategia::"Priorizar Consolidacion" then begin
                    codigo := BuscarFija(prm_Almacen, prm_Producto, prm_Lote, prm_Tipo, prm_Entrada, prm_Excluidas);
                    if codigo <> '' then begin
                        prm_Motivo := MotivoFijaTxt;
                        exit;
                    end;
                end;
                codigo := BuscarConsolidacion(prm_Almacen, prm_Producto, prm_Lote, prm_Tipo, prm_Entrada, prm_Excluidas);
                if codigo <> '' then begin
                    prm_Motivo := MotivoConsolidacionTxt;
                    exit;
                end;
                codigo := BuscarLibre(prm_Almacen, prm_Producto, prm_Lote, prm_Tipo, prm_Entrada, prm_Excluidas);
                if codigo <> '' then
                    prm_Motivo := MotivoPrimeraLibreTxt;
            end;
        end;
    end;

    /// <summary>
    /// Ubicación guiada ("Ubicar producto"): reparte la cantidad en palés y un resto
    /// (Repartir de "Unidades Producto SGA", con el palé de la ficha) y propone un hueco para
    /// cada trozo, en orden y sin dar el mismo hueco a dos. Las líneas quedan Pendiente con el
    /// hueco propuesto también como confirmado, o "Sin Sitio" con el motivo. Como mucho
    /// MaxLineasReparto líneas, para que una unidad mal configurada no genere miles: lo que
    /// no entra no se propone y queda en "Pendiente de ubicar".
    /// </summary>
    procedure ProponerReparto(prm_Estrategia: Enum "Estrategia Ubicacion SGA"; prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_CantidadBase: Decimal; var TempLinea: Record "Linea Ubicacion SGA" temporary)
    var
        excluidas: Text;
        motivo: Text;
        hueco: Code[20];
        MaxLineasReparto: Integer;
    begin
        MaxLineasReparto := 200;
        // El tope corta el reparto al crearlo, por si una cantidad desorbitada o una unidad mal
        // configurada diera miles de palés.
        cUM.Repartir(prm_Producto, prm_CantidadBase, '', MaxLineasReparto, TempLinea);

        // Por la clave (Linea): las exclusiones se acumulan en el orden del reparto.
        if TempLinea.FindSet() then
            repeat
                hueco := ProponerUbicacionCon(prm_Estrategia, excluidas, prm_Almacen, prm_Producto, prm_Lote,
                                              TempLinea."Cod. Unidad Medida", TempLinea.Cantidad, motivo);
                TempLinea.Origen := TempLinea.Origen::Manual;
                TempLinea."Cod. Almacen" := prm_Almacen;
                TempLinea."No. Lote" := prm_Lote;
                TempLinea."Ubicacion Propuesta" := hueco;
                TempLinea."Ubicacion Confirmada" := hueco;
                // Sin hueco, el motivo ya trae la causa.
                if hueco = '' then
                    TempLinea.Estado := TempLinea.Estado::"Sin Sitio"
                else begin
                    TempLinea.Estado := TempLinea.Estado::Pendiente;
                    excluidas := AnadirExclusion(excluidas, hueco);
                end;
                TempLinea.Motivo := CopyStr(motivo, 1, MaxStrLen(TempLinea.Motivo));
                TempLinea.Modify();
            until TempLinea.Next() = 0;
        TempLinea.Reset();
    end;

    /// <summary>
    /// Registra las líneas de un reparto de ProponerReparto: todas las que tengan ubicación
    /// confirmada y no estén ya ubicadas (prm_Linea = 0), o solo esa línea. Primero comprueba
    /// todas y luego registra, para no dejar el reparto a medias por un error en una línea.
    /// Aplica "Exigir confirmar ubicación" y "Permitir desvío ubicación" de la configuración.
    /// Cada línea entra con el SSCC leído de su palé o, si no se ha leído, con uno nuevo.
    /// Devuelve lo que queda sin ubicar del reparto, en unidad base.
    /// </summary>
    procedure ConfirmarReparto(var TempLinea: Record "Linea Ubicacion SGA" temporary; prm_Linea: Integer; prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50]): Decimal
    var
        rConfig: Record "Config. SGA";
        cContenido: Codeunit "Gestion Contenido SGA";
        lineas: List of [Integer];
        ssccs: List of [Code[20]];
        sscc: Code[20];
        n: Integer;
        i: Integer;
        restoBase: Decimal;
        SinLineasConfirmarErr: Label 'No hay ninguna línea con ubicación que confirmar.';
        IndiqueUbicacionErr: Label 'Indique la ubicación de la línea "%1".', Comment = '%1 = qué';
        DesvioNoPermitidoErr: Label 'La configuración no permite desviarse de la ubicación propuesta (%1) en la línea "%2".', Comment = '%1 = ubicación, %2 = qué';
        SinLecturaErr: Label 'Escanee la etiqueta de la ubicación en la que deja la línea "%1": la configuración exige confirmar la ubicación.', Comment = '%1 = qué';
        LecturaDistintaErr: Label 'Se ha leído la ubicación %1, pero la línea "%3" se deja en %2. Lleve la mercancía a %2 y escanee su etiqueta, o cambie la ubicación.', Comment = '%1 = ubicación leída, %2 = ubicación de la línea, %3 = qué';
        UbicadoGuiadoLbl: Label 'Ubicado desde la pantalla de ubicación guiada.';
    begin
        rConfig.ObtenerConfig();

        TempLinea.Reset();
        if prm_Linea <> 0 then
            TempLinea.SetRange(Linea, prm_Linea);
        TempLinea.SetFilter(Estado, '<>%1', TempLinea.Estado::Ubicado);
        if TempLinea.FindSet() then
            repeat
                if TempLinea."Ubicacion Confirmada" = '' then begin
                    // Confirmando todo, lo que no tiene sitio se salta; una línea sola, no.
                    if prm_Linea <> 0 then
                        Error(IndiqueUbicacionErr, TempLinea.Paso);
                end else begin
                    ComprobarUbicacionExiste(prm_Almacen, TempLinea."Ubicacion Confirmada");
                    // Exigir confirmar: la etiqueta del hueco tiene que estar leída y ser la de
                    // la ubicación en la que se deja, para certificar que se ha llevado ahí.
                    if rConfig."Exigir Confirmar Ubicacion" then begin
                        if TempLinea."Ubicacion Leida" = '' then
                            Error(SinLecturaErr, TempLinea.Paso);
                        if TempLinea."Ubicacion Leida" <> TempLinea."Ubicacion Confirmada" then
                            Error(LecturaDistintaErr, TempLinea."Ubicacion Leida", TempLinea."Ubicacion Confirmada", TempLinea.Paso);
                    end;
                    if TempLinea."Ubicacion Propuesta" <> '' then
                        if not rConfig.DesvioPermitido(TempLinea."Ubicacion Propuesta", TempLinea."Ubicacion Confirmada") then
                            Error(DesvioNoPermitidoErr, TempLinea."Ubicacion Propuesta", TempLinea.Paso);
                    lineas.Add(TempLinea.Linea);
                end;
            until TempLinea.Next() = 0;

        if lineas.Count() = 0 then
            Error(SinLineasConfirmarErr);

        // Primero se registran todas y después se marcan: la tabla de la pantalla es temporal y
        // no se deshace con un error, así que si una falla no debe quedar ninguna como ubicada.
        TempLinea.Reset();
        foreach n in lineas do begin
            TempLinea.Get(n);
            // El palé sin etiqueta recibe un SSCC nuevo; se guarda en sscc y se pone al final
            // (SSCCPale lo deja en la variable, no en la tabla).
            sscc := TempLinea.SSCCPale();
            ssccs.Add(sscc);
            cContenido.RegistrarEntrada(prm_Almacen, TempLinea."Ubicacion Confirmada", prm_Producto, prm_Lote,
                                        sscc, TempLinea."Cod. Unidad Medida", TempLinea.Cantidad, "Origen Mov. SGA"::Manual, '', UbicadoGuiadoLbl);
        end;
        for i := 1 to lineas.Count() do begin
            TempLinea.Get(lineas.Get(i));
            TempLinea.SSCC := ssccs.Get(i);
            TempLinea.Estado := TempLinea.Estado::Ubicado;
            TempLinea.Motivo := '';
            TempLinea.Modify();
        end;

        TempLinea.SetFilter(Estado, '<>%1', TempLinea.Estado::Ubicado);
        TempLinea.CalcSums("Cantidad Base");
        restoBase := TempLinea."Cantidad Base";
        TempLinea.Reset();
        exit(restoBase);
    end;

    /// <summary>
    /// Explica por qué no se ha podido proponer ningún hueco y qué hacer. La primera frase es
    /// siempre la causa:
    ///   - no hay ninguna ubicación de almacenamiento ni de picking (o de picking, con ProponerEnPicking);
    ///   - las hay, pero ninguna sirve: cuántas por cada motivo (bloqueadas, sin sitio,
    ///     reservadas a otro producto, con otro producto, con otro lote, esperando una
    ///     reubicación, con sitio pero no vacías si la búsqueda solo usa huecos vacíos, o con
    ///     sitio pero descartadas en esta búsqueda: ya propuestas a otras líneas del mismo
    ///     reparto o la ubicación de origen). Si casi todas están sin sitio, se dice claramente
    ///     que no queda espacio; si además el producto no tiene palé, que falta en su ficha,
    ///     porque sin él no se mide lo que ocupa.
    /// Clasifica cada ubicación con MotivoRechazo, la misma regla que la propuesta.
    /// </summary>
    procedure ExplicarSinHuecoLote(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; prm_SoloVacios: Boolean): Text
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        um: Code[10];
        deUso: Integer;
        motivo: Integer;
        entrada: Decimal;
        cuenta: array[10] of Integer;
        detalle: Text;
        donde: Text;
        deTipo: Text;
        AlmacenZonaTxt: Label '%1, zona %2', Comment = '%1 = almacén, %2 = zona';
        AlmacenamientoOPickingTxt: Label 'almacenamiento ni de picking';
        SinUbicacionesTxt: Label 'No hay ninguna ubicación de %1 en el almacén %2. Ponga el "Tipo ubicación" a las ubicaciones donde se guarda la mercancía: Almacenamiento o Picking.', Comment = '%1 = tipo, %2 = almacén';
        SinPaleTxt: Label 'El producto %1 no tiene palé en su ficha y la capacidad de las ubicaciones se cuenta en palés: sin él, %2 %3 no se pueden medir. Ponga su palé en "Cód. palé por defecto".', Comment = '%1 = producto, %2 = cantidad, %3 = unidad';
        SinEspacioTxt: Label 'No queda espacio (almacén %1): %2 de %3 ubicaciones están llenas o sin sitio para %4 %5.%6 Libere ubicaciones o configure más.', Comment = '%1 = almacén, %2 = sin sitio, %3 = total, %4 = cantidad, %5 = unidad, %6 = resto del detalle';
        NingunaSirveTxt: Label 'Ninguna de las %1 ubicaciones del almacén %2 sirve para %3 %4:%5', Comment = '%1 = total, %2 = almacén, %3 = cantidad, %4 = unidad, %5 = detalle por motivo';
        BloqueadasTxt: Label ' %1 bloqueadas;', Comment = '%1 = número';
        ReservadasTxt: Label ' %1 reservadas a otro producto ("Producto fijo");', Comment = '%1 = número';
        SinSitioTxt: Label ' %1 llenas o sin sitio;', Comment = '%1 = número';
        OtroProductoTxt: Label ' %1 con otro producto (no aceptan mezcla);', Comment = '%1 = número';
        OtroLoteTxt: Label ' %1 con otro lote (no aceptan mezcla de lotes);', Comment = '%1 = número';
        ReubicacionTxt: Label ' %1 vacías, esperando una reposición de otro producto;', Comment = '%1 = número';
        PickingCompletoTxt: Label ' %1 de picking, porque el producto ya ocupa todas las ubicaciones de picking que se le permiten;', Comment = '%1 = número';
        YaPropuestasTxt: Label ' %1 con sitio, pero descartadas en esta búsqueda (ya propuestas a otras líneas o la ubicación de origen);', Comment = '%1 = número';
        NoVaciasTxt: Label ' %1 con sitio, pero no vacías (aquí solo se usan huecos vacíos);', Comment = '%1 = número';
        ReservadasEntradaTxt: Label ' %1 reservadas para otra entrada que se está ubicando;', Comment = '%1 = número';
        DelRestoTxt: Label ' Del resto:';
    begin
        um := prm_UM;
        if um = '' then
            um := cUM.UMBase(prm_Producto);

        // Con la búsqueda limitada a una zona (ProponerEnZona) se cuentan solo las suyas, y los
        // mensajes dicen "almacén X, zona Y"; limitada a picking (ProponerEnPicking), solo ese tipo.
        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        donde := prm_Almacen;
        if ZonaDestino <> '' then begin
            rUbicacionSGA.SetRange("Cod. Zona SGA", ZonaDestino);
            donde := StrSubstNo(AlmacenZonaTxt, prm_Almacen, ZonaDestino);
        end;
        if TipoForzado <> TipoForzado::" " then begin
            rUbicacionSGA.SetRange("Tipo Ubicacion", TipoForzado);
            deTipo := LowerCase(Format(TipoForzado));
        end else begin
            rUbicacionSGA.SetFilter("Tipo Ubicacion", '<>%1', rUbicacionSGA."Tipo Ubicacion"::" ");
            deTipo := AlmacenamientoOPickingTxt;
        end;
        deUso := rUbicacionSGA.Count();
        if deUso = 0 then
            exit(StrSubstNo(SinUbicacionesTxt, deTipo, donde));

        entrada := EntradaEnPales(prm_Producto, um, prm_Cantidad);
        if rUbicacionSGA.FindSet() then
            repeat
                motivo := MotivoRechazo(rUbicacionSGA, prm_Producto, prm_Lote, rUbicacionSGA."Tipo Ubicacion", entrada);
                case true of
                    (motivo = 0) and prm_SoloVacios and not rUbicacionSGA.EstaVacia():
                        cuenta[10] += 1;
                    motivo = 0:
                        cuenta[3] += 1;
                    motivo in [1, 2, 4, 5, 6, 7, 8, 9]:
                        cuenta[motivo] += 1;
                end;
            until rUbicacionSGA.Next() = 0;

        // cuenta: 1 bloqueadas, 2 reservadas a otro producto, 3 descartadas en la búsqueda,
        // 4 sin sitio, 5 otro producto, 6 otro lote, 7 esperando una reubicación, 8 picking del
        // producto completo, 9 reservadas para otra entrada, 10 no vacías (búsqueda de vacíos).
        if cuenta[8] > 0 then
            detalle += StrSubstNo(PickingCompletoTxt, cuenta[8]);
        if cuenta[1] > 0 then
            detalle += StrSubstNo(BloqueadasTxt, cuenta[1]);
        if cuenta[9] > 0 then
            detalle += StrSubstNo(ReservadasEntradaTxt, cuenta[9]);
        if cuenta[2] > 0 then
            detalle += StrSubstNo(ReservadasTxt, cuenta[2]);
        if cuenta[5] > 0 then
            detalle += StrSubstNo(OtroProductoTxt, cuenta[5]);
        if cuenta[6] > 0 then
            detalle += StrSubstNo(OtroLoteTxt, cuenta[6]);
        if cuenta[7] > 0 then
            detalle += StrSubstNo(ReubicacionTxt, cuenta[7]);
        if cuenta[10] > 0 then
            detalle += StrSubstNo(NoVaciasTxt, cuenta[10]);
        if cuenta[3] > 0 then
            detalle += StrSubstNo(YaPropuestasTxt, cuenta[3]);

        // Si la mayoría están sin sitio, lo que falta es espacio: se dice primero. Sin palé en la
        // ficha, lo que ocupa se cuenta en unidades base y nunca cabe: lo que falta es el palé.
        if cuenta[4] * 2 >= deUso then begin
            if cUM.UMPale(prm_Producto) = '' then
                exit(StrSubstNo(SinPaleTxt, prm_Producto, prm_Cantidad, um));
            if detalle <> '' then
                detalle := DelRestoTxt + detalle;
            exit(StrSubstNo(SinEspacioTxt, donde, cuenta[4], deUso, prm_Cantidad, um, detalle));
        end;

        if cuenta[4] > 0 then
            detalle += StrSubstNo(SinSitioTxt, cuenta[4]);
        exit(StrSubstNo(NingunaSirveTxt, deUso, donde, prm_Cantidad, um, detalle));
    end;

    /// <summary>
    /// Casa del producto en ese tipo de ubicación: las reservadas a él ("Producto fijo"), por
    /// ruta, y si no la "Shelf No." de su ficha, si es de ese tipo. Solo si siguen admitiéndolo.
    /// </summary>
    local procedure BuscarFija(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_Tipo: Enum "Tipo Ubicacion SGA"; prm_Entrada: Decimal; prm_Excluidas: Text): Code[20]
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        estanteria: Code[20];
        codigo: Code[20];
    begin
        FiltrarCandidatas(rUbicacionSGA, prm_Almacen, prm_Tipo, prm_Excluidas);
        rUbicacionSGA.SetRange("Producto Fijo", prm_Producto);
        codigo := PrimeraQueAdmite(rUbicacionSGA, prm_Producto, prm_Lote, prm_Tipo, prm_Entrada);
        if codigo <> '' then
            exit(codigo);

        estanteria := EstanteriaProducto(prm_Almacen, prm_Producto);
        if estanteria = '' then
            exit('');
        rUbicacionSGA.Get(prm_Almacen, estanteria);
        if EstaExcluida(prm_Almacen, rUbicacionSGA."Cod. Bin", prm_Excluidas) then
            exit('');
        if not UbicacionAdmite(rUbicacionSGA, prm_Producto, prm_Lote, prm_Tipo, prm_Entrada) then
            exit('');
        exit(rUbicacionSGA."Cod. Bin");
    end;

    /// <summary>
    /// Primer hueco completamente vacío de ese tipo siguiendo la ruta de picking. Es la
    /// estrategia que usan los ensamblados: lo que sale de producción va a un hueco limpio.
    /// </summary>
    local procedure BuscarVacia(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_Tipo: Enum "Tipo Ubicacion SGA"; prm_Entrada: Decimal; prm_Excluidas: Text): Code[20]
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        FiltrarCandidatas(rUbicacionSGA, prm_Almacen, prm_Tipo, prm_Excluidas);
        // El estado guardado lo deja al día cada movimiento: así no se lee el contenido de nadie.
        rUbicacionSGA.SetRange("Estado SGA", rUbicacionSGA."Estado SGA"::Vacia);
        exit(PrimeraQueAdmite(rUbicacionSGA, prm_Producto, prm_Lote, prm_Tipo, prm_Entrada));
    end;

    /// <summary>
    /// La primera ubicación filtrada en prm_Ubicacion, por su orden, que admite la entrada. En
    /// blanco si ninguna.
    /// </summary>
    local procedure PrimeraQueAdmite(var prm_Ubicacion: Record "Ubicacion SGA"; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_Tipo: Enum "Tipo Ubicacion SGA"; prm_Entrada: Decimal): Code[20]
    begin
        if prm_Ubicacion.FindSet() then
            repeat
                if UbicacionAdmite(prm_Ubicacion, prm_Producto, prm_Lote, prm_Tipo, prm_Entrada) then
                    exit(prm_Ubicacion."Cod. Bin");
            until prm_Ubicacion.Next() = 0;
        exit('');
    end;

    /// <summary>
    /// Hueco vacío para un palé completo del producto, en el reparto por huecos libres de Cod.
    /// "Carga Inicial SGA": un tipo y luego el otro, en el orden de TipoPorOrden; en cada tipo, los
    /// reservados a ese producto y luego el siguiente libre de la ruta. Mismas reglas que la
    /// propuesta, pero solo huecos vacíos.
    ///
    /// Los huecos sin producto fijo se recorren con un cursor por tipo que solo avanza y que vive
    /// en esta instancia del codeunit. Vale porque, vacío y sin producto fijo, un hueco admite un
    /// palé de cualquiera: el que se salta una vez no le sirve a nadie después. Así no se recorre
    /// la nave entera por cada palé. Para volver a empezar, Clear de la instancia. Con el picking
    /// del producto completo (FijarPickingPrimero) no se mueve el cursor de picking: ese hueco
    /// sigue sirviendo al siguiente producto.
    /// </summary>
    procedure ProponerHuecoPaleRuta(prm_Almacen: Code[10]; prm_Producto: Code[20]; var prm_Motivo: Text): Code[20]
    var
        rFijo: Record "Ubicacion SGA";
        orden: Integer;
        tipo: Enum "Tipo Ubicacion SGA";
        HuecoReservadoLbl: Label '%1: hueco reservado al producto.', Comment = '%1 = tipo de ubicación';
        HuecoRutaLbl: Label '%1: hueco vacío siguiendo la ruta.', Comment = '%1 = tipo de ubicación';
    begin
        PickingCompleto := PickingDelProductoCompleto(prm_Almacen, prm_Producto);
        for orden := 1 to 2 do begin
            tipo := TipoPorOrden(orden);
            // Un palé completo ocupa uno.
            FiltrarCandidatas(rFijo, prm_Almacen, tipo, '');
            rFijo.SetRange("Producto Fijo", prm_Producto);
            if rFijo.FindSet() then
                repeat
                    if VaciaYAdmite(rFijo, prm_Producto, tipo) then begin
                        prm_Motivo := StrSubstNo(HuecoReservadoLbl, tipo);
                        exit(rFijo."Cod. Bin");
                    end;
                until rFijo.Next() = 0;

            if PickingCompleto and (tipo = tipo::Picking) then
                continue;
            if SiguienteHuecoRuta(orden, prm_Almacen, prm_Producto) then begin
                prm_Motivo := StrSubstNo(HuecoRutaLbl, tipo);
                exit(HuecoRuta[orden]."Cod. Bin");
            end;
        end;
        exit('');
    end;

    /// <summary>
    /// Avanza el cursor del tipo prm_Orden (el de TipoPorOrden) hasta el siguiente
    /// hueco vacío sin producto fijo que admite un palé del producto. False si ya no queda.
    /// </summary>
    local procedure SiguienteHuecoRuta(prm_Orden: Integer; prm_Almacen: Code[10]; prm_Producto: Code[20]): Boolean
    begin
        if HuecosRutaAgotados[prm_Orden] then
            exit(false);

        if not HuecoRutaPosicionado[prm_Orden] then begin
            FiltrarCandidatas(HuecoRuta[prm_Orden], prm_Almacen, TipoPorOrden(prm_Orden), '');
            HuecoRuta[prm_Orden].SetRange("Producto Fijo", '');
            HuecoRutaPosicionado[prm_Orden] := true;
            if not HuecoRuta[prm_Orden].FindSet() then begin
                HuecosRutaAgotados[prm_Orden] := true;
                exit(false);
            end;
        end;

        repeat
            if VaciaYAdmite(HuecoRuta[prm_Orden], prm_Producto, TipoPorOrden(prm_Orden)) then
                exit(true);
        until HuecoRuta[prm_Orden].Next() = 0;

        HuecosRutaAgotados[prm_Orden] := true;
        exit(false);
    end;

    /// <summary>
    /// El orden en que se buscan los tipos al ubicar: 1 almacenamiento y 2 picking, o al revés
    /// con FijarPickingPrimero.
    /// </summary>
    local procedure TipoPorOrden(prm_Orden: Integer): Enum "Tipo Ubicacion SGA"
    begin
        if (prm_Orden = 1) xor PickingPrimero then
            exit("Tipo Ubicacion SGA"::Almacenamiento);
        exit("Tipo Ubicacion SGA"::Picking);
    end;

    /// <summary>
    /// Ubicación sin contenido que admite un palé del producto. Lo vacío se cuenta en el
    /// contenido y no en el estado guardado: el cursor de ProponerHuecoPaleRuta lee los huecos
    /// por adelantado, y la carga puede haber llenado alguno después.
    /// </summary>
    local procedure VaciaYAdmite(var prm_Ubicacion: Record "Ubicacion SGA"; prm_Producto: Code[20]; prm_Tipo: Enum "Tipo Ubicacion SGA"): Boolean
    begin
        if not prm_Ubicacion.EstaVacia() then
            exit(false);

        exit(UbicacionAdmite(prm_Ubicacion, prm_Producto, '', prm_Tipo, 1));
    end;

    /// <summary>
    /// Comprueba si una ubicación cae fuera por el filtro de exclusiones. Se resuelve con un
    /// Record filtrado porque prm_Excluidas es un filtro de AL, no una lista que se pueda comparar.
    ///
    /// Los dos filtros sobre "Cod. Bin" van en grupos distintos a propósito: dentro del mismo
    /// grupo el segundo SetFilter sustituiría al primero en lugar de sumarse.
    /// </summary>
    local procedure EstaExcluida(prm_Almacen: Code[10]; prm_Codigo: Code[20]; prm_Excluidas: Text): Boolean
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        if prm_Excluidas = '' then
            exit(false);

        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        rUbicacionSGA.SetRange("Cod. Bin", prm_Codigo);
        rUbicacionSGA.FilterGroup(10);
        rUbicacionSGA.SetFilter("Cod. Bin", prm_Excluidas);
        rUbicacionSGA.FilterGroup(0);

        exit(rUbicacionSGA.IsEmpty());
    end;

    /// <summary>
    /// Suma un hueco al filtro de exclusiones que recibe ProponerUbicacionCon, en el formato que
    /// entiende SetFilter ('&lt;&gt;A&amp;&lt;&gt;B'). Un código en blanco no añade nada. Es la pareja de
    /// EstaExcluida: quien reparte varias cosas a la vez lo usa para no dar el mismo hueco a dos.
    /// </summary>
    procedure AnadirExclusion(prm_Filtro: Text; prm_Codigo: Code[20]): Text
    begin
        if prm_Codigo = '' then
            exit(prm_Filtro);

        if prm_Filtro = '' then
            exit('<>' + prm_Codigo);

        exit(prm_Filtro + '&<>' + prm_Codigo);
    end;

    /// <summary>
    /// Error si la ubicación no es una ubicación SGA del almacén (con su ficha): es la única
    /// comprobación de que una ubicación existe, para cualquier movimiento, también la que lee
    /// el preparador en el picking. No comprueba nada si el almacén o la ubicación van en
    /// blanco: eso lo decide quien llama.
    /// </summary>
    procedure ComprobarUbicacionExiste(prm_Almacen: Code[10]; prm_Ubicacion: Code[20])
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        UbicacionNoExisteErr: Label 'La ubicación %1 no existe en SGA para el almacén %2.', Comment = '%1 = ubicación, %2 = almacén';
    begin
        if (prm_Almacen = '') or (prm_Ubicacion = '') then
            exit;

        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        rUbicacionSGA.SetRange("Cod. Bin", prm_Ubicacion);
        if rUbicacionSGA.IsEmpty() then
            Error(UbicacionNoExisteErr, prm_Ubicacion, prm_Almacen);
    end;

    /// <summary>
    /// Si existe el Bin prm_Ubicacion en el almacén. Con la ubicación en blanco, no. Solo para
    /// limpiar lo que ha quedado sin Bin (EliminarUbicaciones).
    /// </summary>
    local procedure UbicacionExiste(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]): Boolean
    var
        rBin: Record Bin;
    begin
        if prm_Ubicacion = '' then
            exit(false);
        rBin.SetRange("Location Code", prm_Almacen);
        rBin.SetRange(Code, prm_Ubicacion);
        exit(not rBin.IsEmpty());
    end;

    /// <summary>
    /// Ubicación de ese tipo que ya tiene ese producto y aún admite más: agrupar antes que
    /// dispersar. Se queda con la más cercana en la ruta.
    /// </summary>
    local procedure BuscarConsolidacion(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_Tipo: Enum "Tipo Ubicacion SGA"; prm_Entrada: Decimal; prm_Excluidas: Text): Code[20]
    var
        rContenido: Record "Contenido Ubicacion SGA";
        rUbicacionSGA: Record "Ubicacion SGA";
        vistas: List of [Code[20]];
        mejorSecuencia: Integer;
        mejorCodigo: Code[20];
    begin
        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetRange("No. Producto", prm_Producto);
        rContenido.SetLoadFields("Cod. Bin");
        if not rContenido.FindSet() then
            exit('');

        mejorCodigo := '';
        mejorSecuencia := 0;
        repeat
            // Hay una línea por lote y palé: cada ubicación se evalúa una sola vez.
            if not vistas.Contains(rContenido."Cod. Bin") then begin
                vistas.Add(rContenido."Cod. Bin");
                if not EstaExcluida(prm_Almacen, rContenido."Cod. Bin", prm_Excluidas) then
                if rUbicacionSGA.Get(prm_Almacen, rContenido."Cod. Bin") then
                    // MotivoRechazo descarta las de otro tipo.
                    if UbicacionAdmite(rUbicacionSGA, prm_Producto, prm_Lote, prm_Tipo, prm_Entrada) then
                        if (mejorCodigo = '') or (rUbicacionSGA."Secuencia Picking" < mejorSecuencia) then begin
                            mejorSecuencia := rUbicacionSGA."Secuencia Picking";
                            mejorCodigo := rUbicacionSGA."Cod. Bin";
                        end;
            end;
        until rContenido.Next() = 0;

        exit(mejorCodigo);
    end;

    /// <summary>
    /// Primer hueco de ese tipo que admita el producto, siguiendo la ruta física.
    /// </summary>
    local procedure BuscarLibre(prm_Almacen: Code[10]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_Tipo: Enum "Tipo Ubicacion SGA"; prm_Entrada: Decimal; prm_Excluidas: Text): Code[20]
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        FiltrarCandidatas(rUbicacionSGA, prm_Almacen, prm_Tipo, prm_Excluidas);
        exit(PrimeraQueAdmite(rUbicacionSGA, prm_Producto, prm_Lote, prm_Tipo, prm_Entrada));
    end;

    /// <summary>
    /// Huecos que se recorren por la ruta buscando sitio: del tipo que toca, sin bloquear, de la
    /// zona de ProponerEnZona (si la hay) y fuera de las exclusiones. Las demás las descartaría
    /// igual MotivoRechazo; filtrarlas aquí evita leerlas una a una.
    /// </summary>
    local procedure FiltrarCandidatas(var prm_Ubicacion: Record "Ubicacion SGA"; prm_Almacen: Code[10]; prm_Tipo: Enum "Tipo Ubicacion SGA"; prm_Excluidas: Text)
    begin
        prm_Ubicacion.SetCurrentKey("Cod. Almacen", "Tipo Ubicacion", "Secuencia Picking", "Cod. Bin");
        prm_Ubicacion.SetRange("Cod. Almacen", prm_Almacen);
        prm_Ubicacion.SetRange("Tipo Ubicacion", prm_Tipo);
        prm_Ubicacion.SetRange(Bloqueada, false);
        if ZonaDestino <> '' then
            prm_Ubicacion.SetRange("Cod. Zona SGA", ZonaDestino);
        if prm_Excluidas <> '' then
            prm_Ubicacion.SetFilter("Cod. Bin", prm_Excluidas);
    end;

    /// <summary>
    /// Lo que ocupa una cantidad del producto en su unidad, en palés: lo que se compara con la
    /// capacidad libre del hueco.
    /// </summary>
    local procedure EntradaEnPales(prm_Producto: Code[20]; prm_UM: Code[10]; prm_Cantidad: Decimal): Decimal
    var
        cUOMMgt: Codeunit "Unit of Measure Management";
    begin
        exit(cUM.EnPales(prm_Producto, cUOMMgt.CalcBaseQty(prm_Cantidad, cUM.FactorUM(prm_Producto, prm_UM))));
    end;

    /// <summary>
    /// Comprobación de si una ubicación puede recibir el producto. Es la criba para
    /// proponer; la validación que manda es la de Cod. "Gestion Contenido SGA" al registrar.
    /// </summary>
    local procedure UbicacionAdmite(var prm_Ubicacion: Record "Ubicacion SGA"; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_Tipo: Enum "Tipo Ubicacion SGA"; prm_Entrada: Decimal): Boolean
    begin
        exit(MotivoRechazo(prm_Ubicacion, prm_Producto, prm_Lote, prm_Tipo, prm_Entrada) = 0);
    end;

    /// <summary>
    /// Por qué una ubicación no puede recibir el producto, en el orden en que se comprueba:
    ///   0 = sí puede; 1 = bloqueada (ella o su zona); 9 = propuesta a otra entrada que aún no
    ///   se ha ubicado (reservada, ver ReservarHueco); 2 = reservada a otro producto;
    ///   3 = no es del tipo que se busca (o no tiene tipo, o es de otra zona que la de
    ///   ProponerEnZona); 4 = sin sitio suficiente;
    ///   5 = tiene otro producto y no acepta mezcla; 6 = tiene otro lote y no acepta mezcla;
    ///   7 = vacía, pero es el destino de una reubicación pendiente de otro producto;
    ///   8 = de picking, y el producto ya ocupa las que permite FijarPickingPrimero.
    /// Es la única regla: la usan la propuesta (UbicacionAdmite) y la explicación de por qué no
    /// hay hueco (ExplicarSinHuecoLote), para que digan siempre lo mismo.
    ///
    /// prm_Entrada es lo que ocupa la cantidad, en palés (EntradaEnPales): quien llama la
    /// calcula una vez para todas las ubicaciones que mira.
    /// </summary>
    local procedure MotivoRechazo(var prm_Ubicacion: Record "Ubicacion SGA"; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_Tipo: Enum "Tipo Ubicacion SGA"; prm_Entrada: Decimal): Integer
    begin
        if not prm_Ubicacion.EsUtilizable() then
            exit(1);

        // Propuesta a otra entrada que todavía no se ha ubicado (ReservarHueco).
        if prm_Ubicacion.ReservadaParaOtro(ParaReserva) then
            exit(9);

        if prm_Ubicacion.FijaParaOtroProducto(prm_Producto) then
            exit(2);

        // Solo el tipo que se busca, y nunca una ubicación sin tipo (muelles, ajustes…).
        if (prm_Tipo = prm_Tipo::" ") or (prm_Ubicacion."Tipo Ubicacion" <> prm_Tipo) then
            exit(3);
        // Fuera de la zona a la que se limita la búsqueda (ProponerEnZona), tampoco toca.
        if (ZonaDestino <> '') and (prm_Ubicacion."Cod. Zona SGA" <> ZonaDestino) then
            exit(3);
        // El producto ya ocupa las ubicaciones de picking que se le permiten: solo donde ya está
        // o en las reservadas a él.
        if PickingCompleto and (prm_Ubicacion."Tipo Ubicacion" = prm_Ubicacion."Tipo Ubicacion"::Picking) then
            if (prm_Ubicacion."Producto Fijo" <> prm_Producto) and not ProductoEnUbicacion(prm_Ubicacion, prm_Producto) then
                exit(8);

        // CabeEntrada parte de la ocupación guardada, sin volver a sumar el contenido de cada
        // hueco que se mira.
        if not prm_Ubicacion.CabeEntrada(prm_Entrada) then
            exit(4);

        // Vacía no tiene nada con que mezclar, pero puede estar esperando una reubicación.
        if prm_Ubicacion."Estado SGA" = prm_Ubicacion."Estado SGA"::Vacia then begin
            if EsperaReubicacion(prm_Ubicacion, prm_Producto) then
                exit(7);
            exit(0);
        end;

        // 5 = otro producto, 6 = otro lote; 0 si nada impide la mezcla.
        exit(prm_Ubicacion.ContenidoQueImpideMezcla(prm_Producto, prm_Lote));
    end;

    /// <summary>
    /// Si la ubicación de picking es el destino de una reubicación pendiente de otro producto:
    /// ese hueco ya tiene dueño aunque esté vacío, y no se le propone a nadie más.
    /// </summary>
    local procedure EsperaReubicacion(var prm_Ubicacion: Record "Ubicacion SGA"; prm_Producto: Code[20]): Boolean
    var
        rLinea: Record "Linea Orden Picking SGA";
    begin
        if prm_Ubicacion."Tipo Ubicacion" <> prm_Ubicacion."Tipo Ubicacion"::Picking then
            exit(false);

        rLinea.SetCurrentKey("Cod. Almacen", "Cod. Bin Destino", Estado);
        rLinea.SetRange("Cod. Almacen", prm_Ubicacion."Cod. Almacen");
        rLinea.SetRange("Cod. Bin Destino", prm_Ubicacion."Cod. Bin");
        rLinea.FiltrarPendientes();
        rLinea.SetFilter("No. Producto", '<>%1', prm_Producto);
        exit(not rLinea.IsEmpty());
    end;

    /// <summary>
    /// Casa declarada de un producto en un almacén, sin mirar si cabe: la primera ubicación con
    /// él como "Producto Fijo" y, si no hay, la "Shelf No." de su ficha si existe en SGA.
    /// </summary>
    procedure UbicacionFijaProducto(prm_Almacen: Code[10]; prm_Producto: Code[20]): Code[20]
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        rUbicacionSGA.SetRange("Producto Fijo", prm_Producto);
        rUbicacionSGA.SetLoadFields("Cod. Bin");
        if rUbicacionSGA.FindFirst() then
            exit(rUbicacionSGA."Cod. Bin");
        exit(EstanteriaProducto(prm_Almacen, prm_Producto));
    end;

    /// <summary>
    /// La "Shelf No." de la ficha del producto, si es una ubicación de SGA de ese almacén.
    /// </summary>
    local procedure EstanteriaProducto(prm_Almacen: Code[10]; prm_Producto: Code[20]): Code[20]
    var
        rItem: Record Item;
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        rItem.SetLoadFields("Shelf No.");
        if not rItem.Get(prm_Producto) then
            exit('');
        if rItem."Shelf No." = '' then
            exit('');
        if not rUbicacionSGA.Get(prm_Almacen, rItem."Shelf No.") then
            exit('');
        exit(rItem."Shelf No.");
    end;


    /// <summary>
    /// Hueco para trasladar a otra zona: la propuesta de siempre (estrategia de la
    /// configuración, mismas reglas de tipo, capacidad y mezcla), pero solo entre las
    /// ubicaciones de prm_Zona y sin la de origen. Sin hueco devuelve '' y en prm_Motivo el
    /// porqué, contado sobre esa zona. Con la zona en blanco busca en todo el almacén.
    /// </summary>
    procedure ProponerEnZona(prm_Almacen: Code[10]; prm_Zona: Code[10]; prm_Origen: Code[20]; prm_Producto: Code[20]; prm_Lote: Code[50]; prm_UM: Code[10]; prm_Cantidad: Decimal; var prm_Motivo: Text): Code[20]
    var
        rConfig: Record "Config. SGA";
        codigo: Code[20];
    begin
        rConfig.ObtenerConfig();
        ZonaDestino := prm_Zona;
        codigo := ProponerUbicacionCon(rConfig."Estrategia Ubicacion", AnadirExclusion('', prm_Origen), prm_Almacen,
                                       prm_Producto, prm_Lote, prm_UM, prm_Cantidad, prm_Motivo);
        ZonaDestino := '';
        exit(codigo);
    end;

    /// <summary>
    /// Error si la ubicación no es de la zona. Una zona en blanco no exige nada.
    /// </summary>
    procedure TestUbicacionEnZona(prm_Almacen: Code[10]; prm_Ubicacion: Code[20]; prm_Zona: Code[10])
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        FueraDeZonaErr: Label 'La ubicación %1 no es de la zona %2.', Comment = '%1 = ubicación, %2 = zona';
    begin
        if (prm_Zona = '') or (prm_Ubicacion = '') then
            exit;
        if rUbicacionSGA.ZonaDe(prm_Almacen, prm_Ubicacion) <> prm_Zona then
            Error(FueraDeZonaErr, prm_Ubicacion, prm_Zona);
    end;

    /// <summary>
    /// Para quién se propone a partir de ahora en esta instancia: sus propias reservas no le
    /// cuentan como ocupadas. En blanco, cualquier reserva es de otro.
    /// </summary>
    procedure FijarReserva(prm_Para: Text)
    begin
        ParaReserva := prm_Para;
    end;

    /// <summary>
    /// Reserva un hueco para una entrada que se está ubicando (prm_Para) y suelta los que tenía
    /// esa misma entrada en esta sesión: cada entrada tiene un solo hueco reservado. False, sin
    /// cambiar nada, si el hueco ya está reservado para otra. Bloquea el registro que lee (y
    /// solo ese, no la tabla para el resto de la transacción), para que dos sesiones que
    /// proponen a la vez no se queden con el mismo hueco.
    /// </summary>
    procedure ReservarHueco(prm_Almacen: Code[10]; prm_Bin: Code[20]; prm_Para: Text): Boolean
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        rUbicacionSGA.ReadIsolation := IsolationLevel::UpdLock;
        if not rUbicacionSGA.Get(prm_Almacen, prm_Bin) then
            exit(false);
        if not rUbicacionSGA.Reservar(prm_Para) then
            exit(false);

        LiberarReservas(prm_Para, prm_Bin);
        exit(true);
    end;

    /// <summary>
    /// Error si el hueco está reservado para otra entrada. Para cuando el operario elige el
    /// hueco a mano: si lo puede usar, queda reservado para él.
    /// </summary>
    procedure TestReservarHueco(prm_Almacen: Code[10]; prm_Bin: Code[20]; prm_Para: Text)
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        ReservadaErr: Label 'La ubicación %1 está reservada para %2 (%3). Elija otra o pida que la liberen.', Comment = '%1 = ubicación, %2 = entrada, %3 = usuario';
    begin
        if ReservarHueco(prm_Almacen, prm_Bin, prm_Para) then
            exit;
        if rUbicacionSGA.Get(prm_Almacen, prm_Bin) then
            Error(ReservadaErr, prm_Bin, rUbicacionSGA."Reservada Para", rUbicacionSGA."Reservada Por");
    end;

    /// <summary>
    /// Suelta los huecos reservados para prm_Para en esta sesión, menos prm_Salvo. Se usa al
    /// cambiar de hueco, al ubicar y al cerrar la pantalla.
    /// </summary>
    procedure LiberarReservas(prm_Para: Text; prm_Salvo: Code[20])
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        rConfig: Record "Config. SGA";
    begin
        if prm_Para = '' then
            exit;

        rUbicacionSGA.SetCurrentKey("Reservada Por", "Sesion Reserva", "Reservada Para");
        rUbicacionSGA.SetRange("Reservada Por", rConfig.UsuarioActual());
        rUbicacionSGA.SetRange("Sesion Reserva", SessionId());
        rUbicacionSGA.SetRange("Reservada Para", CopyStr(prm_Para, 1, MaxStrLen(rUbicacionSGA."Reservada Para")));
        if prm_Salvo <> '' then
            rUbicacionSGA.SetFilter("Cod. Bin", '<>%1', prm_Salvo);
        if rUbicacionSGA.FindSet(true) then
            repeat
                rUbicacionSGA.LiberarReserva();
            until rUbicacionSGA.Next() = 0;
    end;

    /// <summary>
    /// Suelta a mano la reserva de las ubicaciones, sea de quien sea: para cuando una pantalla
    /// se ha quedado sin cerrar bien y su hueco sigue reservado. Devuelve cuántas ha soltado.
    /// </summary>
    procedure LiberarReservasSeleccion(var prm_Ubicaciones: Record "Ubicacion SGA") liberadas: Integer
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        rUbicacionSGA.Copy(prm_Ubicaciones);
        rUbicacionSGA.SetFilter("Reservada Por", '<>%1', '');
        if rUbicacionSGA.FindSet(true) then
            repeat
                rUbicacionSGA.LiberarReserva();
                liberadas += 1;
            until rUbicacionSGA.Next() = 0;
    end;

    var
        // Cursores de ProponerHuecoPaleRuta, uno por orden de TipoPorOrden: el último
        // hueco vacío mirado en la ruta.
        HuecoRuta: array[2] of Record "Ubicacion SGA";
        cUM: Codeunit "Unidades Producto SGA";
        // Para quién se propone (FijarReserva): sus propias reservas no cuentan como ocupadas.
        ParaReserva: Text;
        // Zona a la que ProponerEnZona limita la propuesta mientras dura; en blanco, todas.
        ZonaDestino: Code[10];
        // Tipo al que ProponerEnPicking limita la propuesta mientras dura; en blanco, almacenamiento
        // y luego picking.
        TipoForzado: Enum "Tipo Ubicacion SGA";
        HuecoRutaPosicionado: array[2] of Boolean;
        // Orden de tipos de TipoPorOrden: picking antes que almacenamiento (FijarPickingPrimero).
        PickingPrimero: Boolean;
        // Ubicaciones de picking que puede ocupar cada producto (FijarPickingPrimero); 0, sin
        // límite. PickingCompleto: si el producto de la propuesta en curso ya las ocupa.
        MaxPickingProducto: Integer;
        PickingCompleto: Boolean;
        HuecosRutaAgotados: array[2] of Boolean;
}
