import QtQuick
import QtQuick.Shapes

/**
 * Isla · NeckShape. El gesto orgánico sutil (elección del usuario): al dividirse
 * la isla (p.ej. media reproduciendo + estado en reposo) el cuerpo adopta un
 * perfil "peanut/dumbbell" con un cuello suave. Es GEOMETRÍA pura (QtQuick.Shapes
 * CurveRenderer), NO shader — lo que rechazaste fue el canvas metaball/gooey.
 *
 * AISLADO: el cuerpo de la pill por defecto es un Rectangle probado (Ricelin).
 * Este componente está listo y se monta cuando una surface está en modo "split"
 * (ver Pill.qml). Si no aterriza visualmente, se apaga sin tocar la arquitectura.
 *
 * Args: w/h (size), lobeR (radio de los lóbulos), neckT (0..1 grosor del cuello,
 *   1 = un único lobo, ~0.4 = cuello pinchado), fill (color del vidrio), border.
 *
 * Patron: dos arcos de circunferencia (lóbulos izq/der) + dos bézier tangentes
 * (cuellos superior/inferior) que pinchan al centro según neckT.
 */
Shape {
    id: shape
    preferredRendererType: Shape.CurveRenderer
    asynchronous: true

    property real lobeR: Math.min(width, height) / 2
    property real neckT: 1.0   // pinch del cuello (1 = lobo único, 0.4 = pinchado)
    property color fill: "transparent"
    property color borderColor: "transparent"
    property real borderWidth: 1

    readonly property real cx: width / 2
    readonly property real cy: height / 2
    // distancia de los centros de los lóbulos al centro
    readonly property real loxD: Math.max(0, width / 2 - shape.lobeR)
    /** grosor del cuello en Y: lobeR * neckT (cuando neckT<1 hay cuello). */
    readonly property real neckY: shape.lobeR * shape.neckT

    ShapePath {
        strokeColor: shape.borderColor
        strokeWidth: shape.borderWidth
        fillColor: shape.fill
        startX: shape.cx - shape.loxD - shape.lobeR; startY: shape.cy
        // lobo izquierdo (semicírculo)
        PathArc { x: shape.cx - shape.loxD + shape.lobeR; y: shape.cy; radiusX: shape.lobeR; radiusY: shape.lobeR; direction: PathArc.Clockwise }
        // cuello superior: bézier desde borde derecho-del-izq al borde izquierdo-del-der pinchando Y
        PathCubic {
            control1X: shape.cx - shape.loxD + shape.lobeR * 0.4; control1Y: shape.cy - shape.neckY
            control2X: shape.cx + shape.loxD - shape.lobeR * 0.4; control2Y: shape.cy - shape.neckY
            x: shape.cx + shape.loxD - shape.lobeR; y: shape.cy
        }
        // lobo derecho (semicírculo)
        PathArc { x: shape.cx + shape.loxD + shape.lobeR; y: shape.cy; radiusX: shape.lobeR; radiusY: shape.lobeR; direction: PathArc.Clockwise }
        // cuello inferior: bézier de vuelta
        PathCubic {
            control1X: shape.cx + shape.loxD - shape.lobeR * 0.4; control1Y: shape.cy + shape.neckY
            control2X: shape.cx - shape.loxD + shape.lobeR * 0.4; control2Y: shape.cy + shape.neckY
            x: shape.cx - shape.loxD - shape.lobeR; y: shape.cy
        }
    }
}
