import QtQuick

// Muelle físico del kit (ω en rad/s, ζ adimensional), el mismo modelo que
// PillMorphMotion. A diferencia de SpringAnimation de Qt, arranca del reposo con
// aceleración suave (no salta un tercio del recorrido en el primer fotograma) y
// conserva la velocidad al cambiar de destino. Tiempo de asentamiento ≈ 5/ω s.
// Sin `animate` el valor sigue al destino al instante.
Item {
    id: spring
    property real target: 0
    property bool animate: true
    property real omega: 20
    property real zeta: 1
    property real epsilon: 0.1
    property real value: 0
    property real velocity: 0
    readonly property bool moving: frame.running
    visible: false

    function settle() {
        frame.running = false
        velocity = 0
        value = target
    }
    Component.onCompleted: value = target
    onTargetChanged: if (animate) frame.running = true; else settle()
    onAnimateChanged: if (!animate) settle()

    FrameAnimation {
        id: frame
        onTriggered: {
            const w = spring.omega, z = spring.zeta
            // Pasos de ≤4 ms: estable aunque se pierdan fotogramas.
            const dt = Math.min(frameTime > 0 ? frameTime : 1 / 120, 0.05)
            const n = Math.max(1, Math.ceil(dt / 0.004)), h = dt / n
            let x = spring.value - spring.target, v = spring.velocity
            for (let i = 0; i < n; ++i) {
                v += (-w * w * x - 2 * z * w * v) * h
                x += v * h
            }
            if (Math.abs(x) < spring.epsilon && Math.abs(v) < spring.epsilon * 20) {
                spring.settle()
                return
            }
            spring.velocity = v
            spring.value = spring.target + x
        }
    }
}
