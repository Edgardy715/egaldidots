import QtQuick
import QtQuick.Shapes
import "../Singletons"

// Play↔pause de Tidemark: el triángulo se parte como una gota. Dos mitades
// viajan a las barras de pausa y entre ellas queda un cuello que se estira y se
// pinza cuando el hueco llega a 3 px. Presentación pura: `playing` llega por
// propiedad (true = suena, se ve la pausa) y el muelle `split` conserva posición y velocidad al invertirse.
Item {
    id: root
    property bool playing: false
    property color color: Theme.foreground
    property real size: 24
    // Falso = resuelve al estado final (el botón respeta el ajuste de transiciones de media).
    property bool animate: true
    readonly property bool exposed: visible && (!Window.window || Window.window.visible)
    readonly property real t: split.value
    implicitWidth: size
    implicitHeight: size

    readonly property var play: [[[6, 3], [13, 7.5], [13, 16.5], [6, 21]], [[13, 7.5], [20, 12], [20, 12], [13, 16.5]]]
    readonly property var pause: [[[6, 4], [10, 4], [10, 20], [6, 20]], [[14, 4], [18, 4], [18, 20], [14, 20]]]

    SpringValue {
        id: split
        target: root.playing ? 1 : 0
        active: root.exposed && root.animate
        spring: Motion.strokeSpring.split
        Component.onCompleted: snap()
    }

    function quad(i) {
        const t = root.t, out = []
        for (let j = 0; j < 4; ++j) {
            const a = root.play[i][j], b = root.pause[i][j]
            // Al rebotar más allá del play las y de la punta se cruzarían y dejarían
            // un grumo en el vértice: la punta sólo rebota en x.
            const u = i === 1 && (j === 1 || j === 2) ? Math.max(0, t) : t
            out.push([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * u])
        }
        return out
    }
    function pt(p) { return p[0] + " " + p[1] }
    function mix(p, q, u) { return [p[0] + (q[0] - p[0]) * u, p[1] + (q[1] - p[1]) * u] }
    // Cada mitad sin su borde interior: juntas dibujan el triángulo sin costura.
    function halfA(A) { return "M" + pt(A[1]) + "L" + pt(A[0]) + "L" + pt(A[3]) + "L" + pt(A[2]) }
    function halfB(B) { return "M" + pt(B[0]) + "L" + pt(B[1]) + "L" + pt(B[2]) + "L" + pt(B[3]) }
    // Cuello: los bordes interiores crecen desde las puntas; entre ellos dos
    // curvas se acercan al centro hasta pinzarse.
    function neck(A, B) {
        const gap = B[0][0] - A[1][0]
        const f = Math.max(0, Math.min(1, gap / 3))
        const cy = (A[1][1] + A[2][1]) / 2
        if (f >= 1) return "M" + pt(A[1]) + "L" + pt(A[2]) + "M" + pt(B[0]) + "L" + pt(B[3])
        const a1 = mix(A[1], A[2], f / 2), a2 = mix(A[2], A[1], f / 2)
        const b0 = mix(B[0], B[3], f / 2), b3 = mix(B[3], B[0], f / 2)
        const mx = (a1[0] + b0[0]) / 2
        const ct = (a1[1] + b0[1]) / 2 + (cy - (a1[1] + b0[1]) / 2) * f
        const cb = (a2[1] + b3[1]) / 2 + (cy - (a2[1] + b3[1]) / 2) * f
        return "M" + pt(A[1]) + "L" + pt(a1) + "Q" + mx + " " + ct + " " + pt(b0) + "L" + pt(B[0])
            + "M" + pt(A[2]) + "L" + pt(a2) + "Q" + mx + " " + cb + " " + pt(b3) + "L" + pt(B[3])
    }
    readonly property var qa: quad(0)
    readonly property var qb: quad(1)

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
                PathSvg { path: root.halfA(root.qa) }
            }
            ShapePath {
                strokeColor: root.color; strokeWidth: 2; fillColor: "transparent"
                capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                PathSvg { path: root.halfB(root.qb) }
            }
            ShapePath {
                strokeColor: root.color; strokeWidth: 2; fillColor: "transparent"
                capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                PathSvg { path: root.neck(root.qa, root.qb) }
            }
        }
    }
}
