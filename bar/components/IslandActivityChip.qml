import QtQuick
import "../Singletons"

Item {
    id: root
    property real s: 1
    property real coreH: 38
    property string label: ""
    property string recordingPhase: ""
    property int recordingCountdown: 0
    readonly property bool recordingShown: recordingPhase.length > 0
    readonly property bool statusIconShown: recordingShown || label.length > 0
    readonly property real statusX: 0
    readonly property real labelX: statusX + (statusIconShown ? 30 * s : 0)
    width: labelX + (label.length ? Math.min(156 * s, labelMetrics.width) + 10 * s : 0)
    height: coreH
    visible: width > 0
    clip: true
    Behavior on width { enabled: !Flags.reduceMotion; SmoothedAnimation { duration: Motion.morph; velocity: -1 } }
    TextMetrics { id: labelMetrics; text: root.label; font: labelText.font }
    RecordingGlyph {
        objectName: "recordingIndicator"
        x: root.statusX; y: (root.height - height) / 2
        s: root.s
        phase: root.recordingPhase
        countdown: root.recordingCountdown
        opacity: root.recordingShown ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.standardSmall } }
    }
    MaterialIcon {
        x: root.statusX + 5 * root.s
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.recordingShown && root.label.length > 0
        iconName: "timer"
        font.pixelSize: 20 * root.s
        color: Theme.accent
    }
    CrossfadeLabel {
        id: labelText
        x: root.labelX
        width: Math.max(0, root.width - x - 10 * root.s)
        anchors.verticalCenter: parent.verticalCenter
        value: root.label
        font.family: Theme.font
        font.pixelSize: Theme.fontSizeSmall * root.s
        font.weight: Font.Medium
        color: Theme.foreground
        elide: Text.ElideRight
    }
}
