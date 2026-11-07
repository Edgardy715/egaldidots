pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QtQuick.Controls.Basic
import "../Singletons"
import "../kit"

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
    // Quicksilver: el botón principal es una gota de mercurio teñida con el
    // color de la portada (saturado para que el pastel no se pierda en la plata).
    readonly property color primaryTint: Qt.hsla(effectivePrimaryColor.hslHue < 0 ? 0 : effectivePrimaryColor.hslHue,
        Math.max(0.5, effectivePrimaryColor.hslSaturation), 0.6, 1)
    readonly property color primaryBody: Qt.tint("#c9cbd2", Qt.alpha(primaryTint, 0.78))
    readonly property real primaryLuminance: {
        const channels = [displayedPrimary.r, displayedPrimary.g, displayedPrimary.b].map(v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4))
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }
    property color displayedPrimary: primaryBody
    Behavior on displayedPrimary { ColorAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
    readonly property color primaryInk: primaryLuminance > 0.179 ? "#000000" : "#ffffff"
    property bool active: false
    property bool playing: false
    property bool dim: false
    property bool motionEnabled: true
    readonly property bool moving: enabled && visible && opacity > 0 && motionEnabled && !Flags.reduceMotion && Flags.mediaTransitions
    property real morph: playing ? 1 : 0
    property real angle: 0
    property real symbolScale: 1
    property bool ready: false
    Component.onCompleted: ready = true
    onIconNameChanged: if (ready && moving && !tidemarkGlyph) symbolPop.restart()
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
    // Superficie viva: mientras suena, la gota respira con dos ondas lentas
    // desfasadas (tensión superficial), no gira. En pausa es una esfera quieta.
    AmbientSubscription {
        running: root.primary && root.playing && root.moving
        onTriggered: dt => root.angle = (root.angle + dt * 40) % 360
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
            radius: height / 2
            visible: !root.primary
            color: root.hovered || root.activeFocus ? Qt.alpha(Theme.foreground, 0.08) : "transparent"
            border.width: root.activeFocus ? Theme.borderHairline : 0
            border.color: Theme.accent
            Behavior on color { ColorAnimation { duration: Motion.hover } }
        }
        // Estado activo (aleatorio, repetir): una gota de cinabrio bajo el glifo.
        MercuryBead {
            objectName: "transportActiveBead"
            visible: !root.primary
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 3 * root.s
            width: (root.active ? 12 : 4) * root.s; height: 4 * root.s
            Behavior on width { enabled: !Flags.reduceMotion; SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping } }
            tint: root.primaryColor
            tintAmount: 1
            glint: 0.6
            border.width: 0
            opacity: root.active ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.hover } }
        }
        Shape {
            id: drop
            objectName: "mediaMercuryDrop"
            anchors.fill: parent
            visible: root.primary
            preferredRendererType: Shape.CurveRenderer
            readonly property real phase: root.angle * Math.PI / 180
            readonly property var outline: {
                const points = []
                for (let i = 0; i <= 96; ++i) {
                    const t = i * Math.PI * 2 / 96
                    const wave = root.morph * (0.026 * Math.cos(2 * t + phase) + 0.018 * Math.cos(3 * t - 1.6 * phase))
                    const r = 0.46 * (1 + wave)
                    points.push(Qt.point(width * (0.5 + r * Math.cos(t)), height * (0.5 + r * Math.sin(t))))
                }
                return points
            }
            ShapePath {
                strokeColor: root.activeFocus ? Theme.foreground : Qt.alpha("#000000", 0.3)
                strokeWidth: (root.activeFocus ? 1.5 : 1) * root.s
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 0; y2: drop.height
                    GradientStop { position: 0; color: Qt.lighter(root.displayedPrimary, 1.2) }
                    GradientStop { position: 0.5; color: root.displayedPrimary }
                    GradientStop { position: 1; color: Qt.darker(root.displayedPrimary, 1.5) }
                }
                PathPolyline { path: drop.outline }
            }
        }
        // Reflejo cenital de la gota.
        Rectangle {
            visible: root.primary
            x: parent.width * 0.26; y: parent.height * 0.1
            width: parent.width * 0.48; height: parent.height * 0.26
            radius: height / 2
            color: Qt.alpha("#ffffff", root.hovered ? 0.6 : 0.5)
        }
    }
    // Play/pausa del botón primario: la gota de Tidemark en lugar del glifo de fuente.
    readonly property bool tidemarkGlyph: primary && (iconName === "play_arrow" || iconName === "pause")
    contentItem: Item {
        opacity: root.enabled ? 1 : 0.32
        scale: response.visualScale * root.symbolScale
        MediaSymbol {
            anchors.fill: parent
            visible: !root.tidemarkGlyph
            iconName: root.iconName
            color: root.primary ? root.primaryInk : Theme.foreground
            Behavior on color { ColorAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
            font.pixelSize: root.iconSize * root.s
        }
        PlayPauseGlyph {
            objectName: "mediaPlayPauseGlyph"
            anchors.centerIn: parent
            visible: root.tidemarkGlyph
            playing: root.playing
            animate: root.moving
            size: root.iconSize * root.s
            color: root.primaryInk
            Behavior on color { ColorAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
        }
    }
    HoverHandler { cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
}
