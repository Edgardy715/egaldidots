import QtQuick
import "../Singletons"

Item {
    id: root
    property real s: 1
    property real coreH: 38
    property bool companionEnabled: true
    property string label: ""
    property string mood: "rest"
    property string recordingPhase: ""
    property int recordingCountdown: 0
    property string actionName: qsTr("Abrir enfoque")
    readonly property bool recordingShown: recordingPhase.length > 0
    property real lookX: 0
    property real lookY: 0
    signal activated()
    readonly property bool present: companionEnabled || label.length > 0
    width: present ? 36 * s + (label.length ? Math.min(156 * s, labelMetrics.width) + 10 * s : 0) : 0
    height: coreH
    visible: width > 0
    clip: true
    Behavior on width { enabled: !Flags.reduceMotion; SmoothedAnimation { duration: Motion.morph; velocity: -1 } }
    TextMetrics { id: labelMetrics; text: root.label; font: labelText.font }
    Rectangle {
        objectName: "companionHoverPlate"
        x: 0; y: (root.height - height) / 2
        width: 30 * root.s; height: 26 * root.s
        radius: 10 * root.s
        scale: hit.motion.visualScale
        color: Qt.alpha(Theme.foreground, 0.045 * hit.motion.presence + 0.065 * hit.motion.pressure)
        border.width: hit.activeFocus ? Theme.borderHairline : 0
        border.color: Qt.alpha(Theme.accent, 0.65)
    }
    IslandCompanion {
        id: companion
        objectName: "activityCompanion"
        x: 0; y: (root.height - height) / 2
        s: root.s
        opacity: root.recordingShown ? 0 : 1
        visible: root.companionEnabled && opacity > 0.01
        Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.standardSmall } }
        mood: root.mood
        lookX: root.lookX; lookY: root.lookY
        engaged: hit.containsMouse || hit.activeFocus
        scale: hit.motion.visualScale
    }
    RecordingGlyph {
        objectName: "recordingIndicator"
        x: 0; y: (root.height - height) / 2
        s: root.s
        phase: root.recordingPhase
        countdown: root.recordingCountdown
        opacity: root.recordingShown ? 1 : 0
        visible: opacity > 0.01
        scale: hit.motion.visualScale
        Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.standardSmall } }
    }
    MaterialIcon {
        x: 5 * root.s
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.companionEnabled && !root.recordingShown && root.label.length > 0
        iconName: "timer"
        font.pixelSize: 20 * root.s
        color: Theme.accent
    }
    Text {
        id: labelText
        x: 34 * root.s
        width: Math.max(0, root.width - 42 * root.s)
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font.family: Theme.font
        font.pixelSize: Theme.fontSizeSmall * root.s
        font.weight: Font.Medium
        color: Theme.foreground
        elide: Text.ElideRight
    }
    MotionArea {
        id: hit
        objectName: "islandActivityHit"
        anchors.fill: parent
        accessibleName: root.label.length ? qsTr("%1 · %2").arg(root.actionName).arg(root.label) : root.actionName
        feedbackEnabled: false
        onContainsMouseChanged: if (containsMouse) companion.greet()
        onClicked: root.activated()
    }
}
