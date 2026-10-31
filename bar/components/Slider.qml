import QtQuick
import QtQuick.Effects
import "../Singletons"
import "../"

/**
 * Isla · Slider. Slider horizontal unificado (reemplaza las 3 implementaciones:
 * Mixer barra, Utils slider+knob, Media seekBar+handle). Drag + click para
 * posicionar, fill de acento, knob blanco opcional.
 *
 * Props:
 *   value    — 0..1 (bind de lectura)
 *   height_  — alto del track en px
 *   knob     — mostrar knob circular (false = barra simple estilo mixer)
 *   enabled  — deshabilitado
 * signal sliderChanged(real v)     — al posicionar
 * signal sliderLiveChanged(real v) — durante el arrastre (para OSD/preview)
 */
Item {
    id: root

    property real value: 0
    property real height_: 12
    property bool knob: false
    property real s: 1
    property real trackRadius: 0
    // Ancho mínimo del relleno: con el alto del track, el valor 0 queda como una
    // gota redonda en el origen (que puede alojar un icono) en vez de desaparecer.
    property real minFill: 0

    signal sliderChanged(real v)
    signal sliderLiveChanged(real v)

    height: (root.height_ + (root.knob ? 10 : 0)) * s
    width: parent ? parent.width : 200

    // Direct manipulation: while dragging the fill and knob stay locked to the
    // pointer; clicks and external changes glide and retarget without restarting.
    property real dragValue: 0
    property bool dragging: false
    // After release the fill holds the dropped value until the (often async)
    // model catches up, so it never slides back to the stale value and forward again.
    property bool holding: false
    onValueChanged: if (holding && Math.abs(clamp(value) - dragValue) < 0.01) holding = false
    Timer { id: releaseHold; interval: 300; onTriggered: root.holding = false }
    readonly property bool engaged: root.enabled && (ma.containsMouse || ma.pressed)
    readonly property real targetValue: root.dragging || root.holding ? root.dragValue : root.clamp(root.value)
    property real shownValue: targetValue
    Behavior on shownValue {
        enabled: !Flags.reduceMotion && !root.dragging
        SmoothedAnimation { velocity: -1; duration: Motion.fast }
    }
    // Grip: the bare track thickens a touch under the pointer, like a held control.
    property real grip: root.engaged && !root.knob && !Flags.reduceMotion ? 2 : 0
    Behavior on grip { SmoothedAnimation { velocity: -1; duration: Motion.hover } }
    readonly property real trackH: (root.height_ + root.grip) * s
    readonly property real trackY: (height - trackH) / 2
    readonly property real knobD: 16 * s

    // Menisco: al arrastrar, el borde del relleno se adelanta un poco en la
    // dirección del gesto y vuelve a su sitio al frenar (Superficies líquidas).
    property real lead: 0
    Behavior on lead { SmoothedAnimation { velocity: -1; duration: Motion.standardSmall } }
    property real lastDrag: 0
    Timer { id: leadRelax; interval: 60; onTriggered: root.lead = 0 }
    onDragValueChanged: {
        if (dragging && Theme.liquid && !Flags.reduceMotion) {
            lead = Math.max(-6 * s, Math.min(6 * s, (dragValue - lastDrag) * width * 0.8))
            leadRelax.restart()
        }
        lastDrag = dragValue
    }

    function clamp(v) { return Math.max(0, Math.min(1, v)) }
    function valFromX(x) { return root.clamp((x - (root.knob ? knobD / 2 : 0)) / (width - (root.knob ? knobD : 0))) }

    // ---- track ----
    Rectangle {
        y: root.trackY
        height: root.trackH
        width: parent.width
        radius: root.trackRadius > 0 ? root.trackRadius * s : height / 2
        color: Qt.alpha(Theme.foreground, Theme.alphaSoft)
        border.width: Theme.borderHairline
        border.color: Qt.alpha(Theme.foreground, Theme.alphaFaint)

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(root.minFill, Math.min(parent.width, root.minFill + (parent.width - root.minFill) * root.shownValue + root.lead))
            radius: parent.radius
            color: Theme.liquid ? Theme.stateFill : Theme.accent
            gradient: Theme.liquid ? fillVolume : null
            property Gradient fillVolume: Gradient {
                GradientStop { position: 0; color: Theme.stateFillLight }
                GradientStop { position: 1; color: Theme.stateFill }
            }
            layer.enabled: root.visible && root.enabled && root.value > 0 && !Theme.liquid
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.alpha(Theme.accent, 0.7)
                shadowBlur: 0.7
                blurMax: 12
            }
        }
    }

    // ---- knob ----
    Rectangle {
        id: knobItem
        visible: root.knob
        width: root.knobD
        height: root.knobD
        radius: width / 2
        color: ma.containsMouse ? Qt.lighter("#ffffff", 1.02) : "#ffffff"
        x: root.shownValue * (parent.width - root.knobD)
        y: (root.height - root.knobD) / 2
        scale: Flags.reduceMotion ? 1 : ma.containsMouse || ma.pressed ? Motion.gripScale : 1
        Behavior on scale { SmoothedAnimation { duration: Motion.hover; velocity: -1 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: (m) => {
            root.dragValue = root.valFromX(m.x)
            root.sliderChanged(root.dragValue); root.sliderLiveChanged(root.dragValue)
        }
        onPositionChanged: (m) => {
            if (!pressed) return
            root.dragValue = root.valFromX(m.x)
            root.dragging = true
            root.sliderChanged(root.dragValue); root.sliderLiveChanged(root.dragValue)
        }
        onReleased: {
            if (root.dragging && Math.abs(root.clamp(root.value) - root.dragValue) >= 0.01) {
                root.holding = true
                releaseHold.restart()
            }
            root.dragging = false
        }
        onCanceled: root.dragging = false
    }
}
