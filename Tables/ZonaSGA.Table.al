namespace AntonioNadal.SGA;

using Microsoft.Inventory.Location;

/// <summary>
/// Table Zona SGA (ID 51100).
/// Agrupación lógica de ubicaciones dentro de un almacén (cámara, almacenamiento, picking...).
/// Una zona se bloquea entera o es una playa (sin ubicaciones), y acota los traslados
/// arrastrando en el mapa.
/// </summary>
table 51100 "Zona SGA"
{
    Caption = 'Zona SGA';
    DataClassification = ToBeClassified;
    LookupPageId = "Zonas SGA";
    DrillDownPageId = "Zonas SGA";

    fields
    {
        field(10; "Cod. Almacen"; Code[10])
        {
            Caption = 'Cód. almacén';
            DataClassification = ToBeClassified;
            TableRelation = Location;
            NotBlank = true;
        }
        field(20; Code; Code[10])
        {
            Caption = 'Código';
            DataClassification = ToBeClassified;
            NotBlank = true;
        }
        field(30; Descripcion; Text[50])
        {
            Caption = 'Descripción';
            DataClassification = ToBeClassified;
        }
        field(90; Bloqueada; Boolean)
        {
            Caption = 'Bloqueada';
            DataClassification = ToBeClassified;
            ToolTip = 'Bloquea todas las ubicaciones de la zona: no se proponen ni admiten movimientos y salen como bloqueadas.';

            trigger OnValidate()
            var
                cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
            begin
                // El estado de cada ubicación lee de la base de datos si su zona está bloqueada
                // (EsUtilizable): se guarda la zona antes. Una zona aún sin insertar no tiene
                // ubicaciones.
                if Modify() then
                    cUbicaciones.RecalcularEstados("Cod. Almacen", Code);
            end;
        }
        field(95; Playa; Boolean)
        {
            Caption = 'Playa';
            DataClassification = ToBeClassified;
            ToolTip = 'La zona es una playa: donde se dejan los pedidos preparados. No lleva ubicaciones. Las órdenes de picking de venta nacen con la playa por defecto de la configuración y se cambian con Cambiar playa.';

            trigger OnValidate()
            var
                rUbicacionSGA: Record "Ubicacion SGA";
                PlayaConUbicacionesErr: Label 'La zona %1 tiene ubicaciones: una playa no lleva ubicaciones. Páselas a otra zona antes de marcarla como playa.', Comment = '%1 = zona';
            begin
                if not Playa then
                    exit;
                rUbicacionSGA.SetRange("Cod. Almacen", "Cod. Almacen");
                rUbicacionSGA.SetRange("Cod. Zona SGA", Code);
                if not rUbicacionSGA.IsEmpty() then
                    Error(PlayaConUbicacionesErr, Code);
            end;
        }
        field(100; "No. Ubicaciones"; Integer)
        {
            Caption = 'Nº ubicaciones';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = count("Ubicacion SGA" where("Cod. Almacen" = field("Cod. Almacen"),
                                                      "Cod. Zona SGA" = field(Code)));
        }
    }

    keys
    {
        key(PK; "Cod. Almacen", Code)
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Code, Descripcion)
        {
        }
    }

    trigger OnDelete()
    var
        rUbicacionSGA: Record "Ubicacion SGA";
        ZonaConUbicacionesErr: Label 'No se puede eliminar la zona %1 porque tiene ubicaciones asignadas.', Comment = '%1 = zona';
    begin
        rUbicacionSGA.SetRange("Cod. Almacen", "Cod. Almacen");
        rUbicacionSGA.SetRange("Cod. Zona SGA", Code);
        if not rUbicacionSGA.IsEmpty() then
            Error(ZonaConUbicacionesErr, Code);
    end;

    /// <summary>
    /// Para quien mete ubicaciones en una zona: error si la zona es una playa, que no lleva
    /// ubicaciones. Sin zona o con una zona que no existe no hace nada.
    /// </summary>
    procedure ComprobarAdmiteUbicaciones(prm_Almacen: Code[10]; prm_Zona: Code[10])
    var
        rZona: Record "Zona SGA";
        PlayaSinUbicacionesErr: Label 'La zona %1 es una playa y no lleva ubicaciones.', Comment = '%1 = zona';
    begin
        if prm_Zona = '' then
            exit;
        rZona.SetLoadFields(Playa);
        if rZona.Get(prm_Almacen, prm_Zona) then
            if rZona.Playa then
                Error(PlayaSinUbicacionesErr, prm_Zona);
    end;

    /// <summary>
    /// Lista de las zonas de un almacén para el OnLookup de un campo de zona que no es de
    /// tabla. Deja en prm_Text la elegida; false si se cancela.
    /// </summary>
    procedure BuscarZona(prm_Almacen: Code[10]; var prm_Text: Text): Boolean
    var
        rZona: Record "Zona SGA";
    begin
        rZona.SetRange("Cod. Almacen", prm_Almacen);
        if Page.RunModal(0, rZona) <> Action::LookupOK then
            exit(false);
        prm_Text := rZona.Code;
        exit(true);
    end;
}
