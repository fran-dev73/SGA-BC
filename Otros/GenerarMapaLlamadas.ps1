# Genera MAPA_LLAMADAS.md: qué codeunit de SGA usa a cuál y quién lo llama.
# Lee los .al de SGA y busca las referencias a otros objetos de SGA (variables Record,
# Codeunit, Page..., RunObject, CardPageId, partes, extends, SourceTable, TableRelation,
# usercontrol). Es un mapa estático: no cuenta cuántas veces ni en qué orden. Solo se
# muestran codeunits. Los objetos de la base de BC y del resto del proyecto no salen. Uso:
#   powershell -ExecutionPolicy Bypass -File SGA\Otros\GenerarMapaLlamadas.ps1
$ErrorActionPreference = 'Stop'

$raiz = Split-Path $PSScriptRoot -Parent
$salida = Join-Path $PSScriptRoot 'MAPA_LLAMADAS.md'

$patronObjeto = '^\s*(table|tableextension|page|pageextension|codeunit|report|enum|enumextension|query|xmlport|controladdin|profile|permissionset)\s+(\d+\s+)?"?([^"{]+?)"?\s*(extends|$|\{)'

# Cada patrón da el tipo del objeto nombrado: fijo, o sacado de la palabra que lo precede.
# Hay nombres repetidos entre tipos (tabla y página "Config. SGA"), así que el tipo cuenta.
$palabraTipo = @{
    record = 'table'; codeunit = 'codeunit'; page = 'page'; report = 'report'; enum = 'enum'
    query = 'query'; xmlport = 'xmlport'
}
$patronesRef = @(
    @{ Patron = '(?i)\b(Record|Codeunit|Page|Report|Enum|Query|XmlPort)\s+"([^"]+)"'; Tipo = $null },
    @{ Patron = '(?i)\b(page|codeunit|report|enum)::"([^"]+)"'; Tipo = $null },
    @{ Patron = '(?i)\bRunObject\s*=\s*(page|codeunit|report)\s+"([^"]+)"'; Tipo = $null },
    @{ Patron = '(?i)\b(RoleCenter|CardPageId|DrillDownPageId|LookupPageId)\s*=\s*"([^"]+)"'; Tipo = 'page' },
    @{ Patron = '(?i)\b(SourceTable|TableRelation)\s*=\s*"([^"]+)"'; Tipo = 'table' },
    @{ Patron = '(?i)\b(part)\s*\(\s*\w+\s*;\s*"([^"]+)"'; Tipo = 'page' },
    @{ Patron = '(?i)\b(usercontrol)\s*\(\s*\w+\s*;\s*"([^"]+)"'; Tipo = 'controladdin' }
)
$tipoExtendido = @{ pageextension = 'page'; tableextension = 'table'; enumextension = 'enum' }

$nombreTipo = @{
    codeunit = 'Codeunit'; page = 'Página'; pageextension = 'Ext. página'; table = 'Tabla'
    tableextension = 'Ext. tabla'; report = 'Informe'; enum = 'Enum'; controladdin = 'Control add-in'
    profile = 'Perfil'; permissionset = 'Permisos'; query = 'Query'; xmlport = 'XmlPort'; enumextension = 'Ext. enum'
}

# 1. Objetos declarados, por tipo y nombre.
$objetos = [ordered]@{}
$ficheros = Get-ChildItem -LiteralPath $raiz -Recurse -Filter '*.al' | Where-Object { $_.FullName -notmatch '\\\.git\\' }
foreach ($f in $ficheros) {
    foreach ($linea in (Get-Content -LiteralPath $f.FullName -Encoding UTF8)) {
        if ($linea -match $patronObjeto) {
            $tipo = $Matches[1].ToLower()
            $nombre = $Matches[3].Trim()
            $objetos["$tipo|$nombre"] = [pscustomobject]@{ Tipo = $tipo; Nombre = $nombre; Fichero = $f.FullName; Usa = @{}; UsadoPor = @{} }
            break
        }
    }
}

# 2. Referencias entre objetos de SGA. Los permisos lo nombran todo y no cuentan.
foreach ($clave in @($objetos.Keys)) {
    $obj = $objetos[$clave]
    if ($obj.Tipo -eq 'permissionset') { continue }
    $refs = @{}
    foreach ($linea in (Get-Content -LiteralPath $obj.Fichero -Encoding UTF8)) {
        if ($linea.TrimStart().StartsWith('//')) { continue }
        $codigo = $linea -replace "\s//[^']*$", ''
        foreach ($p in $patronesRef) {
            foreach ($m in [regex]::Matches($codigo, $p.Patron)) {
                $tipo = $p.Tipo
                if (-not $tipo) { $tipo = $palabraTipo[$m.Groups[1].Value.ToLower()] }
                $refs["$tipo|$($m.Groups[2].Value)"] = $true
            }
        }
        if (($codigo -match '(?i)\bextends\s+"([^"]+)"') -and $tipoExtendido.Contains($obj.Tipo)) {
            $refs["$($tipoExtendido[$obj.Tipo])|$($Matches[1])"] = $true
        }
    }
    foreach ($ref in $refs.Keys) {
        if (($ref -ne $clave) -and $objetos.Contains($ref)) {
            $obj.Usa[$ref] = $true
            $objetos[$ref].UsadoPor[$clave] = $true
        }
    }
}

