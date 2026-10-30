namespace AntonioNadal.SGA;

using System.Text;

/// <summary>
/// Report Etiquetas Ubicaciones SGA (ID 51106).
/// Etiqueta pequeña (70 × 35 mm, una por página, para impresora de etiquetas) de cada
/// ubicación: el código del hueco en grande, su dígito de control en un recuadro y el código
/// de barras Code 128 del hueco para escanearlo.
///
/// El dígito de control es lo que certifica el picking: solo se sabe estando delante de la
/// etiqueta. Por eso va aparte del código de barras y no dentro de él: si estuviera dentro,
/// bastaría con escanear un listado impreso.
///
/// Las barras usan el proveedor de fuentes de BC (IDAutomation, incluido en BC online); el
/// layout aplica la fuente IDAutomationC128S al campo codificado.
/// </summary>
report 51106 "Etiquetas Ubicaciones SGA"
{
    Caption = 'Etiquetas de ubicación';
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    DefaultRenderingLayout = Etiqueta70x35;

    dataset
    {
        dataitem(Ubicacion; "Ubicacion SGA")
        {
            RequestFilterFields = "Cod. Almacen", "Cod. Bin", "Cod. Zona SGA", "Tipo UM Admitida";

            column(CodAlmacen; "Cod. Almacen") { }
            column(CodBin; "Cod. Bin") { }
            column(Zona; "Cod. Zona SGA") { }
            column(Digito; "Digito Control") { }
            column(Barras; Barras) { }
            column(Pie; Pie) { }

            trigger OnAfterGetRecord()
            var
                BarcodeFontProvider: Interface "Barcode Font Provider";
                PieEtiquetaLbl: Label '%1 · %2', Comment = '%1 = almacén, %2 = qué admite';
            begin
                // Sin dígito no se puede certificar nada: se genera ahora, que es cuando se va a
                // imprimir la etiqueta que lo lleva.
                if "Digito Control" = '' then begin
                    GenerarDigitoControl();
                    Modify();
                end;

                BarcodeFontProvider := Enum::"Barcode Font Provider"::IDAutomation1D;
                Barras := BarcodeFontProvider.EncodeFont("Cod. Bin", Enum::"Barcode Symbology"::Code128);

                Pie := StrSubstNo(PieEtiquetaLbl, "Cod. Almacen", "Tipo UM Admitida");
            end;
        }
    }

    rendering
    {
        layout(Etiqueta70x35)
        {
            Type = RDLC;
            LayoutFile = './SGA/Otros/Layouts/Rep51106.EtiquetasUbicacionesSGA.rdlc';
            Caption = 'Etiqueta 70 × 35 mm';
        }
    }

    var
        Barras: Text;
        Pie: Text;
}
