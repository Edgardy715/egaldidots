import QtQuick
import "../Singletons"
import "../"

/**
 * Isla · StaggerItem. Envoltorio de entrada escalonada (stagger): el contenido
 * aparece con opacity 0→1 + scale 0.96→1 + slide 8px, con retraso proporcional
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
    property real scaleFrom: 0.96
    // al cambiar, re-dispara la animación de entrada (p.ej. al navegar de mes)
    property var restartKey: null
    onRestartKeyChanged: {
        if (entered) {
            root._revealed = false
            revealTimer.restart()
        }
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
    onEnteredChanged: if (!entered) root._revealed = false
    Timer {
        id: revealTimer
        interval: Motion.stagger(root.staggerIndex)
        running: root.entered
        repeat: false
        onTriggered: root._revealed = true
    }

    opacity: root._revealed ? 1 : 0
    visible: opacity > 0.01
    transformOrigin: Item.Center
    scale: root._revealed ? 1 : root.scaleFrom
    transform: Translate {
        id: entryT
        y: root._revealed ? 0 : 8 * root.s
        Behavior on y { Anim { type: Anim.EmphasizedIn } }
    }

    Behavior on opacity { Anim { type: Anim.EmphasizedIn } }
    Behavior on scale { Anim { type: Anim.EmphasizedIn } }

    // capa de contenido: rellena el item; los hijos van aquí (default property)
    default property alias content: contentItem.data
    Item {
        id: contentItem
        anchors.fill: parent
    }
}
