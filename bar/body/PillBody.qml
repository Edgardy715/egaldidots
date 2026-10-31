import QtQuick
import "../Singletons"
import "../components"

// Presentation only: PillMorphMotion remains the owner of layout and input.
Item {
    id: root
    property var companion0: null
    readonly property vector4d box0: companion0 ? companion0.fieldBox : Qt.vector4d(0, 0, 0, 0)
    property var companion1: null
    readonly property vector4d box1: companion1 ? companion1.fieldBox : Qt.vector4d(0, 0, 0, 0)
    property var companion2: null
    readonly property vector4d box2: companion2 ? companion2.fieldBox : Qt.vector4d(0, 0, 0, 0)
    property var companion3: null
    readonly property vector4d box3: companion3 ? companion3.fieldBox : Qt.vector4d(0, 0, 0, 0)
    property var companion4: null
    readonly property vector4d box4: companion4 ? companion4.fieldBox : Qt.vector4d(0, 0, 0, 0)
    // All bodies share one padded render domain, including detached/centered cards.
    readonly property real fieldLeft: Math.min(-captureLeftExtra, box0.x - box0.z, box1.x - box1.z, box2.x - box2.z, box3.x - box3.z, box4.x - box4.z)
    readonly property real fieldTop: Math.min(0, box0.y - box0.w, box1.y - box1.w, box2.y - box2.w, box3.y - box3.w, box4.y - box4.w)
    readonly property real fieldRight: Math.max(width + captureExtra, box0.x + box0.z, box1.x + box1.z, box2.x + box2.z, box3.x + box3.z, box4.x + box4.z)
    readonly property real fieldBottom: Math.max(height, liveHeight, box0.y + box0.w, box1.y + box1.w, box2.y + box2.w, box3.y + box3.w, box4.y + box4.w)
    readonly property bool hasCompanion: box0.z > 0 || box1.z > 0 || box2.z > 0 || box3.z > 0 || box4.z > 0
    property string surface: ""
    property string artUrl: ""
    property var artworkTransition: null
    property color materialAccent: Theme.accent
    property bool materialAwake: false
    property real notifBreathGlow: 0
    property int materialEpoch: 0
    onMaterialEpochChanged: awaken()
    readonly property bool receiving: receptionSpring.integrating
    readonly property alias receptionMotion: receptionSpring
    readonly property alias sweepMotion: sweepSpring
    property vector4d receptionOrigin: Qt.vector4d(0, 0, 1, 1)
    // Media is slot 0 in composition; the shared artwork clock stays with content.
    readonly property var mediaCompanion: companion0 && companion0.surfaceName === "media"
        && companion0.active && companion0.ambientMedia ? companion0 : null
    readonly property var ambientTransition: surface === "media" ? artworkTransition
        : mediaCompanion ? mediaCompanion.artworkTransition : null
    readonly property string ambientUrl: surface === "media" ? artUrl : mediaCompanion ? mediaCompanion.artUrl : ""
    readonly property vector4d ambientBox: surface === "media" ? Qt.vector4d(width / 2, liveHeight / 2, width / 2, liveHeight / 2)
        : mediaCompanion ? box0 : Qt.vector4d(0, 0, 0, 0)
    function awaken() {
        if (waterActive) sweepSpring.target += 1
    }
    function receive(position, companion) {
        if (!waterActive) return
        const b = companion ? companion.fieldBox : Qt.vector4d(width / 2, liveHeight / 2, width / 2, liveHeight / 2)
        // Repeated feedback preserves the moving field's origin and position.
        if (!receiving) receptionOrigin = Qt.vector4d(b.x + (Math.max(.08, Math.min(.92, position)) - .5) * 2 * b.z, b.y + b.w * .48, b.z, b.w)
        receptionSpring.kick(Motion.strokeSpring.wave.omega)
        awaken()
    }
    function settleReception() { receptionSpring.snap(0) }
    SpringValue {
        id: receptionSpring
        target: 0
        spring: Motion.strokeSpring.wave
        active: root.waterActive
        manualStep: true
    }
    SpringValue {
        id: sweepSpring
        target: 0
        spring: Motion.strokeSpring.tide
        active: root.waterActive
        manualStep: true
    }
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
    readonly property bool waterActive: waterBody && running && shaderSupported && !shaderFailed && !Flags.reduceTransparency && !reduceMotion
    property real exposure: (waterBody ? waterActive : resting && running && shaderSupported && !shaderFailed) ? 1 : 0
    readonly property alias engine: engine
    readonly property alias shader: glass
    visible: exposure > 0.001
    // Legacy handoff only: compensated opacity keeps the stacked alpha constant.
    // Water mode has no exposure animation; decoration is part of the shared field.

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
        x: -root.margin + (root.waterBody ? root.fieldLeft : 0)
        y: -root.margin + (root.waterBody ? root.fieldTop : 0)
        width: (root.waterBody ? root.fieldRight - root.fieldLeft : root.width) + 2 * root.margin
        height: (root.waterBody ? root.fieldBottom - root.fieldTop : Math.max(root.height, root.liveHeight)) + 2 * root.margin
        designScale: root.s
        // Aura stays off; water shadow has its own alpha capped below ignore_alpha=0.15.
        outsideOpacity: 0
        water: root.waterBody ? 1 : 0
        decorAccent: root.materialAccent
        decorAwake: root.materialAwake || root.hasCompanion ? 1 : 0
        decorGlow: root.notifBreathGlow
        reception: Qt.vector4d(root.receptionOrigin.x - x, root.receptionOrigin.y - y,
            Math.max(1, root.receptionOrigin.z), Math.max(0, receptionSpring.value))
        sweep: sweepSpring.value
        decorMoving: root.waterActive && (receptionSpring.integrating || sweepSpring.integrating)
        onAdvanceDecor: dt => {
            if (receptionSpring.integrating) receptionSpring.step(dt)
            if (sweepSpring.integrating) sweepSpring.step(dt)
        }
        artBox: Qt.vector4d(root.ambientBox.x - x, root.ambientBox.y - y, root.ambientBox.z, root.ambientBox.w)
        artFirstUrl: root.waterActive && root.ambientUrl.length > 0
            ? root.ambientTransition ? root.ambientTransition.firstUrl : root.ambientUrl : ""
        artSecondUrl: root.waterActive && root.ambientUrl.length > 0 && root.ambientTransition ? root.ambientTransition.secondUrl : ""
        artBlend: root.ambientTransition ? root.ambientTransition.blend : 0
        artSlot: root.ambientTransition ? root.ambientTransition.activeSlot : 0
        reading: root.reading
        edgeExposure: root.hasCompanion ? 1 : root.suppressEdge ? 0 : root.edgeExposure
        shadowExposure: root.shadowEnabled ? root.reading * edgeExposure : 0
        cacheWhenStill: root.waterActive && !engine.needsFrames
            && !(engine.breathe && !root.reduceMotion) && !restPresence.integrating
            && !dockSpring.integrating && !dockTouch.integrating
        cacheOrigin: root.sceneOrigin
        time: engine.time
        // Use only bounded expressive offsets, never a second layout spring.
        pillCx: -glass.x + (root.width + (root.waterBody ? root.captureExtra - root.captureLeftExtra : 0)) / 2 + root.expressiveGeometry * Math.max(-6 * root.s, Math.min(6 * root.s, engine.pill.x - engine.cx))
        pillCy: -glass.y + root.liveHeight / 2 + root.expressiveGeometry * Math.max(-4 * root.s, Math.min(4 * root.s, engine.pill.y - engine.cy))
        pillHalfW: root.waterBody ? (root.width + root.captureExtra + root.captureLeftExtra) / 2
            + root.restExposure * Math.max(-8 * root.s, Math.min(8 * root.s, engine.pill.z - engine.baseW / 2))
            : Math.max(pillHalfH, root.width / 2 + Math.max(-8 * root.s, Math.min(8 * root.s, engine.pill.z - engine.baseW / 2)))
        pillHalfH: root.liveHeight / 2 + root.expressiveGeometry * Math.max(-6 * root.s, Math.min(4 * root.s, engine.pill.w - engine.baseH / 2))
        pillRadius: root.waterBody ? root.cornerRadius : root.resting ? -1 : root.cornerRadius
        bulge: Qt.vector4d(engine.bulge.x - glass.x - root.margin, engine.bulge.y - glass.y - root.margin,
            engine.bulge.z * root.restExposure, engine.bulge.w * root.restExposure)
        // Buds from inside the lower edge; the shared fusion radius draws the neck.
        // A shared rest spring withdraws the bud and expressive shape without a hard switch.
        drop0: {
            const p = Math.max(0, root.dockProgress) * (root.waterBody ? root.restExposure : root.exposure)
            const size = root.waterBody ? Math.max(0, root.dockProgress) : p
            const r = root.dock.z * Math.min(1, 0.4 + 0.6 * size) * (1 + 0.08 * dockTouch.value)
                * (root.waterBody ? root.restExposure : 1)
            const top = glass.pillCy + glass.pillHalfH - r * 0.6
            return Qt.vector4d(root.dock.x - glass.x - root.margin, top + (root.dock.y - glass.y - root.margin - top) * p, r * Math.min(1, size * 4), root.waterBody ? p : p > 0.01 ? 1 : 0)
        }
        wallOrigin: Qt.vector2d(x + (root.waterBody ? root.sceneOrigin.x : 0), y + (root.waterBody ? root.sceneOrigin.y : 0))
        companionBox0: Qt.vector4d(root.box0.x - x, root.box0.y - y, root.box0.z, root.box0.w)
        companionShape0: root.companion0 ? root.companion0.fieldShape : Qt.vector2d(0, 0)
        companionBox1: Qt.vector4d(root.box1.x - x, root.box1.y - y, root.box1.z, root.box1.w)
        companionShape1: root.companion1 ? root.companion1.fieldShape : Qt.vector2d(0, 0)
        companionBox2: Qt.vector4d(root.box2.x - x, root.box2.y - y, root.box2.z, root.box2.w)
        companionShape2: root.companion2 ? root.companion2.fieldShape : Qt.vector2d(0, 0)
        companionBox3: Qt.vector4d(root.box3.x - x, root.box3.y - y, root.box3.z, root.box3.w)
        companionShape3: root.companion3 ? root.companion3.fieldShape : Qt.vector2d(0, 0)
        companionBox4: Qt.vector4d(root.box4.x - x, root.box4.y - y, root.box4.z, root.box4.w)
        companionShape4: root.companion4 ? root.companion4.fieldShape : Qt.vector2d(0, 0)
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
