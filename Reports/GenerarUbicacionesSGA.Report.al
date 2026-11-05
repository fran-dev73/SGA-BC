namespace AntonioNadal.SGA;

using Microsoft.Inventory.Location;
using System.Utilities;

/// <summary>
/// Report Generar Ubicaciones SGA (ID 51100).
/// Alta masiva de ubicaciones: recorre los rangos de pasillo, estantería y altura de un
/// almacén y crea lo que falte, tanto en la topología existente como en los datos SGA. El
/// código sale como pasillo-estantería-altura con ceros a la izquierda (101-15-03).
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
                ConfirmarGenerarQst: Label 'Se van a revisar %1 ubicaciones del almacén %2, y se crearán las que falten. ¿Desea continuar?', Comment = '%1 = nº de combinaciones, %2 = almacén';
                ConfirmarGenerarZonaQst: Label 'Se van a revisar %1 ubicaciones del almacén %2, y se crearán las que falten en la zona %3. Las que ya existen conservan su zona. ¿Desea continuar?', Comment = '%1 = nº de combinaciones, %2 = almacén, %3 = zona';
                ProcesoTerminadoMsg: Label 'Proceso terminado. Se han creado %1 ubicaciones nuevas.', Comment = '%1 = nº de ubicaciones creadas';
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

                combinaciones := (intPasilloHasta - intPasilloDesde + 1) *
                                 (intEstanteriaHasta - intEstanteriaDesde + 1) *
                                 (intAlturaHasta - intAlturaDesde + 1);

                if GuiAllowed() then
                    if codZona = '' then begin
                        if not Confirm(ConfirmarGenerarQst, false, combinaciones, codAlmacen) then
                            exit;
                    end else
                        if not Confirm(ConfirmarGenerarZonaQst, false, combinaciones, codAlmacen, codZona) then
                            exit;

                creadas := cUbicaciones.GenerarUbicaciones(codAlmacen, intPasilloDesde, intPasilloHasta,
                                                           intEstanteriaDesde, intEstanteriaHasta, intAlturaDesde, intAlturaHasta,
                                                           codZona, enumTipoUbicacion, decCapacidadUds);

                if GuiAllowed() then
                    Message(ProcesoTerminadoMsg, creadas);
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
                    field(AlturaDesde; intAlturaDesde)
                    {
                        Caption = 'Altura desde';
                        ToolTip = 'Primera altura de cada estantería que se crea. Entre 1 y 99; en el código va con dos dígitos (01).';
                        ApplicationArea = All;
                        MinValue = 1;
                        MaxValue = 99;
                    }
                    field(AlturaHasta; intAlturaHasta)
                    {
                        Caption = 'Altura hasta';
                        ToolTip = 'Última altura de cada estantería que se crea. Entre 1 y 99; en el código va con dos dígitos (01).';
                        ApplicationArea = All;
                        MinValue = 1;
                        MaxValue = 99;
                    }
                }
                group(Atributos)
                {
                    Caption = 'Atributos de las ubicaciones nuevas';

                    field(TipoUbicacion; enumTipoUbicacion)
                    {
                        Caption = 'Tipo ubicación';
                        ToolTip = 'Uso funcional que se asigna a las ubicaciones creadas.';
                        ApplicationArea = All;
                    }
                    field(CapacidadUds; decCapacidadUds)
                    {
                        Caption = 'Capacidad uds.';
                        ToolTip = 'Cuánto cabe en cada ubicación creada, contado en palés (o cajas, según el tipo de hueco al generar de la configuración): 1 = un palé, lleve lo que lleve. 0 deja la capacidad sin declarar.';
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
            if intAlturaDesde = 0 then
                intAlturaDesde := 1;
            if intAlturaHasta = 0 then
                intAlturaHasta := 1;
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
        codZona: Code[10];
        enumTipoUbicacion: Enum "Tipo Ubicacion SGA";
        decCapacidadUds: Decimal;
}
