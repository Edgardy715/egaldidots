import QtQuick
import Quickshell
import "../"
import "../components"
import "../Singletons"

PillSurface {
    id: root
    property var session: FocusSession
    property var recorder: Recording
    property int initialPage: 0
    readonly property alias selectedPage: view.selectedPage
    onActiveChanged: if (!active) recorder.cancelCountdown()
    Component.onDestruction: recorder.cancelCountdown()
    mTop: 24; mLeft: 24; mRight: 24; mBottom: 24

    ActivityView {
        id: view
        anchors.fill: parent
        session: root.session
        recorder: root.recorder
        selectedPage: root.initialPage
        s: root.s
        open: root.contentReady
        onCloseRequested: root.requestClose()
        onFeedbackRequested: kind => root.feedbackRequested(kind)
        onRecordingStartRequested: root.recorder.start()
        onRecordingStopRequested: root.recorder.stop()
        onRecordingPauseRequested: root.recorder.pause()
        onRecordingResumeRequested: root.recorder.resume()
        onRecordingRefreshRequested: root.recorder.refresh()
        onRecordingCountdownCancelRequested: root.recorder.cancelCountdown()
        onSystemAudioToggled: root.recorder.systemAudio = !root.recorder.systemAudio
        onMicrophoneAudioToggled: root.recorder.microphoneAudio = !root.recorder.microphoneAudio
        onOpenOutputRequested: {
            if (root.recorder.outputPath.startsWith("/"))
                Qt.openUrlExternally("file://" + root.recorder.outputPath.split("/").map(encodeURIComponent).join("/"))
        }
    }
}
