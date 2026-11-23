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
    // Alta y baja a mano desde la lista abierta en Configuración: al crear se crea también su
    // ubicación de BC y al eliminar se elimina (OnInsert y OnDelete de la tabla). Abierta desde
    // Consultas va en modo Ver.

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
                    ToolTip = 'Código de la ubicación en la topología pasillo-estantería-altura (101-15-03). Al crear una ubicación nueva, también se crea en BC si no existe.';
                    ApplicationArea = All;
                }
                field(Descripcion; Rec.Descripcion)
                {
                    ApplicationArea = All;
                }
                field("Cod. Zona SGA"; Rec."Cod. Zona SGA")
                {
                    Editable = EsVacia;
                    ToolTip = 'Zona a la que pertenece la ubicación. Al asignarla toma la secuencia de picking de la zona si aún no tiene.';
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
                    ApplicationArea = All;
                    StyleExpr = EstiloPorcentaje;
                }
                field("Cantidad Base"; Rec."Cantidad Base")
                {
                    ToolTip = 'Unidades base que hay actualmente en la ubicación.';
                    ApplicationArea = All;
                }
                field("Lineas Contenido"; Rec."Lineas Contenido")
                {
                    ToolTip = 'Número de líneas de contenido de la ubicación: una por producto, lote y palé.';
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
                    ApplicationArea = All;
                    Enabled = Rec.Bloqueada;
                }
                field("Reservada Para"; Rec."Reservada Para")
                {
                    ApplicationArea = All;
                    Style = Attention;
                }
                field("Reservada Por"; Rec."Reservada Por")
                {
                    ApplicationArea = All;
                }
                field("Fecha Reserva"; Rec."Fecha Reserva")
                {
                    ApplicationArea = All;
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
                field(Fondo; Rec.Fondo)
                {
                    ApplicationArea = All;
                }
                field("Producto Fijo"; Rec."Producto Fijo")
                {
                    Editable = EsVacia;
                    ToolTip = 'Producto que tiene esta ubicación como casa. Solo se admite este producto.';
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
                Enabled = Modificable;

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
                Enabled = Modificable;

                trigger OnAction()
                var
                    rContenido: Record "Contenido Ubicacion SGA";
                    cContenido: Codeunit "Gestion Contenido SGA";
                begin
                    rContenido.FiltrarUbicacion(Rec."Cod. Almacen", Rec."Cod. Bin");
                    if cContenido.DesubicarConDialogo(rContenido) > 0 then
                        CurrPage.Update(false);
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
        EstiloPorcentaje: Text;
        // La configuración solo se cambia con la ubicación vacía (ver TestVacia de la tabla).
        EsVacia: Boolean;
        // En modo ver (desde Consultas) no se ejecuta nada que cambie datos.
        Modificable: Boolean;

    trigger OnAfterGetRecord()
    begin
        EstiloFila := Rec.EstiloEstado();
        EstiloPorcentaje := Rec.EstiloOcupacion();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        EsVacia := Rec.EstaVacia();
        Modificable := CurrPage.Editable();
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    var
        rConfig: Record "Config. SGA";
    begin
        // Si la lista viene filtrada por un almacén, ya lo trae; si no, el de por defecto.
        if Rec."Cod. Almacen" = '' then
            Rec."Cod. Almacen" := rConfig.AlmacenODefecto('');
        EsVacia := true;
    end;
}
