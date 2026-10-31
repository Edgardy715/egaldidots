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
    readonly property bool recordingShown: recordingPhase.length > 0
    property var companionContext: null
    property real lookX: 0
    property real lookY: 0
    property bool asleep: false
    property bool sleepy: false
    property bool listening: false
    readonly property point faceCenter: Qt.point(companion.x + companion.width / 2, companion.y + companion.height / 2)
    readonly property bool statusIconShown: recordingShown || (!companionEnabled && label.length > 0)
    readonly property real statusX: companionEnabled ? 36 * s : 0
    readonly property real labelX: statusX + (statusIconShown ? 30 * s : 0)
    width: labelX + (label.length ? Math.min(156 * s, labelMetrics.width) + 10 * s : 0)
    height: coreH
    visible: width > 0
    clip: true
    Behavior on width { enabled: !Flags.reduceMotion; SmoothedAnimation { duration: Motion.morph; velocity: -1 } }
    TextMetrics { id: labelMetrics; text: root.label; font: labelText.font }
    Rectangle {
        id: plate
        objectName: "companionHoverPlate"
        visible: root.companionEnabled
        x: 0; y: (root.height - height) / 2
        width: 30 * root.s; height: 26 * root.s
        radius: (10 + companion.touch * 3) * root.s
        scale: hit.motion.visualScale
        transform: [
            Scale { origin.x: plate.width / 2; origin.y: plate.height / 2; xScale: companion.materialScaleX; yScale: companion.materialScaleY },
            Translate { x: companion.materialX; y: companion.materialY }
        ]
        color: Qt.alpha(Theme.foreground, 0.045 * hit.motion.presence + 0.065 * hit.motion.pressure + 0.055 * companion.touch)
        border.width: hit.activeFocus ? Theme.borderHairline : 0
        border.color: Qt.alpha(Theme.accent, 0.65)
    }
    IslandCompanion {
        id: companion
        objectName: "activityCompanion"
        x: 0; y: (root.height - height) / 2
        s: root.s
        visible: root.companionEnabled
        context: root.companionContext
        mood: root.mood
        asleep: root.asleep; sleepy: root.sleepy; listening: root.listening
        lookX: root.lookX; lookY: root.lookY
        engaged: hit.containsMouse || hit.activeFocus
        scale: hit.motion.visualScale
    }
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
        visible: !root.companionEnabled && !root.recordingShown && root.label.length > 0
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
    MotionArea {
        id: hit
        objectName: "islandActivityHit"
        width: 30 * root.s
        height: parent.height
        visible: root.companionEnabled
        enabled: visible
        accessibleName: qsTr("Jugar con Iris")
        feedbackEnabled: false
        onContainsMouseChanged: companion.approachPointer(containsMouse)
        onClicked: companion.interact()
    }
    // Distance and speed are measured in unscaled face coordinates.
    HoverHandler {
        id: stroke
        enabled: root.companionEnabled
        parent: hit
        property real lastX: -1
        property real lastY: 0
        property int dir: 0
        property int turns: 0
        property real since: 0
        property real lastPat: 0
        property double lastMove: 0
        onHoveredChanged: { lastX = -1; dir = 0; turns = 0; lastMove = Date.now() }
        onPointChanged: {
            if (!hovered) return
            const x = point.position.x
            const y = point.position.y
            if (lastX < 0) { lastX = x; lastY = y; since = Date.now(); return }
            const dx = x - lastX, dy = y - lastY
            const distance = Math.hypot(dx, dy)
            if (distance < 3 * root.s) return
            const d = Math.abs(dx) >= Math.abs(dy) ? (dx > 0 ? 1 : -1) : (dy > 0 ? 1 : -1)
            const now = Date.now()
            const speed = distance / root.s * 1000 / Math.max(16, now - lastMove)
            companion.stroke(speed, d, x / hit.width * 2 - 1)
            lastMove = now
            if (speed > 550) turns = 0
            else if (dir !== 0 && d !== dir) {
                if (now - since > 1400) { turns = 0; since = now }
                if (++turns >= 3 && now - lastPat >= 1800) { turns = 0; lastPat = now; companion.pat() }
            }
            dir = d
            lastX = x; lastY = y
        }
    }
}
