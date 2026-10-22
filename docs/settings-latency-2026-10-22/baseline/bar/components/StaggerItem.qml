import QtQuick
import "../Singletons"

/**
 * Isla · StaggerItem. Envoltorio de entrada escalonada (stagger): el contenido
 * aparece con opacity 0→1 + scale 0.985→1 + slide 6px, con retraso proporcional
 * a `staggerIndex`. Para animar filas/items de una surface que entra con morph.
 *
 * Tiene una capa de contenido (`content`) que rellena el item: los hijos se
 * anclan a ella, así funciona tanto como celda de grilla (Calendar/Workspaces,
 * con width/height explícitos) como wrapper de altura variable en ColumnLayout
 * (Utils/Notifs/Mixer — el implicitHeight agrega la altura de los hijos).
 *
 * Props:
 *   staggerIndex — posición en la lista (0-based; NO se llama `index` para no
 *                  chocar con el `index` contextual del Repeater en el delegate)
 *   entered       — gate maestro (surfaces: se enciende cuando el morph asienta)
 *   s             — escala del host
 *   scaleFrom     — escala inicial
 */
Item {
    id: root

    property int staggerIndex: 0
    property bool entered: true
    property real s: 1
    property real scaleFrom: 0.985
    // al cambiar, re-dispara la animación de entrada (p.ej. al navegar de mes)
    property var restartKey: null
    onRestartKeyChanged: if (entered && !Flags.reduceMotion) {
        root._revealed = false
        revealTimer.restart()
    }

    // como Item plano, agrega el tamaño del contenido envuelto para que el
    // layout padre (Column/ColumnLayout) mida bien.
    implicitHeight: {
        var best = 0
        for (var i = 0; i < contentItem.children.length; i++) {
            var c = contentItem.children[i]
            if (c && (c.implicitHeight || 0) > best) best = c.implicitHeight
        }
        return best
    }
    implicitWidth: {
        var best = 0
        for (var i = 0; i < contentItem.children.length; i++) {
            var c = contentItem.children[i]
            if (c && (c.implicitWidth || 0) > best) best = c.implicitWidth
        }
        return best
    }

    property bool _revealed: false
    property real progress: _revealed ? 1 : 0
    function updateReveal() {
        revealTimer.stop()
        if (!entered) root._revealed = false
        else if (Flags.reduceMotion) root._revealed = true
        else revealTimer.start()
    }
    onEnteredChanged: updateReveal()
    Component.onCompleted: updateReveal()
    Connections {
        target: Flags
        function onReduceMotionChanged() {
            root.updateReveal()
            if (Flags.reduceMotion) entryAnimation.complete()
        }
    }
    Timer {
        id: revealTimer
        // A compact wave, even in the six-row calendar.
        interval: Math.min(Motion.stagger(root.staggerIndex), Motion.standardSmall)
        onTriggered: root._revealed = root.entered
    }

    opacity: root.progress
    visible: opacity > 0.01
    enabled: root.entered && root._revealed
    transformOrigin: Item.Top
    scale: Flags.reduceMotion ? 1 : root.scaleFrom + (1 - root.scaleFrom) * root.progress
    transform: Translate {
        y: Flags.reduceMotion ? 0 : 6 * root.s * (1 - root.progress)
    }
    Behavior on progress {
        enabled: !Flags.reduceMotion
        SmoothedAnimation {
            id: entryAnimation
            duration: root._revealed ? Motion.standard : Motion.fast
            velocity: -1
        }
    }

    // capa de contenido: rellena el item; los hijos van aquí (default property)
    default property alias content: contentItem.data
    Item {
        id: contentItem
        anchors.fill: parent
    }
}
