namespace AntonioNadal.SGA;

using Microsoft.Inventory.Location;

/// <summary>
/// Table Zona SGA (ID 51100).
/// Agrupación lógica de ubicaciones dentro de un almacén (cámara, almacenamiento, picking...).
/// La zona fija las prioridades por defecto que heredan sus ubicaciones.
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
        field(50; "Tipo Ubicacion"; Enum "Tipo Ubicacion SGA")
        {
            Caption = 'Tipo ubicación';
            DataClassification = ToBeClassified;
            ToolTip = 'Tipo que se propone por defecto a las ubicaciones que se creen en esta zona.';
        }
        field(55; "Grupo IIEE"; Code[20])
        {
            Caption = 'Grupo IIEE';
            DataClassification = ToBeClassified;
            ToolTip = 'Grupo IIEE de los productos que se guardan en esta zona. Al ubicar un producto de ese grupo se buscan primero huecos en sus zonas y, si no queda sitio, en el resto del almacén. La zona sigue admitiendo cualquier producto. Un grupo puede tener varias zonas. Requiere "Campo del grupo IIEE en el producto" en la configuración SGA.';
        }
        field(70; "Prioridad Picking"; Integer)
        {
            Caption = 'Prioridad picking';
            DataClassification = ToBeClassified;
            ToolTip = 'Secuencia de picking que toma una ubicación al asignarle esta zona, si aún no tiene la suya. Menor valor, antes en el recorrido.';
        }
        field(90; Bloqueada; Boolean)
        {
            Caption = 'Bloqueada';
            DataClassification = ToBeClassified;
            ToolTip = 'Impide proponer las ubicaciones de esta zona para ubicar o recoger.';
        }
        field(95; Playa; Boolean)
        {
            Caption = 'Playa';
            DataClassification = ToBeClassified;
            ToolTip = 'Zona de playas: cada ubicación es una playa donde se dejan los pedidos preparados. Sus ubicaciones van sin tipo, así que nunca se proponen para ubicar ni reponer.';

            trigger OnValidate()
            begin
                if Playa then
                    TestField("Tipo Ubicacion", "Tipo Ubicacion"::" ")
                else
                    "Ubicacion por Defecto" := '';
            end;
        }
        field(96; "Ubicacion por Defecto"; Code[20])
        {
            Caption = 'Ubicación por defecto';
            DataClassification = ToBeClassified;
            TableRelation = "Ubicacion SGA"."Cod. Bin" where("Cod. Almacen" = field("Cod. Almacen"),
                                                             "Cod. Zona SGA" = field(Code));
            ToolTip = 'Playa en la que el preparador deja lo que recoge en el picking de venta. Se le indica en cada parada y al terminar la orden.';

            trigger OnValidate()
            begin
                if "Ubicacion por Defecto" <> '' then
                    TestField(Playa, true);
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
        fieldgroup(DropDown; Code, Descripcion, "Tipo Ubicacion")
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
    /// Playa en la que se deja lo preparado en el almacén: la ubicación por defecto de su zona
    /// de playas. En blanco si no tiene.
    /// </summary>
    procedure PlayaPorDefecto(prm_Almacen: Code[10]): Code[20]
    var
        rZona: Record "Zona SGA";
    begin
        rZona.SetRange("Cod. Almacen", prm_Almacen);
        rZona.SetRange(Playa, true);
        rZona.SetFilter("Ubicacion por Defecto", '<>%1', '');
        rZona.SetLoadFields("Ubicacion por Defecto");
        if rZona.FindFirst() then
            exit(rZona."Ubicacion por Defecto");
        exit('');
    end;
}
