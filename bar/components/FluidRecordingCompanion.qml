pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

FluidCompanion {
    id: root
    property string recordingPhase: "recording"
    property string elapsedText: "00:00"
    property int countdown: 0
    property bool tallBar: false
    readonly property string label: recordingPhase === "unknown" ? qsTr("Sin conexión")
        : recordingPhase === "starting" ? qsTr("Iniciando…")
        : recordingPhase === "stopping" ? qsTr("Guardando…")
        : recordingPhase === "countdown" ? qsTr("En %1").arg(countdown) : elapsedText
    leftSide: true
    compactY: bodyY + (tallBar ? Math.max(0, (IslandGeometry.compactRestHeight * s - moduleH) / 2) : 0)
    surfaceName: "recording"
    compactWidth: Math.max(94 * s, labelMetrics.width + 48 * s)
    hoverWidth: compactWidth + 8 * s
    compactAccessibleName: recordingPhase === "paused" ? qsTr("Grabación en pausa, %1. Abrir controles").arg(label)
        : qsTr("Grabación, %1. Abrir controles").arg(label)
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
                (root.wPos - labelMetrics.width - 39 * root.s) / (8 * root.s)))
            visible: opacity > 0.01
            clip: true
            Row {
                anchors.centerIn: parent
                spacing: 3 * root.s
                RecordingGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    s: root.s
                    phase: root.recordingPhase
                    countdown: root.countdown
                }
                Text {
                    objectName: "recordingDropTime"
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
