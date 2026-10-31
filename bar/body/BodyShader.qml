import QtQuick

ShaderEffect {
    id: root
    property size itemSize: Qt.size(width, height)
    property real time: 0
    property real designScale: 1
    property real aaPx: 1 / Screen.devicePixelRatio
    property real fusionRadius: 24 * designScale
    property real warm: 0
    property real glow: 0
    property real night: 0
    property real spec: 1
    property real outsideOpacity: 1
    property real water: 0
    property real reading: 0
    property real edgeExposure: 1
    property real shadowExposure: 1
    property bool cacheWhenStill: false
    property point cacheOrigin: Qt.point(0, 0)
    readonly property int quietFrames: 6
    property int unchangedFrames: 0
    property bool inputsDirty: true
    readonly property bool parametersChanging: unchangedFrames < quietFrames
    readonly property bool settling: settleFrames.running
    // Every render input invalidates the frozen texture, including theme and geometry.
    readonly property var renderInputs: cacheWhenStill ? [width, height, opacity, itemSize, time, designScale, aaPx,
        fusionRadius, warm, glow, night, spec, outsideOpacity, wallMix, pill, bulge,
        drop0, drop1, drop2, drop3, lightDir, wallOrigin, wallXform, colA, colB, colC,
        colBg, colBase, colTop, fillAlpha, pillRadius, water, reading, edgeExposure,
        shadowExposure, wallpaperSource, fragmentShader, status, cacheOrigin] : null
    onRenderInputsChanged: { unchangedFrames = 0; inputsDirty = true }
    FrameAnimation {
        id: settleFrames
        running: root.cacheWhenStill && root.parametersChanging
        onTriggered: {
            if (root.inputsDirty) root.inputsDirty = false
            else root.unchangedFrames++
        }
    }
    property real wallMix: wallImg.status === Image.Ready ? 1 : 0
    property vector4d pill: Qt.vector4d(pillCx, pillCy, pillHalfW, pillHalfH)
    property vector4d bulge: Qt.vector4d(bulgeX, bulgeY, bulgeR, bulgeWeight)
    property vector4d drop0: Qt.vector4d(0, 0, 0, 0)
    property vector4d drop1: Qt.vector4d(0, 0, 0, 0)
    property vector4d drop2: Qt.vector4d(0, 0, 0, 0)
    property vector4d drop3: Qt.vector4d(0, 0, 0, 0)
    property vector2d lightDir: Qt.vector2d(0, -1)
    property vector2d wallOrigin: Qt.vector2d(x, y)
    property vector4d wallXform: {
        const iw = Math.max(1, wallImg.implicitWidth)
        const ih = Math.max(1, wallImg.implicitHeight)
        const sw = Math.max(1, screenSize.width)
        const sh = Math.max(1, screenSize.height)
        const scale = Math.max(sw / iw, sh / ih)
        const rw = iw * scale, rh = ih * scale
        return Qt.vector4d(1 / rw, 1 / rh, (rw - sw) / (2 * rw), (rh - sh) / (2 * rh))
    }
    required property color colA
    required property color colB
    required property color colC
    required property color colBg
    // Tinte compartido con PillMaterial; water añade sus tres paradas de lectura.
    property color colBase: Qt.rgba(0.026, 0.026, 0.034, 1)
    property color colTop: colBase
    property real fillAlpha: 1
    // < 0: estadio. Un radio explícito sigue las esquinas del morph.
    property real pillRadius: -1

    // La superficie reserva 90*designScale por lado para aura y sombra.
    property real pillCx: width / 2
    property real pillCy: height / 2
    property real pillHalfW: width / 2
    property real pillHalfH: height / 2
    property real bulgeX: 0
    property real bulgeY: 0
    property real bulgeR: 0
    // Escala la fusión del brote: 0 lo retira sin dejar hinchazón en el borde.
    property real bulgeWeight: 1
    property size screenSize: Qt.size(Screen.width, Screen.height)
    property url wallpaperSource: ""
    property var wallpaper: wallImg

    Image {
        id: wallImg
        visible: false
        asynchronous: true
        cache: true
        sourceSize: Qt.size(960, 540)
        fillMode: Image.Stretch
        source: root.wallpaperSource
    }
    Behavior on wallMix { NumberAnimation { duration: 400 } }

    fragmentShader: Qt.resolvedUrl("shaders/body.frag.qsb")
}
