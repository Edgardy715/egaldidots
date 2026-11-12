import QtQuick
import "../Singletons"

// Muelle escalar de Tidemark: cada cambio de `target` parte de la posición y la
// velocidad actuales. Sin timers: el FrameAnimation sólo corre mientras integra.
// Oculto (`active` falso) o con reduceMotion resuelve al destino sin animar.
Item {
    id: root
    visible: false
    property real target: 0
    property real value: 0
    property real velocity: 0
    // Token de Motion.strokeSpring (omega rad/s, zeta); los componentes eligen el suyo.
    property var spring: Motion.strokeSpring.level
    property bool active: true
    // Las pruebas avanzan el muelle a mano con step(dt) para ser deterministas.
    property bool manualStep: false
    readonly property bool settled: !integrating
    property bool integrating: false
    // Posición a la que el muelle se asienta: |x - target| y |v| bajo estos umbrales.
    property real settleDistance: 0.0005
    property real settleSpeed: 0.01
    // Paso máximo por cuadro (s de muelle). 2 recupera cuadros tardíos; una apertura que no debe
    // saltar con el primer cuadro (mapeo de ventana) lo baja a ~1/30: el cuadro tardío frena, no salta.
    property real maxStep: 2
    // Muelle con banda (Motion.surfaceSpring): si `spring` trae omegaFar/zetaFar/band, más allá del
    // destino (band * recorrido, en la dirección del último retarget) se endurece y amortigua, de modo
    // que rebasa ~3 % como PillMorphMotion.accel. Sin esos campos el muelle es el lineal de siempre.
    readonly property bool _banded: spring.omegaFar !== undefined && spring.band !== undefined
    property real _dir: 1
    property real _span: 1

    function snap(v) {
        value = v === undefined ? target : v
        velocity = 0
        integrating = false
    }
    // Empuje instantáneo (cono del volumen, clac del candado).
    function kick(v) {
        if (!active || Flags.reduceMotion) return
        velocity += v
        integrating = true
    }
    function retarget() {
        if (!active || Flags.reduceMotion) { snap(target); return }
        if (value !== target) { _dir = target > value ? 1 : -1; _span = Math.abs(target - value) }
        if (value !== target || velocity !== 0) integrating = true
    }
    // Subpasos estables a 240 Hz; un cuadro tardío no lanza el muelle.
    function step(dt) {
        if (!isFinite(dt) || dt <= 0) return
        dt = Math.min(dt / Math.max(0.1, Flags.motionScale), maxStep)
        const sp = spring, banded = _banded
        let w = sp.omega, z = sp.zeta
        const n = Math.max(1, Math.ceil(dt * 240)), h = dt / n
        const band = banded ? Math.max(sp.band * _span, 1e-9) : 1
        let x = value, v = velocity
        for (let i = 0; i < n; ++i) {
            const e = x - target
            if (banded) {
                const b = Math.max(0, Math.min(1, e * _dir / band)), k = b * b * (3 - 2 * b)
                w = sp.omega + (sp.omegaFar - sp.omega) * k
                z = sp.zeta + (sp.zetaFar - sp.zeta) * k
            }
            v += (-w * w * e - 2 * z * w * v) * h
            x += v * h
        }
        if (Math.abs(x - target) < settleDistance && Math.abs(v) < settleSpeed) { x = target; v = 0 }
        velocity = v
        value = x
        if (x === target) integrating = false
    }
    onTargetChanged: retarget()
    onActiveChanged: if (!active) snap(target)
    Connections {
        target: Flags
        function onReduceMotionChanged() { if (Flags.reduceMotion) root.snap(root.target) }
    }
    FrameAnimation {
        running: root.integrating && root.active && !root.manualStep
        onTriggered: root.step(frameTime)
    }
}
