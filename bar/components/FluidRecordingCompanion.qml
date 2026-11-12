pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

FluidCompanion {
    id: root
    property bool focusActive: false
    property bool recordingActive: true
    property var activity: null
    property int activityCount: 0
    readonly property bool activityOnly: !focusActive && !recordingActive
    readonly property string resultKey: activity && activity.state !== "running" ? activity.id + activity.state + activity.endedAt : ""
    onResultKeyChanged: if (activity?.state === "done" && active) successSwell.kick(80)
    SpringValue {
        id: successSwell
        objectName: "activitySuccessSwell"
        spring: Motion.strokeSpring.lift
        active: root.active && root.activityCount > 0
        manualStep: root.manualStep
    }
    gestureDismissable: false
    surfaceSize: IslandGeometry.focusSurface
    property string recordingPhase: "recording"
    property string elapsedText: "00:00"
    property int countdown: 0
    property bool tallBar: false
    property int focusRemainingSeconds: 0
    readonly property string label: focusActive ? Math.floor(focusRemainingSeconds / 60) + ":" + String(focusRemainingSeconds % 60).padStart(2, "0") : recordingPhase === "unknown" ? I18n.tr("Sin conexión")
        : recordingPhase === "starting" ? I18n.tr("Iniciando…")
        : recordingPhase === "stopping" ? I18n.tr("Guardando…")
        : recordingPhase === "countdown" ? I18n.tr("En %1").arg(countdown) : elapsedText
    leftSide: true
    compactY: bodyY + (tallBar ? Math.max(0, (IslandGeometry.compactRestHeight * s - moduleH) / 2) : 0)
    surfaceName: !recordingActive || activityCount > 0 || focusActive ? "focus" : "recording"
    compactWidth: (activityOnly ? 82 * s : Math.max(94 * s, labelMetrics.width + 48 * s) + (activityCount > 0 ? 44 * s : 0)) + Math.max(0, successSwell.value) * s
    hoverWidth: activityCount > 0 ? Math.max(compactWidth, 252 * s) : compactWidth + 8 * s
    compactAccessibleName: activityCount > 0 ? I18n.tr("Abrir actividades: %1").arg(activity?.title || "") : focusActive ? I18n.tr("Foco") + ", " + label : recordingPhase === "paused" ? I18n.tr("Grabación en pausa, %1. Abrir controles").arg(label)
        : I18n.tr("Grabación, %1. Abrir controles").arg(label)
    signal requestRecording()
    onRequestToggle: requestRecording()

    TextMetrics {
        id: labelMetrics
        text: root.label
        font.family: Theme.fontMedia
        font.pixelSize: Theme.fontSizeBodyLg * root.s
        font.weight: Font.Medium
    }
    compactContent: Component {
        Item {
            anchors.fill: parent
            opacity: root.contentExposure * Math.max(0, Math.min(1,
                (root.wPos - (root.activityOnly ? 42 * root.s : labelMetrics.width + 39 * root.s)) / (8 * root.s)))
            visible: opacity > 0.01
            clip: true
            Row {
                anchors.centerIn: parent
                spacing: 3 * root.s
                ActivityDropContent {
                    activity: root.activity
                    count: root.activityCount
                    s: root.s
                    peek: root.hovered
                    width: root.hovered ? 228 * root.s : 42 * root.s
                    height: 36 * root.s
                    visible: root.activityCount > 0
                    anchors.verticalCenter: parent.verticalCenter
                }
                RecordingGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    s: root.s
                    visible: !root.focusActive && !root.activityOnly && !(root.hovered && root.activityCount > 0)
                    phase: root.recordingPhase
                    countdown: root.countdown
                }
                MaterialIcon {
                    visible: root.focusActive && !(root.hovered && root.activityCount > 0)
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: Icons.iClock
                    color: Theme.foreground
                    font.pixelSize: 18 * root.s
                }
                Text {
                    objectName: "recordingDropTime"
                    visible: !root.activityOnly && !(root.hovered && root.activityCount > 0)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.label
                    color: Theme.foreground
                    font.family: Theme.fontMedia
                    font.pixelSize: Theme.fontSizeBodyLg * root.s
                    font.weight: Font.Medium
                    font.features: ({ "tnum": 1 })
                }
            }
        }
    }
}
