pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../Singletons"

FocusScope {
    id: root
    property real s: 1
    property bool open: false
    property string phase: "offline"
    property bool requestBusy: false
    property bool pauseSupported: true
    property bool connected: false
    property bool setupRequired: false
    property int elapsedSeconds: 0
    property int countdown: 3
    property string outputPath: ""
    property string error: ""
    signal startRequested()
    signal stopRequested()
    signal pauseRequested()
    signal resumeRequested()
    signal refreshRequested()
    property bool systemAudio: true
    property bool microphoneAudio: false
    signal systemAudioToggled()
    signal microphoneAudioToggled()
    signal openOutputRequested()

    readonly property bool active: phase === "recording" || phase === "paused"
    readonly property bool busy: requestBusy || phase === "starting" || phase === "stopping"
    readonly property bool counting: phase === "countdown"
    readonly property bool ready: connected && !setupRequired && phase === "idle"
    readonly property bool needsConnection: !connected || setupRequired || phase === "offline"
    readonly property bool motionAllowed: open && visible && !Flags.reduceMotion
    readonly property bool outputAvailable: phase === "idle" && outputPath.length > 0
    readonly property string timeText: {
        const seconds = Math.max(0, elapsedSeconds)
        const minutes = String(Math.floor(seconds / 60) % 60).padStart(2, "0")
        const remainder = String(seconds % 60).padStart(2, "0")
        return seconds >= 3600 ? String(Math.floor(seconds / 3600)).padStart(2, "0") + ":" + minutes + ":" + remainder : minutes + ":" + remainder
    }
    readonly property string statusText: phase === "recording" ? qsTr("Grabando pantalla")
        : phase === "paused" ? qsTr("Grabación en pausa")
        : counting ? qsTr("Prepárate") : phase === "starting" ? qsTr("Elige qué compartir…")
        : phase === "stopping" ? qsTr("Guardando grabación…") : phase === "error" ? qsTr("No se pudo completar la acción")
        : needsConnection ? qsTr("Grabador no disponible") : outputAvailable ? qsTr("Grabación finalizada") : qsTr("Listo para grabar")
    readonly property string primaryText: active ? qsTr("Detener grabación") : counting ? qsTr("Cancelar cuenta atrás")
        : phase === "starting" ? qsTr("Iniciando…") : phase === "stopping" ? qsTr("Finalizando…") : qsTr("Iniciar grabación")
    implicitHeight: content.implicitHeight

    onMotionAllowedChanged: if (!motionAllowed) { shapeRadiusMotion.complete(); symbolSizeMotion.complete(); symbolRadiusMotion.complete() }
    onOpenChanged: if (open) Qt.callLater(() => { if (root.needsConnection || root.phase === "error") refresh.forceActiveFocus(); else primary.forceActiveFocus() })

    component ActionButton: MotionButton {
        id: control
        Layout.fillWidth: true
        Layout.preferredHeight: 42 * root.s
        font.family: Theme.font
        font.pixelSize: Theme.fontSizeBodyLg * root.s
        contentItem: Text {
            text: control.text
            font: control.font
            color: control.enabled ? Theme.foreground : Theme.iconMuted
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: Theme.radiusXl * root.s
            color: Qt.alpha(Theme.foreground, control.hovered ? Theme.alphaWash : Theme.alphaFaint)
            border.width: control.activeFocus ? 2 : 0
            border.color: Theme.accent
        }
    }

    component AudioControl: MotionButton {
        id: control
        required property string label
        required property string iconName
        required property bool selected
        Layout.fillWidth: true
        Layout.preferredHeight: 52 * root.s
        enabled: root.open && root.ready && !root.busy
        Accessible.role: Accessible.CheckBox
        Accessible.name: label
        Accessible.checkable: true
        Accessible.checked: selected
        contentItem: RowLayout {
            spacing: 12 * root.s
            MaterialIcon {
                iconName: control.iconName
                font.pixelSize: 21 * root.s
                color: control.selected ? Theme.foreground : Theme.iconSecondary
                Accessible.ignored: true
            }
            Text {
                Layout.fillWidth: true
                text: control.label
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                color: Theme.foreground
                elide: Text.ElideRight
            }
            Rectangle {
                Layout.preferredWidth: 34 * root.s
                Layout.preferredHeight: 20 * root.s
                radius: height / 2
                color: control.selected ? Theme.accent : Qt.alpha(Theme.foreground, Theme.alphaWashStrong)
                opacity: control.enabled ? 1 : 0.5
                Rectangle {
                    x: (control.selected ? 16 : 3) * root.s
                    y: 3 * root.s
                    width: 14 * root.s; height: width; radius: width / 2
                    color: control.selected ? Theme.primaryContent : Theme.foreground
                    Behavior on x { enabled: root.motionAllowed; SmoothedAnimation { duration: Motion.standardSmall; velocity: -1 } }
                }
                Accessible.ignored: true
            }
        }
        leftPadding: 16 * root.s; rightPadding: 16 * root.s
        background: Rectangle {
            radius: 13 * root.s
            color: Qt.alpha(Theme.foreground, control.hovered && control.enabled ? Theme.alphaFaint : 0)
            border.width: control.activeFocus ? 2 : 0
            border.color: Theme.accent
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: 12 * root.s
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: (Theme.fontSizeCover * 1.3 + Theme.fontSizeBodyLg + 8) * root.s
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width
                spacing: 6 * root.s
                Text {
                    objectName: "recordingTime"
                    Layout.fillWidth: true
                    text: root.counting ? String(Math.max(1, root.countdown)) : root.needsConnection ? "—" : root.timeText
                    horizontalAlignment: Text.AlignHCenter
                    color: root.needsConnection ? Theme.iconSecondary : Theme.foreground
                    font.family: Theme.fontMedia
                    font.pixelSize: Theme.fontSizeCover * root.s
                    font.weight: Font.Medium
                    font.features: ({ "tnum": 1 })
                    Accessible.name: root.counting ? qsTr("La grabación comienza en %1").arg(root.countdown) : qsTr("Duración de grabación: %1").arg(root.timeText)
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 7 * root.s
                    Rectangle {
                        width: 5 * root.s; height: width; radius: width / 2
                        color: root.active ? Theme.error : Theme.iconSecondary
                        visible: root.active
                        Accessible.ignored: true
                    }
                    AnimatedLabel {
                        value: root.statusText
                        color: Theme.iconSecondary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeBodyLg * root.s
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: audioRows.implicitHeight
            visible: !root.needsConnection && root.phase !== "error"
            radius: 16 * root.s
            color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
            ColumnLayout {
                id: audioRows
                width: parent.width
                spacing: 0
                AudioControl {
                    objectName: "recordingSystemAudio"
                    label: qsTr("Audio del sistema")
                    iconName: root.systemAudio ? "volume_up" : "volume_off"
                    selected: root.systemAudio
                    onClicked: root.systemAudioToggled()
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 49 * root.s; Layout.rightMargin: 16 * root.s
                    height: 1
                    color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
                }
                AudioControl {
                    objectName: "recordingMicrophone"
                    label: qsTr("Micrófono")
                    iconName: root.microphoneAudio ? "mic" : "mic_off"
                    selected: root.microphoneAudio
                    onClicked: root.microphoneAudioToggled()
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: !root.needsConnection && root.phase !== "error"
            spacing: 10 * root.s
            MotionButton {
                id: primary
                objectName: "recordingPrimary"
                Layout.fillWidth: true
                Layout.preferredHeight: 52 * root.s
                enabled: root.open && !root.busy && (root.ready || root.active || root.counting)
                text: root.primaryText
                Accessible.name: text
                onClicked: {
                    if (root.active || root.counting) root.stopRequested()
                    else if (root.ready) root.startRequested()
                }
                background: Rectangle {
                    id: primaryShape
                    objectName: "recordingPrimaryShape"
                    radius: (root.active || root.busy ? 18 : 26) * root.s
                    color: root.active || root.busy ? Qt.alpha(Theme.foreground, primary.hovered ? Theme.alphaWashStrong : Theme.alphaWash) : Theme.accent
                    opacity: primary.enabled ? 1 : 0.5
                    border.width: primary.activeFocus ? 2 : 0
                    border.color: Theme.foreground
                    Behavior on radius { SmoothedAnimation { id: shapeRadiusMotion; duration: root.motionAllowed ? Motion.morph : 0; velocity: -1 } }
                }
                contentItem: RowLayout {
                    spacing: 9 * root.s
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: (root.active || root.phase === "stopping" ? 13 : root.counting ? 11 : 16) * root.s
                        height: width
                        radius: (root.active || root.phase === "stopping" || root.counting ? 3 : 8) * root.s
                        color: root.active ? Theme.error : root.busy ? Theme.foreground : Theme.primaryContent
                        Accessible.ignored: true
                        Behavior on width { SmoothedAnimation { id: symbolSizeMotion; duration: root.motionAllowed ? Motion.standardSmall : 0; velocity: -1 } }
                        Behavior on radius { SmoothedAnimation { id: symbolRadiusMotion; duration: root.motionAllowed ? Motion.standardSmall : 0; velocity: -1 } }
                    }
                    Text {
                        text: primary.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeBodyLg * root.s
                        font.weight: Font.DemiBold
                        color: root.active || root.busy ? Theme.foreground : Theme.primaryContent
                    }
                    Item { Layout.fillWidth: true }
                }
            }
            MotionButton {
                id: pause
                objectName: "recordingPause"
                Layout.preferredWidth: 52 * root.s; Layout.preferredHeight: 52 * root.s
                visible: root.active
                enabled: root.open && !root.busy && root.pauseSupported
                text: !root.pauseSupported ? qsTr("Pausa no disponible") : root.phase === "paused" ? qsTr("Continuar") : qsTr("Pausar")
                Accessible.name: text
                onClicked: if (root.phase === "paused") root.resumeRequested(); else root.pauseRequested()
                contentItem: MaterialIcon {
                    iconName: root.phase === "paused" ? "play_arrow" : "pause"
                    font.pixelSize: 22 * root.s
                    color: pause.enabled ? Theme.foreground : Theme.iconMuted
                }
                background: Rectangle {
                    radius: height / 2
                    color: Qt.alpha(Theme.foreground, pause.hovered ? Theme.alphaWash : Theme.alphaFaint)
                    border.width: pause.activeFocus ? 2 : 0
                    border.color: Theme.accent
                }
            }
        }
        ActionButton {
            id: refresh
            objectName: "recordingRefresh"
            visible: root.needsConnection || root.phase === "error"
            enabled: root.open
            text: qsTr("Reintentar")
            onClicked: root.refreshRequested()
        }
        Text {
            objectName: "recordingHelp"
            Layout.fillWidth: true
            Layout.minimumHeight: 32 * root.s
            text: root.error ? root.error : root.phase === "error" ? qsTr("No se ha confirmado el guardado. Puedes volver a intentarlo.")
                : root.needsConnection ? qsTr("Instala gpu-screen-recorder para grabar con aceleración por hardware.")
                : root.busy ? qsTr("Esperando al grabador o al selector de pantalla…")
                : root.counting ? qsTr("Puedes cancelar antes de que comience.")
                : root.active ? qsTr("El audio se mantiene como lo configuraste al iniciar.")
                : root.outputAvailable ? qsTr("Guardada en Vídeos/Recordings.") : qsTr("Elige pantalla o ventana al empezar.")
            textFormat: Text.PlainText
            color: (root.error && !root.setupRequired) || root.phase === "error" ? Theme.error : Theme.iconSecondary
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeBody * root.s
        }
        ActionButton {
            id: output
            objectName: "recordingOutput"
            visible: root.outputAvailable
            enabled: root.open && root.outputAvailable
            text: qsTr("Abrir grabación")
            Accessible.description: root.outputPath
            onClicked: root.openOutputRequested()
        }
    }
}
