import QtQuick
import "../Singletons"

// One choreography owns outgoing and incoming content, including retargeting.
Item {
    id: root
    property int requestedPage: 0
    property int displayedPage: 0
    property bool reduced: false
    property bool active: true
    property real exposure: 1
    property real travel: 0
    property int direction: 1
    // Search on/off swaps through the same fade/translate as page changes.
    property bool requestedSearching: false
    property bool displayedSearching: false
    readonly property bool transitioning: swap.running || entrance.running
    function settle() {
        swap.stop(); entrance.stop()
        displayedPage = requestedPage; displayedSearching = requestedSearching; exposure = 1; travel = 0
    }
    onRequestedSearchingChanged: {
        if (reduced || !active) { settle(); return }
        direction = 1
        entrance.stop()
        swap.restart()
    }
    onRequestedPageChanged: {
        if (reduced || !active) { settle(); return }
        direction = requestedPage >= displayedPage ? 1 : -1
        entrance.stop()
        swap.restart()
    }
    onReducedChanged: if (reduced) settle()
    onActiveChanged: {
        if (!active || reduced) settle()
        else { exposure = 0; travel = 16; entrance.restart() }
    }
    SequentialAnimation {
        id: swap
        ParallelAnimation {
            NumberAnimation { target: root; property: "exposure"; to: 0; duration: Motion.fast; easing.type: Motion.easeStandard }
            NumberAnimation { target: root; property: "travel"; to: -12 * root.direction; duration: Motion.fast; easing.type: Motion.easeStandard }
        }
        ScriptAction { script: { root.displayedPage = root.requestedPage; root.displayedSearching = root.requestedSearching; root.travel = 20 * root.direction } }
        ParallelAnimation {
            NumberAnimation { target: root; property: "exposure"; to: 1; duration: Motion.emphasized; easing.type: Motion.easeStandard }
            NumberAnimation { target: root; property: "travel"; to: 0; duration: Motion.emphasized; easing.type: Motion.easeStandard }
        }
    }
    ParallelAnimation {
        id: entrance
        NumberAnimation { target: root; property: "exposure"; to: 1; duration: Motion.emphasized; easing.type: Motion.easeStandard }
        NumberAnimation { target: root; property: "travel"; to: 0; duration: Motion.emphasized; easing.type: Motion.easeStandard }
    }
}
