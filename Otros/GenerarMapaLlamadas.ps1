# Genera MAPA_LLAMADAS.md: qué objetos de SGA usa cada objeto de SGA y quién lo usa a él.
# Lee los .al de SGA y busca las referencias a otros objetos de SGA (variables Record,
# Codeunit, Page..., RunObject, CardPageId, partes, extends, SourceTable, TableRelation,
# usercontrol). Es un mapa estático: dice qué objeto depende de cuál, no cuántas veces ni en
# qué orden. Los objetos de la base de BC y del resto del proyecto no salen. Uso:
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

# 3. Diagramas Mermaid. Los nodos llevan un id corto; el nombre va en la etiqueta.
# Los menús apuntan a casi todo: en el diagrama de navegación solo harían ruido.
$menus = @('page|Rol Center Almacen SGA', 'pageextension|Order Processor SGA')
$ids = @{}
$n = 0
foreach ($clave in $objetos.Keys) { $n++; $ids[$clave] = "n$n" }

function Nodo([string]$clave) {
    $obj = $objetos[$clave]
    $forma = switch ($obj.Tipo) {
        'codeunit' { '[["{0}"]]' }
        'table' { '[("{0}")]' }
        'tableextension' { '[("{0}")]' }
        'report' { '[/"{0}"/]' }
        default { '["{0}"]' }
    }
    return "$($ids[$clave])$([string]::Format($forma, $obj.Nombre))"
}

function Diagrama([string]$titulo, [string]$explicacion, [scriptblock]$filtroArista) {
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## $titulo").AppendLine().AppendLine($explicacion).AppendLine()
    [void]$sb.AppendLine('```mermaid').AppendLine('flowchart LR')
    $nodos = [ordered]@{}
    $aristas = [System.Collections.Generic.List[string]]::new()
    foreach ($origen in $objetos.Keys) {
        foreach ($destino in ($objetos[$origen].Usa.Keys | Sort-Object)) {
            if (& $filtroArista $objetos[$origen].Tipo $objetos[$destino].Tipo $origen) {
                $nodos[$origen] = $true; $nodos[$destino] = $true
                $aristas.Add("    $($ids[$origen]) --> $($ids[$destino])")
            }
        }
    }
    foreach ($clave in $nodos.Keys) { [void]$sb.AppendLine("    $(Nodo $clave)") }
    foreach ($a in $aristas) { [void]$sb.AppendLine($a) }
    [void]$sb.AppendLine('```').AppendLine()
    return $sb.ToString()
}

# Nombre legible de una lista de objetos; el tipo solo se añade si el nombre se repite.
function Etiqueta([string]$clave) {
    $obj = $objetos[$clave]
    $repetido = @($objetos.Values | Where-Object { $_.Nombre -eq $obj.Nombre }).Count -gt 1
    if ($repetido) { return "$($obj.Nombre) ($($nombreTipo[$obj.Tipo].ToLower()))" }
    return $obj.Nombre
}

function Lista([hashtable]$conjunto) {
    if ($conjunto.Count -eq 0) { return '—' }
    return ((@($conjunto.Keys | ForEach-Object { Etiqueta $_ }) | Sort-Object) -join ', ')
}

$md = [System.Text.StringBuilder]::new()
[void]$md.AppendLine('# Mapa de llamadas de SGA').AppendLine()
[void]$md.AppendLine('Qué objeto de SGA usa a cuál. Lo genera `GenerarMapaLlamadas.ps1` leyendo el código: no se edita a mano, se vuelve a generar.').AppendLine()
[void]$md.AppendLine('Es un mapa de dependencias, no de ejecución: una flecha dice que el objeto nombra al otro (variable, `RunObject`, parte, `SourceTable`...), no cuántas veces ni en qué orden lo llama. No salen los objetos de BC ni los del resto del proyecto, ni los conjuntos de permisos.').AppendLine()
[void]$md.AppendLine('Formas: `[[codeunit]]`, `[(tabla)]`, `[/informe/]`, `[página u otro]`.').AppendLine()

[void]$md.Append((Diagrama 'Núcleo: codeunits entre sí' 'Cómo se apoyan los codeunits unos en otros. La puerta de escritura es *Gestion Contenido SGA*; el motor de propuesta, *Gestion Ubicaciones SGA*.' { param($o, $d) $o -eq 'codeunit' -and $d -eq 'codeunit' }))
[void]$md.Append((Diagrama 'Quién llama a la lógica' 'Páginas, informes, extensiones y tablas que usan algún codeunit. La lógica vive en los codeunits; las páginas llaman.' { param($o, $d) $o -ne 'codeunit' -and $d -eq 'codeunit' }))
[void]$md.Append((Diagrama 'Navegación entre pantallas' 'Qué página, informe o extensión abre o incrusta a cuál (partes, fichas, informes). Los dos menús, *Rol Center Almacen SGA* y *Order Processor SGA*, abren casi todo y no salen aquí: su lista está en la tabla.' { param($o, $d, $clave) ($o -in 'page', 'pageextension', 'report', 'codeunit') -and ($d -in 'page', 'report', 'controladdin') -and ($clave -notin $menus) }))

[void]$md.AppendLine('## Tabla completa').AppendLine()
[void]$md.AppendLine('| Objeto | Tipo | Usa | Lo usan |').AppendLine('|---|---|---|---|')
foreach ($clave in ($objetos.Keys | Sort-Object { $objetos[$_].Tipo }, { $objetos[$_].Nombre })) {
    $obj = $objetos[$clave]
    if ($obj.Tipo -eq 'permissionset') { continue }
    [void]$md.AppendLine("| **$($obj.Nombre)** | $($nombreTipo[$obj.Tipo]) | $(Lista $obj.Usa) | $(Lista $obj.UsadoPor) |")
}
[void]$md.AppendLine()

$sinUso = @($objetos.Keys | Where-Object {
        $objetos[$_].UsadoPor.Count -eq 0 -and $objetos[$_].Tipo -notin 'pageextension', 'tableextension', 'permissionset', 'profile', 'enumextension'
    } | Sort-Object { $objetos[$_].Nombre })
[void]$md.AppendLine('## Objetos que ningún otro objeto de SGA nombra').AppendLine()
[void]$md.AppendLine('No quiere decir que sobren: pueden abrirse desde el buscador, la cola de proyectos o una URL. Es la lista que hay que mirar al buscar código muerto.').AppendLine()
if ($sinUso.Count -eq 0) { [void]$md.AppendLine('Ninguno.') }
foreach ($clave in $sinUso) { [void]$md.AppendLine("- **$($objetos[$clave].Nombre)** ($($nombreTipo[$objetos[$clave].Tipo]))") }

Set-Content -LiteralPath $salida -Value $md.ToString() -Encoding UTF8
Write-Host "Generado $salida con $($objetos.Count) objetos."
