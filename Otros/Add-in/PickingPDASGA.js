// Pantalla de picking para PDA (control add-in "Picking PDA SGA"), y del alta de stock en la PDA
// con la misma base (datos.modo 'alta', pintarAlta).
//
// Solo pinta y recoge: AL manda la parada con Mostrar y aquí se devuelve lo que hace el
// preparador con los eventos Lectura, Cantidad, Dato y Accion. Nada se valida aquí.
//
// Cada parada se confirma leyendo la ubicación de la que se recoge, en su casilla. El foco va
// a esa casilla, así que un lector que escribe como un teclado deja la lectura en su sitio.
// Mientras el preparador teclea la cantidad, el foco se queda en ella. Con el escáner de la app
// de BC (datos.escaner) las lecturas llegan a AL por su cuenta; la casilla tiene el foco
// igualmente, pero con inputmode none para que Android no abra el teclado hasta que se toque.

(function () {
    'use strict';

    var raiz = null;
    var datos = null;
    var tecleandoCantidad = false;  // el preparador está escribiendo la cantidad: no se le quita el foco
    var audio = null;
    var scrollLista = 0;            // posición de la lista de productos del alta, para no perderla al cargar más
    var esperaBusqueda = null;      // búsqueda de productos pendiente de mandar mientras se escribe

    function invocar(evento, argumentos) {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod(evento, argumentos || []);
    }

    // La cantidad se manda a AL en cuanto cambia, sin esperar: la lectura del escáner de la app
    // llega a AL por su cuenta, sin pasar por esta pantalla, y si la cantidad esperase podría
    // confirmarse la parada con la cantidad anterior.
    function cantidadCambiada(valor) {
        invocar('Cantidad', [String(valor).replace(',', '.')]);
        // AL no repinta al recibir la cantidad: la marca "Cantidad" del alta se pone aquí, en
        // verde en cuanto hay una cantidad mayor que cero.
        var hay = (parseFloat(String(valor).replace(',', '.')) || 0) > 0;
        if (datos && datos.modo === 'alta') { datos.cantidad = hay ? String(valor) : ''; }
        var marca = raiz.querySelector('[data-paso="cantidad"]');
        if (marca) {
            marca.classList.toggle('pk-hecho', hay);
            marca.textContent = (hay ? '✔ ' : '○ ') + 'Cantidad';
        }
    }

    function nodo(etiqueta, clase, texto) {
        var n = document.createElement(etiqueta);
        if (clase) { n.className = clase; }
        if (texto !== undefined && texto !== null) { n.textContent = texto; }
        return n;
    }

    function boton(texto, clase, accion) {
        var b = nodo('button', 'pk-btn ' + clase, texto);
        b.type = 'button';
        b.addEventListener('click', function () { invocar('Accion', [accion]); });
        return b;
    }

    // Bloque con el título pequeño a la izquierda de su primera línea, no encima: en una PDA
    // cada línea cuenta. Devuelve la primera línea en .linea para añadirle lo que va al lado.
    function bloque(titulo, clase) {
        var b = nodo('div', 'pk-bloque ' + (clase || ''));
        b.linea = nodo('div', 'pk-linea');
        b.linea.appendChild(nodo('span', 'pk-titulo', titulo));
        b.appendChild(b.linea);
        return b;
    }

    // Texto de una línea: si no cabe se corta con puntos suspensivos y el texto completo
    // queda en el title.
    function corto(etiqueta, clase, texto) {
        var n = nodo(etiqueta, clase + ' pk-corto', texto);
        n.title = texto;
        return n;
    }

    function paso(texto, hecho) {
        return nodo('span', 'pk-paso' + (hecho ? ' pk-hecho' : ''), (hecho ? '✔ ' : '○ ') + texto);
    }

    // Casilla de lectura. Muestra lo ya leído; Intro manda lo tecleado como una lectura.
    function campoUbicacion(valor, textoVacio) {
        var c = nodo('input', 'pk-campo pk-lectura' + (valor ? ' pk-leido' : ''));
        c.type = 'text';
        c.setAttribute('data-campo', 'ubicacion');
        c.setAttribute('autocomplete', 'off');
        c.setAttribute('autocapitalize', 'characters');
        c.placeholder = textoVacio;
        c.value = valor || '';
        // Con el escáner de la app, y siempre en el alta (donde la cantidad va con + y −), tiene
        // el foco sin abrir el teclado; al tocarla, se abre.
        if (datos.escaner || datos.modo === 'alta') { c.setAttribute('inputmode', 'none'); }
        c.addEventListener('pointerdown', function () {
            c.setAttribute('inputmode', 'text');
            // Lo ya leído se borra al tocarla, para teclear encima.
            if (c.value === (valor || '') && valor) { c.value = ''; }
        });
        c.addEventListener('keydown', function (e) {
            if (e.key !== 'Enter') { return; }
            if (c.value.trim() !== '' && c.value !== (valor || '')) {
                var texto = c.value;
                c.value = '';
                invocar('Lectura', [texto]);
            }
        });
        return c;
    }

    // Ubicación del alta de stock tecleada a mano: solo cifras, con la máscara XXX-XX-XX (los
    // guiones los pone sola) y teclado numérico. Con las 7 cifras (o con Intro) se manda a AL,
    // que comprueba el formato y que exista. Lo escrito se queda en la casilla: en verde si AL
    // la acepta, en rojo si no.
    var ubicacionEscrita = '';      // lo último tecleado en la casilla, hasta que AL lo acepta
    var ubicacionPrevia = null;     // la ubicación del alta en el pintado anterior

    function mascaraUbicacion(texto) {
        var d = String(texto).replace(/\D/g, '').substring(0, 7);
        var r = d.substring(0, 3);
        if (d.length > 3) { r += '-' + d.substring(3, 5); }
        if (d.length > 5) { r += '-' + d.substring(5, 7); }
        return r;
    }

    function campoUbicacionAlta() {
        // Una ubicación nueva puesta por AL (leída con el escáner o aceptada) manda sobre lo escrito.
        if (datos.ubicacion !== ubicacionPrevia) {
            if (datos.ubicacion) { ubicacionEscrita = ''; }
            ubicacionPrevia = datos.ubicacion;
        }
        var texto = ubicacionEscrita || datos.ubicacion || '';
        var aceptada = !!datos.ubicacion && texto === datos.ubicacion;
        var mal = !!ubicacionEscrita && !aceptada && !!datos.avisoError;
        var c = nodo('input', 'pk-campo pk-lectura pk-campo-ubicacion' + (aceptada ? ' pk-leido' : '') + (mal ? ' pk-mal' : ''));
        c.type = 'text';
        c.setAttribute('data-campo', 'ubicacionAlta');
        c.setAttribute('autocomplete', 'off');
        c.setAttribute('inputmode', 'none');
        c.maxLength = 9;
        c.placeholder = 'Ubicación (000-00-00)';
        c.value = texto;
        var enviada = '';
        function enviar() {
            if (c.value.replace(/\D/g, '').length === 0 || c.value === enviada) { return; }
            enviada = c.value;
            ubicacionEscrita = c.value;
            invocar('Dato', ['ubicacion', c.value]);
        }
        // Al tocarla: teclado numérico y, si tenía una ubicación, vacía para escribir otra.
        c.addEventListener('pointerdown', function () {
            c.setAttribute('inputmode', 'numeric');
            if (aceptada || mal) { c.value = ''; c.classList.remove('pk-leido', 'pk-mal'); }
        });
        c.addEventListener('input', function () {
            c.value = mascaraUbicacion(c.value);
            if (c.value.replace(/\D/g, '').length === 7) { enviar(); }
        });
        c.addEventListener('keydown', function (e) { if (e.key === 'Enter') { enviar(); } });
        return c;
    }

    // Cantidad con − y + y su unidad, en una fila. Cada cambio se manda a AL al momento.
    function filaCantidad(valor, unidad) {
        var fila = nodo('div', 'pk-fila');
        var cantidad = nodo('input', 'pk-campo pk-campo-cantidad');
        cantidad.type = 'number';
        cantidad.min = '0';
        cantidad.step = 'any';
        cantidad.setAttribute('data-campo', 'cantidad');
        cantidad.setAttribute('inputmode', 'decimal');
        cantidad.value = valor;
        cantidad.addEventListener('input', function () {
            tecleandoCantidad = true;
            cantidadCambiada(cantidad.value);
        });
        cantidad.addEventListener('blur', function () { tecleandoCantidad = false; });
        // Intro en la cantidad (ya enviada al teclearla) devuelve el foco a la lectura.
        cantidad.addEventListener('keydown', function (e) {
            if (e.key === 'Enter') {
                tecleandoCantidad = false;
                enfocarLectura();
            }
        });
        function sumar(delta) {
            var v = parseFloat(String(cantidad.value).replace(',', '.')) || 0;
            v = Math.max(0, v + delta);
            cantidad.value = v;
            cantidadCambiada(v);
            enfocarLectura();
        }
        var menos = nodo('button', 'pk-btn pk-mas-menos', '−');
        menos.type = 'button';
        menos.addEventListener('click', function () { sumar(-1); });
        var mas = nodo('button', 'pk-btn pk-mas-menos', '+');
        mas.type = 'button';
        mas.addEventListener('click', function () { sumar(1); });
        fila.appendChild(menos);
        fila.appendChild(cantidad);
        fila.appendChild(mas);
        if (unidad) { fila.appendChild(nodo('span', 'pk-unidad', unidad)); }
        return fila;
    }

    // El foco va a la lectura; solo se queda en la cantidad mientras se teclea.
    function enfocar(activo) {
        if (activo === 'cantidad' && tecleandoCantidad) {
            raiz.querySelector('[data-campo="cantidad"]').focus();
            return;
        }
        enfocarLectura();
    }

    // Alta de stock (página "Alta Stock PDA SGA"): de cada palé, su ubicación, su etiqueta
    // (SSCC), el producto (elegido de la lista), el
    // lote y la cantidad en la unidad que se elija. ACEPTAR lo da de alta.
    // Todo tiene que caber en la pantalla de la PDA sin desplazarse (pk-compacto): cada bloque
    // junta en una fila lo que puede (título y casilla, producto y lote, cantidad y unidad).
    function pintarAlta(activo) {
        // La ubicación en su propia casilla (campoUbicacionAlta), al lado del título: se lee o
        // se teclea; lo tecleado va como ubicación (Dato), para comprobar su formato.
        var donde = bloque('UBICACIÓN');
        var casillaDonde = campoUbicacionAlta();
        donde.linea.appendChild(casillaDonde);
        raiz.appendChild(donde);

        // El palé: la descripción, que es como se reconoce el producto, y en pequeño el código y
        // el SSCC. El producto se elige de la lista; el lote se teclea o se lee en su casilla.
        var pale = bloque('PALÉ');
        if (datos.producto) {
            var descripcion = nodo('div', 'pk-descripcion', datos.descripcion || datos.producto);
            descripcion.title = datos.descripcion || datos.producto;
            pale.appendChild(descripcion);
        }
        var detalle = [];
        if (datos.producto) { detalle.push(datos.producto); }
        if (datos.sscc) { detalle.push('SSCC ' + datos.sscc); }
        if (detalle.length > 0) { pale.appendChild(corto('div', 'pk-lote', detalle.join('  ·  '))); }
        var filaProducto = nodo('div', 'pk-otros pk-fila');
        filaProducto.appendChild(boton(datos.producto ? 'Cambiar producto' : 'Elegir producto', 'pk-secundario', 'producto'));
        var lote = nodo('input', 'pk-campo pk-lectura' + (datos.lote ? ' pk-leido' : ''));
        lote.type = 'text';
        lote.setAttribute('data-campo', 'lote');
        lote.setAttribute('autocomplete', 'off');
        lote.setAttribute('autocapitalize', 'characters');
        lote.placeholder = 'Lote';
        lote.value = datos.lote || '';
        // Se manda al salir de la casilla o con Intro (el lector que escribe como un teclado).
        function loteCambiado() {
            if (lote.value !== (datos.lote || '')) { invocar('Dato', ['lote', lote.value]); }
        }
        lote.addEventListener('change', loteCambiado);
        lote.addEventListener('keydown', function (e) {
            if (e.key === 'Enter') { loteCambiado(); }
        });
        filaProducto.appendChild(lote);
        pale.appendChild(filaProducto);
        raiz.appendChild(pale);

        // Lo que falta para aceptar, la lectura (ubicación o etiqueta del palé), la cantidad y
        // su unidad.
        var leer = bloque('LEA', 'pk-confirmar');
        leer.linea.appendChild(paso('Ubicación', datos.ubicacion !== ''));
        leer.linea.appendChild(paso('Producto', datos.producto !== ''));
        var marcaCantidad = paso('Cantidad', (parseFloat(datos.cantidad) || 0) > 0);
        marcaCantidad.setAttribute('data-paso', 'cantidad');
        leer.linea.appendChild(marcaCantidad);
        var filaLectura = nodo('div', 'pk-fila');
        filaLectura.appendChild(campoUbicacion('', 'Etiqueta del palé'));
        leer.appendChild(filaLectura);
        // La unidad, en la misma fila que la cantidad: un botón que pasa a la siguiente unidad
        // del producto (palé, caja, base) cada vez que se toca.
        var filaCant = filaCantidad(datos.cantidad, '');
        var unidades = datos.unidades || [];
        if (unidades.length > 1) {
            var siguiente = unidades[(unidades.indexOf(datos.unidad) + 1) % unidades.length];
            filaCant.appendChild(boton(datos.unidad + ' ↻', 'pk-elegido pk-cambiar-unidad', 'unidad:' + siguiente));
        } else {
            filaCant.appendChild(nodo('span', 'pk-unidad', datos.unidad));
        }
        leer.appendChild(filaCant);
        if (datos.aviso) {
            leer.appendChild(nodo('div', 'pk-aviso' + (datos.avisoError ? ' pk-aviso-error' : ''), datos.aviso));
        }
        raiz.appendChild(leer);

        raiz.appendChild(boton('ACEPTAR', 'pk-principal', 'aceptar'));
        enfocar(activo);
        // Sin ubicación, el cursor espera en su casilla (para el lector que escribe como teclado).
        if (!datos.ubicacion && !(activo === 'cantidad' && tecleandoCantidad)) { casillaDonde.focus(); }
        // Siempre desde arriba: tras ACEPTAR, lista para el palé siguiente sin volver atrás.
        raiz.scrollTop = 0;
        window.scrollTo(0, 0);
    }

    // Elegir el producto del palé en el alta de stock: la lista se filtra mientras se escribe
    // (lo escrito, en cualquier parte del código o de la descripción) y se toca la fila. Cada fila
    // es un botón grande, como el resto de la pantalla. La lista va en su propia caja con scroll,
    // debajo de la búsqueda y encima de Volver, que no se mueven. Llega de 25 en 25: al bajar
    // hasta el final se pide la tanda siguiente, y al volver a pintarla se deja donde estaba.
    // prm_Escrito trae lo que había en la casilla antes de repintar (texto y cursor): puede ir por
    // delante de la búsqueda que contesta la página si se ha seguido escribiendo.
    function pintarProductos(prm_Escrito) {
        var buscar = bloque('PRODUCTO');
        var filaBusqueda = nodo('div', 'pk-fila');
        var busqueda = nodo('input', 'pk-campo pk-lectura');
        busqueda.type = 'text';
        busqueda.setAttribute('data-campo', 'busqueda');
        busqueda.setAttribute('autocomplete', 'off');
        busqueda.placeholder = 'Código o descripción';
        busqueda.value = prm_Escrito ? prm_Escrito.texto : (datos.busqueda || '');
        function buscarProductos() {
            clearTimeout(esperaBusqueda);
            esperaBusqueda = null;
            scrollLista = 0;
            invocar('Dato', ['busqueda', busqueda.value]);
        }
        // Busca al dejar de escribir un momento, o al momento con Intro.
        busqueda.addEventListener('input', function () {
            clearTimeout(esperaBusqueda);
            esperaBusqueda = setTimeout(buscarProductos, 400);
        });
        busqueda.addEventListener('keydown', function (e) {
            if (e.key === 'Enter') { buscarProductos(); }
        });
        filaBusqueda.appendChild(busqueda);
        buscar.appendChild(filaBusqueda);
        raiz.appendChild(buscar);

        var lista = nodo('div', 'pk-lista');
        if (!datos.productos || datos.productos.length === 0) {
            lista.appendChild(nodo('div', 'pk-aviso', 'Ningún producto con esa búsqueda.'));
        }
        (datos.productos || []).forEach(function (p) {
            var fila = nodo('button', 'pk-btn pk-producto');
            fila.type = 'button';
            fila.appendChild(corto('div', 'pk-producto-desc', p.descripcion || p.no));
            fila.appendChild(nodo('div', 'pk-lote', p.no));
            fila.addEventListener('click', function () { invocar('Accion', ['elegir:' + p.no]); });
            lista.appendChild(fila);
        });
        if (datos.hayMas) {
            lista.appendChild(nodo('div', 'pk-lote pk-cargando', 'Cargando más…'));
        }
        // Una sola petición por tanda: hasta que llega la nueva lista no se pide otra.
        var pidiendo = false;
        lista.addEventListener('scroll', function () {
            scrollLista = lista.scrollTop;
            if (datos.hayMas && !pidiendo && lista.scrollTop + lista.clientHeight >= lista.scrollHeight - 80) {
                pidiendo = true;
                invocar('Accion', ['masProductos']);
            }
        });
        raiz.appendChild(lista);
        lista.scrollTop = scrollLista;

        raiz.appendChild(boton('Volver', 'pk-secundario pk-volver', 'volver'));
        // Al abrir la lista, tras buscar o si se estaba escribiendo, con el cursor donde estaba;
        // al cargar otra tanda, el teclado no debe salir.
        if (prm_Escrito || scrollLista === 0) {
            busqueda.focus();
            if (prm_Escrito) { busqueda.setSelectionRange(prm_Escrito.cursor, prm_Escrito.cursor); }
        }
    }

    function pintar() {
        var activo = document.activeElement ? document.activeElement.getAttribute('data-campo') : null;
        // Lo que se está escribiendo en la búsqueda de productos no se pierde al repintar.
        var escrito = null;
        if (activo === 'busqueda') {
            escrito = { texto: document.activeElement.value, cursor: document.activeElement.selectionStart };
        }
        raiz.innerHTML = '';
        if (!datos) { return; }
        raiz.classList.toggle('pk-compacto', datos.modo === 'alta');

        if (datos.modo === 'alta') {
            if (datos.eligiendo) {
                pintarProductos(escrito);
            } else {
                clearTimeout(esperaBusqueda);
                esperaBusqueda = null;
                scrollLista = 0;
                pintarAlta(activo);
            }
            return;
        }

        if (datos.vacia) {
            raiz.appendChild(nodo('div', 'pk-vacia', datos.mensaje || 'No hay líneas pendientes en esta orden.'));
            // En turno se puede volver a buscar: el responsable puede haberle asignado otra.
            if (datos.enTurno) { raiz.appendChild(boton('BUSCAR SIGUIENTE ORDEN', 'pk-principal', 'siguiente')); }
            return;
        }

        // Cabecera: solo el avance; el nº de orden ya sale en la barra de título de BC.
        var cab = nodo('div', 'pk-cab');
        cab.appendChild(nodo('span', 'pk-progreso', datos.progreso));
        raiz.appendChild(cab);

        // Adónde ir y dónde dejarlo, en la misma línea: el destino de una reubicación o la
        // playa de un pedido.
        var ir = bloque(datos.destino ? 'DE' : 'VAYA A', datos.destino ? 'pk-reubicacion' : '');
        ir.linea.appendChild(nodo('span', 'pk-ubicacion', datos.ubicacion));
        if (datos.destino || datos.playa) {
            ir.linea.appendChild(nodo('span', 'pk-titulo pk-a', datos.destino ? '→ A' : '→ PLAYA'));
            ir.linea.appendChild(nodo('span', 'pk-ubicacion', datos.destino || datos.playa));
        }
        raiz.appendChild(ir);

        // Qué coger. Manda lo que se coge (la cantidad), luego la descripción, que es como el
        // preparador reconoce el producto (con miles de referencias nadie se sabe los códigos),
        // y en pequeño el código, el lote, la caducidad, el palé (SSCC) y la cantidad en base.
        var coger = bloque('COJA');
        coger.linea.appendChild(nodo('span', 'pk-cantidad', datos.cantidad + ' ' + datos.unidad));
        var descripcion = nodo('div', 'pk-descripcion', datos.descripcion || datos.producto);
        descripcion.title = datos.descripcion || datos.producto;
        coger.appendChild(descripcion);
        var detalle = [];
        if (datos.descripcion) { detalle.push(datos.producto); }
        if (datos.lote) { detalle.push('Lote ' + datos.lote); }
        if (datos.lote && datos.caducidad) { detalle.push('Cad. ' + datos.caducidad); }
        if (datos.sscc) { detalle.push('SSCC ' + datos.sscc); }
        if (datos.cantidadBase) { detalle.push('= ' + datos.cantidadBase); }
        if (detalle.length > 0) { coger.appendChild(corto('div', 'pk-lote', detalle.join('  ·  '))); }
        raiz.appendChild(coger);

        // Lo que falta para confirmar, al lado del título.
        var confirmar = bloque('CONFIRME', 'pk-confirmar');
        confirmar.linea.appendChild(paso('Ubicación', datos.ubicacionLeida !== ''));

        // La ubicación es la que trae la etiqueta del hueco; se escanea o se teclea.
        var filaLectura = nodo('div', 'pk-fila');
        filaLectura.appendChild(campoUbicacion(datos.ubicacionLeida, 'Ubicación'));
        confirmar.appendChild(filaLectura);

        // Cantidad con − y + y su unidad; Confirmar va debajo, a lo ancho.
        confirmar.appendChild(filaCantidad(datos.cantidadRecogida, datos.unidad));

        if (datos.aviso) {
            confirmar.appendChild(nodo('div', 'pk-aviso' + (datos.avisoError ? ' pk-aviso-error' : ''), datos.aviso));
        }
        raiz.appendChild(confirmar);

        raiz.appendChild(boton('CONFIRMAR', 'pk-principal', 'confirmar'));

        var otros = nodo('div', 'pk-otros');
        otros.appendChild(boton('Saltar', 'pk-secundario', 'saltar'));
        otros.appendChild(boton('Sin stock', 'pk-peligro', 'sinstock'));
        raiz.appendChild(otros);

        enfocar(activo);
    }

    function enfocarLectura() {
        var campo = raiz.querySelector('[data-campo="ubicacion"]');
        if (campo) { campo.focus(); }
    }

    function senal(tipo) {
        var error = tipo === 'error';
        try {
            if (navigator.vibrate) { navigator.vibrate(error ? [120, 80, 120] : 60); }
        } catch (e) { /* Sin vibración. */ }
        try {
            var Contexto = window.AudioContext || window.webkitAudioContext;
            if (!Contexto) { return; }
            if (!audio) { audio = new Contexto(); }
            var osc = audio.createOscillator();
            var vol = audio.createGain();
            osc.frequency.value = error ? 220 : 880;
            vol.gain.value = 0.2;
            osc.connect(vol);
            vol.connect(audio.destination);
            osc.start();
            osc.stop(audio.currentTime + (error ? 0.35 : 0.1));
        } catch (e) { /* Sin sonido. */ }
    }

    // Funciones que AL invoca por nombre sobre el control.
    window.Mostrar = function (d) {
        datos = d;
        pintar();
    };

    window.Senal = function (tipo) {
        senal(tipo);
    };

    function arrancar() {
        raiz = document.getElementById('controlAddIn');
        if (!raiz) {
            // En algunos hosts el contenedor tarda un instante en existir.
            window.setTimeout(arrancar, 50);
            return;
        }
        raiz.classList.add('pk-raiz');
        invocar('Listo');
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', arrancar);
    } else {
        arrancar();
    }
})();
