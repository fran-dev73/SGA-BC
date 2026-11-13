namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;

/// <summary>
/// Codeunit Lectura Codigos SGA (ID 51114).
/// Interpreta lo que lee el escáner: si es una ubicación, un palé (SSCC) o un producto y, para
/// un producto, cuál es, con su variante y su lote si el código los trae.
///
/// Un producto se reconoce por, en este orden: referencia de tipo código de barras, GTIN de
/// la ficha y nº de producto. Una lectura GS1-128 aporta el SSCC de (00), el GTIN de (01) o
/// (02) y el lote de (10); un GTIN-14 que empieza por 0 se busca también como EAN-13.
///
/// También da los SSCC nuevos, con el mismo generador que el resto del sistema (Cod. "Gestion
/// Codigos Barras".generaSSCC).
/// </summary>
codeunit 51114 "Lectura Codigos SGA"
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
    /// Devuelve true si la lectura identifica un producto. prm_Variante y prm_Lote quedan en
    /// blanco si el código no los trae.
    /// </summary>
    procedure LeerProducto(prm_Lectura: Text; var prm_Producto: Code[20]; var prm_Variante: Code[10]; var prm_Lote: Code[50]): Boolean
    var
        codigo: Text;
        gtin: Text;
        sscc: Text;
    begin
        Clear(prm_Producto);
        Clear(prm_Variante);
        Clear(prm_Lote);

        codigo := Normalizar(prm_Lectura);
        if LeerGS1(codigo, gtin, prm_Lote, sscc) then
            codigo := gtin;

        if BuscarProducto(codigo, prm_Producto, prm_Variante) then
            exit(true);

        // GTIN-14 de la unidad: un 0 delante del EAN-13.
        if (StrLen(codigo) = 14) and (CopyStr(codigo, 1, 1) = '0') then
            exit(BuscarProducto(CopyStr(codigo, 2), prm_Producto, prm_Variante));

        exit(false);
    end;

    /// <summary>
    /// Devuelve true si la lectura trae un SSCC: el (00) de un GS1-128 o los 18 dígitos solos,
    /// con su dígito de control bien. El SSCC queda en prm_SSCC.
    /// </summary>
    procedure LeerSSCC(prm_Lectura: Text; var prm_SSCC: Code[20]): Boolean
    var
        codigo: Text;
        gtin: Text;
        lote: Code[50];
        sscc: Text;
    begin
        Clear(prm_SSCC);
        codigo := Normalizar(prm_Lectura);
        if (StrLen(codigo) = 18) and SoloDigitos(codigo) then
            sscc := codigo
        else
            if not LeerGS1(codigo, gtin, lote, sscc) then
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
    /// Un SSCC nuevo para un palé que no lo trae, del mismo generador que las etiquetas de palé
    /// del resto del sistema.
    /// </summary>
    procedure NuevoSSCC(): Code[20]
    var
        cduCodBarras: Codeunit "Gestion Codigos Barras";
    begin
        exit(cduCodBarras.generaSSCC());
    end;

    /// <summary>
    /// 18 dígitos con el dígito de control GS1 correcto: los 17 primeros por 3 y 1 alternos,
    /// empezando por 3, y el último completa la decena.
    /// </summary>
    local procedure SSCCValido(prm_SSCC: Text): Boolean
    var
        digito: Integer;
        suma: Integer;
        i: Integer;
    begin
        if (StrLen(prm_SSCC) <> 18) or not SoloDigitos(prm_SSCC) then
            exit(false);

        for i := 1 to 17 do begin
            Evaluate(digito, CopyStr(prm_SSCC, i, 1));
            if i mod 2 = 1 then
                suma += digito * 3
            else
                suma += digito;
        end;
        Evaluate(digito, CopyStr(prm_SSCC, 18, 1));
        exit((10 - suma mod 10) mod 10 = digito);
    end;

    local procedure SoloDigitos(prm_Texto: Text): Boolean
    begin
        exit((prm_Texto <> '') and (DelChr(prm_Texto, '=', '0123456789') = ''));
    end;

    local procedure BuscarProducto(prm_Codigo: Text; var prm_Producto: Code[20]; var prm_Variante: Code[10]): Boolean
    var
        rItemReference: Record "Item Reference";
        rItem: Record Item;
    begin
        if (prm_Codigo = '') or (StrLen(prm_Codigo) > MaxStrLen(rItemReference."Reference No.")) then
            exit(false);

        rItemReference.SetLoadFields("Item No.", "Variant Code");
        rItemReference.SetRange("Reference Type", rItemReference."Reference Type"::"Bar Code");
        rItemReference.SetRange("Reference No.", prm_Codigo);
        if rItemReference.FindFirst() then begin
            prm_Producto := rItemReference."Item No.";
            prm_Variante := rItemReference."Variant Code";
            exit(true);
        end;

        if StrLen(prm_Codigo) <= MaxStrLen(rItem.GTIN) then begin
            rItem.SetLoadFields("No.");
            rItem.SetRange(GTIN, prm_Codigo);
            if rItem.FindFirst() then begin
                prm_Producto := rItem."No.";
                exit(true);
            end;
        end;

        if StrLen(prm_Codigo) <= MaxStrLen(rItem."No.") then begin
            rItem.Reset();
            rItem.SetLoadFields("No.");
            if rItem.Get(CopyStr(prm_Codigo, 1, MaxStrLen(rItem."No."))) then begin
                prm_Producto := rItem."No.";
                exit(true);
            end;
        end;

        exit(false);
    end;

    /// <summary>
    /// Saca el SSCC de (00), el GTIN de (01) o (02) y el lote de (10) de una lectura GS1-128, tal
    /// como la manda el escáner (separador GS) o con los AI entre paréntesis. Devuelve false si
    /// no lo es. Se deja de leer en el primer AI que no se conoce: lo que interesa suele ir delante.
    /// </summary>
    local procedure LeerGS1(prm_Codigo: Text; var prm_Gtin: Text; var prm_Lote: Code[50]; var prm_SSCC: Text): Boolean
    var
        texto: Text;
        ai: Text;
        valor: Text;
        separador: Text[1];
        pos: Integer;
        largoAI: Integer;
        largoValor: Integer;
        finValor: Integer;
    begin
        Clear(prm_Gtin);
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
                valor := CopyStr(texto, pos, largoValor);
                pos += largoValor;

                case ai of
                    '00':
                        prm_SSCC := valor;
                    '01', '02':
                        prm_Gtin := valor;
                    '10':
                        prm_Lote := CopyStr(valor, 1, MaxStrLen(prm_Lote));
                end;
            end;

        exit((prm_Gtin <> '') or (prm_Lote <> '') or (prm_SSCC <> ''));
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
}
