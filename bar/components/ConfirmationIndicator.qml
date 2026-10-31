import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../Singletons"

// Presentation only: the caller owns the operation and its real result.
Item {
    id: root
    // "", busy (indeterminate arc), progress (determinate, 0..1), success, error, cancelled.
    property string status: ""
    property real progress: 0
    property real s: 1
    // Arc colour while working; filled controls pass their foreground so the arc stays visible.
    property color busyColor: Theme.accent
    readonly property bool terminal: status === "success" || status === "error" || status === "cancelled"
    readonly property bool determinate: status === "progress"
    readonly property bool animating: visible && status === "busy" && !Flags.reduceMotion
    readonly property color signalColor: status === "success" ? Theme.signalSuccess : status === "error" ? Theme.signalError
        : status === "cancelled" ? Theme.iconSecondary : busyColor
    property real shownProgress: Math.max(0, Math.min(1, progress))
    Behavior on shownProgress {
        enabled: root.visible && !Flags.reduceMotion
        NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
    }
    property string lastStatus: ""
    readonly property bool glyphOk: status === "success"
    readonly property bool glyphStop: status === "cancelled"
    property real loadingPhase: 0
    readonly property real loadingSweep: Flags.reduceMotion ? 285 : 28 + 272 * (0.5 - 0.5 * Math.cos(loadingPhase * Math.PI * 2))
    property real ringOrigin: -90
    property real ringProgress: 0
    property real symbolProgress: 0
    readonly property real drawProgress: symbolProgress
    implicitWidth: 48 * s
    implicitHeight: 48 * s
    visible: status !== ""
    Accessible.ignored: true

    function settle() {
        reveal.stop()
        ringProgress = terminal ? 1 : 0
        symbolProgress = terminal ? 1 : 0
    }
    // The result ring closes from wherever the previous arc was, busy or determinate.
    function resync(from) {
        reveal.stop()
        if (!visible || Flags.reduceMotion) { settle(); return }
        const wasDeterminate = from === "progress"
        ringOrigin = wasDeterminate ? -90 - ring.rotation : -90 + Math.max(0, loadingPhase - 0.5) * 720
        ringProgress = terminal ? (wasDeterminate ? shownProgress : loadingSweep / 360) : 0
        symbolProgress = 0
        if (terminal) reveal.start()
    }
    onStatusChanged: {
        const from = lastStatus
        lastStatus = status
        Qt.callLater(() => { if (typeof root.resync === "function") root.resync(from) })
    }
    onVisibleChanged: { if (!visible) settle(); else resync() }
    Component.onCompleted: resync()
    Connections {
        target: Flags
        function onReduceMotionChanged() { if (Flags.reduceMotion) root.settle() }
    }
    NumberAnimation on loadingPhase {
        from: 0; to: 1; duration: Motion.heat; loops: Animation.Infinite
        running: root.animating
    }
    SequentialAnimation {
        id: reveal
        NumberAnimation { target: root; property: "ringProgress"; to: 1; duration: Motion.press; easing.type: Motion.easeStandard }
        NumberAnimation { target: root; property: "symbolProgress"; to: 1; duration: Motion.standard; easing.type: Motion.easeStandard }
    }
    Item {
        id: drawing
        anchors.centerIn: parent
        width: Math.min(root.width, root.height)
        height: width
        layer.enabled: root.visible
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha(root.signalColor, root.terminal ? 0.85 : 0.45)
            shadowBlur: 0.75
            blurMax: 16
        }
        Shape {
            id: ring
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            RotationAnimation on rotation {
                from: 0; to: 360; duration: Motion.heat; loops: Animation.Infinite
                running: root.animating
            }
            ShapePath {
                strokeColor: root.signalColor
                strokeWidth: Math.max(1.5, drawing.width * Theme.strokeRing)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: drawing.width / 2; centerY: drawing.height / 2
                    radiusX: drawing.width * 0.43; radiusY: radiusX
                    // Determinate progress always grows clockwise from 12 o'clock on screen.
                    startAngle: root.terminal ? root.ringOrigin : root.determinate ? -90 - ring.rotation
                        : -90 + Math.max(0, root.loadingPhase - 0.5) * 720
                    sweepAngle: root.terminal ? 360 * root.ringProgress : root.determinate ? Math.max(4, 360 * root.shownProgress)
                        : root.loadingSweep
                    moveToStart: true
                }
            }
        }
        Shape {
            anchors.fill: parent
            visible: root.terminal
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.signalColor
                strokeWidth: Math.max(1.5, drawing.width * Theme.strokeSymbol)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                trim.end: root.symbolProgress
                // success: check · error: first cross stroke · cancelled: a calm horizontal stop bar.
                startX: drawing.width * (root.glyphOk ? 0.27 : root.glyphStop ? 0.33 : 0.35)
                startY: drawing.height * (root.glyphOk ? 0.51 : root.glyphStop ? 0.5 : 0.35)
                PathLine { x: drawing.width * (root.glyphOk ? 0.44 : root.glyphStop ? 0.5 : 0.65); y: drawing.height * (root.glyphStop ? 0.5 : 0.65) }
                PathLine { x: drawing.width * (root.glyphOk ? 0.73 : root.glyphStop ? 0.67 : 0.65); y: drawing.height * (root.glyphOk ? 0.34 : root.glyphStop ? 0.5 : 0.65) }
            }
            ShapePath {
                strokeColor: root.status === "error" ? root.signalColor : "transparent"
                strokeWidth: Math.max(1.5, drawing.width * Theme.strokeSymbol)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                trim.end: root.symbolProgress
                startX: drawing.width * 0.65; startY: drawing.height * 0.35
                PathLine { x: drawing.width * 0.35; y: drawing.height * 0.65 }
            }
        }
    }
}
