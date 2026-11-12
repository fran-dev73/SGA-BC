namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;

/// <summary>
/// Codeunit Lectura Codigos SGA (ID 51114).
/// Interpreta lo que lee el escáner: si es una ubicación o un producto y, para un producto,
/// cuál es, con su variante y su lote si el código los trae.
///
/// Un producto se reconoce por, en este orden: referencia de tipo código de barras, GTIN de
/// la ficha y nº de producto. Una lectura GS1-128 aporta el GTIN de (01) o (02) y el lote de
/// (10); un GTIN-14 que empieza por 0 se busca también como EAN-13. Lo que SGA no conoce
/// (campos propios de la ficha) lo puede resolver otra extensión con OnBuscarProducto.
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
    begin
        Clear(prm_Producto);
        Clear(prm_Variante);
        Clear(prm_Lote);

        codigo := Normalizar(prm_Lectura);
        if LeerGS1(codigo, gtin, prm_Lote) then
            codigo := gtin;

        if BuscarProducto(codigo, prm_Producto, prm_Variante) then
            exit(true);

        // GTIN-14 de la unidad: un 0 delante del EAN-13.
        if (StrLen(codigo) = 14) and (CopyStr(codigo, 1, 1) = '0') then
            exit(BuscarProducto(CopyStr(codigo, 2), prm_Producto, prm_Variante));

        exit(false);
    end;

    local procedure BuscarProducto(prm_Codigo: Text; var prm_Producto: Code[20]; var prm_Variante: Code[10]): Boolean
    var
        rItemReference: Record "Item Reference";
        rItem: Record Item;
        encontrado: Boolean;
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

        OnBuscarProducto(prm_Codigo, prm_Producto, prm_Variante, encontrado);
        exit(encontrado);
    end;

    /// <summary>
    /// Saca el GTIN de (01) o (02) y el lote de (10) de una lectura GS1-128, tal como la manda
    /// el escáner (separador GS) o con los AI entre paréntesis. Devuelve false si no lo es.
    /// Se deja de leer en el primer AI que no se conoce: lo que interesa suele ir delante.
    /// </summary>
    local procedure LeerGS1(prm_Codigo: Text; var prm_Gtin: Text; var prm_Lote: Code[50]): Boolean
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
                    '01', '02':
                        prm_Gtin := valor;
                    '10':
                        prm_Lote := CopyStr(valor, 1, MaxStrLen(prm_Lote));
                end;
            end;

        exit((prm_Gtin <> '') or (prm_Lote <> ''));
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

    /// <summary>
    /// Para que otra extensión reconozca códigos que SGA no conoce, como campos propios de la
    /// ficha del producto. Se lanza solo si SGA no lo ha encontrado.
    /// </summary>
    [IntegrationEvent(false, false)]
    local procedure OnBuscarProducto(prm_Codigo: Text; var prm_Producto: Code[20]; var prm_Variante: Code[10]; var prm_Encontrado: Boolean)
    begin
    end;
}
