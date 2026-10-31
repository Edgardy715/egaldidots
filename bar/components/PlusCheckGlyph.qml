import QtQuick
import QtQuick.Shapes
import "../Singletons"

// Más↔check de Tidemark: la barra horizontal del más se dobla hasta ser el check
// y la vertical se recoge en su vértice. Presentación pura: `checked` llega por
// propiedad y el muelle conserva posición y velocidad si se invierte a mitad.
Item {
    id: root
    property bool checked: false
    property color color: Theme.foreground
    property real size: 24
    readonly property bool exposed: visible && (!Window.window || Window.window.visible)
    readonly property real t: morph.value
    implicitWidth: size
    implicitHeight: size

    SpringValue {
        id: morph
        target: root.checked ? 1 : 0
        active: root.exposed
        spring: Motion.strokeSpring.morph
        Component.onCompleted: snap()
    }

    function lerp(a, b) { return a + (b - a) * root.t }
    // Barra horizontal -> check (tres puntos); vertical -> recogida en el vértice.
    readonly property var bar: [Qt.point(lerp(4, 5), lerp(12, 12.5)), Qt.point(lerp(12, 10), lerp(12, 17.5)), Qt.point(lerp(20, 19), lerp(12, 7))]
    readonly property var stem: [Qt.point(lerp(12, 10), lerp(4, 17.5)), Qt.point(lerp(12, 10), lerp(20, 17.5))]

    Item {
        width: 24; height: 24
        anchors.centerIn: parent
        scale: Math.min(root.width, root.height) / 24
        Shape {
            width: 24; height: 24
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color; strokeWidth: 2; fillColor: "transparent"
                capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                PathPolyline { path: root.bar }
            }
            ShapePath {
                strokeColor: Qt.alpha(root.color, Math.max(0, Math.min(1, 1 - root.t * Motion.strokeCrossFade))); strokeWidth: 2; fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathPolyline { path: root.stem }
            }
        }
    }
}
