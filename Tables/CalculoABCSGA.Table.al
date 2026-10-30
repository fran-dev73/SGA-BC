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
            ToolTip = 'Son A los productos hasta este % acumulado de palés salidos.';
            Caption = 'Corte clase A (%)';
            DataClassification = ToBeClassified;
        }
        field(33; "Corte B"; Decimal)
        {
            ToolTip = 'Son B los productos que siguen a los A hasta este % acumulado.';
            Caption = 'Corte clase B (%)';
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
}
