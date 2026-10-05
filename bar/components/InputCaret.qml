import QtQuick
import "../Singletons"

// Qt owns x, y and height: text editing, scrolling and IME never wait on motion.
Item {
    id: root
    objectName: "inputCaret"
    required property var input
    property color color: Theme.foreground
    property bool motionActive: true
    readonly property bool engaged: motionActive && visible && input.visible
        && input.activeFocus && input.cursorVisible && input.enabled && !input.readOnly
        && input.selectionStart === input.selectionEnd
        && (!Window.window || (Window.window.visible && Window.window.active))
    readonly property bool resting: engaged && !hold.running && !Flags.reduceMotion
        && Qt.styleHints.cursorFlashTime > 0
    property real ink: 1
    width: 2
    opacity: engaged ? 1 : 0

    function wake() {
        blink.stop()
        ink = 1
        if (engaged && !Flags.reduceMotion) hold.restart()
        else hold.stop()
    }
    onEngagedChanged: wake()
    Component.onCompleted: wake()
    Connections {
        target: root.input
        function onCursorPositionChanged() { root.wake() }
        function onTextEdited() { root.wake() }
        function onPreeditTextChanged() { root.wake() }
    }
    Connections {
        target: Flags
        function onReduceMotionChanged() { root.wake() }
    }
    Timer { id: hold; interval: Math.max(500, Qt.styleHints.cursorFlashTime / 2) }
    SequentialAnimation {
        id: blink
        running: root.resting
        loops: Animation.Infinite
        PauseAnimation { duration: Math.max(80, Qt.styleHints.cursorFlashTime / 2 - Motion.hover) }
        NumberAnimation { target: root; property: "ink"; to: 0.25; duration: Motion.hover; easing.type: Easing.InOutSine }
        PauseAnimation { duration: Math.max(80, Qt.styleHints.cursorFlashTime / 2 - Motion.hover) }
        NumberAnimation { target: root; property: "ink"; to: 1; duration: Motion.hover; easing.type: Easing.InOutSine }
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: hold.running && !Flags.reduceMotion ? 2 : 1.5
        height: Math.max(1, parent.height - 2)
        radius: width / 2
        color: root.color
        opacity: root.ink
        Behavior on width {
            enabled: root.engaged && !Flags.reduceMotion
            NumberAnimation { duration: Motion.hover; easing.type: Motion.easeStandard }
        }
    }
}
