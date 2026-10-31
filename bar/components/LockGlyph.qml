import QtQuick
import QtQuick.Shapes
import "../Singletons"

// Candado de Tidemark: el cuerpo es fijo; al abrir el arco sube, gira ya fuera y
// la cerradura se vacía; al cerrar baja y el cuerpo hace un "clac". Cuatro muelles
// encadenados (lift → swing → seat) y cada uno conserva su velocidad al invertirse.
// Presentación pura: `open` llega por propiedad.
Item {
    id: root
    property bool open: false
    property color color: Theme.foreground
    property real size: 24
    readonly property bool exposed: visible && (!Window.window || Window.window.visible)
    property bool seated: true
    implicitWidth: size
    implicitHeight: size

    SpringValue { id: lift; active: root.exposed; spring: Motion.strokeSpring.lift }
    SpringValue { id: swing; active: root.exposed; spring: Motion.strokeSpring.swing }
    SpringValue { id: seat; target: 0; active: root.exposed; spring: Motion.strokeSpring.seat }
    SpringValue { id: hole; active: root.exposed; spring: Motion.strokeSpring.hole }

    // El encadenado sólo reacciona a valores del muelle: sin timers.
    function chain() {
        if (open) {
            if (lift.value > 0.8 && swing.target !== 1) swing.target = 1
        } else {
            if (swing.value < 0.15 && lift.target !== 0) lift.target = 0
            if (lift.target === 0 && lift.value < 0.05 && lift.velocity <= 0 && !seated) {
                seated = true
                seat.kick(Motion.strokeKick.seat)
            }
        }
    }
    onOpenChanged: {
        seated = false
        if (open) { lift.target = 1; hole.target = 0 }
        else { swing.target = 0; hole.target = 1 }
        chain()
    }
    Connections { target: lift; function onValueChanged() { root.chain() } }
    Connections { target: swing; function onValueChanged() { root.chain() } }
    // Estado inicial sin animar: el candado nace ya abierto o cerrado.
    Component.onCompleted: {
        lift.target = open ? 1 : 0; swing.target = open ? 1 : 0; hole.target = open ? 0 : 1
        lift.snap(); swing.snap(); hole.snap(); seat.snap()
        seated = true
    }

    readonly property real l: lift.value
    readonly property real sx: 1 - 0.75 * Math.max(0, Math.min(1.08, swing.value))
    readonly property real h: Math.max(0, hole.value) * 2

    Item {
        width: 24; height: 24
        anchors.centerIn: parent
        scale: Math.min(root.width, root.height) / 24
        Shape {
            width: 24; height: 24
            preferredRendererType: Shape.CurveRenderer
            transform: Translate { y: -3.2 * root.l }
            ShapePath {
                strokeColor: root.color; strokeWidth: 2; fillColor: "transparent"
                capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M8 11V7a" + 4 * root.sx + " 4 0 0 1 " + 8 * root.sx + " 0v" + (4 - 0.9 * root.l) }
            }
        }
        Shape {
            width: 24; height: 24
            preferredRendererType: Shape.CurveRenderer
            transform: Translate { y: -Motion.strokeSeatShift * seat.value }
            ShapePath {
                strokeColor: root.color; strokeWidth: 2; fillColor: "transparent"
                capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M5 11h14v10H5Z" }
            }
            ShapePath {
                strokeColor: root.color; strokeWidth: 2; fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M12 " + (15.5 - root.h / 2) + "V" + (15.5 + root.h / 2 + 0.01) }
            }
        }
    }
}
