#!/bin/bash
# Genera el manual de SGA por roles en HTML y PDF a partir de Manual_Usuario_SGA_por_roles.md.
# Requiere Microsoft Edge (para el PDF). Ejecutar desde cualquier carpeta:
#   bash generar_manual.sh
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
BASE="Manual_Usuario_SGA_por_roles"
MD="$DIR/$BASE.md"
HTML="$DIR/$BASE.html"
PDF="$DIR/$BASE.pdf"
EDGE="/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"

CUERPO="$(mktemp)"
awk -f "$DIR/md2html.awk" "$MD" "$MD" > "$CUERPO"

cat > "$HTML" <<'CABECERA'
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>Manual de usuario de SGA</title>
<style>
  @page { size: A4; margin: 18mm 16mm 18mm 16mm; }
  body { font-family: "Segoe UI", Arial, sans-serif; font-size: 10.5pt; line-height: 1.45; color: #222; max-width: 180mm; margin: 0 auto; }
  h1 { font-size: 24pt; color: #0b3d6e; margin: 0 0 6mm 0; }
  h2.seccion { font-size: 16pt; color: #0b3d6e; border-bottom: 2px solid #0b3d6e; padding-bottom: 2mm; margin-top: 8mm; page-break-before: always; }
  h2.seccion:first-of-type { page-break-before: auto; }
  h3 { font-size: 12.5pt; color: #174f86; margin: 6mm 0 2mm 0; page-break-after: avoid; }
  h4 { font-size: 11pt; color: #174f86; margin: 4mm 0 1mm 0; page-break-after: avoid; }
  p { margin: 2mm 0; }
  table { border-collapse: collapse; width: 100%; margin: 3mm 0; font-size: 9.5pt; page-break-inside: auto; }
  tr { page-break-inside: avoid; }
  th, td { border: 1px solid #b8c4d0; padding: 1.5mm 2mm; vertical-align: top; text-align: left; }
  th { background: #e7eef6; color: #0b3d6e; }
  code { font-family: Consolas, monospace; font-size: 9pt; background: #f1f3f5; padding: 0 1mm; border-radius: 2px; }
  ul, ol { margin: 1.5mm 0 2.5mm 6mm; padding: 0; }
  li { margin: 0.8mm 0; }
  hr { border: 0; border-top: 1px solid #ccc; margin: 5mm 0; }
  .captura { border: 2px dashed #7a8ea3; background: #f5f8fb; padding: 4mm; margin: 4mm 0; min-height: 40mm; page-break-inside: avoid; }
  .captura p:first-child { color: #0b3d6e; }
  .captura p:last-child { color: #555; font-size: 9.5pt; }
  .aviso { border-left: 4px solid #d98c00; background: #fff8e8; padding: 2mm 4mm; margin: 3mm 0; page-break-inside: avoid; }
  .indice { page-break-after: always; }
  .indice h2 { font-size: 16pt; color: #0b3d6e; }
  .indice ol { list-style: none; margin-left: 0; }
  .indice li { margin: 1mm 0; }
  .indice li.i2 { font-weight: bold; margin-top: 2mm; }
  .indice li.i3 { margin-left: 6mm; font-size: 9.5pt; }
  .indice a { color: #174f86; text-decoration: none; }
</style>
</head>
<body>
CABECERA

cat "$CUERPO" >> "$HTML"
printf '</body>\n</html>\n' >> "$HTML"
rm -f "$CUERPO"

# PDF con Edge (sin cabecera ni pie del navegador)
URL="file:///$(cygpath -m "$HTML")"
RUTA_PDF="$(cygpath -m "$PDF")"
rm -f "$PDF"
"$EDGE" --headless --disable-gpu --no-pdf-header-footer --print-to-pdf="$RUTA_PDF" "$URL" > /dev/null 2>&1
# Edge puede devolver el control antes de escribir el fichero: espera a que exista.
for i in $(seq 1 60); do
  if [ -s "$PDF" ]; then sleep 2; break; fi
  sleep 1
done
[ -s "$PDF" ] || { echo "No se ha generado el PDF"; exit 1; }
echo "HTML: $HTML"
echo "PDF:  $PDF"
