import QtQuick
import QtQuick.Shapes
import "../Singletons"
import "AnimatedIconData.js" as IconData

// Lucide strokes, animated independently in the native scene graph (Qt >= 6.10).
Item {
    id: root
    property string iconName: ""
    property color color: Theme.foreground
    property bool hovered: false
    property bool pressed: false
    property real reveal: 1
    readonly property var parts: IconData.parts(iconName)
    readonly property bool supported: parts.length > 0
    property real progress: 1
    readonly property bool animating: gesture.running
    readonly property bool exposed: visible && (!Window.window || Window.window.visible)
    implicitWidth: 24
    implicitHeight: 24

    function play() {
        if (!exposed || Flags.reduceMotion) return
        gesture.stop()
        gesture.from = progress === 1 ? 0 : progress
        gesture.to = 1
        gesture.duration = Motion.iconGesture * (1 - gesture.from)
        gesture.start()
    }
    onHoveredChanged: {
        if (hovered) play()
        else if (gesture.running) {
            gesture.stop()
            gesture.from = progress
            gesture.duration = Motion.fast
            gesture.start()
        }
    }
    onPressedChanged: if (pressed) play()
    onExposedChanged: if (!exposed) { gesture.stop(); progress = 1 }
    Connections {
        target: Flags
        function onReduceMotionChanged() {
            if (Flags.reduceMotion) { gesture.stop(); root.progress = 1 }
        }
    }
    NumberAnimation {
        id: gesture
        target: root; property: "progress"
        to: 1
        easing.type: Easing.Linear
    }
    Item {
        width: 24; height: 24
        anchors.centerIn: parent
        scale: Math.min(root.width, root.height) / 24
        Repeater {
            model: root.parts.length
            delegate: Shape {
                id: piece
                readonly property var modelData: root.parts[index] || ({path: "", role: "body"})
                required property int index
                readonly property string role: modelData.role
                readonly property real phase: Math.max(0, Math.min(1, (root.progress - Math.min(index, 4) * 0.06) / (1 - Math.min(index, 4) * 0.06)))
                readonly property real pulse: Math.sin(Math.PI * phase)
                readonly property bool wave: role === "wave"
                readonly property bool redraw: role === "draw" || wave
                readonly property real strokeReveal: redraw ? 1 - 0.94 * pulse : role === "arc" || role === "shackle" ? 1 - 0.24 * pulse : 1
                objectName: "animatedPart" + index
                width: 24; height: 24
                preferredRendererType: Shape.CurveRenderer
                opacity: wave ? 1 - 0.75 * pulse : 1
                transform: [
                    Translate {
                        x: piece.role === "arrow" ? 2.5 * piece.pulse : piece.role === "clapper" ? -2 * Math.sin(piece.phase * Math.PI * 4) * piece.pulse : 0
                        y: piece.role === "stem" || piece.role === "shackle" ? -1.4 * piece.pulse : 0
                    },
                    Rotation {
                        origin.x: 12; origin.y: piece.role === "bell" ? 3 : 12
                        angle: piece.role === "bell" ? 14 * Math.sin(piece.phase * Math.PI * 4) * piece.pulse
                            : piece.role === "gear" || piece.role === "rotate" ? 38 * piece.pulse : 0
                    },
                    Scale { origin.x: 12; origin.y: 20; xScale: piece.wave ? 1 - 0.12 * piece.pulse : 1; yScale: xScale }
                ]
                ShapePath {
                    strokeColor: root.color
                    strokeWidth: 2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    trim.end: piece.strokeReveal * root.reveal
                    PathSvg { path: piece.modelData.path }
                }
            }
        }
    }
}
