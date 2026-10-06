import QtQuick
import "Singletons"
import "components"

/**
 * Isla · Pill. El corazón: una píldora de vidrio oscura top-centre que morpha
 * (Behavior width/height/morphRadius · continuous retargeting). Molde
 * Ricelin Pill.qml — vidrio = gradiente cardTop→cardBot + borde 1px + sheen
 * (catch-light) + MultiEffect SÓLO sombra + inner-glow del acento que respira
 * (el "lo vivo respira" del waybar). Blur real = compositor (layerrule).
 *
 * Rest: reloj central (tap→calendar); la gota multimedia vive a su derecha
 * en FluidMediaCompanion. Surfaces via Loader. Wheel = volumen.
 */
Item {
    id: pill

    // ---- API pública (host svg) ----
    property real s: 1
    property string screenName: ""
    property color bgColor: "transparent"
    property string surface: ""            // nombre de surface activa
    property bool launcherClosing: false
    property int launcherClosePhase: 0
    property bool forcePinned: false
    property bool hovered: false
    // El motor Fluid puede extender visualmente el casquete derecho sin cambiar
    // el layout ni el contenido de reposo de la pill.
    property bool fluidJoined: false
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
        restHeight: IslandGeometry.restHeight
        surfaceSizes: pill.surfaceSize
        fallbackSurface: IslandGeometry.fallbackSurface
        mediaSurface: IslandGeometry.mediaSurface
        marginMd: Theme.marginMd
        fontSizeBodyLg: Theme.fontSizeBodyLg
        fontSizeLabel: Theme.fontSizeLabel
        fontScale: Flags.fontScale
        hasNotification: !!pill.activeNotif
        notifAnimating: pill.notifAnimating
        notifState: pill.notifState
        notifBreathRadius: pill.notifBreathRadius
        contentLoaded: !!pill.surfaceItem
        contentClosing: !!(pill.surfaceItem && pill.surfaceItem.closing)
        resultsVisible: !!(pill.surfaceItem && pill.surfaceItem.resultsVisible)
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
        || notifAnimating || fluidCaptureExtra > 0.5 * s || fluidCaptureLeftExtra > 0.5 * s
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
    onSurfaceChanged: if (surface.length > 0) awakenMaterial()

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
        workspaceAnimating: header.workspaceAnimating
        notifAnimating: pill.notifAnimating
        notifHolding: pill.notifAnimating && pill.notifState === "hold"
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
    property alias lastSurfaceW: morph.lastSurfaceW
    property alias lastSurfaceH: morph.lastSurfaceH
    readonly property real restW: geometry.restW
    readonly property real surfaceGrowth: morph.surfaceGrowth
    readonly property real surfaceContentProgress: morph.contentProgress

    NotificationChoreography {
        id: notificationMotion
        blocked: pill.surface === "auth"
        popup: pill.notificationsEnabled ? Notifs.activePopup : null
        surfaceOpen: pill.surfaceOpen
        collapseDuration: Motion.notifCollapse + 50
        expandDuration: Motion.notifExpand + 80
        holdDuration: Math.round((Motion.notifHoldMin + Motion.notifHoldMax) / 2)
        restoreDuration: Motion.morph + 70
        onAdvanceRequested: { if (pill.notificationsEnabled) Notifs.advancePopup() }
    }
    readonly property string notifState: notificationMotion.notifState

    property alias notifBreath: morph.breath
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

    PillMaterial {
        id: material
        s: pill.s
        morphRadius: pill.morphRadius
        notifBreathRadius: pill.notifBreathRadius
        materialAwake: pill.materialAwake
        materialAccent: pill.materialAccent
        materialPulse: pill.materialPulse
        materialSweep: pill.materialSweep
        surface: pill.surface
        mode: pill.mode
        notifBreathGlow: pill.notifBreathGlow
        notifState: pill.notifState
        suppressEdge: pill.fluidJoined
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
            surface: pill.surface
            surfaceOpen: pill.surfaceOpen
            launcherReturning: pill.launcherReturning
            launcherHeaderVisible: pill.launcherHeaderVisible
            launcherHeaderH: pill.launcherHeaderH
            surfaceReveal: pill.surfaceReveal
            morphCloseness: pill.morphCloseness
            hasNotification: !!pill.activeNotif
            notifAnimating: pill.notifAnimating
            capsLockOn: statusAdapter.capsLockOn
            now: pill.now
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
            closeness: pill.activeNotif && pill.notifAnimating
                && (pill.notifState === "expand" || pill.notifState === "hold") ? pill.morphCloseness : 0
            breath: pill.notifBreath
            holding: pill.notifAnimating && pill.notifState === "hold"
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
        reveal: pill.launcherReturning ? 0 : pill.surfaceReveal
        onRequestClose: pill.requestClose()
        onRequestPage: (name) => pill.requestSurface(name)
    }
    }

    /** item de la surface activa (para que el host enrute teclado hacia él). */
    readonly property var surfaceItem: surfaceHost.loadedItem

    IslandStatusAdapter {
        id: statusAdapter
        s: pill.s
        fallbackVisible: pill.surfaceOpen || (pill.activeNotif && pill.notifAnimating)
        onShowVolume: (progress, muted) => header.showVolume(progress, muted)
        onShowMic: (progress, muted) => header.showMic(progress, muted)
        onShowBrightness: (progress) => header.showBrightness(progress)
        onShowBattery: (percent, status) => header.showBattery(percent, status)
        onFallbackVolumeRequested: (scaleFactor) => osd.showVolume(scaleFactor)
        onFallbackBrightnessRequested: (scaleFactor) => osd.showBrightness(scaleFactor)
    }

    // Public API used by wheel and external hosts.
    function showVolumeOSD() { statusAdapter.showVolumeOSD() }

    Component.onCompleted: {
        // The initial load is complete; the next workspace change is real.
        wsReady = true
    }

    // wheel → volumen inline (no abre surface)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            statusAdapter.adjustVolume(wheel.angleDelta.y > 0 ? 0.04 : -0.04)
        }
    }

    // OSD overlay (brillo/volumen/mic) → components/OsdOverlay.qml
}
