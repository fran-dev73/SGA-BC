// Mapa del almacén para SGA: vista 3D, planta y frente de pasillo.
//
// Todo se dibuja sobre un canvas 2D. No usa ninguna librería externa a propósito: la política
// de contenido de Business Central bloquea los recursos de fuera, así que una dependencia de
// CDN dejaría el panel en blanco.
//
// Ejes del almacén: pasillo (profundidad, u.e), estantería (anchura, u.c) y altura
// (vertical, u.a), sacados del código pasillo-estantería-altura (101-15-03). Las alturas
// pueden saltar (00, 10, 20…): se dibujan por su nivel (u.n, 1 = la más baja de todo el
// almacén) y se rotulan con su número.
//
// Tres vistas sobre los mismos datos:
//   - 3D: cada ubicación es un cubo en proyección isométrica. Da la idea de conjunto.
//   - Planta: el almacén visto desde arriba, una fila por pasillo y una columna por estantería;
//     cada hueco se parte en franjas, una por altura (la de abajo es la más baja).
//   - Frente: un pasillo de frente, estanterías por alturas, con casillas grandes en las que
//     se lee el producto. Es la vista de trabajo.
// En las tres se colorea por el criterio elegido (estado, posición ABC del hueco, rotación ABC
// del producto o caducidad),
// se busca un producto o una ubicación y se traslada arrastrando de una ubicación a otra.
//
// Los pasillos de la 3D se dibujan separados entre sí, como en un almacén real.
// Un bloque macizo esconde sus cubos interiores y no hay ángulo desde el que verlos.

