namespace AntonioNadal.SGA;

using Microsoft.Inventory.Location;
using System.Utilities;

/// <summary>
/// Report Generar Ubicaciones SGA (ID 51100).
/// Alta masiva de ubicaciones: recorre los rangos de estantería, columna y altura de una
/// nave y crea lo que falte, tanto en la topología existente como en los datos SGA.
///
/// Es idempotente: lo que ya existe no se toca, así que se puede volver a ejecutar para
/// ampliar una nave.
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
                combinaciones: Integer;
                creadas: Integer;
                ConfirmarGenerarQst: Label 'Se van a revisar %1 ubicaciones de la nave %2 del almacén %3, y se crearán las que falten. ¿Desea continuar?', Comment = '%1 = nº de combinaciones, %2 = nave, %3 = almacén';
                ProcesoTerminadoMsg: Label 'Proceso terminado. Se han creado %1 ubicaciones nuevas.', Comment = '%1 = nº de ubicaciones creadas';
                AlmacenNaveObligatoriosErr: Label 'Debe indicar el almacén y la nave.';
            begin
                if (codAlmacen = '') or (codNave = '') then
                    Error(AlmacenNaveObligatoriosErr);

                combinaciones := (intEstanteriaHasta - intEstanteriaDesde + 1) *
                                 (intColumnaHasta - intColumnaDesde + 1) *
                                 (intAlturaHasta - intAlturaDesde + 1);

                if GuiAllowed() then
                    if not Confirm(ConfirmarGenerarQst, false, combinaciones, codNave, codAlmacen) then
                        exit;

                creadas := cUbicaciones.GenerarUbicaciones(codAlmacen, codNave, intEstanteriaDesde, intEstanteriaHasta,
                                                           intColumnaDesde, intColumnaHasta, intAlturaDesde, intAlturaHasta,
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
                    }
                    field(Nave; codNave)
                    {
                        Caption = 'Nave';
                        ToolTip = 'Código de nave, de un carácter.';
                        ApplicationArea = All;
                        ShowMandatory = true;
                    }
                }
                group(Rangos)
                {
                    Caption = 'Rangos';

                    field(EstanteriaDesde; intEstanteriaDesde)
                    {
                        Caption = 'Estantería desde';
                        ToolTip = 'Primera estantería que se crea. Entre 1 y 99.';
                        ApplicationArea = All;
                        MinValue = 1;
                        MaxValue = 99;
                    }
                    field(EstanteriaHasta; intEstanteriaHasta)
                    {
                        Caption = 'Estantería hasta';
                        ToolTip = 'Última estantería que se crea. Entre 1 y 99.';
                        ApplicationArea = All;
                        MinValue = 1;
                        MaxValue = 99;
                    }
                    field(ColumnaDesde; intColumnaDesde)
                    {
                        Caption = 'Columna desde';
                        ToolTip = 'Primera columna que se crea. Entre 1 y 99.';
                        ApplicationArea = All;
                        MinValue = 1;
                        MaxValue = 99;
                    }
                    field(ColumnaHasta; intColumnaHasta)
                    {
                        Caption = 'Columna hasta';
                        ToolTip = 'Última columna que se crea. Entre 1 y 99.';
                        ApplicationArea = All;
                        MinValue = 1;
                        MaxValue = 99;
                    }
                    field(AlturaDesde; intAlturaDesde)
                    {
                        Caption = 'Altura desde';
                        ToolTip = 'Primera altura que se crea. Entre 1 y 9, porque el código de altura es de un carácter.';
                        ApplicationArea = All;
                        MinValue = 1;
                        MaxValue = 9;
                    }
                    field(AlturaHasta; intAlturaHasta)
                    {
                        Caption = 'Altura hasta';
                        ToolTip = 'Última altura que se crea. Entre 1 y 9, porque el código de altura es de un carácter.';
                        ApplicationArea = All;
                        MinValue = 1;
                        MaxValue = 9;
                    }
                }
                group(Atributos)
                {
                    Caption = 'Atributos de las ubicaciones nuevas';

                    field(Zona; codZona)
                    {
                        Caption = 'Zona';
                        ToolTip = 'Zona que se asigna a las ubicaciones creadas.';
                        ApplicationArea = All;
                        TableRelation = "Zona SGA".Code;
                    }
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

            if intEstanteriaDesde = 0 then
                intEstanteriaDesde := 1;
            if intEstanteriaHasta = 0 then
                intEstanteriaHasta := 1;
            if intColumnaDesde = 0 then
                intColumnaDesde := 1;
            if intColumnaHasta = 0 then
                intColumnaHasta := 1;
            if intAlturaDesde = 0 then
                intAlturaDesde := 1;
            if intAlturaHasta = 0 then
                intAlturaHasta := 1;
        end;
    }

    var
        codAlmacen: Code[10];
        codNave: Code[1];
        intEstanteriaDesde: Integer;
        intEstanteriaHasta: Integer;
        intColumnaDesde: Integer;
        intColumnaHasta: Integer;
        intAlturaDesde: Integer;
        intAlturaHasta: Integer;
        codZona: Code[10];
        enumTipoUbicacion: Enum "Tipo Ubicacion SGA";
        decCapacidadUds: Decimal;
}
