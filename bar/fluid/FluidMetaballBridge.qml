import QtQuick
import QtQuick.Shapes

Shape {
    id: root
    property real x1: 0; property real y1: 0; property real r1: 1
    property real x2: 0; property real y2: 0; property real r2: 1
    property real waist: 0.42
    property color fill: "black"

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    asynchronous: true

    readonly property real d: Math.hypot(x2 - x1, y2 - y1)
    readonly property bool valid: d > Math.abs(r1 - r2) + 0.5 && d < (r1 + r2) * 1.6
    readonly property real angle: Math.atan2(y2 - y1, x2 - x1)
    readonly property real u1: d < r1 + r2 ? Math.acos((r1 * r1 + d * d - r2 * r2) / (2 * r1 * d)) : 0
    readonly property real u2: d < r1 + r2 ? Math.acos((r2 * r2 + d * d - r1 * r1) / (2 * r2 * d)) : 0
    readonly property real spread: Math.acos(Math.max(-1, Math.min(1, (r1 - r2) / d)))
    readonly property real a1: angle + u1 + (spread - u1) * waist
    readonly property real a2: angle - u1 - (spread - u1) * waist
    readonly property real a3: angle + Math.PI - u2 - (Math.PI - u2 - spread) * waist
    readonly property real a4: angle - Math.PI + u2 + (Math.PI - u2 - spread) * waist
    readonly property real p1x: x1 + r1 * Math.cos(a1); readonly property real p1y: y1 + r1 * Math.sin(a1)
    readonly property real p2x: x1 + r1 * Math.cos(a2); readonly property real p2y: y1 + r1 * Math.sin(a2)
    readonly property real p3x: x2 + r2 * Math.cos(a3); readonly property real p3y: y2 + r2 * Math.sin(a3)
    readonly property real p4x: x2 + r2 * Math.cos(a4); readonly property real p4y: y2 + r2 * Math.sin(a4)
    readonly property real handleScale: Math.min(waist * 2.1, Math.hypot(p1x - p3x, p1y - p3y) / (r1 + r2)) * Math.min(1, d * 2 / (r1 + r2))
    readonly property real h1x: p1x + r1 * handleScale * Math.cos(a1 - Math.PI / 2); readonly property real h1y: p1y + r1 * handleScale * Math.sin(a1 - Math.PI / 2)
    readonly property real h2x: p2x + r1 * handleScale * Math.cos(a2 + Math.PI / 2); readonly property real h2y: p2y + r1 * handleScale * Math.sin(a2 + Math.PI / 2)
    readonly property real h3x: p3x + r2 * handleScale * Math.cos(a3 + Math.PI / 2); readonly property real h3y: p3y + r2 * handleScale * Math.sin(a3 + Math.PI / 2)
    readonly property real h4x: p4x + r2 * handleScale * Math.cos(a4 - Math.PI / 2); readonly property real h4y: p4y + r2 * handleScale * Math.sin(a4 - Math.PI / 2)

    visible: valid
    ShapePath {
        fillColor: root.fill
        strokeColor: "transparent"
        startX: root.p1x; startY: root.p1y
        PathCubic { x: root.p3x; y: root.p3y; control1X: root.h1x; control1Y: root.h1y; control2X: root.h3x; control2Y: root.h3y }
        PathLine { x: root.p4x; y: root.p4y }
        PathCubic { x: root.p2x; y: root.p2y; control1X: root.h4x; control1Y: root.h4y; control2X: root.h2x; control2Y: root.h2y }
        PathLine { x: root.p1x; y: root.p1y }
    }
}
