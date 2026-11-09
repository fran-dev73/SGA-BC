namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;

/// <summary>
/// Codeunit Analisis ABC SGA (ID 51107).
/// Clasifica los productos por rotación (A, B, C) y los huecos por calidad, y guarda el
/// resultado en "Calculo ABC SGA" / "Clasificacion ABC SGA". Solo observa: no mueve nada ni
/// cambia cómo se ubica. Sirve para decidir con datos si merece la pena ubicar por rotación
/// (ver SGA/Otros/DOCUMENTACION_TECNICA_SGA.md, parte II).
///
/// Productos: los que han tenido ventas en los últimos "Dias Analisis ABC" días o tienen palés
/// en SGA. La rotación se mide en palés salidos (ventas netas en UM base entre lo que lleva el
/// palé del producto), porque con palés completos cada palé es un viaje de carretilla. De más a
/// menos salidas, son A hasta sumar "Corte ABC Clase A" % de los palés, B hasta "Corte ABC
/// Clase B" % y el resto C. Sin ventas, C.
///
/// Huecos: los de Picking y Almacenamiento no bloqueados, del mejor al peor: primero por altura (el
/// nivel más bajo es el mejor) y luego por "Secuencia picking". Se reparten en clases según los
/// palés que hay de cada clase de producto: los primeros tantos huecos como palés A hay son A,
/// los siguientes tantos como palés B son B, y el resto C. Así cada clase tiene justo el sitio
/// que necesita hoy.
///
/// Se puede lanzar desde la cola de proyectos: calcula el almacén por defecto de la configuración.
/// </summary>
codeunit 51107 "Analisis ABC SGA"
{
    trigger OnRun()
    var
        rConfig: Record "Config. SGA";
    begin
        rConfig.ObtenerConfig();
        rConfig.TestField("Almacen por Defecto");
        Calcular(rConfig."Almacen por Defecto");
    end;

    /// <summary>
    /// Hace un cálculo nuevo para el almacén y devuelve su número.
    /// </summary>
    procedure Calcular(prm_Almacen: Code[10]): Integer
    var
        rConfig: Record "Config. SGA";
        rCalculo: Record "Calculo ABC SGA";
        PalesProductoHueco: Dictionary of [Text, Boolean];
        ClaseHueco: Dictionary of [Code[20], Integer];
        AlmacenObligatorioErr: Label 'Indique el almacén que se quiere analizar.';
        CorteBMenorQueAErr: Label 'El corte de la clase B (%1 %) tiene que ser mayor o igual que el de la clase A (%2 %): los cortes son acumulados y la B empieza donde acaba la A.', Comment = '%1 = corte B, %2 = corte A';
    begin
        if prm_Almacen = '' then
            Error(AlmacenObligatorioErr);

        rConfig.ObtenerConfig();
        if rConfig."Dias Analisis ABC" <= 0 then
            rConfig."Dias Analisis ABC" := 90;
        if rConfig."Corte ABC Clase A" <= 0 then
            rConfig."Corte ABC Clase A" := 80;
        if rConfig."Corte ABC Clase B" <= 0 then
            rConfig."Corte ABC Clase B" := 95;
        if rConfig."Corte ABC Clase B" < rConfig."Corte ABC Clase A" then
            Error(CorteBMenorQueAErr, rConfig."Corte ABC Clase B", rConfig."Corte ABC Clase A");

        CrearCabecera(rCalculo, prm_Almacen, rConfig);

        CargarVentas(rCalculo);
        CargarPalesEnAlmacen(rCalculo, PalesProductoHueco);
        Clasificar(rCalculo);
        ClasificarHuecos(rCalculo, ClaseHueco);
        CompararUbicacion(rCalculo, PalesProductoHueco, ClaseHueco);
        CompararConAnterior(rCalculo);

        rCalculo.Modify();
        exit(rCalculo."No.");
    end;

    /// <summary>
    /// Clase (A, B o C, como entero de "Clase ABC SGA") de cada producto en el último cálculo
    /// del almacén. Vacío si no hay ningún cálculo. Lo usa el mapa para colorear por rotación.
    /// </summary>
    procedure ClasesUltimoCalculo(prm_Almacen: Code[10]; var prm_Clases: Dictionary of [Code[20], Integer])
    var
        rCalculo: Record "Calculo ABC SGA";
        rLinea: Record "Clasificacion ABC SGA";
    begin
        Clear(prm_Clases);
        rCalculo.SetCurrentKey("Cod. Almacen", "No.");
        rCalculo.SetRange("Cod. Almacen", prm_Almacen);
        if not rCalculo.FindLast() then
            exit;

        rLinea.SetRange("No. Calculo", rCalculo."No.");
        rLinea.SetLoadFields("No. Producto", Clase);
        if rLinea.FindSet() then
            repeat
                if not prm_Clases.ContainsKey(rLinea."No. Producto") then
                    prm_Clases.Add(rLinea."No. Producto", rLinea.Clase.AsInteger());
            until rLinea.Next() = 0;
    end;

    local procedure CrearCabecera(var prm_Calculo: Record "Calculo ABC SGA"; prm_Almacen: Code[10]; prm_Config: Record "Config. SGA")
    var
        rUltimo: Record "Calculo ABC SGA";
    begin
        if rUltimo.FindLast() then;

        prm_Calculo.Init();
        prm_Calculo."No." := rUltimo."No." + 1;
        prm_Calculo."Cod. Almacen" := prm_Almacen;
        prm_Calculo."Fecha Calculo" := CurrentDateTime();
        prm_Calculo.Usuario := CopyStr(UserId(), 1, MaxStrLen(prm_Calculo.Usuario));
        prm_Calculo."Fecha Hasta" := Today();
        prm_Calculo."Fecha Desde" := Today() - prm_Config."Dias Analisis ABC" + 1;
        prm_Calculo."Corte A" := prm_Config."Corte ABC Clase A";
        prm_Calculo."Corte B" := prm_Config."Corte ABC Clase B";
        prm_Calculo.Insert();
    end;

    /// <summary>
    /// Una línea por producto vendido en el periodo, con sus ventas netas (las devoluciones
    /// restan) pasadas a palés.
    /// </summary>
    local procedure CargarVentas(var prm_Calculo: Record "Calculo ABC SGA")
    var
        rMovProducto: Record "Item Ledger Entry";
        ventas: Dictionary of [Code[20], Decimal];
        producto: Code[20];
        cantidad: Decimal;
    begin
        rMovProducto.SetRange("Entry Type", rMovProducto."Entry Type"::Sale);
        rMovProducto.SetRange("Posting Date", prm_Calculo."Fecha Desde", prm_Calculo."Fecha Hasta");
        rMovProducto.SetRange("Location Code", prm_Calculo."Cod. Almacen");
        rMovProducto.SetLoadFields("Item No.", Quantity);
        if rMovProducto.FindSet() then
            repeat
                if ventas.Get(rMovProducto."Item No.", cantidad) then;
                // En las ventas la cantidad va en negativo.
                ventas.Set(rMovProducto."Item No.", cantidad - rMovProducto.Quantity);
                cantidad := 0;
            until rMovProducto.Next() = 0;

        foreach producto in ventas.Keys() do
            AnotarVentas(prm_Calculo, producto, ventas.Get(producto));
    end;

    local procedure AnotarVentas(var prm_Calculo: Record "Calculo ABC SGA"; prm_Producto: Code[20]; prm_CantidadBase: Decimal)
    var
        rLinea: Record "Clasificacion ABC SGA";
        cUM: Codeunit "Unidades Producto SGA";
    begin
        if prm_CantidadBase <= 0 then
            exit;

        NuevaLinea(prm_Calculo, prm_Producto, rLinea);
        rLinea."Cantidad Salida Base" := prm_CantidadBase;
        // Solo sale un palé que el producto tiene y que lleva más de una unidad base.
        rLinea."Unidad Pale" := cUM.UMPale(prm_Producto);
        if rLinea."Unidad Pale" <> '' then
            rLinea."Palets Salidos" := Round(prm_CantidadBase / cUM.FactorUM(prm_Producto, rLinea."Unidad Pale"), 0.1)
        else
            rLinea."Sin Unidad Pale" := true;
        rLinea.Insert();
    end;

    local procedure NuevaLinea(prm_Calculo: Record "Calculo ABC SGA"; prm_Producto: Code[20]; var prm_Linea: Record "Clasificacion ABC SGA")
    var
        rItem: Record Item;
    begin
        prm_Linea.Init();
        prm_Linea."No. Calculo" := prm_Calculo."No.";
        prm_Linea."No. Producto" := prm_Producto;
        prm_Linea."Cod. Almacen" := prm_Calculo."Cod. Almacen";
        if rItem.Get(prm_Producto) then
            prm_Linea.Descripcion := rItem.Description;
    end;

    /// <summary>
    /// Palés que hay ahora en huecos de Picking y Almacenamiento. Cada hueco es de un palé, así que se
    /// cuenta un palé por producto y hueco. Los productos con palés y sin ventas también entran:
    /// son los C que pueden estar ocupando huecos buenos.
    /// </summary>
    local procedure CargarPalesEnAlmacen(var prm_Calculo: Record "Calculo ABC SGA"; var prm_PalesProductoHueco: Dictionary of [Text, Boolean])
    var
        rContenido: Record "Contenido Ubicacion SGA";
        rUbicacion: Record "Ubicacion SGA";
        rLinea: Record "Clasificacion ABC SGA";
        clave: Text;
    begin
        rContenido.SetCurrentKey("Cod. Almacen", "Cod. Bin");
        rContenido.SetRange("Cod. Almacen", prm_Calculo."Cod. Almacen");
        rContenido.SetFilter(Cantidad, '>0');
        if not rContenido.FindSet() then
            exit;

        repeat
            clave := rContenido."No. Producto" + '|' + rContenido."Cod. Bin";
            if not prm_PalesProductoHueco.ContainsKey(clave) then
                if rUbicacion.Get(rContenido."Cod. Almacen", rContenido."Cod. Bin") then
                    if EsHuecoUtil(rUbicacion) then begin
                        prm_PalesProductoHueco.Add(clave, true);

                        if not rLinea.Get(prm_Calculo."No.", rContenido."No. Producto") then begin
                            NuevaLinea(prm_Calculo, rContenido."No. Producto", rLinea);
                            rLinea.Insert();
                        end;
                        rLinea."Palets en Almacen" += 1;
                        rLinea.Modify();
                    end;
        until rContenido.Next() = 0;
    end;

    /// <summary>
    /// Ordena de más a menos palés salidos y pone posición, porcentajes y clase. Un producto es
    /// de la clase en la que estaba el acumulado antes de sumarlo: el que cruza el corte del 80 %
    /// todavía es A.
    /// </summary>
    local procedure Clasificar(var prm_Calculo: Record "Calculo ABC SGA")
    var
        rLinea: Record "Clasificacion ABC SGA";
        acumulado: Decimal;
        acumuladoAntes: Decimal;
        salidasTop: Decimal;
        posicion: Integer;
    begin
        rLinea.SetRange("No. Calculo", prm_Calculo."No.");
        rLinea.CalcSums("Palets Salidos");
        prm_Calculo."Palets Salidos" := rLinea."Palets Salidos";
        prm_Calculo.Productos := rLinea.Count();
        // El 20 % de los productos, redondeando hacia arriba: con 7 productos, 2.
        prm_Calculo."Productos Top 20" := Round(prm_Calculo.Productos * 0.2, 1, '>');

        rLinea.SetCurrentKey("No. Calculo", "Palets Salidos");
        rLinea.Ascending(false);
        acumulado := 0;
        if not rLinea.FindSet() then
            exit;

        repeat
            posicion += 1;
            rLinea.Posicion := posicion;

            if prm_Calculo."Palets Salidos" > 0 then begin
                acumuladoAntes := acumulado;
                acumulado += rLinea."Palets Salidos";
                rLinea."% Salidas" := Round(rLinea."Palets Salidos" / prm_Calculo."Palets Salidos" * 100, 0.1);
                rLinea."% Acumulado" := Round(acumulado / prm_Calculo."Palets Salidos" * 100, 0.1);
            end;

            if rLinea."Palets Salidos" <= 0 then
                rLinea.Clase := rLinea.Clase::C
            else
                if acumuladoAntes / prm_Calculo."Palets Salidos" * 100 < prm_Calculo."Corte A" then
                    rLinea.Clase := rLinea.Clase::A
                else
                    if acumuladoAntes / prm_Calculo."Palets Salidos" * 100 < prm_Calculo."Corte B" then
                        rLinea.Clase := rLinea.Clase::B
                    else
                        rLinea.Clase := rLinea.Clase::C;

            case rLinea.Clase of
                rLinea.Clase::A:
                    prm_Calculo."Productos A" += 1;
                rLinea.Clase::B:
                    prm_Calculo."Productos B" += 1;
                rLinea.Clase::C:
                    prm_Calculo."Productos C" += 1;
            end;
            if rLinea."Sin Unidad Pale" then
                prm_Calculo."Productos Sin UM Pale" += 1;

            if posicion <= prm_Calculo."Productos Top 20" then
                salidasTop += rLinea."Palets Salidos";

            rLinea.Modify();
        until rLinea.Next() = 0;

        if prm_Calculo."Palets Salidos" > 0 then
            prm_Calculo."% Salidas Top 20" := Round(salidasTop / prm_Calculo."Palets Salidos" * 100, 0.1);
    end;

    /// <summary>
    /// Clase de cada hueco útil. Se ordenan en una copia temporal, reaprovechando "Secuencia
    /// picking" como clave de orden (altura y luego secuencia); la tabla real no se toca.
    /// </summary>
    local procedure ClasificarHuecos(var prm_Calculo: Record "Calculo ABC SGA"; var prm_ClaseHueco: Dictionary of [Code[20], Integer])
    var
        rUbicacion: Record "Ubicacion SGA";
        TempOrden: Record "Ubicacion SGA" temporary;
        rLinea: Record "Clasificacion ABC SGA";
        palesA: Integer;
        palesB: Integer;
        n: Integer;
    begin
        rUbicacion.SetRange("Cod. Almacen", prm_Calculo."Cod. Almacen");
        if rUbicacion.FindSet() then
            repeat
                if EsHuecoUtil(rUbicacion) then begin
                    TempOrden := rUbicacion;
                    // La secuencia de un código generado llega a 9.999.999 (pasillo 999): cabe
                    // entera detrás de la altura, que no pasa de 100.
                    TempOrden."Secuencia Picking" := NivelHueco(rUbicacion."Cod. Bin") * 10000000 + Minimo(rUbicacion."Secuencia Picking", 9999999);
                    TempOrden.Insert();
                end;
            until rUbicacion.Next() = 0;
        prm_Calculo."Huecos Utiles" := TempOrden.Count();

        rLinea.SetRange("No. Calculo", prm_Calculo."No.");
        rLinea.CalcSums("Palets en Almacen");
        prm_Calculo."Palets en Almacen" := rLinea."Palets en Almacen";
        rLinea.SetRange(Clase, rLinea.Clase::A);
        rLinea.CalcSums("Palets en Almacen");
        palesA := rLinea."Palets en Almacen";
        rLinea.SetRange(Clase, rLinea.Clase::B);
        rLinea.CalcSums("Palets en Almacen");
        palesB := rLinea."Palets en Almacen";
        prm_Calculo."Palets A" := palesA;

        TempOrden.SetCurrentKey("Cod. Almacen", "Secuencia Picking", "Cod. Bin");
        if TempOrden.FindSet() then
            repeat
                n += 1;
                if n <= palesA then
                    prm_ClaseHueco.Add(TempOrden."Cod. Bin", "Clase ABC SGA"::A.AsInteger())
                else
                    if n <= palesA + palesB then
                        prm_ClaseHueco.Add(TempOrden."Cod. Bin", "Clase ABC SGA"::B.AsInteger())
                    else
                        prm_ClaseHueco.Add(TempOrden."Cod. Bin", "Clase ABC SGA"::C.AsInteger());
            until TempOrden.Next() = 0;
    end;

    /// <summary>
    /// Cuántos palés de cada producto están en un hueco de su misma clase.
    /// </summary>
    local procedure CompararUbicacion(var prm_Calculo: Record "Calculo ABC SGA"; prm_PalesProductoHueco: Dictionary of [Text, Boolean]; prm_ClaseHueco: Dictionary of [Code[20], Integer])
    var
        rLinea: Record "Clasificacion ABC SGA";
        partes: List of [Text];
        clave: Text;
        hueco: Code[20];
        claseHueco: Integer;
    begin
        foreach clave in prm_PalesProductoHueco.Keys() do begin
            partes := clave.Split('|');
            hueco := CopyStr(partes.Get(2), 1, MaxStrLen(hueco));
            if prm_ClaseHueco.Get(hueco, claseHueco) then
                if rLinea.Get(prm_Calculo."No.", CopyStr(partes.Get(1), 1, MaxStrLen(rLinea."No. Producto"))) then
                    if rLinea.Clase.AsInteger() = claseHueco then begin
                        rLinea."Palets Hueco Su Clase" += 1;
                        rLinea.Modify();
                        prm_Calculo."Palets Hueco Su Clase" += 1;
                        if rLinea.Clase = rLinea.Clase::A then
                            prm_Calculo."Palets A en Huecos A" += 1;
                    end;
        end;

        rLinea.SetRange("No. Calculo", prm_Calculo."No.");
        rLinea.SetFilter("Palets en Almacen", '>0');
        if rLinea.FindSet() then
            repeat
                if rLinea."Palets Hueco Su Clase" < rLinea."Palets en Almacen" then begin
                    rLinea."Mal Ubicado" := true;
                    rLinea.Modify();
                end;
            until rLinea.Next() = 0;
    end;

    /// <summary>
    /// Clase que tenía cada producto en el cálculo anterior del mismo almacén.
    /// </summary>
    local procedure CompararConAnterior(prm_Calculo: Record "Calculo ABC SGA")
    var
        rAnterior: Record "Calculo ABC SGA";
        rLinea: Record "Clasificacion ABC SGA";
        rLineaAnterior: Record "Clasificacion ABC SGA";
    begin
        rAnterior.SetCurrentKey("Cod. Almacen", "No.");
        rAnterior.SetRange("Cod. Almacen", prm_Calculo."Cod. Almacen");
        rAnterior.SetFilter("No.", '<%1', prm_Calculo."No.");
        if not rAnterior.FindLast() then
            exit;

        rLinea.SetRange("No. Calculo", prm_Calculo."No.");
        if rLinea.FindSet() then
            repeat
                if rLineaAnterior.Get(rAnterior."No.", rLinea."No. Producto") then begin
                    rLinea."Clase Anterior" := rLineaAnterior.Clase;
                    rLinea."Cambia Clase" := rLinea.Clase <> rLineaAnterior.Clase;
                    rLinea.Modify();
                end;
            until rLinea.Next() = 0;
    end;

    /// <summary>
    /// Hueco en el que se guarda stock: con tipo (picking o almacenamiento) y no bloqueado. Las
    /// ubicaciones sin tipo (muelles, ajustes…) no se clasifican.
    /// </summary>
    local procedure EsHuecoUtil(prm_Ubicacion: Record "Ubicacion SGA"): Boolean
    begin
        // Solo cuenta el bloqueo del propio hueco, no el de su zona.
        exit((not prm_Ubicacion.Bloqueada) and prm_Ubicacion.TieneTipo());
    end;

    /// <summary>
    /// Altura del hueco sacada de su código (pasillo-estantería-altura), de 0 a 99. Si el código
    /// no tiene esa forma, 100: cuenta como la peor.
    /// </summary>
    local procedure NivelHueco(prm_Codigo: Code[20]): Integer
    var
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        pasillo: Integer;
        estanteria: Integer;
        altura: Integer;
    begin
        if not cUbicaciones.TrocearCodigo(prm_Codigo, pasillo, estanteria, altura) then
            exit(100);
        exit(altura);
    end;

    local procedure Minimo(prm_A: Integer; prm_B: Integer): Integer
    begin
        if prm_A < prm_B then
            exit(prm_A);
        exit(prm_B);
    end;
}
