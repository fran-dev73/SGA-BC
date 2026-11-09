namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;

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
    /// </summary>
    procedure ConstruirMapa(var prm_Buffer: Record "Buffer Mapa SGA"; prm_Almacen: Code[10]) maxEstanteriaEncontrada: Integer
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        pasillo: Integer;
        estanteria: Integer;
        altura: Integer;
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
            if cUbicaciones.TrocearCodigo(rUbicacionSGA."Cod. Bin", pasillo, estanteria, altura) then begin
                if estanteria > maxEstanteriaEncontrada then
                    maxEstanteriaEncontrada := estanteria;

                // Más allá de la rejilla no se pinta, pero sí se ha contado arriba
                // para que la página pueda avisar de que el pasillo no cabe entero.
                if estanteria <= MaximoColumnasRejilla() then begin
                    SituarFila(prm_Buffer, prm_Almacen, pasillo, altura);
                    Pintar(rUbicacionSGA, resumen, estilo);
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
        rContenido: Record "Contenido Ubicacion SGA";
    begin
        rContenido.SetRange("Cod. Almacen", prm_Buffer."Cod. Almacen");
        rContenido.SetRange("Cod. Bin", cUbicaciones.ComponerCodigoUbicacion(prm_Buffer.Pasillo, prm_Columna, prm_Buffer.Altura));
        Page.Run(Page::"Contenido Ubicaciones SGA", rContenido);
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
    ///   b = código de ubicación, d = descripción, z = zona,
    ///   e = pasillo, c = estantería, a = altura (los tres como número),
    ///   s = estado (0 vacía, 1 parcial, 2 llena, 3 bloqueada, 4 con contenido sin medir),
    ///   o = % de ocupación, redondeado hacia abajo (-1 si no se puede medir),
    ///   m = por qué no se puede medir (solo si no se puede),
    ///   l = líneas de contenido, k = contenido (solo si tiene; ver ContenidoParaMapa),
    ///   y, solo si tiene contenido, de todas sus líneas: pp = productos (sin repetir, para
    ///   buscar), fc = caducidad más próxima (aaaa-mm-dd, vacía si ninguna lleva) y
    ///   r = mejor clase ABC de sus productos en el último cálculo (1 A, 2 B, 3 C, 0 sin clase).
    /// Las claves son cortas porque el JSON viaja entero al navegador y un almacén grande
    /// son más de mil ubicaciones. Con prm_Pasillo distinto de 0, solo las de ese pasillo.
    ///
    /// El % se redondea hacia abajo para que no diga 100 % de una ubicación que aún tiene
    /// hueco. No se puede medir sin capacidad declarada, ni si algún producto de dentro no tiene
    /// palé en su ficha: su contenido se contaría en unidades base como si cada una fuera un palé.
    /// </summary>
    procedure DatosMapa3D(prm_Almacen: Code[10]; prm_Zona: Code[10]; prm_Pasillo: Integer): Text
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        cABC: Codeunit "Analisis ABC SGA";
        lista: JsonArray;
        elemento: JsonObject;
        productos: JsonArray;
        sinUnidad: Dictionary of [Text, Boolean];
        clasesABC: Dictionary of [Code[20], Integer];
        salida: Text;
        motivoSinMedir: Text;
        caducidad: Date;
        claseABC: Integer;
        pasillo: Integer;
        estanteria: Integer;
        altura: Integer;
        SinCapacidadLbl: Label 'Sin capacidad declarada: no se puede medir cuánto ocupa. Indique la capacidad en la ficha de la ubicación.';
    begin
        if prm_Almacen = '' then
            exit('[]');

        rUbicacionSGA.SetRange("Cod. Almacen", prm_Almacen);
        if prm_Zona <> '' then
            rUbicacionSGA.SetRange("Cod. Zona SGA", prm_Zona);
        if not rUbicacionSGA.FindSet() then
            exit('[]');

        // La clase de cada producto se lee una vez para todo el mapa.
        cABC.ClasesUltimoCalculo(prm_Almacen, clasesABC);

        repeat
            // Sin pasillo, estantería y altura no hay dónde colocar el cubo.
            if cUbicaciones.TrocearCodigo(rUbicacionSGA."Cod. Bin", pasillo, estanteria, altura) then
                if (prm_Pasillo = 0) or (pasillo = prm_Pasillo) then begin
                    rUbicacionSGA.CalcFields("Cantidad Base", "Lineas Contenido");

                    Clear(elemento);
                    elemento.Add('b', rUbicacionSGA."Cod. Bin");
                    elemento.Add('d', rUbicacionSGA.Descripcion);
                    elemento.Add('z', rUbicacionSGA."Cod. Zona SGA");
                    elemento.Add('e', pasillo);
                    elemento.Add('c', estanteria);
                    elemento.Add('a', altura);
                    // Líneas de contenido: el lienzo solo deja arrastrar un traslado desde
                    // una ubicación que tenga algo, y el color no basta (bloqueada tapa a llena).
                    elemento.Add('l', rUbicacionSGA."Lineas Contenido");
                    motivoSinMedir := '';
                    if rUbicacionSGA."Lineas Contenido" > 0 then begin
                        elemento.Add('k', ContenidoParaMapa(rUbicacionSGA, sinUnidad, clasesABC, motivoSinMedir, productos, caducidad, claseABC));
                        elemento.Add('pp', productos);
                        if caducidad <> 0D then
                            elemento.Add('fc', Format(caducidad, 0, 9))
                        else
                            elemento.Add('fc', '');
                        elemento.Add('r', claseABC);
                        if rUbicacionSGA."Capacidad Uds." <= 0 then
                            motivoSinMedir := SinCapacidadLbl;
                    end;
                    elemento.Add('s', EstadoNumerico(rUbicacionSGA, motivoSinMedir <> ''));
                    if motivoSinMedir <> '' then begin
                        elemento.Add('o', -1);
                        elemento.Add('m', motivoSinMedir);
                    end else
                        elemento.Add('o', Round(rUbicacionSGA."% Ocupacion", 1, '<'));
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
    /// almacén (ver UnidadParaMostrar): el palé si está completo y, si no llega al 100 %, el
    /// número de cajas. Con el palé completo no se manda "gf": diría "1 PALE/palé".
    ///
    /// Se envía con el resto del mapa y no se pide al pasar el ratón: una ida y vuelta a BC por
    /// cada bloque haría la ficha lenta. Se limita a las primeras líneas para que un hueco
    /// mixto con muchas referencias no engorde el JSON; el lienzo dice cuántas faltan con "l".
    ///
    /// Mira además todas las líneas, no solo las enviadas, para saber si la ocupación se puede
    /// medir: con capacidad declarada (en palés), cada producto tiene que tener palé en su
    /// ficha. Si no, deja el porqué en prm_MotivoSinMedir (el primer producto que falla).
    /// prm_SinUnidad guarda lo ya mirado de cada producto en todo el mapa.
    ///
    /// De todas las líneas devuelve también, para colorear y buscar: los productos sin repetir
    /// (prm_Productos), la caducidad más próxima (prm_Caducidad, 0D si ninguna lleva) y la mejor
    /// clase ABC de sus productos según prm_ClasesABC (prm_ClaseABC, 0 si ninguno tiene).
    /// </summary>
    local procedure ContenidoParaMapa(var prm_Ubicacion: Record "Ubicacion SGA"; var prm_SinUnidad: Dictionary of [Text, Boolean]; var prm_ClasesABC: Dictionary of [Code[20], Integer]; var prm_MotivoSinMedir: Text; var prm_Productos: JsonArray; var prm_Caducidad: Date; var prm_ClaseABC: Integer): JsonArray
    var
        rContenido: Record "Contenido Ubicacion SGA";
        cUM: Codeunit "Unidades Producto SGA";
        lineas: JsonArray;
        vistos: List of [Code[20]];
        enviadas: Integer;
        MaxLineas: Integer;
        clase: Integer;
        falta: Boolean;
        medirEnPales: Boolean;
        SinPaleLbl: Label 'El producto %1 no tiene palé en su ficha ("Cód. palé por defecto"): no se puede medir cuánto ocupa.', Comment = '%1 = producto';
    begin
        MaxLineas := 8;
        enviadas := 0;
        Clear(prm_Productos);
        prm_Caducidad := 0D;
        prm_ClaseABC := 0;
        medirEnPales := prm_Ubicacion."Capacidad Uds." > 0;
        rContenido.SetRange("Cod. Almacen", prm_Ubicacion."Cod. Almacen");
        rContenido.SetRange("Cod. Bin", prm_Ubicacion."Cod. Bin");
        if rContenido.FindSet() then
            repeat
                if medirEnPales and (prm_MotivoSinMedir = '') then begin
                    if not prm_SinUnidad.Get(rContenido."No. Producto", falta) then begin
                        falta := cUM.UMPale(rContenido."No. Producto") = '';
                        prm_SinUnidad.Add(rContenido."No. Producto", falta);
                    end;
                    if falta then
                        prm_MotivoSinMedir := StrSubstNo(SinPaleLbl, rContenido."No. Producto");
                end;
                if enviadas < MaxLineas then begin
                    lineas.Add(LineaMapa(rContenido));
                    enviadas += 1;
                end;
                if not vistos.Contains(rContenido."No. Producto") then begin
                    vistos.Add(rContenido."No. Producto");
                    prm_Productos.Add(rContenido."No. Producto");
                    // A (1) es la mejor; 0 = sin clase, no cuenta.
                    if prm_ClasesABC.Get(rContenido."No. Producto", clase) then
                        if (clase > 0) and ((prm_ClaseABC = 0) or (clase < prm_ClaseABC)) then
                            prm_ClaseABC := clase;
                end;
                if rContenido."Fecha Caducidad" <> 0D then
                    if (prm_Caducidad = 0D) or (rContenido."Fecha Caducidad" < prm_Caducidad) then
                        prm_Caducidad := rContenido."Fecha Caducidad";
            until rContenido.Next() = 0;

        exit(lineas);
    end;

    /// <summary>
    /// Una línea de contenido en el formato de la ficha flotante (ver ContenidoParaMapa).
    /// </summary>
    local procedure LineaMapa(var prm_Contenido: Record "Contenido Ubicacion SGA"): JsonObject
    var
        rItem: Record Item;
        rItemUM: Record "Item Unit of Measure";
        linea: JsonObject;
        umMostrar: Code[10];
        factorMostrar: Decimal;
    begin
        if not rItem.Get(prm_Contenido."No. Producto") then
            Clear(rItem);
        UnidadParaMostrar(rItem, prm_Contenido."Cantidad Base", umMostrar, factorMostrar);

        linea.Add('p', prm_Contenido."No. Producto");
        linea.Add('t', CopyStr(rItem.Description, 1, 60));
        linea.Add('l', prm_Contenido."No. Lote");
        if prm_Contenido."Fecha Caducidad" <> 0D then
            linea.Add('f', Format(prm_Contenido."Fecha Caducidad", 0, 9))
        else
            linea.Add('f', '');
        if umMostrar <> '' then begin
            linea.Add('q', Round(prm_Contenido."Cantidad Base" / factorMostrar, 0.01));
            linea.Add('u', umMostrar);
        end else begin
            linea.Add('q', prm_Contenido.Cantidad);
            linea.Add('u', prm_Contenido."Cod. Unidad Medida");
        end;
        linea.Add('x', prm_Contenido.Bloqueado);
        // Tipo de palé del producto (el de su ficha) y cuánto lleva en la misma unidad
        // que la cantidad, para que la ficha diga "45 CAJA12 · PALE (45 CAJA12/palé)".
        linea.Add('g', rItem."Cod. Pale por Defecto");
        if (rItem."Cod. Pale por Defecto" <> '') and (umMostrar <> '') and (umMostrar <> rItem."Cod. Pale por Defecto") and
           rItemUM.Get(prm_Contenido."No. Producto", rItem."Cod. Pale por Defecto")
        then
            linea.Add('gf', Round(rItemUM."Qty. per Unit of Measure" / factorMostrar, 0.01))
        else
            linea.Add('gf', 0);
        exit(linea);
    end;

    /// <summary>
    /// Unidad en la que se enseña una línea de contenido y sus unidades base: el palé si la
    /// línea llena el palé al 100 %; si no, la unidad de venta (la caja) si es mayor que la base,
    /// y si no, la base. En blanco si el producto no se reconoce.
    /// </summary>
    local procedure UnidadParaMostrar(var prm_Item: Record Item; prm_CantidadBase: Decimal; var prm_UM: Code[10]; var prm_Factor: Decimal)
    var
        rItemUM: Record "Item Unit of Measure";
    begin
        prm_UM := '';
        prm_Factor := 0;
        if prm_Item."No." = '' then
            exit;

        // El palé completo se enseña como palé. Si no llega, en cajas.
        if prm_Item."Cod. Pale por Defecto" <> '' then
            if rItemUM.Get(prm_Item."No.", prm_Item."Cod. Pale por Defecto") then
                if (rItemUM."Qty. per Unit of Measure" > 0) and (prm_CantidadBase >= rItemUM."Qty. per Unit of Measure") then begin
                    prm_UM := rItemUM.Code;
                    prm_Factor := rItemUM."Qty. per Unit of Measure";
                    exit;
                end;

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
    /// Traduce el estado de la ubicación al índice de color que entiende el lienzo. Con
    /// contenido que no se puede medir (prm_SinMedir), 4: no se sabe si está llena.
    /// </summary>
    local procedure EstadoNumerico(var prm_Ubicacion: Record "Ubicacion SGA"; prm_SinMedir: Boolean): Integer
    begin
        if prm_Ubicacion.Bloqueada then
            exit(3);
        if prm_SinMedir and (prm_Ubicacion."Estado SGA" <> prm_Ubicacion."Estado SGA"::Bloqueada) then
            exit(4);

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

    var
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
}
