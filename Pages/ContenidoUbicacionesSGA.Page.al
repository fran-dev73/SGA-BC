namespace AntonioNadal.SGA;

/// <summary>
/// Page Contenido Ubicaciones SGA (ID 51103).
/// Vista transversal del contenido de todas las ubicaciones: permite responder
/// "qué hay en esta ubicación" y "dónde está este producto" desde el mismo sitio.
/// </summary>
page 51103 "Contenido Ubicaciones SGA"
{
    Caption = 'Contenido de ubicaciones';
    PageType = List;
    SourceTable = "Contenido Ubicacion SGA";
    UsageCategory = Lists;
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
                field("Cod. Almacen"; Rec."Cod. Almacen")
                {
                    ToolTip = 'Almacén en el que está la mercancía.';
                    ApplicationArea = All;
                }
                field("Cod. Bin"; Rec."Cod. Bin")
                {
                    ToolTip = 'Ubicación en la que está la mercancía.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field("Cod. Zona SGA"; Rec."Cod. Zona SGA")
                {
                    ToolTip = 'Zona de la ubicación.';
                    ApplicationArea = All;
                }
                field("Tipo Ubicacion"; Rec."Tipo Ubicacion")
                {
                    ToolTip = 'Uso funcional de la ubicación.';
                    ApplicationArea = All;
                }
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
                field("Secuencia Picking"; Rec."Secuencia Picking")
                {
                    ToolTip = 'Orden de recorrido físico de la ubicación.';
                    ApplicationArea = All;
                    Visible = false;
                }
                field("Fecha Ultima Entrada"; Rec."Fecha Ultima Entrada")
                {
                    ToolTip = 'Fecha y hora en que entró por última vez.';
                    ApplicationArea = All;
                }
                field("Fecha Ultima Salida"; Rec."Fecha Ultima Salida")
                {
                    ToolTip = 'Fecha y hora en que salió por última vez.';
                    ApplicationArea = All;
                    Visible = false;
                }
            }
        }
        area(FactBoxes)
        {
            part(MovimientosFactBox; "Movs. Ubicacion FactBox")
            {
                Caption = 'Últimos movimientos del producto';
                ApplicationArea = All;
                SubPageLink = "No. Producto" = field("No. Producto");
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
            action(Recontar)
            {
                Caption = 'Recontar';
                ToolTip = 'Ajusta esta línea a la cantidad realmente contada y registra la diferencia como recuento.';
                ApplicationArea = All;
                Image = PhysicalInventory;

                trigger OnAction()
                begin
                    RecontarContenido();
                end;
            }
            action(Desubicar)
            {
                Caption = 'Quitar de la ubicación';
                ToolTip = 'Saca de su ubicación las líneas seleccionadas y las deja pendientes de ubicar. No toca el stock de BC: la mercancía sigue en el almacén y vuelve a salir en "Ubicar producto" para colocarla bien.';
                ApplicationArea = All;
                Image = RemoveLine;

                trigger OnAction()
                begin
                    DesubicarSeleccion();
                end;
            }
        }
        area(Navigation)
        {
            action(VerUbicacion)
            {
                Caption = 'Ficha de la ubicación';
                ToolTip = 'Abre la ficha SGA de la ubicación.';
                ApplicationArea = All;
                Image = BinContent;
                RunObject = page "Ficha Ubicacion SGA";
                RunPageLink = "Cod. Almacen" = field("Cod. Almacen"),
                              "Cod. Bin" = field("Cod. Bin");
            }
            action(VerMovimientos)
            {
                Caption = 'Movimientos';
                ToolTip = 'Muestra los movimientos de ubicación de este producto y lote.';
                ApplicationArea = All;
                Image = Entries;
                RunObject = page "Movs. Ubicacion SGA";
                RunPageLink = "No. Producto" = field("No. Producto"),
                              "No. Lote" = field("No. Lote");
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(Trasladar_Promoted; Trasladar)
                {
                }
                actionref(Recontar_Promoted; Recontar)
                {
                }
                actionref(AlternarBloqueo_Promoted; AlternarBloqueo)
                {
                }
                actionref(Desubicar_Promoted; Desubicar)
                {
                }
            }
            group(Category_Navigate)
            {
                Caption = 'Contenido';

                actionref(VerUbicacion_Promoted; VerUbicacion)
                {
                }
                actionref(VerMovimientos_Promoted; VerMovimientos)
                {
                }
            }
        }
    }

    views
    {
        view(SoloBloqueado)
        {
            Caption = 'Bloqueado';
            Filters = where(Bloqueado = const(true));
        }
        view(Reservado)
        {
            Caption = 'Con reserva';
            Filters = where("Cantidad Reservada" = filter(> 0));
        }
    }

    var
        EstiloFila: Text;

    trigger OnAfterGetRecord()
    begin
        EstiloFila := Rec.EstiloContenido();
    end;

    /// <summary>
    /// Saca de su ubicación las líneas seleccionadas, enteras, con una salida en el diario.
    /// El stock de BC no cambia, así que la mercancía queda pendiente de ubicar: vuelve a salir
    /// en "Ubicar producto" y en la conciliación como sin ubicar. Sirve para deshacer una
    /// ubicación equivocada sin tener que inventarse un recuento.
    ///
    /// No se deja quitar lo reservado por una orden de picking: se quedaría sin el stock que
    /// tiene que recoger. Hay que cancelar antes la orden o su parada.
    /// </summary>
    local procedure DesubicarSeleccion()
    var
        rContenido: Record "Contenido Ubicacion SGA";
        TempCopia: Record "Contenido Ubicacion SGA" temporary;
        cContenido: Codeunit "Gestion Contenido SGA";
        lineas: Integer;
        hechas: Integer;
        DesubicarLineasQst: Label 'Se van a quitar de su ubicación %1 líneas de contenido. La mercancía queda pendiente de ubicar (el stock de BC no cambia). ¿Continuar?', Comment = '%1 = número de líneas';
        LineaDesubicadaMsg: Label 'Se ha quitado %1 %2 de %3 de la ubicación %4. Queda pendiente de ubicar.', Comment = '%1 = cantidad, %2 = unidad, %3 = producto, %4 = ubicación';
        LineasDesubicadasMsg: Label 'Se han quitado %1 líneas de sus ubicaciones. Quedan pendientes de ubicar.', Comment = '%1 = número de líneas';
        LineaReservadaErr: Label 'La línea de %1 en %2 tiene %3 reservadas por una orden de picking. Cancele antes la orden o la parada.', Comment = '%1 = producto, %2 = ubicación, %3 = cantidad reservada';
    begin
        CurrPage.SetSelectionFilter(rContenido);
        lineas := rContenido.Count();
        if lineas = 0 then
            exit;

        if not Confirm(DesubicarLineasQst, false, lineas) then
            exit;

        if rContenido.FindSet() then
            repeat
                if rContenido."Cantidad Reservada" > 0 then
                    Error(LineaReservadaErr, rContenido."No. Producto", rContenido."Cod. Bin", rContenido."Cantidad Reservada");
            until rContenido.Next() = 0;

        // Se copian antes a una tabla temporal: la salida borra la línea al dejarla a cero, y
        // recorrer la tabla real mientras se borra podría saltarse líneas.
        rContenido.FindSet();
        repeat
            TempCopia := rContenido;
            TempCopia.Insert();
        until rContenido.Next() = 0;

        TempCopia.FindSet();
        repeat
            cContenido.Desubicar(TempCopia);
            hechas += 1;
        until TempCopia.Next() = 0;

        if hechas = 1 then
            Message(LineaDesubicadaMsg, TempCopia.Cantidad, TempCopia."Cod. Unidad Medida", TempCopia."No. Producto", TempCopia."Cod. Bin")
        else
            Message(LineasDesubicadasMsg, hechas);

        CurrPage.Update(false);
    end;

    local procedure TrasladarContenido()
    var
        cContenido: Codeunit "Gestion Contenido SGA";
        pagMover: Page "Mover Contenido SGA";
        noMovimiento: Integer;
    begin
        pagMover.Inicializar(Rec);
        if pagMover.RunModal() <> Action::OK then
            exit;

        noMovimiento := cContenido.RegistrarTraslado(Rec."Cod. Almacen", Rec."Cod. Bin",
                                                     pagMover.ObtenerDestino(), Rec."No. Producto",
                                                     Rec."Cod. Variante", Rec."No. Lote",
                                                     Rec."Cod. Unidad Medida", pagMover.ObtenerCantidad(),
                                                     "Origen Mov. SGA"::Manual, '', 0, pagMover.ObtenerMotivo());
        if noMovimiento <> 0 then
            CurrPage.Update(false);
    end;

    local procedure AlternarBloqueoContenido()
    var
        cContenido: Codeunit "Gestion Contenido SGA";
        motivo: Text[50];
        BloqueadoPorLbl: Label 'Bloqueado por %1 el %2', Comment = '%1 = usuario, %2 = fecha';
    begin
        if Rec.Bloqueado then begin
            cContenido.BloquearContenido(Rec, false, '');
            CurrPage.Update(false);
            exit;
        end;

        motivo := CopyStr(StrSubstNo(BloqueadoPorLbl, UserId(), Format(Today())), 1, MaxStrLen(motivo));
        cContenido.BloquearContenido(Rec, true, motivo);
        CurrPage.Update(false);
    end;

    local procedure RecontarContenido()
    var
        cContenido: Codeunit "Gestion Contenido SGA";
        pagRecontar: Page "Recontar Contenido SGA";
        noMovimiento: Integer;
        SinDiferenciaMsg: Label 'No había diferencia: la cantidad contada coincide con la registrada.';
    begin
        pagRecontar.Inicializar(Rec);
        if pagRecontar.RunModal() <> Action::OK then
            exit;

        noMovimiento := cContenido.RegistrarRecuento(Rec."Cod. Almacen", Rec."Cod. Bin", Rec."No. Producto",
                                                     Rec."Cod. Variante", Rec."No. Lote",
                                                     pagRecontar.ObtenerCantidadContada(),
                                                     pagRecontar.ObtenerMotivo());
        if noMovimiento = 0 then
            Message(SinDiferenciaMsg);

        CurrPage.Update(false);
    end;
}
