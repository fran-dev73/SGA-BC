namespace AntonioNadal.SGA;

using System.Text;

/// <summary>
/// Report Etiquetas Ubicaciones SGA (ID 51106).
/// Etiqueta de cada ubicación (4 × 3 cm, una por página, para impresora de etiquetas) para
/// pegar en el puntal de la estantería. Lleva el código de la ubicación con su código de
/// barras Code 128 y el texto legible debajo. El picking lee ese código para confirmar que
/// el preparador está delante del hueco correcto.
///
/// Las barras usan el proveedor de fuentes de BC (IDAutomation, incluido en BC online); el
/// layout aplica la fuente IDAutomationC128S al campo codificado.
/// </summary>
report 51106 "Etiquetas Ubicaciones SGA"
{
    Caption = 'Etiquetas de ubicación SGA';
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    DefaultRenderingLayout = Etiqueta40x30;

    dataset
    {
        dataitem(Ubicacion; "Ubicacion SGA")
        {
            RequestFilterFields = "Cod. Almacen", "Cod. Bin", "Cod. Zona SGA", "Tipo Ubicacion";

            column(CodAlmacen; "Cod. Almacen") { }
            column(CodBin; "Cod. Bin") { }
            column(Barras; Barras) { }

            trigger OnAfterGetRecord()
            var
                BarcodeFontProvider: Interface "Barcode Font Provider";
            begin
                BarcodeFontProvider := Enum::"Barcode Font Provider"::IDAutomation1D;
                Barras := BarcodeFontProvider.EncodeFont("Cod. Bin", Enum::"Barcode Symbology"::Code128);
            end;
        }
    }

    rendering
    {
        layout(Etiqueta40x30)
        {
            Type = RDLC;
            LayoutFile = './SGA/Otros/Layouts/Rep51106.EtiquetasUbicacionesSGA.rdlc';
            Caption = 'Etiqueta de ubicación 4 × 3 cm';
        }
    }

    var
        Barras: Text;
}
