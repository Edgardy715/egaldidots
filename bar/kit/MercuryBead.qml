import QtQuick
import "../Singletons"

// Quicksilver · gota de mercurio. Cuerpo cromado con brillo cenital; el
// estado la tiñe del acento (cinabrio) en lugar de rellenar una pista.
// Es el único material elevado del kit: lo que se toca es metal líquido.
Rectangle {
    id: bead
    property color tint: Theme.accent
    // 0 plata pura, 1 mercurio teñido de acento.
    property real tintAmount: 0
    // Intensidad del brillo especular (baja en reposo deshabilitado).
    property real glint: 1
    radius: Math.min(width, height) / 2
    // Los acentos de Matugen suelen ser pastel: se satura el tono para que el
    // cinabrio se lea sobre la plata.
    readonly property color ink: Qt.hsla(tint.hslHue < 0 ? 0 : tint.hslHue, Math.max(0.55, tint.hslSaturation), Theme.dark ? 0.62 : 0.5, 1)
    readonly property color body: Qt.tint(Theme.dark ? "#c3c5cc" : "#b9bcc4", Qt.alpha(ink, 0.82 * Math.max(0, Math.min(1, tintAmount))))
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.lighter(bead.body, 1.24) }
        GradientStop { position: 0.5; color: bead.body }
        GradientStop { position: 1; color: Qt.darker(bead.body, 1.55) }
    }
    border.width: 1
    border.color: Qt.alpha("#000000", Theme.dark ? 0.34 : 0.18)
    // Reflejo: una media luna clara arriba, más estrecha que la gota.
    Rectangle {
        x: bead.width * 0.2; y: Math.max(1, bead.height * 0.1)
        width: bead.width * 0.6; height: bead.height * 0.36
        radius: height / 2
        color: Qt.alpha("#ffffff", 0.62 * bead.glint)
    }
}
