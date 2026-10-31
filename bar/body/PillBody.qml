import QtQuick
import "../Singletons"
import "../components"

// Presentation only: PillMorphMotion remains the owner of layout and input.
Item {
    id: root
    property bool waterBody: false
    property real reading: 0
    property real edgeExposure: 1
    property bool suppressEdge: false
    property bool shadowEnabled: true
    property real captureExtra: 0
    property real captureLeftExtra: 0
    readonly property real restExposure: waterBody ? Math.max(0, Math.min(1, restPresence.value)) : 1
    readonly property bool expressive: !waterBody || restExposure > 0
    readonly property real expressiveGeometry: restExposure
    property point sceneOrigin: Qt.point(x, y)
    property real s: 1
    property real restWidth: width
    // The engine keeps the rest height; only PillMorphMotion owns the live outline.
    property real liveHeight: height
    property real cornerRadius: height / 2
    // Same transmission as PillMaterial; legacy mode keeps readingExposure at zero.
    readonly property real fillAlpha: Math.min(1, Flags.glassAlpha + (1 - Flags.glassAlpha) * (0.15 + 0.25 * (waterBody ? reading : 0))
        + Theme.glassChromaLift * (0.4 + 0.6 * (waterBody ? reading : 0)))
    property bool resting: false
    property bool running: true
    property bool reduceMotion: false
    property bool breathe: false
    property real hour: 12
    property string mood: "curiosa"
    property bool music: false
    property real beatEnvelope: 0
    property bool messengerActive: false
    property bool pointerInside: false
    property point pointer: Qt.point(-1, -1)
    // Stored file: the messenger owns the hit target; this only draws it as a
    // droplet budding from the underside (x, y, radius in body coordinates).
    property bool docked: false
    property vector3d dock: Qt.vector3d(0, 0, 0)
    property bool dockHovered: false
    property bool dockPressed: false
    readonly property real dockProgress: dockSpring.value
    readonly property real margin: 90 * s
    readonly property bool shaderFailed: glass.status === ShaderEffect.Error
    readonly property bool shaderSupported: glass.GraphicsInfo.api !== GraphicsInfo.Software
    readonly property bool waterActive: waterBody && running && shaderSupported && !shaderFailed && !Flags.reduceTransparency
    property real exposure: (waterBody ? waterActive : resting && running && shaderSupported && !shaderFailed) ? 1 : 0
    readonly property alias engine: engine
    readonly property alias shader: glass
    visible: exposure > 0.001
    // Legacy handoff only: compensated opacity keeps the stacked alpha constant.
    // Water mode has no exposure animation and leaves only material decorations.

    Behavior on exposure {
        enabled: !root.waterBody && !root.reduceMotion
        NumberAnimation { duration: 100; easing.type: Easing.InOutQuad }
    }

    SpringValue {
        id: restPresence
        objectName: "pillBodyRestPresence"
        target: root.waterBody && root.resting ? 1 : 0
        spring: Motion.strokeSpring.lift
        active: root.waterActive && !root.reduceMotion
    }
    SpringValue {
        id: dockSpring
        target: root.docked ? 1 : 0
        spring: Motion.strokeSpring.lift
        active: root.running && !root.reduceMotion
    }
    SpringValue {
        id: dockTouch
        target: root.dockPressed ? -1 : root.dockHovered ? 1 : 0
        spring: Motion.strokeSpring.lift
        active: root.running && !root.reduceMotion
    }

    BodyEngine {
        id: engine
        objectName: "pillBodyEngine"
        cx: root.margin + root.width / 2
        cy: root.margin + root.height / 2
        baseW: Math.max(root.height, root.restWidth)
        baseH: root.height
        active: root.running && root.exposure > 0.001 && !root.shaderFailed
        reduceMotion: root.reduceMotion
        breathe: root.breathe && root.expressive
        maxBreathAmplitude: 1.1 * root.s
        storedWidens: false
        sleepWhenStill: root.waterBody
        hour: root.hour
        mood: root.expressive ? root.mood : "curiosa"
        music: root.music && root.expressive
        beatEnvelope: root.beatEnvelope
        pointer: root.expressive && root.pointerInside ? Qt.point(root.pointer.x + root.margin, root.pointer.y + root.margin) : Qt.point(-1, -1)
    }

    BodyShader {
        id: glass
        visible: !root.messengerActive
        objectName: "pillBodyShader"
        opacity: root.waterBody ? 1 : root.exposure / Math.max(0.001, 1 - root.fillAlpha * (1 - root.exposure))
        x: -root.margin - (root.waterBody ? root.captureLeftExtra : 0); y: -root.margin
        width: root.width + (root.waterBody ? root.captureExtra + root.captureLeftExtra : 0) + 2 * root.margin
        height: Math.max(root.height, root.liveHeight) + 2 * root.margin
        designScale: root.s
        // Aura stays off; water shadow has its own alpha capped below ignore_alpha=0.15.
        outsideOpacity: 0
        water: root.waterBody ? 1 : 0
        reading: root.reading
        edgeExposure: root.suppressEdge ? 0 : root.edgeExposure
        shadowExposure: root.shadowEnabled ? root.reading * edgeExposure : 0
        cacheWhenStill: root.waterActive && !engine.needsFrames
            && !(engine.breathe && !root.reduceMotion) && !restPresence.integrating
            && !dockSpring.integrating && !dockTouch.integrating
        cacheOrigin: root.sceneOrigin
        time: engine.time
        // Use only bounded expressive offsets, never a second layout spring.
        pillCx: root.margin + (root.width + (root.waterBody ? root.captureExtra + root.captureLeftExtra : 0)) / 2 + root.expressiveGeometry * Math.max(-6 * root.s, Math.min(6 * root.s, engine.pill.x - engine.cx))
        pillCy: root.margin + root.liveHeight / 2 + root.expressiveGeometry * Math.max(-4 * root.s, Math.min(4 * root.s, engine.pill.y - engine.cy))
        pillHalfW: root.waterBody ? (root.width + root.captureExtra + root.captureLeftExtra) / 2
            + root.restExposure * Math.max(-8 * root.s, Math.min(8 * root.s, engine.pill.z - engine.baseW / 2))
            : Math.max(pillHalfH, root.width / 2 + Math.max(-8 * root.s, Math.min(8 * root.s, engine.pill.z - engine.baseW / 2)))
        pillHalfH: root.liveHeight / 2 + root.expressiveGeometry * Math.max(-6 * root.s, Math.min(4 * root.s, engine.pill.w - engine.baseH / 2))
        pillRadius: root.waterBody ? root.cornerRadius : root.resting ? -1 : root.cornerRadius
        bulge: Qt.vector4d(engine.bulge.x, engine.bulge.y, engine.bulge.z * root.restExposure, engine.bulge.w * root.restExposure)
        // Buds from inside the lower edge; the shared fusion radius draws the neck.
        // A shared rest spring withdraws the bud and expressive shape without a hard switch.
        drop0: {
            const p = Math.max(0, root.dockProgress) * (root.waterBody ? root.restExposure : root.exposure)
            const size = root.waterBody ? Math.max(0, root.dockProgress) : p
            const r = root.dock.z * Math.min(1, 0.4 + 0.6 * size) * (1 + 0.08 * dockTouch.value)
                * (root.waterBody ? root.restExposure : 1)
            const top = glass.pillCy + glass.pillHalfH - r * 0.6
            return Qt.vector4d(root.dock.x, top + (root.dock.y - top) * p, r * Math.min(1, size * 4), root.waterBody ? p : p > 0.01 ? 1 : 0)
        }
        glow: engine.glow
        night: engine.night
        spec: engine.spec
        warm: engine.warm
        lightDir: engine.lightDir
        colA: Theme.accentSoft
        colB: Theme.accentAlt
        colC: Theme.accent
        colBg: Theme.background
        colTop: Theme.cardTop
        colBase: Theme.cardBot
        fillAlpha: root.fillAlpha
    }
    ShaderEffectSource {
        id: cachedGlass
        objectName: "pillBodyCache"
        readonly property real dpr: Screen.devicePixelRatio
        x: Math.floor((root.sceneOrigin.x + glass.x) * dpr) / dpr - root.sceneOrigin.x
        y: Math.floor((root.sceneOrigin.y + glass.y) * dpr) / dpr - root.sceneOrigin.y
        width: Math.ceil((glass.x + glass.width - x) * dpr) / dpr
        height: Math.ceil((glass.y + glass.height - y) * dpr) / dpr
        sourceRect: Qt.rect(x - glass.x, y - glass.y, width, height)
        textureSize: Qt.size(Math.round(width * dpr), Math.round(height * dpr))
        sourceItem: hideSource ? glass : null
        live: false
        smooth: true
        hideSource: root.waterActive && glass.cacheWhenStill && !glass.parametersChanging
        visible: hideSource && !root.messengerActive
        Connections {
            target: glass
            function onParametersChangingChanged() {
                if (!glass.parametersChanging && root.waterActive) cachedGlass.scheduleUpdate()
            }
        }
    }
}
