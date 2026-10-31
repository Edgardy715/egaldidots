pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../Singletons"
import "../"

FocusScope {
    id: root
    required property var session
    property real s: 1
    property bool open: false
    property bool showHeader: true
    property int selectedMinutes: 25
    property bool choosingNext: false
    signal closeRequested()
    signal feedbackRequested(string kind)
    readonly property bool completed: !choosingNext && !session.active && session.durationSeconds > 0 && session.remainingSeconds === 0
    readonly property int displaySeconds: session.active || completed ? session.remainingSeconds : selectedMinutes * 60
    readonly property string statusText: session.paused ? qsTr("En pausa") : session.running ? qsTr("Un momento para concentrarte") : completed ? qsTr("Sesión completada") : qsTr("Elige tu tiempo")
    readonly property string timeText: String(Math.floor(displaySeconds / 60)).padStart(2, "0") + ":" + String(displaySeconds % 60).padStart(2, "0")
    implicitHeight: content.implicitHeight
    onSelectedMinutesChanged: if (!session.active) choosingNext = true
    Connections {
        target: root.session
        function onFinished() { root.choosingNext = false }
    }

    onOpenChanged: if (open) primary.forceActiveFocus()
    Keys.onEscapePressed: event => { root.closeRequested(); event.accepted = true }

    // Chip de duración: cápsula que se rellena de acento al elegirla.
    component DurationChip: MotionButton {
        id: chip
        property bool selected: false
        Layout.preferredHeight: 36 * root.s
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        font.family: Theme.font
        font.pixelSize: Theme.fontSizeBody * root.s
        font.weight: chip.selected ? Font.DemiBold : Font.Medium
        font.features: Theme.fontNumeric
        contentItem: Text {
            text: chip.text
            font: chip.font
            color: chip.selected ? Theme.primaryContent : Theme.foreground
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        }
        background: Rectangle {
            radius: height / 2
            color: chip.selected ? Theme.accent : Qt.alpha(Theme.foreground, chip.hovered ? Theme.alphaWash : Theme.alphaFaint)
            border.width: chip.visualFocus ? 2 : Theme.borderHairline
            border.color: chip.visualFocus ? Theme.accent : chip.selected ? "transparent" : Qt.alpha(Theme.foreground, Theme.alphaHair)
            Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: Theme.spacingXl * root.s
        RowLayout {
            Layout.fillWidth: true
            visible: root.showHeader
            SurfaceHeader {
                Layout.fillWidth: true
                title: qsTr("Enfoque")
                subtitle: root.statusText
                s: root.s
            }
            CtrlBtn { iconName: "close"; size: 30; s: root.s; accessibleName: qsTr("Cerrar enfoque"); onClicked: root.closeRequested() }
        }

        // Cifra y estado centrados en el espacio libre, igual que Grabación.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: (Theme.fontSizeCover * 1.3 + Theme.fontSizeBodyLg + 26) * root.s
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width
                spacing: 6 * root.s
                Text {
                    Layout.fillWidth: true
                    text: root.timeText
                    color: root.session.paused ? Theme.iconSecondary : Theme.foreground
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.fontMedia
                    font.pixelSize: Theme.fontSizeCover * root.s
                    font.weight: Font.Medium
                    font.features: Theme.fontNumeric
                    Accessible.name: qsTr("Tiempo restante: %1").arg(root.timeText)
                    Behavior on color { ColorAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                }
                AnimatedLabel {
                    objectName: "focusStatus"
                    Layout.fillWidth: true
                    visible: !root.showHeader
                    value: root.statusText
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.iconSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeBodyLg * root.s
                }
                TimeRing {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8 * root.s
                    s: root.s
                    progress: root.session.progress
                    active: root.session.active
                    running: root.session.running
                    completed: root.completed
                }
            }
        }

        // Duración: tres atajos y un campo libre en la misma fila de cápsulas.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd * root.s
            visible: !root.session.active
            Repeater {
                model: [15, 25, 45]
                DurationChip {
                    required property int modelData
                    text: qsTr("%1 min").arg(modelData)
                    selected: root.selectedMinutes === modelData && minutesInput.text === String(modelData)
                    onClicked: { root.choosingNext = true; root.selectedMinutes = modelData; minutesInput.text = String(modelData) }
                }
            }
            Rectangle {
                id: customField
                readonly property bool custom: [15, 25, 45].indexOf(Number(minutesInput.text)) < 0
                // Con un atajo elegido el campo no repite su cifra: se presenta como «Otro».
                readonly property bool idle: !custom && !minutesInput.activeFocus
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 36 * root.s
                radius: height / 2
                color: custom && minutesInput.acceptableInput ? Qt.alpha(Theme.accent, Theme.alphaChip) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                border.width: minutesInput.activeFocus ? 2 : Theme.borderHairline
                border.color: minutesInput.activeFocus || !minutesInput.acceptableInput ? Theme.accent : Qt.alpha(Theme.foreground, Theme.alphaHair)
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10 * root.s; anchors.rightMargin: 12 * root.s
                    spacing: Theme.spacingXs * root.s
                    IslaTextField {
                        id: minutesInput
                        objectName: "focusMinutes"
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        text: "25"
                        floating: false
                        chrome: false
                        horizontalAlignment: Text.AlignRight
                        font.pixelSize: Theme.fontSizeBody * root.s
                        font.weight: Font.DemiBold
                        font.features: Theme.fontNumeric
                        color: customField.idle ? "transparent" : Theme.foreground
                        onActiveFocusChanged: if (activeFocus && !customField.custom) selectAll()
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator { bottom: 1; top: 180 }
                        Accessible.name: qsTr("Duración en minutos, entre 1 y 180")
                        onTextEdited: { root.choosingNext = true; if (acceptableInput) root.selectedMinutes = Number(text) }
                        onAccepted: if (acceptableInput && root.session.start(Number(text))) root.feedbackRequested("received")
                    }
                    Text {
                        text: qsTr("min")
                        visible: !customField.idle
                        color: Theme.iconSecondary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeBody * root.s
                    }
                }
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingSm * root.s
                    visible: customField.idle
                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "edit"
                        color: Theme.iconSecondary
                        font.pixelSize: 15 * root.s
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Otro")
                        color: Theme.iconSecondary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeBody * root.s
                        font.weight: Font.Medium
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd * root.s
            MotionButton {
                id: primary
                objectName: "focusPrimary"
                Layout.fillWidth: true
                Layout.preferredHeight: 52 * root.s
                enabled: root.session.active || minutesInput.acceptableInput
                text: root.session.running ? qsTr("Pausar") : root.session.paused ? qsTr("Continuar") : qsTr("Iniciar")
                Accessible.name: text
                onClicked: {
                    const kind = root.session.running ? "paused" : "received"
                    const accepted = root.session.running ? root.session.pause() : root.session.paused ? root.session.resume() : root.session.start(Number(minutesInput.text))
                    if (accepted) root.feedbackRequested(kind)
                }
                background: Rectangle {
                    radius: height / 2
                    color: root.session.running ? Qt.alpha(Theme.foreground, primary.hovered ? Theme.alphaWashStrong : Theme.alphaWash) : Theme.accent
                    opacity: primary.enabled ? 1 : Theme.alphaDisabled
                    border.width: primary.visualFocus ? 2 : 0
                    border.color: Theme.foreground
                    Behavior on color { ColorAnimation { duration: Motion.morph; easing.type: Motion.easeStandard } }
                    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                }
                contentItem: RowLayout {
                    spacing: 6 * root.s
                    Item { Layout.fillWidth: true }
                    PlayPauseGlyph {
                        playing: root.session.running
                        color: root.session.running ? Theme.foreground : Theme.primaryContent
                        size: 22 * root.s
                        Behavior on color { ColorAnimation { duration: Motion.morph; easing.type: Motion.easeStandard } }
                    }
                    CrossfadeLabel {
                        value: primary.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeBodyLg * root.s
                        font.weight: Font.DemiBold
                        color: root.session.running ? Theme.foreground : Theme.primaryContent
                        Behavior on color { ColorAnimation { duration: Motion.morph; easing.type: Motion.easeStandard } }
                    }
                    Item { Layout.fillWidth: true }
                }
            }
            MotionButton {
                id: cancel
                objectName: "focusCancel"
                visible: root.session.active
                Layout.preferredWidth: 52 * root.s
                Layout.preferredHeight: 52 * root.s
                text: qsTr("Cancelar")
                Accessible.name: text
                onClicked: root.session.cancel()
                contentItem: MaterialIcon {
                    iconName: "stop"
                    interaction: cancel.interaction
                    color: Theme.foreground
                    font.pixelSize: 22 * root.s
                }
                background: Rectangle {
                    radius: height / 2
                    color: Qt.alpha(Theme.foreground, cancel.hovered ? Theme.alphaWash : Theme.alphaFaint)
                    border.width: cancel.visualFocus ? 2 : 0
                    border.color: Theme.accent
                }
            }
        }
        Text {
            objectName: "focusFootnote"
            Layout.fillWidth: true
            text: !root.session.active && !minutesInput.acceptableInput ? qsTr("Elige entre 1 y 180 minutos") : qsTr("Sesión temporal · se descarta al reiniciar Isla")
            color: !root.session.active && !minutesInput.acceptableInput ? Theme.accent : Theme.iconSecondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeSmall * root.s
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}
