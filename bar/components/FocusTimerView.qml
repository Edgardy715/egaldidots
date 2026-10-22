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
    readonly property string timeText: String(Math.floor(displaySeconds / 60)).padStart(2, "0") + ":" + String(displaySeconds % 60).padStart(2, "0")
    implicitHeight: content.implicitHeight
    onSelectedMinutesChanged: if (!session.active) choosingNext = true
    Connections {
        target: root.session
        function onFinished() { root.choosingNext = false }
    }

    onOpenChanged: if (open) primary.forceActiveFocus()
    Keys.onEscapePressed: event => { root.closeRequested(); event.accepted = true }

    component FocusButton: MotionButton {
        id: control
        property bool selected: false
        Layout.preferredHeight: 42 * root.s
        Layout.fillWidth: true
        font.family: Theme.font
        font.pixelSize: Theme.fontSizeBodyLg * root.s
        contentItem: Text {
            text: control.text
            font: control.font
            color: control.selected ? Theme.primaryContent : Theme.foreground
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: Theme.radiusLg * root.s
            color: control.selected ? Theme.accent : Qt.alpha(Theme.foreground, control.hovered ? Theme.alphaWash : Theme.alphaFaint)
            border.width: control.activeFocus ? 2 : 1
            border.color: control.activeFocus ? Theme.accent : Theme.border
            opacity: control.enabled ? 1 : Theme.alphaDisabled
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: Theme.spacingXxl * root.s
        RowLayout {
            Layout.fillWidth: true
            visible: root.showHeader
            SurfaceHeader {
                Layout.fillWidth: true
                title: qsTr("Enfoque")
                subtitle: root.session.paused ? qsTr("En pausa") : root.session.running ? qsTr("Un momento para concentrarte") : root.completed ? qsTr("Sesión completada") : qsTr("Elige tu tiempo")
                s: root.s
            }
            CtrlBtn { iconName: "close"; size: 30; s: root.s; accessibleName: qsTr("Cerrar enfoque"); onClicked: root.closeRequested() }
        }
        Text {
            Layout.fillWidth: true
            text: root.timeText
            color: Theme.foreground
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.fontMedia
            font.pixelSize: Theme.fontSizeCover * root.s
            font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
            Accessible.name: qsTr("Tiempo restante: %1").arg(root.timeText)
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 4 * root.s
            radius: height / 2
            color: Qt.alpha(Theme.foreground, Theme.alphaSubtle)
            Accessible.ignored: true
            Rectangle {
                width: parent.width * (root.session.active || root.completed ? root.session.progress : 0)
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd * root.s
            visible: !root.session.active
            Repeater {
                model: [15, 25, 45]
                FocusButton {
                    required property int modelData
                    text: qsTr("%1 min").arg(modelData)
                    selected: root.selectedMinutes === modelData
                    onClicked: { root.choosingNext = true; root.selectedMinutes = modelData; minutesInput.text = String(modelData) }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: !root.session.active
            spacing: Theme.spacingMd * root.s
            Text {
                text: qsTr("Minutos")
                color: Theme.iconSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeBodyLg * root.s
            }
            IslaTextField {
                id: minutesInput
                objectName: "focusMinutes"
                Layout.fillWidth: true
                Layout.preferredHeight: 38 * root.s
                text: "25"
                floating: false
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 1; top: 180 }
                Accessible.name: qsTr("Duración en minutos, entre 1 y 180")
                onTextEdited: { root.choosingNext = true; if (acceptableInput) root.selectedMinutes = Number(text) }
                onAccepted: if (acceptableInput && root.session.start(Number(text))) root.feedbackRequested("received")
            }
            Text {
                text: qsTr("1–180")
                color: Theme.iconSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall * root.s
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd * root.s
            FocusButton {
                id: primary
                objectName: "focusPrimary"
                selected: true
                enabled: root.session.active || minutesInput.acceptableInput
                text: root.session.running ? qsTr("Pausar") : root.session.paused ? qsTr("Continuar") : qsTr("Iniciar")
                onClicked: {
                    const kind = root.session.running ? "paused" : "received"
                    const accepted = root.session.running ? root.session.pause() : root.session.paused ? root.session.resume() : root.session.start(Number(minutesInput.text))
                    if (accepted) root.feedbackRequested(kind)
                }
            }
            FocusButton {
                objectName: "focusCancel"
                visible: root.session.active
                text: qsTr("Cancelar")
                onClicked: root.session.cancel()
            }
        }
        Text {
            Layout.fillWidth: true
            text: qsTr("Sesión temporal · se descarta al reiniciar Isla")
            color: Theme.iconSecondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeSmall * root.s
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}
