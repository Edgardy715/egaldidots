pragma ComponentBehavior: Bound
import QtQuick
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
    // El botón principal es una gota sólida del color de la portada (saturado
    // para que el pastel de la paleta no se lave).
    readonly property color primaryTint: Qt.hsla(effectivePrimaryColor.hslHue < 0 ? 0 : effectivePrimaryColor.hslHue,
        Math.max(0.5, effectivePrimaryColor.hslSaturation), 0.6, 1)
    readonly property color primaryBody: primaryTint
    readonly property color primaryAlt: Qt.hsla(((effectivePrimaryColor.hslHue < 0 ? 0 : effectivePrimaryColor.hslHue) + 0.09) % 1,
        Math.max(0.55, effectivePrimaryColor.hslSaturation), 0.66, 1)
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
    // División de la gota: sólo al sonar y sin puntero encima (al apuntar se funde y enseña la pausa).
    // Asomar la pausa: al entrar el puntero con la música sonando la gota se funde
    // y enseña la pausa. Un clic lo anula, para que al darle a play se vea dividirse
    // aunque el puntero siga encima; hay que salir y volver a entrar para asomarla.
    property bool peek: false
    onHoveredChanged: peek = hovered && playing
    onPressedChanged: if (pressed) peek = false
    readonly property real splitTarget: primary && playing && !peek && !visualFocus ? 1 : 0
    property real split: splitTarget
    // Dividirse tarda más que fundirse: la gota se abre con calma y se recoge con decisión.
    Behavior on split {
        enabled: root.moving
        NumberAnimation {
            duration: root.splitTarget > 0.5 ? 760 : 560
            easing.type: root.splitTarget > 0.5 ? Easing.OutCubic : Easing.InOutCubic
        }
    }
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
        onTriggered: dt => root.angle = root.angle + dt * 120
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
            border.width: 0
            opacity: root.active ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.hover } }
        }
        // Gota de play: una esfera en pausa. Al sonar se divide en cuatro
        // columnas líquidas que laten como un ecualizador; al apuntar vuelve a
        // fundirse y deja ver la pausa. `split` dirige la división, `angle` el latido.
        ShaderEffect {
            id: drop
            objectName: "mediaMercuryDrop"
            anchors.fill: parent
            visible: root.primary && status !== ShaderEffect.Error
            readonly property real beat: root.angle * Math.PI / 180 * 3
            readonly property real amount: Math.max(0, Math.min(1, root.split))
            readonly property var bars: {
                const m = Math.min(width, height), count = 4
                const big = 0.44 * m, small = 0.068 * m, spacing = 0.2 * m
                const list = []
                for (let i = 0; i < count; ++i) {
                    // Las columnas salen en cascada desde el centro hacia fuera.
                    const k = Math.max(0, Math.min(1, root.split * 1.3 - 0.2 * (Math.abs(i - 1.5) - 0.5)))
                    // Primero adelgaza y se alarga (sigue siendo una gota), luego se abre en columnas.
                    const er = Math.min(1, k / 0.55), shrink = er * er * (3 - 2 * er)
                    const eo = Math.max(0, (k - 0.12) / 0.88), e = eo * eo * (3 - 2 * eo)
                    // Latido de cada columna: dos senos desfasados, como un nivel de audio.
                    const level = 0.65 * Math.abs(Math.sin(beat * (1 + 0.21 * i) + i * 1.7))
                        + 0.35 * (0.5 + 0.5 * Math.sin(beat * (1.9 - 0.27 * i) + i * 2.9))
                    const r = big + (small - big) * shrink
                    // Nunca se sale del botón: la media altura cabe con el radio actual.
                    const half = Math.min(0.46 * m - r, (0.1 * Math.sin(Math.PI * Math.min(1, k)) * (1 - e) + (0.03 + 0.15 * (root.moving ? level : 0.5)) * e) * m)
                    list.push(Qt.vector4d(width / 2 + (i - 1.5) * spacing * e, Math.max(0, half), r, 0))
                }
                return list
            }
            property size itemSize: Qt.size(width, height)
            property vector4d b0: bars[0]
            property vector4d b1: bars[1]
            property vector4d b2: bars[2]
            property vector4d b3: bars[3]
            // La unión es pegajosa a media división (cuellos) y casi nula al asentarse.
            property real goo: Math.min(width, height) * (0.02 + 0.16 * Math.sin(Math.PI * Math.min(1, amount)))
            property color colorA: root.primaryAlt
            property color colorB: root.displayedPrimary
            fragmentShader: Qt.resolvedUrl("shaders/playdrops.frag.qsb")
        }
        // Sin shader (GPU sin soporte): la esfera plana de siempre.
        Rectangle {
            anchors.fill: parent
            anchors.margins: parent.width * 0.04
            radius: width / 2
            visible: root.primary && drop.status === ShaderEffect.Error
            color: root.displayedPrimary
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: root.primary && root.visualFocus
            color: "transparent"
            border.width: 1.5 * root.s
            border.color: Theme.foreground
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
            // Dividida en columnas, la gota ya dice "sonando": el glifo se aparta.
            opacity: Math.max(0, 1 - 2.2 * root.split)
            scale: 1 - 0.3 * Math.min(1, root.split)
            color: root.primaryInk
            Behavior on color { ColorAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
        }
    }
    HoverHandler { cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
}
