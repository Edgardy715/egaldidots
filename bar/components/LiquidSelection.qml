import QtQuick
import "../Singletons"

/**
 * Isla · LiquidSelection. Indicador de selección que viaja como una gota: el
 * borde que va delante llega primero y el de atrás lo sigue, así que se estira
 * durante el trayecto y se recoge al llegar. Cada borde se anima por separado
 * desde su posición actual, de modo que un cambio a mitad de camino retargetea
 * sin saltos. Sin Superficies líquidas ambos bordes viajan juntos.
 *
 * Props:
 *   targetX/targetY/targetWidth/targetHeight — caja de destino, en coords del padre
 *   immediate — coloca sin animar (primer montaje, reaparición)
 *   volume    — con Superficies líquidas, degradado de luz cenital
 */
Rectangle {
    id: root

    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 0
    property real targetHeight: 0
    property bool immediate: false
    // Relleno de estado con volumen (más claro arriba); para marcas tenues, no.
    property bool volume: false
    gradient: volume && Theme.liquid ? volumeGradient : null
    property Gradient volumeGradient: Gradient {
        GradientStop { position: 0; color: Qt.lighter(root.color, 1.14) }
        GradientStop { position: 1; color: root.color }
    }

    readonly property int leadDuration: Flags.reduceMotion || immediate ? 0 : Theme.liquid ? Math.round(Motion.standardSmall * 0.9) : Motion.standard
    readonly property int trailDuration: Flags.reduceMotion || immediate ? 0 : Theme.liquid ? Math.round(Motion.standardLarge * 0.95) : Motion.standard

    property real edgeLeft: targetX
    property real edgeRight: targetX + targetWidth
    property real edgeTop: targetY
    property real edgeBottom: targetY + targetHeight
    // Qué borde lidera en cada eje; se decide antes de que cambien los destinos.
    property bool towardRight: true
    property bool towardDown: true

    function retarget() {
        towardRight = targetX + targetWidth / 2 >= (edgeLeft + edgeRight) / 2
        towardDown = targetY + targetHeight / 2 >= (edgeTop + edgeBottom) / 2
        edgeLeft = targetX; edgeRight = targetX + targetWidth
        edgeTop = targetY; edgeBottom = targetY + targetHeight
    }
    onTargetXChanged: retarget()
    onTargetYChanged: retarget()
    onTargetWidthChanged: retarget()
    onTargetHeightChanged: retarget()

    Behavior on edgeLeft { NumberAnimation { duration: root.towardRight ? root.trailDuration : root.leadDuration; easing.type: Motion.easeStandard } }
    Behavior on edgeRight { NumberAnimation { duration: root.towardRight ? root.leadDuration : root.trailDuration; easing.type: Motion.easeStandard } }
    Behavior on edgeTop { NumberAnimation { duration: root.towardDown ? root.trailDuration : root.leadDuration; easing.type: Motion.easeStandard } }
    Behavior on edgeBottom { NumberAnimation { duration: root.towardDown ? root.leadDuration : root.trailDuration; easing.type: Motion.easeStandard } }

    x: edgeLeft
    y: edgeTop
    width: Math.max(0, edgeRight - edgeLeft)
    height: Math.max(0, edgeBottom - edgeTop)
}
