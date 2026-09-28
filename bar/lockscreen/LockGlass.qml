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
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop { position: 0; color: "#18ffffff" }
            GradientStop { position: 1; color: "#38000000" }
        }
    }
    GlassCard { anchors.fill: parent; radius_: root.radius; borderColor: "#28ffffff" }
}
