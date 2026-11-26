# Mapa de llamadas de SGA.
#
# Lee los .al de SGA (sin compilar) y genera MapaSGA.html, que se abre en el navegador. Parte de
# los menús (perfiles y su rol center, acciones de SGA en pantallas de BC, búsqueda de BC y lo que
# lanza BC por eventos) y baja por pantallas, acciones, campos y procedimientos hasta las tablas.
#
# Es una lectura del texto, no del compilador: lo que no está escrito como llamada (RecordRef,
# interfaces, eventos propios) no sale. Las llamadas se resuelven por el tipo de la variable.
#
# Uso, desde esta carpeta: powershell -ExecutionPolicy Bypass -File .\GenerarMapa.ps1
$ErrorActionPreference = 'Stop'

$raizSGA = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$rutaPlantilla = Join-Path $PSScriptRoot 'MapaSGA.plantilla.html'
$rutaSalida = Join-Path $PSScriptRoot 'MapaSGA.html'
# Cómo funciona cada acción: los mismos datos en otra página.
$rutaPlantillaAcciones = Join-Path $PSScriptRoot 'ComoFuncionaSGA.plantilla.html'
$rutaSalidaAcciones = Join-Path $PSScriptRoot 'ComoFuncionaSGA.html'
$rutaAddinPDA = Join-Path $raizSGA 'Otros\Add-in\PickingPDASGA.js'

$opc = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
$reObjeto = New-Object regex '^(table|tableextension|page|pageextension|codeunit|report|reportextension|query|xmlport|enum|enumextension|controladdin|permissionset|permissionsetextension|profile|interface)\s+(?:(\d+)\s+)?(?:"([^"]+)"|([\w\.]+))(?:\s+extends\s+(?:"([^"]+)"|([\w\.]+)))?', $opc
$reTokens = New-Object regex '''(?:[^'']|'''')*''|"[^"]*"|//.*$|/\*.*?(?:\*/|$)'
$reDeclaracion = New-Object regex '^(?:(local|internal|protected)\s+)?(procedure|trigger)\s+("[^"]+"|\w+)', $opc
$reAbre = New-Object regex '\b(begin|case)\b', $opc
$reCierra = New-Object regex '\bend\b', $opc
$reRefObjeto = New-Object regex '\b(Page|Report|Codeunit)::("[^"]+"|\w+)', $opc
$reLlamadaVar = New-Object regex '(?<![\w"\.])("[^"\n]+"|[A-Za-z_]\w*)\s*\.\s*("[^"\n]+"|[A-Za-z_]\w*)\s*\(', $opc
$reSubpagina = New-Object regex 'CurrPage\.("[^"\n]+"|\w+)\.Page\.("[^"\n]+"|\w+)\s*\(', $opc
$reLlamadaSuelta = New-Object regex '(?<![\w"\.:])("[^"\n]+"|[A-Za-z_]\w*)\s*\(', $opc
$reToken = New-Object regex '''(?:[^'']|'''')*''|"[^"]*"|\d+(?:\.\d+)?|[A-Za-z_]\w*|::|:=|\+=|-=|\*=|/=|<>|<=|>=|\.\.|\S'
$reAsignacion = New-Object regex '(?<![\w"\.])(\w+)\s*(?::=|\+=|-=|\*=|/=)|\b(?:Clear|Evaluate)\s*\(\s*(\w+)', $opc
# Etiquetas: "Nombre: Label 'texto', Comment = '...'" (las Locked no son textos para el usuario).
$reEtiqueta = New-Object regex '^\s*("[^"]+"|\w+)\s*:\s*Label\s+''((?:[^'']|'''')*)''(.*)$', $opc
# Uso de una etiqueta de aviso: por convención acaban en Err (error), Qst (pregunta) o Msg.
$reAviso = New-Object regex '(?<![\w"\.])(\w+?(Err|Qst|Msg))\b'
$reCampoObligatorio = New-Object regex '\bTestField\s*\(\s*("[^"]+"|\w+)', $opc
# Ramas de un evento de un control de la PDA: "'valor':", "x = 'valor':", "x.StartsWith('valor'):"
# o "if x = 'valor' then".
$reRama = New-Object regex '^\s*(?:''([^'']+)''\s*:|\w+\s*=\s*''([^'']+)''\s*:|\w+\.StartsWith\(\s*''([^'']+)''\s*\)\s*:|if\s+\w+\s*=\s*''([^'']+)''\s+then\b)', $opc

$lecturas = @('get', 'find', 'findfirst', 'findlast', 'findset', 'isempty', 'count', 'calcsums', 'calcfields', 'getbysystemid')
$escrituras = @('insert', 'modify', 'delete', 'modifyall', 'deleteall', 'rename')
$omitidos = @('enum', 'enumextension', 'controladdin', 'permissionset', 'permissionsetextension', 'interface')

$objetos = @{}        # clave del objeto -> objeto leído
$miembros = @{}       # id -> procedimiento, trigger, acción o campo con código
$listaMiembros = New-Object System.Collections.Generic.List[object]
$procsTabla = @{}     # tabla -> @{ procedimiento -> id } (tabla y sus ampliaciones de SGA)
$camposTabla = @{}    # tabla -> @{ campo -> contexto del campo }
$trigTabla = @{}      # tabla -> @{ trigger -> id } (OnInsert, OnModify...)
$nodos = @{}          # id -> nodo del mapa

# ---------------------------------------------------------------------------------------------
# Lectura de los ficheros
# ---------------------------------------------------------------------------------------------

$script:enComentario = $false
$evaluador = [System.Text.RegularExpressions.MatchEvaluator] {
    param($m)
    $v = $m.Value
    # El texto vacío se conserva (las condiciones lo comparan); cualquier otro queda en '?'.
    if ($v.StartsWith("'")) { if ($v -eq "''") { return "''" }; return "'?'" }
    if ($v.StartsWith('"')) { return $v }
    if ($v.StartsWith('/*') -and -not $v.EndsWith('*/')) { $script:enComentario = $true }
    return ''
}

# La línea sin comentarios y con los textos vacíos: lo que queda es código e identificadores.
function Limpiar([string]$s) {
    if ($script:enComentario) {
        $p = $s.IndexOf('*/')
        if ($p -lt 0) { return '' }
        $s = $s.Substring($p + 2)
        $script:enComentario = $false
    }
    return $reTokens.Replace($s, $evaluador)
}

function Remove-Comillas([string]$s) {
    $s = $s.Trim()
    if ($s.Length -ge 2 -and $s.StartsWith('"') -and $s.EndsWith('"')) { return $s.Substring(1, $s.Length - 2) }
    return $s
}

function Get-NombreGrupo([System.Text.RegularExpressions.Match]$m, [int]$g1, [int]$g2) {
    if ($m.Groups[$g1].Success) { return $m.Groups[$g1].Value }
    $v = $m.Groups[$g2].Value
    if ($v.Contains('.')) { $v = $v.Substring($v.LastIndexOf('.') + 1) }
    return $v
}

function Clave([string]$tipo, [string]$nombre) { return $tipo + ':' + $nombre.ToLower() }

# Tipo de una variable: solo interesan registros, codeunits, páginas e informes.
function Get-TipoVariable([string]$t) {
    $m = [regex]::Match($t, '^\s*(Record|Codeunit|Page|Report)\s+(?:"([^"]+)"|([\w\.]+))(\s+temporary)?', $opc)
    if (-not $m.Success) { return $null }
    $clase = $m.Groups[1].Value.ToLower()
    if ($clase -eq 'record') { $clase = 'table' }
    return @{ tipo = $clase; nombre = (Get-NombreGrupo $m 2 3); temporal = $m.Groups[4].Success }
}

function Read-Variable([string]$c, [hashtable]$destino) {
    $m = [regex]::Match($c, '^("[^"]+"|\w+(?:\s*,\s*\w+)*)\s*:\s*(.+?);?\s*$')
    if (-not $m.Success) { return }
    $tipo = Get-TipoVariable $m.Groups[2].Value
    if ($null -eq $tipo) { return }
    foreach ($n in ($m.Groups[1].Value -split ',')) { $destino[(Remove-Comillas $n).ToLower()] = $tipo }
}

# Una etiqueta de texto para el usuario: su texto, con cada %n cambiado por lo que dice su
# Comment ("%1 = ubicación" -> «ubicación»). Las Locked son códigos, no textos.
function Read-Etiqueta([string]$raw, [hashtable]$destino) {
    $m = $reEtiqueta.Match($raw)
    if (-not $m.Success -or $m.Groups[3].Value -match '(?i)\bLocked\s*=\s*true') { return }
    $texto = $m.Groups[2].Value.Replace("''", "'")
    $comentario = [regex]::Match($m.Groups[3].Value, '(?i)Comment\s*=\s*''((?:[^'']|'''')*)''')
    $nombres = @{}
    if ($comentario.Success) {
        foreach ($p in [regex]::Matches($comentario.Groups[1].Value, '%(\d)\s*=\s*([^,]+)')) { $nombres[$p.Groups[1].Value] = $p.Groups[2].Value.Trim() }
    }
    # Sin literales con acentos ni comillas angulares: PowerShell 5 lee este fichero como ANSI.
    $abre = [string][char]0xAB; $cierra = [string][char]0xBB; $puntos = [string][char]0x2026
    $texto = [regex]::Replace($texto, '%(\d)', { param($x) $n = $nombres[$x.Groups[1].Value]; if ($n) { $abre + $n + $cierra } else { $abre + $puntos + $cierra } })
    $destino[(Remove-Comillas $m.Groups[1].Value).ToLower()] = $texto
}

