namespace AntonioNadal.SGA;

/// <summary>
/// Codeunit Gestion Mapa SGA (ID 51102).
/// Construcción y renderizado del mapa visual de almacén sobre el Bin estándar.
///
/// El mapa deduce la topología del propio código de ubicación, con el formato
/// pasillo-estantería-altura que genera Cod. "Gestion Ubicaciones SGA" (101-15-03).
/// Las ubicaciones cuyo código no sigue ese formato no se dibujan: el mapa es una vista de
/// pasillos ordenados, y un código libre no tiene posición en la rejilla.
/// </summary>
codeunit 51102 "Gestion Mapa SGA"
{
    Access = Public;

    /// <summary>
    /// Rellena el buffer de la rejilla con las ubicaciones del almacén y devuelve la última
    /// estantería encontrada, para que la página avise si no caben todas.
    /// El buffer lo pasa la página: es temporal y cada página tiene su propia instancia.
    /// Con prm_GrupoIIEE, las ubicaciones con algún producto de ese grupo se marcan (◆ y su
    /// color) y las demás se apagan; en prm_ConGrupo, cuántas lo tienen.
    /// </summary>
    procedure ConstruirMapa(var prm_Buffer: Record "Buffer Mapa SGA"; prm_Almacen: Code[10]; prm_GrupoIIEE: Code[20]; var prm_ConGrupo: Integer) maxEstanteriaEncontrada: Integer
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        productoUnico: Dictionary of [Code[20], Code[20]];
        conGrupo: List of [Code[20]];
        MarcaGrupoTok: Label '◆ ', Locked = true;
        pasillo: Integer;
        estanteria: Integer;
        altura: Integer;
        resumen: Text;
        estilo: Text;
    begin
        prm_Buffer.Reset();
        prm_Buffer.DeleteAll();
        prm_ConGrupo := 0;

        if prm_Almacen = '' then
            exit(0);

        // Las líneas de cada ubicación llegan con la misma consulta; el producto de las que
        // tienen una sola, de una lectura del contenido del almacén.
        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        rUbicacionSGA.SetLoadFields("Cod. Bin", "Estado SGA", "Reservada Por");
        rUbicacionSGA.SetAutoCalcFields("Lineas Contenido");
        if not rUbicacionSGA.FindSet() then
            exit(0);
        LeerProductoUnico(prm_Almacen, productoUnico);
        if prm_GrupoIIEE <> '' then begin
            LeerUbicacionesConGrupo(prm_Almacen, prm_GrupoIIEE, conGrupo);
            prm_ConGrupo := conGrupo.Count();
        end;

        repeat
            if cUbicaciones.TrocearCodigo(rUbicacionSGA."Cod. Bin", pasillo, estanteria, altura) then begin
                if estanteria > maxEstanteriaEncontrada then
                    maxEstanteriaEncontrada := estanteria;

                // Más allá de la rejilla no se pinta, pero sí se ha contado arriba
                // para que la página pueda avisar de que el pasillo no cabe entero.
                if estanteria <= MaximoColumnasRejilla() then begin
                    SituarFila(prm_Buffer, prm_Almacen, pasillo, altura);
                    Pintar(rUbicacionSGA, productoUnico, resumen, estilo);
                    if prm_GrupoIIEE <> '' then
                        if conGrupo.Contains(rUbicacionSGA."Cod. Bin") then
                            resumen := MarcaGrupoTok + resumen
                        else
                            estilo := 'Subordinate';
                    prm_Buffer.FijarColumna(estanteria, resumen, estilo);
                    prm_Buffer.Modify();
                end;
            end;
        until rUbicacionSGA.Next() = 0;

        prm_Buffer.Reset();
    end;

    /// <summary>
    /// Abre el contenido de la ubicación que representa una celda de la rejilla: la columna es
    /// la estantería.
    /// </summary>
    procedure AbrirContenidoCelda(var prm_Buffer: Record "Buffer Mapa SGA"; prm_Columna: Integer)
    var
        cContenido: Codeunit "Gestion Contenido SGA";
    begin
        cContenido.MostrarContenidoUbicacion(prm_Buffer."Cod. Almacen", cUbicaciones.ComponerCodigoUbicacion(prm_Buffer.Pasillo, prm_Columna, prm_Buffer.Altura));
    end;

    /// <summary>
    /// Columnas que caben en la rejilla de "Buffer Mapa SGA".
    /// </summary>
    procedure MaximoColumnasRejilla(): Integer
    begin
        // Tantas como columnas tiene el buffer del mapa. Si se amplía el buffer,
        // hay que subir este número y añadir los campos a la página del mapa.
        exit(32);
    end;

    /// <summary>
    /// Devuelve las ubicaciones del almacén en JSON, para el mapa 3D.
    /// Cada elemento lleva las coordenadas físicas que el lienzo necesita para colocar el
    /// cubo y el estado con el que lo pinta:
    /// Lo vacío o a cero no va (d, z, ch, l): el lienzo lo toma como vacío o 0.
    ///   b = código de ubicación, d = descripción, z = zona,
    ///   e = pasillo, c = estantería, a = altura (los tres como número),
    ///   s = estado (0 vacía, 1 parcial, 2 llena, 3 bloqueada, 4 con contenido sin medir),
    ///   v = para quién está reservada (solo si lo está: propuesta a una entrada que aún no se
    ///   ha ubicado),
    ///   o = % de ocupación, redondeado hacia abajo (-1 si no se puede medir),
    ///   m = por qué no se puede medir (solo si no se puede),
    ///   l = líneas de contenido y, solo si tiene, k, pp, gi, fc y r (ver LeerContenidos);
    ///   ch = clase del hueco por su posición (1 A, 2 B, 3 C, 0 si no es hueco útil),
    ///   f = 1 si es fondo de pasillo (solo si lo es).
    /// Las dos clases son del cálculo ABC prm_NoCalculoABC (0 = el último del almacén).
    /// Las claves son cortas porque el JSON viaja entero al navegador y un almacén grande
    /// son más de mil ubicaciones. Con prm_Pasillo distinto de 0, solo las de ese pasillo.
    /// En prm_Resumen, el de ResumenUbicaciones del almacén y la zona: sin pasillo se cuenta con
    /// las mismas ubicaciones que se leen; con pasillo se pide aparte.
    ///
    /// El % se redondea hacia abajo para que no diga 100 % de una ubicación que aún tiene
    /// hueco. No se puede medir sin capacidad declarada, ni si algún producto de dentro no tiene
    /// palé en su ficha: su contenido se contaría en unidades base como si cada una fuera un palé.
    /// </summary>
    procedure DatosMapa3D(prm_Almacen: Code[10]; prm_Zona: Code[10]; prm_Pasillo: Integer; prm_NoCalculoABC: Integer; var prm_Resumen: Text): Text
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        lista: JsonArray;
        elemento: JsonObject;
        contenidos: Dictionary of [Code[20], JsonObject];
        sinPale: Dictionary of [Code[20], Text];
        filtroPasillo: Text;
        total: Integer;
        vacias: Integer;
        llenas: Integer;
        bloqueadas: Integer;
        salida: Text;
        motivoSinMedir: Text;
        claseHueco: Integer;
        pasillo: Integer;
        estanteria: Integer;
        altura: Integer;
        conContenido: Boolean;
        SinCapacidadLbl: Label 'Sin capacidad declarada: no se puede medir cuánto ocupa. Indique la capacidad en la ficha de la ubicación.';
        ReservadaLbl: Label 'Reservada para %1 (%2).', Comment = '%1 = entrada, %2 = usuario';
    begin
        if prm_Almacen = '' then
            exit('[]');

        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        if prm_Zona <> '' then
            rUbicacionSGA.SetRange("Cod. Zona SGA", prm_Zona);
        // Un pasillo son los códigos que empiezan por él (101-*): lo filtra la base de datos.
        if prm_Pasillo <> 0 then
            filtroPasillo := cUbicaciones.ConCeros(prm_Pasillo, 3) + '-*';
        if filtroPasillo <> '' then
            rUbicacionSGA.SetFilter("Cod. Bin", filtroPasillo);
        rUbicacionSGA.SetLoadFields("Cod. Bin", Descripcion, "Cod. Zona SGA", Fondo, "Capacidad Uds.", "Estado SGA", "% Ocupacion", "Reservada Por", "Reservada Para");
        // El resumen de un pasillo no sirve: es el del almacén (y zona), que se cuenta aparte.
        if prm_Pasillo <> 0 then
            prm_Resumen := cUbicaciones.ResumenUbicaciones(prm_Almacen, prm_Zona);
        if not rUbicacionSGA.FindSet() then begin
            if prm_Pasillo = 0 then
                prm_Resumen := cUbicaciones.TextoResumen(0, 0, 0, 0);
            exit('[]');
        end;

        // La clase de cada producto y la de cada hueco por su posición, y el contenido de todas
        // las ubicaciones, se leen una vez para todo el mapa.
        LeerClasesABC(prm_Almacen, prm_NoCalculoABC);
        LeerContenidos(prm_Almacen, prm_Zona, filtroPasillo, ClasesABC, contenidos, sinPale);

        repeat
            // Sin pasillo, el resumen sale de lo que se está leyendo (todas, se dibujen o no).
            total += 1;
            case rUbicacionSGA."Estado SGA" of
                rUbicacionSGA."Estado SGA"::Vacia:
                    vacias += 1;
                rUbicacionSGA."Estado SGA"::Llena:
                    llenas += 1;
                rUbicacionSGA."Estado SGA"::Bloqueada:
                    bloqueadas += 1;
            end;
            // Sin pasillo, estantería y altura no hay dónde colocar el cubo.
            if cUbicaciones.TrocearCodigo(rUbicacionSGA."Cod. Bin", pasillo, estanteria, altura) then begin
                // Con contenido, el elemento ya trae lo que hay dentro (LeerContenidos).
                // Lo vacío o a cero no se manda (el lienzo lo toma así): un almacén grande son
                // miles de elementos. Sin "l", la ubicación no tiene contenido y el lienzo no deja
                // arrastrar un traslado desde ella.
                conContenido := contenidos.Get(rUbicacionSGA."Cod. Bin", elemento);
                if not conContenido then
                    Clear(elemento);
                elemento.Add('b', rUbicacionSGA."Cod. Bin");
                if rUbicacionSGA.Descripcion <> '' then
                    elemento.Add('d', rUbicacionSGA.Descripcion);
                if rUbicacionSGA."Cod. Zona SGA" <> '' then
                    elemento.Add('z', rUbicacionSGA."Cod. Zona SGA");
                elemento.Add('e', pasillo);
                elemento.Add('c', estanteria);
                elemento.Add('a', altura);
                // Clase del hueco por su posición (1 A, 2 B, 3 C; sin ella, no es hueco útil).
                if ClasesHueco.Get(rUbicacionSGA."Cod. Bin", claseHueco) then
                    elemento.Add('ch', claseHueco);
                if rUbicacionSGA.Fondo then
                    elemento.Add('f', 1);
                motivoSinMedir := '';
                if conContenido then
                    if rUbicacionSGA."Capacidad Uds." <= 0 then
                        motivoSinMedir := SinCapacidadLbl
                    else
                        if sinPale.Get(rUbicacionSGA."Cod. Bin", motivoSinMedir) then;
                elemento.Add('s', EstadoNumerico(rUbicacionSGA, motivoSinMedir <> ''));
                if rUbicacionSGA."Reservada Por" <> '' then
                    elemento.Add('v', StrSubstNo(ReservadaLbl, rUbicacionSGA."Reservada Para", rUbicacionSGA."Reservada Por"));
                if motivoSinMedir <> '' then begin
                    elemento.Add('o', -1);
                    elemento.Add('m', motivoSinMedir);
                end else
                    elemento.Add('o', Round(rUbicacionSGA."% Ocupacion", 1, '<'));
                lista.Add(elemento);
            end;
        until rUbicacionSGA.Next() = 0;

        if prm_Pasillo = 0 then
            prm_Resumen := cUbicaciones.TextoResumen(total, vacias, llenas, bloqueadas);
        lista.WriteTo(salida);
        exit(salida);
    end;

    /// <summary>
    /// Lo que hay en las ubicaciones del mapa (almacén, zona y pasillo de DatosMapa3D), leído en
    /// una sola consulta: el contenido se recorre por su clave principal, que empieza por
    /// almacén y ubicación, así que las líneas de cada ubicación vienen seguidas. La descripción
    /// del producto llega en la misma consulta (FlowField Descripcion).
    ///
    /// Por cada ubicación con contenido deja en prm_Contenidos el principio de su elemento:
    ///   l = líneas, k = las primeras líneas (ver LineaMapa) y, de todas ellas, pp = productos
    ///   (sin repetir, para buscar), gi = Grupos IIEE de sus productos (sin repetir, los que
    ///   tienen), fc = caducidad más próxima (aaaa-mm-dd, vacía si ninguna lleva) y r = mejor
    ///   clase ABC de sus productos según prm_ClasesABC (1 A, 2 B, 3 C, 0 sin clase).
    /// Y en prm_SinPale, si algún producto de dentro no tiene palé en su ficha, por qué no se
    /// puede medir en palés (el primero que falla).
    ///
    /// Va con el resto del mapa y no se pide al pasar el ratón: una ida y vuelta a BC por cada
    /// bloque haría la ficha lenta. Se envían solo las primeras líneas para que un hueco mixto
    /// con muchas referencias no engorde el JSON; el lienzo dice cuántas faltan con "l".
    /// </summary>
    local procedure LeerContenidos(prm_Almacen: Code[10]; prm_Zona: Code[10]; prm_FiltroPasillo: Text; var prm_ClasesABC: Dictionary of [Code[20], Integer]; var prm_Contenidos: Dictionary of [Code[20], JsonObject]; var prm_SinPale: Dictionary of [Code[20], Text])
    var
        rContenido: Record "Contenido Ubicacion SGA";
        grupo: JsonObject;
        lineas: JsonArray;
        productos: JsonArray;
        gruposIIEE: JsonArray;
        vistos: List of [Code[20]];
        vistosGrupo: List of [Code[20]];
        ubicacion: Code[20];
        umPale: Code[10];
        factorPale: Decimal;
        caducidad: Date;
        numLineas: Integer;
        claseABC: Integer;
        clase: Integer;
        MaxLineas: Integer;
        fin: Boolean;
        SinPaleLbl: Label 'El producto %1 no tiene palé en su ficha ("Cód. palé por defecto"): no se puede medir cuánto ocupa.', Comment = '%1 = producto';
    begin
        MaxLineas := 8;
        caducidad := 0D;
        claseABC := 0;
        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        if prm_Zona <> '' then
            rContenido.SetRange("Cod. Zona SGA", prm_Zona);
        if prm_FiltroPasillo <> '' then
            rContenido.SetFilter("Cod. Bin", prm_FiltroPasillo);
        rContenido.SetLoadFields("Cod. Bin", "No. Producto", "No. Lote", "Cod. Unidad Medida", "Cantidad Base", "Fecha Caducidad", Bloqueado);
        rContenido.SetAutoCalcFields(Descripcion, "Grupo IIEE");
        if not rContenido.FindSet() then
            exit;

        repeat
            ubicacion := rContenido."Cod. Bin";
            numLineas += 1;
            if numLineas <= MaxLineas then
                lineas.Add(LineaMapa(rContenido));
            if not vistos.Contains(rContenido."No. Producto") then begin
                vistos.Add(rContenido."No. Producto");
                productos.Add(rContenido."No. Producto");
                // A (1) es la mejor; 0 = sin clase, no cuenta.
                if prm_ClasesABC.Get(rContenido."No. Producto", clase) then
                    if (clase > 0) and ((claseABC = 0) or (clase < claseABC)) then
                        claseABC := clase;
                // Sin palé, su contenido se contaría en unidades base como si cada una fuera un palé.
                if not prm_SinPale.ContainsKey(ubicacion) then
                    if not cUM.LeerPale(rContenido."No. Producto", umPale, factorPale) then
                        prm_SinPale.Add(ubicacion, StrSubstNo(SinPaleLbl, rContenido."No. Producto"));
            end;
            if (rContenido."Grupo IIEE" <> '') and not vistosGrupo.Contains(rContenido."Grupo IIEE") then begin
                vistosGrupo.Add(rContenido."Grupo IIEE");
                gruposIIEE.Add(rContenido."Grupo IIEE");
            end;
            if rContenido."Fecha Caducidad" <> 0D then
                if (caducidad = 0D) or (rContenido."Fecha Caducidad" < caducidad) then
                    caducidad := rContenido."Fecha Caducidad";

            // Tras la última línea de la ubicación se guarda lo reunido y se empieza la siguiente.
            fin := rContenido.Next() = 0;
            if fin or (rContenido."Cod. Bin" <> ubicacion) then begin
                grupo.Add('l', numLineas);
                grupo.Add('k', lineas);
                grupo.Add('pp', productos);
                grupo.Add('gi', gruposIIEE);
                if caducidad <> 0D then
                    grupo.Add('fc', Format(caducidad, 0, 9))
                else
                    grupo.Add('fc', '');
                grupo.Add('r', claseABC);
                prm_Contenidos.Add(ubicacion, grupo);
                Clear(grupo);
                Clear(lineas);
                Clear(productos);
                Clear(vistos);
                Clear(gruposIIEE);
                Clear(vistosGrupo);
                numLineas := 0;
                caducidad := 0D;
                claseABC := 0;
            end;
        until fin;
    end;

    /// <summary>
    /// Una línea de contenido, para la ficha flotante del mapa 3D:
    ///   p = producto, t = descripción, l = lote, f = caducidad (aaaa-mm-dd o vacía),
    ///   q = cantidad, u = unidad, x = bloqueado,
    ///   g = palé por defecto del producto (ficha del producto), gf = cuántas "u" lleva ese palé.
    ///
    /// La cantidad no se enseña en la unidad en que se registró, sino como se cuenta en el
    /// almacén (ver UnidadParaMostrar): el palé si está completo y, si no llega al 100 %, el
    /// número de cajas. Con el palé completo no se manda "gf": diría "1 PALE/palé".
    /// La descripción la trae el registro (FlowField calculado al leer, ver LeerContenidos).
    /// </summary>
    local procedure LineaMapa(var prm_Contenido: Record "Contenido Ubicacion SGA"): JsonObject
    var
        linea: JsonObject;
        umMostrar: Code[10];
        umPale: Code[10];
        factorMostrar: Decimal;
        factorPale: Decimal;
    begin
        cUM.LeerPale(prm_Contenido."No. Producto", umPale, factorPale);
        cUM.UnidadParaMostrar(prm_Contenido."No. Producto", prm_Contenido."Cantidad Base", umMostrar, factorMostrar);

        linea.Add('p', prm_Contenido."No. Producto");
        linea.Add('t', CopyStr(prm_Contenido.Descripcion, 1, 60));
        linea.Add('l', prm_Contenido."No. Lote");
        if prm_Contenido."Fecha Caducidad" <> 0D then
            linea.Add('f', Format(prm_Contenido."Fecha Caducidad", 0, 9))
        else
            linea.Add('f', '');
        if umMostrar <> '' then begin
            linea.Add('q', Round(prm_Contenido."Cantidad Base" / factorMostrar, 0.01));
            linea.Add('u', umMostrar);
        end else begin
            linea.Add('q', prm_Contenido."Cantidad Base");
            linea.Add('u', prm_Contenido."Cod. Unidad Medida");
        end;
        linea.Add('x', prm_Contenido.Bloqueado);
        // Tipo de palé del producto (el de su ficha) y cuánto lleva en la misma unidad
        // que la cantidad, para que la ficha diga "45 CAJA12 · PALE (45 CAJA12/palé)".
        linea.Add('g', umPale);
        if (umPale <> '') and (umMostrar <> '') and (umMostrar <> umPale) then
            linea.Add('gf', Round(factorPale / factorMostrar, 0.01))
        else
            linea.Add('gf', 0);
        exit(linea);
    end;

    /// <summary>
    /// Traduce el estado de la ubicación al índice de color que entiende el lienzo. Con
    /// contenido que no se puede medir (prm_SinMedir), 4: no se sabe si está llena.
    /// </summary>
    local procedure EstadoNumerico(var prm_Ubicacion: Record "Ubicacion SGA"; prm_SinMedir: Boolean): Integer
    begin
        // El estado guardado ya dice si está bloqueada ella o su zona entera (RecalcularOcupacion).
        if prm_Ubicacion."Estado SGA" = prm_Ubicacion."Estado SGA"::Bloqueada then
            exit(3);
        if prm_SinMedir then
            exit(4);

        case prm_Ubicacion."Estado SGA" of
            prm_Ubicacion."Estado SGA"::Llena:
                exit(2);
            prm_Ubicacion."Estado SGA"::Parcial:
                exit(1);
            else
                exit(0);
        end;
    end;

    /// <summary>
    /// Deja el buffer posicionado en la fila de ese pasillo y altura, creándola si hace falta.
    /// La fila se busca por su clave: dentro del pasillo, el orden sale de la altura invertida,
    /// para que la rejilla se lea como se ve el pasillo de frente, con la altura más alta arriba.
    /// </summary>
    local procedure SituarFila(var prm_Buffer: Record "Buffer Mapa SGA"; prm_Almacen: Code[10]; prm_Pasillo: Integer; prm_Altura: Integer)
    begin
        if prm_Buffer.Get(prm_Almacen, prm_Pasillo, 100 - prm_Altura) then
            exit;

        prm_Buffer.Init();
        prm_Buffer."Cod. Almacen" := prm_Almacen;
        prm_Buffer.Pasillo := prm_Pasillo;
        prm_Buffer.Altura := prm_Altura;
        prm_Buffer.Orden := 100 - prm_Altura;
        prm_Buffer.Insert();
    end;

    /// <summary>
    /// El producto de cada ubicación del almacén, en una lectura del contenido. Solo se usa en las
    /// que tienen una sola línea, así que basta el de cualquiera de sus líneas.
    /// </summary>
    local procedure LeerProductoUnico(prm_Almacen: Code[10]; var prm_Productos: Dictionary of [Code[20], Code[20]])
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetLoadFields("Cod. Bin", "No. Producto");
        if rContenido.FindSet() then
            repeat
                if not prm_Productos.ContainsKey(rContenido."Cod. Bin") then
                    prm_Productos.Add(rContenido."Cod. Bin", rContenido."No. Producto");
            until rContenido.Next() = 0;
    end;

    /// <summary>
    /// Las ubicaciones del almacén con algún producto del Grupo IIEE (el de la ficha del
    /// producto, FlowField del contenido), en una lectura.
    /// </summary>
    local procedure LeerUbicacionesConGrupo(prm_Almacen: Code[10]; prm_GrupoIIEE: Code[20]; var prm_Ubicaciones: List of [Code[20]])
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        rContenido.SetRange("Cod. Almacen", prm_Almacen);
        rContenido.SetRange("Grupo IIEE", prm_GrupoIIEE);
        rContenido.SetLoadFields("Cod. Bin");
        if rContenido.FindSet() then
            repeat
                if not prm_Ubicaciones.Contains(rContenido."Cod. Bin") then
                    prm_Ubicaciones.Add(rContenido."Cod. Bin");
            until rContenido.Next() = 0;
    end;

    /// <summary>
    /// Texto y color de la celda de una ubicación, con "Lineas Contenido" ya calculado y el
    /// producto de cada ubicación (LeerProductoUnico).
    /// </summary>
    local procedure Pintar(var prm_Ubicacion: Record "Ubicacion SGA"; var prm_ProductoUnico: Dictionary of [Code[20], Code[20]]; var prm_Resumen: Text; var prm_Estilo: Text)
    var
        LineasLbl: Label '%1 lín.', Comment = '%1 = nº de líneas de contenido (producto, lote y palé)';
    begin
        prm_Estilo := prm_Ubicacion.EstiloEstado();

        // Bloqueada la ubicación o su zona entera (el estado guardado ya lo recoge).
        if prm_Ubicacion."Estado SGA" = prm_Ubicacion."Estado SGA"::Bloqueada then begin
            prm_Estilo := 'Unfavorable';
            prm_Resumen := 'BLOQ';
            exit;
        end;

        case prm_Ubicacion."Lineas Contenido" of
            0:
                prm_Resumen := '-';
            1:
                prm_Resumen := prm_ProductoUnico.Get(prm_Ubicacion."Cod. Bin");
            else
                // Una línea por producto, lote y palé: no son productos distintos.
                prm_Resumen := StrSubstNo(LineasLbl, prm_Ubicacion."Lineas Contenido");
        end;

        // Reservada para una entrada que aún no se ha ubicado: su propio color.
        if prm_Ubicacion."Reservada Por" <> '' then begin
            prm_Estilo := 'StrongAccent';
            if prm_Ubicacion."Lineas Contenido" = 0 then
                prm_Resumen := 'RESERV';
        end;
    end;

    /// <summary>
    /// Deja en ClasesABC y ClasesHueco las clases del cálculo ABC prm_NoCalculo del almacén (0 =
    /// el último). Se leen una vez por instancia: el mapa 3D guarda la suya mientras está
    /// abierto, y repintar tras un traslado o un vaciado no vuelve a clasificar todos los huecos.
    /// Un cálculo nuevo es otro número y se lee.
    /// </summary>
    local procedure LeerClasesABC(prm_Almacen: Code[10]; prm_NoCalculo: Integer)
    var
        rCalculo: Record "Calculo ABC SGA";
        cABC: Codeunit "Analisis ABC SGA";
        noCalculo: Integer;
    begin
        noCalculo := prm_NoCalculo;
        if noCalculo = 0 then
            noCalculo := rCalculo.UltimoDelAlmacen(prm_Almacen);
        if ClasesLeidas and (ClasesAlmacen = prm_Almacen) and (ClasesCalculo = noCalculo) then
            exit;
        cABC.ClasesDeCalculo(prm_Almacen, noCalculo, ClasesABC, ClasesHueco);
        ClasesAlmacen := prm_Almacen;
        ClasesCalculo := noCalculo;
        ClasesLeidas := true;
    end;

    var
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        // Una instancia para toda la carga: guarda lo leído de cada producto.
        cUM: Codeunit "Unidades Producto SGA";
        // Clases ABC ya leídas (LeerClasesABC): de qué almacén y cálculo son.
        ClasesABC: Dictionary of [Code[20], Integer];
        ClasesHueco: Dictionary of [Code[20], Integer];
        ClasesAlmacen: Code[10];
        ClasesCalculo: Integer;
        ClasesLeidas: Boolean;
}
