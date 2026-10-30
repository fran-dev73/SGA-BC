namespace AntonioNadal.SGA;

using Microsoft.Inventory.Location;

/// <summary>
/// Page Mapa Almacen SGA (ID 51107).
/// Rejilla de la nave: una fila por altura de cada estantería y una columna por columna
/// física. Cada celda muestra qué hay en ese hueco y se colorea según su estado, de modo
/// que se ve de un golpe de vista qué está vacío, qué está lleno y qué está bloqueado.
///
/// Al pulsar una celda se abre el contenido de esa ubicación.
/// </summary>
page 51107 "Mapa Almacen SGA"
{
    Caption = 'Mapa de almacén';
    PageType = List;
    SourceTable = "Buffer Mapa SGA";
    SourceTableTemporary = true;
    UsageCategory = Tasks;
    ApplicationArea = All;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    AboutTitle = 'Mapa de almacén';
    AboutText = 'Dibuja las ubicaciones como una rejilla: cada columna es un hueco del pasillo y cada fila una altura, con el color según lo ocupada que esté. Filtre por estantería para verla de frente, como un alzado. Pulse una celda para ver qué contiene. Se reconstruye cada vez que se abre, así que refleja siempre las estanterías que hay ahora.';

    layout
    {
        area(Content)
        {
            group(Seleccion)
            {
                Caption = 'Selección';

                field(FiltroAlmacen; FiltroAlmacen)
                {
                    Caption = 'Almacén';
                    ToolTip = 'Almacén cuya nave se quiere ver.';
                    ApplicationArea = All;
                    TableRelation = Location;

                    trigger OnValidate()
                    begin
                        Construir();
                    end;
                }
                field(FiltroNave; FiltroNave)
                {
                    Caption = 'Nave';
                    ToolTip = 'Nave que se quiere dibujar. En blanco dibuja todas las naves del almacén.';
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        Construir();
                    end;
                }
                field(FiltroEstanteria; FiltroEstanteria)
                {
                    Caption = 'Estantería';
                    ToolTip = 'Estantería que se quiere ver de frente, como un alzado: los huecos en horizontal y las alturas en vertical. En blanco muestra todas.';
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        Construir();
                    end;
                }
                field(Leyenda; Leyenda)
                {
                    Caption = 'Leyenda';
                    ToolTip = 'Significado de los colores de las celdas.';
                    ApplicationArea = All;
                    Editable = false;
                    MultiLine = true;
                }
                field(Aviso; Aviso)
                {
                    Caption = 'Aviso';
                    ToolTip = 'Avisos sobre el dibujo, por ejemplo si la estantería tiene más columnas de las que caben en la rejilla.';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Unfavorable;
                    Visible = HayAviso;
                }
            }
            repeater(Rejilla)
            {
                field("Cod. Estanteria"; Rec."Cod. Estanteria")
                {
                    ToolTip = 'Estantería que representa la fila.';
                    ApplicationArea = All;
                    Style = Strong;
                }
                field("Cod. Altura"; Rec."Cod. Altura")
                {
                    ToolTip = 'Altura que representa la fila. Las alturas se dibujan de arriba abajo.';
                    ApplicationArea = All;
                    Style = Strong;
                }
                field("Columna 01"; Rec."Columna 01")
                {
                    ToolTip = 'Hueco de la columna 01: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 01";
                    Visible = MostrarCol01;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 1);
                    end;
                }
                field("Columna 02"; Rec."Columna 02")
                {
                    ToolTip = 'Hueco de la columna 02: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 02";
                    Visible = MostrarCol02;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 2);
                    end;
                }
                field("Columna 03"; Rec."Columna 03")
                {
                    ToolTip = 'Hueco de la columna 03: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 03";
                    Visible = MostrarCol03;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 3);
                    end;
                }
                field("Columna 04"; Rec."Columna 04")
                {
                    ToolTip = 'Hueco de la columna 04: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 04";
                    Visible = MostrarCol04;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 4);
                    end;
                }
                field("Columna 05"; Rec."Columna 05")
                {
                    ToolTip = 'Hueco de la columna 05: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 05";
                    Visible = MostrarCol05;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 5);
                    end;
                }
                field("Columna 06"; Rec."Columna 06")
                {
                    ToolTip = 'Hueco de la columna 06: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 06";
                    Visible = MostrarCol06;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 6);
                    end;
                }
                field("Columna 07"; Rec."Columna 07")
                {
                    ToolTip = 'Hueco de la columna 07: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 07";
                    Visible = MostrarCol07;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 7);
                    end;
                }
                field("Columna 08"; Rec."Columna 08")
                {
                    ToolTip = 'Hueco de la columna 08: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 08";
                    Visible = MostrarCol08;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 8);
                    end;
                }
                field("Columna 09"; Rec."Columna 09")
                {
                    ToolTip = 'Hueco de la columna 09: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 09";
                    Visible = MostrarCol09;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 9);
                    end;
                }
                field("Columna 10"; Rec."Columna 10")
                {
                    ToolTip = 'Hueco de la columna 10: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 10";
                    Visible = MostrarCol10;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 10);
                    end;
                }
                field("Columna 11"; Rec."Columna 11")
                {
                    ToolTip = 'Hueco de la columna 11: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 11";
                    Visible = MostrarCol11;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 11);
                    end;
                }
                field("Columna 12"; Rec."Columna 12")
                {
                    ToolTip = 'Hueco de la columna 12: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 12";
                    Visible = MostrarCol12;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 12);
                    end;
                }
                field("Columna 13"; Rec."Columna 13")
                {
                    ToolTip = 'Hueco de la columna 13: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 13";
                    Visible = MostrarCol13;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 13);
                    end;
                }
                field("Columna 14"; Rec."Columna 14")
                {
                    ToolTip = 'Hueco de la columna 14: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 14";
                    Visible = MostrarCol14;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 14);
                    end;
                }
                field("Columna 15"; Rec."Columna 15")
                {
                    ToolTip = 'Hueco de la columna 15: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 15";
                    Visible = MostrarCol15;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 15);
                    end;
                }
                field("Columna 16"; Rec."Columna 16")
                {
                    ToolTip = 'Hueco de la columna 16: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 16";
                    Visible = MostrarCol16;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 16);
                    end;
                }
                field("Columna 17"; Rec."Columna 17")
                {
                    ToolTip = 'Hueco de la columna 17: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 17";
                    Visible = MostrarCol17;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 17);
                    end;
                }
                field("Columna 18"; Rec."Columna 18")
                {
                    ToolTip = 'Hueco de la columna 18: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 18";
                    Visible = MostrarCol18;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 18);
                    end;
                }
                field("Columna 19"; Rec."Columna 19")
                {
                    ToolTip = 'Hueco de la columna 19: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 19";
                    Visible = MostrarCol19;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 19);
                    end;
                }
                field("Columna 20"; Rec."Columna 20")
                {
                    ToolTip = 'Hueco de la columna 20: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 20";
                    Visible = MostrarCol20;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 20);
                    end;
                }
                field("Columna 21"; Rec."Columna 21")
                {
                    ToolTip = 'Hueco de la columna 21: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 21";
                    Visible = MostrarCol21;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 21);
                    end;
                }
                field("Columna 22"; Rec."Columna 22")
                {
                    ToolTip = 'Hueco de la columna 22: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 22";
                    Visible = MostrarCol22;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 22);
                    end;
                }
                field("Columna 23"; Rec."Columna 23")
                {
                    ToolTip = 'Hueco de la columna 23: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 23";
                    Visible = MostrarCol23;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 23);
                    end;
                }
                field("Columna 24"; Rec."Columna 24")
                {
                    ToolTip = 'Hueco de la columna 24: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 24";
                    Visible = MostrarCol24;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 24);
                    end;
                }
                field("Columna 25"; Rec."Columna 25")
                {
                    ToolTip = 'Hueco de la columna 25: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 25";
                    Visible = MostrarCol25;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 25);
                    end;
                }
                field("Columna 26"; Rec."Columna 26")
                {
                    ToolTip = 'Hueco de la columna 26: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 26";
                    Visible = MostrarCol26;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 26);
                    end;
                }
                field("Columna 27"; Rec."Columna 27")
                {
                    ToolTip = 'Hueco de la columna 27: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 27";
                    Visible = MostrarCol27;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 27);
                    end;
                }
                field("Columna 28"; Rec."Columna 28")
                {
                    ToolTip = 'Hueco de la columna 28: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 28";
                    Visible = MostrarCol28;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 28);
                    end;
                }
                field("Columna 29"; Rec."Columna 29")
                {
                    ToolTip = 'Hueco de la columna 29: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 29";
                    Visible = MostrarCol29;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 29);
                    end;
                }
                field("Columna 30"; Rec."Columna 30")
                {
                    ToolTip = 'Hueco de la columna 30: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 30";
                    Visible = MostrarCol30;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 30);
                    end;
                }
                field("Columna 31"; Rec."Columna 31")
                {
                    ToolTip = 'Hueco de la columna 31: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 31";
                    Visible = MostrarCol31;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 31);
                    end;
                }
                field("Columna 32"; Rec."Columna 32")
                {
                    ToolTip = 'Hueco de la columna 32: producto y cantidad que contiene.';
                    ApplicationArea = All;
                    StyleExpr = Rec."Estilo 32";
                    Visible = MostrarCol32;

                    trigger OnDrillDown()
                    begin
                        cMapa.AbrirContenidoCelda(Rec, 32);
                    end;
                }
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
                ToolTip = 'Vuelve a dibujar el mapa con el contenido actual de las ubicaciones.';
                ApplicationArea = All;
                Image = Refresh;

                trigger OnAction()
                begin
                    Construir();
                end;
            }
        }
        area(Navigation)
        {
            action(VerUbicaciones)
            {
                Caption = 'Ubicaciones SGA';
                ToolTip = 'Abre la lista de ubicaciones del almacén.';
                ApplicationArea = All;
                Image = BinContent;
                RunObject = page "Ubicaciones SGA";
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
        cMapa: Codeunit "Gestion Mapa SGA";
        FiltroAlmacen: Code[10];
        FiltroNave: Code[1];
        FiltroEstanteria: Code[2];
        Leyenda: Text;
        Aviso: Text;
        HayAviso: Boolean;
        ColumnasVisibles: Integer;
        MostrarCol01: Boolean;
        MostrarCol02: Boolean;
        MostrarCol03: Boolean;
        MostrarCol04: Boolean;
        MostrarCol05: Boolean;
        MostrarCol06: Boolean;
        MostrarCol07: Boolean;
        MostrarCol08: Boolean;
        MostrarCol09: Boolean;
        MostrarCol10: Boolean;
        MostrarCol11: Boolean;
        MostrarCol12: Boolean;
        MostrarCol13: Boolean;
        MostrarCol14: Boolean;
        MostrarCol15: Boolean;
        MostrarCol16: Boolean;
        MostrarCol17: Boolean;
        MostrarCol18: Boolean;
        MostrarCol19: Boolean;
        MostrarCol20: Boolean;
        MostrarCol21: Boolean;
        MostrarCol22: Boolean;
        MostrarCol23: Boolean;
        MostrarCol24: Boolean;
        MostrarCol25: Boolean;
        MostrarCol26: Boolean;
        MostrarCol27: Boolean;
        MostrarCol28: Boolean;
        MostrarCol29: Boolean;
        MostrarCol30: Boolean;
        MostrarCol31: Boolean;
        MostrarCol32: Boolean;

    trigger OnOpenPage()
    var
        rConfig: Record "Config. SGA";
        LeyendaLbl: Label 'Gris: vacía  |  Verde: con hueco  |  Naranja: llena  |  Rojo: bloqueada  |  "?": sin dar de alta en SGA';
    begin
        rConfig.ObtenerConfig();
        FiltroAlmacen := rConfig."Almacen por Defecto";
        Leyenda := LeyendaLbl;
        Construir();
    end;

    local procedure Construir()
    var
        rConfig: Record "Config. SGA";
        columnaMaxima: Integer;
        limiteRejilla: Integer;
        RejillaInsuficienteLbl: Label 'La nave tiene columnas hasta la %1 y la rejilla muestra %2. Suba "Columnas mapa" en la configuración de SGA o filtre por nave.', Comment = '%1 = última columna encontrada, %2 = columnas mostradas';
    begin
        rConfig.ObtenerConfig();
        limiteRejilla := rConfig."Columnas Mapa";
        if limiteRejilla <= 0 then
            limiteRejilla := cMapa.MaximoColumnasRejilla();

        columnaMaxima := cMapa.ConstruirMapa(Rec, FiltroAlmacen, FiltroNave);

        // El alzado se consigue filtrando la vista: el buffer ya está construido, así que
        // quedarse con una estantería es solo acotar las filas que se pintan.
        Rec.FilterGroup(2);
        if FiltroEstanteria <> '' then
            Rec.SetRange("Cod. Estanteria", FiltroEstanteria)
        else
            Rec.SetRange("Cod. Estanteria");
        Rec.FilterGroup(0);

        // El aviso se decide contra el límite configurado, antes de recortar por lo que hay.
        HayAviso := columnaMaxima > limiteRejilla;
        if HayAviso then
            Aviso := StrSubstNo(RejillaInsuficienteLbl, columnaMaxima, limiteRejilla)
        else
            Aviso := '';

        // Solo enseño las columnas que existen de verdad, para no dejar huecos en blanco.
        ColumnasVisibles := limiteRejilla;
        if columnaMaxima < ColumnasVisibles then
            ColumnasVisibles := columnaMaxima;

        FijarVisibilidad();

        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    local procedure FijarVisibilidad()
    begin
        MostrarCol01 := ColumnasVisibles >= 1;
        MostrarCol02 := ColumnasVisibles >= 2;
        MostrarCol03 := ColumnasVisibles >= 3;
        MostrarCol04 := ColumnasVisibles >= 4;
        MostrarCol05 := ColumnasVisibles >= 5;
        MostrarCol06 := ColumnasVisibles >= 6;
        MostrarCol07 := ColumnasVisibles >= 7;
        MostrarCol08 := ColumnasVisibles >= 8;
        MostrarCol09 := ColumnasVisibles >= 9;
        MostrarCol10 := ColumnasVisibles >= 10;
        MostrarCol11 := ColumnasVisibles >= 11;
        MostrarCol12 := ColumnasVisibles >= 12;
        MostrarCol13 := ColumnasVisibles >= 13;
        MostrarCol14 := ColumnasVisibles >= 14;
        MostrarCol15 := ColumnasVisibles >= 15;
        MostrarCol16 := ColumnasVisibles >= 16;
        MostrarCol17 := ColumnasVisibles >= 17;
        MostrarCol18 := ColumnasVisibles >= 18;
        MostrarCol19 := ColumnasVisibles >= 19;
        MostrarCol20 := ColumnasVisibles >= 20;
        MostrarCol21 := ColumnasVisibles >= 21;
        MostrarCol22 := ColumnasVisibles >= 22;
        MostrarCol23 := ColumnasVisibles >= 23;
        MostrarCol24 := ColumnasVisibles >= 24;
        MostrarCol25 := ColumnasVisibles >= 25;
        MostrarCol26 := ColumnasVisibles >= 26;
        MostrarCol27 := ColumnasVisibles >= 27;
        MostrarCol28 := ColumnasVisibles >= 28;
        MostrarCol29 := ColumnasVisibles >= 29;
        MostrarCol30 := ColumnasVisibles >= 30;
        MostrarCol31 := ColumnasVisibles >= 31;
        MostrarCol32 := ColumnasVisibles >= 32;
    end;
}
