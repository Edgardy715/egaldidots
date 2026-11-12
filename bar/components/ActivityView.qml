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
    property double durationNow: Date.now()
    Timer {
        objectName: "activityDurationClock"
        interval: 1000; repeat: true; triggeredOnStart: true
        running: root.open && pageMotion.displayedPage === 2 && Activities.hasLive
        onTriggered: root.durationNow = Date.now()
    }
    readonly property var activityRows: {
        const rows = Activities.list.slice()
        if (session.active) rows.push({id: "internal:focus", title: I18n.tr("Enfoque"), subtitle: Math.floor(session.remainingSeconds / 60) + ":" + String(session.remainingSeconds % 60).padStart(2, "0"), icon: "schedule", progress: session.progress, state: "running", internalPage: 0})
        if (recorder.engaged) rows.push({id: "internal:recording", title: I18n.tr("Grabación"), subtitle: recorder.timeText || "", icon: "fiber_manual_record", progress: -1, state: "running", internalPage: 1})
        return rows
    }
    function consumeListRequest() {
        if (open && Activities.requestList) { selectedPage = 2; Activities.requestList = false }
    }
    onOpenChanged: consumeListRequest()
    Component.onCompleted: consumeListRequest()
    Connections { target: Activities; function onRequestListChanged() { root.consumeListRequest() } }
    function duration(item) {
        if (!item.startedAt) return ""
        const seconds = Math.max(0, Math.floor(((item.endedAt || durationNow) - item.startedAt) / 1000))
        return seconds >= 60 ? Math.floor(seconds / 60) + " m " + seconds % 60 + " s" : seconds + " s"
    }
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
                title: I18n.tr("Actividades")
                subtitle: root.selectedPage === 2 ? I18n.tr("Procesos en curso y recientes") : root.selectedPage === 1 ? I18n.tr("Pantalla y audio") : I18n.tr("Tu tiempo y tus capturas")
            }
            CtrlBtn { iconName: "close"; size: 30; s: root.s; accessibleName: I18n.tr("Cerrar actividades"); onClicked: root.closeRequested() }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42 * root.s
            radius: 13 * root.s
            color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
            Rectangle {
                x: 3 * root.s + root.selectedPage * (parent.width - 6 * root.s) / 3
                y: 3 * root.s
                width: (parent.width - 6 * root.s) / 3
                height: parent.height - 6 * root.s
                radius: 10 * root.s
                color: Qt.alpha(Theme.foreground, Theme.alphaWash)
                Behavior on x { enabled: !Flags.reduceMotion && root.visible; SmoothedAnimation { duration: Motion.standard; velocity: -1 } }
            }
            Row {
                anchors.fill: parent
                anchors.margins: 3 * root.s
                Repeater {
                    model: [I18n.tr("Enfoque"), I18n.tr("Grabación"), I18n.tr("Procesos")]
                    MotionButton {
                        id: tab
                        required property int index
                        required property string modelData
                        objectName: index === 0 ? "focusTab" : index === 1 ? "recordingTab" : "activitiesTab"
                        width: parent.width / 3; height: parent.height
                        text: modelData
                        Accessible.role: Accessible.PageTab
                        Accessible.name: text
                        Accessible.checked: root.selectedPage === index
                        contentItem: Text {
                            text: tab.text
                            color: root.selectedPage === tab.index ? Theme.foreground : Theme.iconSecondary
                            Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSizeBodyLg * root.s
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle { radius: 10 * root.s; color: "transparent"; border.width: tab.activeFocus ? Theme.borderHairline : 0; border.color: Theme.accent }
                        onClicked: root.selectedPage = index
                        Keys.onLeftPressed: { root.selectedPage = Math.max(0, root.selectedPage - 1) }
                        Keys.onRightPressed: { root.selectedPage = Math.min(2, root.selectedPage + 1) }
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
            Flickable {
                id: activityScroll
                objectName: "activityList"
                anchors.fill: parent
                visible: pageMotion.displayedPage === 2
                clip: true
                contentWidth: width
                contentHeight: activityColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: activityColumn
                    width: activityScroll.width
                    spacing: 8 * root.s
                    Text {
                        width: parent.width
                        visible: root.activityRows.length === 0
                        text: I18n.tr("No hay actividades en curso.")
                        textFormat: Text.PlainText
                        color: Theme.iconSecondary
                        font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s
                        wrapMode: Text.WordWrap
                    }
                    Repeater {
                        model: root.activityRows
                        Rectangle {
                            id: activityRow
                            required property var modelData
                            width: activityColumn.width
                            height: 82 * root.s
                            radius: 12 * root.s
                            color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 12 * root.s
                                spacing: 12 * root.s
                                ConfirmationIndicator {
                                    Layout.preferredWidth: 28 * root.s; Layout.preferredHeight: 28 * root.s
                                    visible: root.open && activityScroll.visible
                                    status: activityRow.modelData.state === "done" ? "success" : activityRow.modelData.state === "failed" ? "error"
                                        : activityRow.modelData.progress >= 0 ? "progress" : "busy"
                                    progress: activityRow.modelData.progress
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2 * root.s
                                    Text {
                                        Layout.fillWidth: true; text: activityRow.modelData.title
                                        textFormat: Text.PlainText; elide: Text.ElideRight
                                        color: Theme.foreground; font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg * root.s
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: [activityRow.modelData.subtitle, root.duration(activityRow.modelData)].filter(Boolean).join(" · ")
                                        textFormat: Text.PlainText; elide: Text.ElideRight
                                        color: Theme.iconSecondary; font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * root.s
                                    }
                                }
                                CtrlBtn {
                                    objectName: "activityAction_" + activityRow.modelData.id
                                    s: root.s; size: 30
                                    iconName: activityRow.modelData.internalPage !== undefined ? "open_in_new" : "close"
                                    accessibleName: activityRow.modelData.internalPage !== undefined ? I18n.tr("Abrir %1").arg(activityRow.modelData.title) : I18n.tr("Quitar %1").arg(activityRow.modelData.title)
                                    onClicked: {
                                        if (activityRow.modelData.internalPage !== undefined) root.selectedPage = activityRow.modelData.internalPage
                                        else Activities.remove(activityRow.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
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
