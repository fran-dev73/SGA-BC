namespace AntonioNadal.SGA;

using Microsoft.Inventory.Location;

/// <summary>
/// Page Analisis ABC SGA (ID 51128).
/// Resultado de un cálculo ABC: arriba el resumen que dice si merece la pena ubicar por
/// rotación, y debajo una línea por producto ordenada de más a menos palés salidos.
///
/// Se abre en el último cálculo del almacén por defecto. "Calcular ahora" hace uno nuevo; los
/// anteriores se ven desde "Cálculos anteriores". Solo informa: no mueve nada.
/// </summary>
page 51128 "Analisis ABC SGA"
{
    Caption = 'Análisis ABC';
    // Worksheet y no List: hace falta la cabecera con el almacén y el resumen.
    PageType = Worksheet;
    SourceTable = "Clasificacion ABC SGA";
    SourceTableView = sorting("No. Calculo", Posicion);
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    AboutTitle = 'Análisis ABC';
    AboutText = 'Clasifica los productos por los palés que salen: A los que más, C los que menos. Arriba verá si unos pocos productos se llevan la mayoría de las salidas y cuántos palés están en un hueco de su clase. Solo informa: no cambia ninguna ubicación.';

    layout
    {
        area(Content)
        {
            group(Cabecera)
            {
                Caption = 'Qué se mira';

                field(FiltroAlmacen; FiltroAlmacen)
                {
                    Caption = 'Almacén';
                    ToolTip = 'Almacén analizado. Al cambiarlo se enseña su último cálculo.';
                    ApplicationArea = All;
                    TableRelation = Location;

                    trigger OnValidate()
                    begin
                        MostrarCalculo(UltimoCalculo(FiltroAlmacen));
                    end;
                }
                field(Mostrar; Mostrar)
                {
                    Caption = 'Mostrar';
                    ToolTip = 'Qué productos se ven en la lista.';
                    ApplicationArea = All;
                    OptionCaption = 'Todos,Solo A,Solo B,Solo C,Cambian de clase,Con palés fuera de su clase';

                    trigger OnValidate()
                    begin
                        AplicarFiltros();
                    end;
                }
                field(InfoCalculo; InfoCalculo)
                {
                    Caption = 'Cálculo';
                    ToolTip = 'Qué cálculo se está viendo y qué periodo de ventas mira.';
                    ApplicationArea = All;
                    Editable = false;
                }
            }
            group(Resumen)
            {
                Caption = 'Resumen';

                field(ResumenConcentracion; ResumenConcentracion)
                {
                    Caption = 'Concentración';
                    ToolTip = 'Qué parte de los palés salidos se lleva el 20 % de productos que más sale. Cuanto más alto, más rinde ubicar por rotación.';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                }
                field(ResumenClases; ResumenClases)
                {
                    Caption = 'Clases';
                    ToolTip = 'Cuántos productos y palés en almacén hay de cada clase.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(ResumenHuecos; ResumenHuecos)
                {
                    Caption = 'Huecos';
                    ToolTip = 'Cuántos palés están en un hueco de su misma clase. Los huecos se clasifican del mejor (altura más baja y antes en la secuencia de picking) al peor, con tantos huecos de cada clase como palés hay de ella.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(ResumenAvisos; ResumenAvisos)
                {
                    Caption = 'Avisos';
                    ToolTip = 'Datos que faltan y hacen el análisis menos fiable.';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Unfavorable;
                }
            }
            repeater(Productos)
            {
                field(Posicion; Rec.Posicion)
                {
                    ApplicationArea = All;
                }
                field("No. Producto"; Rec."No. Producto")
                {
                    ApplicationArea = All;
                }
                field(Descripcion; Rec.Descripcion)
                {
                    ApplicationArea = All;
                }
                field(Clase; Rec.Clase)
                {
                    ApplicationArea = All;
                    StyleExpr = EstiloClase;
                }
                field("Clase Anterior"; Rec."Clase Anterior")
                {
                    ApplicationArea = All;
                    StyleExpr = EstiloCambio;
                }
                field("Palets Salidos"; Rec."Palets Salidos")
                {
                    ApplicationArea = All;
                }
                field("% Salidas"; Rec."% Salidas")
                {
                    ApplicationArea = All;
                }
                field("% Acumulado"; Rec."% Acumulado")
                {
                    ApplicationArea = All;
                }
                field("Palets en Almacen"; Rec."Palets en Almacen")
                {
                    ApplicationArea = All;
                }
                field("Palets Hueco Su Clase"; Rec."Palets Hueco Su Clase")
                {
                    ApplicationArea = All;
                    StyleExpr = EstiloUbicacion;
                }
                field("Unidad Pale"; Rec."Unidad Pale")
                {
                    ApplicationArea = All;
                    StyleExpr = EstiloUnidad;
                }
                field("Cantidad Salida Base"; Rec."Cantidad Salida Base")
                {
                    ApplicationArea = All;
                    Visible = false;
                }
            }
        }
        area(FactBoxes)
        {
            part(UbicacionesProducto; "Ubicaciones Producto FactBox")
            {
                ApplicationArea = All;
                SubPageLink = "No. Producto" = field("No. Producto"), "Cod. Almacen" = field("Cod. Almacen");
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CalcularAhora)
            {
                Caption = 'Calcular ahora';
                ToolTip = 'Hace un cálculo nuevo con las ventas y los palés de hoy. Los anteriores se guardan.';
                ApplicationArea = All;
                Image = Calculate;

                trigger OnAction()
                var
                    cABC: Codeunit "Analisis ABC SGA";
                begin
                    MostrarCalculo(cABC.Calcular(FiltroAlmacen));
                end;
            }
            action(CalculosAnteriores)
            {
                Caption = 'Cálculos anteriores';
                ToolTip = 'Lista de los cálculos guardados, para ver uno antiguo o borrar los que sobren.';
                ApplicationArea = All;
                Image = History;
                RunObject = page "Calculos ABC SGA";
            }
            action(VerEnMapa)
            {
                Caption = 'Dónde está el producto';
                ToolTip = 'Muestra en qué ubicaciones está el producto de la línea.';
                ApplicationArea = All;
                Image = BinContent;

                trigger OnAction()
                var
                    rContenido: Record "Contenido Ubicacion SGA";
                begin
                    rContenido.SetRange("Cod. Almacen", Rec."Cod. Almacen");
                    rContenido.SetRange("No. Producto", Rec."No. Producto");
                    Page.Run(Page::"Contenido Ubicaciones SGA", rContenido);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(CalcularAhora_Promoted; CalcularAhora)
                {
                }
                actionref(CalculosAnteriores_Promoted; CalculosAnteriores)
                {
                }
            }
        }
    }

    var
        FiltroAlmacen: Code[10];
        NoCalculo: Integer;
        Mostrar: Option Todos,"Solo A","Solo B","Solo C","Cambian de Clase","Fuera de su Clase";
        InfoCalculo: Text;
        ResumenConcentracion: Text;
        ResumenClases: Text;
        ResumenHuecos: Text;
        ResumenAvisos: Text;
        EstiloClase: Text;
        EstiloCambio: Text;
        EstiloUbicacion: Text;
        EstiloUnidad: Text;

    trigger OnOpenPage()
    var
        rConfig: Record "Config. SGA";
        rCalculo: Record "Calculo ABC SGA";
    begin
        if NoCalculo <> 0 then begin
            rCalculo.Get(NoCalculo);
            FiltroAlmacen := rCalculo."Cod. Almacen";
            MostrarCalculo(NoCalculo);
            exit;
        end;

        rConfig.ObtenerConfig();
        FiltroAlmacen := rConfig."Almacen por Defecto";
        MostrarCalculo(UltimoCalculo(FiltroAlmacen));
    end;

    trigger OnAfterGetRecord()
    begin
        case Rec.Clase of
            Rec.Clase::A:
                EstiloClase := 'Favorable';
            Rec.Clase::B:
                EstiloClase := 'Ambiguous';
            else
                EstiloClase := 'Subordinate';
        end;

        EstiloCambio := 'Standard';
        if Rec."Cambia Clase" then
            EstiloCambio := 'Unfavorable';

        EstiloUbicacion := 'Standard';
        if Rec."Mal Ubicado" then
            EstiloUbicacion := 'Unfavorable';

        EstiloUnidad := 'Standard';
        if Rec."Sin Unidad Pale" then
            EstiloUnidad := 'Unfavorable';
    end;

    /// <summary>
    /// Abre la página en un cálculo concreto (desde "Cálculos anteriores").
    /// </summary>
    procedure FijarCalculo(prm_NoCalculo: Integer)
    begin
        NoCalculo := prm_NoCalculo;
    end;

    local procedure UltimoCalculo(prm_Almacen: Code[10]): Integer
    var
        rCalculo: Record "Calculo ABC SGA";
    begin
        rCalculo.SetCurrentKey("Cod. Almacen", "No.");
        rCalculo.SetRange("Cod. Almacen", prm_Almacen);
        if rCalculo.FindLast() then
            exit(rCalculo."No.");
        exit(0);
    end;

    local procedure MostrarCalculo(prm_NoCalculo: Integer)
    var
        rCalculo: Record "Calculo ABC SGA";
        InfoCalculoLbl: Label 'Nº %1 del %2 (%3). Ventas del %4 al %5. Cortes: A hasta %6 %, B hasta %7 %.', Comment = '%1 = nº, %2 = fecha, %3 = usuario, %4 = desde, %5 = hasta, %6 = corte A, %7 = corte B';
        SinCalculoLbl: Label 'Todavía no hay ningún cálculo de este almacén. Pulse "Calcular ahora".';
        ResumenConcentracionLbl: Label 'El 20 % de los productos (%1 de %2) hace el %3 % de los palés salidos (%4 palés).', Comment = '%1 = productos top, %2 = productos, %3 = %, %4 = palés salidos';
        ResumenClasesLbl: Label 'A: %1 productos (%2 palés en almacén) · B: %3 productos · C: %4 productos.', Comment = '%1 = productos A, %2 = palés A, %3 = productos B, %4 = productos C';
        ResumenHuecosLbl: Label '%1 de %2 palés están en un hueco de su clase (%3 %). De los palés A, el %4 % está en huecos A. Huecos de picking y reserva: %5.', Comment = '%1 = bien ubicados, %2 = palés, %3 = %, %4 = % A en A, %5 = huecos';
        ProductosSinUMPaleLbl: Label '%1 productos con ventas no tienen unidad de palé: quedan como C. Márquelos en la columna "Unidad de palé".', Comment = '%1 = nº productos';
    begin
        NoCalculo := prm_NoCalculo;
        Clear(ResumenConcentracion);
        Clear(ResumenClases);
        Clear(ResumenHuecos);
        Clear(ResumenAvisos);

        if (NoCalculo = 0) or not rCalculo.Get(NoCalculo) then begin
            NoCalculo := 0;
            InfoCalculo := SinCalculoLbl;
        end else begin
            InfoCalculo := StrSubstNo(InfoCalculoLbl, rCalculo."No.", rCalculo."Fecha Calculo", rCalculo.Usuario,
                                      rCalculo."Fecha Desde", rCalculo."Fecha Hasta", rCalculo."Corte A", rCalculo."Corte B");
            ResumenConcentracion := StrSubstNo(ResumenConcentracionLbl, rCalculo."Productos Top 20", rCalculo.Productos,
                                               rCalculo."% Salidas Top 20", rCalculo."Palets Salidos");
            ResumenClases := StrSubstNo(ResumenClasesLbl, rCalculo."Productos A", rCalculo."Palets A", rCalculo."Productos B", rCalculo."Productos C");
            ResumenHuecos := StrSubstNo(ResumenHuecosLbl, rCalculo."Palets Hueco Su Clase", rCalculo."Palets en Almacen",
                                        rCalculo.PorcentajeBienUbicados(), rCalculo.PorcentajeAEnHuecosA(), rCalculo."Huecos Utiles");
            if rCalculo."Productos Sin UM Pale" > 0 then
                ResumenAvisos := StrSubstNo(ProductosSinUMPaleLbl, rCalculo."Productos Sin UM Pale");
        end;

        AplicarFiltros();
    end;

    local procedure AplicarFiltros()
    begin
        Rec.Reset();
        Rec.SetCurrentKey("No. Calculo", Posicion);
        Rec.FilterGroup(2);
        Rec.SetRange("No. Calculo", NoCalculo);
        Rec.FilterGroup(0);

        case Mostrar of
            Mostrar::"Solo A":
                Rec.SetRange(Clase, Rec.Clase::A);
            Mostrar::"Solo B":
                Rec.SetRange(Clase, Rec.Clase::B);
            Mostrar::"Solo C":
                Rec.SetRange(Clase, Rec.Clase::C);
            Mostrar::"Cambian de Clase":
                Rec.SetRange("Cambia Clase", true);
            Mostrar::"Fuera de su Clase":
                Rec.SetRange("Mal Ubicado", true);
        end;

        CurrPage.Update(false);
    end;
}
