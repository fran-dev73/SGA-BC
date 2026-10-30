// Arranque del control add-in del mapa 3D.
//
// Business Central crea un contenedor con el id del control y ejecuta este script. Aquí solo
// se monta el lienzo y se avisa a AL de que ya puede mandar los datos: si se pidieran antes,
// llegarían a un canvas que todavía no existe.

(function () {
    'use strict';

    var ID = 'controlAddIn';

    function arrancar() {
        var cont = document.getElementById(ID);
        if (!cont) {
            // En algunos hosts el contenedor tarda un instante en existir.
            window.setTimeout(arrancar, 50);
            return;
        }

        cont.classList.add('sga3d-raiz');
        SGA3D.crear(ID);
        estirarHastaAbajo();
        SGA3D.listo();
    }

    // BC da al iframe la altura pedida (RequestedHeight) y, con el grupo de filtros encima,
    // no lo estira: el mapa se quedaba a media pantalla. Aquí se alarga el iframe hasta el
    // borde inferior de la ventana. Se revisa cada poco porque BC vuelve a ponerle su altura
    // al redimensionar y porque plegar los filtros mueve el iframe sin redimensionar nada.
    var MARGEN_INFERIOR = 16;
    var ALTO_MINIMO = 560;

    function estirarHastaAbajo() {
        var marco, padre;
        try {
            marco = window.frameElement;
            padre = window.parent;
        } catch (e) {
            return; // Iframe de otro origen: se queda con la altura que dé BC.
        }
        if (!marco || !padre) { return; }

        function aplicar() {
            // Posición sin el desplazamiento de la página: si no, al bajar la página el
            // iframe crecería y habría más página que bajar.
            var arriba = marco.getBoundingClientRect().top;
            for (var el = marco.parentElement; el; el = el.parentElement) {
                arriba += el.scrollTop || 0;
            }
            var alto = Math.max(ALTO_MINIMO, Math.floor(padre.innerHeight - arriba - MARGEN_INFERIOR));
            if (marco.style.height === alto + 'px') { return; }

            marco.style.height = alto + 'px';
            marco.style.maxHeight = 'none';
            if (marco.parentElement) {
                marco.parentElement.style.height = alto + 'px';
                marco.parentElement.style.maxHeight = 'none';
            }
        }

        aplicar();
        padre.addEventListener('resize', aplicar);
        window.setInterval(aplicar, 500);
    }

    // Funciones que AL invoca por nombre sobre el control.
    window.Dibujar = function (datos) {
        SGA3D.cargar(datos);
    };

    window.Actualizar = function (datos) {
        SGA3D.refrescar(datos);
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', arrancar);
    } else {
        arrancar();
    }
})();
