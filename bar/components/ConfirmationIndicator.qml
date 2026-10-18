import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../Singletons"

// Presentation only: the caller owns the operation and its real result.
Item {
    id: root
    property string status: ""
    property real s: 1
    readonly property bool terminal: status === "success" || status === "error"
    readonly property color signalColor: status === "success" ? "#32d975" : status === "error" ? "#ff4d61" : Theme.accent
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
    function update() {
        reveal.stop()
        if (!visible || Flags.reduceMotion) { settle(); return }
        ringOrigin = -90 + Math.max(0, loadingPhase - 0.5) * 720
        ringProgress = terminal ? loadingSweep / 360 : 0
        symbolProgress = 0
        if (terminal) reveal.start()
    }
    onStatusChanged: Qt.callLater(update)
    onVisibleChanged: { if (!visible) settle(); else update() }
    Component.onCompleted: update()
    Connections {
        target: Flags
        function onReduceMotionChanged() { if (Flags.reduceMotion) root.settle() }
    }
    NumberAnimation on loadingPhase {
        from: 0; to: 1; duration: 1100; loops: Animation.Infinite
        running: root.visible && root.status === "busy" && !Flags.reduceMotion
    }
    SequentialAnimation {
        id: reveal
        NumberAnimation { target: root; property: "ringProgress"; to: 1; duration: Motion.press; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "symbolProgress"; to: 1; duration: Motion.standard; easing.type: Easing.OutCubic }
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
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            RotationAnimation on rotation {
                from: 0; to: 360; duration: 1100; loops: Animation.Infinite
                running: root.visible && root.status === "busy" && !Flags.reduceMotion
            }
            ShapePath {
                strokeColor: root.signalColor
                strokeWidth: Math.max(1.5, drawing.width * 0.045)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: drawing.width / 2; centerY: drawing.height / 2
                    radiusX: drawing.width * 0.43; radiusY: radiusX
                    startAngle: root.terminal ? root.ringOrigin : -90 + Math.max(0, root.loadingPhase - 0.5) * 720
                    sweepAngle: root.terminal ? 360 * root.ringProgress : root.loadingSweep
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
                strokeWidth: Math.max(1.5, drawing.width * 0.055)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                trim.end: root.symbolProgress
                startX: drawing.width * (root.status === "success" ? 0.27 : 0.35)
                startY: drawing.height * (root.status === "success" ? 0.51 : 0.35)
                PathLine { x: drawing.width * (root.status === "success" ? 0.44 : 0.65); y: drawing.height * 0.65 }
                PathLine { x: drawing.width * (root.status === "success" ? 0.73 : 0.65); y: drawing.height * (root.status === "success" ? 0.34 : 0.65) }
            }
            ShapePath {
                strokeColor: root.status === "error" ? root.signalColor : "transparent"
                strokeWidth: Math.max(1.5, drawing.width * 0.055)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                trim.end: root.symbolProgress
                startX: drawing.width * 0.65; startY: drawing.height * 0.35
                PathLine { x: drawing.width * 0.35; y: drawing.height * 0.65 }
            }
        }
    }
}
