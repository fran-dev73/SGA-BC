namespace AntonioNadal.SGA;

/// <summary>
/// Page Contenido Ubicacion Subpag (ID 51102).
/// Subpágina y factbox con el contenido de una ubicación. Solo lectura: el contenido
/// se cambia con traslados, ajustes y recuentos, nunca editando la fila.
/// </summary>
page 51102 "Contenido Ubicacion Subpag"
{
    Caption = 'Contenido de la ubicación';
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
                field("Cod. Variante"; Rec."Cod. Variante")
                {
                    ToolTip = 'Variante del producto.';
                    ApplicationArea = All;
                }
                field("No. Lote"; Rec."No. Lote")
                {
                    ToolTip = 'Lote al que corresponde la cantidad.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field("Cantidad Base"; Rec."Cantidad Base")
                {
                    ToolTip = 'Unidades base que hay de este producto y lote en la ubicación.';
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
                    ToolTip = 'Razón del bloqueo.';
                    ApplicationArea = All;
                }
                field("Fecha Ultima Entrada"; Rec."Fecha Ultima Entrada")
                {
                    ToolTip = 'Fecha y hora en que entró por última vez.';
                    ApplicationArea = All;
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Trasladar)
            {
                Caption = 'Trasladar';
                ToolTip = 'Mueve todo o parte de este contenido a otra ubicación del mismo almacén.';
                ApplicationArea = All;
                Image = TransferOrder;

                trigger OnAction()
                begin
                    TrasladarContenido();
                end;
            }
            action(AlternarBloqueo)
            {
                Caption = 'Bloquear / desbloquear';
                ToolTip = 'Bloquea o desbloquea esta línea de contenido.';
                ApplicationArea = All;
                Image = Lock;

                trigger OnAction()
                begin
                    AlternarBloqueoContenido();
                end;
            }
        }
    }

    var
        EstiloFila: Text;

    trigger OnAfterGetRecord()
    begin
        EstiloFila := Rec.EstiloContenido();
    end;

    local procedure TrasladarContenido()
    var
        cContenido: Codeunit "Gestion Contenido SGA";
        destino: Code[20];
    begin
        if cContenido.TrasladarConDialogo(Rec, destino, '') <> 0 then
            CurrPage.Update(false);
    end;

    local procedure AlternarBloqueoContenido()
    var
        cContenido: Codeunit "Gestion Contenido SGA";
    begin
        cContenido.AlternarBloqueo(Rec);
        CurrPage.Update(false);
    end;
}
