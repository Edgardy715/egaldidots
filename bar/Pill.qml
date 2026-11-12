import QtQuick
import Quickshell.Wayland
import "Singletons"
import "components"
import "components/audio"
import "components/RubberBand.js" as RubberBand
import "body"

/** Pill principal: expone estado al shell y coordina geometría, surfaces y morphs de notificación.
 * Inspirada en Ricelin Pill.qml.
 */
Item {
    id: pill

    // ---- API pública (host svg) ----
    readonly property alias bodyPresentation: body
    property real s: 1
    property bool layoutChanging: false
    property bool pullIntent: false
    readonly property alias pullMotion: morph
    readonly property alias pullGesture: pull
    property bool pullEnabled: true
    property string pullTarget: "utils"
    signal pullPrepare(string name)
    signal pullSettled(string name, bool opened)
    PillPullGesture {
        id: pull
        motion: morph
        s: pill.s
        enabled: pill.pullEnabled && !pill.layoutChanging
        reduceMotion: Flags.reduceMotion
        mode: pill.notifMorphing && pill.activeNotif ? "notification" : "surface"
        target: pill.pullTarget
        plannedW: pill.surfaceOpen && pill.surface === pull.surface ? pill.targetW
            : (IslandGeometry.surfaceSizes[pull.surface || target] || IslandGeometry.fallbackSurface).width * pill.s
        plannedH: pill.surfaceOpen && pill.surface === pull.surface ? pill.targetH
            : (IslandGeometry.surfaceSizes[pull.surface || target] || IslandGeometry.fallbackSurface).height * pill.s
        plannedRadius: Math.min(Math.max(18 * pill.s, plannedW * 0.055), plannedH / 2 - 2 * pill.s)
        rubberBand: (value, limit) => RubberBand.rubberBand(value, limit, 0.55)
        onNotificationStarted: pill.pauseNotification()
        onNotificationFinished: action => pill.finishNotification(action)
        onPrepare: name => pill.pullPrepare(name)
        onSettled: (name, opened) => pill.pullSettled(name, opened)
    }
    // Observe before descendant MouseAreas, without accepting their presses.
    Item {
        anchors.fill: parent
        z: 100
        PointHandler {
            id: pullPoint
            acceptedButtons: Qt.LeftButton
            enabled: pill.pullEnabled
            onPointChanged: if (active && pill.pullGesture.candidate)
                pill.pullIntent = pill.pullGesture.wantsMove(point.scenePosition.x, point.scenePosition.y)
            onActiveChanged: {
                if (active) pill.pullIntent = false
                if (active && pill.pullCanStart(point.position)) {
                    pill.pullGesture.press(point.scenePosition.x, point.scenePosition.y,
                        Date.now(), pill.surfaceOpen, pill.surface)
                } else if (!active && !pullDrag.active && !pill.pullGesture.scrolling) {
                    pill.pullGesture.release(Date.now())
                }
            }
        }
        DragHandler {
            id: pullDrag
            target: null
            acceptedButtons: Qt.LeftButton
            enabled: pill.pullEnabled && !pill.pullGesture.scrolling
            xAxis.enabled: pill.pullGesture.kind === "notification"
            dragThreshold: pill.pullIntent ? Math.max(Motion.pullThreshold * pill.s, 1) : 32766
            grabPermissions: PointerHandler.CanTakeOverFromItems
                | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                | PointerHandler.ApprovesTakeOverByAnything
            onActiveChanged: {
                if (active) pill.pullGesture.move(centroid.scenePosition.x, centroid.scenePosition.y, Date.now())
                else if (!pullPoint.active) pill.pullGesture.release(Date.now())
            }
            onCentroidChanged: if (active)
                pill.pullGesture.move(centroid.scenePosition.x, centroid.scenePosition.y, Date.now())
            onCanceled: pill.pullGesture.cancel()
        }
        WheelHandler {
            id: pullWheel
            target: null
            enabled: pill.pullEnabled
            acceptedDevices: PointerDevice.TouchPad  // la rueda del ratón nunca abre ni cierra surfaces
            blocking: false
            activeTimeout: Motion.pullScrollTimeout / 1000
            onWheel: event => { event.accepted = pill.pullWheelDelta(event.x, event.y,
                event.pixelDelta.x, event.pixelDelta.y, event.inverted) }
            // Qt's QML WheelEvent omits phase; WheelHandler.active handles
            // native ScrollEnd. The state also has a 120 ms fallback.
            onActiveChanged: if (!active && !pullWheelCatch.active) pill.pullWheelIdle()
        }
        // The shrinking card moves away from a fixed pointer. While a wheel
        // gesture lives, this catcher (parented to the window, so it covers
        // the whole overlay) keeps receiving the steps the pill no longer gets.
        Item {
            id: wheelCatcher
            parent: pill.Window.contentItem || pill
            anchors.fill: parent
            z: -1
            enabled: pill.pullGesture.scrolling
            WheelHandler {
                id: pullWheelCatch
                target: null
                enabled: wheelCatcher.enabled
                acceptedDevices: PointerDevice.TouchPad  // la rueda del ratón nunca abre ni cierra surfaces
                blocking: false
                activeTimeout: Motion.pullScrollTimeout / 1000
                onWheel: event => { event.accepted = pill.pullWheelDelta(event.x, event.y,
                    event.pixelDelta.x, event.pixelDelta.y, event.inverted) }
                onActiveChanged: if (!active && !pullWheel.active) pill.pullWheelIdle()
            }
        }
    }

    function pullWheelDelta(x, y, dx, dy, inverted) {
        // Angle-only mouse wheels always retain their existing path.
        if (!pullGesture.scrolling && !pullCanWheel(Qt.point(x, y))) return false
        const atTop = pullScrollAtTop(surfaceItem)
        const wanted = pullGesture.wheelWanted(dx, dy, surfaceOpen, atTop, inverted)
        // Never open/close surfaces inside Qt's wheel delivery.
        if (wanted) pullGesture.queueWheel(dx, dy, Date.now(), surfaceOpen, surface, atTop, inverted)
        return wanted
    }
    // Deactivating well before the timeout is a native ScrollEnd (real lift-off
    // time); otherwise it is the timeout, measured at the last step.
    function pullWheelIdle() {
        const now = Date.now(), last = pullGesture.lastWheelTime
        pullGesture.queueWheelRelease(now - last < Motion.pullScrollTimeout - 20 ? now : last)
    }

    function pullScrollAtTop(item) {
        if (!item || !item.visible || !item.enabled) return true
        if (item.contentY !== undefined && item.originY !== undefined
                && item.contentY > item.originY + 0.5) return false
        for (const child of item.children || []) if (!pullScrollAtTop(child)) return false
        return true
    }
    function pullHit(item, point) {
        if (!item || !item.visible || !item.enabled) return false
        const p = item.mapFromItem(pill, point.x, point.y)
        return p.x >= 0 && p.y >= 0 && p.x <= item.width && p.y <= item.height
    }
    function pullWheelControlAt(item, point) {
        if (!pullHit(item, point)) return false
        // Campos de texto no usan la rueda: el scroll sobre ellos cierra la
        // superficie como en cualquier otro punto. Sliders/faders sí la consumen.
        if (item instanceof Slider || item instanceof AudioFader) return true
        for (const child of item.children || []) if (pullWheelControlAt(child, point)) return true
        return false
    }
    function pullCanWheel(point) {
        if (!pull.enabled || surface === "auth" || surface === "wallpaper") return false
        if (notifMorphing && activeNotif) return true
        if (!surfaceOpen) return true
        // Anywhere on an open surface except wheel controls: wheel() still
        // requires every list to sit at its top before a scroll closes it.
        return !pullWheelControlAt(surfaceHost.loadedItem, point)
    }
    function pullHeaderAt(item, point) {
        if (!item || !item.visible || !item.enabled) return false
        const p = item.mapFromItem(pill, point.x, point.y)
        if (p.x < 0 || p.y < 0 || p.x > item.width || p.y > item.height) return false
        if (item.pullGrabZone === true) return true
        for (const child of item.children || []) if (pullHeaderAt(child, point)) return true
        return false
    }
    function pullCanStart(point) {
        if (!pull.enabled || surface === "auth" || surface === "wallpaper") return false
        if (notifMorphing && activeNotif) return true
        if (!surfaceOpen) return true
        // The launcher's separate top strip contains the clock/media controls.
        // Its outer rim remains a grip; its controls keep their existing input.
        if (surface === "launcher" && point.y < launcherHeaderH)
            return point.y < 8 * s || point.x < 12 * s || point.x > width - 12 * s
        const item = surfaceHost.loadedItem
        if (!item) return false
        const p = item.mapFromItem(pill, point.x, point.y)
        return p.x < 0 || p.y < 0 || p.x > item.width || p.y > item.height || pullHeaderAt(item, point)
    }
    property bool recordingDetached: false
    readonly property real restHeaderOpacity: header.restOpacity
    property real restLeftWidth: 0
    property real restRightWidth: 0
    property real restHeight: IslandGeometry.restHeight
    readonly property real restCenterWidth: header.restContentWidth
    property string screenName: ""
    property color bgColor: "transparent"
    property string surface: ""            // nombre de surface activa
    property bool launcherClosing: false
    property int launcherClosePhase: 0
    // Vuelo del launcher: la pill entera se recoge en una gota (LauncherDropMotion).
    property bool dropMode: false
    readonly property real dropSize: geometry.coreH
    // El contenido se retira antes de que la forma se recoja y vuelve con ella.
    property real dropVeil: dropMode ? 0 : 1
    Behavior on dropVeil {
        enabled: !Flags.reduceMotion
        NumberAnimation { duration: pill.dropMode ? 110 : 160; easing.type: Easing.OutCubic }
    }
    property bool forcePinned: false
    property bool companionCodeFocused: false
    property bool companionBlocked: false
    property bool hovered: false
    property bool interactionOpen: surfaceOpen
    readonly property bool receiving: body.waterActive ? body.receiving : material.receiving
    property real pointerX: width / 2
    property real pointerY: height / 2
    property string activityNotice: ""
    property string lastBatteryStatus: ""
    readonly property string focusTime: Math.floor(FocusSession.remainingSeconds / 60)
        + ":" + String(FocusSession.remainingSeconds % 60).padStart(2, "0")
    function respond(kind) {
        if (!visible || surface === "auth" || layoutChanging) return
        bodyEvents.react(kind)
        if (kind !== "paused" && kind !== "cancel") {
            if (body.waterActive) body.receive(0.55)
            else material.receive(0.55)
        }
    }
    function notice(text, kind) {
        if (!visible || surface === "auth" || layoutChanging) return
        activityNotice = text
        noticeHold.restart()
        respond(kind)
    }
    Timer { id: noticeHold; interval: 3200; onTriggered: pill.activityNotice = "" }
    onVisibleChanged: if (!visible) {
        noticeHold.stop()
        activityNotice = ""
        material.settleReception()
        body.settleReception()
    }
    // El motor Fluid puede extender visualmente el casquete derecho sin cambiar
    // el layout ni el contenido de reposo de la pill.
    property Item fluidCompanion0: null
    property Item fluidCompanion1: null
    property Item fluidCompanion2: null
    property Item fluidCompanion3: null
    property Item fluidCompanion4: null
    property bool fluidJoined: false
    property real fluidEdgeExposure: fluidJoined ? 0 : 1
    property real fluidCaptureExtra: 0
    property real fluidCaptureLeftExtra: 0
    readonly property bool pinned: hovered || forcePinned

    signal requestSurface(string name)
    signal requestClose()

    PillGeometry {
        id: geometry
        s: pill.s
        surface: pill.surface
        launcherClosing: pill.launcherClosing
        launcherClosePhase: pill.launcherClosePhase
        dropMode: pill.dropMode
        restContentWidth: header.restContentWidth
        restLeftWidth: pill.restLeftWidth
        restRightWidth: pill.restRightWidth
        restHeight: pill.restHeight
        surfaceSizes: pill.surfaceSize
        fallbackSurface: IslandGeometry.fallbackSurface
        mediaSurface: IslandGeometry.mediaSurface
        marginMd: Theme.marginMd
        fontSizeBodyLg: Theme.fontSizeBodyLg
        fontSizeLabel: Theme.fontSizeLabel
        fontScale: Flags.fontScale
        hasNotification: !!pill.activeNotif && !pill.notifDrop
        notifAnimating: pill.notifMorphing
        notifState: pill.notifState
        notifBreathRadius: pill.notifBreathRadius
        contentLoaded: !!pill.surfaceItem
        contentHeightHint: pill.surfaceItem && pill.surface === "utils" ? pill.surfaceItem.contentHeightHint || 0 : 0
        contentClosing: !!(pill.surfaceItem && pill.surfaceItem.closing)
        resultsVisible: !!(pill.surfaceItem && pill.surfaceItem.resultsVisible)
        emptyResultsVisible: !!(pill.surfaceItem && pill.surfaceItem.emptyResultsVisible)
        showCalculator: !!(pill.surfaceItem && pill.surfaceItem.showCalculator)
        resultsCount: pill.surfaceItem ? pill.surfaceItem.resultsCount : 0
        maxVisibleResults: pill.surfaceItem ? pill.surfaceItem.maxVisibleResults : undefined
        albumDistinct: pill.surfaceItem ? pill.surfaceItem.albumDistinct : undefined
        album: pill.surfaceItem ? pill.surfaceItem.album : undefined
    }

    // Public geometry bindings; PillMorphMotion owns animated values.
    readonly property real coreH: geometry.coreH
    readonly property real padH: geometry.padH

    // ---- notification morph (Dynamic Island style) ----
    // activeNotif = NotifData mostrandose (o null). La pill se morph->circle->notif->hold->circle->rest
    property bool notificationsEnabled: true
    readonly property var activeNotif: notificationMotion.activeNotif
    // ¿resolveIcon encontró un icono real? (false → mostrar genericBadge con glyph fallback)
    readonly property bool _notifIconResolved: activeNotif
        && contentAdapter.notificationIcon.length > 0
    readonly property bool notifAnimating: notificationMotion.notifAnimating
    // Informational notifications bud below as a droplet; the pill keeps its
    // content. Critical ones keep the interrupting morph.
    readonly property bool notifDrop: Flags.notificationDrop && !!activeNotif && !activeNotif.isCritical
    readonly property bool notifMorphing: notifAnimating && !notifDrop
    readonly property bool notifDropOpen: notifDrop && notifAnimating
        && (notifState === "collapse-in" || notifState === "expand" || notifState === "hold")
    readonly property string notificationIcon: contentAdapter.notificationIcon
    // La surface abierta conserva su estado durante una notificación, pero su
    // árbol visual se retira antes del morph para que no se deforme junto al
    // contenido de la notificación. Se revela de nuevo cuando la pill ya volvió
    // a su geometría estable.
    readonly property bool surfaceNotifSuspended: notificationMotion.surfaceNotifSuspended
    readonly property real surfaceReveal: notificationMotion.surfaceReveal
    // target del círculo intermedio (más pequeño que la pill en reposo)
    readonly property real notifCircleD: geometry.notifCircleD
    // target del pill de notif (ancho fijo ~380*s, alto compacto)
    readonly property real notifPillW: geometry.notifPillW
    readonly property real notifPillH: geometry.notifPillH

    readonly property bool surfaceOpen: geometry.surfaceOpen
    readonly property bool launcherReturning: geometry.launcherReturning
    readonly property string mode: surfaceOpen && !launcherReturning ? surface : (hovered ? "hover" : "rest")
    readonly property bool materialAwake: hovered || (surfaceOpen && !launcherReturning)
        || notifMorphing || fluidCaptureExtra > 0.5 * s || fluidCaptureLeftExtra > 0.5 * s
    readonly property color materialAccent: surface === "wallpaper" && surfaceItem && surfaceItem.previewAccent
        ? surfaceItem.previewAccent : Theme.accent
    MaterialChoreography {
        id: materialMotion
        reduceMotion: Flags.reduceMotion
        shapeshiftDuration: Motion.shapeshift
        pulseRiseDuration: Motion.standard
        pulseFallDuration: Motion.emphasizedLarge
        emphasizedDecelCurve: Motion.emphasizedDecelCurve
    }
    readonly property int materialEpoch: materialMotion.epoch
    readonly property real materialSweep: materialMotion.sweep
    readonly property real materialPulse: materialMotion.pulse

    function awakenMaterial() { materialMotion.awaken() }
    onSurfaceChanged: {
        // Escape, outside click or another route wins over an ongoing pull.
        if (pull.active && !pull.resolving && surface !== pull.surface) pull.cancel(false)
        if (surface !== "focus" && surface !== "recording") Recording.cancelCountdown()
        if (surface.length > 0) awakenMaterial()
    }

    // ---- target geometry ----
    readonly property var surfaceSize: IslandGeometry.surfaceSizes
    readonly property var sizeFor: geometry.sizeFor
    readonly property real authInputW: geometry.authInputW
    readonly property real launcherSearchH: geometry.launcherSearchH
    readonly property real launcherHeaderH: geometry.launcherHeaderH
    readonly property bool launcherHeaderVisible: geometry.launcherHeaderVisible
    readonly property real targetW: geometry.targetW
    readonly property real targetH: geometry.targetH
    readonly property real launcherH: geometry.launcherH
    readonly property real mediaH: geometry.mediaH
    readonly property real radiusRest: geometry.radiusRest
    readonly property real radiusOpen: geometry.radiusOpen
    readonly property real targetRadius: geometry.targetRadius

    PillMorphMotion {
        id: morph
        s: pill.s
        targetW: pill.targetW
        targetH: pill.targetH
        targetRadius: pill.targetRadius
        restW: pill.restW
        coreH: pill.coreH
        surfaceOpen: pill.surfaceOpen
        surfaceName: pill.surface
        workspaceAnimating: header.workspaceAnimating
        notifAnimating: pill.notifMorphing
        notifHolding: pill.notifMorphing && pill.notifState === "hold"
        reduceMotion: Flags.reduceMotion
        morphDuration: Motion.morph
        notifCollapseDuration: Motion.notifCollapse
    }
    width: morph.width
    height: morph.height
    property alias morphRadius: morph.radius
    transformOrigin: Item.Top
    readonly property int _morphDuration: morph.duration
    readonly property real morphCloseness: morph.closeness
    readonly property real morphRestReturn: morph.restReturn
    property alias lastSurfaceW: morph.lastSurfaceW
    property alias lastSurfaceH: morph.lastSurfaceH
    readonly property real restW: geometry.restW
    readonly property real surfaceGrowth: morph.surfaceGrowth
    readonly property real surfaceContentProgress: morph.contentProgress

    property var heldNotification: null
    property bool notificationResolving: false
    property var notificationClocks: []
    function pauseNotification() {
        heldNotification = activeNotif
        if (!heldNotification) return
        heldNotification.lock(pill)
        Notifs.pauseExpiration(heldNotification)
        for (const clock of notificationClocks) {
            clock.resume = clock.timer.running
            clock.remaining = Math.max(1, clock.timer.interval - (Date.now() - clock.started))
            clock.timer.stop()
        }
    }
    function finishNotification(action) {
        const notif = heldNotification
        if (!notif) return
        if (action !== "return") {
            notificationResolving = true
            if (action === "open") { Notifs.promote(notif); notif.popup = false }
            else Notifs.dismissGesture(notif)
        }
        for (const clock of notificationClocks) {
            if (action === "return" && clock.resume) {
                clock.timer.interval = clock.remaining
                clock.timer.start()
            } else clock.timer.interval = clock.interval
            clock.resume = false
        }
        Notifs.resumeExpiration(notif)
        notif.unlock(pill)
        heldNotification = null
        if (action !== "return") Qt.callLater(settleNotificationGesture)
    }
    property bool notificationExternalSettling: false
    function settleNotificationGesture() {
        if (!morph.integrating && !morph.grabbed && !notificationExternalSettling) notificationResolving = false
    }
    onNotificationExternalSettlingChanged: settleNotificationGesture()
    Connections {
        target: morph
        function onIntegratingChanged() { if (!morph.integrating) Qt.callLater(pill.settleNotificationGesture) }
    }
    function setupNotificationClocks() {
        const timers = [notificationMotion.notifHoldInObject, notificationMotion.notifExpandTimerObject,
            notificationMotion.notifHoldTimerObject, notificationMotion.notifCollapseOutTimerObject,
            notificationMotion.notifReturnTimerObject, notificationMotion.surfaceRestoreTimerObject]
        notificationClocks = timers.map(timer => ({timer: timer, started: Date.now(), interval: timer.interval, resume: false, remaining: 0}))
        for (const clock of notificationClocks) {
            clock.timer.runningChanged.connect(() => { if (clock.timer.running) clock.started = Date.now() })
            clock.timer.triggered.connect(() => { clock.timer.interval = clock.interval })
        }
    }
    NotificationChoreography {
        id: notificationMotion
        objectName: "pillNotificationMotion"
        blocked: pill.surface === "auth" || pill.notificationResolving
        deferInformational: true
        suspendSurface: !pill.notifDrop
        popup: pill.heldNotification || (pill.notificationsEnabled ? Notifs.activePopup : null)
        surfaceOpen: pill.interactionOpen
        collapseDuration: Motion.notifCollapse + 50
        expandDuration: Motion.notifExpand + 80
        holdDuration: Math.round((Motion.notifHoldMin + Motion.notifHoldMax) / 2)
        restoreDuration: Motion.morph + 70
        onAdvanceRequested: notification => { if (pill.notificationsEnabled) Notifs.advancePopup(notification) }
    }
    readonly property string notifState: notificationMotion.notifState

    readonly property real notifBreath: morph.breathLevel
    readonly property real notifBreathRadius: morph.breathRadius
    readonly property real notifBreathGlow: morph.breathGlow

    //Cuando la pill está en modo notif, el target se computa según notifState.
    // Esto reescribe notifTargetW/H/Radius (declarados arriba como readonly con
    // función IIFE que leía width — los hacemos bindings reactivos a notifState).
    readonly property real _notifTargetW: geometry._notifTargetW
    readonly property real _notifTargetH: geometry._notifTargetH
    readonly property real _notifTargetRadius: geometry._notifTargetRadius

    PillContentAdapter {
        id: contentAdapter
        screenName: pill.screenName
        notification: pill.activeNotif
        onWorkspaceChanged: number => header.flashWorkspace(number)
    }
    property alias now: contentAdapter.now
    property alias wsReady: contentAdapter.workspaceReady
    readonly property string activeWsName: contentAdapter.activeWsName

    ArtworkImage {
        id: sharedArtwork
        visible: false
        width: 416 * pill.s; height: width
        sourceSize: Qt.size(416 * pill.s, 416 * pill.s)
        source: pill.surface === "media" || surfaceHost.displayedSurface === "media" ? contentAdapter.artUrl : ""
        transitionsEnabled: Flags.mediaTransitions
        motionVisible: pill.visible && (pill.surface === "media" || surfaceHost.displayedSurface === "media")
        preloadAmbient: true
    }
    PillBody {
        id: body
        objectName: "pillBody"
        width: pill.width
        height: pill.coreH
        liveHeight: pill.height
        cornerRadius: pill.morphRadius + (body.waterBody ? pill.notifBreathRadius : 0)
        s: pill.s
        waterBody: Config.appearance.waterBody === true
        companion0: pill.fluidCompanion0
        companion1: pill.fluidCompanion1
        companion2: pill.fluidCompanion2
        companion3: pill.fluidCompanion3
        companion4: pill.fluidCompanion4
        sceneOrigin: pill.parent ? pill.parent.mapToItem(null, pill.x, pill.y) : Qt.point(pill.x, pill.y)
        surface: pill.surface === "media" || surfaceHost.displayedSurface === "media" ? "media" : pill.surface
        artUrl: contentAdapter.artUrl
        artworkTransition: sharedArtwork
        materialAccent: pill.materialAccent
        materialAwake: pill.materialAwake
        materialEpoch: pill.materialEpoch
        notifBreathGlow: pill.notifBreathGlow
        reading: material.readingExposure
        edgeExposure: pill.fluidEdgeExposure
        suppressEdge: pill.fluidJoined
        shadowEnabled: pill.surface !== "auth"
        captureExtra: pill.fluidCaptureExtra
        captureLeftExtra: pill.fluidCaptureLeftExtra
        restWidth: pill.restW
        running: pill.visible && pill.opacity > 0.005
        reduceMotion: Flags.reduceMotion
        breathe: Config.appearance.bodyBreath === true
        hour: pill.now.getHours() + pill.now.getMinutes() / 60
        mood: bodyEvents.mood
        music: Config.companion.reactToMusic && Players.playing && Cava.hasFrame && !Flags.reduceMotion
        beatEnvelope: Cava.hasFrame && Cava.values.length ? Math.max.apply(null, Cava.values.slice(0, 8)) : 0
        tintColor: MediaPalette.extracted ? MediaPalette.extracted : "transparent"
        tintOn: Players.playing && Players.isMusicSource
        bassLive: Config.appearance.waterReactsToMusic !== false && Config.companion.reactToMusic
            && Players.playing && Cava.hasFrame && !Flags.reduceMotion
        bassTarget: body.bassLive ? (Cava.bass || 0) : 0
        pointerInside: pill.hovered && Config.companion.followPointer
        pointer: Qt.point(pill.pointerX, pill.pointerY)
        resting: Config.appearance.personality && Flags.liquidSurfaces && !Flags.reduceTransparency
            && !pill.surfaceOpen && !pill.interactionOpen && !pill.layoutChanging
            && !pill.notifAnimating && !pill.fluidJoined && pill.fluidEdgeExposure > 0.999
            && pill.fluidCaptureExtra < 0.5 * pill.s && pill.fluidCaptureLeftExtra < 0.5 * pill.s
            && Math.abs(pill.height - pill.coreH) < 0.5 * pill.s
    }
    BodyEvents {
        id: bodyEvents
        active: Config.appearance.personality && body.running && !pill.companionBlocked
        systemEnabled: Config.companion.reactToSystem
        focusEnabled: Config.companion.reactToCode
        nightEnabled: Config.companion.reactAtNight
        focused: FocusSession.running || pill.companionCodeFocused
        idle: presence.isIdle && !Players.playing && !FocusSession.running
        hour: body.hour
    }
    readonly property bool bodyAudioWanted: body.exposure > 0.001 && body.running
        && Config.companion.reactToMusic && Players.playing && !Flags.reduceMotion
    property string bodyAudioConsumer: ""
    function updateBodyAudio() {
        if (bodyAudioConsumer) Cava.setConsumer(bodyAudioConsumer, false)
        bodyAudioConsumer = "body:" + pill.screenName
        Cava.setConsumer(bodyAudioConsumer, bodyAudioWanted)
    }
    onBodyAudioWantedChanged: updateBodyAudio()
    onScreenNameChanged: updateBodyAudio()
    Component.onDestruction: if (bodyAudioConsumer) Cava.setConsumer(bodyAudioConsumer, false)
    PillMaterial {
        id: material
        objectName: "pillMaterial"
        shaderActive: body.waterActive
        opacity: body.waterBody ? 1 : 1 - body.exposure
        visible: opacity > 0.001
        s: pill.s
        morphRadius: pill.morphRadius
        notifBreathRadius: pill.notifBreathRadius
        materialAwake: pill.materialAwake
        materialAccent: pill.materialAccent
        materialPulse: pill.materialPulse
        materialSweep: pill.materialSweep
        surface: pill.surface
        mode: pill.mode
        artUrl: contentAdapter.artUrl
        artworkTransition: sharedArtwork
        mediaPlaying: Players.live
        mediaSettled: pill.surfaceContentProgress > 0.95 && !pill.surfaceNotifSuspended
        notifBreathGlow: pill.notifBreathGlow
        notifState: pill.notifState
        suppressEdge: pill.fluidJoined
        edgeExposure: pill.fluidEdgeExposure
        captureExtra: pill.fluidCaptureExtra
        captureLeftExtra: pill.fluidCaptureLeftExtra
    }
    // ---- contenido (sobre el body) ----
    Item {
        id: content
        anchors.fill: parent
        z: 1
        opacity: pill.dropVeil
        visible: opacity > 0.001

        PillHeaderView {
            id: header
            anchors.fill: parent
            z: 3
            // Mientras dura el momento de corriente cede el reposo al rayo y al porcentaje.
            opacity: 1 - powerMoment.exposure
            s: pill.s
            coreH: pill.coreH
            layoutChanging: pill.layoutChanging
            restWidth: pill.restW
            restLeftWidth: pill.restLeftWidth
            restRightWidth: pill.restRightWidth
            surface: pill.surface
            surfaceOpen: pill.surfaceOpen
            launcherReturning: pill.launcherReturning
            launcherHeaderVisible: pill.launcherHeaderVisible
            launcherHeaderH: pill.launcherHeaderH
            surfaceReveal: pill.surfaceReveal
            morphCloseness: pill.morphCloseness
            restReturn: pill.morphRestReturn
            contentReveal: pill.surfaceContentProgress
            hasNotification: !!pill.activeNotif && !pill.notifDrop
            notifAnimating: pill.notifMorphing
            capsLockOn: statusAdapter.capsLockOn
            now: pill.now
            recordingPhase: !pill.recordingDetached && Recording.engaged ? (Recording.uncertain ? "unknown" : Recording.phase) : ""
            recordingCountdown: Recording.countdown
            activityText: !pill.recordingDetached && Recording.engaged ? Recording.uncertain ? I18n.tr("Grabador sin conexión")
                : Recording.phase === "countdown" ? I18n.tr("Preparando…")
                : Recording.phase === "starting" ? I18n.tr("Iniciando…")
                : Recording.phase === "stopping" ? I18n.tr("Finalizando…")
                : Recording.paused ? I18n.tr("Pausa · %1").arg(Recording.timeText) : I18n.tr("REC · %1").arg(Recording.timeText)
                : pill.activityNotice || (FocusSession.active
                ? (FocusSession.paused ? I18n.tr("Pausa · %1").arg(pill.focusTime) : pill.focusTime)
                : FocusSession.durationSeconds > 0 && FocusSession.remainingSeconds === 0 ? I18n.tr("Sesión completada") : "")
            hasMedia: contentAdapter.hasMedia
            artUrl: contentAdapter.artUrl
            hasProgress: contentAdapter.hasProgress
            progress: contentAdapter.progress
            title: contentAdapter.title
            artist: contentAdapter.artist
            onRequestCalendar: pill.requestSurface("calendar")
        }

        DevicePowerMoment {
            id: powerMoment
            z: 4
            s: pill.s
            coreH: pill.coreH
            shown: DeviceMoments.powerShown && !pill.surfaceOpen && !pill.activeNotif
            charging: DeviceMoments.powerPlugged
            percent: DeviceMoments.powerPercent
        }

        IslandNotification {
            contentOffset: pull.kind === "notification" ? pull.contentOffset : 0
            gestureActive: pull.candidate && pull.kind === "notification"
            anchors.centerIn: parent
            notification: pill.activeNotif
            s: pill.s
            pillWidth: pill.notifPillW
            pillHeight: pill.notifPillH
            closeness: pill.activeNotif && pill.notifMorphing
                && (pill.notifState === "expand" || pill.notifState === "hold") ? pill.morphCloseness : 0
            breath: pill.notifBreath
            holding: pill.notifMorphing && pill.notifState === "hold"
            iconResolved: pill._notifIconResolved
            iconSource: contentAdapter.notificationIcon
        }

        // ---- OSD overlay (brillo/volumen feedback) ----
        // Aparece 1.2s cuando cambia brillo o volumen: morph opacity + scale,
        // auto-dismiss timer. Visualmente: barra horizontal pequeña arriba de la
        // pill con glyph + valor. NO interfiere con notifs morph (prioridad de
        // visibilidad: notif > surface > OSD). Sólo se muestra si la pill NO está
        // morph'd en otra cosa (idle/reposo).
        OsdOverlay {
            id: osd
            anchors.top: parent.bottom
            anchors.topMargin: 6 * s   // bajo la pill
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // surface loader — el host inyecta s/open/morphCloseness/screenName al
        // item cargado (PillSurface los declara); sin esto opacidad=0 (bug).
        // Bug #8: el `requestClose.connect(...)` antiguo se acumulaba en
        // hot-reloads cuando el Loader reusaba un item (sin disconnect). Ahora
        // disconnectamos cualquier conexión previa antes de reconectar, y la
        // limpiamos vía `onItemChanged` cuando el item pasa a null (Qt Loader
        // NO expone `onUnloaded` — sólo `onLoaded` y `onItemChanged`).
        // Bug #15: si la surface falla al cargar (parse error, ruta inválida)
        // pill morph al tamaño correcto con cuerpo vacío y sin feedback →
        // ahora cerramos automáticamente vía onStatusChanged.
    // El contenido es hermano del fondo: necesita su propio recorte redondeado.
    PillSurfaceHost {
        id: surfaceHost
        artworkTransition: sharedArtwork
        gestureDriven: pull.active || morph.pullRevealing
        open: pill.surfaceOpen
        surface: pill.surface
        scaleFactor: pill.s
        morphCloseness: pill.surfaceContentProgress
        morphRadius: pill.morphRadius
        surfaceRadius: material.bodyRadius
        screenName: pill.screenName
        bgColor: pill.bgColor
        capsLockOn: statusAdapter.capsLockOn
        authContextWidth: header.restContentWidth + 56 * pill.s
        closing: pill.launcherClosing
        suspended: pill.surfaceNotifSuspended
        reveal: pill.surfaceReveal
        returning: pill.launcherReturning
        largeSurface: pill.lastSurfaceW * pill.lastSurfaceH > Motion.materializeLargeArea * pill.s * pill.s
        // Lay the content out at the surface's own size; a notification target is not one.
        layoutTargetWidth: pill.surfaceOpen && !pill.surfaceNotifSuspended ? geometry.surfaceTargetW : 0
        layoutTargetHeight: pill.surfaceOpen && !pill.surfaceNotifSuspended ? geometry.surfaceTargetH : 0
        onRequestClose: pill.requestClose()
        onRequestPage: (name) => pill.requestSurface(name)
        onFeedbackRequested: kind => pill.respond(kind)
    }
    }

    /** item de la surface activa (para que el host enrute teclado hacia él). */
    readonly property var surfaceItem: surfaceHost.loadedItem

    IslandStatusAdapter {
        id: statusAdapter
        s: pill.s
        fallbackVisible: pill.surfaceOpen || (pill.activeNotif && pill.notifMorphing)
        objectName: "pillStatusAdapter"
        onShowVolume: (progress, muted) => { header.showVolume(progress, muted); body.adjust("volume", progress, muted) }
        onShowMic: (progress, muted) => header.showMic(progress, muted)
        onShowBrightness: (progress) => { header.showBrightness(progress); body.adjust("brightness", progress, false) }
        onShowBattery: (percent, status) => {
            header.showBattery(percent, status)
            // El momento de corriente de DeviceMoments sustituye al aviso de enchufar.
            if (status === "charging" && pill.lastBatteryStatus.length && pill.lastBatteryStatus !== status
                && !DeviceMoments.ownsPowerTransition())
                pill.notice(I18n.tr("Cargando · %1%").arg(percent), "connected")
            pill.lastBatteryStatus = status
        }
        onFallbackVolumeRequested: (scaleFactor) => osd.showVolume(scaleFactor)
        onFallbackBrightnessRequested: (scaleFactor) => osd.showBrightness(scaleFactor)
    }

    // Public API used by external hosts.
    function showVolumeOSD() { statusAdapter.showVolumeOSD() }


    onActiveNotifChanged: {
        if (activeNotif && !heldNotification) pull.resetNotificationContent()
        if (activeNotif && activeNotif.urgency >= 2) {
            respond("attention")
        }
    }

    // Presence: the compositor reports idleness and the body quietens; nothing polls.
    IdleMonitor {
        id: presence
        enabled: Config.appearance.personality && pill.visible
        timeout: Config.companion.sleepAfterSeconds
        respectInhibitors: true
    }
    Connections {
        target: FocusSession
        function onFinished() { pill.notice(I18n.tr("Sesión completada"), "finished") }
    }
    Connections {
        target: Recording
        function onFeedbackRequested(kind) { pill.respond(kind) }
        function onSaved(path) { pill.notice(I18n.tr("Grabación guardada"), "finished") }
    }
    Connections {
        target: Config
        function onSaved() { if (pill.surfaceOpen) pill.respond("received") }
    }

    Component.onCompleted: {
        setupNotificationClocks()
        lastBatteryStatus = statusAdapter.batteryStatus
        // The initial load is complete; the next workspace change is real.
        wsReady = true
    }

    // OSD overlay (brillo/volumen/mic) → components/OsdOverlay.qml
}