# 3. Salida: solo codeunits. Diagrama de flechas entre ellos, tabla y lista de los que nadie nombra.
$ids = @{}
$n = 0
foreach ($clave in $objetos.Keys) { $n++; $ids[$clave] = "n$n" }

function Diagrama([string]$titulo, [string]$explicacion) {
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## $titulo").AppendLine().AppendLine($explicacion).AppendLine()
    [void]$sb.AppendLine('```mermaid').AppendLine('flowchart LR')
    $nodos = [ordered]@{}
    $aristas = [System.Collections.Generic.List[string]]::new()
    foreach ($origen in $objetos.Keys) {
        if ($objetos[$origen].Tipo -ne 'codeunit') { continue }
        foreach ($destino in ($objetos[$origen].Usa.Keys | Sort-Object)) {
            if ($objetos[$destino].Tipo -ne 'codeunit') { continue }
            $nodos[$origen] = $true; $nodos[$destino] = $true
            $aristas.Add("    $($ids[$origen]) --> $($ids[$destino])")
        }
    }
    foreach ($clave in $nodos.Keys) { [void]$sb.AppendLine("    $($ids[$clave])[[`"$($objetos[$clave].Nombre)`"]]") }
    foreach ($a in $aristas) { [void]$sb.AppendLine($a) }
    [void]$sb.AppendLine('```').AppendLine()
    return $sb.ToString()
}

# Nombres de los codeunits de un conjunto de relaciones.
function Lista([hashtable]$conjunto) {
    $nombres = @($conjunto.Keys | Where-Object { $objetos[$_].Tipo -eq 'codeunit' } | ForEach-Object { $objetos[$_].Nombre })
    if ($nombres.Count -eq 0) { return '—' }
    return (($nombres | Sort-Object) -join ', ')
}

$md = [System.Text.StringBuilder]::new()
[void]$md.AppendLine('# Mapa de llamadas de SGA').AppendLine()
[void]$md.AppendLine('Qué codeunit de SGA llama a cuál. Lo genera `GenerarMapaLlamadas.ps1`: no se edita a mano, se vuelve a generar.').AppendLine()
[void]$md.AppendLine('Una flecha `A --> B` significa que el código de A nombra a B; no dice cuántas veces ni en qué orden. Páginas, informes y tablas no salen.').AppendLine()
[void]$md.Append((Diagrama 'Codeunits entre sí' 'La puerta de escritura es *Gestion Contenido SGA*; el motor de propuesta, *Gestion Ubicaciones SGA*.'))

[void]$md.AppendLine('## Codeunits: qué usan y quién los llama').AppendLine()
[void]$md.AppendLine('| Codeunit | Usa | Lo llaman |').AppendLine('|---|---|---|')
foreach ($clave in ($objetos.Keys | Where-Object { $objetos[$_].Tipo -eq 'codeunit' } | Sort-Object { $objetos[$_].Nombre })) {
    $obj = $objetos[$clave]
    [void]$md.AppendLine("| **$($obj.Nombre)** | $(Lista $obj.Usa) | $(Lista $obj.UsadoPor) |")
}
[void]$md.AppendLine()

$sinUso = @($objetos.Keys | Where-Object { $objetos[$_].Tipo -eq 'codeunit' -and $objetos[$_].UsadoPor.Count -eq 0 } | Sort-Object { $objetos[$_].Nombre })
[void]$md.AppendLine('## Codeunits que ningún objeto de SGA nombra').AppendLine()
[void]$md.AppendLine('No quiere decir que sobren: pueden ejecutarse desde el buscador, la cola de proyectos o una URL. Es la lista que hay que mirar al buscar código muerto.').AppendLine()
if ($sinUso.Count -eq 0) { [void]$md.AppendLine('Ninguno.') }
foreach ($clave in $sinUso) { [void]$md.AppendLine("- **$($objetos[$clave].Nombre)**") }

Set-Content -LiteralPath $salida -Value $md.ToString() -Encoding UTF8
Write-Host "Generado $salida con $($objetos.Count) objetos."
