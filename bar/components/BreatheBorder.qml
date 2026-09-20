import QtQuick
import "../Singletons"

/**
 * Isla · BreatheBorder. Anillo de glow que "respira" (reemplaza las ~12 copias
 * del patrón SequentialAnimation InOutSine + Pause en Media/Overview/NotifCard/
 * Wallpaper): un borde de acento que pulsa entre alphaMin y alphaMax.
 *
 * Props:
 *   color    — color del glow (default acento)
 *   width    — ancho del borde en px escalado
 *   alphaMin — alpha base (quiet)
 *   alphaMax — alpha pico
 *   period   — duración del ciclo completo (sube+baja) en ms
 *   pause    — pausa en estado "alto" antes de volver (ms)
 *   running  — gate (por defecto true; pausa con reduce-motion)
 */
Rectangle {
    id: root

    property color glowColor: Theme.accent
    property real width_: 2 * s
    property real alphaMin: 0.10
    property real alphaMax: 0.45
    property int period: 2000
    property int pause: Math.round(800 * Motion.mult)
    property bool running: true
    property real s: 1

    anchors.fill: parent
    radius: parent ? parent.radius : 0
    color: "transparent"
    border.width: root.width_
    border.color: Qt.alpha(root.glowColor, root.alphaMin)

    SequentialAnimation on border.color {
        id: anim
        running: root.running && Motion.mult >= 1
        loops: Animation.Infinite
        ColorAnimation {
            to: Qt.alpha(root.glowColor, root.alphaMax)
            duration: Math.round(root.period / 2)
            easing.type: Easing.InOutSine
        }
        ColorAnimation {
            to: Qt.alpha(root.glowColor, root.alphaMin)
            duration: Math.round(root.period / 2)
            easing.type: Easing.InOutSine
        }
        PauseAnimation { duration: root.pause }
    }
}
