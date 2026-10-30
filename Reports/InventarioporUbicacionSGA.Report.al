namespace AntonioNadal.SGA;

report 51104 "Inventario por Ubicacion SGA"
{
    Caption = 'Inventario por ubicación';
    ApplicationArea = All;
    UsageCategory = ReportsAndAnalysis;
    dataset
    {
        dataitem(Contenido; "Contenido Ubicacion SGA")
        {
            RequestFilterFields = "Cod. Almacen", "Cod. Bin", "No. Producto", "No. Lote";
            column(CodAlmacen; "Cod. Almacen") { }
            column(CodBin; "Cod. Bin") { }
            column(NoProducto; "No. Producto") { }
            column(CodVariante; "Cod. Variante") { }
            column(NoLote; "No. Lote") { }
            column(CantidadBase; "Cantidad Base") { }
            column(FechaCaducidad; "Fecha Caducidad") { }
        }
    }
}
