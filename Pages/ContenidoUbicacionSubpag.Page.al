namespace AntonioNadal.SGA;

/// <summary>
/// Page Contenido Ubicacion Subpag (ID 51102).
/// Subpágina y factbox con el contenido de una ubicación. Solo lectura: el contenido
/// se cambia con traslados, ajustes y recuentos, nunca editando la fila.
/// </summary>
page 51102 "Contenido Ubicacion Subpag"
{
    Caption = 'Contenido de la ubicación SGA';
    PageType = ListPart;
    SourceTable = "Contenido Ubicacion SGA";
    ApplicationArea = All;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("No. Producto"; Rec."No. Producto")
                {
                    ToolTip = 'Producto que hay en la ubicación.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field(Descripcion; Rec.Descripcion)
                {
                    ToolTip = 'Descripción del producto.';
                    ApplicationArea = All;
                }
                field("No. Lote"; Rec."No. Lote")
                {
                    ToolTip = 'Lote al que corresponde la cantidad.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field(SSCC; Rec.SSCC)
                {
                    ApplicationArea = All;
                }
                field("Cantidad Base"; Rec."Cantidad Base")
                {
                    ToolTip = 'Unidades base que hay de este producto y lote en la ubicación.';
                    ApplicationArea = All;
                }
                field(CantidadVenta; CantidadVenta)
                {
                    Caption = 'Cantidad (UM venta)';
                    ToolTip = 'La misma cantidad en la unidad de venta del producto, por ejemplo en cajas. Sin unidad de venta en la ficha, en unidades base.';
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 5;
                }
                field("UM Venta"; Rec."UM Venta")
                {
                    ApplicationArea = All;
                }
                field("Cantidad Reservada"; Rec."Cantidad Reservada")
                {
                    ToolTip = 'Cantidad ya comprometida por órdenes de picking pendientes.';
                    ApplicationArea = All;
                }
                field("Cantidad Disponible"; Rec."Cantidad Disponible")
                {
                    ToolTip = 'Cantidad libre para recoger.';
                    ApplicationArea = All;
                }
                field("Cod. Unidad Medida"; Rec."Cod. Unidad Medida")
                {
                    ToolTip = 'Unidad de medida en la que se guarda el contenido. En la Fase 1 es siempre la unidad base del producto.';
                    ApplicationArea = All;
                    Visible = false;
                }
                field("Fecha Caducidad"; Rec."Fecha Caducidad")
                {
                    ToolTip = 'Caducidad del lote.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field(Bloqueado; Rec.Bloqueado)
                {
                    ToolTip = 'Si está activo, el motor de picking no propone esta línea.';
                    ApplicationArea = All;
                }
                field("Motivo Bloqueo"; Rec."Motivo Bloqueo")
                {
                    ApplicationArea = All;
                }
                field("Fecha Entrada"; Rec."Fecha Entrada")
                {
                    ApplicationArea = All;
                    Visible = false;
                }
            }
        }
    }

    var
        // Una instancia mientras la página está abierta: guarda el factor de cada producto.
        cUM: Codeunit "Unidades Producto SGA";
        EstiloFila: Text;
        CantidadVenta: Decimal;

    trigger OnOpenPage()
    begin
        // La unidad de venta llega en la misma consulta de la página (CantidadEnUMVenta).
        Rec.SetAutoCalcFields("UM Venta");
    end;

    trigger OnAfterGetRecord()
    begin
        EstiloFila := Rec.EstiloContenido();
        CantidadVenta := Rec.CantidadEnUMVenta(cUM);
    end;
}
