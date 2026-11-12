import QtQuick
import "../Singletons"

// Vuelo del launcher: la propia pill se recoge en una gota, cae a su sitio y
// allí se abre; al cerrar se recoge otra vez, sube y vuelve a ser la pill.
// Sólo decide la forma (dropMode) y el desplazamiento vertical; las
// dimensiones las sigue animando PillMorphMotion.
Item {
    id: root
    property real s: 1
    property bool open: false
    property bool reduceMotion: false
    // Distancia desde el borde superior de reposo hasta el sitio del launcher.
    property real landing: 0
    property real dropSize: 38
    property real pillW: 0
    property real pillH: 0
    // La gota de media se absorbe antes de que la pill se descuelgue.
    property bool holdAtTop: false

    // Si la absorción se atasca, la gota no espera más de 700 ms.
    property bool holdExpired: false
    Timer {
        interval: 700
        running: root.open && !root.down && root.holdAtTop && !root.holdExpired
        onTriggered: { root.holdExpired = true; root.sync() }
    }

    property bool down: false
    property real offset: 0
    property real velocity: 0
    readonly property real target: down ? landing : 0
    readonly property bool nearLanding: Math.abs(landing - offset) < 24 * s
    readonly property bool nearTop: offset < 14 * s
    // Al bajar, la gota sale ya recogida (la gota de media se funde antes y la
    // pill no debe ensancharse hacia ella). Al subir despega cuando la forma está
    // casi recogida, no cuando el muelle de PillMorphMotion agota su cola:
    // esperar a dropSize + 6 dejaba la gota quieta ~170 ms en el centro.
    readonly property bool isDrop: Math.max(pillW, pillH)
        <= (open ? dropSize + 6 * s : dropSize * 1.6)
    readonly property bool moving: Math.abs(target - offset) > 0.3 * s || Math.abs(velocity) > 5 * s
    // Abierto: gota hasta tocar su sitio. Cerrado: gota hasta volver arriba.
    // Imperativo, no binding: la pill reacciona a dropMode y puede escribir `down`
    // en la misma pila (sync), y un binding re-entrante quedaba congelado en true
    // (gota posada que nunca se abría). La última escritura siempre gana.
    property bool dropMode: false
    function updateMode() {
        dropMode = !reduceMotion && (open ? !(down && nearLanding) : (down || !nearTop))
    }
    onDownChanged: updateMode()
    onNearLandingChanged: updateMode()
    onNearTopChanged: updateMode()
    Component.onCompleted: updateMode()
    readonly property bool active: dropMode || down || offset > 0.5 * s || moving

    function sync() {
        if (reduceMotion) {
            down = open
            offset = target
            velocity = 0
            return
        }
        if (open && !down && isDrop && (!holdAtTop || holdExpired)) down = true
        else if (!open && down && isDrop) down = false
    }
    onOpenChanged: { if (!open) holdExpired = false; sync(); updateMode() }
    onIsDropChanged: sync()
    onHoldAtTopChanged: sync()
    onReduceMotionChanged: { sync(); updateMode() }
    onLandingChanged: if (reduceMotion) sync()

    // Muelle con aceleración motriz acotada: arranca como una gota que cae
    // (aceleración constante) y frena sin límite, rebasando ~2 px al posarse.
    readonly property real omega: 18
    readonly property real zeta: 0.8
    readonly property real maxAccel: (down ? 6500 : 5600) * s
    function step(dt) {
        dt = Math.min(dt / Math.max(0.05, Flags.motionScale), 0.1)
        const n = Math.max(1, Math.ceil(dt * 240))
        const h = dt / n
        let x = offset, v = velocity
        const t = target
        for (let i = 0; i < n; ++i) {
            let a = -omega * omega * (x - t) - 2 * zeta * omega * v
            if (a * v >= 0) a = Math.max(-maxAccel, Math.min(maxAccel, a))
            v += a * h
            x += v * h
        }
        if (Math.abs(x - t) < 0.3 * s && Math.abs(v) < 5 * s) { x = t; v = 0 }
        velocity = v
        offset = x
    }
    FrameAnimation {
        running: root.moving && !root.reduceMotion
        onTriggered: root.step(frameTime)
    }
}
