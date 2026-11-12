pragma Singleton
import QtQuick
import QtQuick.Window
import Quickshell

/** Tokens de duración y easing basados en Ricelin y las curvas de Material 3/Apple.
 * `mult` aplica reduce-motion; `staggerIndex(i)` escalona las entradas de listas.
 */
Singleton {
    id: root

    readonly property real mult: (Flags.reduceMotion ? 0.28 : 1) * Flags.motionScale

    readonly property real pullThreshold: 6
    readonly property real pullFling: 0.35 // px/ms at scale 1
    readonly property int pullSampleWindow: 80
    readonly property int pullScrollTimeout: 120
    readonly property real pullOverdrag: 40
    readonly property real pullUnderdrag: 10

    // durations (ms)
    readonly property int fast:       Math.round(140 * mult)
    readonly property int standard:   Math.round(250 * mult)
    readonly property int morph:      Math.round(420 * mult)
    // Cierre del launcher en dos fases (resultados -> buscador, buscador -> pill):
    // ~370 ms en total en vez de ~670 ms (P1-2 del QA visual 2026-10-30).
    // Swap de surface: el contenido saliente se retira en 90 ms (el entrante ya se
    // revela con el crecimiento, ver openContentStart).
    readonly property int crossfadeOut: Math.round(90 * mult)
    readonly property int launcherCloseResults: Math.round(120 * mult)
    readonly property int launcherCloseReturn:  Math.round(250 * mult)
    readonly property int shapeshift: Math.round(820 * mult)
    readonly property int glide:      Math.round(260 * mult)
    readonly property int heat:       Math.round(1100 * mult)
    readonly property int pulse:      Math.round(420 * mult)
    readonly property int spinner:    Math.round(1000 * mult)   // busy spinner, one turn
    readonly property int breathe:    Math.round(3000 * mult)   // "lo vivo respira" (eco waybar 3.4s)

    // ── duraciones por rol (Material 3 / caelestia) ──
    readonly property int standardSmall:  Math.round(200 * mult)  // botones, chips
    readonly property int standardLarge:  Math.round(400 * mult)  // paneles, tarjetas
    readonly property int emphasized:     Math.round(350 * mult)  // notifs, surfaces
    readonly property int emphasizedLarge: Math.round(500 * mult) // morph de superficies

    // easings (Easing enums para las formas sin bezier)
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeMorph:    Easing.BezierSpline
    readonly property int easeInOut:    Easing.InOutCubic
    readonly property int easeBreathe:  Easing.InOutSine  // loops that breathe or pulse

    // cubic-bezier como [p1x,p1y, p2x,p2y, 1,1] (formato QML BezierSpline, 3 pts)
    // morphCurve: cubic-bezier(0.25, 1, 0.25, 1) — Apple-like, settle rápido sin bounce
    readonly property var morphCurve:  [0.25, 1, 0.25, 1, 1, 1]
    readonly property var bounceCurve: [0.2, 1.05, 0.35, 1.05, 1, 1]   // hypr bounceIn, minimal overshoot
    readonly property var slingCurve:  [0.35, -0.25, 0.15, 1.1, 1, 1] // hypr slingShot, softer
    readonly property var softFluid:   [0.2, 1, 0.2, 1, 1, 1]          // hypr softFluid
    // easeOut: cubic-bezier(0.25, 1, 0.5, 1) — settle natural, sin bounce
    readonly property var easeOut:     [0.25, 1, 0.5, 1, 1, 1]

    // ── curvas emphasized (Material 3 / Apple) ──
    // Entrada: cubic-bezier(0.05, 0.7, 0.1, 1.0) — arranque rápido, aterrizaje largo.
    readonly property var emphasizedDecelCurve: [0.05, 0.7, 0.1, 1.0, 1, 1]
    // Salida: cubic-bezier(0.3, 0.0, 0.8, 0.15) — se acelera hacia afuera.
    readonly property var emphasizedAccelCurve: [0.3, 0.0, 0.8, 0.15, 1, 1]
    // Standard decel/accel: cubic-bezier(0, 0, 0, 1) y (0.3, 0, 1, 1).
    readonly property var standardDecelCurve: [0, 0, 0, 1, 1, 1]
    readonly property var standardAccelCurve: [0.3, 0, 1, 1, 1, 1]

    // Shared control grammar. Reduced motion keeps color feedback, no travel.
    readonly property int hover: Math.round(120 * mult)
    readonly property int press: Math.round(70 * mult)
    readonly property int iconGesture: Flags.reduceMotion ? 0 : Math.round(650 * Flags.motionScale)
    readonly property int iconSwap: Flags.reduceMotion ? 0 : Math.round(190 * mult)
    readonly property real iconLift: Flags.reduceMotion ? 0 : 1.5
    readonly property real iconEmphasisSubtle: 0.025
    readonly property real iconEmphasis: 0.045
    readonly property real iconEmphasisStrong: 0.065
    readonly property real labelTravel: Flags.reduceMotion ? 0 : 1
    readonly property real gripScale: 1.08
    readonly property real iconTravel: Flags.reduceMotion ? 0 : 2
    readonly property real pressScaleSmall: 0.96
    readonly property real pressScale: 0.975
    readonly property real pressScaleExpressive: 0.965
    readonly property real controlSpring: Math.min(5, 4 / Flags.motionScale)
    readonly property real controlDamping: 0.35

    // radii
    readonly property real rSmall: 7
    readonly property real rTile:  13

    // ---- stagger de entrada (surfaces) ----
    // retraso por elemento en ms. `staggerIndex(i)` para el Timer/delegate.
    readonly property int staggerStep: Math.round(36 * mult)
    readonly property int staggerMax:  Math.round(360 * mult)   // cap total del stagger
    function stagger(i) { return Math.min(root.staggerMax, Math.round((i || 0) * root.staggerStep)) }

    // ---- Spring physics para el morph Dynamic Island (notifs) ----
    // Masa fija 1.0 (QML SpringAnimation usa masa implícita). damping/stiffness
    // afinados para spring visible con 2-3 oscilaciones antes de asentarse.
    // reduce-motion (mult < 1) → damping sube, stiffness baja = asentamiento rápido.
    readonly property real springMass: 1.0
    readonly property real springDamping: Flags.reduceMotion ? 28 : 15
    readonly property real springStiffness: Flags.reduceMotion ? 480 : 420
    readonly property real springVelocity: 0

    // ---- Materialización de surfaces: muelle físico de la geometría ----
    // Integrado por PillMorphMotion (omega en rad/s, zeta adimensional). Más allá del
    // destino (omegaFar/zetaFar, mezcla suave en `band` * recorrido) el muelle se
    // endurece: rebasa ~3 % y se asienta en ~600 ms, algo que un zeta constante no
    // logra. El alto es algo más blando que el ancho (t90 ~40 ms después).
    // open = rest/otra surface -> surface; resize = misma surface cambia de tamaño;
    // close = vuelta al reposo (ancho sin rebasar, alto con retroceso < 0.5 %).
    // La notificación y el aviso de workspace no usan este muelle.
    readonly property var surfaceSpring: ({
        "open": {
            "w": { "omega": 9.0, "zeta": 0.60, "omegaFar": 20, "zetaFar": 1.0, "band": 0.005 },
            "h": { "omega": 7.8, "zeta": 0.60, "omegaFar": 20, "zetaFar": 1.0, "band": 0.005 }
        },
        "resize": {
            "w": { "omega": 15, "zeta": 1.0, "omegaFar": 15, "zetaFar": 1.0, "band": 0.005 },
            "h": { "omega": 15, "zeta": 1.0, "omegaFar": 15, "zetaFar": 1.0, "band": 0.005 }
        },
        "close": {
            "w": { "omega": 17, "zeta": 1.0, "omegaFar": 17, "zetaFar": 1.0, "band": 0.005 },
            "h": { "omega": 17, "zeta": 0.85, "omegaFar": 24, "zetaFar": 1.0, "band": 0.005 }
        }
    })
    // Contenido que se materializa (PillSurfaceHost): escala, desenfoque y desplazamiento
    // dependen de p = progreso de contenido; la capa sólo existe mientras p < 1.
    readonly property real materializeScale: 0.96        // entrada: 0.96 -> 1
    readonly property real materializeRetireScale: 0.97  // salida entre surfaces: 1 -> 0.97
    readonly property real materializeBlur: 0.4          // fracción de blurMax al empezar
    readonly property real materializeBlurMax: 32
    readonly property real materializeBlurMaxLarge: 14   // wallpaper/ajustes: la capa cuesta más
    readonly property real materializeLargeArea: 480000  // px^2 a escala 1
    readonly property real materializeTravel: 6          // px a escala 1, hacia abajo -> 0
    readonly property real restScale: 0.96               // contenido de reposo al volver
    // Apertura: el contenido llega con la forma. Se revela entre openContentStart y
    // openContentStart + openContentSpan del crecimiento (antes 45 %..80 %, que dejaba
    // un cristal vacío 100-250 ms). P1-1 del QA visual 2026-10-30.
    readonly property real openContentStart: 0.12
    readonly property real openContentSpan: 0.28
    // Cierre: el contenido sale completo con el crecimiento en closeFull..closeStart.
    readonly property real closeContentStart: 0.9
    readonly property real closeContentFull: 0.6
    // Asentamiento: dentro de este margen (px * s) y con esta velocidad (px/s * s) se clava el destino.
    readonly property real surfaceSettleDistance: 0.3
    readonly property real surfaceSettleSpeed: 8

    // ---- Las apps nacen de la isla (docs/apps-nacen-2026-11-06) ----
    // Un único muelle 2D lleva la gota del icono desde la isla hasta la ventana; un
    // retarget (destino provisional -> rectángulo real) conserva posición y velocidad.
    readonly property var launchFlight: ({ "omega": Flags.reduceMotion ? 28 : 12, "zeta": 0.9 })
    // Llegada: la gota se ensancha al rectángulo de la ventana y se desvanece. Tope duro
    // de 200 ms (< 220 ms de cobertura máxima) aunque motionScale sea grande.
    readonly property int launchFade: Math.min(200, Math.round(180 * mult))
    readonly property int launchCoverMax: 220
    // Tiempo real (no escalado) que espera una ventana antes de volver a la isla.
    readonly property int launchWait: 6000
    // Tras el openwindow que casa, la geometría debe resolverse en este plazo.
    readonly property int launchGeometryWait: 1500
    // Absorción al volver a la isla o al indicador de workspace.
    readonly property int launchAbsorb: Math.round(140 * mult)
    // Microgota que deja el cuello al romper (regla 4).
    readonly property int launchResidue: Math.round(200 * mult)

    // Duraciones clave del ciclo notif (para timers/hold, NO para la anim del spring)
    // P1-5 (QA 10-30): colapso 350->160 y expansión 350->260 ms; el título se lee hacia ~420 ms.
    readonly property int notifCollapse:  Math.round(160 * mult)   // pill -> circle
    readonly property int notifExpand:    Math.round(260 * mult)   // circle -> notif pill
    // El hold es tiempo de lectura, no movimiento: reduceMotion y motionScale
    // no deben acortarlo (con reduceMotion quedaba en ~420 ms).
    readonly property int notifHoldMin:   1000  // hold mínimo
    readonly property int notifHoldMax:   2000  // hold máximo

    // ---- Tidemark: lenguaje de trazo (docs/plan-trazo-pill-2026-10-30.md) ----
    // Dibujar usa `standard`, borrar `fast`; el escalón entre piezas es el que ya
    // usaba AnimatedSymbol. Los muelles (omega rad/s, zeta) los integra SpringValue
    // y conservan posición y velocidad al cambiar de destino. Valores de la vista
    // previa aprobada docs/previews/tidemark-lenguaje.html.
    readonly property int strokeDraw: standard
    readonly property int strokeErase: fast
    readonly property real strokeRadioStep: 0.2             // cada onda del wifi se enciende 0.2 del recorrido después de la anterior
    readonly property int strokeWaveStagger: Math.round(45 * mult)  // retraso entre ondas del volumen
    readonly property int strokeTideHold: Flags.reduceMotion ? 0 : Math.round(700 * Flags.motionScale)  // la marca de marea espera antes de bajar
    readonly property real strokeHeadScale: 1.25            // radio de la cabeza = trazo * esto
    readonly property real strokeBoltFillStart: 0.6         // el relleno del rayo entra cuando el trazo lleva este tanto dibujado
    readonly property real strokeBarGain: 1.4               // la barra de apagado de la radio llega antes de que la onda termine de salir
    readonly property real strokeCrossFade: 1.6             // el trazo vertical del más se desvanece antes de que el check cierre
    readonly property real strokeSeatShift: 0.6             // cuánto baja el arco del candado con el "clac" (unidades del glifo)
    readonly property real strokeGlow: 0.85                 // intensidad del brillo único al resolver
    readonly property var strokeSpring: ({
        "wave":  { "omega": 17, "zeta": 0.62 },   // onda del volumen: radio + apertura
        "cone":  { "omega": 30, "zeta": 0.45 },   // el cono se comprime al empujar
        "mute":  { "omega": 20, "zeta": 0.75 },   // onda central -> barra que tacha
        "level": { "omega": 26, "zeta": 1.0 },    // nivel sigue al valor sin rebasar
        "tide":  { "omega": 4,  "zeta": 1.0 },    // marca de marea: baja despacio
        "split": { "omega": 19, "zeta": 0.68 },   // play <-> pausa: la gota se parte
        "lift":  { "omega": 18, "zeta": 0.60 },   // candado: el arco sube
        "swing": { "omega": 15, "zeta": 0.70 },   // candado: el arco gira
        "seat":  { "omega": 34, "zeta": 0.40 },   // candado: clac del cuerpo
        "hole":  { "omega": 22, "zeta": 0.80 },   // candado: la cerradura se vuelve punto
        "morph": { "omega": 20, "zeta": 0.80 },   // más <-> check, rayo, ondas de radio
        "radio": { "omega": 17, "zeta": 0.65 }    // wifi / bluetooth: ondas y barra de apagado
    })
    // Caja de selección del explorador de archivos: sigue al puntero con un retraso elástico corto.
    // Vista rápida del explorador: crece desde el elemento (zeta 0.78: rebase ~2-3 %, asentada ~600 ms,
    // sin la banda de surfaceSpring.open) y vuelve sin rebasar.
    readonly property var quickLookSpring: ({
        "open": { "omega": 9.0, "zeta": 0.78 },
        "close": { "omega": 14, "zeta": 1.0 }
    })
    readonly property var rubberBandSpring: ({ "omega": 30, "zeta": 0.8 })
    // Explorador: al navegar el contenido nuevo entra desplazado como mucho `filesNavTravel` px con
    // fundido (muelles críticos: se mueve, no rebota). Si el listado aún carga, la entrada espera
    // como mucho `filesNavHold` ms (tiempo real) en su pose inicial. El resaltado de selección
    // desliza entre elementos y las migas se reacomodan con muelles sin rebase visible.
    readonly property real filesNavTravel: 24
    readonly property int filesNavHold: 200
    readonly property var filesNavSpring: ({
        "offset": { "omega": 20, "zeta": 1.0 },
        "fade": { "omega": 24, "zeta": 1.0 }
    })
    readonly property var filesHighlightSpring: ({ "omega": 26, "zeta": 0.9 })
    readonly property var filesCrumbSpring: ({ "omega": 22, "zeta": 1.0 })
    // Velocidad inicial (unidades del muelle/s) de los empujones con `kick`.
    readonly property var strokeKick: ({
        "cone": 9,     // el cono del volumen se comprime al encender una onda
        "seat": -14    // el cuerpo del candado "clac" al cerrar
    })
}
