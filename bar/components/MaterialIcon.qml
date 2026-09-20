import QtQuick
import "../Singletons"

/**
 * Isla · MaterialIcon. Icono Material Symbols Rounded (fuente variable de Google).
 * Usa LIGADURAS: el `iconName` es el nombre del glifo (ej. "wifi_off",
 * "bluetooth", "settings") y la fuente lo convierte al icono automáticamente —
 * exactamente como caelestia (MaterialIcon.qml). Ejes variables: ROND (redondez),
 * FILL (relleno), GRAD.
 *
 * Uso:
 *   MaterialIcon { iconName: "wifi_off"; color: Theme.foreground }
 *   MaterialIcon { iconName: "bluetooth"; color: Theme.accent; fill: 1 }
 *
 * Nota: el tamaño se fija vía `font.pixelSize` (puedes escalar con * s).
 */
Text {
    id: root

    // nombre del icono Material Symbols (se renderiza via ligadura)
    property string iconName: ""
    // 0..1 — relleno del glifo (outline → filled)
    property real fill: 0

    text: root.iconName
    color: Theme.foreground
    font.family: "Material Symbols Rounded"
    font.weight: Font.Normal
    font.letterSpacing: 0
    // axes variables (Qt 6.4+): ROND (0-100) + FILL (0-1) + GRAD. opsz NO se
    // fija aquí (loop con pixelSize); la fuente usa opsz auto del render.
    font.variableAxes: ({
        "ROND": 55,
        "FILL": root.fill,
        "GRAD": 0
    })
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
