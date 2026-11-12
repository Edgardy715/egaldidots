import QtQuick
import "../Singletons"

/**
 * Isla · RollingNumber. Cifra que rueda como un odómetro (ClockReel): sólo giran
 * los dígitos que cambian, las unidades primero; al subir el valor nuevo baja
 * desde arriba, al bajar sube desde abajo. Las ráfagas (tecla mantenida) encadenan
 * giros más cortos. El sufijo («%») queda quieto.
 *
 * `immediate` (manipulación directa: slider arrastrado) muestra la cifra al
 * instante; movimiento reducido u oculto también. Sin trabajo en reposo.
 */
Row {
    id: root
    property real value: 0
    property int decimals: 0
    property string suffix: ""
    property string widthSample: "100"
    property font font
    property color color: Theme.foreground
    property color suffixColor: color
    property font suffixFont: font
    property bool immediate: false
    property int alignment: Qt.AlignRight
    readonly property string text: (isFinite(value) ? value : 0).toFixed(decimals)
    readonly property alias rolling: reel.animating

    spacing: 0
    baselineOffset: reel.y + reel.baselineOffset
    Accessible.role: Accessible.StaticText
    Accessible.name: root.text + root.suffix

    ClockReel {
        id: reel
        text: root.text
        font: root.font
        color: root.color
        widthSample: root.widthSample
        alignment: root.alignment
        numericDirection: true
        motionEnabled: root.visible && !Flags.reduceMotion && !root.immediate
    }
    Text {
        visible: root.suffix.length > 0
        y: reel.baselineOffset - baselineOffset
        text: root.suffix
        color: root.suffixColor
        font: root.suffixFont
    }
}
