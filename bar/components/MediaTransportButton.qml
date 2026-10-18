pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QtQuick.Controls.Basic
import "../Singletons"

AbstractButton {
    id: root
    property string iconName: ""
    property string accessibleName: ""
    property real s: 1
    property real size: 44
    property real iconSize: 26
    property bool primary: false
    property color primaryColor: Theme.accent
    readonly property color effectivePrimaryColor: hovered ? Qt.lighter(primaryColor, 1.08) : primaryColor
    readonly property real primaryLuminance: {
        const channels = [effectivePrimaryColor.r, effectivePrimaryColor.g, effectivePrimaryColor.b].map(v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4))
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }
    readonly property color primaryInk: primaryLuminance > 0.179 ? "#000000" : "#ffffff"
    property bool active: false
    property bool playing: false
    property bool dim: false
    property bool motionEnabled: true
    readonly property bool moving: enabled && visible && motionEnabled && !Flags.reduceMotion && Flags.mediaTransitions
    property real morph: playing ? 1 : 0
    property real angle: 0
    property real symbolScale: 1
    property bool ready: false
    Component.onCompleted: ready = true
    onIconNameChanged: if (ready && moving) symbolPop.restart()
    NumberAnimation {
        id: symbolPop
        target: root; property: "symbolScale"; from: 0.8; to: 1
        duration: Motion.standard
        easing.type: Motion.easeStandard
    }
    implicitWidth: size * s
    implicitHeight: size * s
    enabled: !dim
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: accessibleName
    Accessible.role: Accessible.Button
    ToolTip.visible: hovered && accessibleName.length > 0
    ToolTip.text: accessibleName
    ToolTip.delay: 700
    onMovingChanged: if (!moving) { morphAnimation.complete(); symbolPop.complete() }
    Behavior on morph {
        enabled: root.moving
        NumberAnimation { id: morphAnimation; duration: Motion.emphasizedLarge; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedDecelCurve }
    }
    FrameAnimation {
        running: root.primary && root.playing && root.moving
        onTriggered: root.angle = (root.angle + Math.min(frameTime, 0.05) * 16) % 360
    }
    InteractionMotion {
        id: response
        hovered: root.hovered
        focused: root.activeFocus
        pressed: root.down
        enabled: root.enabled
        extent: root.size
    }
    background: Item {
        scale: response.visualScale
        opacity: root.enabled ? 1 : 0.32
        Rectangle {
            anchors.fill: parent
            radius: 16 * root.s
            visible: !root.primary
            color: root.active ? Theme.secondaryContainer : root.hovered || root.activeFocus
                ? Qt.alpha(Theme.foreground, 0.10) : "transparent"
            border.width: root.activeFocus ? Theme.borderHairline : 0
            border.color: Theme.accent
            Behavior on color { ColorAnimation { duration: Motion.hover } }
        }
        Shape {
            id: cookie
            anchors.fill: parent
            visible: root.primary
            rotation: root.angle
            preferredRendererType: Shape.CurveRenderer
            readonly property var outline: {
                const points = []
                for (let i = 0; i <= 120; ++i) {
                    const t = i * Math.PI * 2 / 120
                    const wave = (1 - root.morph) * 0.085 * Math.cos(5 * t) + root.morph * 0.055 * Math.cos(9 * t)
                    const r = 0.455 * (1 + wave)
                    points.push(Qt.point(width * (0.5 + r * Math.cos(t)), height * (0.5 + r * Math.sin(t))))
                }
                return points
            }
            ShapePath {
                fillColor: root.effectivePrimaryColor
                strokeColor: root.activeFocus ? Theme.foreground : "transparent"
                strokeWidth: root.activeFocus ? 1.5 * root.s : 0
                PathPolyline { path: cookie.outline }
            }
        }
    }
    contentItem: MediaSymbol {
        iconName: root.iconName
        color: root.primary ? root.primaryInk : root.active ? Theme.secondaryContainerContent : Theme.foreground
        font.pixelSize: root.iconSize * root.s
        opacity: root.enabled ? 1 : 0.32
        scale: response.visualScale * root.symbolScale
    }
    HoverHandler { cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
}
