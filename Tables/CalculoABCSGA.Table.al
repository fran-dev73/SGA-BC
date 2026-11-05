namespace AntonioNadal.SGA;

using Microsoft.Inventory.Location;

/// <summary>
/// Table Calculo ABC SGA (ID 51112).
/// Cabecera de cada cálculo del análisis ABC: con qué parámetros se hizo y el resumen que dice
/// si merece la pena ubicar por rotación. Se guarda uno por ejecución, no solo el último, para
/// poder ver cómo evoluciona cada producto (ver "Clasificacion ABC SGA").
///
/// Solo observa: no cambia ninguna ubicación ni la estrategia de ubicar.
/// </summary>
table 51112 "Calculo ABC SGA"
{
    Caption = 'Cálculo ABC SGA';
    DataClassification = ToBeClassified;
    LookupPageId = "Calculos ABC SGA";
    DrillDownPageId = "Calculos ABC SGA";

    fields
    {
        field(1; "No."; Integer)
        {
            ToolTip = 'Número del cálculo.';
            Caption = 'Nº';
            DataClassification = ToBeClassified;
        }
        field(10; "Cod. Almacen"; Code[10])
        {
            ToolTip = 'Almacén analizado.';
            Caption = 'Almacén';
            DataClassification = ToBeClassified;
            TableRelation = Location;
        }
        field(20; "Fecha Calculo"; DateTime)
        {
            ToolTip = 'Cuándo se hizo el cálculo.';
            Caption = 'Calculado el';
            DataClassification = ToBeClassified;
        }
        field(21; Usuario; Code[50])
        {
            ToolTip = 'Quién lanzó el cálculo.';
            Caption = 'Usuario';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(30; "Fecha Desde"; Date)
        {
            ToolTip = 'Primer día de ventas que se mira.';
            Caption = 'Ventas desde';
            DataClassification = ToBeClassified;
        }
        field(31; "Fecha Hasta"; Date)
        {
            ToolTip = 'Último día de ventas que se mira.';
            Caption = 'Ventas hasta';
            DataClassification = ToBeClassified;
        }
        field(32; "Corte A"; Decimal)
        {
            ToolTip = 'Son A los productos que se suman desde el 0 % hasta este % acumulado de palés salidos.';
            Caption = 'Clase A: del 0 % hasta (%)';
            DataClassification = ToBeClassified;
        }
        field(33; "Corte B"; Decimal)
        {
            ToolTip = 'Son B los productos que siguen a los A, desde el corte de la A hasta este % acumulado. El resto son C.';
            Caption = 'Clase B: desde la A hasta (%)';
            DataClassification = ToBeClassified;
        }
        field(40; Productos; Integer)
        {
            Caption = 'Productos';
            DataClassification = ToBeClassified;
            ToolTip = 'Productos analizados: los que han tenido ventas en el periodo o tienen palés en SGA.';
        }
        field(41; "Productos A"; Integer)
        {
            ToolTip = 'Productos de clase A.';
            Caption = 'Productos A';
            DataClassification = ToBeClassified;
        }
        field(42; "Productos B"; Integer)
        {
            ToolTip = 'Productos de clase B.';
            Caption = 'Productos B';
            DataClassification = ToBeClassified;
        }
        field(43; "Productos C"; Integer)
        {
            ToolTip = 'Productos de clase C.';
            Caption = 'Productos C';
            DataClassification = ToBeClassified;
        }
        field(44; "Productos Sin UM Pale"; Integer)
        {
            Caption = 'Productos sin unidad de palé';
            DataClassification = ToBeClassified;
            ToolTip = 'Productos con ventas cuyas salidas no se han podido pasar a palés porque no tienen unidad de palé. Quedan como C.';
        }
        field(50; "Palets Salidos"; Decimal)
        {
            ToolTip = 'Palés salidos en el periodo, sumando todos los productos.';
            Caption = 'Palés salidos';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 1;
        }
        field(51; "Productos Top 20"; Integer)
        {
            ToolTip = 'Cuántos productos son el 20 % que más sale.';
            Caption = 'Productos del 20 % que más sale';
            DataClassification = ToBeClassified;
        }
        field(52; "% Salidas Top 20"; Decimal)
        {
            Caption = '% de salidas del 20 % que más sale';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 1;
            ToolTip = 'Qué parte de los palés salidos se lleva el 20 % de productos que más sale. Cuanto más alto, más rinde ubicar por rotación.';
        }
        field(60; "Huecos Utiles"; Integer)
        {
            ToolTip = 'Huecos de picking y reserva no bloqueados.';
            Caption = 'Huecos de picking y reserva';
            DataClassification = ToBeClassified;
        }
        field(61; "Palets en Almacen"; Integer)
        {
            ToolTip = 'Palés que hay ahora en huecos de picking y reserva.';
            Caption = 'Palés en almacén';
            DataClassification = ToBeClassified;
        }
        field(62; "Palets Hueco Su Clase"; Integer)
        {
            ToolTip = 'Palés que están en un hueco de su misma clase.';
            Caption = 'Palés en hueco de su clase';
            DataClassification = ToBeClassified;
        }
        field(63; "Palets A"; Integer)
        {
            ToolTip = 'Palés de productos A que hay en el almacén.';
            Caption = 'Palés A en almacén';
            DataClassification = ToBeClassified;
        }
        field(64; "Palets A en Huecos A"; Integer)
        {
            ToolTip = 'Palés de productos A que están en los mejores huecos.';
            Caption = 'Palés A en huecos A';
            DataClassification = ToBeClassified;
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(Almacen; "Cod. Almacen", "No.")
        {
        }
    }

    trigger OnDelete()
    var
        rClasificacion: Record "Clasificacion ABC SGA";
    begin
        rClasificacion.SetRange("No. Calculo", "No.");
        rClasificacion.DeleteAll();
    end;

    /// <summary>
    /// % de palés que están en un hueco de su misma clase.
    /// </summary>
    procedure PorcentajeBienUbicados(): Decimal
    begin
        if "Palets en Almacen" = 0 then
            exit(0);
        exit(Round("Palets Hueco Su Clase" / "Palets en Almacen" * 100, 0.1));
    end;

    /// <summary>
    /// % de los palés A que están en huecos A.
    /// </summary>
    procedure PorcentajeAEnHuecosA(): Decimal
    begin
        if "Palets A" = 0 then
            exit(0);
        exit(Round("Palets A en Huecos A" / "Palets A" * 100, 0.1));
    end;

    /// <summary>
    /// Nº del último cálculo del almacén, o 0 si no tiene ninguno.
    /// </summary>
    procedure UltimoDelAlmacen(prm_Almacen: Code[10]): Integer
    var
        rCalculo: Record "Calculo ABC SGA";
    begin
        rCalculo.SetCurrentKey("Cod. Almacen", "No.");
        rCalculo.SetRange("Cod. Almacen", prm_Almacen);
        rCalculo.SetLoadFields("No.");
        if rCalculo.FindLast() then
            exit(rCalculo."No.");
        exit(0);
    end;

    /// <summary>
    /// Textos del resumen de este cálculo: qué cálculo es, la concentración de las salidas,
    /// las clases, los huecos y los avisos (en blanco si no hay).
    /// </summary>
    procedure TextosResumen(var prm_Info: Text; var prm_Concentracion: Text; var prm_Clases: Text; var prm_Huecos: Text; var prm_Avisos: Text)
    var
        InfoCalculoLbl: Label 'Nº %1 del %2 (%3). Ventas del %4 al %5. Cortes: A hasta %6 %, B hasta %7 %.', Comment = '%1 = nº, %2 = fecha, %3 = usuario, %4 = desde, %5 = hasta, %6 = corte A, %7 = corte B';
        ResumenConcentracionLbl: Label 'El 20 % de los productos (%1 de %2) hace el %3 % de los palés salidos (%4 palés).', Comment = '%1 = productos top, %2 = productos, %3 = %, %4 = palés salidos';
        ResumenClasesLbl: Label 'A: %1 productos (%2 palés en almacén) · B: %3 productos · C: %4 productos.', Comment = '%1 = productos A, %2 = palés A, %3 = productos B, %4 = productos C';
        ResumenHuecosLbl: Label '%1 de %2 palés están en un hueco de su clase (%3 %). De los palés A, el %4 % está en huecos A. Huecos de picking y reserva: %5.', Comment = '%1 = bien ubicados, %2 = palés, %3 = %, %4 = % A en A, %5 = huecos';
        ProductosSinUMPaleLbl: Label '%1 productos con ventas no tienen unidad de palé: quedan como C. Márquelos en la columna "Unidad de palé".', Comment = '%1 = nº productos';
    begin
        prm_Info := StrSubstNo(InfoCalculoLbl, "No.", "Fecha Calculo", Usuario, "Fecha Desde", "Fecha Hasta", "Corte A", "Corte B");
        prm_Concentracion := StrSubstNo(ResumenConcentracionLbl, "Productos Top 20", Productos, "% Salidas Top 20", "Palets Salidos");
        prm_Clases := StrSubstNo(ResumenClasesLbl, "Productos A", "Palets A", "Productos B", "Productos C");
        prm_Huecos := StrSubstNo(ResumenHuecosLbl, "Palets Hueco Su Clase", "Palets en Almacen",
                                 PorcentajeBienUbicados(), PorcentajeAEnHuecosA(), "Huecos Utiles");
        prm_Avisos := '';
        if "Productos Sin UM Pale" > 0 then
            prm_Avisos := StrSubstNo(ProductosSinUMPaleLbl, "Productos Sin UM Pale");
    end;
}
