import QtQuick
import Quickshell.Widgets
import "../Singletons"

ClippingRectangle {
    id: root
    property string fontFamily: Theme.font
    property string name: ""
    property url source
    radius: width / 2
    color: Qt.alpha(Theme.accent, 0.24)
    border.color: "#60ffffff"
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
    Image {
        id: photo
        anchors.fill: parent
        anchors.margins: 3
        source: root.source
        sourceSize: Qt.size(256, 256)
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
    }
}
