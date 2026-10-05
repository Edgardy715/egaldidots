import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../Singletons"

Item {
    id: root
    property real s: 1
    property string ssid: ""
    property bool active: false
    property bool busy: false
    property bool succeeded: false
    property string errorText: ""
    property bool reveal: false
    property real fieldOffset: 0
    property alias input: password
    signal submitted(string secret)
    signal cancelled()
    signal edited()

    readonly property color successColor: "#a6efd0"
    readonly property color errorColor: "#ffb4bc"

    function focusInput() { if (active && !busy && !succeeded) password.forceActiveFocus() }
    function reset() {
        password.clear()
        reveal = false
        fieldOffset = 0
    }
    function submit() {
        if (!active || busy || succeeded || password.text.length < 8) return
        const secret = password.text
        password.clear()
        submitted(secret)
    }
    function reject() {
        password.clear()
        focusInput()
        recoil.stop()
        fieldOffset = 0
        if (!Flags.reduceMotion) recoil.start()
    }

    onActiveChanged: {
        if (active) Qt.callLater(focusInput)
        else { recoil.stop(); reset() }
    }
    onErrorTextChanged: if (errorText.length) reject()
    onSucceededChanged: if (succeeded) password.clear()
    Connections {
        target: Flags
        function onReduceMotionChanged() {
            if (Flags.reduceMotion) { recoil.stop(); root.fieldOffset = 0 }
        }
    }

    SequentialAnimation {
        id: recoil
        NumberAnimation { target: root; property: "fieldOffset"; to: -7 * root.s; duration: Motion.fast * 0.35 }
        NumberAnimation { target: root; property: "fieldOffset"; to: 5 * root.s; duration: Motion.fast * 0.55 }
        NumberAnimation { target: root; property: "fieldOffset"; to: -2 * root.s; duration: Motion.fast * 0.45 }
        NumberAnimation { target: root; property: "fieldOffset"; to: 0; duration: Motion.fast * 0.5 }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingMd * root.s

        RowLayout {
            Layout.fillWidth: true
            Item {
                Layout.preferredWidth: 32 * root.s
                Layout.preferredHeight: 32 * root.s
                MaterialIcon { anchors.centerIn: parent; iconName: "arrow_back"; color: Theme.foreground; font.pixelSize: 20 * root.s }
                MotionArea {
                    anchors.fill: parent
                    accessibleName: qsTr("Volver a las redes")
                    enabled: !root.busy
                    hoverWash: false
                    onClicked: root.cancelled()
                }
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("Conectar a una red")
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                font.weight: Font.DemiBold
            }
        }

        Item { Layout.fillHeight: true }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 72 * root.s
            Layout.preferredHeight: 72 * root.s
            scale: root.succeeded ? 1.10 : 1
            Behavior on scale { enabled: !Flags.reduceMotion; SmoothedAnimation { duration: Motion.standard; velocity: -1 } }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.succeeded ? root.successColor : Qt.alpha(Theme.accent, Theme.alphaGlow)
                border.width: Theme.borderHairline
                border.color: Qt.alpha(root.succeeded ? root.successColor : Theme.accent, Theme.alphaMid)
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }
            }
            MaterialIcon {
                id: statusIcon
                anchors.centerIn: parent
                iconName: root.succeeded ? "check" : root.busy ? "sync" : "wifi_lock"
                color: root.succeeded ? Theme.background : Theme.accent
                font.pixelSize: 34 * root.s
                RotationAnimator on rotation {
                    from: 0; to: 360; duration: 900; loops: Animation.Infinite
                    running: root.active && root.busy && !Flags.reduceMotion
                    onStopped: statusIcon.rotation = 0
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.ssid
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeTitle * root.s
            font.weight: Font.DemiBold
        }
        Text {
            Layout.fillWidth: true
            text: root.succeeded ? qsTr("Conectado") : root.busy ? qsTr("Estableciendo conexión…") : qsTr("Introduce la contraseña de la red")
            horizontalAlignment: Text.AlignHCenter
            color: root.succeeded ? root.successColor : Theme.iconSecondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeCaption * root.s
        }

        Item { Layout.fillHeight: true }

        Item {
            id: fieldWrap
            Layout.fillWidth: true
            Layout.preferredHeight: 68 * root.s
            opacity: root.succeeded ? 0 : 1
            enabled: !root.succeeded
            transform: Translate { x: root.fieldOffset }
            Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast } }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusLg * root.s
                color: Qt.alpha(Theme.foreground, password.activeFocus ? Theme.alphaSoft : Theme.alphaFaint)
                border.width: Theme.borderHairline
                border.color: root.errorText.length ? root.errorColor : password.activeFocus ? Qt.alpha(Theme.accent, Theme.alphaIconSec) : Theme.hair
                Behavior on color { enabled: root.active && !Flags.reduceMotion; ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { enabled: root.active && !Flags.reduceMotion; ColorAnimation { duration: Motion.fast } }
            }
            Text {
                x: 16 * root.s
                y: 9 * root.s
                text: qsTr("CONTRASEÑA WI-FI")
                color: root.errorText.length ? root.errorColor : Theme.iconSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 0.6 * root.s
            }
            TextField {
                id: password
                objectName: "wifiPassword"
                cursorDelegate: InputCaret { input: password; color: Theme.foreground; motionActive: root.active && !root.succeeded }
                anchors.left: parent.left
                anchors.leftMargin: 15 * root.s
                anchors.right: eye.left
                anchors.rightMargin: 6 * root.s
                anchors.top: parent.top
                anchors.topMargin: 28 * root.s
                height: 32 * root.s
                padding: 0
                background: null
                color: Theme.foreground
                placeholderText: qsTr("Escribe para conectar")
                placeholderTextColor: "transparent"
                InputPlaceholder { input: password; color: Theme.iconSecondary; motionActive: root.active && !root.succeeded }
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeBody * root.s
                echoMode: root.reveal ? TextInput.Normal : TextInput.Password
                passwordMaskDelay: 0
                enabled: root.active && !root.busy
                selectByMouse: true
                Accessible.name: qsTr("Contraseña para %1").arg(root.ssid)
                onAccepted: root.submit()
                onTextEdited: root.edited()
                Keys.onEscapePressed: root.cancelled()
            }
            Item {
                id: eye
                anchors.right: parent.right
                anchors.rightMargin: 5 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 40 * root.s; height: 40 * root.s
                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: root.reveal ? "visibility_off" : "visibility"
                    color: Theme.iconSecondary
                    font.pixelSize: 20 * root.s
                }
                MotionArea {
                    anchors.fill: parent
                    accessibleName: root.reveal ? qsTr("Ocultar contraseña") : qsTr("Mostrar contraseña")
                    enabled: !root.busy
                    hoverWash: false
                    onClicked: { root.reveal = !root.reveal; root.focusInput() }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: 34 * root.s
            text: root.errorText || (root.busy ? qsTr("Verificando credenciales…")
                : password.text.length > 0 && password.text.length < 8 ? qsTr("Faltan %1 caracteres").arg(8 - password.text.length)
                : password.text.length >= 8 ? qsTr("Pulsa Enter para conectar") : qsTr("Mínimo 8 caracteres"))
            color: root.errorText.length ? root.errorColor : Theme.iconSecondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeCaption * root.s
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            opacity: root.succeeded ? 0 : 1
            Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast } }
        }

        MotionButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 42 * root.s
            opacity: root.succeeded ? 0 : 1
            enabled: root.active && !root.busy && password.text.length >= 8
            Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast } }
            text: root.errorText.length ? qsTr("Reintentar") : qsTr("Conectar")
            onClicked: root.submit()
            background: Rectangle {
                radius: Theme.radiusLg * root.s
                color: parent.enabled ? Theme.accent : Qt.alpha(Theme.foreground, Theme.alphaSoft)
            }
            contentItem: Text {
                text: parent.text
                color: parent.enabled ? Theme.background : Theme.iconSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeBody * root.s
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
        Item { Layout.fillHeight: true }
    }
}
