import QtQuick
import Quickshell.Wayland
import "Singletons"
import "components"
import "body"

/** Pill principal: expone estado al shell y coordina geometría, surfaces y morphs de notificación.
 * Inspirada en Ricelin Pill.qml.
 */
Item {
    id: pill

    // ---- API pública (host svg) ----
    // Cuerpo replaces the face; retain legacy wiring for the later cleanup.
    readonly property bool legacyCompanionEnabled: false
    readonly property alias bodyPresentation: body
    property real s: 1
    property bool layoutChanging: false
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
    property bool forcePinned: false
    property real companionWorkspaceLook: 0
    property bool companionCodeFocused: false
    property bool companionMusicVisible: false
    property real companionSeek: 0.5
    property real companionBeat: 0
    property bool companionBlocked: false
    property bool hovered: false
    property bool interactionOpen: surfaceOpen
    readonly property bool receiving: material.receiving
    property real pointerX: width / 2
    property real pointerY: height / 2
    property string responseMood: "rest"
    property string activityNotice: ""
    property string lastBatteryStatus: ""
    readonly property string focusTime: Math.floor(FocusSession.remainingSeconds / 60)
        + ":" + String(FocusSession.remainingSeconds % 60).padStart(2, "0")
    function respond(kind) {
        if (!visible || surface === "auth" || layoutChanging) return
        responseMood = kind
        bodyEvents.react(kind)
        expressionHold.restart()
        if (kind !== "paused" && kind !== "cancel") material.receive(0.55)
    }
    function notice(text, kind) {
        if (!visible || surface === "auth" || layoutChanging) return
        activityNotice = text
        noticeHold.restart()
        respond(kind)
    }
    Timer { id: expressionHold; interval: 1600; onTriggered: pill.responseMood = "rest" }
    Timer { id: noticeHold; interval: 3200; onTriggered: pill.activityNotice = "" }
    onVisibleChanged: if (!visible) {
        expressionHold.stop(); noticeHold.stop()
        responseMood = "rest"; activityNotice = ""
        material.settleReception()
    }
    // El motor Fluid puede extender visualmente el casquete derecho sin cambiar
    // el layout ni el contenido de reposo de la pill.
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

    NotificationChoreography {
        id: notificationMotion
        objectName: "pillNotificationMotion"
        blocked: pill.surface === "auth"
        deferInformational: true
        suspendSurface: !pill.notifDrop
        popup: pill.notificationsEnabled ? Notifs.activePopup : null
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
        sceneOrigin: pill.parent ? pill.parent.mapToItem(null, pill.x, pill.y) : Qt.point(pill.x, pill.y)
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

        PillHeaderView {
            id: header
            anchors.fill: parent
            z: 3
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
            companionContext: companionBehavior
            companionEnabled: pill.legacyCompanionEnabled
            companionAsleep: presence.isIdle
            companionSleepy: Config.companion.reactAtNight && companionBehavior.night
            companionListening: Config.companion.reactToMusic && Players.playing
            recordingPhase: !pill.recordingDetached && Recording.engaged ? (Recording.uncertain ? "unknown" : Recording.phase) : ""
            recordingCountdown: Recording.countdown
            activityText: !pill.recordingDetached && Recording.engaged ? Recording.uncertain ? qsTr("Grabador sin conexión")
                : Recording.phase === "countdown" ? qsTr("Preparando…")
                : Recording.phase === "starting" ? qsTr("Iniciando…")
                : Recording.phase === "stopping" ? qsTr("Finalizando…")
                : Recording.paused ? qsTr("Pausa · %1").arg(Recording.timeText) : qsTr("REC · %1").arg(Recording.timeText)
                : pill.activityNotice || (FocusSession.active
                ? (FocusSession.paused ? qsTr("Pausa · %1").arg(pill.focusTime) : pill.focusTime)
                : FocusSession.durationSeconds > 0 && FocusSession.remainingSeconds === 0 ? qsTr("Sesión completada") : "")
            activityMood: pill.faceMood
            lookX: pill.faceLookX
            lookY: pill.faceLookY
            hasMedia: contentAdapter.hasMedia
            artUrl: contentAdapter.artUrl
            hasProgress: contentAdapter.hasProgress
            progress: contentAdapter.progress
            title: contentAdapter.title
            artist: contentAdapter.artist
            onRequestCalendar: pill.requestSurface("calendar")
        }

        IslandNotification {
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
        onRequestClose: pill.requestClose()
        onRequestPage: (name) => pill.requestSurface(name)
        onFeedbackRequested: kind => pill.respond(kind)
    }

        // Iris travels to the corner of an open surface and back. It is the same
        // face (same behaviour context) as the one in the header; the header face
        // fades as this one takes over, so there is never a second personality.
        IslandCompanion {
            id: perch
            objectName: "irisPerch"
            z: 6
            s: pill.s
            context: companionBehavior
            mood: pill.faceMood
            asleep: presence.isIdle
            sleepy: Config.companion.reactAtNight && companionBehavior.night
            listening: Config.companion.reactToMusic && Players.playing
            lookX: pill.faceLookX
            lookY: pill.faceLookY
            opacity: pill.perchTravel
            visible: pill.perchShown
            x: pill.perchOrigin.x + (pill.perchTarget.x - pill.perchOrigin.x) * pill.perchTravel - width / 2
            y: pill.perchOrigin.y + (pill.perchTarget.y - pill.perchOrigin.y) * pill.perchTravel - height / 2
        }
    }

    /** item de la surface activa (para que el host enrute teclado hacia él). */
    readonly property var surfaceItem: surfaceHost.loadedItem

    IslandStatusAdapter {
        id: statusAdapter
        s: pill.s
        fallbackVisible: pill.surfaceOpen || (pill.activeNotif && pill.notifMorphing)
        onShowVolume: (progress, muted) => header.showVolume(progress, muted)
        onShowMic: (progress, muted) => header.showMic(progress, muted)
        onShowBrightness: (progress) => header.showBrightness(progress)
        onShowBattery: (percent, status) => {
            header.showBattery(percent, status)
            if (status === "charging" && pill.lastBatteryStatus.length && pill.lastBatteryStatus !== status)
                pill.notice(qsTr("Cargando · %1%").arg(percent), "connected")
            pill.lastBatteryStatus = status
            companionBehavior.noteBattery(percent, status)
        }
        onFallbackVolumeRequested: (scaleFactor) => osd.showVolume(scaleFactor)
        onFallbackBrightnessRequested: (scaleFactor) => osd.showBrightness(scaleFactor)
    }

    // Public API used by external hosts.
    function showVolumeOSD() { statusAdapter.showVolumeOSD() }

    // ---- Iris: shared face state, perch and attention ----
    readonly property string faceMood: responseMood !== "rest" ? responseMood
        : FocusSession.paused ? "paused" : FocusSession.running ? "working" : "rest"
    readonly property real faceLookX: companionBehavior.lookX
    readonly property real faceLookY: responseMood === "attention" ? 0.8 : companionBehavior.lookY

    // The perch: the face leaves the header for the corner of surfaces that hide
    // the header. The launcher and the auth prompt keep it in their own header.
    // With reduced motion it does not travel (the header face simply fades).
    readonly property bool perchWanted: pill.legacyCompanionEnabled && surfaceOpen && !launcherReturning
        && surface !== "launcher" && surface !== "auth" && !layoutChanging && !Flags.reduceMotion
        && !surfaceNotifSuspended && !(activeNotif && notifMorphing)
    property real perchTravel: perchWanted ? 1 : 0
    // SmoothedAnimation keeps the velocity when the target flips mid-way, as the pill's own geometry does.
    Behavior on perchTravel {
        enabled: !Flags.reduceMotion
        SmoothedAnimation { duration: Motion.standardLarge; velocity: -1 }
    }
    readonly property bool perchShown: perchTravel > 0.01
    readonly property bool faceVisible: header.restOpacity > 0.01 || perchShown
    // Origin: where the header face is now (it follows the header, so the way back
    // ends exactly on it, whatever the scale). Target: top right, on the inset the
    // launcher divider uses, at the middle of the scaled rest strip (coreH).
    readonly property point perchOrigin: header.faceSlot
    readonly property point perchTarget: Qt.point(width - 22 * s - 15 * s, coreH / 2)
    // Where the face looks from: the perch while it is out, the header otherwise.
    readonly property point faceCenter: perchShown ? Qt.point(perch.x + perch.width / 2, perch.y + perch.height / 2) : header.faceSlot

    // Attention: a surface with one point that matters publishes it and Iris
    // looks there. Nothing is evaluated unless the surface declares it active.
    // The surface open in the pill, or else the one the host injects (the media card
    // of the split layout lives outside the pill).
    property var attentionItem: null
    readonly property var attentionSource: surfaceItem ? surfaceItem : attentionItem
    readonly property bool attentionActive: !!attentionSource && attentionSource.focusActive === true && faceVisible
    readonly property point attentionVector: {
        if (!attentionActive) return Qt.point(0, 0)
        const p = attentionSource.mapToItem(pill, attentionSource.focusPoint.x, attentionSource.focusPoint.y)
        const range = 120 * s
        return Qt.point(Math.max(-1, Math.min(1, (p.x - faceCenter.x) / range)),
                        Math.max(-1, Math.min(1, (p.y - faceCenter.y) / range)))
    }

    CompanionBehavior {
        id: companionBehavior
        objectName: "companionBehavior"
        active: pill.legacyCompanionEnabled && pill.visible && pill.faceVisible && !pill.layoutChanging
        reduced: Flags.reduceMotion
        asleep: presence.isIdle
        options: Config.companion
        blocked: pill.companionBlocked || pill.surface === "launcher" || pill.surface === "auth" || Recording.engaged || !!pill.activeNotif
        night: pill.now.getHours() >= 23 || pill.now.getHours() < 6
        codeFocused: pill.companionCodeFocused
        workspaceLook: pill.companionWorkspaceLook
        musicVisible: pill.companionMusicVisible
        playing: Players.playing
        seek: pill.companionSeek
        beat: pill.companionBeat
        memoryPlayfulness: IrisMemory.playfulness
        recording: Recording.engaged
        greetingPending: IrisMemory.greetingKind !== ""
        onInteracted: IrisMemory.noteInteraction()
        onVisited: kind => IrisMemory.noteSighting(kind)
        onGreetingRequested: greet(IrisMemory.consumeGreeting())
        focusActive: pill.attentionActive
        focusX: pill.attentionVector.x
        focusY: pill.attentionVector.y
        pointerInside: pill.hovered
        pointerX: (pill.pointerX / Math.max(1, pill.width) - 0.5) * 2
        pointerY: (pill.pointerY / Math.max(1, pill.height) - 0.5) * 2
    }
    onActiveNotifChanged: {
        if (activeNotif && activeNotif.urgency >= 2) {
            companionBehavior.gestureRequested("curious")
            companionBehavior.react("surprised", "defer")
            respond("attention")
        }
    }

    // The companion's sense of presence: it falls asleep when the user leaves
    // and greets them on return. The compositor reports idleness; nothing polls.
    IdleMonitor {
        id: presence
        enabled: Config.appearance.personality && pill.visible
        timeout: Config.companion.sleepAfterSeconds
        respectInhibitors: true
    }
    // The first activity of the day is noted once the user is present, at startup
    // or on waking; IrisMemory ignores every later call that day.
    readonly property bool irisPresent: Config.loaded && pill.legacyCompanionEnabled && !presence.isIdle
    onIrisPresentChanged: if (irisPresent) IrisMemory.noteActivity()

    Connections {
        target: FocusSession
        function onFinished() { pill.notice(qsTr("Sesión completada"), "finished") }
    }
    Connections {
        target: Recording
        function onFeedbackRequested(kind) { pill.respond(kind) }
        function onActiveChanged() { if (!Recording.active && !Recording.uncertain) Qt.callLater(() => companionBehavior.react("relief")) }
        function onSaved(path) { pill.notice(qsTr("Grabación guardada"), "finished") }
    }
    // The prompt's own verdict on the password; the face sits beside it on this surface.
    Connections {
        target: pill.surfaceItem
        ignoreUnknownSignals: true
        function onHasErrorChanged() { if (pill.surface === "auth" && pill.surfaceItem.hasError) companionBehavior.react("no", "surface") }
        function onSuccessStateChanged() { if (pill.surface === "auth" && pill.surfaceItem.successState) companionBehavior.react("wink", "surface") }
    }
    // A discrete success on the open surface (an app launched, a wallpaper applied).
    // Wink is the existing approval gesture; it bypasses `blocked` like auth's.
    Connections {
        target: pill.surfaceItem
        ignoreUnknownSignals: true
        function onApproved() { if (pill.surface !== "auth") companionBehavior.react("wink", "surface") }
    }
    Connections {
        target: Config
        function onSaved() { if (pill.surfaceOpen) pill.respond("received") }
    }

    Component.onCompleted: {
        lastBatteryStatus = statusAdapter.batteryStatus
        if (irisPresent) IrisMemory.noteActivity()
        // The initial load is complete; the next workspace change is real.
        wsReady = true
    }

    // OSD overlay (brillo/volumen/mic) → components/OsdOverlay.qml
}
