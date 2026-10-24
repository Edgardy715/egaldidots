import QtQuick
import "../Singletons"
import "../pets" as Pets

Rectangle {
    id: root
    objectName: "petPreview"
    property string palette: "marea"
    property string petName: "Mimo"
    property string petScale: "normal"
    property bool reducedMotion: false
    readonly property var pack: Pets.PetPack.data
    readonly property int px: petScale === "large" ? 3 : petScale === "small" ? 1 : 2
    property int poseIndex: 0
    property int frameIndex: 0
    readonly property var poses: ["idle", "walk", "dance", "sleep"]
    property string pose: "idle"
    readonly property var animation: pack ? pack.animations[pose] || pack.animations.idle : null
    readonly property bool ticking: visible && !reducedMotion && !!animation
    function advance() {
        if (!animation) return
        if (++frameIndex < animation.f.length) return
        frameIndex = 0
        if (pose === "happy") pose = poses[poseIndex]
        else { poseIndex = (poseIndex + 1) % poses.length; pose = poses[poseIndex] }
    }
    onReducedMotionChanged: if (reducedMotion) { poseIndex = 0; pose = "idle"; frameIndex = 0 }
    onVisibleChanged: if (!visible) { poseIndex = 0; pose = "idle"; frameIndex = 0 }
    onPaletteChanged: frameIndex = Math.min(frameIndex, animation ? animation.f.length - 1 : 0)
    radius: 18
    color: Qt.alpha(Theme.foreground, 0.045)
    border.color: Qt.alpha(Theme.foreground, 0.08)
    border.width: 1
    implicitHeight: 184

    Text {
        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 18
        text: qsTr("Vista previa")
        color: Theme.foreground
        font.family: Config.appearance.fontFamily
        font.pixelSize: 16
        font.weight: Font.DemiBold
    }
    Item {
        id: stage
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top; anchors.topMargin: 38
        width: Math.max(116, root.px * 20 + 44); height: 92
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 68; width: Math.max(100, root.px * 20 + 24); height: 2
            radius: 1; color: Qt.alpha(Theme.foreground, 0.3)
        }
        Pets.PetSprite {
            id: sprite
            objectName: "previewSprite"
            anchors.horizontalCenter: parent.horizontalCenter
            y: 68 - (root.pack ? root.pack.canvas.baseline : 18) * root.px
            source: Pets.PetPack.atlasFor(root.palette)
            palette: root.palette
            frame: root.animation ? root.animation.f[root.frameIndex] : 0
            frameCount: root.pack ? root.pack.frameCount : 1
            frameWidth: root.pack ? root.pack.canvas.width : 20
            frameHeight: root.pack ? root.pack.canvas.height : 20
            px: root.px
        }
        TapHandler {
            onTapped: {
                if (root.reducedMotion) return
                root.pose = "happy"
                root.frameIndex = 0
            }
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 16
        text: root.petName || qsTr("Mimo")
        color: Theme.foreground
        font.family: Config.appearance.fontFamily
        font.pixelSize: 14
        Accessible.role: Accessible.StaticText
    }
    Timer {
        id: previewClock
        objectName: "previewClock"
        interval: root.animation ? root.animation.ms[root.frameIndex] : 900
        repeat: true
        running: root.ticking
        onTriggered: root.advance()
    }
}
