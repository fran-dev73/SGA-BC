$ErrorActionPreference = 'Stop'

$sourcePath = Join-Path $PSScriptRoot 'MANUAL_SGA.md'
$outputPath = Join-Path $PSScriptRoot 'MANUAL_SGA.pdf'
$edgePath = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'

if (-not (Test-Path $sourcePath)) { throw "No se encuentra el manual: $sourcePath" }
if (-not (Test-Path $edgePath)) { throw "No se encuentra Microsoft Edge: $edgePath" }

function Convert-InlineMarkdown([string]$text) {
    $html = [System.Net.WebUtility]::HtmlEncode($text)
    $html = [regex]::Replace($html, '`([^`]+)`', '<code>$1</code>')
    $html = [regex]::Replace($html, '\*\*(.+?)\*\*', '<strong>$1</strong>')
    $html = [regex]::Replace($html, '(?<!\*)\*([^*]+)\*(?!\*)', '<em>$1</em>')
    $html = [regex]::Replace($html, '\[([^\]]+)\]\(([^)]+)\)', '<a href="$2">$1</a>')
    return $html
}

function Convert-TableRow([string]$line, [string]$cellTag) {
    $cells = $line.Trim().Trim('|').Split('|')
    $result = '<tr>'
    foreach ($cell in $cells) {
        $result += "<$cellTag>$(Convert-InlineMarkdown $cell.Trim())</$cellTag>"
    }
    return "$result</tr>"
}

$lines = Get-Content -LiteralPath $sourcePath -Encoding UTF8
$body = [System.Text.StringBuilder]::new()
$index = 0

while ($index -lt $lines.Count) {
    $line = $lines[$index]
    if ([string]::IsNullOrWhiteSpace($line)) { $index++; continue }

    if ($line -match '^```') {
        $index++
        $code = [System.Text.StringBuilder]::new()
        while ($index -lt $lines.Count -and $lines[$index] -notmatch '^```') {
            [void]$code.AppendLine([System.Net.WebUtility]::HtmlEncode($lines[$index]))
            $index++
        }
        if ($index -lt $lines.Count) { $index++ }
        [void]$body.AppendLine("<pre><code>$($code.ToString())</code></pre>")
        continue
    }

    if ($line -match '^\s*\|.*\|\s*$' -and $index + 1 -lt $lines.Count -and $lines[$index + 1] -match '^\s*\|?\s*:?-{2,}') {
        [void]$body.AppendLine('<table>')
        [void]$body.AppendLine((Convert-TableRow $line 'th'))
        $index += 2
        while ($index -lt $lines.Count -and $lines[$index] -match '^\s*\|.*\|\s*$') {
            [void]$body.AppendLine((Convert-TableRow $lines[$index] 'td'))
            $index++
        }
        [void]$body.AppendLine('</table>')
        continue
    }

    if ($line -match '^(#{1,6})\s+(.+)$') {
        $level = $Matches[1].Length
        $heading = Convert-InlineMarkdown $Matches[2]
        [void]$body.AppendLine("<h$level>$heading</h$level>")
        $index++
        continue
    }

    if ($line -match '^\s*([-*+]\s+|\d+\.\s+)') {
        $ordered = $line -match '^\s*\d+\.\s+'
        $tag = if ($ordered) { 'ol' } else { 'ul' }
        [void]$body.AppendLine("<$tag>")
        while ($index -lt $lines.Count -and $lines[$index] -match '^\s*([-*+]\s+|\d+\.\s+)(.+)$') {
            [void]$body.AppendLine("<li>$(Convert-InlineMarkdown $Matches[2])</li>")
            $index++
        }
        [void]$body.AppendLine("</$tag>")
        continue
    }

    if ($line -match '^\s*&gt;|^\s*>') {
        $quote = [System.Text.StringBuilder]::new()
        while ($index -lt $lines.Count -and $lines[$index] -match '^\s*>\s?(.*)$') {
            [void]$quote.AppendLine("$(Convert-InlineMarkdown $Matches[1])<br>")
            $index++
        }
        [void]$body.AppendLine("<blockquote>$($quote.ToString())</blockquote>")
        continue
    }

    if ($line -match '^\s*(---+|___+|\*\*\*+)\s*$') {
        [void]$body.AppendLine('<hr>')
        $index++
        continue
    }

    $paragraph = [System.Collections.Generic.List[string]]::new()
    while ($index -lt $lines.Count -and -not [string]::IsNullOrWhiteSpace($lines[$index]) -and $lines[$index] -notmatch '^(#{1,6}\s|```|\s*\|.*\|\s*$|\s*([-*+]\s+|\d+\.\s+)|\s*>)') {
        $paragraph.Add($lines[$index].Trim())
        $index++
    }
    if ($paragraph.Count -gt 0) {
        [void]$body.AppendLine("<p>$(Convert-InlineMarkdown ($paragraph -join ' '))</p>")
    } else {
        $index++
    }
}

