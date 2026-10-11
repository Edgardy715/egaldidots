pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../Singletons"

Item {
    id: root
    property real s: 1
    property bool active: false
    property bool playing: false
    property bool dragging: false
    property real progress: 0
    property real position: 0
    property real length: 0
    property string displayTime: ""
    signal seekRequested(real position)
    signal dragStarted(real fraction)
    signal dragMoved(real fraction)
    signal dragCommitted(real fraction)
    signal dragCanceled()

    readonly property real boundedProgress: isFinite(progress) ? Math.max(0, Math.min(1, progress)) : 0
    property real displayedProgress: boundedProgress
    readonly property real trackInset: 7 * s
    readonly property real trackWidth: Math.max(1, width - 2 * trackInset)
    readonly property real cursorX: trackInset + trackWidth * displayedProgress
    readonly property real wavelength: 36 * s
    readonly property bool moving: active && visible && playing && !dragging
        && !Flags.reduceMotion && boundedProgress > 0 && boundedProgress < 1
    property real waveOffset: 0
    property real waveAmount: active && playing && !dragging && !Flags.reduceMotion ? 1 : 0
    function fractionAt(x) { return Math.max(0, Math.min(1, (x - trackInset) / trackWidth)) }

    Behavior on displayedProgress {
        enabled: !root.dragging && !Flags.reduceMotion
            && Math.abs(root.boundedProgress - root.displayedProgress) < 0.02
        SmoothedAnimation { duration: Motion.fast; velocity: -1; reversingMode: SmoothedAnimation.Immediate }
    }
    Behavior on waveAmount {
        enabled: root.visible && !Flags.reduceMotion
        NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard }
    }
    FrameAnimation {
        running: root.moving
        onTriggered: root.waveOffset = (root.waveOffset + frameTime * 18 * root.s) % root.wavelength
    }
    Rectangle {
        anchors.fill: parent
        radius: 8 * root.s
        color: "transparent"
        border.width: input.activeFocus ? Theme.borderHairline : 0
        border.color: Theme.accent
    }
    Rectangle {
        x: root.cursorX + 8 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.width - root.trackInset - x)
        height: 3 * root.s
        radius: height / 2
        color: Qt.alpha(Theme.foreground, Theme.alphaSubtle)
    }
    Item {
        x: root.trackInset
        width: Math.max(0, root.cursorX - x - 8 * root.s)
        height: parent.height
        clip: true
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 3 * root.s
            radius: height / 2
            color: Theme.accent
            opacity: 1 - root.waveAmount
        }
        Shape {
            y: parent.height / 2
            width: root.trackWidth + root.wavelength
            height: 1
            opacity: root.waveAmount
            preferredRendererType: Shape.CurveRenderer
            transform: [
                Translate { x: -root.waveOffset },
                Scale { yScale: root.waveAmount }
            ]
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.accent
                strokeWidth: 3 * root.s
                capStyle: ShapePath.RoundCap
                PathSvg {
                    // Static geometry; only translation and amplitude change per frame.
                    path: {
                        const wave = root.wavelength
                        const amplitude = 5 * root.s
                        let result = "M 0 0"
                        for (let x = 0; x < root.trackWidth + wave; x += wave) {
                            result += " C " + (x + wave / 4) + " " + -amplitude
                                + " " + (x + wave / 4) + " " + -amplitude + " " + (x + wave / 2) + " 0"
                                + " C " + (x + wave * 3 / 4) + " " + amplitude
                                + " " + (x + wave * 3 / 4) + " " + amplitude + " " + (x + wave) + " 0"
                        }
                        return result
                    }
                }
            }
        }
    }
    Rectangle {
        x: root.cursorX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 6 * root.s
        height: (root.dragging || input.containsMouse || input.activeFocus ? 20 : 16) * root.s
        radius: width / 2
        color: Theme.foreground
        Behavior on height { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
    }
    MouseArea {
        id: input
        objectName: "mediaSeek"
        anchors.fill: parent
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.role: Accessible.Slider
        Accessible.name: qsTr("Posición de reproducción")
        Accessible.description: root.displayTime
        Accessible.onIncreaseAction: root.seekRequested(root.position + 5)
        Accessible.onDecreaseAction: root.seekRequested(root.position - 5)
        Keys.onLeftPressed: root.seekRequested(root.position - 5)
        Keys.onRightPressed: root.seekRequested(root.position + 5)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Home) root.seekRequested(0)
            else if (event.key === Qt.Key_End) root.seekRequested(root.length)
            else return
            event.accepted = true
        }
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => { forceActiveFocus(); root.dragStarted(root.fractionAt(mouse.x)) }
        onPositionChanged: mouse => { if (root.dragging) root.dragMoved(root.fractionAt(mouse.x)) }
        onReleased: mouse => root.dragCommitted(root.fractionAt(mouse.x))
        onCanceled: root.dragCanceled()
    }
}
