import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../components"

Item {
    id: root
    required property Item wallpaperItem
    property real sampleX: 0
    property real sampleY: 0
    property real radius: 30
    property real unit: 1
    ShaderEffectSource {
        id: sample
        width: root.width
        height: root.height
        sourceItem: root.wallpaperItem
        sourceRect: Qt.rect(root.sampleX, root.sampleY, root.width, root.height)
        textureSize: Qt.size(512, 512)
        visible: false
    }
    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        MultiEffect {
            anchors.fill: parent
            source: sample
            blurEnabled: true
            blurMax: 32
            blur: 1
            saturation: -0.15
        }
    }
    PillMaterial {
        s: root.unit
        morphRadius: root.radius
    }
}
