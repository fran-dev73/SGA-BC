namespace AntonioNadal.SGA;

using System.Text;

/// <summary>
/// Report Etiquetas Ubicaciones SGA (ID 51106).
/// Etiqueta pequeña (70 × 35 mm, una por página, para impresora de etiquetas) de cada
/// ubicación: el código del hueco en grande, su dígito de control en un recuadro y un código
/// de barras Code 128 con los dos (Cod. "Lectura Codigos SGA".CodigoEtiqueta), para que un solo
/// escaneo dé la ubicación y el dígito.
///
/// El dígito de control es lo que certifica el picking: solo está en esta etiqueta, en el
/// recuadro y en sus barras; ningún otro listado lo imprime. Se puede teclear o escanear.
///
/// Las barras usan el proveedor de fuentes de BC (IDAutomation, incluido en BC online); el
/// layout aplica la fuente IDAutomationC128S al campo codificado.
/// </summary>
report 51106 "Etiquetas Ubicaciones SGA"
{
    Caption = 'Etiquetas de ubicación SGA';
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    DefaultRenderingLayout = Etiqueta70x35;

    dataset
    {
        dataitem(Ubicacion; "Ubicacion SGA")
        {
            RequestFilterFields = "Cod. Almacen", "Cod. Bin", "Cod. Zona SGA", "Tipo Ubicacion";

            column(CodAlmacen; "Cod. Almacen") { }
            column(CodBin; "Cod. Bin") { }
            column(Zona; "Cod. Zona SGA") { }
            column(Digito; "Digito Control") { }
            column(Barras; Barras) { }
            column(Pie; Pie) { }

            trigger OnAfterGetRecord()
            var
                BarcodeFontProvider: Interface "Barcode Font Provider";
                PieEtiquetaLbl: Label '%1 · %2', Comment = '%1 = almacén, %2 = tipo de ubicación (Picking o Almacenamiento)';
            begin
                // Sin dígito no se puede certificar nada: se genera ahora, que es cuando se va a
                // imprimir la etiqueta que lo lleva.
                if "Digito Control" = '' then begin
                    GenerarDigitoControl();
                    Modify();
                end;
                // Imprimir no marca el dígito como colocado: se marca después de pegar la
                // etiqueta, para no pedir al preparador un dígito que aún no está en el hueco.

                // Un solo escaneo da la ubicación y su dígito (Cod. "Lectura Codigos SGA").
                BarcodeFontProvider := Enum::"Barcode Font Provider"::IDAutomation1D;
                Barras := BarcodeFontProvider.EncodeFont(cLectura.CodigoEtiqueta("Cod. Bin", "Digito Control"), Enum::"Barcode Symbology"::Code128);

                Pie := StrSubstNo(PieEtiquetaLbl, "Cod. Almacen", "Tipo Ubicacion");
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
        cLectura: Codeunit "Lectura Codigos SGA";
        Barras: Text;
        Pie: Text;
}
