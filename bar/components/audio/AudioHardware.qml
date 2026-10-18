pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../../Singletons"
import ".."
import "../../settings"

Item {
    id: root
    required property var card
    property real s: 1
    property Item popupBounds: null
    property bool advanced: false
    signal requested(string action, var args)
    signal menuOpened(var menu)
    implicitHeight: body.implicitHeight + 32 * s
    ColumnLayout {
        id: body
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 16 * root.s
        spacing: 12 * root.s
        RowLayout {
            Layout.fillWidth: true
            spacing: 12 * root.s
            MaterialIcon { Layout.preferredWidth: 24 * root.s; Layout.preferredHeight: 24 * root.s; iconName: "speaker"; font.pixelSize: 24 * root.s; color: Theme.iconSecondary }
            Text {
                Layout.fillWidth: true
                text: root.card.description
                font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg * root.s; font.weight: Font.DemiBold
                color: Theme.foreground; elide: Text.ElideRight
            }
            AudioButton {
                objectName: "latencyDetails-" + root.card.id
                s: root.s; symbol: "tune"; selected: root.advanced
                visible: (root.card.ports || []).length > 0
                ToolTip.text: qsTr("Compensación de latencia"); ToolTip.visible: hovered
                onClicked: root.advanced = !root.advanced
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.card.outputEnabled !== undefined || root.card.inputEnabled !== undefined
            spacing: 8 * root.s
            AudioButton {
                objectName: "enable-output-" + root.card.id
                Layout.fillWidth: true
                s: root.s; symbol: root.card.outputEnabled ? "volume_up" : "volume_off"
                text: root.card.outputEnabled ? qsTr("Salida activada") : qsTr("Salida desactivada")
                selected: !!root.card.outputEnabled
                enabled: !!root.card.canToggleOutput
                Accessible.role: Accessible.CheckBox
                Accessible.checkable: true
                Accessible.checked: !!root.card.outputEnabled
                Accessible.name: qsTr("Salida de %1").arg(root.card.description)
                onClicked: root.requested("setDeviceEnabled", {id:root.card.id, direction:"output", enabled:!root.card.outputEnabled})
            }
            AudioButton {
                objectName: "enable-input-" + root.card.id
                Layout.fillWidth: true
                s: root.s; symbol: root.card.inputEnabled ? "mic" : "mic_off"
                text: root.card.inputEnabled ? qsTr("Entrada activada") : qsTr("Entrada desactivada")
                selected: !!root.card.inputEnabled
                enabled: !!root.card.canToggleInput
                Accessible.role: Accessible.CheckBox
                Accessible.checkable: true
                Accessible.checked: !!root.card.inputEnabled
                Accessible.name: qsTr("Entrada de %1").arg(root.card.description)
                onClicked: root.requested("setDeviceEnabled", {id:root.card.id, direction:"input", enabled:!root.card.inputEnabled})
            }
        }
        AudioChoice {
            objectName: "profile-" + root.card.id
            Layout.fillWidth: true
            s: root.s; popupBounds: root.popupBounds
            label: qsTr("Perfil de %1").arg(root.card.description)
            options: root.card.profiles || []
            selectedValue: root.card.activeProfile || ""
            onMenuOpened: menu => root.menuOpened(menu)
            onChosen: value => root.requested("setProfile", {id:root.card.id, profile:value})
        }
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.advanced ? latency.implicitHeight : 0
            opacity: root.advanced ? 1 : 0
            clip: true; enabled: root.advanced
            Behavior on Layout.preferredHeight { enabled: root.visible && !Flags.reduceMotion; NumberAnimation { duration: Motion.standardSmall; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
            ColumnLayout {
                id: latency
                width: parent.width
                spacing: 10 * root.s
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Compensación de latencia · milisegundos")
                    wrapMode: Text.WordWrap
                    font.family: Theme.font; font.pixelSize: Theme.fontSizeSmall * root.s; color: Theme.iconSecondary
                }
                Repeater {
                    model: root.card.ports || []
                    delegate: RowLayout {
                        id: port
                        required property var modelData
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: port.modelData.description
                            elide: Text.ElideRight
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeSmall * root.s; color: Theme.foreground
                        }
                        AudioButton {
                            s: root.s; symbol: "remove"
                            Accessible.name: qsTr("Reducir latencia de %1").arg(port.modelData.description)
                            onClicked: root.requested("setLatencyOffset", {id:root.card.id, port:port.modelData.name, offset:Math.max(-2000000, port.modelData.latencyOffset - 1000)})
                        }
                        EdotsTextField {
                            id: latencyValue
                            objectName: "latency-" + root.card.id + "-" + port.modelData.name
                            property bool dirty: false
                            onTextEdited: dirty = true
                            Layout.preferredWidth: 100 * root.s
                            implicitHeight: 36 * root.s
                            horizontalAlignment: Text.AlignHCenter
                            font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeBody * root.s
                            validator: DoubleValidator { bottom: -2000; top: 5000; decimals: 3; notation: DoubleValidator.StandardNotation; locale: "C" }
                            invalid: !acceptableInput
                            Accessible.name: qsTr("Latencia de %1 en milisegundos").arg(port.modelData.description)
                            Binding { target: latencyValue; property: "text"; value: (port.modelData.latencyOffset / 1000).toFixed(3); when: !latencyValue.activeFocus }
                            onEditingFinished: {
                                if (dirty && acceptableInput) {
                                    root.requested("setLatencyOffset", {id:root.card.id, port:port.modelData.name, offset:Math.round(Number(text) * 1000)})
                                    dirty = false
                                }
                            }
                        }
                        AudioButton {
                            s: root.s; symbol: "add"
                            Accessible.name: qsTr("Aumentar latencia de %1").arg(port.modelData.description)
                            onClicked: root.requested("setLatencyOffset", {id:root.card.id, port:port.modelData.name, offset:Math.min(5000000, port.modelData.latencyOffset + 1000)})
                        }
                        AudioButton {
                            s: root.s; symbol: "restart_alt"
                            Accessible.name: qsTr("Restablecer latencia de %1").arg(port.modelData.description)
                            onClicked: root.requested("setLatencyOffset", {id:root.card.id, port:port.modelData.name, offset:0})
                        }
                    }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.hair }
    }
}
