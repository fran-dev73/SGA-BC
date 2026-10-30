// Mapa 3D del almacén para SGA.
//
// Dibuja cada ubicación como un cubo en proyección isométrica sobre un canvas 2D. No usa
// ninguna librería externa a propósito: la política de contenido de Business Central bloquea
// los recursos de fuera, así que una dependencia de CDN dejaría el panel en blanco.
//
// Ejes del almacén: estantería (profundidad), columna (anchura) y altura (vertical).
//
// Las estanterías se dibujan separadas entre sí, como los pasillos de un almacén real. Un
// bloque macizo esconde sus cubos interiores y no hay ángulo desde el que verlos; separando
// las estanterías se llega a todas girando alrededor.

var SGA3D = (function () {
    'use strict';

    var canvas = null;
    var ctx = null;
    var ubicaciones = [];   // datos crudos que llegan de AL
    var cubos = [];         // cubos ya proyectados, ordenados de atrás a adelante
    var rotulos = [];       // carteles de pasillo, proyectados igual que los cubos
    var angulo = 0;         // giro libre alrededor del eje vertical, en radianes
    var escala = 1;
    var panX = 0;
    var panY = 0;
    var modoArrastre = '';  // 'girar' o 'mover'
    var ultimoX = 0;
    var ultimoY = 0;
    var hover = null;
    var seHaMovido = false;
    var separarPasillos = true;
    var verEtiquetas = true;
    var pasilloActivo = '';  // estantería aislada; vacío = se ven todas
    var pasillos = [];       // estanterías presentes en los datos, ordenadas

    // Traslado arrastrando: con el botón "Trasladar" activo (o Ctrl pulsado) arrastrar no gira,
    // sino que lleva una ubicación hasta otra. El lienzo solo avisa a AL; no mueve nada.
    var modoTraslado = false;
    var origenTraslado = null;   // cubo del que sale la mercancía
    var destinoTraslado = null;  // cubo sobre el que está el ratón al arrastrar
    var ratonX = 0;
    var ratonY = 0;

    // Ancho y alto de la base del cubo en pantalla, y altura del bloque.
    var ANCHO = 22;
    var ALTO = 11;
    var GRUESO = 16;

    // Cuánto se separan las estanterías entre sí. 1 = pegadas (bloque macizo).
    var SEPARACION = 2.6;

    // Límites del zoom. El máximo es alto a propósito: un pasillo aislado se encuadra a lo
    // que haga falta para que sus huecos se vean grandes y se lea lo que hay dentro.
    var ESCALA_MIN = 0.15;
    var ESCALA_MAX = 12;

    // A partir de este ancho de cubo (en píxeles) se escribe también el producto encima.
    var ANCHO_PARA_PRODUCTO = 34;

    // Colores por estado, en el mismo orden que el enum de AL:
    // 0 vacía, 1 parcial, 2 llena, 3 bloqueada.
    var PALETA = [
        { techo: '#d9dde3', izq: '#aeb4bd', der: '#c3c9d1', texto: '#3a4048' },
        { techo: '#7cc47f', izq: '#4e8a51', der: '#68ab6b', texto: '#16351a' },
        { techo: '#e8a33d', izq: '#a86f1e', der: '#cc8b2c', texto: '#3d2606' },
        { techo: '#d9534f', izq: '#93302d', der: '#bb4340', texto: '#ffffff' }
    ];

    // Colores del traslado: de dónde sale (azul) y a dónde va (amarillo).
    var COLOR_ORIGEN = { techo: '#60a5fa', izq: '#2563eb', der: '#3b82f6', texto: '#ffffff' };
    var COLOR_DESTINO = { techo: '#fde047', izq: '#ca8a04', der: '#eab308', texto: '#1f2937' };

    function crear(idContenedor) {
        var cont = document.getElementById(idContenedor);
        if (!cont) { return; }

        cont.innerHTML =
            '<div class="sga3d-barra">' +
            '  <button type="button" class="sga3d-btn" data-accion="girar">Girar 45°</button>' +
            '  <button type="button" class="sga3d-btn" data-accion="acercar">+</button>' +
            '  <button type="button" class="sga3d-btn" data-accion="alejar">-</button>' +
            '  <button type="button" class="sga3d-btn" data-accion="centrar">Centrar</button>' +
            '  <button type="button" class="sga3d-btn sga3d-on" data-accion="pasillos">Pasillos</button>' +
            '  <button type="button" class="sga3d-btn sga3d-on" data-accion="etiquetas">Nº ubicación</button>' +
            '  <button type="button" class="sga3d-btn" data-accion="trasladar" title="Arrastre una ubicación con contenido hasta otra para trasladarlo. También con Ctrl+arrastrar.">Trasladar</button>' +
            '  <span class="sga3d-sel">Pasillo:' +
            '    <button type="button" class="sga3d-btn sga3d-mini" data-accion="anterior">&lt;</button>' +
            '    <select class="sga3d-combo" id="sga3d-pasillo"><option value="">Todos</option></select>' +
            '    <button type="button" class="sga3d-btn sga3d-mini" data-accion="siguiente">&gt;</button>' +
            '  </span>' +
            '  <span class="sga3d-leyenda">' +
            '    <i class="sga3d-m sga3d-m0"></i>vacía' +
            '    <i class="sga3d-m sga3d-m1"></i>con hueco' +
            '    <i class="sga3d-m sga3d-m2"></i>llena' +
            '    <i class="sga3d-m sga3d-m3"></i>bloqueada' +
            '  </span>' +
            '  <span class="sga3d-ayuda" id="sga3d-ayuda">Arrastre para girar · Mayús+arrastre para mover · Ctrl+arrastre para trasladar · clic derecho para vaciar · rueda para acercar</span>' +
            '  <span class="sga3d-info" id="sga3d-info"></span>' +
            '</div>' +
            '<canvas class="sga3d-canvas"></canvas>' +
            '<div class="sga3d-tip" id="sga3d-tip"></div>';

        canvas = cont.querySelector('canvas');
        ctx = canvas.getContext('2d');

        cont.querySelector('.sga3d-barra').addEventListener('click', function (e) {
            var accion = e.target.getAttribute('data-accion');
            if (!accion) { return; }
            if (accion === 'girar') { angulo += Math.PI / 4; }
            if (accion === 'acercar') { escala = Math.min(escala * 1.25, ESCALA_MAX); }
            if (accion === 'alejar') { escala = Math.max(escala / 1.25, ESCALA_MIN); }
            // Centrar encuadra lo que se está viendo: el almacén entero o el pasillo aislado.
            if (accion === 'centrar') { angulo = 0; encuadrar(); return; }
            if (accion === 'pasillos') {
                separarPasillos = !separarPasillos;
                e.target.className = 'sga3d-btn' + (separarPasillos ? ' sga3d-on' : '');
            }
            if (accion === 'etiquetas') {
                verEtiquetas = !verEtiquetas;
                e.target.className = 'sga3d-btn' + (verEtiquetas ? ' sga3d-on' : '');
            }
            if (accion === 'trasladar') {
                modoTraslado = !modoTraslado;
                e.target.className = 'sga3d-btn' + (modoTraslado ? ' sga3d-on' : '');
                canvas.classList.toggle('sga3d-trasladar', modoTraslado);
                document.getElementById('sga3d-ayuda').textContent = modoTraslado
                    ? 'Arrastre una ubicación con contenido hasta otra para trasladarlo'
                    : 'Arrastre para girar · Mayús+arrastre para mover · Ctrl+arrastre para trasladar · clic derecho para vaciar · rueda para acercar';
                return;
            }
            if (accion === 'anterior') { saltarPasillo(-1); return; }
            if (accion === 'siguiente') { saltarPasillo(1); return; }
            proyectar();
            pintar();
        });

        cont.querySelector('#sga3d-pasillo').addEventListener('change', function (e) {
            aislarPasillo(e.target.value);
        });

        canvas.addEventListener('mousedown', function (e) {
            seHaMovido = false;
            ultimoX = e.clientX;
            ultimoY = e.clientY;

            // Traslado: solo se puede arrastrar desde una ubicación que tenga algo dentro.
            // Fuera de un cubo, o desde uno vacío, no hace nada: así no se gira sin querer.
            if (modoTraslado || e.ctrlKey) {
                var c = cuboEn(e);
                modoArrastre = '';
                if (c && c.u.l > 0) {
                    modoArrastre = 'trasladar';
                    origenTraslado = c;
                    destinoTraslado = null;
                    e.preventDefault();
                }
                return;
            }

            // Arrastrar gira la nave; con Mayús se desplaza, que es lo que hacía antes.
            modoArrastre = e.shiftKey ? 'mover' : 'girar';
        });

        window.addEventListener('mouseup', function () {
            if (modoArrastre === 'trasladar') {
                terminarTraslado();
            }
            modoArrastre = '';
        });

        canvas.addEventListener('mousemove', function (e) {
            if (modoArrastre === 'trasladar') {
                var r = canvas.getBoundingClientRect();
                ratonX = e.clientX - r.left;
                ratonY = e.clientY - r.top;
                seHaMovido = true;
                var c = cuboEn(e);
                destinoTraslado = (c && c.u.b !== origenTraslado.u.b) ? c : null;
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
                    panX += dx;
                    panY += dy;
                    pintar();
                } else {
                    angulo += dx * 0.012;
                    proyectar();
                    pintar();
                }
                return;
            }
            var antes = hover;
            hover = cuboEn(e);
            if (hover !== antes) {
                mostrarInfo(hover);
                pintar();
            }
            // La ficha sigue al ratón aunque el bloque no cambie.
            mostrarFicha(hover, e);
        });

        canvas.addEventListener('mouseleave', function () {
            // Soltar fuera del mapa no traslada a ningún sitio.
            destinoTraslado = null;
            hover = null;
            mostrarInfo(null);
            mostrarFicha(null);
            pintar();
        });

        // La rueda acerca hacia donde apunta el ratón, no hacia el centro: así se entra en la
        // zona del pasillo que interesa sin tener que desplazar después.
        canvas.addEventListener('wheel', function (e) {
            e.preventDefault();
            var factor = e.deltaY < 0 ? 1.15 : 1 / 1.15;
            var nueva = Math.max(ESCALA_MIN, Math.min(escala * factor, ESCALA_MAX));
            factor = nueva / escala;
            if (factor === 1) { return; }

            // Las posiciones de los cubos son proporcionales a la escala alrededor del centro
            // de pantalla, así que basta con corregir el desplazamiento.
            var r = canvas.getBoundingClientRect();
            var o = centroPantalla();
            var mx = e.clientX - r.left;
            var my = e.clientY - r.top;
            panX += (mx - o.x) * (1 - factor);
            panY += (my - o.y) * (1 - factor);

            escala = nueva;
            mostrarFicha(null);
            proyectar();
            pintar();
        }, { passive: false });

        // Un clic limpio (sin arrastre) abre el contenido de la ubicación en BC.
        canvas.addEventListener('click', function (e) {
            if (seHaMovido) { return; }
            var c = cuboEn(e);
            if (c) { avisarAL('CeldaPulsada', [c.u.b]); }
        });

        // Clic derecho sobre un bloque con contenido: pedir a AL que lo vacíe (queda sin
        // ubicar). AL confirma antes; aquí solo se avisa. Sin contenido no hace nada.
        canvas.addEventListener('contextmenu', function (e) {
            e.preventDefault();
            var c = cuboEn(e);
            if (c && c.u.l > 0) {
                mostrarFicha(null);
                avisarAL('VaciarSolicitado', [c.u.b]);
            }
        });

        // Doble clic: aísla el pasillo de ese cubo. Es la forma rápida de meterse en un
        // pasillo del medio, que de otro modo queda tapado por los de delante.
        canvas.addEventListener('dblclick', function (e) {
            var c = cuboEn(e);
            if (c) { aislarPasillo(String(c.u.e)); }
        });

        window.addEventListener('resize', function () { ajustarTamano(); pintar(); });

        ajustarTamano();
    }

    function ajustarTamano() {
        if (!canvas) { return; }
        var r = canvas.parentElement.getBoundingClientRect();
        // Se descuenta la altura real de la barra de botones (puede ocupar dos líneas en
        // pantallas estrechas); el resto es todo para las estanterías.
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

    // Deja a la vista un solo pasillo. Con una única estantería no hay nada delante que la
    // tape, así que se llega a todos sus huecos; con el almacén entero, los pasillos del
    // medio quedan escondidos por mucho que se gire.
    function aislarPasillo(estanteria) {
        pasilloActivo = estanteria || '';
        sincronizarSelector();
        // El pasillo se encuadra solo: crece hasta llenar el lienzo, que es lo que permite
        // trabajar hueco a hueco. Al volver a "Todos" se encuadra el almacén entero.
        encuadrar();
        // La página acompaña el filtro para que sus acciones vayan sobre este pasillo.
        avisarAL('PasilloSeleccionado', [pasilloActivo ? pad2(Number(pasilloActivo)) : '']);
    }

    // Ajusta zoom y desplazamiento para que lo visible (un pasillo o el almacén) llene el
    // lienzo con un pequeño margen. Se proyecta a escala 1 para medir y luego se escala: las
    // posiciones de los cubos son proporcionales a la escala.
    function encuadrar() {
        escala = 1;
        panX = 0;
        panY = 0;
        proyectar();
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

        var w = canvas.width / (window.devicePixelRatio || 1);
        var h = canvas.height / (window.devicePixelRatio || 1);
        var ancho = Math.max(maxX - minX, 1);
        var alto = Math.max(maxY - minY, 1);
        escala = Math.min((w * 0.92) / ancho, (h * 0.88) / alto);
        escala = Math.max(ESCALA_MIN, Math.min(escala, ESCALA_MAX));

        // El centro de lo que se ve, a la nueva escala, va al centro del lienzo.
        panX = -((minX + maxX) / 2) * escala;
        panY = -((minY + maxY) / 2) * escala;

        proyectar();
        pintar();
    }

    function saltarPasillo(paso) {
        if (!pasillos.length) { return; }
        var i = pasillos.indexOf(pasilloActivo);
        if (i < 0) {
            // Desde "Todos" se entra por el primero o por el último, según el sentido.
            aislarPasillo(paso > 0 ? pasillos[0] : pasillos[pasillos.length - 1]);
            return;
        }
        i += paso;
        if (i < 0 || i >= pasillos.length) { aislarPasillo(''); return; }
        aislarPasillo(pasillos[i]);
    }

    function sincronizarSelector() {
        var sel = document.getElementById('sga3d-pasillo');
        if (!sel) { return; }

        var html = '<option value="">Todos</option>';
        for (var i = 0; i < pasillos.length; i++) {
            html += '<option value="' + pasillos[i] + '">Est. ' + pad2(Number(pasillos[i])) + '</option>';
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
    }

    function visible(u) {
        return !pasilloActivo || String(u.e) === pasilloActivo;
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

    function proyectar() {
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
            var p = aPantalla(g.e, g.c, u.a);
            cubos.push({
                u: u,
                x: p.x,
                y: p.y,
                // La profundidad decide el orden de pintado: lo de detrás primero, para que
                // lo de delante lo tape y el volumen se lea bien.
                z: g.c + g.e + u.a * 0.01
            });
        }

        cubos.sort(function (a, b) { return a.z - b.z; });

        if (separarPasillos) {
            proyectarRotulos(minE, maxE, minC, sep, centroE, centroC);
        }
    }

    // Un cartel por estantería, delante de su primera columna, para saber en qué pasillo se
    // está mirando cuando la nave se gira.
    function proyectarRotulos(minE, maxE, minC, sep, centroE, centroC) {
        var vistas = {};
        for (var i = 0; i < ubicaciones.length; i++) {
            var u = ubicaciones[i];
            if (!visible(u)) { continue; }
            if (vistas[u.e]) { continue; }
            vistas[u.e] = true;

            var g = girar(u.e * sep - centroE, (minC - 1.5) - centroC);
            var p = aPantalla(g.e, g.c, 0);
            rotulos.push({ texto: 'Est. ' + pad2(u.e), x: p.x, y: p.y, z: g.c + g.e });
        }
    }

    function pad2(n) {
        return (n < 10 ? '0' : '') + n;
    }

    function centroPantalla() {
        var w = canvas.width / (window.devicePixelRatio || 1);
        var h = canvas.height / (window.devicePixelRatio || 1);
        return { x: w / 2 + panX, y: h / 2 + panY };
    }

    function pintar() {
        if (!ctx) { return; }
        var w = canvas.width / (window.devicePixelRatio || 1);
        var h = canvas.height / (window.devicePixelRatio || 1);

        ctx.clearRect(0, 0, w, h);

        if (!cubos.length) {
            ctx.fillStyle = '#6b7280';
            ctx.font = '13px Segoe UI, sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('No hay ubicaciones que dibujar con este filtro.', w / 2, h / 2);
            return;
        }

        var o = centroPantalla();
        var a = ANCHO * escala;
        var b = ALTO * escala;
        var g = GRUESO * escala;

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
                if (ctx.measureText(codigoLargo(cubos[0].u)).width <= anchoUtil) {
                    modoTexto = 'largo';
                } else if (ctx.measureText('88').width <= anchoUtil) {
                    modoTexto = 'corto';
                }
            }
        }

        for (var i = 0; i < cubos.length; i++) {
            var cu = cubos[i];
            var col = PALETA[cu.u.s] || PALETA[0];
            var px = o.x + cu.x;
            var py = o.y + cu.y;
            var resaltado = hover && hover.u.b === cu.u.b;

            // Mientras se arrastra un traslado, el origen y el destino llevan su propio color.
            if (modoArrastre === 'trasladar') {
                resaltado = false;
                if (origenTraslado && origenTraslado.u.b === cu.u.b) { col = COLOR_ORIGEN; }
                if (destinoTraslado && destinoTraslado.u.b === cu.u.b) { col = COLOR_DESTINO; }
            }

            // Fuera de pantalla no se dibuja: con miles de cubos es la diferencia entre que
            // gire suelto o a tirones.
            if (px < -a * 2 || px > w + a * 2 || py < -g * 3 || py > h + g * 3) { continue; }

            // Cara superior
            ctx.beginPath();
            ctx.moveTo(px, py - b);
            ctx.lineTo(px + a, py);
            ctx.lineTo(px, py + b);
            ctx.lineTo(px - a, py);
            ctx.closePath();
            ctx.fillStyle = resaltado ? '#ffffff' : col.techo;
            ctx.fill();

            // Cara izquierda
            ctx.beginPath();
            ctx.moveTo(px - a, py);
            ctx.lineTo(px, py + b);
            ctx.lineTo(px, py + b + g);
            ctx.lineTo(px - a, py + g);
            ctx.closePath();
            ctx.fillStyle = resaltado ? '#d0d7de' : col.izq;
            ctx.fill();

            // Cara derecha
            ctx.beginPath();
            ctx.moveTo(px + a, py);
            ctx.lineTo(px, py + b);
            ctx.lineTo(px, py + b + g);
            ctx.lineTo(px + a, py + g);
            ctx.closePath();
            ctx.fillStyle = resaltado ? '#e8edf2' : col.der;
            ctx.fill();

            if (escala > 0.5) {
                ctx.strokeStyle = 'rgba(0,0,0,0.18)';
                ctx.lineWidth = 1;
                ctx.stroke();
            }

            if (modoTexto) {
                ctx.fillStyle = resaltado ? '#111827' : col.texto;
                ctx.font = tamLetra + 'px Segoe UI, sans-serif';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillText(modoTexto === 'largo' ? codigoLargo(cu.u) : String(cu.u.c), px, py);
            }

            // Con el cubo grande (pasillo encuadrado o mucho zoom) se escribe el producto en
            // la cara frontal; si hay más de uno, cuántos más. El detalle está en la ficha.
            if (a >= ANCHO_PARA_PRODUCTO && cu.u.k && cu.u.k.length) {
                var prod = cu.u.k[0].p + (cu.u.l > 1 ? ' +' + (cu.u.l - 1) : '');
                ctx.fillStyle = col.texto;
                ctx.font = 'bold ' + Math.round(Math.min(a * 0.3, 14)) + 'px Segoe UI, sans-serif';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillText(prod, px, py + b + g / 2, a * 1.9);
            }
        }

        pintarRotulos(o, w, h);
        pintarTraslado(o);
    }

    // Línea desde el bloque de origen hasta el ratón, con una punta, mientras se arrastra.
    function pintarTraslado(o) {
        if (modoArrastre !== 'trasladar' || !origenTraslado) { return; }

        var x0 = o.x + origenTraslado.x;
        var y0 = o.y + origenTraslado.y;
        var x1 = ratonX;
        var y1 = ratonY;
        if (destinoTraslado) {
            x1 = o.x + destinoTraslado.x;
            y1 = o.y + destinoTraslado.y;
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
            '<span>' + (u.o || 0) + '% ocupada</span></div>';

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
                    ' líneas más. Pulse el bloque para verlas todas.</div>';
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
        el.textContent = 'Trasladar ' + origenTraslado.u.b + ' → ' +
            (destinoTraslado ? destinoTraslado.u.b : '…');
    }

    // Dentro de un pasillo la estantería y la altura ya se ven por la posición, así que lo
    // que identifica al hueco es la columna. Cuando cabe, se pone el código completo.
    function codigoLargo(u) {
        return u.b;
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

    function mostrarInfo(cu) {
        var el = document.getElementById('sga3d-info');
        if (!el) { return; }
        if (!cu) { el.textContent = ''; return; }
        var t = cu.u.b;
        if (cu.u.d) { t += '  ·  ' + cu.u.d; }
        t += '  ·  ' + cu.u.o + '% ocupada';
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
        // La llama AL con el JSON de ubicaciones.
        cargar: function (json) {
            try {
                ubicaciones = JSON.parse(json) || [];
            } catch (err) {
                ubicaciones = [];
            }
            angulo = 0; pasilloActivo = '';
            listarPasillos();
            sincronizarSelector();
            ajustarTamano();
            encuadrar();
        },
        // Como cargar, pero conservando giro, zoom, desplazamiento y pasillo aislado: tras un
        // traslado el operario sigue mirando lo mismo, ya con los colores al día.
        refrescar: function (json) {
            try {
                ubicaciones = JSON.parse(json) || [];
            } catch (err) {
                return;
            }
            listarPasillos();
            if (pasilloActivo && pasillos.indexOf(pasilloActivo) < 0) { pasilloActivo = ''; }
            sincronizarSelector();
            hover = null;
            proyectar();
            pintar();
        },
        listo: function () { avisarAL('ControlListo', []); }
    };
})();