$coverDiagram = @'
<svg class="flow" viewBox="0 0 900 215" role="img" aria-label="Flujo diario: registrar entrada, ubicar en SGA, preparar picking y registrar envío">
  <defs><marker id="arrow" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L0,6 L9,3 z" fill="#52636b"/></marker></defs>
  <g font-family="Segoe UI, sans-serif" text-anchor="middle">
    <rect x="18" y="35" width="185" height="84" rx="8" fill="#e9f1f3" stroke="#b6c8ce"/><text x="110" y="68" font-size="17" font-weight="700" fill="#18313b">Entrada en BC</text><text x="110" y="94" font-size="13" fill="#43565e">Compra o ensamblado</text>
    <path d="M207 77 H247" stroke="#52636b" stroke-width="3" marker-end="url(#arrow)"/>
    <rect x="260" y="35" width="185" height="84" rx="8" fill="#e7f2eb" stroke="#b8d2bf"/><text x="352" y="68" font-size="17" font-weight="700" fill="#234b32">Ubicar en SGA</text><text x="352" y="94" font-size="13" fill="#43565e">Proponer y confirmar</text>
    <path d="M449 77 H489" stroke="#52636b" stroke-width="3" marker-end="url(#arrow)"/>
    <rect x="502" y="35" width="185" height="84" rx="8" fill="#fbf1db" stroke="#e3d2a7"/><text x="594" y="68" font-size="17" font-weight="700" fill="#674e1c">Picking</text><text x="594" y="94" font-size="13" fill="#43565e">Recoger y confirmar</text>
    <path d="M691 77 H731" stroke="#52636b" stroke-width="3" marker-end="url(#arrow)"/>
    <rect x="744" y="35" width="140" height="84" rx="8" fill="#f1e9e5" stroke="#d5c3b9"/><text x="814" y="68" font-size="17" font-weight="700" fill="#573b2f">Envío BC</text><text x="814" y="94" font-size="13" fill="#43565e">Registrar pedido</text>
    <path d="M110 151 V174 H814 V151" fill="none" stroke="#52727a" stroke-width="2" stroke-dasharray="6 5" marker-end="url(#arrow)"/><rect x="345" y="157" width="235" height="34" rx="17" fill="#fff"/><text x="462" y="179" font-size="14" font-weight="700" fill="#31535d">Conciliar SGA contra BC</text>
  </g>
</svg>
'@

$layerDiagram = @'
<svg class="layers" viewBox="0 0 850 150" role="img" aria-label="BC mantiene el stock global; SGA detalla su distribución por ubicación, lote y caducidad">
  <defs><marker id="arrow2" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L0,6 L9,3 z" fill="#52636b"/></marker></defs>
  <g font-family="Segoe UI, sans-serif" text-anchor="middle">
    <rect x="22" y="27" width="320" height="92" rx="8" fill="#e9f1f3" stroke="#b6c8ce"/><text x="182" y="62" font-size="20" font-weight="700" fill="#18313b">Business Central</text><text x="182" y="91" font-size="14" fill="#43565e">Stock global y registro contable</text>
    <path d="M355 73 H487" stroke="#52636b" stroke-width="3" marker-start="url(#arrow2)" marker-end="url(#arrow2)"/><text x="421" y="53" font-size="13" fill="#43565e">Conciliación</text>
    <rect x="500" y="27" width="328" height="92" rx="8" fill="#e7f2eb" stroke="#b8d2bf"/><text x="664" y="62" font-size="20" font-weight="700" fill="#234b32">SGA</text><text x="664" y="91" font-size="14" fill="#43565e">Ubicación · producto · lote · caducidad</text>
  </g>
</svg>
'@

