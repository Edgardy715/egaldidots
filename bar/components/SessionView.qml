pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../"
import "../Singletons"
import "../components"

Item {
    id: root
    property real s: 1
    property bool open: false
    property string userName: I18n.tr("Usuario")
    property string avatarSource: ""
    signal actionRequested(string action)
    signal closeRequested()
    property int focused: 4
    property int pending: -1
    // Keep the outgoing confirmation copy while its row fades away.
    property int displayedPending: -1
    onPendingChanged: if (pending >= 0) displayedPending = pending
    readonly property var choices: [
        { icon: "lock", label: I18n.tr("Bloquear"), detail: I18n.tr("Tu sesión seguirá abierta."), action: "lock" },
        { icon: "logout", label: I18n.tr("Cerrar sesión"), detail: I18n.tr("Se cerrarán tus aplicaciones."), action: "logout" },
        { icon: "restart_alt", label: I18n.tr("Reiniciar"), detail: I18n.tr("El equipo volverá a iniciarse."), action: "reboot" },
        { icon: "power_settings_new", label: I18n.tr("Apagar"), detail: I18n.tr("El equipo se apagará."), action: "shutdown" },
        { icon: "dark_mode", label: I18n.tr("Suspender"), detail: I18n.tr("Tu sesión seguirá abierta."), action: "suspend" }
    ]
    readonly property var primaryOrder: [4, 2, 3, 1]
    readonly property var navigationOrder: [4, 2, 3, 1, 0]
    property date now: Regional.now()
    readonly property string greeting: now.getHours() < 12 ? I18n.tr("Buenos días") : now.getHours() < 19 ? I18n.tr("Buenas tardes") : I18n.tr("Buenas noches")
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
        focused = (index + choices.length) % choices.length
        pending = -1
    }
    function activate(index) {
        if (index < 0 || index >= choices.length) return
        focused = index
        if (index === 0 || index === 4) {
            pending = -1
            actionRequested(choices[index].action)
            closeRequested()
        } else pending = index
    }
    function confirm() {
        if (pending < 1) return
        const action = choices[pending].action
        pending = -1
        actionRequested(action)
        closeRequested()
    }
    function cancel() { pending = -1; root.forceActiveFocus() }
    Keys.onPressed: event => handleKey(event)
    function handleKey(event) {
        event.accepted = false
        if (event.isAutoRepeat) { event.accepted = true; return }
        const k = event.key
        if (k === Qt.Key_Escape) {
            if (pending >= 0) cancel(); else closeRequested()
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            if (pending >= 0) confirm(); else activate(focused)
        } else if (k >= Qt.Key_1 && k <= Qt.Key_5) activate(k - Qt.Key_1)
        else if ([Qt.Key_Left, Qt.Key_Up, Qt.Key_H, Qt.Key_K].indexOf(k) >= 0) select(navigationOrder[(navigationOrder.indexOf(focused) + navigationOrder.length - 1) % navigationOrder.length])
        else if ([Qt.Key_Right, Qt.Key_Down, Qt.Key_L, Qt.Key_J].indexOf(k) >= 0) select(navigationOrder[(navigationOrder.indexOf(focused) + 1) % navigationOrder.length])
        else return
        event.accepted = true
    }

    Timer { interval: 60000; repeat: true; running: root.open; onTriggered: root.now = Regional.now() }
    ColumnLayout {
        anchors.fill: parent
        spacing: 16 * root.s
        RowLayout {
            Layout.fillWidth: true
            SurfaceHeader {
                Layout.fillWidth: true
                title: I18n.tr("Sesión y energía")
                s: root.s
            }
            CtrlBtn { iconName: "close"; size: 30; s: root.s; accessibleName: I18n.tr("Cerrar panel"); onClicked: root.closeRequested() }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8 * root.s
            UserAvatar {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 82 * root.s; Layout.preferredHeight: 82 * root.s
                name: root.userName; source: root.avatarSource; fontFamily: Theme.fontMedia
            }
            Text {
                Layout.fillWidth: true
                text: root.userName; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                font.family: Theme.fontMedia; font.pixelSize: 20 * Flags.fontScale * root.s
                font.weight: Font.DemiBold; color: Theme.foreground
            }
            Text {
                Layout.fillWidth: true
                text: root.greeting; horizontalAlignment: Text.AlignHCenter
                font.family: Theme.fontMedia; font.pixelSize: 13 * Flags.fontScale * root.s
                color: Qt.alpha(Theme.foreground, 0.65)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12 * root.s
            Repeater {
                model: root.primaryOrder
                delegate: MotionButton {
                    id: tile
                    objectName: "sessionAction" + modelData
                    expressive: true
                    required property int modelData
                    readonly property var choice: root.choices[modelData]
                    readonly property color tint: modelData === 4 ? "#98baff" : modelData === 3 ? "#ff8395" : modelData === 1 ? "#ffbd80" : Theme.foreground
                    readonly property bool selected: root.focused === modelData || root.pending === modelData
                    highlighted: selected
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: 108 * root.s
                    Accessible.name: choice.label
                    onClicked: root.activate(modelData)
                    onActiveFocusChanged: if (activeFocus && root.pending < 0) root.focused = modelData
                    background: Rectangle {
                        radius: 22 * root.s
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.alpha(tile.tint, 0.11 + 0.07 * tile.interaction.presence + 0.05 * tile.interaction.pressure) }
                            GradientStop { position: 1; color: Qt.alpha(tile.tint, 0.025) }
                        }
                        border.color: Qt.alpha(tile.tint, tile.activeFocus ? 0.7 : tile.selected ? 0.35 : 0.15)
                        border.width: root.s
                        Behavior on border.color { ColorAnimation { duration: Motion.hover } }
                    }
                    contentItem: Item {
                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 14 * root.s
                            interaction: tile.interaction
                            objectName: "sessionIcon" + tile.modelData
                            iconName: tile.choice.icon
                            font.pixelSize: 34 * root.s; color: tile.tint
                            fill: tile.modelData === 4 ? 1 : 0
                        }
                        Text {
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 12 * root.s
                            transform: Translate { y: -Motion.labelTravel * tile.interaction.presence }
                            text: tile.choice.label
                            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                            font.family: Theme.fontMedia; font.pixelSize: 11 * Flags.fontScale * root.s
                            font.weight: Font.Medium; color: Theme.foreground
                        }
                    }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: root.s; color: Qt.alpha(Theme.foreground, 0.10) }
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 52 * root.s
            RowLayout {
                anchors.fill: parent
                enabled: root.pending < 0
                opacity: root.pending < 0 ? 1 : 0
                visible: opacity > 0.01
                transform: Translate {
                    y: Flags.reduceMotion || root.pending < 0 ? 0 : -3 * root.s
                    Behavior on y { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                }
                Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                FooterButton { text: I18n.tr("Bloquear"); onClicked: root.activate(0) }
                Item { Layout.fillWidth: true }
            }
            RowLayout {
                anchors.fill: parent
                enabled: root.pending >= 0
                opacity: root.pending >= 0 ? 1 : 0
                visible: opacity > 0.01
                transform: Translate {
                    y: Flags.reduceMotion || root.pending >= 0 ? 0 : 3 * root.s
                    Behavior on y { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                }
                Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                spacing: 12 * root.s
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4 * root.s
                    AnimatedLabel {
                        Layout.fillWidth: true
                        value: root.displayedPending >= 0 ? I18n.tr("¿%1?").arg(root.choices[root.displayedPending].label) : ""
                        font.family: Theme.fontMedia; font.pixelSize: 13 * Flags.fontScale * root.s
                        font.weight: Font.Medium; color: Theme.foreground
                    }
                    AnimatedLabel {
                        Layout.fillWidth: true
                        value: root.displayedPending >= 0 ? root.choices[root.displayedPending].detail : ""
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontMedia; font.pixelSize: 11 * Flags.fontScale * root.s
                        color: Theme.iconSecondary
                    }
                }
                FooterButton { text: I18n.tr("Cancelar"); onClicked: root.cancel() }
                FooterButton { text: I18n.tr("Confirmar"); prominent: true; onClicked: root.confirm() }
            }
        }
    }
    component FooterButton: MotionButton {
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
            transform: Translate { y: -Motion.labelTravel * control.interaction.presence }
            text: control.text
            font.family: Theme.fontMedia; font.pixelSize: Theme.fontSizeBody * root.s
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            color: control.prominent ? Theme.primaryContent : Theme.foreground
        }
    }
}
