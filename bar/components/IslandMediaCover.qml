import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import "../"
import "../Singletons"

/** Circular cover art and playback-progress ring for the compact media chip. */
Item {
    id: root

    property real s: 1
    property real diameter: 34
    property real ringWidth: 2
    property real ringGap: 2
    property real progress: 0
    property bool hasProgress: false
    property bool hovered: false
    property bool pressed: false
    property string artUrl: ""

    width: diameter
    height: diameter

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: height / 2
        color: "transparent"
        border.color: Qt.alpha(Theme.foreground, Theme.alphaSoft)
        border.width: root.ringWidth
        visible: root.hasProgress
    }
    Shape {
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        preferredRendererType: Shape.CurveRenderer
        visible: root.hasProgress
        ShapePath {
            strokeColor: Theme.accent
            strokeWidth: root.ringWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - root.ringWidth / 2
                radiusY: root.height / 2 - root.ringWidth / 2
                startAngle: -90
                sweepAngle: 360 * root.progress
                moveToStart: true
            }
        }
    }

    Item {
        id: cover
        anchors.centerIn: parent
        width: root.diameter - 2 * (root.ringWidth + root.ringGap)
        height: width
        scale: root.pressed ? 0.96 : root.hovered ? 1.025 : 1
        Behavior on scale { Anim { type: Anim.FastEffects } }

        Image {
            id: artwork
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true
            smooth: true
            source: root.artUrl
            sourceSize: Qt.size(cover.width * 2, cover.height * 2)
            visible: false
        }
        Rectangle {
            id: mask
            anchors.fill: parent
            radius: height / 2
            color: "#ffffff"
            visible: false
        }
        MaterialIcon {
            anchors.centerIn: parent
            iconName: "music_note"
            color: Theme.iconSecondary
            font.pixelSize: cover.width * 0.58
            visible: artwork.status !== Image.Ready
            Accessible.ignored: true
        }
        OpacityMask {
            anchors.fill: parent
            source: artwork
            maskSource: mask
            opacity: artwork.status === Image.Ready ? 1 : 0
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.color: Theme.border
            border.width: Theme.borderHairline
            antialiasing: true
        }
    }
}
