import QtQuick
import "../Singletons"

// Discrete state/metadata changes only. Keep continuously updated values as Text.
Text {
    id: root
    property string value: ""
    property bool ready: false
    property string displayed: ""
    property real reveal: 1
    text: displayed
    opacity: reveal
    onValueChanged: {
        if (!ready || !visible || Flags.reduceMotion) {
            swap.stop()
            displayed = value
            reveal = 1
        } else if (value !== displayed) swap.restart()
    }
    onVisibleChanged: if (!visible) { swap.stop(); displayed = value; reveal = 1 }
    Component.onCompleted: { displayed = value; ready = true }
    Connections {
        target: Flags
        function onReduceMotionChanged() {
            if (Flags.reduceMotion) { swap.stop(); root.displayed = root.value; root.reveal = 1 }
        }
    }
    SequentialAnimation {
        id: swap
        NumberAnimation { target: root; property: "reveal"; to: 0; duration: Motion.press; easing.type: Motion.easeStandard }
        ScriptAction { script: root.displayed = root.value }
        NumberAnimation { target: root; property: "reveal"; to: 1; duration: Motion.hover; easing.type: Motion.easeStandard }
    }
}
