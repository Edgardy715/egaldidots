import QtQuick
import QtQuick.Shapes
import "../Singletons"

// Trazo = medida (Tidemark). `value` 0..1 se dibuja con trim.end sobre una pista
// tenue; el muelle suaviza el salto sin animar cada paso. La marca de marea es el
// pico reciente: se queda un momento y baja despacio. Presentación pura: el
// llamador pone `value`; en reposo no hay timers, y oculto no integra.
Item {
    id: root
    // "line" (horizontal) o "arc" (arco de `arcSweep` grados que arranca en `arcStart`).
    property string shape: "line"
    property real value: 0
    property color color: Theme.accent
    property color trackColor: Qt.alpha(Theme.foreground, 0.14)
    property real s: 1
    property real lineWidth: 2 * s
    property bool tide: false
    property bool head: false
    property real arcStart: -90
    property real arcSweep: 360
    readonly property bool isArc: shape === "arc"
    readonly property bool exposed: visible && (!Window.window || Window.window.visible)
    readonly property real shown: Math.max(0, Math.min(1, level.value))
    readonly property real tideShown: Math.max(shown, Math.min(1, tideSpring.value))
    // La cabeza sólo acompaña mientras el trazo crece.
    readonly property bool leading: head && exposed && level.velocity > 0.02 && shown > 0.01 && shown < 0.995
    readonly property real clamped: Math.max(0, Math.min(1, value))
    property real peak: clamped
    implicitWidth: isArc ? 48 * s : 96 * s
    implicitHeight: isArc ? 48 * s : lineWidth * 3
    Accessible.ignored: true

    SpringValue { id: level; target: root.clamped; active: root.exposed; spring: Motion.strokeSpring.level; Component.onCompleted: snap() }
    SpringValue { id: tideSpring; target: root.peak; active: root.exposed && root.tide; spring: Motion.strokeSpring.tide; Component.onCompleted: snap() }
    onClampedChanged: {
        if (clamped >= peak || !tide || Flags.reduceMotion || !exposed) { peak = clamped; hold.stop() }
        else if (!hold.running) hold.restart()
    }
    onExposedChanged: if (!exposed) { hold.stop(); peak = clamped }
    // Sólo existe mientras el pico está por encima del nivel.
    Timer {
        id: hold
        interval: Math.max(1, Motion.strokeTideHold)
        onTriggered: root.peak = root.clamped
    }

    function pointAt(v) {
        if (isArc) {
            const r = Math.min(width, height) / 2 - lineWidth, a = (arcStart + arcSweep * v) * Math.PI / 180
            return Qt.point(width / 2 + r * Math.cos(a), height / 2 + r * Math.sin(a))
        }
        return Qt.point(lineWidth + (width - 2 * lineWidth) * v, height / 2)
    }

    readonly property real arcRadius: Math.max(0, Math.min(width, height) / 2 - lineWidth)

    // Dos Shapes (línea / arco): sólo el activo se renderiza.
    Shape {
        anchors.fill: parent
        visible: !root.isArc
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: root.lineWidth; startY: root.height / 2
            PathLine { x: root.width - root.lineWidth; y: root.height / 2 }
        }
        ShapePath {
            objectName: "lineFill"
            strokeColor: root.color
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            trim.end: root.shown
            startX: root.lineWidth; startY: root.height / 2
            PathLine { x: root.width - root.lineWidth; y: root.height / 2 }
        }
    }
    Shape {
        anchors.fill: parent
        visible: root.isArc
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.arcRadius; radiusY: root.arcRadius
                startAngle: root.arcStart; sweepAngle: root.arcSweep
                moveToStart: true
            }
        }
        ShapePath {
            objectName: "arcFill"
            strokeColor: root.color
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            trim.end: root.shown
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.arcRadius; radiusY: root.arcRadius
                startAngle: root.arcStart; sweepAngle: root.arcSweep
                moveToStart: true
            }
        }
    }
    // Marca de marea: tic fino en el pico, sólo mientras está por encima del nivel.
    Rectangle {
        objectName: "tideMark"
        readonly property point p: root.pointAt(root.tideShown)
        visible: root.tide && root.tideShown - root.shown > 0.015
        width: root.lineWidth * 0.6; height: root.lineWidth * 2.4; radius: width / 2
        x: p.x - width / 2; y: p.y - height / 2
        rotation: root.isArc ? root.arcStart + root.arcSweep * root.tideShown + 90 : 0
        color: root.color; opacity: 0.75
    }
    // Cabeza: punta algo más gruesa que el cuerpo; sólo mientras el trazo crece.
    Rectangle {
        objectName: "head"
        readonly property point p: root.pointAt(root.shown)
        visible: root.leading
        width: root.lineWidth * Motion.strokeHeadScale * 2; height: width; radius: width / 2
        x: p.x - width / 2; y: p.y - height / 2
        color: root.color
    }
}
