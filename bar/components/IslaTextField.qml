import QtQuick
import "../Singletons"

/**
 * Isla · IslaTextField. Campo de texto nativo con movimiento de foco:
 *  - Placeholder flotante: se encoge y sube al enfocar o al tener texto.
 *  - Outline que crece el borde al enfocar (Material 3).
 *
 * Uso:
 *   IslaTextField {
 *       width: 200; height: 40
 *       placeholderText: "Buscar…"
 *       onTextChanged: ...  // signal de TextInput
 *   }
 */
TextInput {
    id: root

    // placeholder flotante
    property string placeholderText: ""
    property color placeholderColor: Theme.iconSecondary
    property bool floating: true   // placeholder "flotante" estilo Material
    property bool chrome: true     // fondo outline propio (false si el padre ya tiene borde)

    color: Theme.foreground
    font.family: Theme.font
    font.pixelSize: 14
    clip: true
    verticalAlignment: TextInput.AlignVCenter
    selectByMouse: true
    selectionColor: Qt.alpha(Theme.accent, Theme.alphaSelected)
    selectedTextColor: Theme.foreground

    property bool motionActive: visible && enabled
    cursorDelegate: InputCaret { input: root; color: root.color; motionActive: root.motionActive }
    leftPadding: chrome ? 12 : 0
    rightPadding: chrome ? 12 : 0

    // espacio extra arriba para que el placeholder flotante no choque con el texto
    topPadding: root.floating ? 13 : 0

    // ── fondo: outline Material 3 (opcional) ────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: root.chrome
        radius: 10
        color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
        border.width: root.activeFocus ? 1.5 : 1
        border.color: root.activeFocus ? Qt.alpha(Theme.accent, Theme.alphaIconSec) : Qt.alpha(Theme.border, Theme.alphaIconOnAcc)
        Behavior on border.color { enabled: !Flags.reduceMotion; ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        Behavior on border.width { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        Behavior on color { enabled: !Flags.reduceMotion; ColorAnimation { duration: Motion.fast } }
        z: -1
    }

    InputPlaceholder {
        input: root
        floating: root.floating
        motionActive: root.motionActive
        color: root.placeholderColor
    }
}
