import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell.Widgets
import ".."
import "../Singletons"

/** Material continuo de la isla: sombra, halo, arte multimedia y vidrio. */
Item {
    id: root

    property real s: 1
    property real morphRadius: 19 * s
    property real notifBreathRadius: 0
    property bool materialAwake: false
    property color materialAccent: Theme.accent
    property real materialPulse: 0
    property real materialSweep: -0.55
    property string surface: ""
    property string mode: "rest"
    property real notifBreathGlow: 0
    property string notifState: "idle"

    readonly property real bodyRadius: root.morphRadius + root.notifBreathRadius

    anchors.fill: parent

    Rectangle {
        id: bodyShadow
        anchors.fill: parent
        anchors.margins: -2 * root.s
        radius: root.bodyRadius + 2 * root.s
        color: "transparent"
        border.width: Theme.borderHairlineSoft * root.s
        border.color: Qt.alpha(root.materialAccent,
                               root.materialAwake ? Theme.alphaMid : Theme.alphaHair)
        opacity: root.surface === "auth" ? 0 : root.materialAwake ? 0.9 : 0.58
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.72)
            shadowBlur: 0.95
            shadowVerticalOffset: 7 * root.s
        }
        z: 0
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
    }

    Rectangle {
        id: materialHalo
        anchors.fill: parent
        anchors.margins: -7 * root.s
        radius: root.morphRadius + 7 * root.s
        color: "transparent"
        border.width: Math.max(1, Theme.borderHairline * root.s)
        border.color: Qt.alpha(root.materialAccent, 0.32)
        opacity: root.surface === "auth" ? 0 : (root.materialAwake ? 0.16 : 0) + root.materialPulse * 0.34
        scale: 1 + root.materialPulse * 0.028
        layer.enabled: opacity > 0.01
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha(root.materialAccent, 0.55)
            shadowBlur: 1.0
        }
        z: 1
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        Behavior on scale { Anim { type: Anim.FastEffects } }
    }

    Rectangle {
        id: mediaBgLayer
        anchors.fill: parent
        radius: root.bodyRadius
        color: "transparent"
        visible: root.surface === "media" && Players.artUrl.length > 0
        z: 1
        clip: true

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: FastBlur { radius: 56 }
            Image {
                anchors.fill: parent
                anchors.margins: -80
                source: Players.artUrl
                fillMode: Image.PreserveAspectCrop
                opacity: 0.12
                smooth: true
                asynchronous: true
                sourceSize: Qt.size(root.width * 2, root.height * 2)
                Behavior on opacity {
                    SequentialAnimation {
                        NumberAnimation { to: 0; duration: 120 * Motion.mult; easing.type: Easing.OutCubic }
                        NumberAnimation { to: 0.12; duration: 120 * Motion.mult; easing.type: Easing.InCubic }
                    }
                }
            }
        }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Item {
                width: mediaBgLayer.width
                height: mediaBgLayer.height
                Rectangle {
                    width: mediaBgLayer.width
                    height: mediaBgLayer.height
                    radius: mediaBgLayer.radius
                    color: "white"
                }
            }
        }
    }

    ClippingRectangle {
        id: body
        anchors.fill: parent
        radius: root.bodyRadius
        border.width: root.surface === "auth" ? 1 : Theme.borderHairline
        border.color: Qt.alpha(Theme.foreground,
                                root.surface === "auth" ? 0.18 : root.materialAwake ? Theme.alphaHairline : Theme.alphaHair)
        color: "transparent"
        contentUnderBorder: true
        z: 2

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Theme.cardTop, Math.min(0.95, Flags.glassAlpha + 0.12)) }
                GradientStop { position: 0.46; color: Qt.alpha(Theme.cardBot, Flags.glassAlpha) }
                GradientStop { position: 1; color: Qt.alpha(Qt.darker(Theme.cardBot, 1.16), Math.min(0.95, Flags.glassAlpha + 0.08)) }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.max(30 * root.s, parent.height * 0.22)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(root.materialAccent, root.materialAwake ? 0.075 : 0.028) }
                GradientStop { position: 1; color: "transparent" }
            }
            opacity: root.materialAwake ? 0.88 : 0.62
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        }

        Rectangle {
            width: Math.max(48 * root.s, parent.width * 0.20)
            height: parent.height * 2.4
            x: parent.width * root.materialSweep - width / 2
            y: -parent.height * 0.70
            rotation: -17
            opacity: root.materialPulse > 0.01 ? 0.22 * Math.sin(root.materialPulse * Math.PI) : 0
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.48; color: Qt.alpha(Theme.foreground, 0.55) }
                GradientStop { position: 0.56; color: Qt.alpha(root.materialAccent, 0.22) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: mediaBgLayer.visible
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.35) }
                GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.10) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.35) }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: body.radius
            color: "transparent"
            border.width: Theme.borderEmphasis * root.s
            border.color: Qt.alpha(root.materialAccent, root.notifBreathGlow + 0.08)
            visible: root.notifBreathGlow > 0 || root.notifState === "hold"
        }

        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: root.s
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.82
            height: 1.5 * root.s
            radius: height / 2
            color: Theme.sheen
        }

        Rectangle {
            anchors.fill: parent
            radius: body.radius
            color: root.materialAccent
            opacity: 0.035
            SequentialAnimation on opacity {
                running: root.mode === "rest"
                loops: Animation.Infinite
                NumberAnimation { from: 0.025; to: 0.075; duration: Motion.breathe; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.075; to: 0.025; duration: Motion.breathe; easing.type: Easing.InOutSine }
                PauseAnimation { duration: Math.round(1100 * Motion.mult) }
            }
        }
    }
}
