// Pantalla de picking para PDA (control add-in "Picking PDA SGA").
//
// Solo pinta y recoge: AL manda la parada con Mostrar y aquí se devuelve lo que hace el
// preparador con los eventos Lectura, Cantidad y Accion. Nada se valida aquí.
//
// Cada parada se confirma en un orden fijo, con una casilla por paso: ubicación y, si se
// exige, producto. El foco va solo a la primera casilla pendiente, así que un
// lector que escribe como un teclado deja cada lectura en su sitio. Si el preparador toca una
// casilla para teclear, el foco se queda en ella hasta que la manda. Lo que se manda lo
// clasifica AL por su contenido, no por la casilla. Con el escáner de la app de BC
// (datos.escaner) las lecturas llegan a AL por su cuenta; las casillas tienen el foco igualmente,
// pero con inputmode none para que Android no abra el teclado hasta que se toquen.

(function () {
    'use strict';

    var raiz = null;
    var datos = null;
    var cantidadSinEnviar = null;
    var temporizadorCantidad = null;
    var audio = null;
    // Casilla que el preparador ha tocado para teclear: el foco se queda en ella.
    var campoManual = null;

    function invocar(evento, argumentos) {
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod(evento, argumentos || []);
    }

    // La cantidad se manda con un poco de retraso para no llamar a AL en cada tecla, pero
    // siempre antes que cualquier otra cosa: si no, una lectura que confirma la parada podría
    // llegar a AL antes que la cantidad tecleada.
    function enviarCantidad() {
        if (temporizadorCantidad) {
            window.clearTimeout(temporizadorCantidad);
            temporizadorCantidad = null;
        }
        if (cantidadSinEnviar === null) { return; }
        var valor = cantidadSinEnviar;
        cantidadSinEnviar = null;
        invocar('Cantidad', [valor]);
    }

    function enviar(evento, argumentos) {
        enviarCantidad();
        invocar(evento, argumentos);
    }

    function cantidadCambiada(valor) {
        cantidadSinEnviar = String(valor).replace(',', '.');
        if (temporizadorCantidad) { window.clearTimeout(temporizadorCantidad); }
        temporizadorCantidad = window.setTimeout(enviarCantidad, 400);
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
        b.addEventListener('click', function () { enviar('Accion', [accion]); });
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

    // Primera casilla pendiente, en el orden ubicación, producto. Con todo leído, la
    // ubicación: una lectura nueva empieza otra vez por ahí.
    function campoPendiente() {
        if (!datos.ubicacionLeida) { return 'ubicacion'; }
        if (datos.exigeProducto && !datos.productoLeido) { return 'producto'; }
        return 'ubicacion';
    }

    // Casilla de lectura. Muestra lo ya leído; Intro manda lo tecleado como una lectura, salvo
    // que la casilla traiga su propio Intro (alIntro).
    function campoLectura(nombre, clase, marcador, valor, alIntro) {
        var c = nodo('input', 'pk-campo ' + clase + (valor ? ' pk-leido' : ''));
        c.type = 'text';
        c.setAttribute('data-campo', nombre);
        c.setAttribute('autocomplete', 'off');
        c.setAttribute('autocapitalize', 'characters');
        c.placeholder = marcador;
        c.value = valor || '';
        // Con el escáner de la app tiene el foco sin abrir el teclado; al tocarla, se abre.
        if (datos.escaner) { c.setAttribute('inputmode', 'none'); }
        c.addEventListener('pointerdown', function () {
            campoManual = nombre;
            c.setAttribute('inputmode', 'text');
            // Lo ya leído se borra al tocarla, para teclear encima.
            if (c.value === (valor || '') && valor) { c.value = ''; }
        });
        c.addEventListener('keydown', function (e) {
            if (e.key !== 'Enter') { return; }
            if (alIntro) { alIntro(); return; }
            if (c.value.trim() !== '' && c.value !== (valor || '')) {
                var texto = c.value;
                c.value = '';
                campoManual = null;
                enviar('Lectura', [texto]);
            }
        });
        return c;
    }

    function pintar() {
        var activo = document.activeElement ? document.activeElement.getAttribute('data-campo') : null;
        raiz.innerHTML = '';
        if (!datos) { return; }

        if (datos.vacia) {
            raiz.appendChild(nodo('div', 'pk-vacia', datos.mensaje || 'No hay paradas pendientes en esta orden.'));
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
        if (datos.exigeProducto) { confirmar.linea.appendChild(paso('Producto', datos.productoLeido !== '')); }

        // La ubicación es la que trae la etiqueta del hueco; se escanea o se teclea.
        var filaLectura = nodo('div', 'pk-fila');
        filaLectura.appendChild(campoLectura('ubicacion', 'pk-lectura', 'Ubicación', datos.ubicacionLeida));
        confirmar.appendChild(filaLectura);

        if (datos.exigeProducto) {
            var filaProducto = nodo('div', 'pk-fila');
            filaProducto.appendChild(campoLectura('producto', 'pk-lectura', 'Producto', datos.productoLeido));
            confirmar.appendChild(filaProducto);
        }

        // Cantidad con − y + y su unidad; Confirmar va debajo, a lo ancho.
        var filaCantidad = nodo('div', 'pk-fila');
        var cantidad = nodo('input', 'pk-campo pk-campo-cantidad');
        cantidad.type = 'number';
        cantidad.min = '0';
        cantidad.step = 'any';
        cantidad.setAttribute('data-campo', 'cantidad');
        cantidad.setAttribute('inputmode', 'decimal');
        cantidad.value = datos.cantidadRecogida;
        cantidad.addEventListener('input', function () { cantidadCambiada(cantidad.value); });
        // Intro en la cantidad la manda y devuelve el foco a la lectura.
        cantidad.addEventListener('keydown', function (e) {
            if (e.key === 'Enter') {
                enviarCantidad();
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
        filaCantidad.appendChild(menos);
        filaCantidad.appendChild(cantidad);
        filaCantidad.appendChild(mas);
        filaCantidad.appendChild(nodo('span', 'pk-unidad', datos.unidad));
        confirmar.appendChild(filaCantidad);

        if (datos.aviso) {
            confirmar.appendChild(nodo('div', 'pk-aviso' + (datos.avisoError ? ' pk-aviso-error' : ''), datos.aviso));
        }
        raiz.appendChild(confirmar);

        raiz.appendChild(boton('CONFIRMAR', 'pk-principal', 'confirmar'));

        var otros = nodo('div', 'pk-otros');
        otros.appendChild(boton('Saltar', 'pk-secundario', 'saltar'));
        otros.appendChild(boton('Sin stock', 'pk-peligro', 'sinstock'));
        raiz.appendChild(otros);

        // El foco va a la primera casilla pendiente. Solo se queda donde está mientras se teclea
        // la cantidad, o en la casilla que el preparador ha tocado para teclear.
        if (activo === 'cantidad' && temporizadorCantidad) {
            raiz.querySelector('[data-campo="cantidad"]').focus();
            return;
        }
        enfocarLectura();
    }

    function enfocarLectura() {
        // La casilla tocada a mano deja de mandar en cuanto ya tiene su lectura (p. ej. llegó
        // por el escáner de la app).
        var leido = { ubicacion: datos.ubicacionLeida, producto: datos.productoLeido };
        if (campoManual && leido[campoManual]) { campoManual = null; }
        var nombre = campoManual || campoPendiente();
        var campo = raiz.querySelector('[data-campo="' + nombre + '"]');
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
