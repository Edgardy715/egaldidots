import QtQuick
import Quickshell.Widgets
import "../Singletons"

ClippingRectangle {
    id: root
    property string fontFamily: Theme.font
    property string name: ""
    property url source
    radius: width / 2
    color: Qt.alpha(Theme.accent, 0.10)
    border.color: Qt.alpha(Theme.foreground, 0.18)
    border.width: 1
    Accessible.name: name
    Text {
        anchors.centerIn: parent
        text: root.name.slice(0, 1).toLocaleUpperCase()
        font.family: root.fontFamily
        font.pixelSize: root.width * 0.42
        font.weight: Font.Light
        color: "#f8f8fa"
        visible: photo.status !== Image.Ready
    }
    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: width / 2
        color: "transparent"
        Image {
            id: photo
            anchors.fill: parent
            source: root.source
            sourceSize: Qt.size(256, 256)
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            opacity: status === Image.Ready ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                enabled: root.visible && !Flags.reduceMotion
                NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
            }
        }
    }
}
