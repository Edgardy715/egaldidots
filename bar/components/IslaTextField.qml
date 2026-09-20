import QtQuick
import "../"
import "../Singletons"

/**
 * Isla · IslaTextField. Campo de texto con animaciones de escritura de
 * caelestia (components/controls/TextFieldBase.qml + StyledTextField.qml):
 *  - Cursor personalizado que parpadea y se desliza suavemente entre posiciones.
 *  - Al escribir, el cursor se "clava" (disableBlink) 500ms y vuelve a parpadear.
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

    // espacio extra arriba para que el placeholder flotante no choque con el texto
    topPadding: root.floating ? 8 : 0

    // ── fondo: outline Material 3 (opcional) ────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: root.chrome
        radius: 10
        color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
        border.width: root.activeFocus ? 1.5 : 1
        border.color: root.activeFocus ? Qt.alpha(Theme.accent, Theme.alphaIconSec) : Qt.alpha(Theme.border, Theme.alphaIconOnAcc)
        Behavior on border.color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        Behavior on border.width { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        z: -1
    }

    // ── placeholder flotante ────────────────────────────────────────────────
    // flota (pequeño, arriba) cuando hay foco o texto; grande y centrado si no.
    Text {
        visible: root.placeholderText.length > 0
        text: root.placeholderText
        color: root.placeholderColor
        font.family: root.font.family
        font.pixelSize: root.activeFocus || root.text
            ? root.font.pixelSize * 0.62
            : root.font.pixelSize
        // posición flotante: arriba-izquierda, con ligero pad
        x: root.activeFocus || root.text ? 8 : 12
        y: root.activeFocus || root.text ? 2 : (parent.height - implicitHeight) / 2
        opacity: (root.activeFocus || root.text) ? 0.85 : 0.65
        elide: Text.ElideRight
        width: parent.width - 24

        Behavior on x { Anim { type: Anim.FastSpatial; easing.bezierCurve: Motion.softFluid } }
        Behavior on y { Anim { type: Anim.FastSpatial; easing.bezierCurve: Motion.softFluid } }
        Behavior on font.pixelSize { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    // ── cursor personalizado animado (patrón caelestia TextFieldBase) ──────
    property bool disableBlink: false
    cursorDelegate: Rectangle {
        id: cursor
        visible: root.activeFocus
        width: 1.5
        height: root.font.pixelSize * 0.85
        radius: 0.75
        color: Theme.accent

        property real targetX: root.cursorRectangle.x
        // sigue al cursor real del TextInput, con deslizamiento suave
        x: targetX
        y: (root.height - height) / 2

        Behavior on x {
            NumberAnimation {
                duration: Motion.glide
                easing.bezierCurve: [0.2, 1, 0.21, 1, 1, 1]
            }
        }
        Behavior on opacity { Anim { type: Anim.StandardSmall } }

        // al mover el cursor (escribir/navegar): se clava visible 500ms
        Connections {
            target: root
            function onCursorPositionChanged(): void {
                if (root.activeFocus) {
                    cursor.opacity = 1
                    root.disableBlink = true
                    enableBlink.restart()
                }
            }
        }
        Timer {
            id: enableBlink
            interval: 500
            onTriggered: root.disableBlink = false
        }
        // parpadeo
        Timer {
            running: root.activeFocus && !root.disableBlink
            repeat: true
            triggeredOnStart: true
            interval: 500
            onTriggered: cursor.opacity = cursor.opacity === 1 ? 0 : 1
        }
    }

    // onTextChanged se propaga desde TextInput
}
