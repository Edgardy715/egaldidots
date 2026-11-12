import QtQuick
import "../Singletons"

// Gota del kit: superficie plana y sólida, sin degradados ni brillos.
// El carácter viene del movimiento (se estira, se aplasta), no del material.
Rectangle {
    id: bead
    property color tint: Theme.accent
    // 0 neutro (blanco), 1 acento pleno.
    property real tintAmount: 0
    // Compatibilidad: ya no hay reflejo; se conserva la propiedad.
    property real glint: 1
    radius: Math.min(width, height) / 2
    // Los acentos de Matugen suelen ser pastel: se satura el tono para que se lea.
    readonly property color ink: Qt.hsla(tint.hslHue < 0 ? 0 : tint.hslHue, Math.max(0.55, tint.hslSaturation), Theme.dark ? 0.66 : 0.5, 1)
    // Segundo tono del relleno vivo: el acento desplazado en el círculo cromático.
    readonly property color inkAlt: Qt.hsla(((tint.hslHue < 0 ? 0 : tint.hslHue) + 0.09) % 1, Math.max(0.6, tint.hslSaturation), Theme.dark ? 0.7 : 0.55, 1)
    readonly property color body: Qt.tint(Theme.dark ? "#f5f5f7" : "#ffffff", Qt.alpha(ink, Math.max(0, Math.min(1, tintAmount))))
    color: body
    border.width: Theme.dark ? 0 : 1
    border.color: Qt.alpha("#000000", 0.10)
}
