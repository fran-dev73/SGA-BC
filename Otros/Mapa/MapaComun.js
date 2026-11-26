// Común al mapa (MapaSGA.html) y a Cómo funciona (ComoFuncionaSGA.html): los nombres de menús y
// triggers, y seguir las condiciones de cada llamada con los valores que llegan a cada función.

var TEXTOS = {
    'area:embedding': 'Barra de navegación', 'area:sections': 'Menús', 'area:processing': 'Acciones',
    'area:creation': 'Nuevo', 'area:reporting': 'Informes'
};
var TRIGGERS = {
    onopenpage: 'Al abrir la pantalla', onclosepage: 'Al cerrar', onqueryclosepage: 'Antes de cerrar',
    onaftergetrecord: 'Al leer cada línea', onaftergetcurrrecord: 'Al cambiar de línea', oninit: 'Al iniciar',
    onnewrecord: 'Al crear una línea', oninsertrecord: 'Al insertar', onmodifyrecord: 'Al modificar',
    ondeleterecord: 'Al borrar', onprereport: 'Antes del informe', onpostreport: 'Después del informe',
    oninitreport: 'Al iniciar el informe', onvalidate: 'al validar', onlookup: 'al buscar', ondrilldown: 'al pulsar la cifra',
    onassistedit: 'al pulsar …', onrun: 'Al ejecutar', datacaptionexpression: 'Título de la ficha'
};

// Valores conocidos de los parámetros de una función: { posición: 'v' (texto vacío),
// 'l' (texto con algo), 't', 'f' o 'e:x' (valor x de un enum) }. Una arista puede llevar
// variantes (x), una por cada sitio donde está escrita: c = condiciones sobre los parámetros
// de quien llama para que ese sitio se ejecute ("pos|condición", o "o~pos|cond~pos|cond" si basta
// una de varias), v = lo que pasa a los
// parámetros de la función llamada (un valor, '@pos' = el parámetro de quien llama, o
// '#[!]pos|x;y' = si ese parámetro está entre x, y). pasos devuelve, por cada variante que se
// puede ejecutar con ctx, los valores con que entra la función llamada; ninguno si no se ejecuta.
// 'r'/'k': el registro que se pasa es real o temporal (s = el propio registro de una tabla).
var CONTRARIO = { v: 'l', l: 'v', t: 'f', f: 't', r: 'k', k: 'r' };
function cumple(valor, cond) {
    if (valor === undefined) { return true; }
    if (CONTRARIO[cond]) { return valor !== CONTRARIO[cond]; }
    if (valor.indexOf('e:') !== 0) { return true; }
    var op = cond.substring(0, 2), lista = cond.substring(2).split(';'), esta = lista.indexOf(valor.substring(2)) >= 0;
    return (op === 'e:' || op === 'i:') ? esta : !esta;
}
function pasos(arista, ctx) {
    if (!arista.x) { return [{}]; }
    var res = [], unicos = {};
    arista.x.forEach(function (x) {
        // Cada condición "pos|cond" se tiene que poder cumplir; de un "o~pos|cond~pos|cond", basta una.
        function puede(c) { var p = c.indexOf('|'); return cumple(ctx[c.substring(0, p)], c.substring(p + 1)); }
        var posible = x.c.every(function (c) {
            return c.indexOf('o~') === 0 ? c.substring(2).split('~').some(puede) : puede(c);
        });
        if (!posible) { return; }
        var nuevo = {};
        Object.keys(x.v).forEach(function (pos) {
            var val = x.v[pos];
            if (val.charAt(0) === '@') { val = ctx[val.substring(1)]; }
            else if (val.charAt(0) === '#') {
                var neg = val.charAt(1) === '!', resto = val.substring(neg ? 2 : 1), p = resto.indexOf('|');
                var de = ctx[resto.substring(0, p)];
                val = undefined;
                if (de && de.indexOf('e:') === 0) { val = (cumple(de, 'i:' + resto.substring(p + 1)) !== neg) ? 't' : 'f'; }
            }
            if (val) { nuevo[pos] = val; }
        });
        var k = claveCtx(nuevo);
        if (!unicos[k]) { unicos[k] = true; res.push(nuevo); }
    });
    return res;
}
function claveCtx(ctx) { return Object.keys(ctx).sort().map(function (k) { return k + ctx[k]; }).join(','); }
