namespace AntonioNadal.SGA;

using Microsoft.Foundation.NoSeries;
using Microsoft.Inventory.Setup;

/// <summary>
/// Codeunit Codigos Barras SGA (ID 51114).
/// Todo lo de códigos de barras de SGA, sin depender del resto del proyecto:
/// - Interpreta lo que lee el escáner: si es una ubicación (EsUbicacion) o un palé (LeerSSCC:
///   SSCC, solo o en el (00) de una lectura GS1-128).
/// - Da los SSCC nuevos (NuevoSSCC) con las series de SSCC de la configuración de inventario.
/// </summary>
codeunit 51114 "Codigos Barras SGA"
{
    /// <summary>
    /// Devuelve true si la lectura es el código de una ubicación SGA del almacén, y su código
    /// en prm_Bin.
    /// </summary>
    procedure EsUbicacion(prm_Almacen: Code[10]; prm_Lectura: Text; var prm_Bin: Code[20]): Boolean
    var
        rUbicacion: Record "Ubicacion SGA";
        lectura: Text;
    begin
        Clear(prm_Bin);
        lectura := Normalizar(prm_Lectura);
        if (lectura = '') or (StrLen(lectura) > MaxStrLen(prm_Bin)) then
            exit(false);

        rUbicacion.SetRange("Cod. Almacen", prm_Almacen);
        rUbicacion.SetRange("Cod. Bin", CopyStr(lectura, 1, MaxStrLen(prm_Bin)));
        if rUbicacion.IsEmpty() then
            exit(false);

        prm_Bin := CopyStr(lectura, 1, MaxStrLen(prm_Bin));
        exit(true);
    end;

    /// <summary>
    /// La ubicación de una lectura o de lo tecleado, para guardarla en un campo: sin los
    /// espacios ni el identificador de simbología que pone el escáner.
    /// </summary>
    procedure UbicacionLeida(prm_Lectura: Text): Code[20]
    begin
        exit(CopyStr(Normalizar(prm_Lectura), 1, 20));
    end;

    /// <summary>
    /// Devuelve true si la lectura trae un SSCC: el (00) de un GS1-128 o los 18 dígitos solos,
    /// con su dígito de control bien. El SSCC queda en prm_SSCC.
    /// </summary>
    procedure LeerSSCC(prm_Lectura: Text; var prm_SSCC: Code[20]): Boolean
    var
        codigo: Text;
        sscc: Text;
    begin
        Clear(prm_SSCC);
        codigo := Normalizar(prm_Lectura);
        if (StrLen(codigo) = 18) and SoloDigitos(codigo) then
            sscc := codigo
        else
            if not LeerGS1(codigo, sscc) then
                exit(false);

        if not SSCCValido(sscc) then
            exit(false);
        prm_SSCC := CopyStr(sscc, 1, MaxStrLen(prm_SSCC));
        exit(true);
    end;

    /// <summary>
    /// El SSCC de una lectura o de lo tecleado, para guardarlo en un campo. En blanco si la lectura
    /// va en blanco; error si no es un SSCC válido.
    /// </summary>
    procedure SSCCLeido(prm_Lectura: Text): Code[20]
    var
        sscc: Code[20];
        SSCCNoValidoErr: Label '%1 no es un SSCC válido: tienen que ser los 18 dígitos del palé, o la lectura de su etiqueta.', Comment = '%1 = lo leído';
    begin
        if Normalizar(prm_Lectura) = '' then
            exit('');
        if not LeerSSCC(prm_Lectura, sscc) then
            Error(SSCCNoValidoErr, prm_Lectura);
        exit(sscc);
    end;

    /// <summary>
    /// Un SSCC nuevo para un palé que no lo trae. Son 18 dígitos: el dígito de extensión (último
    /// nº usado de "Nº serie ind. extensión IA00"), el prefijo de empresa GS1, el siguiente
    /// número de "Nº serie EAN-128 - IA00" (9 dígitos) y el dígito de control. Las dos series
    /// son las de la configuración de inventario que usan las etiquetas de palé del resto del
    /// sistema: comparten contador con ellas y no se repite ningún SSCC.
    /// </summary>
    procedure NuevoSSCC(): Code[20]
    var
        cSerie: Codeunit "No. Series";
        base: Text;
        PrefijoEmpresaGS1Tok: Label '8414037', Locked = true;
        SSCCMalFormadoErr: Label 'Las series de SSCC de la configuración de inventario (%1 y %2) dan %3, que no son los 17 dígitos de un SSCC sin el de control: la extensión tiene que ser un dígito y el número, de 9.', Comment = '%1 = serie de extensión, %2 = serie de número, %3 = lo que dan';
    begin
        // Las series se leen una vez por instancia: quien numera muchos palés usa una.
        if not InvtSetupLeida then begin
            InvtSetup.SetLoadFields("No. Serie EAN-128 - IA00", "No. Serie Ind. Extension IA00");
            InvtSetup.Get();
            InvtSetup.TestField("No. Serie EAN-128 - IA00");
            InvtSetup.TestField("No. Serie Ind. Extension IA00");
            InvtSetupLeida := true;
        end;

        base := cSerie.GetLastNoUsed(InvtSetup."No. Serie Ind. Extension IA00") + PrefijoEmpresaGS1Tok + cSerie.GetNextNo(InvtSetup."No. Serie EAN-128 - IA00");
        if (StrLen(base) <> 17) or not SoloDigitos(base) then
            Error(SSCCMalFormadoErr, InvtSetup."No. Serie Ind. Extension IA00", InvtSetup."No. Serie EAN-128 - IA00", base);
        exit(CopyStr(base + Format(DigitoControl(base)), 1, 20));
    end;

    /// <summary>
    /// 18 dígitos con el dígito de control GS1 correcto (DigitoControl de los 17 primeros).
    /// </summary>
    local procedure SSCCValido(prm_SSCC: Text): Boolean
    var
        digito: Integer;
    begin
        if (StrLen(prm_SSCC) <> 18) or not SoloDigitos(prm_SSCC) then
            exit(false);

        Evaluate(digito, CopyStr(prm_SSCC, 18, 1));
        exit(DigitoControl(CopyStr(prm_SSCC, 1, 17)) = digito);
    end;

    /// <summary>
    /// Dígito de control GS1 de los 17 primeros dígitos de un SSCC: por 3 y 1 alternos,
    /// empezando por 3, y el dígito completa la decena (StrCheckSum de la plataforma).
    /// </summary>
    local procedure DigitoControl(prm_Digitos: Text): Integer
    begin
        // Pesos GS1 de los 17 dígitos: 3 y 1 alternos.
        exit(StrCheckSum(prm_Digitos, '31313131313131313'));
    end;

    local procedure SoloDigitos(prm_Texto: Text): Boolean
    begin
        exit((prm_Texto <> '') and (DelChr(prm_Texto, '=', '0123456789') = ''));
    end;

    /// <summary>
    /// Saca el SSCC (00) de una lectura GS1-128, tal como la manda el escáner (separador GS) o
    /// con los AI entre paréntesis. Los demás AI conocidos se saltan por su longitud. Devuelve
    /// false si no trae SSCC. Se deja de leer en el primer AI que no se conoce: lo que interesa
    /// suele ir delante.
    /// </summary>
    local procedure LeerGS1(prm_Codigo: Text; var prm_SSCC: Text): Boolean
    var
        texto: Text;
        ai: Text;
        separador: Text[1];
        pos: Integer;
        largoAI: Integer;
        largoValor: Integer;
        finValor: Integer;
    begin
        Clear(prm_SSCC);
        separador[1] := 29;
        texto := prm_Codigo;
        if CopyStr(texto, 1, 1) = '(' then
            texto := DelChr(texto.Replace('(', separador), '=', ')')
        else
            // Sin paréntesis ni separador solo se toma por GS1 lo que no puede ser un EAN/GTIN.
            if (StrPos(texto, separador) = 0) and ((StrLen(texto) <= 14) or not (CopyStr(texto, 1, 2) in ['00', '01', '02'])) then
                exit(false);

        pos := 1;
        while pos <= StrLen(texto) do
            if CopyStr(texto, pos, 1) = separador then
                pos += 1
            else begin
                ai := CopyStr(texto, pos, 2);
                largoAI := 2;
                case ai of
                    '00':
                        largoValor := 18;
                    '01', '02':
                        largoValor := 14;
                    '11', '12', '13', '15', '16', '17':
                        largoValor := 6;
                    '20':
                        largoValor := 2;
                    '10', '21', '22', '30', '37':
                        largoValor := 0;
                    '31', '32', '33', '34', '35', '36':
                        begin
                            largoAI := 4;
                            largoValor := 6;
                        end;
                    else
                        break;
                end;

                pos += largoAI;
                if largoValor = 0 then begin
                    finValor := StrPos(CopyStr(texto, pos), separador);
                    if finValor = 0 then
                        largoValor := StrLen(texto) - pos + 1
                    else
                        largoValor := finValor - 1;
                end;
                if ai = '00' then
                    prm_SSCC := CopyStr(texto, pos, largoValor);
                pos += largoValor;
            end;

        exit(prm_SSCC <> '');
    end;

    /// <summary>
    /// Quita espacios, saltos de línea y el identificador de simbología (]C1, ]d2...) que
    /// algunos escáneres ponen delante.
    /// </summary>
    local procedure Normalizar(prm_Lectura: Text): Text
    var
        lectura: Text;
        saltos: Text[2];
    begin
        saltos[1] := 13;
        saltos[2] := 10;
        lectura := DelChr(prm_Lectura, '<>', ' ' + saltos);
        if CopyStr(lectura, 1, 1) = ']' then
            lectura := CopyStr(lectura, 4);
        exit(lectura);
    end;

    var
        // Las series de SSCC, leídas en NuevoSSCC una vez por instancia.
        InvtSetup: Record "Inventory Setup";
        InvtSetupLeida: Boolean;
}
