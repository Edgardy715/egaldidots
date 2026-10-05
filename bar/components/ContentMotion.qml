import QtQuick
import "../Singletons"

// One short, interruptible transition for content state changes. No idle work.
Item {
    id: root
    property bool shown: true
    property real progress: shown ? 1 : 0
    readonly property real visualScale: Flags.reduceMotion ? 1 : 0.975 + 0.025 * progress
    readonly property real offset: Flags.reduceMotion ? 0 : -6 * (1 - progress)
    signal concealed()
    onProgressChanged: if (!shown && progress === 0) concealed()
    Behavior on progress {
        NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.standardSmall; easing.type: Motion.easeStandard }
    }
}
