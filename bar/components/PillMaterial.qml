pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
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
    property string artUrl: ""
    property var artworkTransition: null
    property bool mediaPlaying: false
    property bool mediaSettled: false
    property string mode: "rest"
    property real notifBreathGlow: 0
    property string notifState: "idle"
    property bool suppressEdge: false
    property real edgeExposure: suppressEdge ? 0 : 1
    property real captureExtra: 0
    property real captureLeftExtra: 0

    function receive(position) { reception.trigger(position) }
    function settleReception() { reception.settle() }
    readonly property bool receiving: reception.running

    readonly property real bodyRadius: root.morphRadius + root.notifBreathRadius
    // A light compact tint grows gently for reading, keeping the backdrop visible.
    readonly property real readingExposure: Math.max(0, Math.min(1, (height / s - 38) / 58))
    readonly property real bodyAlpha: Flags.glassAlpha + (1 - Flags.glassAlpha) * (0.15 + 0.25 * readingExposure)

    anchors.fill: parent

    Rectangle {
        id: bodyShadow
        objectName: "pillMaterialShadow"
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: -root.captureLeftExtra
        width: parent.width + root.captureExtra + root.captureLeftExtra
        radius: root.bodyRadius
        color: Theme.cardBot
        // Compact shadows otherwise make compositor blur sample the app outside the glass.
        opacity: root.surface === "auth" ? 0 : 0.32 * root.readingExposure * root.edgeExposure
        // Compact pills, rails and idle droplets keep no shadow FBO or MultiEffect.
        layer.enabled: opacity > 0.001
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.72)
            shadowBlur: 0.95
            shadowVerticalOffset: 7 * root.s
        }
        z: 0
        Behavior on opacity { enabled: !root.suppressEdge; Anim { type: Anim.DefaultEffects } }
    }

    Rectangle {
        id: materialHalo
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: -7 * root.s - root.captureLeftExtra
        anchors.topMargin: -7 * root.s
        anchors.bottomMargin: -7 * root.s
        width: parent.width + root.captureExtra + root.captureLeftExtra + 14 * root.s
        radius: root.morphRadius + 7 * root.s
        color: "transparent"
        border.width: Math.max(1, Theme.borderHairline * root.s)
        border.color: Qt.alpha(root.materialAccent, 0.32)
        opacity: root.surface === "auth" ? 0
            : ((root.materialAwake && root.mode !== "hover" ? 0.16 : 0) + root.materialPulse * 0.34) * (1 - root.readingExposure) * root.edgeExposure
        scale: 1 + root.materialPulse * 0.028
        layer.enabled: opacity > 0.01
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha(root.materialAccent, 0.55)
            shadowBlur: 1.0
        }
        z: 1
        Behavior on opacity { enabled: !root.suppressEdge; Anim { type: Anim.DefaultEffects } }
        Behavior on scale { Anim { type: Anim.FastEffects } }
    }

    ClippingRectangle {
        id: mediaBgLayer
        anchors.fill: parent
        radius: root.bodyRadius
        color: "transparent"
        visible: root.surface === "media" && root.artUrl.length > 0
        z: 1

        MediaAmbient {
            anchors.fill: parent
            artUrl: root.artUrl
            artworkTransition: root.artworkTransition
            playing: root.mediaPlaying
            settled: root.mediaSettled
        }
    }

    ClippingRectangle {
        id: body
        anchors.left: parent.left
        anchors.leftMargin: -root.captureLeftExtra
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width + root.captureExtra + root.captureLeftExtra
        radius: root.bodyRadius
        border.width: root.surface === "auth" ? 1 : Theme.borderHairline
        border.color: Qt.alpha(Theme.foreground, root.edgeExposure
            * (root.surface === "auth" ? 0.18 : root.materialAwake ? Theme.alphaHairline : Theme.alphaHair))
        color: "transparent"
        contentUnderBorder: true
        z: 2

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Theme.cardTop, Math.min(1, root.bodyAlpha + 0.08 * root.readingExposure)) }
                GradientStop { position: 0.46; color: Qt.alpha(Theme.cardBot, root.bodyAlpha) }
                GradientStop { position: 1; color: Qt.alpha(Qt.darker(Theme.cardBot, 1 + 0.16 * root.readingExposure), Math.min(1, root.bodyAlpha + 0.04 * root.readingExposure)) }
            }
        }

        InnerGlow {
            anchors.fill: parent
            glowColor: root.materialAccent
            focusX: root.mode === "status" ? 0.76 : root.mode === "rest" || root.mode === "hover" ? 0.5 : 0.26
            opacity: root.mode === "lateral" || root.width >= 300 * root.s || root.height > 80 * root.s ? 0
                : root.materialAwake ? 0.48 : root.mode === "rest" ? 0.34 : root.mode === "status" ? 0.38 : 0
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        }

        ReceptionPulse {
            id: reception
            anchors.fill: parent
            accent: root.materialAccent
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
            opacity: (root.materialAwake ? 0.88 : 0.62) * (1 - root.readingExposure * 0.65)
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
            visible: root.edgeExposure > 0
            opacity: (1 - root.readingExposure) * root.edgeExposure
        }

        Rectangle {
            objectName: "pillMaterialDepthLight"
            anchors.top: parent.top
            anchors.topMargin: root.s
            x: parent.width * 0.06
            width: parent.width * 0.68
            height: Math.max(1, 1.5 * root.s)
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.32; color: Theme.foreground }
                GradientStop { position: 1; color: "transparent" }
            }
            opacity: Flags.materialDepth * root.edgeExposure
                * (1 - root.readingExposure * 0.5) * (1 - root.bodyAlpha * 0.2) * 0.32
        }

        Rectangle {
            objectName: "pillMaterialDepthShade"
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: parent.width * 0.75
            height: Math.min(parent.height * 0.18, 16 * root.s)
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.12) }
            }
            opacity: Flags.materialDepth * root.edgeExposure
                * (0.45 + root.readingExposure * 0.35) * (1 - root.bodyAlpha * 0.35)
        }

        Rectangle {
            anchors.fill: parent
            radius: body.radius
            color: root.materialAccent
            opacity: 0.035
        }
    }
}