var SGA3D = (function () {
    'use strict';

    var canvas = null;
    var ctx = null;
    var ubicaciones = [];   // datos crudos que llegan de AL
    var vista = '3d';       // '3d', 'planta' o 'frente'
    var colorear = 'estado'; // 'estado', 'posicion', 'abc' o 'caducidad'
    var busqueda = '';      // texto buscado, en mayúsculas; vacío = no se busca

    // Vista 3D
    var cubos = [];         // cubos ya proyectados, ordenados de atrás a adelante
    var rotulos = [];       // carteles de pasillo, proyectados igual que los cubos
    var angulo = 0;         // giro libre alrededor del eje vertical, en radianes
    var escala = 1;
    var panX = 0;
    var panY = 0;
    var separarPasillos = true;

    // Vistas planas (planta y frente): rectángulos en coordenadas propias, con su zoom y su
    // desplazamiento, aparte de los de la 3D para que cada vista conserve el suyo.
    var rects = [];
    var rotulos2 = [];
    var escala2 = 1;
    var pan2X = 0;
    var pan2Y = 0;

    var modoArrastre = '';  // 'girar', 'mover', 'coger' o 'trasladar'
    var ultimoX = 0;
    var ultimoY = 0;
    var hover = null;
    var seHaMovido = false;
    var verEtiquetas = true;
    var pasilloActivo = '';  // pasillo elegido; vacío = todos
    var pasillos = [];       // pasillos presentes en los datos, ordenados

    // Traslado arrastrando y soltando: se coge una ubicación con contenido y se suelta sobre
    // otra. El lienzo solo avisa a AL (TrasladoSolicitado), que registra el traslado.
    var origenTraslado = null;   // elemento del que sale la mercancía
    var destinoTraslado = null;  // elemento sobre el que está el ratón al arrastrar
    var destinoOtraZona = null;  // ubicación de otra zona bajo el ratón: no se puede soltar
    var ratonX = 0;
    var ratonY = 0;
    var inicioX = 0;             // dónde se pulsó, para distinguir un clic de un arrastre
    var inicioY = 0;

    // Píxeles que hay que mover el ratón con el botón pulsado para que sea arrastrar y no
    // un clic: con menos, al soltar se abre el contenido como siempre.
    var UMBRAL_ARRASTRE = 5;

    var AYUDA = {
        '3d': 'Arrastre una ubicación con contenido a otra para trasladarlo · arrastre fuera de ellas (o Alt+arrastre) para girar · Mayús+arrastre para mover · doble clic para aislar su pasillo · clic derecho para vaciar · rueda para acercar',
        'planta': 'Cada hueco se parte en sus alturas (abajo la más baja) · doble clic en un pasillo para verlo de frente · arrastre una ubicación con contenido a otra para trasladarlo · arrastre fuera para mover · clic derecho para vaciar · rueda para acercar',
        'frente': 'Arrastre una ubicación con contenido a otra para trasladarlo · arrastre fuera para mover · clic derecho para vaciar · rueda para acercar · < > cambia de pasillo'
    };

    // Ancho y alto de la base del cubo en pantalla, y altura del bloque.
    var ANCHO = 22;
    var ALTO = 11;
    var GRUESO = 16;

    // Cuánto se separan las estanterías entre sí en la 3D. 1 = pegadas (bloque macizo).
    var SEPARACION = 2.6;

    // Límites del zoom. El máximo es alto a propósito: un pasillo aislado se encuadra a lo
    // que haga falta para que sus huecos se vean grandes y se lea lo que hay dentro.
    var ESCALA_MIN = 0.15;
    var ESCALA_MAX = 12;
    var ESCALA2_MIN = 0.2;
    var ESCALA2_MAX = 6;

    // A partir de este ancho de cubo (en píxeles) se escribe también el producto encima.
    var ANCHO_PARA_PRODUCTO = 34;

    // Medidas de las vistas planas, en sus unidades (a escala 1, píxeles).
    var FRENTE_ANCHO = 104;   // casilla de una ubicación en el frente
    var FRENTE_ALTO = 74;
    var FRENTE_HUECO = 6;     // entre casillas
    var PLANTA_ANCHO = 34;    // hueco (columna) en la planta, con todas sus alturas
    var PLANTA_ALTO = 48;
    var PLANTA_HUECO = 4;     // entre columnas
    var PLANTA_PASILLO = 30;  // entre estanterías

    // Colores por estado, en el mismo orden que manda AL:
    // 0 vacía, 1 parcial, 2 llena, 3 bloqueada, 4 con contenido que no se puede medir
    // (sin capacidad declarada, o un producto sin palé o caja en su ficha).
    // 5 sobrepasada no lo manda AL (para AL es llena): lo decide colorDe con el % por encima
    // de 100, para que no se confunda una ubicación justa con una que no cabe.
    // libreIzq / libreDer: el mismo color, claro, para la parte libre de los laterales. Así el
    // color se ve en todo el cubo y el tono oscuro dice hasta dónde está lleno.
    var PALETA = [
        { techo: '#d9dde3', izq: '#aeb4bd', der: '#c3c9d1', libreIzq: '#aeb4bd', libreDer: '#c3c9d1', texto: '#3a4048' },
        { techo: '#7cc47f', izq: '#4e8a51', der: '#68ab6b', libreIzq: '#b4d6b5', libreDer: '#cbe4cc', texto: '#16351a' },
        { techo: '#e8a33d', izq: '#a86f1e', der: '#cc8b2c', libreIzq: '#eccb98', libreDer: '#f4dcb5', texto: '#3d2606' },
        { techo: '#d9534f', izq: '#93302d', der: '#bb4340', libreIzq: '#e3a3a1', libreDer: '#efc1bf', texto: '#ffffff' },
        { techo: '#a5b4fc', izq: '#6366f1', der: '#818cf8', libreIzq: '#c3cafb', libreDer: '#d6dbfd', texto: '#1e1b4b' },
        { techo: '#9a3412', izq: '#5c1f0b', der: '#7c2a0f', libreIzq: '#5c1f0b', libreDer: '#7c2a0f', texto: '#ffffff' }
    ];

    // Con contenido pero sin el dato del criterio (producto sin clase ABC, lote sin caducidad):
    // un tono propio, para no confundirlo con el gris de vacía.
    var COLOR_SIN_DATO = '#a78bfa';

    // Reservada para una entrada que aún no se ha ubicado (u.v, lo manda AL): en el color por
    // estado manda sobre todo menos bloqueada.
    var COLOR_RESERVADA = '#14b8a6';

    // Criterios de color. Cada uno da, para una ubicación, el color base y la entrada de su
    // leyenda. Las vacías van siempre en el gris de vacía.
    var CRITERIOS = {
        estado: {
            nombre: 'Estado',
            leyenda: [['#d9dde3', 'vacía'], ['#7cc47f', 'con hueco'], ['#e8a33d', 'llena'], ['#9a3412', 'sobrepasada'], ['#d9534f', 'bloqueada'], [COLOR_RESERVADA, 'reservada'], ['#a5b4fc', 'sin medir']]
        },
        posicion: {
            nombre: 'Posición ABC',
            leyenda: [['#ef4444', 'hueco A'], ['#f59e0b', 'hueco B'], ['#3b82f6', 'hueco C'], ['#d9dde3', 'sin clase']]
        },
        abc: {
            nombre: 'Rotación ABC',
            leyenda: [['#d9dde3', 'vacía'], ['#ef4444', 'A (alta)'], ['#f59e0b', 'B'], ['#3b82f6', 'C (baja)'], [COLOR_SIN_DATO, 'sin clase']]
        },
        caducidad: {
            nombre: 'Caducidad',
            leyenda: [['#d9dde3', 'vacía'], ['#7f1d1d', 'caducado'], ['#f97316', '30 días o menos'], ['#facc15', '31-90 días'], ['#22c55e', 'más de 90 días'], [COLOR_SIN_DATO, 'sin fecha']]
        }
    };

    // Lo que se ve de un hueco con algo dentro aunque su % redondeado sea 0: si no, un hueco
    // casi vacío parecería vacío del todo.
    var NIVEL_MINIMO = 0.06;

    // Parte del sitio de cada cubo que ocupa la línea de separación con sus vecinos, y su color.
    var RENDIJA = 0.08;
    var COLOR_SEPARACION = '#374151';

    // Colores del traslado: de dónde sale (azul) y a dónde va (amarillo).
    var COLOR_ORIGEN = { techo: '#60a5fa', izq: '#2563eb', der: '#3b82f6', libreIzq: '#2563eb', libreDer: '#3b82f6', texto: '#ffffff' };
    var COLOR_DESTINO = { techo: '#fde047', izq: '#ca8a04', der: '#eab308', libreIzq: '#ca8a04', libreDer: '#eab308', texto: '#1f2937' };

    // Ubicación que coincide con la búsqueda: borde de este color. Las que no, se apagan.
    var COLOR_ENCONTRADA = '#f59e0b';
    var OPACIDAD_NO_ENCONTRADA = 0.18;

    var paletasHechas = {};

    function crear(idContenedor) {
        var cont = document.getElementById(idContenedor);
        if (!cont) { return; }

        var opcionesColor = '';
        for (var clave in CRITERIOS) {
            if (Object.prototype.hasOwnProperty.call(CRITERIOS, clave)) {
                opcionesColor += '<option value="' + clave + '">' + CRITERIOS[clave].nombre + '</option>';
            }
        }

        cont.innerHTML =
            '<div class="sga3d-barra">' +
            '  <span class="sga3d-grupo">' +
            '    <button type="button" class="sga3d-btn sga3d-on" data-accion="vista" data-vista="3d">3D</button>' +
            '    <button type="button" class="sga3d-btn" data-accion="vista" data-vista="planta">Planta</button>' +
            '    <button type="button" class="sga3d-btn" data-accion="vista" data-vista="frente">Frente</button>' +
            '  </span>' +
            '  <span class="sga3d-sel">Estantería:' +
            '    <button type="button" class="sga3d-btn sga3d-mini" data-accion="anterior">&lt;</button>' +
            '    <select class="sga3d-combo" id="sga3d-pasillo"><option value="">Todas</option></select>' +
            '    <button type="button" class="sga3d-btn sga3d-mini" data-accion="siguiente">&gt;</button>' +
            '  </span>' +
            '  <span class="sga3d-sel">Colorear por:' +
            '    <select class="sga3d-combo" id="sga3d-color">' + opcionesColor + '</select>' +
            '  </span>' +
            '  <span class="sga3d-sel">Buscar:' +
            '    <input type="search" class="sga3d-combo sga3d-buscar" id="sga3d-buscar" placeholder="Producto o ubicación">' +
            '  </span>' +
            '  <span class="sga3d-grupo">' +
            '    <button type="button" class="sga3d-btn sga3d-solo3d" data-accion="girar">Girar 45°</button>' +
            '    <button type="button" class="sga3d-btn" data-accion="acercar">+</button>' +
            '    <button type="button" class="sga3d-btn" data-accion="alejar">-</button>' +
            '    <button type="button" class="sga3d-btn" data-accion="centrar">Centrar</button>' +
            '    <button type="button" class="sga3d-btn sga3d-solo3d sga3d-on" data-accion="pasillos">Pasillos</button>' +
            '    <button type="button" class="sga3d-btn sga3d-on" data-accion="etiquetas">Nº ubicación</button>' +
            '  </span>' +
            '  <span class="sga3d-leyenda" id="sga3d-leyenda"></span>' +
            '  <span class="sga3d-info" id="sga3d-info"></span>' +
            '  <span class="sga3d-ayuda" id="sga3d-ayuda"></span>' +
            '</div>' +
            '<canvas class="sga3d-canvas"></canvas>' +
            '<div class="sga3d-tip" id="sga3d-tip"></div>';

        canvas = cont.querySelector('canvas');
        ctx = canvas.getContext('2d');

        cont.querySelector('.sga3d-barra').addEventListener('click', function (e) {
            var accion = e.target.getAttribute('data-accion');
            if (!accion) { return; }
            if (accion === 'vista') { cambiarVista(e.target.getAttribute('data-vista')); return; }
            if (accion === 'anterior') { saltarPasillo(-1); return; }
            if (accion === 'siguiente') { saltarPasillo(1); return; }
            if (accion === 'acercar') { zoomCentro(1.25); return; }
            if (accion === 'alejar') { zoomCentro(1 / 1.25); return; }
            // Centrar encuadra lo que se está viendo.
            if (accion === 'centrar') { angulo = 0; encuadrarVista(); return; }
            if (accion === 'girar') { angulo += Math.PI / 4; }
            if (accion === 'pasillos') {
                separarPasillos = !separarPasillos;
                e.target.classList.toggle('sga3d-on', separarPasillos);
            }
            if (accion === 'etiquetas') {
                verEtiquetas = !verEtiquetas;
                e.target.classList.toggle('sga3d-on', verEtiquetas);
            }
            proyectar();
            pintar();
        });

        cont.querySelector('#sga3d-pasillo').addEventListener('change', function (e) {
            elegirPasillo(e.target.value);
        });

        cont.querySelector('#sga3d-color').addEventListener('change', function (e) {
            colorear = e.target.value;
            pintarLeyenda();
            pintar();
        });

        cont.querySelector('#sga3d-buscar').addEventListener('input', function (e) {
            busqueda = String(e.target.value || '').trim().toUpperCase();
            mostrarInfo(hover);
            pintar();
        });

        canvas.addEventListener('mousedown', function (e) {
            if (e.button !== 0) { return; }
            seHaMovido = false;
            ultimoX = e.clientX;
            ultimoY = e.clientY;
            inicioX = e.clientX;
            inicioY = e.clientY;

            // Con Mayús se desplaza y con Alt se gira (en la 3D), pulse donde se pulse.
            if (e.shiftKey) { modoArrastre = 'mover'; return; }
            if (e.altKey && vista === '3d') { modoArrastre = 'girar'; e.preventDefault(); return; }

            // Sobre una ubicación con contenido se coge la mercancía. Hasta que el ratón se
            // mueve no es arrastre: si se suelta antes, es un clic y abre el contenido.
            var c = elementoEn(e);
            if (c && c.u.l > 0) {
                modoArrastre = 'coger';
                origenTraslado = c;
                destinoTraslado = null;
                destinoOtraZona = null;
                e.preventDefault();
                return;
            }

            // Fuera de una ubicación, o sobre una vacía: en la 3D gira, en las planas desplaza.
            modoArrastre = vista === '3d' ? 'girar' : 'mover';
        });

        window.addEventListener('mouseup', function () {
            if (modoArrastre === 'trasladar') {
                terminarTraslado();
            } else if (modoArrastre === 'coger') {
                // Se soltó sin arrastrar: queda como clic, que abre el contenido.
                origenTraslado = null;
            }
            modoArrastre = '';
            canvas.classList.remove('sga3d-trasladando');
        });

        // Esc suelta la mercancía sin trasladar.
        window.addEventListener('keydown', function (e) {
            if (e.key === 'Escape' && (modoArrastre === 'trasladar' || modoArrastre === 'coger')) {
                destinoTraslado = null;
                destinoOtraZona = null;
                terminarTraslado();
                canvas.classList.remove('sga3d-trasladando');
            }
        });

        canvas.addEventListener('mousemove', function (e) {
            if (modoArrastre === 'coger') {
                if (Math.abs(e.clientX - inicioX) + Math.abs(e.clientY - inicioY) < UMBRAL_ARRASTRE) { return; }
                modoArrastre = 'trasladar';
                mostrarFicha(null);
                canvas.classList.add('sga3d-trasladando');
            }
            if (modoArrastre === 'trasladar') {
                var r = canvas.getBoundingClientRect();
                ratonX = e.clientX - r.left;
                ratonY = e.clientY - r.top;
                seHaMovido = true;
                var c = elementoEn(e);
                // Entre zonas no se traslada desde el mapa: esa ubicación no vale de destino.
                destinoOtraZona = (c && c.u.b !== origenTraslado.u.b && !mismaZona(c, origenTraslado)) ? c : null;
                destinoTraslado = (c && c.u.b !== origenTraslado.u.b && !destinoOtraZona) ? c : null;
                canvas.classList.toggle('sga3d-prohibido', !!destinoOtraZona);
                mostrarInfoTraslado();
                pintar();
                return;
            }
            if (modoArrastre) {
                mostrarFicha(null);
                var dx = e.clientX - ultimoX;
                var dy = e.clientY - ultimoY;
                ultimoX = e.clientX;
                ultimoY = e.clientY;
                seHaMovido = true;

                if (modoArrastre === 'mover') {
                    if (vista === '3d') { panX += dx; panY += dy; } else { pan2X += dx; pan2Y += dy; }
                    pintar();
                } else {
                    angulo += dx * 0.012;
                    proyectar();
                    pintar();
                }
                return;
            }
            var antes = hover;
            hover = elementoEn(e);
            if (hover !== antes) {
                mostrarInfo(hover);
                pintar();
                // El cursor avisa de que la ubicación se puede coger y llevar a otra.
                canvas.classList.toggle('sga3d-cogible', !!(hover && hover.u.l > 0));
            }
            // La ficha sigue al ratón aunque la ubicación no cambie.
            mostrarFicha(hover, e);
        });

        canvas.addEventListener('mouseleave', function () {
            // Soltar fuera del mapa no traslada a ningún sitio.
            destinoTraslado = null;
            destinoOtraZona = null;
            hover = null;
            mostrarInfo(null);
            mostrarFicha(null);
            pintar();
        });

        // La rueda acerca hacia donde apunta el ratón, no hacia el centro.
        canvas.addEventListener('wheel', function (e) {
            e.preventDefault();
            var r = canvas.getBoundingClientRect();
            zoomEn(e.deltaY < 0 ? 1.15 : 1 / 1.15, e.clientX - r.left, e.clientY - r.top);
        }, { passive: false });

        // Un clic limpio (sin arrastre) abre el contenido de la ubicación en BC.
        canvas.addEventListener('click', function (e) {
            if (seHaMovido) { return; }
            var c = elementoEn(e);
            if (c) { avisarAL('CeldaPulsada', [c.u.b]); }
        });

        // Clic derecho sobre una ubicación con contenido: pedir a AL que la vacíe (queda sin
        // ubicar). AL confirma antes; aquí solo se avisa. Sin contenido no hace nada.
        canvas.addEventListener('contextmenu', function (e) {
            e.preventDefault();
            var c = elementoEn(e);
            if (c && c.u.l > 0) {
                mostrarFicha(null);
                avisarAL('VaciarSolicitado', [c.u.b]);
            }
        });

        // Doble clic: ver de frente el pasillo de esa ubicación. En la 3D es la forma rápida
        // de llegar a un pasillo del medio, que queda tapado por los de delante.
        canvas.addEventListener('dblclick', function (e) {
            var c = elementoEn(e);
            if (!c) { return; }
            if (vista === '3d') {
                elegirPasillo(String(c.u.e));
            } else if (vista === 'planta') {
                pasilloActivo = String(c.u.e);
                cambiarVista('frente');
            }
        });

        window.addEventListener('resize', function () { ajustarTamano(); pintar(); });

        pintarLeyenda();
        actualizarBarra();
        ajustarTamano();
    }

    function ajustarTamano() {
        if (!canvas) { return; }
        var r = canvas.parentElement.getBoundingClientRect();
        // Se descuenta la altura real de la barra de botones (puede ocupar varias líneas en
        // pantallas estrechas); el resto es todo para el mapa.
        var barra = canvas.parentElement.querySelector('.sga3d-barra');
        var altoBarra = barra ? barra.getBoundingClientRect().height : 34;
        var alto = Math.max(400, Math.floor(r.height - altoBarra));
        // El canvas se dimensiona en píxeles reales para que no salga borroso.
        var dpr = window.devicePixelRatio || 1;
        canvas.width = Math.max(320, Math.floor(r.width * dpr));
        canvas.height = Math.floor(alto * dpr);
        canvas.style.width = Math.max(320, Math.floor(r.width)) + 'px';
        canvas.style.height = alto + 'px';
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }

    function anchoLienzo() { return canvas.width / (window.devicePixelRatio || 1); }
    function altoLienzo() { return canvas.height / (window.devicePixelRatio || 1); }

    // ---------------------------------------------------------------- vistas y pasillos

    // Cambia de vista conservando el pasillo elegido. El frente necesita uno: si no hay,
    // se toma el primero. La planta enseña siempre todos.
    function cambiarVista(nueva) {
        if (!nueva || !AYUDA[nueva]) { return; }
        vista = nueva;
        if (vista === 'frente' && !pasilloActivo && pasillos.length) { pasilloActivo = pasillos[0]; }
        if (vista === 'planta') { pasilloActivo = ''; }
        hover = null;
        mostrarFicha(null);
        mostrarInfo(null);
        sincronizarSelector();
        actualizarBarra();
        encuadrarVista();
        avisarPasillo();
    }

    // Botones de la vista activa, los que solo valen en la 3D y el texto de ayuda.
    function actualizarBarra() {
        var raiz = canvas ? canvas.parentElement : null;
        if (!raiz) { return; }
        var botones = raiz.querySelectorAll('[data-accion="vista"]');
        for (var i = 0; i < botones.length; i++) {
            botones[i].classList.toggle('sga3d-on', botones[i].getAttribute('data-vista') === vista);
        }
        var solo3d = raiz.querySelectorAll('.sga3d-solo3d');
        for (var j = 0; j < solo3d.length; j++) {
            solo3d[j].style.display = vista === '3d' ? '' : 'none';
        }
        var ayuda = document.getElementById('sga3d-ayuda');
        if (ayuda) { ayuda.textContent = AYUDA[vista]; }
        ajustarTamano();
    }

    // Elegir un pasillo en el selector, con < > o con doble clic. En la 3D lo aísla; en la
    // planta pasa a verlo de frente; en el frente lo cambia. "Todos" vuelve a la planta desde
    // el frente.
    function elegirPasillo(pasillo) {
        pasillo = pasillo || '';
        if (vista === 'frente' && !pasillo) { cambiarVista('planta'); return; }
        pasilloActivo = pasillo;
        if (vista === 'planta' && pasillo) { cambiarVista('frente'); return; }
        sincronizarSelector();
        encuadrarVista();
        avisarPasillo();
    }

    // La página acompaña el pasillo que se mira.
    function avisarPasillo() {
        avisarAL('PasilloSeleccionado', [pasilloActivo ? conCeros(Number(pasilloActivo), 3) : '']);
    }

    function saltarPasillo(paso) {
        if (!pasillos.length) { return; }
        var i = pasillos.indexOf(pasilloActivo);
        if (i < 0) {
            // Desde "Todos" se entra por el primero o por el último, según el sentido.
            elegirPasillo(paso > 0 ? pasillos[0] : pasillos[pasillos.length - 1]);
            return;
        }
        i += paso;
        if (i < 0 || i >= pasillos.length) { elegirPasillo(''); return; }
        elegirPasillo(pasillos[i]);
    }

    function sincronizarSelector() {
        var sel = document.getElementById('sga3d-pasillo');
        if (!sel) { return; }

        var html = '<option value="">Todos</option>';
        for (var i = 0; i < pasillos.length; i++) {
            html += '<option value="' + pasillos[i] + '">Pas. ' + conCeros(Number(pasillos[i]), 3) + '</option>';
        }
        sel.innerHTML = html;
        sel.value = pasilloActivo;
    }

    function listarPasillos() {
        var vistos = {};
        pasillos = [];
        for (var i = 0; i < ubicaciones.length; i++) {
            var e = String(ubicaciones[i].e);
            if (!vistos[e]) { vistos[e] = true; pasillos.push(e); }
        }
        pasillos.sort(function (a, b) { return Number(a) - Number(b); });
        numerarAlturas();
    }

    // Nivel de cada altura (u.n): su posición entre las alturas que hay, de abajo arriba.
    // Así 00, 10, 20 se dibujan seguidas y no con nueve niveles vacíos entre ellas.
    function numerarAlturas() {
        var vistas = {};
        var alturas = [];
        var i;
        for (i = 0; i < ubicaciones.length; i++) {
            var a = ubicaciones[i].a;
            if (!vistas[a]) { vistas[a] = true; alturas.push(a); }
        }
        alturas.sort(function (x, y) { return x - y; });
        var nivel = {};
        for (i = 0; i < alturas.length; i++) { nivel[alturas[i]] = i + 1; }
        for (i = 0; i < ubicaciones.length; i++) { ubicaciones[i].n = nivel[ubicaciones[i].a]; }
    }

    function visible(u) {
        return !pasilloActivo || String(u.e) === pasilloActivo;
    }

    function proyectar() {
        if (vista === '3d') { proyectar3D(); } else { maquetarPlano(); }
    }

    function encuadrarVista() {
        if (vista === '3d') { encuadrar(); } else { encuadrarPlano(); }
    }

    function pintar() {
        if (!ctx) { return; }
        if (vista === '3d') { pintar3D(); } else { pintarPlano(); }
    }

    function elementoEn(evento) {
        return vista === '3d' ? cuboEn(evento) : rectEn(evento);
    }

    // Zoom con los botones: hacia el centro del lienzo.
    function zoomCentro(factor) {
        zoomEn(factor, anchoLienzo() / 2, altoLienzo() / 2);
    }

    // Zoom hacia un punto de la pantalla: lo que está bajo él se queda donde está. Las
    // posiciones son proporcionales a la escala alrededor del centro, así que basta con
    // corregir el desplazamiento.
    function zoomEn(factor, mx, my) {
        var o;
        if (vista === '3d') {
            var nueva = Math.max(ESCALA_MIN, Math.min(escala * factor, ESCALA_MAX));
            factor = nueva / escala;
            if (factor === 1) { return; }
            o = centroPantalla();
            panX += (mx - o.x) * (1 - factor);
            panY += (my - o.y) * (1 - factor);
            escala = nueva;
        } else {
            var nueva2 = Math.max(ESCALA2_MIN, Math.min(escala2 * factor, ESCALA2_MAX));
            factor = nueva2 / escala2;
            if (factor === 1) { return; }
            o = centroPlano();
            pan2X += (mx - o.x) * (1 - factor);
            pan2Y += (my - o.y) * (1 - factor);
            escala2 = nueva2;
        }
        mostrarFicha(null);
        proyectar();
        pintar();
    }

    // ---------------------------------------------------------------- colores

    // Mezcla dos colores #rrggbb: t = 0 da el primero, 1 el segundo.
    function mezclar(c1, c2, t) {
        var a = parseInt(c1.slice(1), 16);
        var b = parseInt(c2.slice(1), 16);
        var r = Math.round(((a >> 16) & 255) * (1 - t) + ((b >> 16) & 255) * t);
        var g = Math.round(((a >> 8) & 255) * (1 - t) + ((b >> 8) & 255) * t);
        var bl = Math.round((a & 255) * (1 - t) + (b & 255) * t);
        return '#' + ((1 << 24) + (r << 16) + (g << 8) + bl).toString(16).slice(1);
    }

    // Juego de tonos de un color base, como los de PALETA: techo, laterales y lo libre.
    function paleta(base) {
        if (!paletasHechas[base]) {
            var oscuro = parseInt(base.slice(1, 3), 16) * 0.299 + parseInt(base.slice(3, 5), 16) * 0.587 + parseInt(base.slice(5, 7), 16) * 0.114 < 120;
            paletasHechas[base] = {
                techo: base,
                izq: mezclar(base, '#000000', 0.3),
                der: mezclar(base, '#000000', 0.15),
                libreIzq: mezclar(base, '#ffffff', 0.45),
                libreDer: mezclar(base, '#ffffff', 0.6),
                texto: oscuro ? '#ffffff' : '#1f2937'
            };
        }
        return paletasHechas[base];
    }

    // Colores de una ubicación según el criterio elegido.
    function colorDe(u) {
        if (colorear === 'estado') {
            // Bloqueada manda; después, reservada; si no, sin medir, y por encima del 100 %
            // sobrepasada.
            if (u.s !== 3 && u.v) { return paleta(COLOR_RESERVADA); }
            if (u.s !== 3 && u.s !== 4 && u.l && u.o > 100) { return PALETA[5]; }
            return PALETA[u.s] || PALETA[0];
        }
        // Por posición se pintan todas, vacías también: es la clase del hueco, no de lo que tiene.
        if (colorear === 'posicion') {
            if (u.ch === 1) { return paleta('#ef4444'); }
            if (u.ch === 2) { return paleta('#f59e0b'); }
            if (u.ch === 3) { return paleta('#3b82f6'); }
            return PALETA[0];
        }
        if (!u.l) { return PALETA[0]; }

        if (colorear === 'abc') {
            if (u.r === 1) { return paleta('#ef4444'); }
            if (u.r === 2) { return paleta('#f59e0b'); }
            if (u.r === 3) { return paleta('#3b82f6'); }
            return paleta(COLOR_SIN_DATO);
        }
        if (colorear === 'caducidad') {
            var dias = diasHasta(u.fc);
            if (dias === null) { return paleta(COLOR_SIN_DATO); }
            if (dias < 0) { return paleta('#7f1d1d'); }
            if (dias <= 30) { return paleta('#f97316'); }
            if (dias <= 90) { return paleta('#facc15'); }
            return paleta('#22c55e');
        }
        return PALETA[u.s] || PALETA[0];
    }

    // Días que faltan hasta una fecha aaaa-mm-dd (negativo si ya pasó); null sin fecha.
    function diasHasta(f) {
        if (!f) { return null; }
        var p = String(f).split('-');
        if (p.length !== 3) { return null; }
        var fecha = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
        var hoy = new Date();
        hoy = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate());
        return Math.round((fecha - hoy) / 86400000);
    }

    function pintarLeyenda() {
        var el = document.getElementById('sga3d-leyenda');
        if (!el) { return; }
        var items = CRITERIOS[colorear].leyenda;
        var html = '';
        for (var i = 0; i < items.length; i++) {
            html += '<i class="sga3d-m" style="background:' + items[i][0] + '"></i>' + esc(items[i][1]);
        }
        el.innerHTML = html;
    }

    // ---------------------------------------------------------------- búsqueda

    // Si la ubicación tiene el producto buscado (código o descripción) o su código contiene
    // lo buscado. Sin búsqueda, todas coinciden.
    function coincide(u) {
        if (!busqueda) { return true; }
        if (String(u.b).toUpperCase().indexOf(busqueda) >= 0) { return true; }
        var i;
        if (u.pp) {
            for (i = 0; i < u.pp.length; i++) {
                if (String(u.pp[i]).toUpperCase().indexOf(busqueda) >= 0) { return true; }
            }
        }
        if (u.k) {
            for (i = 0; i < u.k.length; i++) {
                if (String(u.k[i].t || '').toUpperCase().indexOf(busqueda) >= 0) { return true; }
            }
        }
        return false;
    }

    function contarCoincidencias() {
        var n = 0;
        for (var i = 0; i < ubicaciones.length; i++) {
            if (coincide(ubicaciones[i])) { n++; }
        }
        return n;
    }

    // ---------------------------------------------------------------- vista 3D

    // Ajusta zoom y desplazamiento para que lo visible (un pasillo o el almacén) llene el
    // lienzo con un pequeño margen. Se proyecta a escala 1 para medir y luego se escala: las
    // posiciones de los cubos son proporcionales a la escala.
    function encuadrar() {
        escala = 1;
        panX = 0;
        panY = 0;
        proyectar3D();
        if (!cubos.length) { pintar(); return; }

        var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
        for (var i = 0; i < cubos.length; i++) {
            var cu = cubos[i];
            // Rombo de arriba más el cuerpo que cuelga: lo que ocupa el cubo en pantalla.
            if (cu.x - ANCHO < minX) { minX = cu.x - ANCHO; }
            if (cu.x + ANCHO > maxX) { maxX = cu.x + ANCHO; }
            if (cu.y - ALTO < minY) { minY = cu.y - ALTO; }
            if (cu.y + ALTO + GRUESO > maxY) { maxY = cu.y + ALTO + GRUESO; }
        }

        var ancho = Math.max(maxX - minX, 1);
        var alto = Math.max(maxY - minY, 1);
        escala = Math.min((anchoLienzo() * 0.92) / ancho, (altoLienzo() * 0.88) / alto);
        escala = Math.max(ESCALA_MIN, Math.min(escala, ESCALA_MAX));

        // El centro de lo que se ve, a la nueva escala, va al centro del lienzo.
        panX = -((minX + maxX) / 2) * escala;
        panY = -((minY + maxY) / 2) * escala;

        proyectar3D();
        pintar();
    }

    // Gira un punto del suelo alrededor del centro de la nave. Al ser un giro libre y no de
    // 90 en 90, se puede mirar un pasillo desde cualquier lado.
    function girar(e, c) {
        var cos = Math.cos(angulo);
        var sin = Math.sin(angulo);
        return { e: e * cos - c * sin, c: e * sin + c * cos };
    }

    // Pasa coordenadas del suelo ya giradas a píxeles de pantalla.
    function aPantalla(ge, gc, altura) {
        return {
            x: (gc - ge) * ANCHO * escala,
            y: (gc + ge) * ALTO * escala - altura * GRUESO * escala
        };
    }

    function proyectar3D() {
        cubos = [];
        rotulos = [];
        if (!ubicaciones.length) { return; }

        var maxE = 0, maxC = 0, minE = 1e9, minC = 1e9;
        var i, u;
        var hayAlguna = false;
        for (i = 0; i < ubicaciones.length; i++) {
            u = ubicaciones[i];
            if (!visible(u)) { continue; }
            hayAlguna = true;
            if (u.e > maxE) { maxE = u.e; }
            if (u.c > maxC) { maxC = u.c; }
            if (u.e < minE) { minE = u.e; }
            if (u.c < minC) { minC = u.c; }
        }
        if (!hayAlguna) { return; }

        // Se gira alrededor del centro de la nave para que no se escape de la pantalla.
        var sep = separarPasillos ? SEPARACION : 1;
        var centroE = ((minE + maxE) / 2) * sep;
        var centroC = (minC + maxC) / 2;

        for (i = 0; i < ubicaciones.length; i++) {
            u = ubicaciones[i];
            if (!visible(u)) { continue; }
            var g = girar(u.e * sep - centroE, u.c - centroC);
            var p = aPantalla(g.e, g.c, u.n);
            cubos.push({
                u: u,
                x: p.x,
                y: p.y,
                // La profundidad decide el orden de pintado: lo de detrás primero, para que
                // lo de delante lo tape y el volumen se lea bien.
                z: g.c + g.e + u.n * 0.01
            });
        }

        cubos.sort(function (a, b) { return a.z - b.z; });

        if (separarPasillos) {
            proyectarRotulos(minC, sep, centroE, centroC);
        }
    }

    // Un cartel por pasillo, delante de su primera estantería, para saber en qué pasillo se
    // está mirando cuando el almacén se gira.
    function proyectarRotulos(minC, sep, centroE, centroC) {
        var vistas = {};
        for (var i = 0; i < ubicaciones.length; i++) {
            var u = ubicaciones[i];
            if (!visible(u)) { continue; }
            if (vistas[u.e]) { continue; }
            vistas[u.e] = true;

            var g = girar(u.e * sep - centroE, (minC - 1.5) - centroC);
            var p = aPantalla(g.e, g.c, 0);
            rotulos.push({ texto: 'Pas. ' + conCeros(u.e, 3), x: p.x, y: p.y, z: g.c + g.e });
        }
    }

    // Número con ceros a la izquierda hasta "digitos" cifras, como en el código de ubicación.
    function conCeros(n, digitos) {
        var texto = String(n);
        while (texto.length < digitos) { texto = '0' + texto; }
        return texto;
    }

    function centroPantalla() {
        return { x: anchoLienzo() / 2 + panX, y: altoLienzo() / 2 + panY };
    }

    function mensajeVacio() {
        ctx.fillStyle = '#6b7280';
        ctx.font = '13px Segoe UI, sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('No hay ubicaciones que dibujar con este filtro.', anchoLienzo() / 2, altoLienzo() / 2);
    }

    function pintar3D() {
        var w = anchoLienzo();
        var h = altoLienzo();
        ctx.clearRect(0, 0, w, h);
        if (!cubos.length) { mensajeVacio(); return; }

        var o = centroPantalla();
        var a = ANCHO * escala;
        var b = ALTO * escala;
        var g = GRUESO * escala;

        // Separación entre ubicaciones: se pinta el sitio entero del cubo en el color de
        // separación y encima el cubo, algo menor. Lo que queda alrededor es una línea opaca:
        // no deja ver el cubo de detrás, que daría a la separación el color de otra ubicación.
        // Con el cubo diminuto no hay separación: sería una mancha oscura.
        var conSeparacion = a * (1 - RENDIJA) >= 4;
        var da = conSeparacion ? a * (1 - RENDIJA) : a;
        var db = conSeparacion ? b * (1 - RENDIJA) : b;
        var dg = conSeparacion ? Math.max(g - b * RENDIJA * 2, g * 0.5) : g;
        var grosorBorde = Math.max(1, Math.min(a / 16, 2));

        // El tamaño de letra sale de lo que mide el cubo, y se decide una sola vez si cabe el
        // código entero o solo el número de hueco. Medir cubo a cubo sería carísimo con mil
        // ubicaciones en pantalla.
        var modoTexto = '';
        var tamLetra = 0;
        if (verEtiquetas) {
            tamLetra = Math.round(Math.min(a * 0.42, 13));
            if (tamLetra >= 6) {
                ctx.font = tamLetra + 'px Segoe UI, sans-serif';
                var anchoUtil = a * 1.5;
                if (ctx.measureText(cubos[0].u.b).width <= anchoUtil) {
                    modoTexto = 'largo';
                } else if (ctx.measureText('88').width <= anchoUtil) {
                    modoTexto = 'corto';
                }
            }
        }

        for (var i = 0; i < cubos.length; i++) {
            var cu = cubos[i];
            var col = colorDe(cu.u);
            var px = o.x + cu.x;
            var py = o.y + cu.y;
            var resaltado = hover && hover.u.b === cu.u.b;
            var nivel = nivelLlenado(cu.u);
            var encontrada = coincide(cu.u);

            // Mientras se arrastra un traslado, el origen y el destino llevan su propio color,
            // en todo el cubo: el destino suele estar vacío y no se vería.
            if (modoArrastre === 'trasladar') {
                resaltado = false;
                if (origenTraslado && origenTraslado.u.b === cu.u.b) { col = COLOR_ORIGEN; nivel = 1; encontrada = true; }
                if (destinoTraslado && destinoTraslado.u.b === cu.u.b) { col = COLOR_DESTINO; nivel = 1; encontrada = true; }
            }

            // Fuera de pantalla no se dibuja: con miles de cubos es la diferencia entre que
            // gire suelto o a tirones.
            if (px < -a * 2 || px > w + a * 2 || py < -g * 3 || py > h + g * 3) { continue; }

            // Con una búsqueda, lo que no coincide se apaga.
            ctx.globalAlpha = encontrada ? 1 : OPACIDAD_NO_ENCONTRADA;

            // Sitio entero en el color de separación; el cubo va encima.
            if (conSeparacion) {
                ctx.beginPath();
                ctx.moveTo(px, py - b);
                ctx.lineTo(px + a, py);
                ctx.lineTo(px + a, py + g);
                ctx.lineTo(px, py + b + g);
                ctx.lineTo(px - a, py + g);
                ctx.lineTo(px - a, py);
                ctx.closePath();
                ctx.fillStyle = COLOR_SEPARACION;
                ctx.fill();
            }

            // Cara superior
            ctx.beginPath();
            ctx.moveTo(px, py - db);
            ctx.lineTo(px + da, py);
            ctx.lineTo(px, py + db);
            ctx.lineTo(px - da, py);
            ctx.closePath();
            ctx.fillStyle = resaltado ? '#ffffff' : col.techo;
            ctx.fill();

            // Caras laterales: el color en todo el lateral, claro en lo libre y oscuro desde
            // abajo hasta la ocupación, como un depósito.
            var hn = dg * nivel;
            var libreIzq = resaltado ? '#d0d7de' : (col.libreIzq || col.izq);
            var libreDer = resaltado ? '#e8edf2' : (col.libreDer || col.der);
            caraLateral(px, py, -da, db, 0, dg, libreIzq);
            caraLateral(px, py, da, db, 0, dg, libreDer);
            if (hn > 0) {
                caraLateral(px, py, -da, db, dg - hn, dg, col.izq);
                caraLateral(px, py, da, db, dg - hn, dg, col.der);
            }

            // Aristas: el contorno del cubo y sus tres aristas de delante, bien marcadas, para
            // que se vea dónde acaba cada ubicación. Con el cubo diminuto ensuciarían.
            if (da >= 4) {
                ctx.beginPath();
                ctx.moveTo(px, py - db);
                ctx.lineTo(px + da, py);
                ctx.lineTo(px + da, py + dg);
                ctx.lineTo(px, py + db + dg);
                ctx.lineTo(px - da, py + dg);
                ctx.lineTo(px - da, py);
                ctx.closePath();
                ctx.moveTo(px - da, py);
                ctx.lineTo(px, py + db);
                ctx.lineTo(px + da, py);
                ctx.moveTo(px, py + db);
                ctx.lineTo(px, py + db + dg);
                if (resaltado) {
                    ctx.strokeStyle = '#1d4ed8';
                    ctx.lineWidth = grosorBorde + 1;
                } else if (busqueda && encontrada) {
                    ctx.strokeStyle = COLOR_ENCONTRADA;
                    ctx.lineWidth = grosorBorde + 1.5;
                } else {
                    ctx.strokeStyle = 'rgba(31,41,55,0.6)';
                    ctx.lineWidth = grosorBorde;
                }
                ctx.lineJoin = 'round';
                ctx.stroke();
            }

            if (modoTexto) {
                ctx.fillStyle = resaltado ? '#111827' : col.texto;
                ctx.font = tamLetra + 'px Segoe UI, sans-serif';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillText(modoTexto === 'largo' ? cu.u.b : String(cu.u.c), px, py);
            }

            // Con el cubo grande (pasillo encuadrado o mucho zoom) se escribe el producto en
            // la cara frontal; si hay más de uno, cuántos más. El detalle está en la ficha.
            if (a >= ANCHO_PARA_PRODUCTO && cu.u.k && cu.u.k.length) {
                // El texto va a media altura: por debajo de la mitad de llenado cae sobre el
                // tono claro de lo libre, y ahí un texto blanco no se leería.
                ctx.fillStyle = nivel >= 0.5 ? col.texto : PALETA[0].texto;
                ctx.font = 'bold ' + Math.round(Math.min(a * 0.3, 14)) + 'px Segoe UI, sans-serif';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillText(textoProducto(cu.u), px, py + db + dg / 2, da * 1.9);
            }
        }
        ctx.globalAlpha = 1;

        pintarRotulos(o, w, h);
        pintarTraslado();
    }

    // Parte de una cara lateral del cubo, entre dos alturas medidas desde arriba (0 = borde
    // de arriba, el grueso del cubo = suelo). lado es -a para la izquierda y +a para la derecha.
    function caraLateral(px, py, lado, b, desde, hasta, color) {
        ctx.beginPath();
        ctx.moveTo(px + lado, py + desde);
        ctx.lineTo(px, py + b + desde);
        ctx.lineTo(px, py + b + hasta);
        ctx.lineTo(px + lado, py + hasta);
        ctx.closePath();
        ctx.fillStyle = color;
        ctx.fill();
    }

    function pintarRotulos(o, w, h) {
        if (!rotulos.length || escala < 0.35) { return; }

        ctx.font = 'bold ' + Math.round(Math.min(13 * escala, 15)) + 'px Segoe UI, sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';

        for (var i = 0; i < rotulos.length; i++) {
            var r = rotulos[i];
            var px = o.x + r.x;
            var py = o.y + r.y;
            if (px < 0 || px > w || py < 0 || py > h) { continue; }

            var m = ctx.measureText(r.texto).width;
            ctx.fillStyle = 'rgba(255,255,255,0.82)';
            ctx.fillRect(px - m / 2 - 4, py - 9, m + 8, 18);
            ctx.fillStyle = '#1f2937';
            ctx.fillText(r.texto, px, py);
        }
    }

    // Busca el cubo bajo el ratón recorriendo de delante hacia atrás, para que gane el que
    // se ve, no el que queda tapado.
    function cuboEn(evento) {
        if (!cubos.length) { return null; }
        var r = canvas.getBoundingClientRect();
        var mx = evento.clientX - r.left;
        var my = evento.clientY - r.top;
        var o = centroPantalla();
        var a = ANCHO * escala;
        var b = ALTO * escala;
        var g = GRUESO * escala;

        for (var i = cubos.length - 1; i >= 0; i--) {
            var cu = cubos[i];
            var px = o.x + cu.x;
            var py = o.y + cu.y;
            var dx = Math.abs(mx - px);
            var dy = my - py;

            // Rombo de la cara superior más el cuerpo que cuelga por debajo.
            if (dx <= a && dy >= -b && dy <= b + g) {
                if (dy <= b) {
                    if (dx / a + Math.abs(dy) / b <= 1) { return cu; }
                } else {
                    return cu;
                }
            }
        }
        return null;
    }

    // ---------------------------------------------------------------- vistas planas

    // Coloca las ubicaciones como rectángulos, a escala 1. Frente: el pasillo elegido,
    // estanterías por alturas (la más baja abajo). Planta: una fila por pasillo y una columna por
    // estantería, cada hueco partido en una franja por altura.
    function maquetarPlano() {
        rects = [];
        rotulos2 = [];
        if (!ubicaciones.length) { return; }

        var minC = 1e9, maxC = -1e9, minN = 1e9, maxN = -1e9;
        var i, u;
        var lista = [];
        var alturaDeNivel = {};
        for (i = 0; i < ubicaciones.length; i++) {
            u = ubicaciones[i];
            if (vista === 'frente' && String(u.e) !== pasilloActivo) { continue; }
            lista.push(u);
            alturaDeNivel[u.n] = u.a;
            if (u.c < minC) { minC = u.c; }
            if (u.c > maxC) { maxC = u.c; }
            if (u.n < minN) { minN = u.n; }
            if (u.n > maxN) { maxN = u.n; }
        }
        if (!lista.length) { return; }

        var columnas = {};
        if (vista === 'frente') {
            var pasoX = FRENTE_ANCHO + FRENTE_HUECO;
            var pasoY = FRENTE_ALTO + FRENTE_HUECO;
            for (i = 0; i < lista.length; i++) {
                u = lista[i];
                rects.push({ u: u, x: (u.c - minC) * pasoX, y: (maxN - u.n) * pasoY, w: FRENTE_ANCHO, h: FRENTE_ALTO });
                columnas[u.c] = true;
            }
            for (var n = minN; n <= maxN; n++) {
                if (alturaDeNivel[n] === undefined) { continue; }
                rotulos2.push({ texto: 'Altura ' + conCeros(alturaDeNivel[n], 2), x: -10, y: (maxN - n) * pasoY + FRENTE_ALTO / 2, alinear: 'right' });
            }
            for (var c in columnas) {
                if (Object.prototype.hasOwnProperty.call(columnas, c)) {
                    rotulos2.push({ texto: 'Est. ' + conCeros(c, 2), x: (Number(c) - minC) * pasoX + FRENTE_ANCHO / 2, y: -14, alinear: 'center' });
                }
            }
            rotulos2.push({ texto: 'Pasillo ' + conCeros(Number(pasilloActivo), 3), x: 0, y: -40, alinear: 'left', grande: true });
            return;
        }

        // Planta
        var alturas = maxN - minN + 1;
        var franja = PLANTA_ALTO / alturas;
        var pasoC = PLANTA_ANCHO + PLANTA_HUECO;
        var pasoE = PLANTA_ALTO + PLANTA_PASILLO;
        var filas = {};
        for (i = 0; i < pasillos.length; i++) { filas[pasillos[i]] = i; }
        for (i = 0; i < lista.length; i++) {
            u = lista[i];
            var fila = filas[String(u.e)];
            rects.push({
                u: u,
                x: (u.c - minC) * pasoC,
                y: fila * pasoE + (maxN - u.n) * franja,
                w: PLANTA_ANCHO,
                h: franja
            });
            columnas[u.c] = true;
        }
        for (i = 0; i < pasillos.length; i++) {
            rotulos2.push({ texto: 'Pas. ' + conCeros(Number(pasillos[i]), 3), x: -10, y: i * pasoE + PLANTA_ALTO / 2, alinear: 'right' });
        }
        for (var cc in columnas) {
            if (Object.prototype.hasOwnProperty.call(columnas, cc)) {
                rotulos2.push({ texto: String(cc), x: (Number(cc) - minC) * pasoC + PLANTA_ANCHO / 2, y: -10, alinear: 'center' });
            }
        }
    }

    // Ajusta zoom y desplazamiento para que todo lo maquetado (con sus rótulos) quepa.
    function encuadrarPlano() {
        escala2 = 1;
        pan2X = 0;
        pan2Y = 0;
        maquetarPlano();
        if (!rects.length) { pintar(); return; }

        var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
        var i;
        for (i = 0; i < rects.length; i++) {
            var r = rects[i];
            if (r.x < minX) { minX = r.x; }
            if (r.y < minY) { minY = r.y; }
            if (r.x + r.w > maxX) { maxX = r.x + r.w; }
            if (r.y + r.h > maxY) { maxY = r.y + r.h; }
        }
        // Sitio para los rótulos de la izquierda y de arriba.
        minX -= 80;
        minY -= vista === 'frente' ? 52 : 22;

        escala2 = Math.min((anchoLienzo() * 0.96) / Math.max(maxX - minX, 1), (altoLienzo() * 0.94) / Math.max(maxY - minY, 1));
        escala2 = Math.max(ESCALA2_MIN, Math.min(escala2, ESCALA2_MAX));
        pan2X = -((minX + maxX) / 2) * escala2;
        pan2Y = -((minY + maxY) / 2) * escala2;
        pintar();
    }

    function centroPlano() {
        return { x: anchoLienzo() / 2 + pan2X, y: altoLienzo() / 2 + pan2Y };
    }

    // Rectángulo en pantalla.
    function enPantalla(r) {
        var o = centroPlano();
        return { x: o.x + r.x * escala2, y: o.y + r.y * escala2, w: r.w * escala2, h: r.h * escala2 };
    }

    function rectEn(evento) {
        if (!rects.length) { return null; }
        var b = canvas.getBoundingClientRect();
        var mx = evento.clientX - b.left;
        var my = evento.clientY - b.top;
        for (var i = 0; i < rects.length; i++) {
            var p = enPantalla(rects[i]);
            if (mx >= p.x && mx <= p.x + p.w && my >= p.y && my <= p.y + p.h) { return rects[i]; }
        }
        return null;
    }

    function pintarPlano() {
        var w = anchoLienzo();
        var h = altoLienzo();
        ctx.clearRect(0, 0, w, h);
        if (!rects.length) { mensajeVacio(); return; }

        var enFrente = vista === 'frente';
        for (var i = 0; i < rects.length; i++) {
            var r = rects[i];
            var p = enPantalla(r);
            if (p.x + p.w < 0 || p.x > w || p.y + p.h < 0 || p.y > h) { continue; }

            var col = colorDe(r.u);
            var nivel = nivelLlenado(r.u);
            var encontrada = coincide(r.u);
            var resaltado = hover && hover.u.b === r.u.b;
            if (modoArrastre === 'trasladar') {
                resaltado = false;
                if (origenTraslado && origenTraslado.u.b === r.u.b) { col = COLOR_ORIGEN; nivel = 1; encontrada = true; }
                if (destinoTraslado && destinoTraslado.u.b === r.u.b) { col = COLOR_DESTINO; nivel = 1; encontrada = true; }
            }

            ctx.globalAlpha = encontrada ? 1 : OPACIDAD_NO_ENCONTRADA;

            // Fondo en el tono claro y, desde abajo, el lleno en el tono del color.
            ctx.fillStyle = col.libreDer || col.techo;
            ctx.fillRect(p.x, p.y, p.w, p.h);
            if (nivel > 0) {
                ctx.fillStyle = col.der;
                ctx.fillRect(p.x, p.y + p.h * (1 - nivel), p.w, p.h * nivel);
            }

            // Borde: separa cada ubicación de la de al lado y de la de arriba.
            if (p.w >= 3 && p.h >= 3) {
                if (resaltado) {
                    ctx.strokeStyle = '#1d4ed8';
                    ctx.lineWidth = 2.5;
                } else if (busqueda && encontrada) {
                    ctx.strokeStyle = COLOR_ENCONTRADA;
                    ctx.lineWidth = 3;
                } else {
                    ctx.strokeStyle = COLOR_SEPARACION;
                    ctx.lineWidth = 1;
                }
                ctx.strokeRect(p.x + 0.5, p.y + 0.5, p.w - 1, p.h - 1);
            }

            if (enFrente) { pintarTextosCasilla(r.u, p); }
        }
        ctx.globalAlpha = 1;

        pintarRotulosPlano();
        pintarTraslado();
    }

    // Lo que se lee en una casilla del frente: arriba el código (o la columna, si no cabe) y la
    // ocupación, en medio el producto y abajo el dato del criterio de color.
    function pintarTextosCasilla(u, p) {
        if (p.w < 40 || p.h < 26) { return; }
        var t = Math.max(9, Math.min(p.h * 0.16, 14));
        ctx.textBaseline = 'top';

        if (verEtiquetas) {
            ctx.font = t + 'px Segoe UI, sans-serif';
            ctx.textAlign = 'left';
            var codigo = ctx.measureText(u.b).width <= p.w * 0.62 ? u.b : String(u.c);
            textoConHalo(codigo, p.x + 5, p.y + 4);
        }
        if (u.l) {
            ctx.font = t + 'px Segoe UI, sans-serif';
            ctx.textAlign = 'right';
            textoConHalo(u.o < 0 || u.o === undefined ? '?' : u.o + '%', p.x + p.w - 5, p.y + 4);

            ctx.font = 'bold ' + Math.round(t * 1.15) + 'px Segoe UI, sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            textoConHalo(textoProducto(u), p.x + p.w / 2, p.y + p.h / 2, p.w - 8);

            var dato = datoCriterio(u);
            if (dato && p.h >= 48) {
                ctx.font = t + 'px Segoe UI, sans-serif';
                ctx.textBaseline = 'bottom';
                textoConHalo(dato, p.x + p.w / 2, p.y + p.h - 4, p.w - 8);
            }
        }
    }

    // Texto oscuro con un halo blanco, para leerse sobre cualquier color de fondo.
    function textoConHalo(texto, x, y, maxAncho) {
        ctx.lineWidth = 3;
        ctx.strokeStyle = 'rgba(255,255,255,0.9)';
        ctx.fillStyle = '#111827';
        if (maxAncho) {
            ctx.strokeText(texto, x, y, maxAncho);
            ctx.fillText(texto, x, y, maxAncho);
        } else {
            ctx.strokeText(texto, x, y);
            ctx.fillText(texto, x, y);
        }
    }

    function pintarRotulosPlano() {
        var o = centroPlano();
        for (var i = 0; i < rotulos2.length; i++) {
            var r = rotulos2[i];
            ctx.font = (r.grande ? 'bold ' + Math.round(Math.max(12, Math.min(16 * escala2, 18))) : Math.round(Math.max(9, Math.min(12 * escala2, 13)))) + 'px Segoe UI, sans-serif';
            ctx.textAlign = r.alinear;
            ctx.textBaseline = 'middle';
            ctx.fillStyle = '#374151';
            ctx.fillText(r.texto, o.x + r.x * escala2, o.y + r.y * escala2);
        }
    }

    // ---------------------------------------------------------------- comunes

    // Producto que se escribe en la ubicación: el primero y, si hay más, cuántos más.
    // La descripción del producto, que es lo que se reconoce; el código si no tiene.
    function textoProducto(u) {
        if (!u.k || !u.k.length) { return ''; }
        return (u.k[0].t || u.k[0].p) + (u.l > 1 ? ' +' + (u.l - 1) : '');
    }

    // El dato que da el color, para escribirlo en la casilla.
    function datoCriterio(u) {
        if (colorear === 'posicion') { return u.ch ? 'Hueco ' + 'ABC'.charAt(u.ch - 1) : 'Sin clase'; }
        if (colorear === 'abc') { return u.r ? 'Rotación ' + 'ABC'.charAt(u.r - 1) : 'Sin clase'; }
        if (colorear === 'caducidad') { return u.fc ? 'Cad. ' + fechaCorta(u.fc) : 'Sin caducidad'; }
        return '';
    }

    // Hasta dónde se llena la ubicación (0 a 1). Sin medir se pinta entera, porque no se sabe
    // cuánto hay; vacía, nada. Por encima del 100 % se queda llena.
    function nivelLlenado(u) {
        if (!u.l) { return 0; }
        if (u.o === undefined || u.o < 0) { return 1; }
        return Math.max(NIVEL_MINIMO, Math.min(u.o / 100, 1));
    }

    // Lo que se dice de la ocupación en la ficha y en la barra.
    function textoOcupacion(u) {
        if (u.o === undefined || u.o < 0) { return 'sin medir'; }
        if (u.o > 100) { return u.o + '% (sobrepasada)'; }
        return u.o + '% ocupada';
    }

    // Centro de una ubicación en pantalla, en cualquier vista.
    function centroDe(el) {
        if (vista === '3d') {
            var o = centroPantalla();
            return { x: o.x + el.x, y: o.y + el.y };
        }
        var p = enPantalla(el);
        return { x: p.x + p.w / 2, y: p.y + p.h / 2 };
    }

    // Línea desde la ubicación de origen hasta el ratón, con una punta, mientras se arrastra.
    function pintarTraslado() {
        if (modoArrastre !== 'trasladar' || !origenTraslado) { return; }

        var c0 = centroDe(origenTraslado);
        var x0 = c0.x;
        var y0 = c0.y;
        var x1 = ratonX;
        var y1 = ratonY;
        if (destinoTraslado) {
            var c1 = centroDe(destinoTraslado);
            x1 = c1.x;
            y1 = c1.y;
        }

        ctx.save();
        ctx.strokeStyle = '#1d4ed8';
        ctx.fillStyle = '#1d4ed8';
        ctx.lineWidth = 3;
        ctx.setLineDash([8, 5]);
        ctx.beginPath();
        ctx.moveTo(x0, y0);
        ctx.lineTo(x1, y1);
        ctx.stroke();

        var ang = Math.atan2(y1 - y0, x1 - x0);
        ctx.setLineDash([]);
        ctx.beginPath();
        ctx.moveTo(x1, y1);
        ctx.lineTo(x1 - 12 * Math.cos(ang - 0.4), y1 - 12 * Math.sin(ang - 0.4));
        ctx.lineTo(x1 - 12 * Math.cos(ang + 0.4), y1 - 12 * Math.sin(ang + 0.4));
        ctx.closePath();
        ctx.fill();
        ctx.restore();
    }

    // Al soltar: si hay un destino distinto del origen, se avisa a AL. Soltar en el vacío o
    // sobre el propio origen cancela sin más.
    function terminarTraslado() {
        var origen = origenTraslado;
        var destino = destinoTraslado;
        origenTraslado = null;
        destinoTraslado = null;
        destinoOtraZona = null;
        canvas.classList.remove('sga3d-prohibido');
        modoArrastre = '';
        mostrarInfo(null);
        pintar();

        if (origen && destino && origen.u.b !== destino.u.b) {
            avisarAL('TrasladoSolicitado', [origen.u.b, destino.u.b]);
        }
    }

    // Ficha flotante con lo que hay en la ubicación. Va junto al ratón para que se lea con
    // cualquier zoom, incluso con el almacén entero en pantalla y los cubos diminutos.
    function mostrarFicha(cu, evento) {
        var tip = document.getElementById('sga3d-tip');
        if (!tip) { return; }
        if (!cu || modoArrastre) { tip.style.display = 'none'; return; }

        var u = cu.u;
        var html = '<div class="sga3d-tip-cab">' + esc(u.b) +
            '<span>' + esc(textoOcupacion(u)) + '</span></div>';
        if (u.v) {
            html += '<div class="sga3d-tip-aviso">' + esc(u.v) + '</div>';
        }
        if (u.m) {
            html += '<div class="sga3d-tip-aviso">' + esc(u.m) + '</div>';
        }
        // Rotación y caducidad más próxima de todo lo que hay, no solo de las líneas listadas.
        var resumen = [];
        if (u.z) { resumen.push('Zona ' + u.z); }
        if (u.r) { resumen.push('Rotación ' + 'ABC'.charAt(u.r - 1)); }
        if (u.fc) { resumen.push('Caducidad más próxima ' + fechaCorta(u.fc)); }
        if (resumen.length) {
            html += '<div class="sga3d-tip-resumen">' + esc(resumen.join(' · ')) + '</div>';
        }

        if (!u.k || !u.k.length) {
            html += '<div class="sga3d-tip-vacia">Vacía</div>';
        } else {
            html += '<table>';
            for (var i = 0; i < u.k.length; i++) {
                var k = u.k[i];
                // Descripción delante (es lo que reconoce el operario), código debajo. La
                // cantidad va en cajas (o en botellas si la ubicación es de unidades), seguida del tipo
                // de palé del producto (el de su ficha) y cuánto lleva en esa misma unidad.
                html += '<tr' + (k.x ? ' class="sga3d-tip-bloq"' : '') + '>' +
                    '<td><b>' + esc(k.t || k.p) + '</b><br><small>' + esc(k.p) +
                    (k.l ? ' · Lote ' + esc(k.l) : '') +
                    (k.f ? ' · Cad. ' + esc(fechaCorta(k.f)) : '') + '</small></td>' +
                    '<td class="sga3d-tip-cant">' + numero(k.q) + ' ' + esc(k.u) + '</td>' +
                    '<td class="sga3d-tip-pale">' + (k.g ? esc(k.g) +
                        (k.gf ? '<br><small>' + numero(k.gf) + ' ' + esc(k.u) + '/palé</small>' : '') : '') + '</td>' +
                    '</tr>';
            }
            html += '</table>';
            if (u.l > u.k.length) {
                html += '<div class="sga3d-tip-mas">… y ' + (u.l - u.k.length) +
                    ' líneas más. Pulse la ubicación para verlas todas.</div>';
            }
        }
        tip.innerHTML = html;
        tip.style.display = 'block';

        // Se coloca al lado del ratón, y al otro lado si no cabe.
        var raiz = tip.parentElement.getBoundingClientRect();
        var x = evento.clientX - raiz.left + 16;
        var y = evento.clientY - raiz.top + 16;
        if (x + tip.offsetWidth > raiz.width) { x = evento.clientX - raiz.left - tip.offsetWidth - 16; }
        if (y + tip.offsetHeight > raiz.height) { y = evento.clientY - raiz.top - tip.offsetHeight - 16; }
        tip.style.left = Math.max(0, x) + 'px';
        tip.style.top = Math.max(0, y) + 'px';
    }

    function esc(t) {
        return String(t === undefined || t === null ? '' : t)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    // aaaa-mm-dd → dd/mm/aaaa
    function fechaCorta(f) {
        var p = String(f).split('-');
        return p.length === 3 ? p[2] + '/' + p[1] + '/' + p[0] : f;
    }

    function numero(n) {
        var v = Number(n) || 0;
        return Math.round(v) === v ? String(v) : v.toFixed(2).replace('.', ',');
    }

    function mostrarInfoTraslado() {
        var el = document.getElementById('sga3d-info');
        if (!el || !origenTraslado) { return; }
        if (destinoOtraZona) {
            el.textContent = destinoOtraZona.u.b + ' es de otra zona (' + nombreZona(destinoOtraZona.u) +
                '): entre zonas se traslada desde Contenido de ubicaciones.';
            return;
        }
        el.textContent = 'Trasladar ' + origenTraslado.u.b + ' → ' +
            (destinoTraslado ? destinoTraslado.u.b : '…');
    }

    // Una ubicación sin zona solo casa con otra sin zona, como comprueba AL.
    function mismaZona(a, b) {
        return (a.u.z || '') === (b.u.z || '');
    }

    function nombreZona(u) {
        return u.z || 'sin zona';
    }

    // La ubicación bajo el ratón o, sin ella, cuántas coinciden con la búsqueda.
    function mostrarInfo(cu) {
        var el = document.getElementById('sga3d-info');
        if (!el) { return; }
        if (!cu) {
            el.textContent = busqueda ? contarCoincidencias() + ' ubicaciones con «' + busqueda + '»' : '';
            return;
        }
        var t = cu.u.b;
        if (cu.u.d) { t += '  ·  ' + cu.u.d; }
        if (cu.u.z) { t += '  ·  Zona ' + cu.u.z; }
        t += '  ·  ' + textoOcupacion(cu.u);
        el.textContent = t;
    }

    function avisarAL(nombreEvento, args) {
        if (typeof Microsoft !== 'undefined' &&
            Microsoft.Dynamics &&
            Microsoft.Dynamics.NAV &&
            Microsoft.Dynamics.NAV.InvokeExtensibilityMethod) {
            Microsoft.Dynamics.NAV.InvokeExtensibilityMethod(nombreEvento, args);
        }
    }

    return {
        crear: crear,
        // La llama AL con el JSON de ubicaciones. Se queda en la vista y el color que haya,
        // y vuelve a encuadrar.
        cargar: function (json) {
            try {
                ubicaciones = JSON.parse(json) || [];
            } catch (err) {
                ubicaciones = [];
            }
            angulo = 0;
            pasilloActivo = '';
            listarPasillos();
            if (vista === 'frente' && pasillos.length) { pasilloActivo = pasillos[0]; }
            sincronizarSelector();
            ajustarTamano();
            encuadrarVista();
            mostrarInfo(null);
        },
        // Como cargar, pero conservando la vista entera (giro, zoom, desplazamiento y
        // pasillo): tras un traslado el operario sigue mirando lo mismo, ya al día.
        // La página manda solo el pasillo que se mira (su filtro sigue a PasilloSeleccionado):
        // se cambia ese pasillo y se conservan los demás, para que el selector y < >
        // sigan llevando a todos.
        refrescar: function (json) {
            var nuevas;
            try {
                nuevas = JSON.parse(json) || [];
            } catch (err) {
                return;
            }
            var llegan = {};
            var i;
            for (i = 0; i < nuevas.length; i++) { llegan[String(nuevas[i].e)] = true; }
            var resto = [];
            for (i = 0; i < ubicaciones.length; i++) {
                if (!llegan[String(ubicaciones[i].e)]) { resto.push(ubicaciones[i]); }
            }
            ubicaciones = resto.concat(nuevas);
            listarPasillos();
            if (pasilloActivo && pasillos.indexOf(pasilloActivo) < 0) {
                pasilloActivo = vista === 'frente' && pasillos.length ? pasillos[0] : '';
            }
            sincronizarSelector();
            hover = null;
            proyectar();
            pintar();
            mostrarInfo(null);
        },
        // La llama AL para abrir el mapa con un criterio de color ('estado', 'abc' o
        // 'caducidad') y un texto ya buscado (producto o ubicación). Deja los controles de la
        // barra igual que si el operario los hubiera elegido.
        preparar: function (criterio, texto) {
            var combo = document.getElementById('sga3d-color');
            var caja = document.getElementById('sga3d-buscar');
            if (CRITERIOS[criterio]) {
                colorear = criterio;
                if (combo) { combo.value = criterio; }
                pintarLeyenda();
            }
            busqueda = String(texto || '').trim().toUpperCase();
            if (caja) { caja.value = texto || ''; }
            mostrarInfo(null);
            pintar();
        },
        listo: function () { avisarAL('ControlListo', []); }
    };
})();