# Los parámetros de una declaración, uno por elemento ('' si no tiene paréntesis).
function Get-ListaParametros([string]$firma) {
    $p = $firma.IndexOf('(')
    if ($p -lt 0) { return ,@() }
    $prof = 0
    $fin = -1
    for ($j = $p; $j -lt $firma.Length; $j++) {
        if ($firma[$j] -eq '(') { $prof++ }
        elseif ($firma[$j] -eq ')') { $prof--; if ($prof -eq 0) { $fin = $j; break } }
    }
    if ($fin -lt 0) { return ,@() }
    return ,@($firma.Substring($p + 1, $fin - $p - 1) -split ';' | Where-Object { $_.Trim() -ne '' })
}

# Lee los parámetros de la firma: los de tipo objeto van a prm_Destino (como las variables) y
# devuelve, en orden, su nombre y si son var.
function Read-Parametros([string]$firma, [hashtable]$destino) {
    $lista = New-Object System.Collections.Generic.List[object]
    foreach ($par in (Get-ListaParametros $firma)) {
        Read-Variable (($par.Trim() -replace '^(?i)var\s+', '') + ';') $destino
        $m = [regex]::Match($par, '^\s*(var\s+)?("[^"]+"|\w+)\s*:\s*(Record\b)?', $opc)
        if ($m.Success) { $lista.Add(@{ n = (Remove-Comillas $m.Groups[2].Value).ToLower(); var = $m.Groups[1].Success; rec = $m.Groups[3].Success }) }
    }
    return ,$lista.ToArray()
}

function Get-TextoDoc($lineas) {
    if ($lineas.Count -eq 0) { return $null }
    $t = (($lineas | ForEach-Object { $_ -replace '<[^>]+>', '' }) -join "`n").Trim()
    $t = [regex]::Replace($t, '\n{3,}', "`n`n")
    if ($t -eq '') { return $null }
    return $t
}

function Get-TablaBase($obj) {
    if ($obj.tipo -eq 'tableextension') { return $obj.base.ToLower() }
    return $obj.nombre.ToLower()
}