$html = @"
<!doctype html>
<html lang="es"><head><meta charset="utf-8"><title>Manual SGA — Gestión de Ubicaciones</title>
<style>
@page { size: A4; margin: 17mm 16mm 18mm; }
* { box-sizing: border-box; }
body { color: #26363c; font-family: 'Segoe UI', Arial, sans-serif; font-size: 10pt; line-height: 1.48; }
h1,h2,h3,h4 { color: #18313b; line-height: 1.2; page-break-after: avoid; }
h1 { font-size: 25pt; margin: 0 0 12pt; }
h2 { font-size: 17pt; margin: 24pt 0 9pt; padding-bottom: 5pt; border-bottom: 1px solid #d5e0e3; }
h3 { font-size: 13pt; margin: 17pt 0 7pt; color: #31535d; }
h4 { font-size: 11pt; margin: 13pt 0 5pt; }
p { margin: 5pt 0 9pt; orphans: 3; widows: 3; }
ul,ol { margin: 5pt 0 10pt; padding-left: 21pt; }
li { margin: 2pt 0; padding-left: 2pt; }
strong { color: #203d46; }
a { color: #276574; text-decoration: none; }
code { font-family: Consolas, 'Courier New', monospace; background: #eef2f3; color: #294852; padding: 1px 3px; font-size: 9pt; }
pre { white-space: pre-wrap; overflow-wrap: anywhere; background: #f2f5f5; border-left: 3px solid #52727a; padding: 9pt 11pt; font-size: 8.5pt; page-break-inside: avoid; }
pre code { background: transparent; padding: 0; }
table { border-collapse: collapse; width: 100%; margin: 9pt 0 12pt; font-size: 9pt; page-break-inside: avoid; }
th { background: #e9f1f3; color: #18313b; text-align: left; font-weight: 700; }
th,td { border: 1px solid #d3dddf; padding: 5pt 6pt; vertical-align: top; }
tr:nth-child(even) td { background: #f8faf9; }
blockquote { margin: 8pt 0; padding: 6pt 10pt; border-left: 3px solid #9aafab; color: #46595d; background: #f5f7f5; }
hr { border: 0; border-top: 1px solid #d5e0e3; margin: 15pt 0; }
.cover { page-break-after: always; min-height: 245mm; display: flex; flex-direction: column; justify-content: center; }
.eyebrow { color: #54717a; font-size: 10pt; font-weight: 700; text-transform: uppercase; margin-bottom: 8pt; }
.cover h1 { font-size: 34pt; margin-bottom: 8pt; }
.subtitle { font-size: 15pt; color: #52636b; margin: 0 0 20pt; }
.rule { width: 55pt; height: 4pt; background: #658f79; margin: 4pt 0 20pt; }
.introbox { border-left: 4px solid #658f79; background: #f2f6f3; padding: 11pt 14pt; margin: 3pt 0 15pt; }
.diagram-title { color: #31535d; font-size: 11pt; font-weight: 700; margin: 13pt 0 3pt; }
.flow,.layers { width: 100%; height: auto; }
.cover-note { color: #52636b; font-size: 9pt; margin-top: 13pt; }
.body-content h1 { font-size: 19pt; margin-top: 0; }
</style></head><body>
<section class="cover">
  <div class="eyebrow">Guía de usuario · Business Central</div>
  <h1>Manual SGA</h1><p class="subtitle">Gestión de ubicaciones y operaciones de almacén</p><div class="rule"></div>
  <div class="introbox">SGA organiza el stock por ubicación, producto, lote y caducidad. Business Central sigue siendo la referencia del stock global; SGA aporta el detalle físico y permite detectar diferencias mediante conciliación.</div>
  <div class="diagram-title">El circuito habitual</div>
  $coverDiagram
  <div class="diagram-title">Dos vistas coordinadas del inventario</div>
  $layerDiagram
  <p class="cover-note">La mercancía se registra en BC y se ubica en SGA; el picking descuenta el contenido ubicado y devuelve al pedido las cantidades y lotes recogidos.</p>
</section>
<main class="body-content">$($body.ToString())</main>
</body></html>
"@

$tempDirectory = Join-Path $env:TEMP ('sga-pdf-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDirectory | Out-Null
$htmlPath = Join-Path $tempDirectory 'manual.html'
$profilePath = Join-Path $tempDirectory 'edge-profile'
try {
    [System.IO.File]::WriteAllText($htmlPath, $html, [System.Text.UTF8Encoding]::new($false))
    $htmlUri = ([System.Uri]::new($htmlPath)).AbsoluteUri
    $arguments = @('--headless', '--disable-gpu', '--no-first-run', '--no-pdf-header-footer', "--user-data-dir=$profilePath", "--print-to-pdf=$outputPath", $htmlUri)
    $process = Start-Process -FilePath $edgePath -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
    if (-not (Test-Path $outputPath) -or (Get-Item $outputPath).Length -lt 10000) {
        throw "Edge no generó un PDF válido (código de salida: $($process.ExitCode))."
    }
    Write-Output "PDF generado: $outputPath"
    Write-Output "Tamaño: $([math]::Round((Get-Item $outputPath).Length / 1KB)) KB"
}
finally {
    Remove-Item -LiteralPath $tempDirectory -Recurse -Force -ErrorAction SilentlyContinue
}