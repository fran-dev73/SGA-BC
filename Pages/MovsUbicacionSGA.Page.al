namespace AntonioNadal.SGA;

/// <summary>
/// Page Movs. Ubicacion SGA (ID 51104).
/// Diario de movimientos de ubicación: quién movió qué, cuándo, desde dónde y a dónde.
/// </summary>
page 51104 "Movs. Ubicacion SGA"
{
    Caption = 'Movimientos de ubicación SGA';
    PageType = List;
    SourceTable = "Movimiento Ubicacion SGA";
    UsageCategory = History;
    ApplicationArea = All;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    SourceTableView = sorting("No. Movimiento") order(descending);

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("No. Movimiento"; Rec."No. Movimiento")
                {
                    ToolTip = 'Número correlativo del movimiento.';
                    ApplicationArea = All;
                }
                field("Fecha-Hora Registro"; Rec."Fecha-Hora Registro")
                {
                    ToolTip = 'Momento exacto en que se registró el movimiento.';
                    ApplicationArea = All;
                }
                field("Tipo Movimiento"; Rec."Tipo Movimiento")
                {
                    ToolTip = 'Naturaleza del movimiento: entrada, salida, traslado, ajuste, recuento o carga inicial.';
                    ApplicationArea = All;
                }
                field(Origen; Rec.Origen)
                {
                    ToolTip = 'Flujo del que procede el movimiento.';
                    ApplicationArea = All;
                }
                field("Cod. Almacen"; Rec."Cod. Almacen")
                {
                    ToolTip = 'Almacén en el que se produjo el movimiento.';
                    ApplicationArea = All;
                }
                field("Cod. Bin Origen"; Rec."Cod. Bin Origen")
                {
                    ToolTip = 'Ubicación de la que salió la mercancía.';
                    ApplicationArea = All;
                }
                field("Cod. Bin Destino"; Rec."Cod. Bin Destino")
                {
                    ToolTip = 'Ubicación a la que fue la mercancía.';
                    ApplicationArea = All;
                }
                field("No. Producto"; Rec."No. Producto")
                {
                    ToolTip = 'Producto movido.';
                    ApplicationArea = All;
                }
                field("Descripcion Producto"; Rec."Descripcion Producto")
                {
                    ToolTip = 'Descripción del producto movido.';
                    ApplicationArea = All;
                }
                field("Cod. Variante"; Rec."Cod. Variante")
                {
                    ToolTip = 'Variante del producto.';
                    ApplicationArea = All;
                    Visible = false;
                }
                field("No. Lote"; Rec."No. Lote")
                {
                    ToolTip = 'Lote movido.';
                    ApplicationArea = All;
                }
                field(Cantidad; Rec.Cantidad)
                {
                    ToolTip = 'Cantidad en la unidad de medida con la que trabajó el operario.';
                    ApplicationArea = All;
                }
                field("Cod. Unidad Medida"; Rec."Cod. Unidad Medida")
                {
                    ToolTip = 'Unidad de medida con la que trabajó el operario.';
                    ApplicationArea = All;
                }
                field("Cantidad Base"; Rec."Cantidad Base")
                {
                    ToolTip = 'Cantidad convertida a unidades base. Es la que se aplicó al contenido.';
                    ApplicationArea = All;
                }
                field("No. Documento Origen"; Rec."No. Documento Origen")
                {
                    ToolTip = 'Documento que originó el movimiento.';
                    ApplicationArea = All;
                }
                field("No. Orden SGA"; Rec."No. Orden SGA")
                {
                    ToolTip = 'Orden de trabajo de almacén que originó el movimiento.';
                    ApplicationArea = All;
                    Visible = false;
                }
                field("Cod. Usuario"; Rec."Cod. Usuario")
                {
                    ToolTip = 'Usuario que registró el movimiento.';
                    ApplicationArea = All;
                }
                field(Descripcion; Rec.Descripcion)
                {
                    ToolTip = 'Nota registrada con el movimiento.';
                    ApplicationArea = All;
                }
                field("Fecha Caducidad"; Rec."Fecha Caducidad")
                {
                    ToolTip = 'Caducidad del lote en el momento del movimiento.';
                    ApplicationArea = All;
                    Visible = false;
                }
            }
        }
    }

    views
    {
        view(Traslados)
        {
            Caption = 'Traslados';
            Filters = where("Tipo Movimiento" = const(Traslado));
        }
        view(Ajustes)
        {
            Caption = 'Ajustes y recuentos';
            Filters = where("Tipo Movimiento" = filter(Ajuste | Recuento));
        }
    }
}
