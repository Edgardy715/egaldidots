import QtQuick
import "../Singletons"

/**
 * Isla · LiquidFill. Un estado activo como gota de acento: nace con la forma
 * del círculo de origen (el icono del control) y se derrama hasta cubrir el
 * contenedor; al apagarse vuelve a recogerse en la gota. Se ensancha antes de
 * crecer en alto, como un líquido que se extiende sobre la superficie.
 *
 * Sólo anima la geometría de un Rectangle: sin capas, máscaras ni shaders.
 * Con Superficies líquidas desactivado el relleno ocupa todo el contenedor y
 * se funde, como el vidrio clásico.
 *
 * Props:
 *   active       — estado (fuente de verdad externa)
 *   originX/Y    — esquina del círculo de origen, en coordenadas del padre
 *   originSize   — diámetro del círculo de origen
 *   cornerRadius — radio del contenedor lleno
 * Lectura:
 *   covered — el líquido ya cubre el contenido (cambio de tinta del texto)
 */
Rectangle {
    id: root

    property bool active: false
    property real originX: 0
    property real originY: 0
    property real originSize: 0
    property real cornerRadius: 0

    property real progress: active ? 1 : 0
    Behavior on progress {
        enabled: !Flags.reduceMotion
        NumberAnimation { duration: Motion.standardLarge; easing.type: Motion.easeStandard }
    }

    readonly property real fullW: parent ? parent.width : 0
    readonly property real fullH: parent ? parent.height : 0
    // El ancho adelanta al alto: la gota se extiende y después sube.
    readonly property real spread: Theme.liquid ? Math.min(1, progress * 1.3) : 1
    readonly property real rise: Theme.liquid ? Math.pow(progress, 1.5) : 1

    // El contenido cambia de tinta cuando el líquido ya lo cubre, no antes.
    readonly property bool covered: progress > 0.55

    x: originX * (1 - spread)
    y: originY * (1 - rise)
    width: originSize + (fullW - originSize) * spread
    height: originSize + (fullH - originSize) * rise
    radius: originSize / 2 + (cornerRadius - originSize / 2) * rise
    color: Theme.stateFill
    // Volumen: más claro arriba, como un líquido con luz cenital.
    gradient: Theme.liquid ? volume : null
    property Gradient volume: Gradient {
        GradientStop { position: 0; color: Theme.stateFillLight }
        GradientStop { position: 1; color: Theme.stateFill }
    }
    opacity: Theme.liquid ? Math.min(1, progress * 4) : progress
    visible: progress > 0.001

    // Menisco: brillo fino en la superficie del líquido.
    Rectangle {
        visible: Theme.liquid
        x: parent.radius * 0.6
        y: 1
        width: Math.max(0, parent.width - 2 * x)
        height: 1
        radius: 0.5
        color: Qt.alpha("#ffffff", 0.32)
        opacity: parent.rise
    }
}
