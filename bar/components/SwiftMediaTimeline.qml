pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../Singletons"

Item {
    id: root
    property color musicAccent: Theme.accent
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
    readonly property real displayedProgress: boundedProgress
    readonly property real trackInset: 9 * s
    readonly property real trackWidth: Math.max(1, width - 2 * trackInset)
    readonly property real cursorX: trackInset + trackWidth * displayedProgress
    readonly property real wavelength: 34 * s
    readonly property real restThickness: 4 * s
    readonly property real expandedThickness: 6 * s
    property real thickness: (input.containsMouse || input.pressed || input.activeFocus)
        ? expandedThickness : restThickness
    property real hoverAmplitude: (input.containsMouse || input.pressed ? 2.4 : 1.6) * s
    readonly property real amplitude: hoverAmplitude * waveAmount
    readonly property real handleWidth: 4 * s
    readonly property real handleHeight: 18 * s
    readonly property bool handleShown: input.containsMouse || input.pressed || input.activeFocus
    readonly property real playedGap: handleShown ? 6 * s : 0
    readonly property real tailGap: handleShown ? 6 * s
        : displayedProgress <= 0 || displayedProgress >= 1 ? 0 : 4 * s
    readonly property bool motionAllowed: enabled && active && visible && Flags.mediaTransitions && !Flags.reduceMotion
    readonly property bool moving: motionAllowed && playing && !dragging
    property real waveAmount: 0
    property real phaseOffset: 0
    property bool pointerDown: false

    implicitHeight: 24 * s
    enabled: length > 0
    opacity: enabled ? 1 : 0.45
    Behavior on thickness {
        enabled: !Flags.reduceMotion
        NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard }
    }
    Behavior on hoverAmplitude {
        enabled: !Flags.reduceMotion
        NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard }
    }

    function fractionAt(x) { return Math.max(0, Math.min(1, (x - trackInset) / trackWidth)) }
    function cancelPointer() {
        if (!pointerDown && !dragging) return
        pointerDown = false
        if (dragging) dragCanceled()
    }
    function syncWave() {
        waveTransition.stop()
        if (!motionAllowed) { waveAmount = 0; return }
        const target = moving ? 1 : 0
        if (waveAmount === target) return
        waveTransition.from = waveAmount
        waveTransition.to = target
        waveTransition.start()
    }
    onDraggingChanged: if (!dragging && pointerDown) pointerDown = false
    onLengthChanged: cancelPointer()
    onActiveChanged: if (!active) cancelPointer()
    onVisibleChanged: if (!visible) cancelPointer()
    onEnabledChanged: if (!enabled) cancelPointer()
    onMotionAllowedChanged: syncWave()
    onMovingChanged: syncWave()
    Component.onCompleted: syncWave()
    NumberAnimation {
        id: waveTransition
        target: root; property: "waveAmount"
        duration: 400 * Motion.mult
        easing.type: Motion.easeStandard
    }
    FrameAnimation {
        id: waveClock
        objectName: "swiftTimelineClock"
        running: root.moving
        onTriggered: root.phaseOffset = (root.phaseOffset
            + root.wavelength * Math.min(frameTime, 0.05) / 1.6) % root.wavelength
    }

    Rectangle {
        anchors.fill: parent
        radius: 8 * root.s
        color: "transparent"
        border.width: input.activeFocus ? Theme.borderHairline : 0
        border.color: Theme.accent
    }
    Rectangle {
        objectName: "swiftTimelineTail"
        x: Math.min(root.width - root.trackInset, root.cursorX + root.tailGap)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.width - root.trackInset - x)
        height: root.thickness
        radius: height / 2
        color: Qt.alpha(root.musicAccent, 0.30)
    }
    Item {
        id: playedClip
        objectName: "swiftTimelinePlayed"
        x: root.trackInset
        width: Math.max(0, root.cursorX - root.playedGap - x)
        height: parent.height
        clip: true
        Shape {
            x: -root.phaseOffset
            y: playedClip.height / 2
            width: root.trackWidth + root.wavelength * 2
            height: 1
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.musicAccent
                strokeWidth: root.thickness
                capStyle: ShapePath.RoundCap
                PathSvg {
                    path: {
                        const half = root.wavelength / 2
                        let result = "M " + (-root.wavelength) + " 0"
                        for (let x = -root.wavelength; x < root.trackWidth + 2 * root.wavelength; x += half) {
                            const up = (Math.round(x / half) % 2 === 0) ? 1 : -1
                            const crest = up * root.amplitude * 4 / 3
                            result += " C " + (x + half / 3) + " " + crest
                                + " " + (x + 2 * half / 3) + " " + crest
                                + " " + (x + half) + " 0"
                        }
                        return result
                    }
                }
            }
        }
    }
    Rectangle {
        objectName: "swiftTimelineThumb"
        x: root.cursorX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: root.handleWidth
        height: root.handleHeight
        radius: width / 2
        color: Theme.foreground
        opacity: root.handleShown && root.enabled ? 1 : 0
        Behavior on opacity {
            enabled: !Flags.reduceMotion
            NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard }
        }
    }
    MouseArea {
        id: input
        objectName: "mediaSeek"
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        activeFocusOnTab: true
        preventStealing: true
        Accessible.role: Accessible.Slider
        Accessible.name: qsTr("Posición de reproducción")
        Accessible.description: root.displayTime
        Accessible.onIncreaseAction: root.seekRequested(Math.min(root.length, root.position + 5))
        Accessible.onDecreaseAction: root.seekRequested(Math.max(0, root.position - 5))
        Keys.onLeftPressed: root.seekRequested(Math.max(0, root.position - 5))
        Keys.onRightPressed: root.seekRequested(Math.min(root.length, root.position + 5))
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Home) root.seekRequested(0)
            else if (event.key === Qt.Key_End) root.seekRequested(root.length)
            else return
            event.accepted = true
        }
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            forceActiveFocus()
            root.pointerDown = true
            root.dragStarted(root.fractionAt(mouse.x))
        }
        onPositionChanged: mouse => {
            if (root.pointerDown) root.dragMoved(root.fractionAt(mouse.x))
        }
        onReleased: mouse => {
            if (!root.pointerDown) return
            root.pointerDown = false
            root.dragCommitted(root.fractionAt(mouse.x))
        }
        onCanceled: root.cancelPointer()
    }
}