function New-Objeto($m, [string]$ruta, [int]$linea, $doc) {
    $tipo = $m.Groups[1].Value.ToLower()
    $nombre = Get-NombreGrupo $m 3 4
    $base = $null
    if ($m.Groups[5].Success -or $m.Groups[6].Success) { $base = Get-NombreGrupo $m 5 6 }
    $obj = @{
        tipo = $tipo; num = $m.Groups[2].Value; nombre = $nombre; base = $base; clave = (Clave $tipo $nombre)
        fichero = $ruta.Substring($raizSGA.Length + 1).Replace('\', '/'); linea = $linea; doc = $doc
        caption = $null; omitir = ($omitidos -contains $tipo); globales = @{}; procs = @{}; etiquetas = @{}
        acciones = (New-Object System.Collections.Generic.List[object])
        campos = (New-Object System.Collections.Generic.List[object])
        partes = (New-Object System.Collections.Generic.List[object])
        dataitems = (New-Object System.Collections.Generic.List[object])
        miembros = (New-Object System.Collections.Generic.List[string])
        fuente = $null; drill = $null; ficha = $null; uso = $null; rolCenter = $null; tipoPagina = $null
        temporal = $false; fuenteTemporal = $false
    }
    if (-not $obj.omitir) { $objetos[$obj.clave] = $obj }
    return $obj
}

# Los argumentos de una llamada (prm_Llamada empieza en su paréntesis), separados por comas fuera
# de paréntesis y corchetes. completa = false si el paréntesis no se cierra.
function Get-ListaArgumentos([string]$prm_Llamada) {
    $lista = New-Object System.Collections.Generic.List[string]
    $p = $prm_Llamada.IndexOf('(')
    if ($p -lt 0) { return @{ args = $lista; completa = $true } }
    $prof = 0; $ini = $p + 1
    for ($j = $p; $j -lt $prm_Llamada.Length; $j++) {
        $ch = $prm_Llamada[$j]
        if ($ch -eq '(' -or $ch -eq '[') { $prof++ }
        elseif ($ch -eq ')' -or $ch -eq ']') {
            $prof--
            if ($prof -eq 0) {
                $ultimo = $prm_Llamada.Substring($ini, $j - $ini).Trim()
                if ($ultimo -ne '' -or $lista.Count -gt 0) { $lista.Add($ultimo) }
                return @{ args = $lista; completa = $true }
            }
        }
        elseif ($ch -eq ',' -and $prof -eq 1) { $lista.Add($prm_Llamada.Substring($ini, $j - $ini).Trim()); $ini = $j + 1 }
    }
    return @{ args = $lista; completa = $false }
}

# Valor fijo de un argumento: v = texto vacío, l = texto con algo, t/f = true/false, e:x = valor
# x de un enum. Un parámetro de la función que llama se pasa como '@nombre', y "[not] p in [...]"
# o "p = Enum::X" sobre un parámetro como '#[!]nombre|x;y' (se resuelve con su valor al recorrer).
function Get-ValorFijo([string]$prm_Texto, $prm_Miembro) {
    $t = Remove-Parentesis $prm_Texto
    if ($t -eq "''") { return 'v' }
    if ($t -eq "'?'") { return 'l' }
    if ($t -eq 'true') { return 't' }
    if ($t -eq 'false') { return 'f' }
    $e = Get-ValorEnum $t
    if ($e) { return 'e:' + $e }
    if ($t -match '^\w+$' -and (Get-PosParametro $prm_Miembro $t) -ge 0) { return '@' + $t.ToLower() }
    $neg = ''
    if ($t -match '^(?i)not\s+(.+)$') { $neg = '!'; $t = Remove-Parentesis $Matches[1] }
    $c = Get-CondicionEnum $t
    if ($c -and $c.op -match '^[ei]:' -and (Get-PosParametro $prm_Miembro $c.nombre) -ge 0) { return '#' + $neg + $c.nombre + '|' + $c.op.Substring(2) }
    return $null
}

# El valor de un literal de enum ("Tipo"::"Valor" o Tipo::Valor), en minúsculas y sin comillas.
function Get-ValorEnum([string]$prm_Texto) {
    $m = [regex]::Match($prm_Texto.Trim(), '^(?:"[^"]+"|\w+)\s*::\s*(?:"([^"]+)"|(\w+))$')
    if (-not $m.Success) { return $null }
    if ($m.Groups[1].Success) { return $m.Groups[1].Value.ToLower() }
    return $m.Groups[2].Value.ToLower()
}

# "p = Enum::X" (e:x), "p <> Enum::X" (n:x) o "p in [Enum::X, Enum::Y]" (i:x;y), con p un nombre.
function Get-CondicionEnum([string]$prm_Texto) {
    $m = [regex]::Match($prm_Texto, '^(\w+)\s*(=|<>)\s*(.+)$')
    if ($m.Success) {
        $e = Get-ValorEnum $m.Groups[3].Value
        if (-not $e) { return $null }
        if ($m.Groups[2].Value -eq '=') { return @{ nombre = $m.Groups[1].Value.ToLower(); op = 'e:' + $e } }
        return @{ nombre = $m.Groups[1].Value.ToLower(); op = 'n:' + $e }
    }
    $m = [regex]::Match($prm_Texto, '^(?i)(\w+)\s+in\s*\[(.+)\]$')
    if (-not $m.Success) { return $null }
    $valores = @()
    foreach ($x in ($m.Groups[2].Value -split ',')) {
        $e = Get-ValorEnum $x
        if (-not $e) { return $null }
        $valores += $e
    }
    return @{ nombre = $m.Groups[1].Value.ToLower(); op = 'i:' + ($valores -join ';') }
}

function Get-PosParametro($prm_Miembro, [string]$prm_Nombre) {
    $n = $prm_Nombre.ToLower()
    for ($i = 0; $i -lt $prm_Miembro.params.Count; $i++) { if ($prm_Miembro.params[$i].n -eq $n) { return $i } }
    return -1
}

# Lo que lleva fijo cada parámetro de prm_Destino en esta llamada (posición -> valor). Un
# parámetro de la función que llama pasado a un parámetro var puede cambiar: deja de ser fijo.
function Get-ValoresLlamada($prm_Destino, $prm_Argumentos) {
    $valores = @{}
    # Una función de tabla recibe además su propio registro (s): temporal, real o el de quien llama.
    if ($script:selfValor -and @('table', 'tableextension') -contains $prm_Destino.obj.tipo) { $valores['s'] = $script:selfValor }
    $params = $prm_Destino.params
    for ($i = 0; $i -lt [Math]::Min($params.Count, $prm_Argumentos.args.Count); $i++) {
        $arg = $prm_Argumentos.args[$i]
        # A un registro se le pasa si es temporal (k) o real (r); la función no puede cambiarlo.
        if ($params[$i].rec) {
            $v = Get-ClaseRegistro $arg
            if ($v) { $valores[[string]$i] = $v }
            continue
        }
        if ($params[$i].var) {
            if ($arg -match '^\w+$') { $script:miActual.inestables[$arg.ToLower()] = $true }
            continue
        }
        $v = Get-ValorFijo $arg $script:miActual
        if ($v) { $valores[[string]$i] = $v }
    }
    return $valores
}

# Si el registro que se pasa en una llamada es temporal ('k') o real ('r'), o '@nombre' si es un
# registro que la función que llama recibe como parámetro.
function Get-ClaseRegistro([string]$prm_Arg) {
    $n = (Remove-Comillas $prm_Arg).ToLower()
    if ($n -notmatch '^\w+$') { return $null }
    $mi = $script:miActual
    if ($mi.locales.ContainsKey($n)) {
        if ((Get-PosParametro $mi $n) -ge 0 -and -not $mi.locales[$n].temporal) { return '@' + $n }
        if ($mi.locales[$n].temporal) { return 'k' }
        return 'r'
    }
    if ($mi.obj.globales.ContainsKey($n)) { if ($mi.obj.globales[$n].temporal) { return 'k' }; return 'r' }
    return $null
}

# Lo que exige una condición (if ... then) a los parámetros de la función. Con partes unidas por
# "and": cada parte entendida (un parámetro comparado con un texto, usado como booleano o comparado
# con un valor de enum) es una exigencia; las demás no se saben y no exigen. Con partes unidas por
# "or": una sola exigencia "o~p|op~p|op" (basta una), solo si se entienden todas. Mezcladas, nada.
# total = cuántas partes tiene; o = las partes del "or" (para negarlo).
function Get-Exigencias([string]$prm_Condicion, $prm_Miembro) {
    $c = Remove-Parentesis $prm_Condicion
    $partes = New-Object System.Collections.Generic.List[string]
    $nexos = @{}
    $prof = 0; $ini = 0
    for ($j = 0; $j -lt $c.Length; $j++) {
        $ch = $c[$j]
        if ($ch -eq '(' -or $ch -eq '[') { $prof++ }
        elseif ($ch -eq ')' -or $ch -eq ']') { $prof-- }
        elseif ($prof -eq 0 -and ($j -eq 0 -or $c[$j - 1] -match '[\s\)]')) {
            $resto = $c.Substring($j)
            if ($resto -match '^(?i)xor\b') { return @{ exige = @(); total = 0 } }
            $mn = [regex]::Match($resto, '^(?i)(and|or)\b')
            if ($mn.Success) {
                $nexos[$mn.Groups[1].Value.ToLower()] = $true
                $partes.Add($c.Substring($ini, $j - $ini))
                $ini = $j + $mn.Length
            }
        }
    }
    $partes.Add($c.Substring($ini))
    if ($nexos.Count -gt 1) { return @{ exige = @(); total = 0 } }
    $entendidas = @($partes | ForEach-Object { Get-ParteCondicion $_ $prm_Miembro })
    if ($nexos.ContainsKey('or')) {
        if (@($entendidas | Where-Object { -not $_ }).Count -gt 0) { return @{ exige = @(); total = 0 } }
        return @{ exige = @('o~' + ($entendidas -join '~')); total = 1; o = $entendidas }
    }
    return @{ exige = @($entendidas | Where-Object { $_ }); total = $partes.Count }
}

# Una parte de una condición sobre un parámetro, como "nombre|op"; $null si no se entiende.
# p = '' -> vacío; p <> '' -> con algo; p = 'X' -> con algo; p <> 'X' no dice nada.
function Get-ParteCondicion([string]$prm_Parte, $prm_Miembro) {
    $p = Remove-Parentesis $prm_Parte
    $nombre = $null; $op = $null
    if ($p -match '^(\w+)\s*(<>|=)\s*(''\?''|'''')$') {
        $nombre = $Matches[1]
        $vacio = ($Matches[3] -eq "''")
        if ($Matches[2] -eq '=') { if ($vacio) { $op = 'v' } else { $op = 'l' } }
        elseif ($vacio) { $op = 'l' }
    }
    elseif ($p -match '^(?i)not\s+(\w+)$') { $nombre = $Matches[1]; $op = 'f' }
    elseif ($p -match '^\w+$') { $nombre = $p; $op = 't' }
    else {
        $neg = $p -match '^(?i)not\s+(.+)$'
        $ce = Get-CondicionEnum $(if ($neg) { Remove-Parentesis $Matches[1] } else { $p })
        if ($ce) { $nombre = $ce.nombre; $op = $ce.op; if ($neg) { $op = Get-Contrario $op } }
    }
    if ($nombre -and $op -and (Get-PosParametro $prm_Miembro $nombre) -ge 0) { return $nombre.ToLower() + '|' + $op }
    return $null
}

# La condición contraria, si se puede expresar exacta: una sola parte entendida (vacío/con algo,
# true/false, igual/distinto, en la lista/fuera), o un "or" entendido entero (ninguna se cumple).
function Get-Negacion($prm_Exigencias) {
    if ($prm_Exigencias.o) { return @($prm_Exigencias.o | ForEach-Object { $par = $_ -split '\|', 2; $par[0] + '|' + (Get-Contrario $par[1]) }) }
    if ($prm_Exigencias.total -ne 1 -or $prm_Exigencias.exige.Count -ne 1) { return @() }
    $par = $prm_Exigencias.exige[0] -split '\|', 2
    return @($par[0] + '|' + (Get-Contrario $par[1]))
}

# ---- Condiciones de cada trozo del cuerpo -----------------------------------------------------
# Recorre las sentencias de un cuerpo y devuelve tramos (inicio, fin, condiciones): las
# condiciones sobre los parámetros que se tienen que cumplir para que se ejecute ese trozo.
# Entiende if/then/else, begin/end, case, bucles y "if X then exit/Error" (lo que sigue, con X
# falsa). Lo que no entiende queda sin condición: nunca quita algo que se pueda ejecutar.

function Get-Palabra($s) {
    if ($s.p -ge $s.t.Count) { return '' }
    return $s.t[$s.p].Value.ToLower()
}

function Read-Expresion($s, $prm_Conds, [string[]]$prm_Fin) {
    $ini = $s.p
    $prof = 0
    while ($s.p -lt $s.t.Count) {
        $v = Get-Palabra $s
        if ($prof -eq 0 -and $prm_Fin -contains $v) { break }
        if ($v -eq '(' -or $v -eq '[') { $prof++ } elseif ($v -eq ')' -or $v -eq ']') { $prof-- }
        $s.p++
    }
    if ($s.p -gt $ini) {
        $desde = $s.t[$ini].Index
        $hasta = $s.t[$s.p - 1].Index + $s.t[$s.p - 1].Length
        $s.tramos.Add(@{ i = $desde; f = $hasta; c = $prm_Conds })
        return $s.texto.Substring($desde, $hasta - $desde)
    }
    return ''
}

function Skip-PuntoComa($s) { if ((Get-Palabra $s) -eq ';') { $s.p++ } }

function Read-Lista($s, $prm_Conds, [string[]]$prm_Fin) {
    $extra = @()
    while ($s.p -lt $s.t.Count -and -not ($prm_Fin -contains (Get-Palabra $s))) {
        $antes = $s.p
        $extra += @(Read-Sentencia $s ($prm_Conds + $extra))
        if ($s.p -eq $antes) { $s.p++ }
    }
}

# Devuelve las condiciones que se añaden a las sentencias siguientes del mismo bloque.
function Read-Sentencia($s, $prm_Conds) {
    $k = Get-Palabra $s
    switch ($k) {
        'begin' {
            # El bloque sale de la función si su última sentencia sale (exit o Error).
            $s.p++
            $s.sale = $false
            Read-Lista $s $prm_Conds @('end')
            $sale = $s.sale
            $s.p++
            Skip-PuntoComa $s
            $s.sale = $sale
            return @()
        }
        'if' {
            # Lo que sigue a un "if" cuya rama sale de la función solo se ejecuta con la rama
            # contraria: "if X then exit" o "if X then begin ...; exit; end" deja X falsa.
            $s.p++
            $ex = Get-Exigencias (Read-Expresion $s $prm_Conds @('then')) $s.mi
            $s.p++
            [void](Read-Sentencia $s ($prm_Conds + $ex.exige))
            $saleThen = $s.sale
            $neg = Get-Negacion $ex
            if ((Get-Palabra $s) -eq 'else') {
                $s.p++
                [void](Read-Sentencia $s ($prm_Conds + $neg))
                $saleElse = $s.sale
                $s.sale = $saleThen -and $saleElse
                if ($saleThen -and -not $saleElse) { return $neg }
                if ($saleElse -and -not $saleThen) { return $ex.exige }
                return @()
            }
            $s.sale = $false
            if ($saleThen) { return $neg }
            return @()
        }
        'case' {
            $s.p++
            [void](Read-Expresion $s $prm_Conds @('of'))
            $s.p++
            while ($s.p -lt $s.t.Count -and (Get-Palabra $s) -ne 'end') {
                if ((Get-Palabra $s) -eq 'else') { $s.p++; Read-Lista $s $prm_Conds @('end'); break }
                $antes = $s.p
                [void](Read-Expresion $s $prm_Conds @(':'))
                $s.p++
                [void](Read-Sentencia $s $prm_Conds)
                if ($s.p -eq $antes) { $s.p++ }
            }
            $s.p++
            Skip-PuntoComa $s
            $s.sale = $false
            return @()
        }
        { @('while', 'for', 'foreach', 'with') -contains $_ } {
            $s.p++
            [void](Read-Expresion $s $prm_Conds @('do'))
            $s.p++
            [void](Read-Sentencia $s $prm_Conds)
            $s.sale = $false
            return @()
        }
        'repeat' {
            $s.p++
            Read-Lista $s $prm_Conds @('until')
            $s.p++
            [void](Read-Expresion $s $prm_Conds @(';', 'end', 'else', 'until'))
            Skip-PuntoComa $s
            $s.sale = $false
            return @()
        }
    }
    $s.sale = @('exit', 'error') -contains $k
    [void](Read-Expresion $s $prm_Conds @(';', 'end', 'else', 'until'))
    Skip-PuntoComa $s
    return @()
}

function Get-Tramos([string]$prm_Texto, $prm_Miembro) {
    $s = @{ t = $reToken.Matches($prm_Texto); p = 0; texto = $prm_Texto; mi = $prm_Miembro; sale = $false; tramos = (New-Object System.Collections.Generic.List[object]) }
    Read-Lista $s @() @()
    return $s.tramos
}

# Las condiciones del trozo del cuerpo donde está prm_Posicion.
function Get-CondicionesEn($prm_Tramos, [int]$prm_Posicion) {
    foreach ($t in $prm_Tramos) { if ($prm_Posicion -ge $t.i -and $prm_Posicion -lt $t.f) { return $t.c } }
    return @()
}

function Get-Contrario([string]$op) {
    $simple = @{ v = 'l'; l = 'v'; t = 'f'; f = 't' }
    if ($simple.ContainsKey($op)) { return $simple[$op] }
    return @{ 'e:' = 'n:'; 'n:' = 'e:'; 'i:' = 'o:'; 'o:' = 'i:' }[$op.Substring(0, 2)] + $op.Substring(2)
}

function Remove-Parentesis([string]$s) {
    $s = $s.Trim()
    while ($s.StartsWith('(') -and $s.EndsWith(')')) {
        # Solo si el primer paréntesis cierra al final: "(a) and (b)" no se toca.
        $prof = 0; $cierra = -1
        for ($j = 0; $j -lt $s.Length; $j++) {
            if ($s[$j] -eq '(') { $prof++ } elseif ($s[$j] -eq ')') { $prof--; if ($prof -eq 0) { $cierra = $j; break } }
        }
        if ($cierra -ne $s.Length - 1) { break }
        $s = $s.Substring(1, $s.Length - 2).Trim()
    }
    return $s
}

function Add-Proc([hashtable]$prm_Mapa, [string]$prm_Nombre, [string]$prm_Id) {
    $k = $prm_Nombre.ToLower()
    if (-not $prm_Mapa.ContainsKey($k)) { $prm_Mapa[$k] = New-Object System.Collections.Generic.List[string] }
    $prm_Mapa[$k].Add($prm_Id)
}

# Arista a la función prm_Nombre de prm_Mapa. Con sobrecargas, a la que tiene tantos parámetros
# como argumentos lleva la llamada (prm_Llamada: la llamada desde su paréntesis); si ninguna
# encaja o no se sabe, a todas.
function Add-LlamadaProc($origen, [hashtable]$prm_Mapa, [string]$prm_Nombre, [string]$prm_Llamada) {
    $k = $prm_Nombre.ToLower()
    if (-not $prm_Mapa.ContainsKey($k)) { return $false }
    $ids = $prm_Mapa[$k]
    $argumentos = Get-ListaArgumentos $prm_Llamada
    if ($ids.Count -gt 1 -and $argumentos.completa) {
        $encajan = @($ids | Where-Object { $miembros[$_].params.Count -eq $argumentos.args.Count })
        if ($encajan.Count -gt 0) { $ids = $encajan }
    }
    foreach ($id in $ids) { Arista $origen $id 'llama' $null (Get-ValoresLlamada $miembros[$id] $argumentos) }
    return $true
}

function Get-Miembro($obj, [string]$id, [string]$nombre, [string]$clase, $ctx, [int]$linea) {
    if ($miembros.ContainsKey($id)) { return $miembros[$id] }
    # cuerpo y lineas van a la par: cada línea de código y su número en el fichero. pasos: lo que
    # hace, en orden (llamadas, avisos, escrituras). segmentos y ramas: los eventos de un control
    # de la PDA y sus botones, por la línea del cuerpo donde empiezan.
    $mi = @{ id = $id; obj = $obj; nombre = $nombre; clase = $clase; ctx = $ctx; linea = $linea; doc = $null; atributos = @(); cuerpo = (New-Object System.Collections.Generic.List[string]); locales = @{}; local = $false; params = @(); inestables = @{}
        etiquetas = @{}; lineas = (New-Object System.Collections.Generic.List[int]); pasos = (New-Object System.Collections.Generic.List[object])
        segmentos = (New-Object System.Collections.Generic.List[object]); ramas = (New-Object System.Collections.Generic.List[object]) }
    $miembros[$id] = $mi
    $listaMiembros.Add($mi)
    $obj.miembros.Add($id)
    return $mi
}

function New-Contexto($obj, $pila, [string]$cab, [int]$linea) {
    $m = [regex]::Match($cab.Trim().TrimEnd(';'), '^(\w+)\s*\((.*)\)\s*$')
    $argumentos = @()
    if ($m.Success) {
        $tipo = $m.Groups[1].Value.ToLower()
        $argumentos = @($m.Groups[2].Value -split ';' | ForEach-Object { Remove-Comillas $_ })
    }
    else { $tipo = (($cab.Trim() -split '\s+')[0]).ToLower() }
    $ctx = @{ tipo = $tipo; nombre = $null; fuente = $null; caption = $null; run = $null; drill = $null; calc = $null; miembro = $null; padres = $pila.ToArray(); disparadores = (New-Object System.Collections.Generic.List[string]) }
    if ($pila.Count -eq 0) { $ctx.tipo = 'objeto'; return $ctx }
    $esTabla = ($obj.tipo -eq 'table' -or $obj.tipo -eq 'tableextension')
    if ($tipo -eq 'field' -and $esTabla -and $argumentos.Count -gt 1) { $ctx.nombre = $argumentos[1] }
    elseif ($argumentos.Count -gt 0) { $ctx.nombre = $argumentos[0] }
    if ($argumentos.Count -gt 1) { $ctx.fuente = $argumentos[1] }
    switch ($tipo) {
        'action' { $obj.acciones.Add($ctx) }
        'field' {
            if ($esTabla) {
                $tabla = Get-TablaBase $obj
                if (-not $camposTabla.ContainsKey($tabla)) { $camposTabla[$tabla] = @{} }
                $camposTabla[$tabla][$ctx.nombre.ToLower()] = $ctx
            }
            else {
                $obj.campos.Add($ctx)
                # Campo que enseña lo que devuelve un procedimiento: field(X; Rec.Calculo()).
                if ($ctx.fuente -and $ctx.fuente.Contains('(')) {
                    $mi = Get-Miembro $obj ($obj.clave + '::field:' + $ctx.nombre.ToLower()) $ctx.nombre 'field' $ctx $linea
                    $ctx.miembro = $mi.id
                    $mi.cuerpo.Add($ctx.fuente)
            $mi.lineas.Add($linea)
                }
            }
        }
        'part' { $obj.partes.Add($ctx) }
        'dataitem' { $obj.dataitems.Add($ctx) }
    }
    return $ctx
}

function Read-Propiedad($obj, $pila, [string]$raw, [string]$c, [int]$linea) {
    $esObj = ($pila.Count -le 1)
    $dest = $null
    if ($pila.Count -gt 0) { $dest = $pila[$pila.Count - 1] }
    # El título de la ficha calculado por código: se lee como un trigger de la página.
    $m = [regex]::Match($c, '^DataCaptionExpression\s*=\s*(.+?);?$', $opc)
    if ($m.Success -and $esObj) {
        $mi = Get-Miembro $obj ($obj.clave + '::trigger:datacaptionexpression') 'DataCaptionExpression' 'trigger' $null $linea
        $mi.cuerpo.Add($m.Groups[1].Value + ';')
        $mi.lineas.Add($linea)
        return
    }
    $m = [regex]::Match($raw, '^\s*Caption\s*=\s*''((?:[^'']|'''')*)''', $opc)
    if ($m.Success) {
        $v = $m.Groups[1].Value.Replace("''", "'")
        if ($esObj) { $obj.caption = $v } else { $dest.caption = $v }
        return
    }
    $m = [regex]::Match($c, '^RunObject\s*=\s*(page|report|codeunit)\s+(?:"([^"]+)"|([\w\.]+))', $opc)
    if ($m.Success) { $dest.run = @{ tipo = $m.Groups[1].Value.ToLower(); nombre = (Get-NombreGrupo $m 2 3) }; return }
    $m = [regex]::Match($c, '^(DrillDownPageId|LookupPageId|CardPageId|SourceTable|RoleCenter)\s*=\s*(?:"([^"]+)"|([\w\.]+))', $opc)
    if ($m.Success) {
        $v = Get-NombreGrupo $m 2 3
        switch ($m.Groups[1].Value.ToLower()) {
            'drilldownpageid' { if ($esObj) { $obj.drill = $v } else { $dest.drill = $v } }
            'cardpageid' { $obj.ficha = $v }
            'sourcetable' { if ($esObj) { $obj.fuente = $v } }
            'rolecenter' { $obj.rolCenter = $v }
        }
        return
    }
    # Tablas que solo existen en memoria y páginas sobre una tabla temporal: no son lecturas ni
    # escrituras de la base de datos.
    if ($esObj -and $c -match '^(?i)TableType\s*=\s*Temporary') { $obj.temporal = $true; return }
    if ($esObj -and $c -match '^(?i)SourceTableTemporary\s*=\s*true') { $obj.fuenteTemporal = $true; return }
    $m = [regex]::Match($c, '^UsageCategory\s*=\s*(\w+)', $opc)
    if ($m.Success -and $esObj -and $m.Groups[1].Value -ne 'None') { $obj.uso = $m.Groups[1].Value; return }
    $m = [regex]::Match($c, '^PageType\s*=\s*(\w+)', $opc)
    if ($m.Success -and $esObj) { $obj.tipoPagina = $m.Groups[1].Value; return }
    $m = [regex]::Match($c, '^CalcFormula\s*=\s*\w+\s*\(\s*(?:"([^"]+)"|(\w+))', $opc)
    if ($m.Success -and $dest) { $dest.calc = Get-NombreGrupo $m 1 2 }
}

function New-Bloque($obj, $pila, $mp, [int]$linea, $doc, $atributos, [string]$c) {
    $decl = $mp.Groups[2].Value.ToLower()
    $nombre = Remove-Comillas $mp.Groups[3].Value
    $ctx = $null
    for ($k = $pila.Count - 1; $k -ge 1; $k--) {
        if (@('action', 'field', 'usercontrol', 'dataitem', 'requestpage') -contains $pila[$k].tipo) { $ctx = $pila[$k]; break }
    }
    $clase = 'trigger'
    if ($decl -eq 'procedure') {
        $id = $obj.clave + '::proc:' + $nombre.ToLower()
        $clase = 'proc'
        if (($atributos -join ' ') -match 'EventSubscriber') { $clase = 'suscriptor' }
        # Sobrecargas (mismo nombre, otros parámetros): cada una es su propio nodo.
        $n = 2
        while ($miembros.ContainsKey($id)) { $id = $obj.clave + '::proc:' + $nombre.ToLower() + '#' + $n; $n++ }
    }
    elseif ($ctx -and @('action', 'field', 'usercontrol') -contains $ctx.tipo) {
        $id = $obj.clave + '::' + $ctx.tipo + ':' + $ctx.nombre.ToLower()
        $ctx.miembro = $id
        $ctx.disparadores.Add($nombre)
        $trigger = $nombre
        # El nodo es la acción, el campo o el control; sus triggers van en "g".
        $nombre = $ctx.nombre
        $clase = $ctx.tipo
    }
    elseif ($ctx -and $ctx.tipo -eq 'dataitem') { $id = $obj.clave + '::trigger:' + $ctx.nombre.ToLower() + '.' + $nombre.ToLower(); $nombre = $ctx.nombre + ' - ' + $nombre }
    elseif ($ctx) { $id = $obj.clave + '::trigger:requestpage.' + $nombre.ToLower(); $nombre = 'RequestPage - ' + $nombre }
    else { $id = $obj.clave + '::trigger:' + $nombre.ToLower() }

    if ($miembros.ContainsKey($id)) { $mi = $miembros[$id] }
    else {
        $mi = Get-Miembro $obj $id $nombre $clase $ctx $linea
        $mi.doc = $doc
        $mi.atributos = @($atributos)
        $mi.local = ($mp.Groups[1].Value -eq 'local')
        if ($clase -eq 'proc' -or $clase -eq 'suscriptor') { Add-Proc $obj.procs $nombre $id }
        $esTabla = ($obj.tipo -eq 'table' -or $obj.tipo -eq 'tableextension')
        if ($esTabla) {
            $tabla = Get-TablaBase $obj
            if ($clase -eq 'proc') {
                if (-not $procsTabla.ContainsKey($tabla)) { $procsTabla[$tabla] = @{} }
                Add-Proc $procsTabla[$tabla] $nombre $id
            }
            elseif ($clase -eq 'trigger' -and -not $ctx) {
                if (-not $trigTabla.ContainsKey($tabla)) { $trigTabla[$tabla] = @{} }
                $trigTabla[$tabla][$nombre.ToLower()] = $id
            }
        }
    }
    # Un campo o un control junta varios triggers en un nodo: se apunta dónde empieza cada uno.
    if ($trigger) { $mi.segmentos.Add(@{ n = $trigger; d = $mi.cuerpo.Count }) }
    return @{ miembro = $mi; fase = 'firma'; firma = $c; prof = 0 }
}

# Una línea de un procedimiento o trigger. Devuelve true cuando se cierra su begin..end.
function Read-LineaCodigo($b, [string]$c, [string]$raw, [int]$linea) {
    if ($b.fase -eq 'firma') {
        if ($c -match '^(?i)var$') { $b.miembro.params = Read-Parametros $b.firma $b.miembro.locales; $b.fase = 'var'; return $false }
        if ($c -match '^(?i)begin\b') { $b.miembro.params = Read-Parametros $b.firma $b.miembro.locales; $b.fase = 'cuerpo' }
        else { $b.firma += ' ' + $c; return $false }
    }
    elseif ($b.fase -eq 'var') {
        if ($c -match '^(?i)begin\b') { $b.fase = 'cuerpo' }
        else { Read-Variable $c $b.miembro.locales; Read-Etiqueta $raw $b.miembro.etiquetas; return $false }
    }
    # Botones de la PDA: las ramas de un evento según el valor que manda la pantalla.
    $mr = $reRama.Match($raw)
    if ($mr.Success -and $b.miembro.clase -eq 'usercontrol') {
        $valor = @(1, 2, 3, 4 | ForEach-Object { $mr.Groups[$_] } | Where-Object { $_.Success })[0].Value
        $b.miembro.ramas.Add(@{ v = $valor; d = $b.miembro.cuerpo.Count })
    }
    $b.miembro.cuerpo.Add($c)
    $b.miembro.lineas.Add($linea)
    $s = [regex]::Replace($c, '"[^"]*"', '""')
    $b.prof += $reAbre.Matches($s).Count - $reCierra.Matches($s).Count
    return ($b.prof -le 0)
}

function Read-Fichero([string]$ruta) {
    $lineas = [IO.File]::ReadAllLines($ruta, [Text.Encoding]::UTF8)
    $script:enComentario = $false
    $obj = $null
    $pila = New-Object System.Collections.Generic.List[object]
    $doc = New-Object System.Collections.Generic.List[string]
    $atributos = New-Object System.Collections.Generic.List[string]
    $ultima = ''
    $bloque = $null
    $varsGlobales = $false
    for ($i = 0; $i -lt $lineas.Length; $i++) {
        $raw = $lineas[$i]
        $t = $raw.Trim()
        if (-not $bloque -and $t.StartsWith('///')) { $doc.Add($t.Substring(3).Trim()); continue }
        $c = (Limpiar $raw).Trim()
        if ($c -eq '') { continue }

        if ($bloque) {
            if (Read-LineaCodigo $bloque $c $raw ($i + 1)) { $bloque = $null }
            continue
        }
        if ($null -eq $obj) {
            $m = $reObjeto.Match($c)
            if ($m.Success) { $obj = New-Objeto $m $ruta ($i + 1) (Get-TextoDoc $doc) }
            if ($c -notmatch '^(?i)(namespace|using)\b') { $doc.Clear() }
            continue
        }
        if ($varsGlobales) {
            if ($c -match '^(?i)((local|internal|protected)\s+)?(procedure|trigger)\b' -or $c.StartsWith('[') -or $c -match '^\}') { $varsGlobales = $false }
            else { Read-Variable $c $obj.globales; Read-Etiqueta $raw $obj.etiquetas; continue }
        }
        if ($c -match '\{\s*\}\s*;?$') { $doc.Clear(); continue }
        if ($c.EndsWith('{')) {
            $cab = $ultima
            if ($c -ne '{') { $cab = $c.TrimEnd('{').Trim() }
            $pila.Add((New-Contexto $obj $pila $cab ($i + 1)))
            $ultima = ''
            continue
        }
        if ($c -match '^\}\s*;?$') {
            if ($pila.Count -gt 0) { $pila.RemoveAt($pila.Count - 1) }
            if ($pila.Count -eq 0) { $obj = $null }
            continue
        }
        if ($obj.omitir) { continue }
        if ($c -match '^(?i)(protected\s+)?var$') {
            if ($pila.Count -eq 1) { $varsGlobales = $true }
            continue
        }
        if ($c.StartsWith('[')) { $atributos.Add($t); continue }
        $mp = $reDeclaracion.Match($c)
        if ($mp.Success) {
            $bloque = New-Bloque $obj $pila $mp ($i + 1) (Get-TextoDoc $doc) $atributos $c
            $doc.Clear()
            $atributos.Clear()
            continue
        }
        Read-Propiedad $obj $pila $raw $c ($i + 1)
        $ultima = $c
        $doc.Clear()
    }
}

Get-ChildItem -Path $raizSGA -Recurse -Filter *.al |
    Where-Object { $_.FullName -notmatch '\\Otros\\' } |
    ForEach-Object { Read-Fichero $_.FullName }

# ---------------------------------------------------------------------------------------------
# Nodos y aristas
# ---------------------------------------------------------------------------------------------

function Nodo([string]$id, [string]$tipo, [string]$nombre) {
    if ($nodos.ContainsKey($id)) { return $nodos[$id] }
    $n = @{ id = $id; t = $tipo; n = $nombre; e = (New-Object System.Collections.Generic.List[object]); vistas = @{} }
    $nodos[$id] = $n
    return $n
}

# Una arista por destino, tipo y método; cada vez que se escribe esa llamada suma una variante
# con los valores fijos que pasa (prm_Valores) y las condiciones del trozo donde está.
function Arista($origen, [string]$destino, [string]$tipo, [string]$metodo, $prm_Valores) {
    if (-not $destino -or $origen.id -eq $destino) { return }
    $k = $destino + '|' + $tipo + '|' + $metodo
    $e = $origen.vistas[$k]
    if (-not $e) {
        $e = @{ a = $destino; k = $tipo; m = $metodo; x = (New-Object System.Collections.Generic.List[object]) }
        $origen.vistas[$k] = $e
        $origen.e.Add($e)
    }
    $e.x.Add(@{ v = $prm_Valores; c = @($script:condActual) })
    # Leyendo un cuerpo, la arista es también un paso de la función, en su sitio.
    if ($script:pasoLinea -ge 0 -and @('llama', 'dispara', 'ejecuta', 'escribe', 'abre') -contains $tipo -and $miembros.ContainsKey($origen.id)) {
        $paso = @{ k = $tipo; a = $destino }
        if ($tipo -eq 'escribe') { $paso.op = $script:opActual }
        if ($tipo -eq 'dispara') { $paso.op = $metodo }
        $paso.v = $prm_Valores
        Add-Paso $miembros[$origen.id] $paso
    }
}

# Un paso de prm_Miembro en la posición actual del cuerpo, con las condiciones de ese trozo.
function Add-Paso($prm_Miembro, $prm_Paso) {
    $prm_Paso.c = @($script:condActual)
    $prm_Paso.i = $script:pasoLinea
    $prm_Paso.p = $script:posActual
    $prm_Paso.l = $prm_Miembro.lineas[$script:pasoLinea]
    $prm_Miembro.pasos.Add($prm_Paso)
}

# Fija las condiciones y la línea del cuerpo de lo que está en prm_Posicion del texto unido.
function Set-Posicion($prm_Tramos, [int]$prm_Posicion) {
    $script:condActual = Get-CondicionesEn $prm_Tramos $prm_Posicion
    $n = 0
    while ($n + 1 -lt $script:inicios.Count -and $script:inicios[$n + 1] -le $prm_Posicion) { $n++ }
    $script:pasoLinea = $n
    $script:posActual = $prm_Posicion
}
$script:pasoLinea = -1
$script:opActual = $null
$script:inicios = $null
$script:condActual = @()
$script:miActual = $null
$script:paramRec = $null
$script:selfValor = $null

# El nodo de un objeto: el de SGA si existe; si no, uno de BC sin contenido.
function Get-RefObjeto([string]$tipo, [string]$nombre) {
    $k = Clave $tipo $nombre
    if ($objetos.ContainsKey($k)) { return $k }
    $id = 'bc:' + $k
    [void](Nodo $id ('bc-' + $tipo) $nombre)
    return $id
}

# Los textos con tildes los pone la plantilla (TEXTOS): PowerShell 5 lee este fichero como ANSI.
function Get-EtiquetaArea([string]$area) { return 'area:' + $area.ToLower() }

# Nodos de los objetos (antes que las aristas, para que Get-RefObjeto los encuentre).
foreach ($obj in $objetos.Values) {
    $n = Nodo $obj.clave $obj.tipo $obj.nombre
    $n.f = $obj.fichero; $n.l = $obj.linea; $n.d = $obj.doc; $n.c = $obj.caption; $n.num = $obj.num; $n.b = $obj.base; $n.pt = $obj.tipoPagina
    if ($obj.temporal) { $n.tmp = '1' }
}
foreach ($mi in $listaMiembros) {
    $n = Nodo $mi.id $mi.clase $mi.nombre
    $n.o = $mi.obj.clave; $n.f = $mi.obj.fichero; $n.l = $mi.linea; $n.d = $mi.doc
    if ($mi.clase -eq 'suscriptor') {
        $raw = $mi.atributos -join ' '
        $m = [regex]::Match($raw, 'ObjectType::(\w+)\s*,\s*\w+::(?:"([^"]+)"|(\w+))\s*,\s*''?(\w+)''?\s*,\s*''([^'']*)''', $opc)
        if ($m.Success) {
            $ev = $m.Groups[1].Value + ' ' + (Get-NombreGrupo $m 2 3) + ' - ' + $m.Groups[4].Value
            if ($m.Groups[5].Value) { $ev += ' (' + $m.Groups[5].Value + ')' }
            $n.ev = $ev
        }
    }
}

# Código: lo que llama cada procedimiento, trigger, acción y campo.
function Add-AccesoTabla($origen, [string]$tabla, [bool]$temporal, [string]$metodo, [string]$argumentos) {
    $tl = $tabla.ToLower()
    $kt = Clave 'table' $tabla
    if ($objetos.ContainsKey($kt) -and $objetos[$kt].temporal) { $temporal = $true }
    if ($metodo -eq 'validate') {
        $campo = Remove-Comillas (($argumentos -split ',')[0])
        if ($camposTabla.ContainsKey($tl) -and $camposTabla[$tl].ContainsKey($campo.ToLower())) {
            $ctx = $camposTabla[$tl][$campo.ToLower()]
            if ($ctx.miembro) { Arista $origen $ctx.miembro 'dispara' 'Validate' }
        }
        return
    }
    if ($escrituras -contains $metodo) {
        $trig = @{ insert = 'oninsert'; modify = 'onmodify'; modifyall = 'onmodify'; delete = 'ondelete'; deleteall = 'ondelete'; rename = 'onrename' }[$metodo]
        if ($argumentos -match '(?i)\btrue\s*$' -and $trigTabla.ContainsKey($tl) -and $trigTabla[$tl].ContainsKey($trig)) {
            Arista $origen $trigTabla[$tl][$trig] 'dispara' $metodo
        }
        $script:opActual = $metodo
        if (-not $temporal) { Add-AccesoReal $origen $tabla 'escribe' }
        return
    }
    if ($lecturas -contains $metodo -and -not $temporal) { Add-AccesoReal $origen $tabla 'lee' }
}

# Lectura o escritura de la tabla real. Si el registro es un parámetro (script:paramRec), solo
# cuando quien llama le pasa un registro que no es temporal: se añade esa condición.
function Add-AccesoReal($origen, [string]$tabla, [string]$tipo) {
    $antes = $script:condActual
    if ($script:paramRec) { $script:condActual = @($antes) + ($script:paramRec + '|r') }
    Arista $origen (Get-RefObjeto 'table' $tabla) $tipo $null
    $script:condActual = $antes
}

function Get-Argumentos([string]$linea, [int]$posParentesis) {
    $prof = 0
    for ($j = $posParentesis; $j -lt $linea.Length; $j++) {
        if ($linea[$j] -eq '(') { $prof++ }
        elseif ($linea[$j] -eq ')') { $prof--; if ($prof -eq 0) { return $linea.Substring($posParentesis + 1, $j - $posParentesis - 1) } }
    }
    return $linea.Substring($posParentesis + 1)
}

function Resolve-Llamada($origen, $tipo, [string]$metodo, [string]$argumentos) {
    $ml = $metodo.ToLower()
    $llamada = '(' + $argumentos + ')'
    switch ($tipo.tipo) {
        'table' {
            $tl = $tipo.nombre.ToLower()
            if ($procsTabla.ContainsKey($tl) -and (Add-LlamadaProc $origen $procsTabla[$tl] $metodo $llamada)) { return }
            Add-AccesoTabla $origen $tipo.nombre $tipo.temporal $ml $argumentos
        }
        'codeunit' {
            $k = Clave 'codeunit' $tipo.nombre
            if ($objetos.ContainsKey($k)) {
                if (-not (Add-LlamadaProc $origen $objetos[$k].procs $metodo $llamada) -and $ml -eq 'run') { Arista $origen $k 'ejecuta' $null }
            }
            else { Arista $origen (Get-RefObjeto 'codeunit' $tipo.nombre) 'llama' $metodo }
        }
        { $_ -eq 'page' -or $_ -eq 'report' } {
            $k = Clave $tipo.tipo $tipo.nombre
            $hecho = $objetos.ContainsKey($k) -and (Add-LlamadaProc $origen $objetos[$k].procs $metodo $llamada)
            if (-not $hecho -and ($ml -eq 'run' -or $ml -eq 'runmodal')) { Arista $origen (Get-RefObjeto $tipo.tipo $tipo.nombre) 'abre' $null }
        }
    }
}

foreach ($mi in $listaMiembros) {
    $origen = $nodos[$mi.id]
    $obj = $mi.obj
    $esTabla = ($obj.tipo -eq 'table' -or $obj.tipo -eq 'tableextension')
    $rec = $null
    if ($esTabla) { $rec = @{ tipo = 'table'; nombre = (Get-TablaBase $obj); temporal = $false } }
    elseif ($mi.ctx -and $mi.ctx.tipo -eq 'dataitem' -and $mi.ctx.fuente) { $rec = @{ tipo = 'table'; nombre = $mi.ctx.fuente; temporal = $false } }
    elseif ($obj.tipo -eq 'page' -and $obj.fuente) { $rec = @{ tipo = 'table'; nombre = $obj.fuente; temporal = $obj.fuenteTemporal } }
    $propios = $obj.procs
    if ($esTabla -and $procsTabla.ContainsKey((Get-TablaBase $obj))) { $propios = $procsTabla[(Get-TablaBase $obj)] }

    # El cuerpo entero en un texto: las llamadas que siguen en otra línea se leen completas, y
    # cada una lleva las condiciones del trozo del cuerpo donde está.
    $script:miActual = $mi
    $linea = $mi.cuerpo -join ' '
    $tramos = Get-Tramos $linea $mi
    # Dónde empieza cada línea del cuerpo en el texto unido, para saber la línea de cada paso.
    $script:inicios = New-Object System.Collections.Generic.List[int]
    $p = 0
    foreach ($l in $mi.cuerpo) { $script:inicios.Add($p); $p += $l.Length + 1 }
    foreach ($m in $reAsignacion.Matches($linea)) {
        $v = $m.Groups[1].Value
        if (-not $v) { $v = $m.Groups[2].Value }
        $mi.inestables[$v.ToLower()] = $true
    }
    # Avisos (etiquetas Err/Qst/Msg propias o de su objeto) y campos obligatorios (TestField).
    foreach ($m in $reAviso.Matches($linea)) {
        $n = $m.Groups[1].Value.ToLower()
        $texto = $mi.etiquetas[$n]
        if (-not $texto) { $texto = $obj.etiquetas[$n] }
        if (-not $texto) { continue }
        Set-Posicion $tramos $m.Index
        Add-Paso $mi @{ k = 'aviso'; s = $m.Groups[2].Value.ToLower(); t = $texto }
    }
    foreach ($m in $reCampoObligatorio.Matches($linea)) {
        Set-Posicion $tramos $m.Index
        Add-Paso $mi @{ k = 'aviso'; s = 'campo'; t = (Remove-Comillas $m.Groups[1].Value) }
    }
    foreach ($m in $reRefObjeto.Matches($linea)) {
        Set-Posicion $tramos $m.Index
        $tipoRef = $m.Groups[1].Value.ToLower()
        $ref = Get-RefObjeto $tipoRef (Remove-Comillas $m.Groups[2].Value)
        if ($tipoRef -eq 'codeunit') { Arista $origen $ref 'ejecuta' $null } else { Arista $origen $ref 'abre' $null }
    }
    foreach ($m in $reLlamadaVar.Matches($linea)) {
        Set-Posicion $tramos $m.Index
        $var = (Remove-Comillas $m.Groups[1].Value).ToLower()
        $metodo = Remove-Comillas $m.Groups[2].Value
        $argumentos = Get-Argumentos $linea ($m.Index + $m.Length - 1)
        if ($var -eq 'this') { [void](Add-LlamadaProc $origen $propios $metodo ('(' + $argumentos + ')')); continue }
        $tipo = $null
        if ($mi.locales.ContainsKey($var)) { $tipo = $mi.locales[$var] }
        elseif ($obj.globales.ContainsKey($var)) { $tipo = $obj.globales[$var] }
        elseif (($var -eq 'rec' -or $var -eq 'xrec') -and $rec) { $tipo = $rec }
        # De qué registro se trata, para no contar como tabla real lo que se hace en una temporal:
        # un parámetro (lo dice quien llama), el propio registro de la tabla (_self) o una variable.
        $script:paramRec = $null
        $script:selfValor = $null
        if ($tipo -and $tipo.tipo -eq 'table') {
            if ((Get-PosParametro $mi $var) -ge 0) { $script:paramRec = $var; $script:selfValor = '@' + $var }
            elseif ($esTabla -and ($var -eq 'rec' -or $var -eq 'xrec')) { $script:paramRec = '_self'; $script:selfValor = '@_self' }
            elseif ($tipo.temporal) { $script:selfValor = 'k' }
            else { $script:selfValor = 'r' }
        }
        if ($tipo) { Resolve-Llamada $origen $tipo $metodo $argumentos }
        $script:paramRec = $null
        $script:selfValor = $null
    }
    # Procedimiento de una subpágina: CurrPage.Parte.Page.Procedimiento(...).
    foreach ($m in $reSubpagina.Matches($linea)) {
        Set-Posicion $tramos $m.Index
        $parte = Remove-Comillas $m.Groups[1].Value
        foreach ($ctx in $obj.partes) {
            if ($ctx.nombre -ne $parte -or -not $ctx.fuente) { continue }
            $k = Clave 'page' $ctx.fuente
            if ($objetos.ContainsKey($k)) {
                $llamada = '(' + (Get-Argumentos $linea ($m.Index + $m.Length - 1)) + ')'
                [void](Add-LlamadaProc $origen $objetos[$k].procs (Remove-Comillas $m.Groups[2].Value) $llamada)
            }
        }
    }
    foreach ($m in $reLlamadaSuelta.Matches($linea)) {
        Set-Posicion $tramos $m.Index
        $nombre = (Remove-Comillas $m.Groups[1].Value).ToLower()
        $llamada = '(' + (Get-Argumentos $linea ($m.Index + $m.Length - 1)) + ')'
        # En una tabla, lo que se llama sin variable va sobre el propio registro.
        if ($esTabla) { $script:paramRec = '_self'; $script:selfValor = '@_self' }
        if (Add-LlamadaProc $origen $propios $nombre $llamada) { }
        elseif ($esTabla -and ($nombre -eq 'validate' -or $lecturas -contains $nombre -or $escrituras -contains $nombre)) {
            Add-AccesoTabla $origen $rec.nombre $false $nombre (Get-Argumentos $linea ($m.Index + $m.Length - 1))
        }
        $script:paramRec = $null
        $script:selfValor = $null
    }
    # Los pasos en el orden en que están escritos.
    $ordenados = @($mi.pasos | Sort-Object { $_.p })
    $mi.pasos.Clear()
    foreach ($x in $ordenados) { $mi.pasos.Add($x) }
}
$script:condActual = @()
$script:pasoLinea = -1

# Estructura: lo que tiene cada objeto y los menús.
function New-NodoAccion($obj, $ctx) {
    $id = $ctx.miembro
    if (-not $id) { $id = $obj.clave + '::action:' + $ctx.nombre.ToLower() }
    $n = Nodo $id 'action' $ctx.nombre
    if ($ctx.caption) { $n.n = $ctx.caption }
    if (-not $n.o) { $n.o = $obj.clave; $n.f = $obj.fichero; $n.l = $obj.linea }
    if ($ctx.run) {
        if ($ctx.run.tipo -eq 'codeunit') { Arista $n (Get-RefObjeto 'codeunit' $ctx.run.nombre) 'ejecuta' $null }
        else { Arista $n (Get-RefObjeto $ctx.run.tipo $ctx.run.nombre) 'abre' $null }
    }
    return $n
}

foreach ($obj in @($objetos.Values)) {
    $n = $nodos[$obj.clave]
    $esPagina = ($obj.tipo -eq 'page' -or $obj.tipo -eq 'pageextension')
    $esTabla = ($obj.tipo -eq 'table' -or $obj.tipo -eq 'tableextension')

    if ($obj.tipo -eq 'profile' -and $obj.rolCenter) { Arista $n (Get-RefObjeto 'page' $obj.rolCenter) 'tiene' $null; continue }

    foreach ($id in $obj.miembros) {
        $mi = $miembros[$id]
        if ($mi.clase -eq 'trigger') { Arista $n $id 'tiene' $null }
    }
    foreach ($ctx in $obj.partes) { if ($ctx.fuente) { Arista $n (Get-RefObjeto 'page' $ctx.fuente) 'contiene' $null } }

    $esRolCenter = ($obj.tipoPagina -eq 'RoleCenter')
    foreach ($ctx in $obj.acciones) {
        if (-not $ctx.miembro -and -not $ctx.run) { continue }
        $na = New-NodoAccion $obj $ctx
        if ($esRolCenter) {
            $menu = $null
            for ($k = $ctx.padres.Count - 1; $k -ge 1; $k--) {
                $p = $ctx.padres[$k]
                if ($p.tipo -eq 'group' -and $p.caption) { $menu = $p.caption; break }
                if ($p.tipo -eq 'area') { $menu = Get-EtiquetaArea $p.nombre; break }
            }
            if (-not $menu) { $menu = 'Acciones' }
            $nm = Nodo ($obj.clave + '::menu:' + $menu.ToLower()) 'menu' $menu
            $nm.o = $obj.clave
            Arista $n $nm.id 'tiene' $null
            Arista $nm $na.id 'tiene' $null
        }
        else { Arista $n $na.id 'tiene' $null }
    }

    foreach ($ctx in $obj.campos) {
        $drill = $ctx.drill
        # Pila de un rol center sin DrillDownPageId: abre la página de la tabla que cuenta.
        if (-not $drill -and $obj.fuente -and $ctx.fuente -match '^Rec\.(?:"([^"]+)"|(\w+))') {
            $campo = $Matches[1]; if (-not $campo) { $campo = $Matches[2] }
            $tf = $obj.fuente.ToLower()
            if ($camposTabla.ContainsKey($tf) -and $camposTabla[$tf].ContainsKey($campo.ToLower())) {
                $cf = $camposTabla[$tf][$campo.ToLower()]
                if ($cf.calc -and $objetos.ContainsKey((Clave 'table' $cf.calc))) { $drill = $objetos[(Clave 'table' $cf.calc)].drill }
            }
        }
        if (-not $ctx.miembro -and -not $drill) { continue }
        $id = $ctx.miembro
        if (-not $id) { $id = $obj.clave + '::field:' + $ctx.nombre.ToLower() }
        $nf = Nodo $id 'field' $ctx.nombre
        if ($ctx.caption) { $nf.n = $ctx.caption }
        if (-not $nf.o) { $nf.o = $obj.clave; $nf.f = $obj.fichero; $nf.l = $obj.linea }
        if ($ctx.disparadores.Count -gt 0) { $nf.g = ($ctx.disparadores -join ', ') }
        if ($drill) { Arista $nf (Get-RefObjeto 'page' $drill) 'abre' $null }
        Arista $n $id 'tiene' $null
    }

    foreach ($id in $obj.miembros) {
        $mi = $miembros[$id]
        if ($mi.clase -eq 'usercontrol') {
            $nodos[$id].g = ($mi.ctx.disparadores -join ', ')
            Arista $n $id 'tiene' $null
        }
        if ($esTabla -and $mi.clase -eq 'field') {
            $nodos[$id].g = ($mi.ctx.disparadores -join ', ')
            if ($mi.ctx.caption) { $nodos[$id].n = $mi.ctx.caption }
            Arista $n $id 'tiene' $null
        }
    }
    if ($esPagina -and $obj.ficha) { Arista $n (Get-RefObjeto 'page' $obj.ficha) 'abre' $null }
    # La tabla de la pantalla, aunque sea temporal: sus triggers saltan al editar en la pantalla.
    if ($esPagina -and $obj.fuente) { Arista $n (Get-RefObjeto 'table' $obj.fuente) 'tabla' $null }
    if ($obj.tipo -eq 'report') { foreach ($ctx in $obj.dataitems) { if ($ctx.fuente) { Arista $n (Get-RefObjeto 'table' $ctx.fuente) 'lee' $null } } }
}

# Raíces: por dónde entra el usuario (o BC).
$raices = New-Object System.Collections.Generic.List[string]
$r = Nodo 'raiz:perfiles' 'raiz' 'raiz:perfiles'
$raices.Add($r.id)
foreach ($obj in ($objetos.Values | Where-Object { $_.tipo -eq 'profile' } | Sort-Object nombre)) { Arista $r $obj.clave 'tiene' $null }
$r = Nodo 'raiz:bc' 'raiz' 'raiz:bc'
$raices.Add($r.id)
foreach ($obj in ($objetos.Values | Where-Object { $_.tipo -eq 'pageextension' } | Sort-Object base)) { Arista $r $obj.clave 'tiene' $null }
$r = Nodo 'raiz:busqueda' 'raiz' 'raiz:busqueda'
$raices.Add($r.id)
foreach ($obj in ($objetos.Values | Where-Object { $_.uso } | Sort-Object { if ($_.caption) { $_.caption } else { $_.nombre } })) { Arista $r $obj.clave 'tiene' $null }
$r = Nodo 'raiz:eventos' 'raiz' 'raiz:eventos'
$raices.Add($r.id)
foreach ($mi in ($listaMiembros | Where-Object { $_.clase -eq 'suscriptor' })) { Arista $r $mi.id 'tiene' $null }

# Nombres a la vista: el caption del objeto, si lo tiene.
foreach ($obj in $objetos.Values) { if ($obj.caption -and $obj.tipo -ne 'profile') { $nodos[$obj.clave].c = $obj.caption } }

# ---------------------------------------------------------------------------------------------
# Salida
# ---------------------------------------------------------------------------------------------

function J([string]$s) {
    if ($null -eq $s) { return 'null' }
    $s = $s.Replace('\', '\\').Replace('"', '\"').Replace("`r", '').Replace("`n", '\n').Replace("`t", ' ')
    # Sin '<' en los datos: un "</script>" en un texto cerraría el bloque de datos del HTML.
    $s = $s.Replace([string][char]60, '\' + 'u003c')
    return '"' + $s + '"'
}

# Las variantes de una arista en JSON: [{"v":{posición destino: valor},"c":["posición|valor"]}],
# con los parámetros de la función que llama por su posición. Lo que depende de un parámetro que
# la función cambia no se sabe y se quita. $null si alguna variante queda sin nada: entonces la
# arista vale siempre y con cualquier valor.
# La clave de un parámetro en los datos: su posición, o 's' para el propio registro de la tabla.
function Get-ClaveParametro($prm_Miembro, [string]$prm_Nombre) {
    if ($prm_Nombre -eq '_self') { return 's' }
    return [string](Get-PosParametro $prm_Miembro $prm_Nombre)
}

# Una variante (valores que pasa y condiciones de quien llama) en JSON, con los parámetros por su
# posición. Lo que depende de un parámetro que la función cambia no se sabe y se quita. $null si
# no queda nada: entonces vale siempre y con cualquier valor.
function Get-Variante($x, $prm_Miembro) {
    $conds = @()
    foreach ($c in $x.c) {
        # Un "or" (o~p|op~p|op) se pasa entero o nada: si una parte no se sabe, no exige.
        $partes = @(($c -replace '^o~', '') -split '~')
        $claves = @()
        foreach ($parte in $partes) {
            $par = $parte -split '\|', 2
            if (-not $prm_Miembro -or $prm_Miembro.inestables.ContainsKey($par[0])) { $claves = $null; break }
            $claves += ((Get-ClaveParametro $prm_Miembro $par[0]) + '|' + $par[1])
        }
        if (-not $claves) { continue }
        if ($c.StartsWith('o~')) { $conds += (J ('o~' + ($claves -join '~'))) } else { $conds += (J $claves[0]) }
    }
    $vals = @()
    if ($x.v) {
        foreach ($pos in $x.v.Keys) {
            $val = $x.v[$pos]
            # '@nombre' y '#[!]nombre|lista' pasan a la posición del parámetro.
            $m = [regex]::Match($val, '^([@#]!?)(\w+)(.*)$')
            if ($m.Success) {
                $nombre = $m.Groups[2].Value
                if (-not $prm_Miembro -or $prm_Miembro.inestables.ContainsKey($nombre)) { continue }
                $val = $m.Groups[1].Value + (Get-ClaveParametro $prm_Miembro $nombre) + $m.Groups[3].Value
            }
            $vals += ((J $pos) + ':' + (J $val))
        }
    }
    if ($conds.Count -eq 0 -and $vals.Count -eq 0) { return $null }
    return '{"v":{' + ($vals -join ',') + '},"c":[' + ($conds -join ',') + ']}'
}

# Las variantes de una arista: [variante, ...], o $null si alguna vale siempre.
function Get-Variantes($prm_Arista, $prm_Miembro) {
    $salida = New-Object System.Collections.Generic.List[string]
    foreach ($x in $prm_Arista.x) {
        $t = Get-Variante $x $prm_Miembro
        if (-not $t) { return $null }
        if (-not $salida.Contains($t)) { $salida.Add($t) }
    }
    if ($salida.Count -eq 0) { return $null }
    return '[' + ($salida -join ',') + ']'
}

# Los pasos de una función en JSON: k = llama, dispara, ejecuta, escribe, abre o aviso; a = a qué;
# op = operación (escribir) o método (disparar); s y t = tipo y texto del aviso; l = línea del
# fichero; i = línea del cuerpo (para los botones de la PDA); x = variante.
function Get-Pasos($prm_Miembro) {
    $salida = @()
    foreach ($p in $prm_Miembro.pasos) {
        if ($p.a -and -not $nodos.ContainsKey($p.a)) { continue }
        $t = '{"k":' + (J $p.k) + ',"l":' + $p.l + ',"i":' + $p.i
        foreach ($c in @('a', 'op', 's', 't')) { if ($p[$c]) { $t += ',"' + $c + '":' + (J ([string]$p[$c])) } }
        $x = Get-Variante $p $prm_Miembro
        if ($x) { $t += ',"x":' + $x }
        $salida += ($t + '}')
    }
    return '[' + ($salida -join ',') + ']'
}

# Los textos de los botones de la PDA, por la acción que mandan: boton('ACEPTAR', clase, 'aceptar').
$botonesPDA = @{}
if (Test-Path $rutaAddinPDA) {
    $js = [IO.File]::ReadAllText($rutaAddinPDA, [Text.Encoding]::UTF8)
    foreach ($m in [regex]::Matches($js, 'boton\((.+?),\s*''[^'']*''\s*,\s*''([^'']+)''')) {
        $textos = @([regex]::Matches($m.Groups[1].Value, '''([^'']*[A-Za-z][^'']*)''') | ForEach-Object { $_.Groups[1].Value.Trim() })
        if ($textos.Count -gt 0) { $botonesPDA[$m.Groups[2].Value.ToLower()] = $textos -join ' / ' }
    }
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('{"raiz":').Append((J $raizSGA.Replace('\', '/'))).Append(',"fecha":').Append((J (Get-Date -Format 'dd/MM/yyyy HH:mm')))
[void]$sb.Append(',"raices":[').Append((($raices | ForEach-Object { J $_ }) -join ',')).Append('],"nodos":{')
$primero = $true
foreach ($n in $nodos.Values) {
    if (-not $primero) { [void]$sb.Append(',') }
    $primero = $false
    [void]$sb.Append((J $n.id)).Append(':{"t":').Append((J $n.t)).Append(',"n":').Append((J $n.n))
    foreach ($p in @('o', 'f', 'd', 'c', 'ev', 'g', 'b', 'num', 'pt', 'tmp')) { if ($n[$p]) { [void]$sb.Append(',"').Append($p).Append('":').Append((J ([string]$n[$p]))) } }
    if ($n.l) { [void]$sb.Append(',"l":').Append($n.l) }
    [void]$sb.Append(',"e":[')
    $mi = $miembros[$n.id]
    $aristas = @($n.e | Where-Object { $nodos.ContainsKey($_.a) } | ForEach-Object {
            $t = '{"a":' + (J $_.a) + ',"k":' + (J $_.k)
            if ($_.m) { $t += ',"m":' + (J $_.m) }
            $x = Get-Variantes $_ $mi
            if ($x) { $t += ',"x":' + $x }
            $t + '}'
        })
    [void]$sb.Append(($aristas -join ','))
    if ($mi -and $mi.pasos.Count -gt 0) { [void]$sb.Append('],"p":').Append((Get-Pasos $mi)) }
    else { [void]$sb.Append(']') }
    # Triggers de un campo o un control y botones de la PDA: dónde empieza cada uno en el cuerpo.
    if ($mi -and $mi.segmentos.Count -gt 1 -or ($mi -and $mi.ramas.Count -gt 0)) {
        [void]$sb.Append(',"sg":[').Append((($mi.segmentos | ForEach-Object { '{"n":' + (J $_.n) + ',"d":' + $_.d + '}' }) -join ',')).Append(']')
        [void]$sb.Append(',"rm":[').Append((($mi.ramas | ForEach-Object { '{"v":' + (J $_.v) + ',"d":' + $_.d + '}' }) -join ',')).Append(']')
    }
    [void]$sb.Append('}')
}
[void]$sb.Append('},"botones":{').Append((($botonesPDA.Keys | ForEach-Object { (J $_) + ':' + (J $botonesPDA[$_]) }) -join ',')).Append('}}')

$html = [IO.File]::ReadAllText($rutaPlantilla, [Text.Encoding]::UTF8).Replace('/*DATOS_MAPA*/null', $sb.ToString())
[IO.File]::WriteAllText($rutaSalida, $html, (New-Object System.Text.UTF8Encoding $false))
$html = [IO.File]::ReadAllText($rutaPlantillaAcciones, [Text.Encoding]::UTF8).Replace('/*DATOS_MAPA*/null', $sb.ToString())
[IO.File]::WriteAllText($rutaSalidaAcciones, $html, (New-Object System.Text.UTF8Encoding $false))
Write-Host ('Acciones generadas: ' + $rutaSalidaAcciones)

$porTipo = $nodos.Values | Group-Object { $_.t } | Sort-Object Name | ForEach-Object { $_.Name + ' ' + $_.Count }
Write-Host ('Mapa generado: ' + $rutaSalida)
Write-Host ('Nodos: ' + $nodos.Count + ' (' + ($porTipo -join ', ') + ')')
