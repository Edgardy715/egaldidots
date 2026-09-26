import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../"
import "../Singletons"
import "../components"

PillSurface {
    id: root
    mTop: 24; mLeft: 24; mRight: 24; mBottom: 24
    // Injection keeps interaction tests entirely separate from system commands.
    property var actions: Session
    property int focused: 0
    property int pending: -1
    readonly property var choices: [
        { icon: "lock", label: qsTr("Bloquear"), detail: qsTr("Tu sesión seguirá abierta."), action: "lock" },
        { icon: "logout", label: qsTr("Cerrar sesión"), detail: qsTr("Se cerrarán tus aplicaciones."), action: "logout" },
        { icon: "restart_alt", label: qsTr("Reiniciar"), detail: qsTr("El equipo volverá a iniciarse."), action: "reboot" },
        { icon: "power_settings_new", label: qsTr("Apagar"), detail: qsTr("El equipo se apagará."), action: "shutdown" }
    ]
    focus: root.open
    onOpenChanged: {
        pending = -1
        if (open) focusTimer.restart()
        else focusTimer.stop()
    }
    Timer {
        id: focusTimer
        interval: Flags.reduceMotion ? 0 : Motion.morph + 40
        onTriggered: if (root.open) root.forceActiveFocus()
    }
    function select(index) {
        focused = (index + 4) % 4
        pending = -1
    }
    function activate(index) {
        if (index < 0 || index >= choices.length) return
        focused = index
        if (index === 0) {
            pending = -1
            actions.lock()
            requestClose()
        } else pending = index
    }
    function confirm() {
        if (pending < 1) return
        const action = choices[pending].action
        pending = -1
        actions[action]()
        requestClose()
    }
    function cancel() { pending = -1; root.forceActiveFocus() }
    Keys.onPressed: event => handleKey(event)
    function handleKey(event) {
        event.accepted = false
        if (event.isAutoRepeat) { event.accepted = true; return }
        const k = event.key
        if (k === Qt.Key_Escape) {
            if (pending >= 0) cancel(); else requestClose()
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            if (pending >= 0) confirm(); else activate(focused)
        } else if (k >= Qt.Key_1 && k <= Qt.Key_4) activate(k - Qt.Key_1)
        else if ([Qt.Key_Left, Qt.Key_Up, Qt.Key_H, Qt.Key_K].indexOf(k) >= 0) select(focused - 1)
        else if ([Qt.Key_Right, Qt.Key_Down, Qt.Key_L, Qt.Key_J].indexOf(k) >= 0) select(focused + 1)
        else return
        event.accepted = true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 18 * root.s
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5 * root.s
                Text {
                    text: qsTr("Sesión y energía")
                    font.family: Theme.fontMedia
                    font.pixelSize: 21 * Flags.fontScale * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.4 * root.s
                    color: Theme.foreground
                }
                Text {
                    text: qsTr("Bloquea la pantalla o finaliza tu sesión.")
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeBody * root.s
                    color: Qt.alpha(Theme.foreground, 0.6)
                }
            }
            Item { Layout.fillWidth: true }
            CtrlBtn {
                iconName: "close"; size: 30; s: root.s
                accessibleName: qsTr("Cerrar panel")
                onClicked: root.requestClose()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10 * root.s
            Repeater {
                model: root.choices
                delegate: Button {
                    id: actionButton
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112 * root.s
                    hoverEnabled: true
                    Accessible.name: modelData.label
                    readonly property bool selected: root.pending === index || (root.pending < 0 && root.focused === index)
                    onClicked: root.activate(index)
                    onActiveFocusChanged: if (activeFocus && root.pending < 0) root.focused = index
                    background: Rectangle {
                        radius: 20 * root.s
                        color: Qt.alpha(Theme.foreground, actionButton.down ? 0.12 : actionButton.hovered || actionButton.selected ? 0.065 : 0)
                        border.width: root.s
                        border.color: Qt.alpha(Theme.foreground, actionButton.activeFocus ? 0.55 : actionButton.selected ? 0.16 : 0)
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                    }
                    contentItem: Column {
                        spacing: 10 * root.s
                        anchors.centerIn: parent
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 56 * root.s; height: width; radius: width / 2
                            color: Qt.alpha(Theme.foreground, actionButton.selected ? 0.14 : 0.07)
                            border.width: root.s
                            border.color: Qt.alpha(Theme.foreground, 0.10)
                            scale: actionButton.down ? 0.93 : actionButton.hovered ? 1.045 : 1
                            Behavior on scale { enabled: !Flags.reduceMotion; Anim { type: Anim.FastEffects } }
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: actionButton.modelData.icon
                                font.pixelSize: 28 * root.s
                                fill: 1
                                color: Theme.foreground
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: actionButton.modelData.label
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSizeBody * root.s
                            font.weight: Font.Medium
                            color: Qt.alpha(Theme.foreground, actionButton.selected ? 1 : 0.78)
                        }
                    }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: root.s; color: Qt.alpha(Theme.foreground, 0.09) }
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 48 * root.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("← →  Elegir     ↵  Continuar     Esc  Cerrar")
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall * root.s
                color: Qt.alpha(Theme.foreground, 0.5)
                opacity: root.pending < 0 ? 1 : 0
                Behavior on opacity { Anim { type: Anim.FastEffects } }
            }
            RowLayout {
                anchors.fill: parent
                spacing: 10 * root.s
                opacity: root.pending >= 0 ? 1 : 0
                enabled: root.pending >= 0
                visible: opacity > 0
                Behavior on opacity { Anim { type: Anim.FastEffects } }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4 * root.s
                    Text {
                        text: root.pending >= 0 ? (root.pending === 1 ? qsTr("¿Cerrar sesión?") : root.pending === 2 ? qsTr("¿Reiniciar el equipo?") : qsTr("¿Apagar el equipo?")) : ""
                        font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s
                        font.weight: Font.Medium; color: Theme.foreground
                    }
                    Text {
                        text: root.pending >= 0 ? root.choices[root.pending].detail : ""
                        font.family: Theme.font; font.pixelSize: Theme.fontSizeSmall * root.s
                        color: Qt.alpha(Theme.foreground, 0.6)
                    }
                }
                FooterButton { text: qsTr("Cancelar"); onClicked: root.cancel() }
                FooterButton {
                    text: root.pending >= 0 ? root.choices[root.pending].label : ""
                    prominent: true
                    onClicked: root.confirm()
                }
            }
        }
    }
    component FooterButton: Button {
        id: control
        property bool prominent: false
        implicitHeight: 36 * root.s
        implicitWidth: Math.max(76 * root.s, contentItem.implicitWidth + 22 * root.s)
        hoverEnabled: true
        background: Rectangle {
            radius: 11 * root.s
            color: control.prominent ? Qt.alpha(Theme.foreground, control.down ? 0.75 : 0.95)
                : Qt.alpha(Theme.foreground, control.hovered ? 0.14 : 0.08)
            border.width: control.activeFocus ? 2 * root.s : 0
            border.color: Theme.accent
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
        contentItem: Text {
            text: control.text
            font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            color: control.prominent ? Theme.background : Theme.foreground
        }
    }
}
