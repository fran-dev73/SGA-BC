namespace AntonioNadal.SGA;

using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;

/// <summary>
/// Page Pendiente Ubicar SGA (ID 51131).
/// Lo que hay en stock y no está en ninguna ubicación, lote a lote, para ubicarlo: uno a uno a
/// mano (abre "Ubicar producto" con todo puesto) o varios a la vez (reparto por huecos libres,
/// como la carga inicial, con el resultado y el motivo de lo que no quepa).
///
/// Se calcula al abrir, sin lanzar la conciliación. De lo sin ubicar separa lo que está
/// pendiente en "Ubicar recepciones" o "Ubicar ensamblados": eso no se ubica desde aquí, para que
/// esas pantallas no lo vuelvan a pedir (ver CargarPendienteUbicar de "Consulta Stock SGA").
/// </summary>
page 51131 "Pendiente Ubicar SGA"
{
    Caption = 'Pendiente de ubicar';
    // Worksheet y no List: hace falta la cabecera con el almacén.
    PageType = Worksheet;
    SourceTable = "Pendiente Ubicar SGA";
    SourceTableTemporary = true;
    UsageCategory = Tasks;
    ApplicationArea = All;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    AboutTitle = 'Pendiente de ubicar';
    AboutText = 'Stock que no está en ninguna ubicación. "Ubicar" abre Ubicar producto con la línea ya puesta; "Ubicar seleccionadas" busca hueco para varias a la vez y enseña lo que no cabe y por qué. Lo que está pendiente en recepciones o ensamblados se ubica desde esas pantallas.';

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
                    ToolTip = 'Almacén cuyo stock sin ubicar se enseña.';
                    ApplicationArea = All;
                    TableRelation = Location;

                    trigger OnValidate()
                    begin
                        Recalcular();
                    end;
                }
                field(Resumen; Resumen)
                {
                    Caption = 'Situación';
                    ToolTip = 'Cuántos lotes tienen algo sin ubicar y cuántas unidades base se pueden ubicar desde aquí.';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                }
            }
            repeater(Lineas)
            {
                Editable = false;

                field("No. Producto"; Rec."No. Producto")
                {
                    ApplicationArea = All;
                }
                field(Descripcion; Rec.Descripcion)
                {
                    ApplicationArea = All;
                }
                field("Cod. Variante"; Rec."Cod. Variante")
                {
                    ApplicationArea = All;
                    Visible = false;
                }
                field("No. Lote"; Rec."No. Lote")
                {
                    ApplicationArea = All;
                }
                field("Fecha Caducidad"; Rec."Fecha Caducidad")
                {
                    ApplicationArea = All;
                }
                field("A Ubicar"; Rec."A Ubicar")
                {
                    ApplicationArea = All;
                    Style = Strong;
                }
                field(Desglose; Rec.Desglose)
                {
                    ApplicationArea = All;
                }
                field("En Documentos"; Rec."En Documentos")
                {
                    ApplicationArea = All;
                    StyleExpr = EstiloDocumentos;
                }
                field(Pendiente; Rec.Pendiente)
                {
                    ApplicationArea = All;
                }
                field("Stock BC"; Rec."Stock BC")
                {
                    ApplicationArea = All;
                    Visible = false;
                }
                field("Stock SGA"; Rec."Stock SGA")
                {
                    ApplicationArea = All;
                    Visible = false;
                }
                field("Unidad Medida Base"; Rec."Unidad Medida Base")
                {
                    ApplicationArea = All;
                }
                field("Cod. Almacen"; Rec."Cod. Almacen")
                {
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
            action(Ubicar)
            {
                Caption = 'Ubicar';
                ToolTip = 'Abre Ubicar producto con esta línea ya puesta (producto, lote, caducidad y lo que hay que ubicar aquí). Allí se propone el hueco de cada parte y se confirma, o se cambia a mano.';
                ApplicationArea = All;
                Image = CreatePutAway;

                trigger OnAction()
                var
                    pUbicar: Page "Ubicar Producto SGA";
                    SoloEnDocumentosErr: Label 'Lo sin ubicar de este lote está pendiente en recepciones o ensamblados: ubíquelo desde "Ubicar recepciones" o "Ubicar ensamblados".';
                begin
                    if Rec."A Ubicar" <= 0 then
                        Error(SoloEnDocumentosErr);
                    pUbicar.Preparar(Rec."Cod. Almacen", Rec."No. Producto", Rec."Cod. Variante", Rec."No. Lote",
                                     Rec."Fecha Caducidad", Rec."A Ubicar");
                    pUbicar.RunModal();
                    Recalcular();
                end;
            }
            action(UbicarSeleccionadas)
            {
                Caption = 'Ubicar seleccionadas';
                ToolTip = 'Busca hueco para lo que hay que ubicar aquí de las líneas seleccionadas, como la carga inicial: palés a huecos de palé, cajas a caja o a palé según cuántas sean, y botellas a huecos de unidad. Se puede simular antes. Al terminar enseña lo ubicado y, de lo que no cabe, el motivo.';
                ApplicationArea = All;
                Image = PutawayLines;

                trigger OnAction()
                begin
                    UbicarSeleccion();
                end;
            }
            action(Actualizar)
            {
                Caption = 'Actualizar';
                ToolTip = 'Vuelve a calcular lo que está sin ubicar.';
                ApplicationArea = All;
                Image = Refresh;

                trigger OnAction()
                begin
                    Recalcular();
                end;
            }
        }
        area(Navigation)
        {
            action(VerContenido)
            {
                Caption = 'Dónde está el producto';
                ToolTip = 'Ubicaciones en las que ya hay de este producto.';
                ApplicationArea = All;
                Image = BinContent;
                RunObject = page "Contenido Ubicaciones SGA";
                RunPageLink = "No. Producto" = field("No. Producto"), "Cod. Almacen" = field("Cod. Almacen");
            }
            action(VerMovsProducto)
            {
                Caption = 'Movimientos del producto';
                ToolTip = 'Movimientos de producto de BC de este producto y lote en el almacén.';
                ApplicationArea = All;
                Image = ItemLedger;
                RunObject = page "Item Ledger Entries";
                RunPageLink = "Item No." = field("No. Producto"), "Location Code" = field("Cod. Almacen"), "Lot No." = field("No. Lote");
            }
            action(IrRecepciones)
            {
                Caption = 'Ubicar recepciones';
                ToolTip = 'Abre Ubicar recepciones, donde se ubica lo pendiente de los albaranes de compra.';
                ApplicationArea = All;
                Image = Receipt;
                RunObject = page "Ubicar Entradas SGA";
                RunPageView = where(Origen = const(Compra));
            }
            action(IrEnsamblados)
            {
                Caption = 'Ubicar ensamblados';
                ToolTip = 'Abre Ubicar ensamblados, donde se ubica lo pendiente de los embotellados.';
                ApplicationArea = All;
                Image = Production;
                RunObject = page "Ubicar Entradas SGA";
                RunPageView = where(Origen = const(Produccion));
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(Ubicar_Promoted; Ubicar)
                {
                }
                actionref(UbicarSeleccionadas_Promoted; UbicarSeleccionadas)
                {
                }
                actionref(Actualizar_Promoted; Actualizar)
                {
                }
            }
        }
    }

    var
        FiltroAlmacen: Code[10];
        Resumen: Text;
        EstiloDocumentos: Text;

    trigger OnOpenPage()
    var
        rConfig: Record "Config. SGA";
    begin
        rConfig.ObtenerConfig();
        FiltroAlmacen := rConfig."Almacen por Defecto";
        Recalcular();
    end;

    trigger OnAfterGetRecord()
    begin
        EstiloDocumentos := 'Standard';
        if Rec."En Documentos" > 0 then
            EstiloDocumentos := 'Ambiguous';
    end;

    local procedure Recalcular()
    var
        cStock: Codeunit "Consulta Stock SGA";
        numLineas: Integer;
        aUbicar: Decimal;
        enDocumentos: Decimal;
        ResumenLbl: Label '%1 lotes con algo sin ubicar: %2 unidades a ubicar desde aquí y %3 pendientes en recepciones o ensamblados.', Comment = '%1 = lotes, %2 = unidades a ubicar aquí, %3 = unidades en documentos';
        SinAlmacenLbl: Label 'Indique el almacén.';
        TodoUbicadoLbl: Label 'Todo el stock del almacén está ubicado.';
    begin
        Rec.Reset();
        Rec.DeleteAll();
        Resumen := SinAlmacenLbl;
        if FiltroAlmacen <> '' then begin
            numLineas := cStock.CargarPendienteUbicar(FiltroAlmacen, Rec);
            Rec.Reset();
            Rec.CalcSums("A Ubicar", "En Documentos");
            aUbicar := Rec."A Ubicar";
            enDocumentos := Rec."En Documentos";
            if numLineas = 0 then
                Resumen := TodoUbicadoLbl
            else
                Resumen := StrSubstNo(ResumenLbl, numLineas, aUbicar, enDocumentos);
        end;
        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    /// <summary>
    /// Reparte por huecos libres lo que hay que ubicar aquí de las líneas seleccionadas, con la
    /// carga inicial en modo "solo pendientes", y enseña su resultado.
    /// </summary>
    local procedure UbicarSeleccion()
    var
        TempSeleccion: Record "Pendiente Ubicar SGA" temporary;
        TempResultado: Record "Linea Ubicacion SGA" temporary;
        cCarga: Codeunit "Carga Inicial SGA";
        pResultado: Page "Resultado Carga Inicial SGA";
        opcion: Integer;
        simular: Boolean;
        productos: Integer;
        cargadas: Decimal;
        noCargadas: Decimal;
        textoError: Text;
        NadaQueUbicarErr: Label 'Ninguna de las líneas seleccionadas tiene nada que ubicar desde aquí: lo que les falta está pendiente en recepciones o ensamblados.';
        OpcionesTxt: Label 'Ubicar ahora,Solo simular (no guarda nada)';
        PreguntaLbl: Label 'Buscar hueco para %1 lotes seleccionados:', Comment = '%1 = número de lotes';
        TerminadoMsg: Label 'Terminado.\Unidades ubicadas: %1.\Unidades sin sitio: %2 (el motivo de cada una está en el detalle).', Comment = '%1 = ubicadas, %2 = sin sitio';
        SimuladoMsg: Label 'Simulación (no se ha guardado nada).\Unidades que se ubicarían: %1.\Unidades sin sitio: %2 (el motivo de cada una está en el detalle).', Comment = '%1 = ubicadas, %2 = sin sitio';
    begin
        CurrPage.SetSelectionFilter(Rec);
        Rec.SetFilter("A Ubicar", '>0');
        if Rec.FindSet() then
            repeat
                TempSeleccion := Rec;
                TempSeleccion.Insert();
            until Rec.Next() = 0;
        Rec.Reset();
        if TempSeleccion.IsEmpty() then
            Error(NadaQueUbicarErr);

        opcion := StrMenu(OpcionesTxt, 1, StrSubstNo(PreguntaLbl, TempSeleccion.Count()));
        if opcion = 0 then
            exit;
        simular := opcion = 2;

        cCarga.Configurar(FiltroAlmacen, 2, '', false, simular, '');
        cCarga.FijarPendientes(TempSeleccion);
        // Codeunit.Run para recoger el fin de simulación, que llega como error para que la base
        // de datos deshaga lo escrito.
        if not cCarga.Run() then begin
            textoError := GetLastErrorText();
            if not cCarga.EsFinSimulacion(textoError) then
                Error(textoError);
        end;

        cCarga.ObtenerTotales(productos, cargadas, noCargadas);
        cCarga.ObtenerResultado(TempResultado);
        if simular then
            Message(SimuladoMsg, cargadas, noCargadas)
        else
            Message(TerminadoMsg, cargadas, noCargadas);
        if not TempResultado.IsEmpty() then begin
            pResultado.Rellenar(TempResultado);
            pResultado.RunModal();
        end;

        Recalcular();
    end;
}
