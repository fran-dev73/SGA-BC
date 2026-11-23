namespace AntonioNadal.SGA;

using Microsoft.Inventory.Location;
using System.Utilities;

/// <summary>
/// Report Generar Ubicaciones SGA (ID 51100).
/// Alta masiva de ubicaciones: recorre los rangos de pasillo, estantería y altura de un
/// almacén y crea lo que falte, tanto en la topología existente como en los datos SGA. El
/// código sale como pasillo-estantería-altura con ceros a la izquierda (101-15-03). Pasillo y
/// estantería van de uno en uno; la altura, de 10 en 10 desde la inicial sin pasar de la
/// final (00, 10, 20…).
///
/// Se genera por almacén y zona: las ubicaciones nuevas nacen en la zona indicada y con el
/// tipo indicado. Sin zona, quedan sin zona.
///
/// Es idempotente: lo que ya existe no se toca, así que se puede volver a ejecutar para
/// ampliar el almacén.
/// </summary>
report 51100 "Generar Ubicaciones SGA"
{
    Caption = 'Generar ubicaciones SGA';
    ProcessingOnly = true;
    UsageCategory = Tasks;
    ApplicationArea = All;

    dataset
    {
        dataitem(Proceso; Integer)
        {
            DataItemTableView = sorting(Number) where(Number = const(1));

            trigger OnAfterGetRecord()
            var
                cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
            begin
                cUbicaciones.GenerarUbicaciones(codAlmacen, intPasilloDesde, intPasilloHasta, intEstanteriaDesde, intEstanteriaHasta,
                                                intAlturaDesde, intAlturaHasta, codZona, enumTipoUbicacion, decCapacidadUds);
            end;
        }
    }

    requestpage
    {
        SaveValues = true;

        layout
        {
            area(Content)
            {
                group(Ubicacion)
                {
                    Caption = 'Ubicación';

                    field(Almacen; codAlmacen)
                    {
                        Caption = 'Almacén';
                        ToolTip = 'Almacén en el que se crean las ubicaciones.';
                        ApplicationArea = All;
                        TableRelation = Location;
                        ShowMandatory = true;

                        trigger OnValidate()
                        begin
                            // Las zonas son de cada almacén.
                            codZona := '';
                        end;
                    }
                    field(Zona; codZona)
                    {
                        Caption = 'Zona';
                        ToolTip = 'Zona del almacén en la que nacen las ubicaciones creadas. Las ubicaciones que ya existen no cambian de zona. En blanco, se crean sin zona.';
                        ApplicationArea = All;

                        trigger OnLookup(var Text: Text): Boolean
                        var
                            rZona: Record "Zona SGA";
                        begin
                            exit(rZona.BuscarZona(codAlmacen, Text));
                        end;

                        trigger OnValidate()
                        var
                            rZona: Record "Zona SGA";
                        begin
                            if codZona <> '' then
                                rZona.Get(codAlmacen, codZona);
                        end;
                    }
                }
                group(Rangos)
                {
                    Caption = 'Rangos';

                    field(PasilloDesde; intPasilloDesde)
                    {
                        Caption = 'Pasillo desde';
                        ToolTip = 'Primer pasillo que se crea. Entre 1 y 999; en el código va con tres dígitos (001).';
                        ApplicationArea = All;
                        MinValue = 1;
                        MaxValue = 999;
                    }
                    field(PasilloHasta; intPasilloHasta)
                    {
                        Caption = 'Pasillo hasta';
                        ToolTip = 'Último pasillo que se crea. Entre 1 y 999; en el código va con tres dígitos (001).';
                        ApplicationArea = All;
                        MinValue = 1;
                        MaxValue = 999;
                    }
                    field(EstanteriaDesde; intEstanteriaDesde)
                    {
                        Caption = 'Estantería desde';
                        ToolTip = 'Primera estantería de cada pasillo que se crea. Entre 1 y 99; en el código va con dos dígitos (01).';
                        ApplicationArea = All;
                        MinValue = 1;
                        MaxValue = 99;
                    }
                    field(EstanteriaHasta; intEstanteriaHasta)
                    {
                        Caption = 'Estantería hasta';
                        ToolTip = 'Última estantería de cada pasillo que se crea. Entre 1 y 99; en el código va con dos dígitos (01).';
                        ApplicationArea = All;
                        MinValue = 1;
                        MaxValue = 99;
                    }
                    field(AlturaDesde; txtAlturaDesde)
                    {
                        Caption = 'Altura desde';
                        ToolTip = 'Primera altura de cada estantería que se crea, con dos dígitos como en el código: de 00 a 99.';
                        ApplicationArea = All;

                        trigger OnValidate()
                        begin
                            LeerAltura(txtAlturaDesde, intAlturaDesde);
                        end;
                    }
                    field(AlturaHasta; txtAlturaHasta)
                    {
                        Caption = 'Altura hasta';
                        ToolTip = 'Altura más alta de cada estantería, con dos dígitos como en el código: de 00 a 99. Se crean las alturas desde la inicial, de 10 en 10, sin pasar de esta: de 00 a 30, las 00, 10, 20 y 30.';
                        ApplicationArea = All;

                        trigger OnValidate()
                        begin
                            LeerAltura(txtAlturaHasta, intAlturaHasta);
                        end;
                    }
                }
                group(Atributos)
                {
                    Caption = 'Atributos de las ubicaciones nuevas';

                    field(TipoUbicacion; enumTipoUbicacion)
                    {
                        Caption = 'Tipo ubicación';
                        ToolTip = 'Almacenamiento o Picking para las ubicaciones creadas. En blanco no se proponen al ubicar.';
                        ApplicationArea = All;
                    }
                    field(CapacidadUds; decCapacidadUds)
                    {
                        Caption = 'Capacidad (palés)';
                        ToolTip = 'Cuántos palés caben en cada ubicación creada: 1 = un palé, lleve lo que lleve. 0 deja la capacidad sin declarar.';
                        ApplicationArea = All;
                        DecimalPlaces = 0 : 5;
                        MinValue = 0;
                    }
                }
            }
        }

        trigger OnOpenPage()
        var
            rConfig: Record "Config. SGA";
        begin
            codAlmacen := rConfig.AlmacenODefecto(codAlmacen);

            if intPasilloDesde = 0 then
                intPasilloDesde := 1;
            if intPasilloHasta = 0 then
                intPasilloHasta := 1;
            if intEstanteriaDesde = 0 then
                intEstanteriaDesde := 1;
            if intEstanteriaHasta = 0 then
                intEstanteriaHasta := 1;
            LeerAltura(txtAlturaDesde, intAlturaDesde);
            LeerAltura(txtAlturaHasta, intAlturaHasta);
        end;
    }

    var
        codAlmacen: Code[10];
        intPasilloDesde: Integer;
        intPasilloHasta: Integer;
        intEstanteriaDesde: Integer;
        intEstanteriaHasta: Integer;
        intAlturaDesde: Integer;
        intAlturaHasta: Integer;
        txtAlturaDesde: Text[2];
        txtAlturaHasta: Text[2];
        codZona: Code[10];
        enumTipoUbicacion: Enum "Tipo Ubicacion SGA";
        decCapacidadUds: Decimal;

    /// <summary>
    /// Lee una altura tecleada (0, 5, 00, 10…) y la deja escrita a dos dígitos, como va en el
    /// código de la ubicación. En blanco cuenta como 00.
    /// </summary>
    local procedure LeerAltura(var prm_Texto: Text[2]; var prm_Altura: Integer)
    var
        cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
        AlturaErr: Label 'La altura debe ser un número de dos dígitos, de 00 a 99.';
    begin
        prm_Texto := CopyStr(DelChr(prm_Texto, '<>', ' '), 1, MaxStrLen(prm_Texto));
        if prm_Texto = '' then
            prm_Texto := '0';
        if DelChr(prm_Texto, '=', '0123456789') <> '' then
            Error(AlturaErr);
        Evaluate(prm_Altura, prm_Texto);
        prm_Texto := CopyStr(cUbicaciones.ConCeros(prm_Altura, 2), 1, MaxStrLen(prm_Texto));
    end;
}
