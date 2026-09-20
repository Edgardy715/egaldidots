import QtQuick
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
    property bool enabled: true
    property real s: 1
    property real trackRadius: 0

    signal sliderChanged(real v)
    signal sliderLiveChanged(real v)

    height: (root.height_ + (root.knob ? 10 : 0)) * s
    width: parent ? parent.width : 200

    readonly property real trackH: root.height_ * s
    readonly property real trackY: (height - trackH) / 2
    readonly property real knobD: 16 * s

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
            width: parent.width * root.value
            radius: parent.radius
            color: Theme.accent
            Behavior on width { Anim { type: Anim.FastEffects } }
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
        x: root.value * (parent.width - root.knobD)
        y: (height - root.knobD) / 2
        Behavior on x { Anim { type: Anim.FastEffects } }
        scale: ma.containsMouse || ma.pressed ? 1.15 : 1.0
        Behavior on scale { Anim { type: Anim.FastEffects } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onPressed: (m) => { root.sliderChanged(root.clamp(m.x / width)); root.sliderLiveChanged(root.clamp(m.x / width)) }
        onPositionChanged: (m) => {
            if (pressed) { root.sliderChanged(root.clamp(m.x / width)); root.sliderLiveChanged(root.clamp(m.x / width)) }
        }
    }
}
