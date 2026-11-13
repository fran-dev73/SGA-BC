# Convierte el manual de SGA (Markdown sencillo) a HTML (solo el cuerpo).
# Uso: awk -f md2html.awk manual.md manual.md > cuerpo.html   (dos pasadas: índice y contenido)
#
# Soporta: # ## ### ####, párrafos, listas "- " y "1. ", tablas con cabecera, "---" como
# separador, citas "> " (si empiezan por **[CAPTURA ...]** se pintan como hueco de captura),
# **negrita**, *cursiva*, `código`, [texto](enlace), y [[TOC]] para el índice.
# Las líneas de continuación de una lista no se admiten: cada elemento va en una sola línea.

function repl(s, from, to,    i, out) {
    out = ""
    while ((i = index(s, from)) > 0) {
        out = out substr(s, 1, i - 1) to
        s = substr(s, i + length(from))
    }
    return out s
}

function inline(s,    m, t, u) {
    s = repl(s, "&", "&amp;")
    s = repl(s, "<", "&lt;")
    s = repl(s, ">", "&gt;")
    while (match(s, /`[^`]+`/)) {
        t = substr(s, RSTART + 1, RLENGTH - 2)
        s = substr(s, 1, RSTART - 1) "<code>" t "</code>" substr(s, RSTART + RLENGTH)
    }
    while (match(s, /\*\*[^*]+\*\*/)) {
        t = substr(s, RSTART + 2, RLENGTH - 4)
        s = substr(s, 1, RSTART - 1) "<strong>" t "</strong>" substr(s, RSTART + RLENGTH)
    }
    while (match(s, /\*[^*]+\*/)) {
        t = substr(s, RSTART + 1, RLENGTH - 2)
        s = substr(s, 1, RSTART - 1) "<em>" t "</em>" substr(s, RSTART + RLENGTH)
    }
    while (match(s, /\[[^]]+\]\([^)]+\)/)) {
        m = substr(s, RSTART, RLENGTH)
        t = m; sub(/\]\(.*$/, "", t); t = substr(t, 2)
        u = m; sub(/^[^(]*\(/, "", u); sub(/\)$/, "", u)
        s = substr(s, 1, RSTART - 1) t substr(s, RSTART + RLENGTH)
    }
    return s
}

function flush_para() { if (para != "") { print "<p>" inline(para) "</p>"; para = "" } }
function close_list() { if (listType != "") { print "</" listType ">"; listType = "" } }
function close_table() { if (inTable) { print "</tbody></table>"; inTable = 0 } }
function close_quote() { if (inQuote) { print "</div>"; inQuote = 0 } }
function close_all() { flush_para(); close_list(); close_table(); close_quote() }

function celdas(L, tag,    arr, n, i, c, out) {
    n = split(L, arr, "|")
    out = ""
    for (i = 2; i < n; i++) {
        c = arr[i]
        gsub(/^ +| +$/, "", c)
        out = out "<" tag ">" inline(c) "</" tag ">"
    }
    return out
}

NR == FNR {
    if ($0 ~ /^## /) { idn++; nivel[idn] = 2; titulo[idn] = substr($0, 4) }
    else if ($0 ~ /^### /) { idn++; nivel[idn] = 3; titulo[idn] = substr($0, 5) }
    next
}

BEGIN { idn = 0; idx = 0; listType = ""; inTable = 0; inQuote = 0; para = "" }

{
    L = $0
    if (L == "[[TOC]]") {
        close_all()
        print "<nav class=\"indice\"><h2>Índice</h2><ol>"
        for (i = 1; i <= idn; i++) {
            if (nivel[i] == 2) {
                print "<li class=\"i2\"><a href=\"#s" i "\">" inline(titulo[i]) "</a></li>"
            } else {
                print "<li class=\"i3\"><a href=\"#s" i "\">" inline(titulo[i]) "</a></li>"
            }
        }
        print "</ol></nav>"
        next
    }

    if (L ~ /^>/) {
        flush_para(); close_list(); close_table()
        t = substr(L, 2); sub(/^ /, "", t)
        if (!inQuote) {
            clase = (t ~ /^\*\*\[CAPTURA/) ? "captura" : "aviso"
            print "<div class=\"" clase "\">"
            inQuote = 1
        }
        if (t != "") print "<p>" inline(t) "</p>"
        next
    }
    close_quote()

    if (L ~ /^\|/) {
        flush_para(); close_list()
        if (L ~ /^\|[-: |]+\|$/) { if (inTable) { print "</thead><tbody>" } ; next }
        if (!inTable) { print "<table><thead><tr>" celdas(L, "th") "</tr>"; inTable = 1; next }
        print "<tr>" celdas(L, "td") "</tr>"
        next
    }
    close_table()

    if (L ~ /^---+$/) { close_all(); print "<hr>"; next }

    if (L ~ /^#### /) { close_all(); print "<h4>" inline(substr(L, 6)) "</h4>"; next }
    if (L ~ /^### /) { close_all(); idx++; print "<h3 id=\"s" idx "\">" inline(substr(L, 5)) "</h3>"; next }
    if (L ~ /^## /) { close_all(); idx++; print "<h2 class=\"seccion\" id=\"s" idx "\">" inline(substr(L, 4)) "</h2>"; next }
    if (L ~ /^# /) { close_all(); print "<h1>" inline(substr(L, 3)) "</h1>"; next }

    if (L ~ /^- /) {
        flush_para()
        if (listType != "ul") { close_list(); print "<ul>"; listType = "ul" }
        print "<li>" inline(substr(L, 3)) "</li>"
        next
    }
    if (L ~ /^[0-9]+\. /) {
        flush_para()
        if (listType != "ol") { close_list(); print "<ol>"; listType = "ol" }
        t = L; sub(/^[0-9]+\. /, "", t)
        print "<li>" inline(t) "</li>"
        next
    }

    if (L ~ /^[ \t]*$/) { flush_para(); close_list(); next }

    close_list()
    if (para == "") para = L; else para = para " " L
}

END { close_all(); close_table() }
