import QtQuick
import QtQuick.Layouts
import "../Singletons"
import "../components"

Rectangle {
    id: root
    property int scene: 0
    property int displayedScene: 0
    property real sceneExposure: 1
    onSceneChanged: {
        if (reduced || !visible) { sceneSwap.stop(); displayedScene = scene; sceneExposure = 1 }
        else sceneSwap.restart()
    }
    onReducedChanged: if (reduced) { sceneSwap.stop(); displayedScene = scene; sceneExposure = 1 }
    onVisibleChanged: if (!visible) { sceneSwap.stop(); displayedScene = scene; sceneExposure = 1 }
    SequentialAnimation {
        id: sceneSwap
        NumberAnimation { target: root; property: "sceneExposure"; to: 0; duration: 90; easing.type: Easing.OutCubic }
        ScriptAction { script: root.displayedScene = root.scene }
        NumberAnimation { target: root; property: "sceneExposure"; to: 1; duration: 150; easing.type: Easing.OutCubic }
    }
    color: Qt.alpha(Theme.foreground, 0.035)
    radius: 16
    implicitHeight: 270
    readonly property bool reduced: Config.appearance.reduceMotion
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 22; spacing: 14
        RowLayout {
            Text { text: qsTr("Prueba el movimiento"); color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.fillWidth: true }
            Text { visible: root.width > 560; text: qsTr("ESCENA DE PRUEBA"); color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontFamily; font.pixelSize: 10 }
        }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            Rectangle {
                x: 8; y: 20; width: 88; height: 30; radius: 15; color: Qt.alpha(Theme.foreground, 0.08)
                opacity: Config.modules.workspaceRail && root.width > 560 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.reduced ? 0 : 200 } }
                Row { anchors.centerIn: parent; spacing: 12
                    Repeater { model: 3; Text { required property int index; text: index + 1; color: index === 0 ? Theme.accent : Qt.alpha(Theme.foreground, 0.65); font.pixelSize: 11 } }
                }
            }
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 8; y: 20; width: 80; height: 30; radius: 15; color: Qt.alpha(Theme.foreground, 0.08)
                opacity: Config.modules.systemStatus && root.width > 560 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.reduced ? 0 : 200 } }
                Row { anchors.centerIn: parent; spacing: 12
                    EdotsIcon { visible: Config.modules.audio; iconName: "volume_up"; color: Theme.accent; font.pixelSize: 15 }
                    EdotsIcon { visible: Config.modules.network; iconName: "wifi"; color: Theme.accent; font.pixelSize: 15 }
                }
            }
            PillMorphMotion {
                id: morph
                anchors.horizontalCenter: parent.horizontalCenter; y: 10
                targetW: root.scene === 0 ? 150 : Math.min(parent.width - 20, 350)
                targetH: root.scene === 0 ? 44 : 120
                targetRadius: root.scene === 0 ? 22 : 28
                restW: 150; coreH: 44; surfaceOpen: root.scene !== 0
                reduceMotion: root.reduced || !root.visible
                morphDuration: 420 * Config.appearance.motionScale
                PillMaterial { morphRadius: morph.radius; materialAccent: Theme.accent; surface: root.scene ? "preview" : "" }
                Text {
                    anchors.centerIn: parent; text: "10:09"; color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: 17 * Config.appearance.fontScale
                    opacity: root.scene === 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: root.reduced ? 0 : 100 } }
                }
                Column {
                    anchors.centerIn: parent; spacing: 8
                    opacity: root.scene !== 0 ? morph.contentProgress * root.sceneExposure : 0
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.displayedScene === 1 ? qsTr("Un espacio para tu música") : qsTr("Todo está a tu alcance"); color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: 12 }
                    Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 20
                        EdotsIcon { animateChanges: false; iconName: root.displayedScene === 1 ? "skip_previous" : "calendar_month"; font.pixelSize: 22; color: Theme.accent }
                        EdotsIcon { animateChanges: false; iconName: root.displayedScene === 1 ? "play_arrow" : "notifications"; font.pixelSize: 22; color: Theme.accent }
                        EdotsIcon { animateChanges: false; iconName: root.displayedScene === 1 ? "skip_next" : "settings"; font.pixelSize: 22; color: Theme.accent }
                    }
                }
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Repeater {
                model: [qsTr("Reposo"), qsTr("Música"), qsTr("Panel")]
                EdotsButton { required property int index; required property string modelData; text: modelData; accent: root.scene === index; onClicked: root.scene = index }
            }
        }
    }
}
