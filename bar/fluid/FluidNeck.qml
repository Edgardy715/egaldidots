import QtQuick

/** GPU neck between the pill and a droplet: smooth union of two rounded boxes,
 * filled only outside both bodies. Geometry is in the parent's coordinates. */
ShaderEffect {
    id: root

    property real bodyLeft: 0; property real bodyTop: 0
    property real bodyWidth: 0; property real bodyHeight: 0
    property real bodyCorner: 0
    property real dropLeft: 0; property real dropTop: 0
    property real dropWidth: 0; property real dropHeight: 0
    property real dropCorner: 0
    property real blend: 0
    // PillMaterial gradient stops of each end; the neck blends between them.
    property color bodyColor0: "black"; property color bodyColor1: "black"; property color bodyColor2: "black"
    property color dropColor0: "black"; property color dropColor1: "black"; property color dropColor2: "black"
    property color accent: "transparent"
    property real bodyBand: 0; property real bodyBandHeight: 1
    property real dropBand: 0; property real dropBandHeight: 1

    readonly property real margin: blend / 2 + 2
    x: Math.floor(Math.min(bodyLeft, dropLeft) - margin)
    y: Math.floor(Math.min(bodyTop, dropTop) - margin)
    width: Math.ceil(Math.max(bodyLeft + bodyWidth, dropLeft + dropWidth) + margin) - x
    height: Math.ceil(Math.max(bodyTop + bodyHeight, dropTop + dropHeight) + margin) - y

    readonly property size itemSize: Qt.size(width, height)
    readonly property vector4d bodyBox: Qt.vector4d(bodyLeft + bodyWidth / 2 - x, bodyTop + bodyHeight / 2 - y,
                                                    bodyWidth / 2, bodyHeight / 2)
    readonly property vector4d dropBox: Qt.vector4d(dropLeft + dropWidth / 2 - x, dropTop + dropHeight / 2 - y,
                                                    dropWidth / 2, dropHeight / 2)
    readonly property real bodyRadius: Math.min(bodyCorner, bodyWidth / 2, bodyHeight / 2)
    readonly property real dropRadius: Math.min(dropCorner, dropWidth / 2, dropHeight / 2)
    readonly property vector4d spans: Qt.vector4d(bodyTop - y, bodyHeight, dropTop - y, dropHeight)
    readonly property vector4d bands: Qt.vector4d(bodyBand, bodyBandHeight, dropBand, dropBandHeight)

    fragmentShader: Qt.resolvedUrl("shaders/fluid_neck.frag.qsb")
}
