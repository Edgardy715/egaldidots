pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"
import "../kit"

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
    // Barra plana: pista translúcida, progreso sólido de acento y una bolita
    // cabeza que crece al apuntar. Mientras suena, un brillo tenue recorre el
    // progreso (fase = wavelength / 1,6 s), sin onda.
    readonly property bool handleShown: input.containsMouse || input.pressed || input.activeFocus
    readonly property real beadSize: (handleShown ? 14 : 9) * s
    readonly property color ink: Qt.hsla(musicAccent.hslHue < 0 ? 0 : musicAccent.hslHue,
        Math.max(0.5, musicAccent.hslSaturation), Theme.dark ? 0.62 : 0.5, 1)
    readonly property color inkAlt: Qt.hsla(((musicAccent.hslHue < 0 ? 0 : musicAccent.hslHue) + 0.09) % 1,
        Math.max(0.55, musicAccent.hslSaturation), Theme.dark ? 0.7 : 0.55, 1)
    readonly property bool motionAllowed: enabled && active && visible && opacity > 0 && Flags.mediaTransitions && !Flags.reduceMotion
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
    AmbientSubscription {
        id: waveClock
        objectName: "swiftTimelineClock"
        running: root.moving
        onTriggered: dt => root.phaseOffset = (root.phaseOffset
            + root.wavelength * dt / 1.6) % root.wavelength
    }

    Rectangle {
        anchors.fill: parent
        radius: 8 * root.s
        color: "transparent"
        border.width: input.activeFocus ? Theme.borderHairline : 0
        border.color: Theme.accent
    }
    MercuryChannel {
        objectName: "swiftTimelineTail"
        x: root.trackInset
        anchors.verticalCenter: parent.verticalCenter
        width: root.trackWidth
        height: root.thickness
    }
    Item {
        id: playedClip
        objectName: "swiftTimelinePlayed"
        x: root.trackInset
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.cursorX - x)
        height: root.thickness
        clip: true
        Rectangle {
            width: Math.max(playedClip.width, height)
            height: parent.height
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root.inkAlt }
                GradientStop { position: 1; color: root.ink }
            }
        }
        // Reflejos que viajan con la fase: el metal líquido fluye hacia la cabeza.
        Repeater {
            model: Math.ceil(root.trackWidth / root.wavelength) + 2
            Rectangle {
                required property int index
                x: (index - 1) * root.wavelength + root.phaseOffset
                width: root.wavelength * 0.5
                height: playedClip.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.alpha("#ffffff", 0) }
                    GradientStop { position: 0.5; color: Qt.alpha("#ffffff", 0.28) }
                    GradientStop { position: 1; color: Qt.alpha("#ffffff", 0) }
                }
                opacity: root.waveAmount
                visible: opacity > 0.01
            }
        }
    }
    MercuryBead {
        objectName: "swiftTimelineThumb"
        x: root.cursorX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: root.beadSize
        height: root.beadSize
        tint: root.musicAccent
        opacity: root.enabled ? 1 : 0
        Behavior on width { enabled: !Flags.reduceMotion; SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping } }
        Behavior on height { enabled: !Flags.reduceMotion; SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping } }
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
        Accessible.name: I18n.tr("Posición de reproducción")
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
