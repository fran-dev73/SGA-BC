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
/// Se genera por almacén y zona: las ubicaciones nuevas nacen en la zona indicada, que
/// propone su tipo de ubicación. Sin zona, quedan sin zona.
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
                rZona: Record "Zona SGA";
                cUbicaciones: Codeunit "Gestion Ubicaciones SGA";
                combinaciones: Integer;
                creadas: Integer;
                alturas: List of [Integer];
                ConfirmarGenerarQst: Label 'Se van a revisar %1 ubicaciones del almacén %2 (alturas %3), y se crearán las que falten. ¿Desea continuar?', Comment = '%1 = nº de combinaciones, %2 = almacén, %3 = lista de alturas';
                ConfirmarGenerarZonaQst: Label 'Se van a revisar %1 ubicaciones del almacén %2 (alturas %3), y se crearán las que falten en la zona %4. Las que ya existen conservan su zona. ¿Desea continuar?', Comment = '%1 = nº de combinaciones, %2 = almacén, %3 = lista de alturas, %4 = zona';
                CreadasMsg: Label 'Proceso terminado. Se han creado %1 ubicaciones.', Comment = '%1 = nº creadas';
                CreadasYExistentesMsg: Label 'Proceso terminado. Se han creado %1 ubicaciones; otras %2 ya existían y no se han tocado.', Comment = '%1 = nº creadas, %2 = nº que ya existían';
                TodasExistianMsg: Label 'Proceso terminado. No se ha creado ninguna ubicación: las %1 ya existían.', Comment = '%1 = nº revisadas';
                AlmacenObligatorioErr: Label 'Debe indicar el almacén.';
                RangoErr: Label 'El %1 desde (%2) no puede ser mayor que el hasta (%3).', Comment = '%1 = pasillo, estantería o altura, %2 = desde, %3 = hasta';
                PasilloLbl: Label 'pasillo';
                EstanteriaLbl: Label 'estantería';
                AlturaLbl: Label 'altura';
            begin
                if codAlmacen = '' then
                    Error(AlmacenObligatorioErr);
                if intPasilloDesde > intPasilloHasta then
                    Error(RangoErr, PasilloLbl, intPasilloDesde, intPasilloHasta);
                if intEstanteriaDesde > intEstanteriaHasta then
                    Error(RangoErr, EstanteriaLbl, intEstanteriaDesde, intEstanteriaHasta);
                if intAlturaDesde > intAlturaHasta then
                    Error(RangoErr, AlturaLbl, intAlturaDesde, intAlturaHasta);
                // La zona se guarda entre ejecuciones: puede venir de otro almacén.
                if codZona <> '' then
                    rZona.Get(codAlmacen, codZona);

                alturas := cUbicaciones.AlturasDelRango(intAlturaDesde, intAlturaHasta);
                combinaciones := (intPasilloHasta - intPasilloDesde + 1) *
                                 (intEstanteriaHasta - intEstanteriaDesde + 1) * alturas.Count();

                if GuiAllowed() then
                    if codZona = '' then begin
                        if not Confirm(ConfirmarGenerarQst, false, combinaciones, codAlmacen, ListaAlturas(alturas)) then
                            exit;
                    end else
                        if not Confirm(ConfirmarGenerarZonaQst, false, combinaciones, codAlmacen, ListaAlturas(alturas), codZona) then
                            exit;

                creadas := cUbicaciones.GenerarUbicaciones(codAlmacen, intPasilloDesde, intPasilloHasta,
                                                           intEstanteriaDesde, intEstanteriaHasta, intAlturaDesde, intAlturaHasta,
                                                           codZona, enumTipoUbicacion, decCapacidadUds);

                if GuiAllowed() then
                    case true of
                        creadas = 0:
                            Message(TodasExistianMsg, combinaciones);
                        creadas = combinaciones:
                            Message(CreadasMsg, creadas);
                        else
                            Message(CreadasYExistentesMsg, creadas, combinaciones - creadas);
                    end;
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
                        ToolTip = 'Zona del almacén en la que nacen las ubicaciones creadas. Al elegirla se propone su tipo de ubicación, si lo tiene. Las ubicaciones que ya existen no cambian de zona. En blanco, se crean sin zona.';
                        ApplicationArea = All;

                        trigger OnLookup(var Text: Text): Boolean
                        var
                            rZona: Record "Zona SGA";
                        begin
                            rZona.SetRange("Cod. Almacen", codAlmacen);
                            if Page.RunModal(0, rZona) <> Action::LookupOK then
                                exit(false);
                            Text := rZona.Code;
                            exit(true);
                        end;

                        trigger OnValidate()
                        var
                            rZona: Record "Zona SGA";
                        begin
                            if codZona = '' then
                                exit;
                            rZona.Get(codAlmacen, codZona);
                            if rZona."Tipo Ubicacion" <> rZona."Tipo Ubicacion"::" " then
                                enumTipoUbicacion := rZona."Tipo Ubicacion";
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
            rConfig.ObtenerConfig();
            if codAlmacen = '' then
                codAlmacen := rConfig."Almacen por Defecto";

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
    /// Las alturas que se van a recorrer, a dos dígitos (00, 10, 20), para confirmarlas antes de
    /// generar: la página guarda los valores de la última vez y un desde antiguo no se ve.
    /// </summary>
    local procedure ListaAlturas(prm_Alturas: List of [Integer]) lista: Text
    var
        altura: Integer;
    begin
        foreach altura in prm_Alturas do begin
            if lista <> '' then
                lista += ', ';
            lista += DosDigitos(altura);
        end;
    end;

    /// <summary>
    /// Lee una altura tecleada (0, 5, 00, 10…) y la deja escrita a dos dígitos, como va en el
    /// código de la ubicación. En blanco cuenta como 00.
    /// </summary>
    local procedure LeerAltura(var prm_Texto: Text[2]; var prm_Altura: Integer)
    var
        AlturaErr: Label 'La altura debe ser un número de dos dígitos, de 00 a 99.';
    begin
        prm_Texto := CopyStr(DelChr(prm_Texto, '<>', ' '), 1, MaxStrLen(prm_Texto));
        if prm_Texto = '' then
            prm_Texto := '0';
        if DelChr(prm_Texto, '=', '0123456789') <> '' then
            Error(AlturaErr);
        Evaluate(prm_Altura, prm_Texto);
        prm_Texto := CopyStr(DosDigitos(prm_Altura), 1, MaxStrLen(prm_Texto));
    end;

    local procedure DosDigitos(prm_Valor: Integer): Text
    begin
        exit(PadStr('', 2 - StrLen(Format(prm_Valor)), '0') + Format(prm_Valor));
    end;
}
