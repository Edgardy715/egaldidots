import QtQuick
import "../Singletons"
import QtQuick.Layouts
import "../components"
import "ModuleSelection.js" as ModuleSelection

Rectangle {
    id: root
    required property var config
    signal editFailed(string message)
    signal edited()
    color: Qt.alpha(Theme.foreground, 0.035)
    radius: 14
    implicitHeight: content.implicitHeight + 36
    function selectLayout(layout) {
        if (!config.loaded || config.saving) return false
        const result = config.update({appearance: {barLayout: layout}})
        if (!result.ok) editFailed(result.errors.join(" · "))
        else edited()
        return result.ok
    }
    function toggle(key) {
        if (!config.loaded || config.saving) return false
        const result = config.update(ModuleSelection.patch(key, !ModuleSelection.selected(config.modules, key)))
        if (!result.ok) editFailed(result.errors.join(" · "))
        else edited()
        return result.ok
    }
    ColumnLayout {
        id: content
        anchors.fill: parent; anchors.margins: 18; spacing: 14
        RowLayout {
            Text { text: qsTr("Composición de la barra"); color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeTitle; font.weight: Font.DemiBold; Layout.fillWidth: true }
            Text { text: qsTr("Pulsa para activar u ocultar"); color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Text { text: qsTr("Diseño"); color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.rightMargin: 8 }
            EdotsButton { objectName: "layout-split"; text: qsTr("Separada"); checkable: true; checked: root.config.appearance.barLayout === "split"; accent: checked; enabled: root.config.loaded && !root.config.saving; Accessible.name: qsTr("Barra separada"); onClicked: { root.selectLayout("split"); checked = Qt.binding(() => root.config.appearance.barLayout === "split") } }
            EdotsButton { objectName: "layout-compact"; text: qsTr("Compacta"); checkable: true; checked: root.config.appearance.barLayout === "compact"; accent: checked; enabled: root.config.loaded && !root.config.saving; Accessible.name: qsTr("Isla compacta"); onClicked: { root.selectLayout("compact"); checked = Qt.binding(() => root.config.appearance.barLayout === "compact") } }
            Item { Layout.fillWidth: true }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            ColumnLayout {
                Layout.fillWidth: true; Layout.preferredWidth: (root.width - 60) / 3; Layout.maximumWidth: Infinity; spacing: 9
                Text { text: qsTr("Izquierda"); color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody }
                ModuleButton { keyName: "workspaceRail"; text: qsTr("Espacios"); symbol: "dashboard" }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.preferredWidth: (root.width - 60) / 3; Layout.maximumWidth: Infinity; spacing: 9
                Text { text: qsTr("Centro"); color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.alignment: Qt.AlignHCenter }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 108; Layout.preferredHeight: 40; radius: 20; color: Qt.alpha(Theme.foreground, 0.08)
                    Row { anchors.centerIn: parent; spacing: 8
                        EdotsIcon { iconName: "lock"; font.pixelSize: 14; color: Theme.accent }
                        Text { text: "Isla"; color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: 13 }
                    }
                    Accessible.role: Accessible.StaticText; Accessible.name: qsTr("Isla principal, siempre visible")
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.preferredWidth: (root.width - 60) / 3; Layout.maximumWidth: Infinity; spacing: 9
                Text { Layout.alignment: Qt.AlignRight; text: qsTr("Derecha"); color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 6
                    ModuleButton { keyName: "systemStatus"; text: qsTr("Estado"); symbol: "tune" }
                    ModuleButton { keyName: "userAvatar"; text: qsTr("Avatar"); symbol: "person" }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Text { text: root.config.modules.systemStatus ? qsTr("En Estado") : qsTr("En Estado · oculto"); color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody; Layout.rightMargin: 8 }
            Repeater {
                model: [{key:"apps",label:qsTr("Apps"),icon:"apps"}, {key:"audio",label:qsTr("Audio"),icon:"volume_up"}, {key:"network",label:qsTr("Red"),icon:"wifi"}, {key:"battery",label:qsTr("Batería"),icon:"battery_full"}]
                ModuleButton {
                    required property var modelData
                    keyName: modelData.key; text: modelData.label; symbol: modelData.icon
                    Layout.fillWidth: true
                }
            }
        }
    }
    component ModuleButton: EdotsButton {
        required property string keyName
        objectName: "module-" + keyName
        checkable: true
        checked: ModuleSelection.selected(root.config.modules, keyName)
        accent: checked
        enabled: root.config.loaded && !root.config.saving
        Accessible.checkable: true
        Accessible.checked: checked
        onClicked: {
            root.toggle(keyName)
            checked = Qt.binding(() => ModuleSelection.selected(root.config.modules, keyName))
        }
    }
}
