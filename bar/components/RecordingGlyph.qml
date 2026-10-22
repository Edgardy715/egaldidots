import QtQuick
import "../Singletons"

Item {
    id: root
    property real s: 1
    property string phase: "recording"
    property int countdown: 0
    readonly property bool paused: phase === "paused"
    readonly property bool unknown: phase === "unknown"
    readonly property bool reduced: Flags.reduceMotion || !visible
    width: 30 * s; height: 26 * s
    Accessible.ignored: true
    Rectangle {
        anchors.centerIn: parent
        width: 24 * root.s; height: 22 * root.s
        radius: 9 * root.s
        color: Qt.alpha(root.unknown ? Theme.accentStrong : Theme.error, 0.08)
    }
    Rectangle {
        anchors.centerIn: parent
        width: (root.paused ? 12 : root.phase === "stopping" ? 8 : 10) * root.s
        height: (root.paused ? 9 : root.phase === "stopping" ? 8 : 10) * root.s
        radius: root.paused || root.phase === "stopping" ? 2 * root.s : width / 2
        color: root.unknown || root.phase === "countdown" ? "transparent" : Theme.error
        border.width: root.unknown ? 1 * root.s : 0
        border.color: Theme.accentStrong
        visible: root.phase !== "countdown"
        Rectangle {
            anchors.centerIn: parent
            width: 4 * root.s; height: parent.height
            color: Theme.cardBot
            visible: root.paused
        }
        Behavior on width { enabled: !root.reduced; SmoothedAnimation { duration: Motion.standardSmall; velocity: -1 } }
        Behavior on height { enabled: !root.reduced; SmoothedAnimation { duration: Motion.standardSmall; velocity: -1 } }
        Behavior on radius { enabled: !root.reduced; SmoothedAnimation { duration: Motion.standardSmall; velocity: -1 } }
    }
    Text {
        anchors.centerIn: parent
        text: root.countdown
        visible: root.phase === "countdown"
        color: Theme.foreground
        font.family: Theme.fontMedia
        font.pixelSize: 15 * root.s
        font.weight: Font.DemiBold
    }
}
