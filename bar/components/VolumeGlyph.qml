import QtQuick
import QtQuick.Shapes
import "../Singletons"

// Altavoz de Tidemark: las ondas nacen de su centro y se alejan como en el agua;
// con mute la onda central se endereza y gira hasta ser la barra que tacha el
// altavoz. Un objeto, dos estados. Presentación pura: `level` y `muted` llegan
// por propiedades; todo se resuelve con muelles interrumpibles (SpringValue).
Item {
    id: root
    property real level: 0
    property bool muted: false
    property color color: Theme.accent
    property real size: 24
    readonly property bool exposed: visible && (!Window.window || Window.window.visible)
    readonly property real v: muted ? 0 : level
    readonly property var thresholds: [0.01, 0.34, 0.67]
    readonly property var radii: [4, 7, 10]
    readonly property real m: Math.max(0, Math.min(1.06, mute.value))
    readonly property real cone: coneSpring.value
    readonly property real muteAmount: m
    function waveExtent(i) { return [w0, w1, w2][i].extent }
    implicitWidth: size
    implicitHeight: size

    // Una onda: `want` sale del nivel; al encenderse espera su turno (escalón) y
    // empuja el cono. Sin timers en reposo: el Timer sólo corre durante el escalón.
    component Wave: Item {
        id: w
        required property int order
        property bool want: root.muted && order === 1 ? true : root.v >= root.thresholds[order]
        property bool on: false
        property bool ready: false
        readonly property real extent: Math.max(0, spring.value)
        visible: false
        onWantChanged: {
            if (!want) { delay.stop(); on = false }
            else if (!root.exposed || Flags.reduceMotion || order === 0) on = true
            else delay.restart()
        }
        onOnChanged: if (on && ready && !(root.muted && order === 1)) coneSpring.kick(Motion.strokeKick.cone)
        Component.onCompleted: { on = want; spring.snap(); ready = true }
        Timer { id: delay; interval: w.order * Motion.strokeWaveStagger; onTriggered: w.on = w.want }
        SpringValue { id: spring; target: w.on ? 1 : 0; active: root.exposed; spring: Motion.strokeSpring.wave; Component.onCompleted: snap() }
    }
    Wave { id: w0; order: 0 }
    Wave { id: w1; order: 1 }
    Wave { id: w2; order: 2 }
    SpringValue { id: coneSpring; target: 0; active: root.exposed; spring: Motion.strokeSpring.cone }
    SpringValue { id: mute; target: root.muted ? 1 : 0; active: root.exposed; spring: Motion.strokeSpring.mute; Component.onCompleted: snap() }

    // Onda central: arco que, con `m`, se mezcla punto a punto con la barra de mute.
    function centerPath(a, m) {
        const N = 16, pts = []
        const k = a + (1 - a) * Math.min(1, m)
        const half = 52 * Math.min(1.05, k), r = 7 * (0.45 + 0.55 * k)
        for (let j = 0; j < N; ++j) {
            const u = j / (N - 1), th = (-half + 2 * half * u) * Math.PI / 180
            const ax = 9.5 + r * Math.cos(th), ay = 12 + r * Math.sin(th)
            pts.push(Qt.point(ax + (20 - 16 * u - ax) * m, ay + (4 + 16 * u - ay) * m))
        }
        return pts
    }

    Item {
        width: 24; height: 24
        anchors.centerIn: parent
        scale: Math.min(root.width, root.height) / 24
        Shape {
            id: speaker
            width: 24; height: 24
            preferredRendererType: Shape.CurveRenderer
            opacity: 1 - 0.45 * Math.min(1, root.m)
            transform: [
                Translate { x: -0.9 * root.cone },
                Scale { origin.x: 11; origin.y: 12; xScale: 1 - 0.08 * root.cone }
            ]
            ShapePath {
                strokeColor: root.color; strokeWidth: 2; fillColor: "transparent"
                capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M11 5 6 9H3v6h3l5 4Z" }
            }
        }
        Repeater {
            model: [0, 2]
            delegate: Shape {
                id: arcWave
                required property int modelData
                readonly property real a: modelData === 0 ? w0.extent : w2.extent
                width: 24; height: 24
                visible: a >= 0.06
                opacity: Math.min(1, a * 2.2)
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: root.color; strokeWidth: 2; fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 9.5; centerY: 12
                        radiusX: root.radii[arcWave.modelData] * (0.45 + 0.55 * arcWave.a); radiusY: radiusX
                        startAngle: -52 * Math.min(1.05, arcWave.a); sweepAngle: 104 * Math.min(1.05, arcWave.a)
                        moveToStart: true
                    }
                }
            }
        }
        Shape {
            width: 24; height: 24
            visible: w1.extent >= 0.06 || root.m > 0.004
            opacity: root.m > 0.004 ? 1 : Math.min(1, w1.extent * 2.2)
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                // Mute: del acento hacia el color de tinta, como un trazo que se apaga.
                strokeColor: Qt.tint(Theme.foreground, Qt.alpha(root.color, 1 - 0.55 * Math.min(1, root.m)))
                strokeWidth: 2; fillColor: "transparent"
                capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                PathPolyline { path: root.centerPath(w1.extent, root.m) }
            }
        }
    }
}
