namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;

/// <summary>
/// Codeunit Gestion Mapa SGA (ID 51102).
/// Construcción y renderizado del mapa visual de almacén sobre el Bin estándar.
///
/// El mapa deduce la topología del propio código de ubicación, con el formato
/// nave-estantería-columna-altura que genera Cod. "Gestion Ubicaciones SGA" (A-01-15-3).
/// Las ubicaciones cuyo código no sigue ese formato no se dibujan: el mapa es una vista de
/// naves ordenadas, y un código libre no tiene posición en la rejilla.
/// </summary>
codeunit 51102 "Gestion Mapa SGA"
{
    Access = Public;

    /// <summary>
    /// Rellena el buffer de la rejilla con las ubicaciones del almacén y devuelve la última
    /// columna encontrada, para que la página avise si no caben todas.
    /// El buffer lo pasa la página: es temporal y cada página tiene su propia instancia.
    /// </summary>
    procedure ConstruirMapa(var prm_Buffer: Record "Buffer Mapa SGA"; prm_Almacen: Code[10]; prm_Nave: Code[1]) maxColumnasEncontradas: Integer
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        nave: Code[1];
        estanteria: Code[2];
        altura: Code[1];
        columna: Integer;
        resumen: Text;
        estilo: Text;
    begin
        prm_Buffer.Reset();
        prm_Buffer.DeleteAll();

        if prm_Almacen = '' then
            exit(0);

        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        if not rUbicacionSGA.FindSet() then
            exit(0);

        repeat
            if TrocearCodigo(rUbicacionSGA."Cod. Bin", nave, estanteria, columna, altura) then
                if (prm_Nave = '') or (nave = prm_Nave) then begin
                    if columna > maxColumnasEncontradas then
                        maxColumnasEncontradas := columna;

                    // Más allá de la rejilla no se pinta, pero sí se ha contado arriba
                    // para que la página pueda avisar de que la nave no cabe entera.
                    if columna <= MaximoColumnasRejilla() then begin
                        SituarFila(prm_Buffer, prm_Almacen, nave, estanteria, altura);
                        Pintar(rUbicacionSGA, resumen, estilo);
                        prm_Buffer.FijarColumna(columna, resumen, estilo);
                        prm_Buffer.Modify();
                    end;
                end;
        until rUbicacionSGA.Next() = 0;

        prm_Buffer.Reset();
    end;

    /// <summary>
    /// Abre el contenido de la ubicación que representa una celda de la rejilla.
    /// </summary>
    procedure AbrirContenidoCelda(var prm_Buffer: Record "Buffer Mapa SGA"; prm_Columna: Integer)
    var
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        rContenido.SetRange("Cod. Almacen", prm_Buffer."Cod. Almacen");
        rContenido.SetRange("Cod. Bin", CodUbicacionCelda(prm_Buffer."Cod. Nave", prm_Buffer."Cod. Estanteria",
                                                          prm_Columna, prm_Buffer."Cod. Altura"));
        Page.Run(Page::"Contenido Ubicaciones SGA", rContenido);
    end;

    /// <summary>
    /// Reconstruye el código de ubicación de una celda: A-01-15-3.
    /// </summary>
    procedure CodUbicacionCelda(prm_Nave: Code[1]; prm_Estanteria: Code[2]; prm_Columna: Integer; prm_Altura: Code[1]): Code[20]
    begin
        exit(CopyStr(prm_Nave + '-' + prm_Estanteria + '-' + DosDigitos(prm_Columna) + '-' + prm_Altura, 1, 20));
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
    /// Trocea un código nave-estantería-columna-altura. Devuelve false si el código no sigue
    /// el formato, para que el llamante lo descarte en lugar de dibujarlo en una celda falsa.
    /// </summary>
    /// <summary>
    /// Devuelve las ubicaciones del almacén en JSON, para el mapa 3D.
    /// Cada elemento lleva las coordenadas físicas que el lienzo necesita para colocar el
    /// cubo y el estado con el que lo pinta:
    ///   b = código de ubicación, d = descripción, n = nave,
    ///   e = estantería, c = columna, a = altura,
    ///   s = estado (0 vacía, 1 parcial, 2 llena, 3 bloqueada), o = % de ocupación,
    ///   l = líneas de contenido, k = contenido (solo si tiene; ver ContenidoParaMapa).
    /// Las claves son cortas porque el JSON viaja entero al navegador y una nave grande
    /// son más de mil ubicaciones.
    /// </summary>
    procedure DatosMapa3D(prm_Almacen: Code[10]; prm_Nave: Code[1]; prm_Estanteria: Code[2]): Text
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        lista: JsonArray;
        elemento: JsonObject;
        salida: Text;
        nave: Code[1];
        estanteria: Code[2];
        altura: Code[1];
        columna: Integer;
        numEstanteria: Integer;
        numAltura: Integer;
    begin
        if prm_Almacen = '' then
            exit('[]');

        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        if not rUbicacionSGA.FindSet() then
            exit('[]');

        repeat
            if TrocearCodigo(rUbicacionSGA."Cod. Bin", nave, estanteria, columna, altura) then
                if ((prm_Nave = '') or (nave = prm_Nave)) and
                   ((prm_Estanteria = '') or (estanteria = prm_Estanteria))
                then
                    // Sin número de estantería o de altura no hay dónde colocar el cubo.
                    if Evaluate(numEstanteria, estanteria) and Evaluate(numAltura, altura) then begin
                        rUbicacionSGA.CalcFields("Cantidad Base", "Lineas Contenido");

                        Clear(elemento);
                        elemento.Add('b', rUbicacionSGA."Cod. Bin");
                        elemento.Add('d', rUbicacionSGA.Descripcion);
                        elemento.Add('n', nave);
                        elemento.Add('e', numEstanteria);
                        elemento.Add('c', columna);
                        elemento.Add('a', numAltura);
                        elemento.Add('s', EstadoNumerico(rUbicacionSGA));
                        elemento.Add('o', Round(rUbicacionSGA."% Ocupacion", 1));
                        // Líneas de contenido: el lienzo solo deja arrastrar un traslado desde
                        // una ubicación que tenga algo, y el color no basta (bloqueada tapa a llena).
                        elemento.Add('l', rUbicacionSGA."Lineas Contenido");
                        if rUbicacionSGA."Lineas Contenido" > 0 then
                            elemento.Add('k', ContenidoParaMapa(rUbicacionSGA));
                        lista.Add(elemento);
                    end;
        until rUbicacionSGA.Next() = 0;

        lista.WriteTo(salida);
        exit(salida);
    end;

    /// <summary>
    /// Lo que hay en una ubicación, para la ficha flotante del mapa 3D:
    ///   p = producto, t = descripción, l = lote, f = caducidad (aaaa-mm-dd o vacía),
    ///   q = cantidad, u = unidad, x = bloqueado,
    ///   g = palé por defecto del producto (ficha del producto), gf = cuántas "u" lleva ese palé.
    ///
    /// La cantidad no se enseña en la unidad en que se registró, sino como se cuenta en el
    /// almacén (ver UnidadParaMostrar): en un hueco de palé, el palé si está completo y, si no
    /// llega al 100 %, el número de cajas; en un hueco de unidades sueltas, botellas; en el
    /// resto, cajas. Con el palé completo no se manda "gf": diría "1 PALE/palé".
    ///
    /// Se envía con el resto del mapa y no se pide al pasar el ratón: una ida y vuelta a BC por
    /// cada bloque haría la ficha lenta. Se limita a las primeras líneas para que un hueco
    /// mixto con muchas referencias no engorde el JSON; el lienzo dice cuántas faltan con "l".
    /// </summary>
    local procedure ContenidoParaMapa(var prm_Ubicacion: Record "Ubicacion SGA"): JsonArray
    var
        rContenido: Record "Contenido Ubicacion SGA";
        rItem: Record Item;
        rItemUM: Record "Item Unit of Measure";
        lineas: JsonArray;
        linea: JsonObject;
        umMostrar: Code[10];
        factorMostrar: Decimal;
        enviadas: Integer;
        MaxLineas: Integer;
    begin
        MaxLineas := 8;
        rContenido.SetRange("Cod. Almacen", prm_Ubicacion."Cod. Almacen");
        rContenido.SetRange("Cod. Bin", prm_Ubicacion."Cod. Bin");
        if rContenido.FindSet() then
            repeat
                Clear(linea);
                if not rItem.Get(rContenido."No. Producto") then
                    Clear(rItem);
                UnidadParaMostrar(prm_Ubicacion, rItem, rContenido."Cantidad Base", umMostrar, factorMostrar);

                linea.Add('p', rContenido."No. Producto");
                linea.Add('t', CopyStr(rItem.Description, 1, 60));
                linea.Add('l', rContenido."No. Lote");
                if rContenido."Fecha Caducidad" <> 0D then
                    linea.Add('f', Format(rContenido."Fecha Caducidad", 0, 9))
                else
                    linea.Add('f', '');
                if umMostrar <> '' then begin
                    linea.Add('q', Round(rContenido."Cantidad Base" / factorMostrar, 0.01));
                    linea.Add('u', umMostrar);
                end else begin
                    linea.Add('q', rContenido.Cantidad);
                    linea.Add('u', rContenido."Cod. Unidad Medida");
                end;
                linea.Add('x', rContenido.Bloqueado);
                // Tipo de palé del producto (el de su ficha) y cuánto lleva en la misma unidad
                // que la cantidad, para que la ficha diga "45 CAJA12 · PALE (45 CAJA12/palé)".
                linea.Add('g', rItem."Cod. Pale por Defecto");
                if (rItem."Cod. Pale por Defecto" <> '') and (umMostrar <> '') and (umMostrar <> rItem."Cod. Pale por Defecto") and
                   rItemUM.Get(rContenido."No. Producto", rItem."Cod. Pale por Defecto")
                then
                    linea.Add('gf', Round(rItemUM."Qty. per Unit of Measure" / factorMostrar, 0.01))
                else
                    linea.Add('gf', 0);
                lineas.Add(linea);
                enviadas += 1;
            until (rContenido.Next() = 0) or (enviadas >= MaxLineas);

        exit(lineas);
    end;

    /// <summary>
    /// Unidad en la que se enseña una línea de contenido y sus unidades base:
    ///   - en un hueco de palé, el palé si la línea llena el palé al 100 %; si no, cajas;
    ///   - en un hueco de unidades sueltas, la base (botellas);
    ///   - en el resto, la unidad de venta (la caja) si es mayor que la base, y si no, la base.
    /// En blanco si el producto no se reconoce.
    /// </summary>
    local procedure UnidadParaMostrar(var prm_Ubicacion: Record "Ubicacion SGA"; var prm_Item: Record Item; prm_CantidadBase: Decimal; var prm_UM: Code[10]; var prm_Factor: Decimal)
    var
        rItemUM: Record "Item Unit of Measure";
    begin
        prm_UM := '';
        prm_Factor := 0;
        if prm_Item."No." = '' then
            exit;

        // Hueco de palé con el palé completo: se enseña como palé. Si no llega, en cajas.
        if prm_Ubicacion."Tipo UM Admitida" = prm_Ubicacion."Tipo UM Admitida"::Pale then
            if prm_Item."Cod. Pale por Defecto" <> '' then
                if rItemUM.Get(prm_Item."No.", prm_Item."Cod. Pale por Defecto") then
                    if (rItemUM."Qty. per Unit of Measure" > 0) and (prm_CantidadBase >= rItemUM."Qty. per Unit of Measure") then begin
                        prm_UM := rItemUM.Code;
                        prm_Factor := rItemUM."Qty. per Unit of Measure";
                        exit;
                    end;

        if prm_Ubicacion."Tipo UM Admitida" <> prm_Ubicacion."Tipo UM Admitida"::Unidad then
            if prm_Item."Sales Unit of Measure" <> '' then
                if rItemUM.Get(prm_Item."No.", prm_Item."Sales Unit of Measure") then
                    if rItemUM."Qty. per Unit of Measure" > 1 then begin
                        prm_UM := rItemUM.Code;
                        prm_Factor := rItemUM."Qty. per Unit of Measure";
                        exit;
                    end;

        prm_UM := prm_Item."Base Unit of Measure";
        prm_Factor := 1;
    end;

    /// <summary>
    /// Traduce el estado de la ubicación al índice de color que entiende el lienzo.
    /// </summary>
    local procedure EstadoNumerico(var prm_Ubicacion: Record "Ubicacion SGA"): Integer
    begin
        if prm_Ubicacion.Bloqueada then
            exit(3);

        case prm_Ubicacion."Estado SGA" of
            prm_Ubicacion."Estado SGA"::Bloqueada:
                exit(3);
            prm_Ubicacion."Estado SGA"::Llena:
                exit(2);
            prm_Ubicacion."Estado SGA"::Parcial:
                exit(1);
            else
                exit(0);
        end;
    end;

    /// <summary>
    /// Parte un código Nave-Estantería-Columna-Altura (p. ej. A-01-05-2). False si no tiene
    /// esa forma. Lo usa también el análisis ABC para saber la altura de cada hueco.
    /// </summary>
    procedure TrocearCodigo(prm_Codigo: Code[20]; var prm_Nave: Code[1]; var prm_Estanteria: Code[2]; var prm_Columna: Integer; var prm_Altura: Code[1]): Boolean
    var
        partes: List of [Text];
        texto: Text;
    begin
        texto := prm_Codigo;
        partes := texto.Split('-');
        if partes.Count() <> 4 then
            exit(false);

        if not Evaluate(prm_Columna, partes.Get(3)) then
            exit(false);

        prm_Nave := CopyStr(partes.Get(1), 1, MaxStrLen(prm_Nave));
        prm_Estanteria := CopyStr(partes.Get(2), 1, MaxStrLen(prm_Estanteria));
        prm_Altura := CopyStr(partes.Get(4), 1, MaxStrLen(prm_Altura));
        exit(true);
    end;

    /// <summary>
    /// Deja el buffer posicionado en la fila de esa estantería y altura, creándola si hace falta.
    /// </summary>
    local procedure SituarFila(var prm_Buffer: Record "Buffer Mapa SGA"; prm_Almacen: Code[10]; prm_Nave: Code[1]; prm_Estanteria: Code[2]; prm_Altura: Code[1])
    begin
        prm_Buffer.Reset();
        prm_Buffer.SetRange("Cod. Almacen", prm_Almacen);
        prm_Buffer.SetRange("Cod. Nave", prm_Nave);
        prm_Buffer.SetRange("Cod. Estanteria", prm_Estanteria);
        prm_Buffer.SetRange("Cod. Altura", prm_Altura);
        if prm_Buffer.FindFirst() then begin
            prm_Buffer.Reset();
            exit;
        end;

        prm_Buffer.Reset();
        prm_Buffer.Init();
        prm_Buffer."Cod. Almacen" := prm_Almacen;
        prm_Buffer."Cod. Nave" := prm_Nave;
        prm_Buffer."Cod. Estanteria" := prm_Estanteria;
        prm_Buffer."Cod. Altura" := prm_Altura;
        prm_Buffer.Orden := OrdenFila(prm_Altura);
        prm_Buffer.Insert();
    end;

    /// <summary>
    /// Orden de la fila dentro de la estantería. Se invierte la altura para que la rejilla
    /// se lea como se ve la estantería de frente: la altura más alta arriba.
    /// </summary>
    local procedure OrdenFila(prm_Altura: Code[1]): Integer
    var
        altura: Integer;
    begin
        if not Evaluate(altura, prm_Altura) then
            altura := 0;
        exit(100 - altura);
    end;

    /// <summary>
    /// Texto y color de la celda de una ubicación.
    /// </summary>
    local procedure Pintar(var prm_Ubicacion: Record "Ubicacion SGA"; var prm_Resumen: Text; var prm_Estilo: Text)
    var
        rContenido: Record "Contenido Ubicacion SGA";
        lineas: Integer;
    begin
        prm_Estilo := prm_Ubicacion.EstiloEstado();

        if prm_Ubicacion.Bloqueada then begin
            prm_Resumen := 'BLOQ';
            exit;
        end;

        rContenido.SetRange("Cod. Almacen", prm_Ubicacion."Cod. Almacen");
        rContenido.SetRange("Cod. Bin", prm_Ubicacion."Cod. Bin");
        lineas := rContenido.Count();

        case lineas of
            0:
                prm_Resumen := '-';
            1:
                begin
                    rContenido.FindFirst();
                    prm_Resumen := rContenido."No. Producto";
                end;
            else
                prm_Resumen := Format(lineas) + ' prod';
        end;
    end;

    /// <summary>
    /// Formatea un entero a dos dígitos con cero a la izquierda. No se usa PadStr porque
    /// en AL rellena por la derecha: PadStr('5', 2, '0') devuelve '50', no '05'.
    /// </summary>
    local procedure DosDigitos(prm_Valor: Integer): Text
    var
        texto: Text;
    begin
        texto := Format(prm_Valor);
        if StrLen(texto) < 2 then
            exit('0' + texto);
        exit(texto);
    end;
}
