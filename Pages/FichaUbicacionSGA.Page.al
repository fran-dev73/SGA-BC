namespace AntonioNadal.SGA;

/// <summary>
/// Page Ficha Ubicacion SGA (ID 51101).
/// Ficha de una ubicación: sus atributos de gestión y, debajo, lo que hay dentro.
/// </summary>
page 51101 "Ficha Ubicacion SGA"
{
    Caption = 'Ficha ubicación SGA';
    PageType = Card;
    SourceTable = "Ubicacion SGA";
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Cod. Almacen"; Rec."Cod. Almacen")
                {
                    ToolTip = 'Almacén al que pertenece la ubicación.';
                    ApplicationArea = All;
                }
                field("Cod. Bin"; Rec."Cod. Bin")
                {
                    ToolTip = 'Código de la ubicación en la topología pasillo-estantería-altura (101-15-03).';
                    ApplicationArea = All;
                }
                field(Descripcion; Rec.Descripcion)
                {
                    ToolTip = 'Descripción libre de la ubicación.';
                    ApplicationArea = All;
                }
                field("Cod. Zona SGA"; Rec."Cod. Zona SGA")
                {
                    Editable = EsVacia;
                    ToolTip = 'Zona a la que pertenece la ubicación. Al asignarla se heredan el tipo y la ruta de la zona.';
                    ApplicationArea = All;
                }
                field("Tipo Ubicacion"; Rec."Tipo Ubicacion")
                {
                    Editable = EsVacia;
                    ApplicationArea = All;
                }
                field("Secuencia Picking"; Rec."Secuencia Picking")
                {
                    Editable = EsVacia;
                    ToolTip = 'Orden de recorrido físico. Los motores de picking y de ubicación recorren las ubicaciones por este valor.';
                    ApplicationArea = All;
                }
                field("Digito Colocado"; Rec."Digito Colocado")
                {
                    ApplicationArea = All;
                }
            }
            group(Ocupacion)
            {
                Caption = 'Ocupación';

                field("Estado SGA"; Rec."Estado SGA")
                {
                    ToolTip = 'Estado de ocupación calculado: vacía, parcial, llena o bloqueada.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field("% Ocupacion"; Rec."% Ocupacion")
                {
                    ToolTip = 'Porcentaje de la capacidad declarada que está ocupado.';
                    ApplicationArea = All;
                    StyleExpr = EstiloFila;
                }
                field("Cantidad Base"; Rec."Cantidad Base")
                {
                    ToolTip = 'Unidades base que hay actualmente en la ubicación.';
                    ApplicationArea = All;
                }
                field("Lineas Contenido"; Rec."Lineas Contenido")
                {
                    ToolTip = 'Número de combinaciones producto-lote distintas que hay en la ubicación.';
                    ApplicationArea = All;
                }
                field("Fecha Ultimo Movimiento"; Rec."Fecha Ultimo Movimiento")
                {
                    ToolTip = 'Fecha y hora del último movimiento registrado en la ubicación.';
                    ApplicationArea = All;
                }
            }
            group(Capacidad)
            {
                Caption = 'Capacidad';

                field("Capacidad Uds."; Rec."Capacidad Uds.")
                {
                    Editable = EsVacia;
                    ToolTip = 'Cuántos palés caben; cada producto se cuenta con su palé por defecto. 0 significa sin límite declarado, y entonces cualquier contenido la marca como llena.';
                    ApplicationArea = All;
                }
                field("Control Capacidad"; Rec."Control Capacidad")
                {
                    Editable = EsVacia;
                    ApplicationArea = All;
                }
                field("Capacidad Volumen"; Rec."Capacidad Volumen")
                {
                    Editable = EsVacia;
                    ToolTip = 'Volumen que admite la ubicación. Informativo.';
                    ApplicationArea = All;
                }
                field("Capacidad Peso"; Rec."Capacidad Peso")
                {
                    Editable = EsVacia;
                    ToolTip = 'Peso que admite la ubicación. Informativo.';
                    ApplicationArea = All;
                }
            }
            group(Reglas)
            {
                Caption = 'Reglas';

                field(Bloqueada; Rec.Bloqueada)
                {
                    ToolTip = 'Si está activo, la ubicación no admite entradas ni se propone para recoger.';
                    ApplicationArea = All;
                }
                field("Motivo Bloqueo"; Rec."Motivo Bloqueo")
                {
                    ToolTip = 'Razón del bloqueo.';
                    ApplicationArea = All;
                    Enabled = Rec.Bloqueada;
                }
                field("Permite Mezcla Producto"; Rec."Permite Mezcla Producto")
                {
                    Editable = EsVacia;
                    ToolTip = 'Si se desactiva, la ubicación solo puede contener un producto a la vez.';
                    ApplicationArea = All;
                }
                field("Permite Mezcla Lote"; Rec."Permite Mezcla Lote")
                {
                    Editable = EsVacia;
                    ToolTip = 'Si se desactiva, la ubicación solo puede contener un lote a la vez.';
                    ApplicationArea = All;
                }
                field("Producto Fijo"; Rec."Producto Fijo")
                {
                    Editable = EsVacia;
                    ToolTip = 'Producto que tiene esta ubicación como casa. Solo se admite este producto.';
                    ApplicationArea = All;
                }
            }
            group(Reposicion)
            {
                Caption = 'Reposición';

                field("Ctdad. Minima"; Rec."Ctdad. Minima")
                {
                    Editable = EsVacia;
                    ToolTip = 'Por debajo de esta cantidad la ubicación es candidata a reposición desde reserva.';
                    ApplicationArea = All;
                }
                field("Ctdad. Maxima"; Rec."Ctdad. Maxima")
                {
                    Editable = EsVacia;
                    ToolTip = 'Cantidad hasta la que se repone la ubicación.';
                    ApplicationArea = All;
                }
            }
            part(Contenido; "Contenido Ubicacion Subpag")
            {
                Caption = 'Contenido';
                ApplicationArea = All;
                SubPageLink = "Cod. Almacen" = field("Cod. Almacen"),
                              "Cod. Bin" = field("Cod. Bin");
                UpdatePropagation = Both;
            }
        }
        area(FactBoxes)
        {
            part(MovimientosFactBox; "Movs. Ubicacion FactBox")
            {
                Caption = 'Últimas entradas en la ubicación';
                ApplicationArea = All;
                SubPageLink = "Cod. Almacen" = field("Cod. Almacen"),
                              "Cod. Bin Destino" = field("Cod. Bin");
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(VerMovsEntrada)
            {
                Caption = 'Movimientos de entrada';
                ToolTip = 'Muestra lo que ha entrado en esta ubicación.';
                ApplicationArea = All;
                Image = Entries;
                RunObject = page "Movs. Ubicacion SGA";
                RunPageLink = "Cod. Almacen" = field("Cod. Almacen"),
                              "Cod. Bin Destino" = field("Cod. Bin");
            }
            action(VerMovsSalida)
            {
                Caption = 'Movimientos de salida';
                ToolTip = 'Muestra lo que ha salido de esta ubicación.';
                ApplicationArea = All;
                Image = Entries;
                RunObject = page "Movs. Ubicacion SGA";
                RunPageLink = "Cod. Almacen" = field("Cod. Almacen"),
                              "Cod. Bin Origen" = field("Cod. Bin");
            }
        }
        area(Processing)
        {
            action(RecalcularEstado)
            {
                Caption = 'Recalcular ocupación';
                ToolTip = 'Vuelve a calcular el estado y el porcentaje de ocupación de esta ubicación.';
                ApplicationArea = All;
                Image = Recalculate;

                trigger OnAction()
                begin
                    Rec.RecalcularOcupacion();
                    Rec.Modify(true);
                    CurrPage.Update(false);
                end;
            }
            action(VaciarUbicacion)
            {
                Caption = 'Vaciar ubicación';
                ToolTip = 'Saca todo lo que hay en esta ubicación y lo deja sin ubicar (pendiente de ubicar). No toca el stock de BC.';
                ApplicationArea = All;
                Image = RemoveLine;

                trigger OnAction()
                var
                    cContenido: Codeunit "Gestion Contenido SGA";
                    lineas: Integer;
                    UbicacionVaciaErr: Label 'La ubicación %1 está vacía.', Comment = '%1 = ubicación';
                    VaciarUbicacionQst: Label 'Se va a vaciar la ubicación %1 (%2 líneas de contenido). La mercancía queda sin ubicar, pendiente de volver a ubicar. ¿Continuar?', Comment = '%1 = ubicación, %2 = líneas';
                    UbicacionVaciadaMsg: Label 'Ubicación %1 vaciada: %2 líneas quedan pendientes de ubicar.', Comment = '%1 = ubicación, %2 = líneas';
                begin
                    Rec.CalcFields("Lineas Contenido");
                    if Rec."Lineas Contenido" = 0 then
                        Error(UbicacionVaciaErr, Rec."Cod. Bin");
                    if not Confirm(VaciarUbicacionQst, false, Rec."Cod. Bin", Rec."Lineas Contenido") then
                        exit;

                    lineas := cContenido.VaciarUbicacion(Rec."Cod. Almacen", Rec."Cod. Bin");
                    CurrPage.Update(false);
                    Message(UbicacionVaciadaMsg, Rec."Cod. Bin", lineas);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';

                actionref(RecalcularEstado_Promoted; RecalcularEstado)
                {
                }
                actionref(VaciarUbicacion_Promoted; VaciarUbicacion)
                {
                }
            }
        }
    }

    var
        EstiloFila: Text;
        // La configuración solo se cambia con la ubicación vacía (ver TestVacia de la tabla).
        EsVacia: Boolean;

    trigger OnAfterGetRecord()
    begin
        EstiloFila := Rec.EstiloEstado();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        EsVacia := Rec.EstaVacia();
    end;
}
