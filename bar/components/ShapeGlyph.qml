import QtQuick
import QtQuick.Shapes
import "../Singletons"

/**
 * Isla · ShapeGlyph. Dibuja una forma geométrica Material (replicando M3Shapes
 * de caelestia con QtQuick.Shapes nativo). Se usa en el campo de contraseña
 * para la animación del lockscreen: cada carácter entra como una forma aleatoria
 * (pentágono, triángulo, diamante…) y luego colapsa a un círculo.
 *
 * Uso:
 *   ShapeGlyph { shape: "triangle"; color: Theme.accent; size: 12 }
 *
 * Formas: circle, triangle, diamond, pentagon, hexagon, star, gem, arrow, cross
 */
Shape {
    id: root

    property string shape: "circle"
    property real size: 12
    property color color: Theme.accent

    width: root.size
    height: root.size
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true

    // puntos del polígono en coordenadas unitarias (0..1)
    // el círculo se aproxima con 24 puntos
    property var pts: {
        var s = root.shape
        if (s === "circle") {
            var c = []
            for (var i = 0; i < 24; i++) {
                var a = i / 24 * 2 * Math.PI
                c.push([0.5 + 0.5 * Math.cos(a), 0.5 + 0.5 * Math.sin(a)])
            }
            return c
        }
        if (s === "triangle") return [[0.5, 0.05], [0.95, 0.95], [0.05, 0.95]]
        if (s === "diamond") return [[0.5, 0.0], [1.0, 0.5], [0.5, 1.0], [0.0, 0.5]]
        if (s === "pentagon") return [[0.5, 0.02], [0.98, 0.37], [0.79, 0.93], [0.21, 0.93], [0.02, 0.37]]
        if (s === "hexagon") return [[0.25, 0.0], [0.75, 0.0], [1.0, 0.5], [0.75, 1.0], [0.25, 1.0], [0.0, 0.5]]
        if (s === "star") return [
            [0.5, 0.0], [0.59, 0.36], [0.95, 0.36], [0.66, 0.58],
            [0.78, 0.95], [0.5, 0.74], [0.22, 0.95], [0.34, 0.58],
            [0.05, 0.36], [0.41, 0.36]]
        if (s === "gem") return [
            [0.5, 0.0], [1.0, 0.0], [0.7, 0.55], [0.5, 1.0], [0.3, 0.55], [0.0, 0.0]]
        if (s === "arrow") return [
            [0.0, 0.25], [0.6, 0.25], [0.6, 0.0], [1.0, 0.5], [0.6, 1.0], [0.6, 0.75], [0.0, 0.75]]
        if (s === "cross") return [
            [0.35, 0.0], [0.65, 0.0], [0.65, 0.35], [1.0, 0.35], [1.0, 0.65],
            [0.65, 0.65], [0.65, 1.0], [0.35, 1.0], [0.35, 0.65],
            [0.0, 0.65], [0.0, 0.35], [0.35, 0.35]]
        return [[0.5, 0.0], [1.0, 0.5], [0.5, 1.0], [0.0, 0.5]]
    }

    // PathMultiline rellena el contorno desde los puntos (cierra el polígono)
    ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        PathMultiline {
            paths: [root.pts.map(p => Qt.point(p[0] * root.size, p[1] * root.size))]
        }
    }
}
