import QtQuick
import QtQuick.Shapes
import "../Singletons"

// Radio de Tidemark (wifi / bluetooth). Wi-Fi: las ondas se trazan en orden desde
// el punto al encender y se borran de fuera adentro al apagar, y una barra se
// dibuja encima. Bluetooth: la runa se atenúa y la misma barra la tacha.
// Presentación pura: `on` llega por propiedad; el muelle conserva posición y
// velocidad si se invierte a mitad, y oculto o con reduceMotion resuelve al final.
Item {
    id: root
    property string kind: "wifi"      // "wifi" | "bluetooth"
    property bool on: true
    property color color: Theme.accent
    property real size: 24
    readonly property bool exposed: visible && (!Window.window || Window.window.visible)
    readonly property bool wifi: kind === "wifi"
    readonly property real d: Math.max(0, Math.min(1.06, draw.value))
    readonly property real off: 1 - Math.max(0, Math.min(1, draw.value))
    implicitWidth: size
    implicitHeight: size

    SpringValue {
        id: draw
        target: root.on ? 1 : 0
        active: root.exposed
        spring: Motion.strokeSpring.radio
        Component.onCompleted: snap()
    }

    // Onda i (0 = la más cercana al punto): escalón por orden dentro del mismo muelle.
    // Cada onda llega a 1 justo cuando d = 1 (el rebote del muelle sí se ve) y se enciende tras la anterior.
    function waveExtent(i) { const k = i * Motion.strokeRadioStep; return Math.max(0, Math.min(1.06, (root.d - k) / (1 - k))) }
    // Cambiar de radio (wifi <-> bluetooth) en la misma instancia no es encender o apagar.
    onKindChanged: Qt.callLater(draw.snap)
    readonly property var radii: [4.5, 8.5, 12.5]
    readonly property real barExtent: Math.max(0, Math.min(1, root.off * Motion.strokeBarGain))

    Item {
        width: 24; height: 24
        anchors.centerIn: parent
        scale: Math.min(root.width, root.height) / 24
        Repeater {
            model: root.wifi ? [0, 1, 2] : []
            delegate: Shape {
                id: arcWave
                required property int modelData
                readonly property real e: root.waveExtent(modelData)
                width: 24; height: 24
                visible: e >= 0.04
                opacity: Math.min(1, e * 2.2)
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: root.color; strokeWidth: 2; fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 12; centerY: 19
                        radiusX: root.radii[arcWave.modelData]; radiusY: radiusX
                        startAngle: -90 - 45 * Math.min(1.06, arcWave.e); sweepAngle: 90 * Math.min(1.06, arcWave.e)
                        moveToStart: true
                    }
                }
            }
        }
        // Punto del wifi: siempre presente, es el origen de las ondas.
        Shape {
            width: 24; height: 24
            visible: root.wifi
            opacity: 1 - 0.45 * root.off
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color; strokeWidth: 2.6; fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 12; startY: 19
                PathLine { x: 12; y: 19.01 }
            }
        }
        // Runa de Bluetooth.
        Shape {
            width: 24; height: 24
            visible: !root.wifi
            opacity: 1 - 0.5 * root.off
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color; strokeWidth: 2; fillColor: "transparent"
                capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                PathPolyline { path: [Qt.point(7, 8), Qt.point(17, 16), Qt.point(12, 20), Qt.point(12, 4), Qt.point(17, 8), Qt.point(7, 16)] }
            }
        }
        // Barra de apagado: se dibuja de la esquina superior a la inferior.
        Shape {
            objectName: "radioBar"
            width: 24; height: 24
            visible: root.barExtent > 0.01
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color; strokeWidth: 2; fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                trim.end: root.barExtent
                startX: 4; startY: 4
                PathLine { x: 20; y: 20 }
            }
        }
    }
}
