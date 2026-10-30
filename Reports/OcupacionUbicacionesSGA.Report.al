namespace AntonioNadal.SGA;

report 51105 "Ocupacion Ubicaciones SGA"
{
    Caption = 'Ocupación de ubicaciones';
    ApplicationArea = All;
    UsageCategory = ReportsAndAnalysis;
    dataset
    {
        dataitem(Ubicacion; "Ubicacion SGA")
        {
            RequestFilterFields = "Cod. Almacen", "Cod. Zona SGA", "Tipo Ubicacion", "Estado SGA";
            column(CodAlmacen; "Cod. Almacen") { }
            column(CodBin; "Cod. Bin") { }
            column(Descripcion; Descripcion) { }
            column(Zona; "Cod. Zona SGA") { }
            column(Tipo; "Tipo Ubicacion") { }
            column(Estado; "Estado SGA") { }
            column(PorcentajeOcupacion; "% Ocupacion") { }
            column(CantidadBase; "Cantidad Base") { }
        }
    }
}
