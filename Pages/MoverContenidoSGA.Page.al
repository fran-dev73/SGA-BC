namespace AntonioNadal.SGA;

using Microsoft.Warehouse.Structure;

/// <summary>
/// Page Mover Contenido SGA (ID 51114).
/// Diálogo de traslado: pregunta a dónde y cuánto se mueve, partiendo de una línea de
/// contenido concreta. No registra nada; el traslado lo hace Cod. "Gestion Contenido SGA".
///
/// Con una zona destino, propone hueco en esa zona (ProponerEnZona) y solo admite
/// ubicaciones suyas; el operario puede cambiar la propuesta por otra de la zona. Así se
/// traslada de una zona a otra.
/// </summary>
page 51114 "Mover Contenido SGA"
{
    Caption = 'Trasladar contenido SGA';
    PageType = StandardDialog;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Origen)
            {
                Caption = 'Origen';

                field(Almacen; Almacen)
                {
                    Caption = 'Almacén';
                    ToolTip = 'Almacén en el que se hace el traslado.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(UbicacionOrigen; UbicacionOrigen)
                {
                    Caption = 'Ubicación origen';
                    ToolTip = 'Ubicación de la que se saca la mercancía.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(ZonaOrigen; ZonaOrigen)
                {
                    Caption = 'Zona origen';
                    ToolTip = 'Zona de la ubicación de origen.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Producto; Producto)
                {
                    Caption = 'Producto';
                    ToolTip = 'Producto que se traslada.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Lote; Lote)
                {
                    Caption = 'Lote';
                    ToolTip = 'Lote que se traslada.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(SSCC; SSCC)
                {
                    Caption = 'SSCC';
                    ToolTip = 'Palé que se traslada. Lo que se lleva sigue siendo de este palé también en el destino.';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(CantidadDisponible; CantidadDisponible)
                {
                    Caption = 'Cantidad disponible';
                    ToolTip = 'Cantidad libre en la ubicación de origen.';
                    ApplicationArea = All;
                    Editable = false;
                }
            }
            group(Destino)
            {
                Caption = 'Destino';

                field(ZonaDestino; ZonaDestino)
                {
                    Caption = 'Zona destino';
                    ToolTip = 'Zona a la que se lleva la mercancía. Al elegirla se propone un hueco de esa zona con las reglas de ubicar (clase, capacidad, mezcla); se puede cambiar por otra ubicación de la misma zona. En blanco, cualquier ubicación del almacén.';
                    ApplicationArea = All;
                    Editable = ZonaEditable;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        rZona: Record "Zona SGA";
                    begin
                        rZona.SetRange("Cod. Almacen", Almacen);
                        if Page.RunModal(0, rZona) <> Action::LookupOK then
                            exit(false);
                        Text := rZona.Code;
                        exit(true);
                    end;

                    trigger OnValidate()
                    var
                        rZona: Record "Zona SGA";
                    begin
                        if ZonaDestino <> '' then
                            rZona.Get(Almacen, ZonaDestino);
                        Proponer();
                    end;
                }
                field(UbicacionDestino; UbicacionDestino)
                {
                    Caption = 'Ubicación destino';
                    ToolTip = 'Ubicación a la que se lleva la mercancía. Con zona destino, tiene que ser de esa zona.';
                    ApplicationArea = All;
                    ShowMandatory = true;
                    TableRelation = Bin.Code;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        rUbicacionSGA: Record "Ubicacion SGA";
                    begin
                        rUbicacionSGA.SetRange("Cod. Almacen", Almacen);
                        if ZonaDestino <> '' then
                            rUbicacionSGA.SetRange("Cod. Zona SGA", ZonaDestino);
                        if Page.RunModal(0, rUbicacionSGA) <> Action::LookupOK then
                            exit(false);
                        Text := rUbicacionSGA."Cod. Bin";
                        exit(true);
                    end;

                    trigger OnValidate()
                    var
                        MismaUbicacionErr: Label 'La ubicación de destino no puede ser la misma que la de origen.';
                    begin
                        if UbicacionDestino = UbicacionOrigen then
                            Error(MismaUbicacionErr);
                        ComprobarZona();
                        // Elegida a mano: ya no se cambia sola al tocar la cantidad.
                        DestinoPropuesto := false;
                        MotivoPropuesta := '';
                    end;
                }
                field(MotivoPropuesta; MotivoPropuesta)
                {
                    Caption = 'Propuesta';
                    ToolTip = 'Por qué se propone esa ubicación o, si no hay ninguna en la zona, por qué.';
                    ApplicationArea = All;
                    Editable = false;
                    MultiLine = true;
                }
                field(Cantidad; Cantidad)
                {
                    Caption = 'Cantidad';
                    ToolTip = 'Cantidad, en unidades base, que se traslada.';
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 5;
                    MinValue = 0;
                    ShowMandatory = true;

                    trigger OnValidate()
                    var
                        CantidadExcesivaErr: Label 'No puede trasladar más de %1 unidades.', Comment = '%1 = cantidad disponible';
                    begin
                        if Cantidad > CantidadDisponible then
                            Error(CantidadExcesivaErr, CantidadDisponible);
                        // El sitio depende de cuánto se lleva: la propuesta se rehace.
                        if DestinoPropuesto then
                            Proponer();
                    end;
                }
                field(Motivo; Motivo)
                {
                    Caption = 'Motivo';
                    ToolTip = 'Nota que queda registrada en el movimiento.';
                    ApplicationArea = All;
                }
            }
        }
    }

    var
        Almacen: Code[10];
        UbicacionOrigen: Code[20];
        UbicacionDestino: Code[20];
        Producto: Code[20];
        Lote: Code[50];
        SSCC: Code[20];
        CantidadDisponible: Decimal;
        Cantidad: Decimal;
        Motivo: Text[100];
        Variante: Code[10];
        UM: Code[10];
        ZonaOrigen: Code[10];
        ZonaDestino: Code[10];
        MotivoPropuesta: Text;
        DestinoPropuesto: Boolean;
        SoloMismaZona: Boolean;
        ZonaEditable: Boolean;

    trigger OnOpenPage()
    begin
        ZonaEditable := not SoloMismaZona;
    end;

    /// <summary>
    /// El destino tiene que ser de la misma zona que el origen. Lo pide el mapa 3D, que no
    /// traslada entre zonas: la zona destino es la del origen y no se puede cambiar. Va
    /// después de Inicializar, que lee la zona del origen.
    /// </summary>
    procedure LimitarAMismaZona()
    begin
        SoloMismaZona := true;
        ZonaDestino := ZonaOrigen;
    end;

    local procedure ComprobarZona()
    var
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
    begin
        if UbicacionDestino = '' then
            exit;
        if SoloMismaZona then
            cUbicaciones.TestMismaZona(Almacen, UbicacionOrigen, UbicacionDestino);
        cUbicaciones.TestUbicacionEnZona(Almacen, UbicacionDestino, ZonaDestino);
    end;

    /// <summary>
    /// Hueco en la zona destino para la cantidad que se lleva. Sin zona no se propone nada: el
    /// operario elige la ubicación como siempre.
    /// </summary>
    local procedure Proponer()
    var
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
    begin
        UbicacionDestino := '';
        MotivoPropuesta := '';
        DestinoPropuesto := false;
        if ZonaDestino = '' then
            exit;

        UbicacionDestino := cUbicaciones.ProponerEnZona(Almacen, ZonaDestino, UbicacionOrigen, Producto, Variante, Lote,
                                                        UM, Cantidad, MotivoPropuesta);
        DestinoPropuesto := UbicacionDestino <> '';
    end;

    /// <summary>
    /// Carga el diálogo desde una línea de contenido y propone trasladarlo entero.
    /// </summary>
    procedure Inicializar(var rContenido: Record "Contenido Ubicacion SGA")
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        Almacen := rContenido."Cod. Almacen";
        UbicacionOrigen := rContenido."Cod. Bin";
        Producto := rContenido."No. Producto";
        Variante := rContenido."Cod. Variante";
        Lote := rContenido."No. Lote";
        SSCC := rContenido.SSCC;
        UM := rContenido."Cod. Unidad Medida";
        CantidadDisponible := rContenido."Cantidad Disponible";
        Cantidad := rContenido."Cantidad Disponible";

        rUbicacionSGA.SetLoadFields("Cod. Zona SGA");
        if rUbicacionSGA.Get(Almacen, UbicacionOrigen) then
            ZonaOrigen := rUbicacionSGA."Cod. Zona SGA";
    end;

    /// <summary>
    /// Deja propuesto el destino. Lo usa el mapa 3D, donde el destino ya se ha elegido
    /// arrastrando; el operario solo confirma la cantidad.
    /// </summary>
    procedure FijarDestino(prm_Destino: Code[20])
    begin
        UbicacionDestino := prm_Destino;
    end;

    /// <summary>
    /// El destino elegido, comprobada la zona. Que no esté en blanco ni sea el origen, y que la
    /// cantidad sea positiva, lo comprueba RegistrarTraslado al registrar.
    /// </summary>
    procedure ObtenerDestino(): Code[20]
    begin
        ComprobarZona();
        exit(UbicacionDestino);
    end;

    procedure ObtenerCantidad(): Decimal
    begin
        exit(Cantidad);
    end;

    procedure ObtenerMotivo(): Text[100]
    begin
        exit(Motivo);
    end;
}
