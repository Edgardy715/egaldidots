pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../"
import "../Singletons"
import "../settings"

FocusScope {
    id: root
    required property var session
    required property var recorder
    property real s: 1
    property bool open: false
    property int selectedPage: 0
    signal closeRequested()
    signal feedbackRequested(string kind)
    signal recordingStartRequested()
    signal recordingStopRequested()
    signal recordingPauseRequested()
    signal recordingResumeRequested()
    signal recordingRefreshRequested()
    signal recordingCountdownCancelRequested()
    signal openOutputRequested()
    signal systemAudioToggled()
    signal microphoneAudioToggled()
    onSelectedPageChanged: if (selectedPage !== 1) root.recordingCountdownCancelRequested()
    Keys.onEscapePressed: event => { root.closeRequested(); event.accepted = true }

    EdotsPageMotion {
        id: pageMotion
        requestedPage: root.selectedPage
        active: root.open
        reduced: Flags.reduceMotion
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 16 * root.s
        RowLayout {
            Layout.fillWidth: true
            SurfaceHeader {
                Layout.fillWidth: true
                s: root.s
                title: qsTr("Actividades")
                subtitle: root.selectedPage === 1 ? qsTr("Pantalla y audio") : qsTr("Tu tiempo y tus capturas")
            }
            CtrlBtn { iconName: "close"; size: 30; s: root.s; accessibleName: qsTr("Cerrar actividades"); onClicked: root.closeRequested() }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42 * root.s
            radius: 13 * root.s
            color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
            Rectangle {
                x: 3 * root.s + root.selectedPage * (parent.width - 6 * root.s) / 2
                y: 3 * root.s
                width: (parent.width - 6 * root.s) / 2
                height: parent.height - 6 * root.s
                radius: 10 * root.s
                color: Qt.alpha(Theme.foreground, Theme.alphaWash)
                Behavior on x { enabled: !Flags.reduceMotion && root.visible; SmoothedAnimation { duration: Motion.standard; velocity: -1 } }
            }
            Row {
                anchors.fill: parent
                anchors.margins: 3 * root.s
                Repeater {
                    model: [qsTr("Enfoque"), qsTr("Grabación")]
                    MotionButton {
                        id: tab
                        required property int index
                        required property string modelData
                        objectName: index === 0 ? "focusTab" : "recordingTab"
                        width: parent.width / 2; height: parent.height
                        text: modelData
                        Accessible.role: Accessible.PageTab
                        Accessible.name: text
                        Accessible.checked: root.selectedPage === index
                        contentItem: Text {
                            text: tab.text
                            color: root.selectedPage === tab.index ? Theme.foreground : Theme.iconSecondary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSizeBodyLg * root.s
                            font.weight: root.selectedPage === tab.index ? Font.DemiBold : Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle { radius: 10 * root.s; color: "transparent"; border.width: tab.activeFocus ? Theme.borderHairline : 0; border.color: Theme.accent }
                        onClicked: root.selectedPage = index
                        Keys.onLeftPressed: { root.selectedPage = 0 }
                        Keys.onRightPressed: { root.selectedPage = 1 }
                    }
                }
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            opacity: pageMotion.exposure
            transform: Translate { x: Flags.reduceMotion ? 0 : pageMotion.travel * root.s }
            FocusTimerView {
                anchors.fill: parent
                session: root.session
                showHeader: false
                s: root.s
                visible: pageMotion.displayedPage === 0
                open: root.open && visible
                onCloseRequested: root.closeRequested()
                onFeedbackRequested: kind => root.feedbackRequested(kind)
            }
            RecordingView {
                anchors.fill: parent
                s: root.s
                visible: pageMotion.displayedPage === 1
                open: root.open && visible
                phase: root.recorder.phase
                connected: root.recorder.connected
                setupRequired: root.recorder.setupRequired
                elapsedSeconds: root.recorder.elapsedSeconds
                countdown: root.recorder.countdown
                outputPath: root.recorder.outputPath
                error: root.recorder.error
                requestBusy: root.recorder.busy
                pauseSupported: root.recorder.pauseSupported
                onStartRequested: root.recordingStartRequested()
                onStopRequested: root.recordingStopRequested()
                onPauseRequested: root.recordingPauseRequested()
                onResumeRequested: root.recordingResumeRequested()
                onRefreshRequested: root.recordingRefreshRequested()
                systemAudio: root.recorder.systemAudio
                microphoneAudio: root.recorder.microphoneAudio
                onSystemAudioToggled: root.systemAudioToggled()
                onMicrophoneAudioToggled: root.microphoneAudioToggled()
                onOpenOutputRequested: root.openOutputRequested()
            }
        }
    }
}
