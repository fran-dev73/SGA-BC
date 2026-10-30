namespace AntonioNadal.SGA;

using Microsoft.Inventory.Location;

/// <summary>
/// Page Mapa 3D Almacen SGA (ID 51122).
/// Vista en tres dimensiones del almacén: cada ubicación es un bloque colocado según su
/// estantería, columna y altura, y coloreado según lo ocupada que esté.
///
/// El dibujo lo hace el control add-in "Mapa 3D SGA"; esta página se limita a decidir qué
/// ubicaciones entran y a atender el clic sobre un bloque.
///
/// Se reconstruye cada vez que se abre o se cambia un filtro, así que refleja siempre las
/// estanterías que hay en ese momento: si se añaden o se quitan, aparece solo.
/// </summary>
page 51122 "Mapa 3D Almacen SGA"
{
    Caption = 'Mapa 3D de almacén';
    PageType = Card;
    UsageCategory = Tasks;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    SaveValues = false;
    AboutTitle = 'Mapa 3D de almacén';
    AboutText = 'Dibuja el almacén en volumen: cada bloque es una ubicación y su color dice si está vacía, con hueco, llena o bloqueada. Arrastre para girar, use la rueda para acercar y pulse un bloque para ver qué contiene. Con "Trasladar" (o Ctrl+arrastrar) lleve una ubicación hasta otra para mover su mercancía.';

    layout
    {
        area(Content)
        {
            group(Filtros)
            {
                Caption = 'Qué se dibuja';

                field(FiltroAlmacen; FiltroAlmacen)
                {
                    Caption = 'Almacén';
                    ToolTip = 'Almacén que se quiere ver.';
                    ApplicationArea = All;
                    TableRelation = Location;

                    trigger OnValidate()
                    begin
                        Refrescar();
                    end;
                }
                field(FiltroNave; FiltroNave)
                {
                    Caption = 'Nave';
                    ToolTip = 'Nave que se quiere ver. En blanco dibuja todas las del almacén.';
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        Refrescar();
                    end;
                }
                field(FiltroEstanteria; FiltroEstanteria)
                {
                    Caption = 'Estantería';
                    ToolTip = 'Estantería concreta. En blanco dibuja todas las de la nave.';
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        Refrescar();
                    end;
                }
                field(Resumen; Resumen)
                {
                    Caption = 'Resumen';
                    ToolTip = 'Cuántas ubicaciones se están dibujando y cómo están de ocupadas.';
                    ApplicationArea = All;
                    Editable = false;
                    MultiLine = true;
                }
            }
            usercontrol(Lienzo; "Mapa 3D SGA")
            {
                ApplicationArea = All;

                trigger ControlListo()
                begin
                    // El lienzo ya está montado: hasta ahora no había dónde pintar.
                    ControlPreparado := true;
                    Refrescar();
                end;

                trigger CeldaPulsada(prm_CodBin: Text)
                var
                    rContenido: Record "Contenido Ubicacion SGA";
                begin
                    rContenido.SetRange("Cod. Almacen", FiltroAlmacen);
                    rContenido.SetRange("Cod. Bin", CopyStr(prm_CodBin, 1, MaxStrLen(rContenido."Cod. Bin")));
                    Page.Run(Page::"Contenido Ubicaciones SGA", rContenido);
                end;

                trigger TrasladoSolicitado(prm_Origen: Text; prm_Destino: Text)
                begin
                    Trasladar(CopyStr(prm_Origen, 1, 20), CopyStr(prm_Destino, 1, 20));
                end;

                trigger VaciarSolicitado(prm_CodBin: Text)
                begin
                    Vaciar(CopyStr(prm_CodBin, 1, 20));
                end;

                trigger PasilloSeleccionado(prm_Estanteria: Text)
                begin
                    // El lienzo ya ha aislado el pasillo por su cuenta, así que aquí solo se
                    // acompaña el filtro de la página: no se vuelve a dibujar, que tiraría
                    // el giro y el zoom que el operario tenga puestos.
                    FiltroEstanteria := CopyStr(prm_Estanteria, 1, MaxStrLen(FiltroEstanteria));
                    CalcularResumen();
                    CurrPage.Update(false);
                end;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Actualizar)
            {
                Caption = 'Actualizar';
                ToolTip = 'Vuelve a leer las ubicaciones y redibuja el mapa.';
                ApplicationArea = All;
                Image = Refresh;

                trigger OnAction()
                begin
                    Refrescar();
                end;
            }
            action(VerRejilla)
            {
                Caption = 'Ver como rejilla';
                ToolTip = 'Abre el mapa plano, con una fila por altura y una columna por hueco.';
                ApplicationArea = All;
                Image = Map;
                RunObject = page "Mapa Almacen SGA";
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(Actualizar_Promoted; Actualizar)
                {
                }
            }
        }
    }

    var
        FiltroAlmacen: Code[10];
        FiltroNave: Code[1];
        FiltroEstanteria: Code[2];
        Resumen: Text;
        ControlPreparado: Boolean;

    trigger OnOpenPage()
    var
        rConfig: Record "Config. SGA";
    begin
        rConfig.ObtenerConfig();
        FiltroAlmacen := rConfig."Almacen por Defecto";
        // No se dibuja aquí: hay que esperar a que el lienzo avise de que está montado.
    end;

    local procedure Refrescar()
    var
        cMapa: Codeunit "Gestion Mapa SGA";
        datos: Text;
    begin
        if not ControlPreparado then
            exit;

        datos := cMapa.DatosMapa3D(FiltroAlmacen, FiltroNave, FiltroEstanteria);
        CurrPage.Lienzo.Dibujar(datos);
        CalcularResumen();
        CurrPage.Update(false);
    end;

    /// <summary>
    /// Traslado pedido arrastrando en el mapa. Si el origen tiene varias líneas (productos o
    /// lotes), se pregunta cuál; luego el diálogo de traslado sale con origen y destino puestos
    /// y el operario confirma la cantidad. Registra Cod. "Gestion Contenido SGA", como siempre.
    /// </summary>
    local procedure Trasladar(prm_Origen: Code[20]; prm_Destino: Code[20])
    var
        rContenido: Record "Contenido Ubicacion SGA";
        cContenido: Codeunit "Gestion Contenido SGA";
        cMapa: Codeunit "Gestion Mapa SGA";
        pContenido: Page "Contenido Ubicaciones SGA";
        destino: Code[20];
        SinContenidoTrasladarErr: Label 'La ubicación %1 no tiene contenido que trasladar.', Comment = '%1 = ubicación';
        TrasladadoMsg: Label 'Trasladado de %1 a %2.', Comment = '%1 = origen, %2 = destino';
        TrasladoMapa3DLbl: Label 'Traslado desde el mapa 3D';
    begin
        rContenido.SetRange("Cod. Almacen", FiltroAlmacen);
        rContenido.SetRange("Cod. Bin", prm_Origen);
        if rContenido.IsEmpty() then
            Error(SinContenidoTrasladarErr, prm_Origen);

        if rContenido.Count() > 1 then begin
            pContenido.SetTableView(rContenido);
            pContenido.LookupMode(true);
            if pContenido.RunModal() <> Action::LookupOK then
                exit;
            pContenido.GetRecord(rContenido);
        end else
            rContenido.FindFirst();

        // El operario puede cambiar en el diálogo el destino del arrastre: el mensaje lleva el elegido.
        destino := prm_Destino;
        if cContenido.TrasladarConDialogo(rContenido, destino, TrasladoMapa3DLbl) = 0 then
            exit;

        // Sin perder la vista: el operario sigue en el mismo giro, zoom y pasillo.
        CurrPage.Lienzo.Actualizar(cMapa.DatosMapa3D(FiltroAlmacen, FiltroNave, FiltroEstanteria));
        CalcularResumen();
        CurrPage.Update(false);
        Message(TrasladadoMsg, prm_Origen, destino);
    end;

    /// <summary>
    /// Vaciar desde el mapa (clic derecho en un bloque): se enseña qué hay, se confirma y todo
    /// queda sin ubicar. El mapa se repinta sin perder la vista.
    /// </summary>
    local procedure Vaciar(prm_CodBin: Code[20])
    var
        rContenido: Record "Contenido Ubicacion SGA";
        cContenido: Codeunit "Gestion Contenido SGA";
        cMapa: Codeunit "Gestion Mapa SGA";
        detalle: Text;
        lineas: Integer;
        LineaDetalleLbl: Label '\  · %1 %2 de %3 (lote %4)', Comment = '%1 = cantidad, %2 = unidad, %3 = producto, %4 = lote';
        VaciarUbicacionQst: Label 'Vaciar la ubicación %1:%2\\Todo queda sin ubicar, pendiente de volver a ubicar. El stock de BC no cambia. ¿Continuar?', Comment = '%1 = ubicación, %2 = lista del contenido';
        UbicacionVaciadaMsg: Label 'Ubicación %1 vaciada: %2 líneas quedan pendientes de ubicar.', Comment = '%1 = ubicación, %2 = líneas';
    begin
        rContenido.SetRange("Cod. Almacen", FiltroAlmacen);
        rContenido.SetRange("Cod. Bin", prm_CodBin);
        if not rContenido.FindSet() then
            exit;

        repeat
            detalle += StrSubstNo(LineaDetalleLbl, rContenido.Cantidad, rContenido."Cod. Unidad Medida",
                                  rContenido."No. Producto", rContenido."No. Lote");
        until rContenido.Next() = 0;

        if not Confirm(VaciarUbicacionQst, false, prm_CodBin, detalle) then
            exit;

        lineas := cContenido.VaciarUbicacion(FiltroAlmacen, prm_CodBin);

        CurrPage.Lienzo.Actualizar(cMapa.DatosMapa3D(FiltroAlmacen, FiltroNave, FiltroEstanteria));
        CalcularResumen();
        CurrPage.Update(false);
        Message(UbicacionVaciadaMsg, prm_CodBin, lineas);
    end;

    local procedure CalcularResumen()
    var
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        IndiqueAlmacenLbl: Label 'Indique un almacén para dibujar el mapa.';
    begin
        if FiltroAlmacen = '' then begin
            Resumen := IndiqueAlmacenLbl;
            exit;
        end;

        Resumen := cUbicaciones.ResumenUbicaciones(FiltroAlmacen);
    end;
}
