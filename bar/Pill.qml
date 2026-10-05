import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
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

    // ---- metrics ----
    readonly property real coreH: IslandGeometry.restHeight * s
    readonly property real padH: 18 * s

    // ---- notification morph (Dynamic Island style) ----
    // activeNotif = NotifData mostrandose (o null). La pill se morph->circle->notif->hold->circle->rest
    property bool notificationsEnabled: true
    readonly property var activeNotif: notificationMotion.activeNotif
    // ¿resolveIcon encontró un icono real? (false → mostrar genericBadge con glyph fallback)
    readonly property bool _notifIconResolved: activeNotif
        && pill.resolveIcon(activeNotif.appIcon, activeNotif.appName).length > 0
    readonly property bool notifAnimating: notificationMotion.notifAnimating
    // La surface abierta conserva su estado durante una notificación, pero su
    // árbol visual se retira antes del morph para que no se deforme junto al
    // contenido de la notificación. Se revela de nuevo cuando la pill ya volvió
    // a su geometría estable.
    readonly property bool surfaceNotifSuspended: notificationMotion.surfaceNotifSuspended
    readonly property real surfaceReveal: notificationMotion.surfaceReveal
    // target del círculo intermedio (más pequeño que la pill en reposo)
    readonly property real notifCircleD: coreH * 0.55
    // target del pill de notif (ancho fijo ~380*s, alto compacto)
    readonly property real notifPillW: 380 * s
    readonly property real notifPillH: 72 * s

    readonly property bool surfaceOpen: surface.length > 0
    readonly property bool launcherReturning: surface === "launcher"
        && launcherClosing && launcherClosePhase === 2
    readonly property string mode: surfaceOpen && !launcherReturning ? surface : (hovered ? "hover" : "rest")
    readonly property bool materialAwake: hovered || (surfaceOpen && !launcherReturning)
        || notifAnimating || fluidCaptureExtra > 0.5 * s || fluidCaptureLeftExtra > 0.5 * s
    readonly property color materialAccent: surface === "wallpaper" && surfaceItem && surfaceItem.previewAccent
        ? surfaceItem.previewAccent : Theme.accent
    property int materialEpoch: 0
    property real materialSweep: -0.55
    property real materialPulse: 0

    function awakenMaterial() {
        if (Flags.reduceMotion) return
        materialEpoch++
        materialSweepAnim.restart()
        materialPulseAnim.restart()
    }

    onSurfaceChanged: if (surfaceOpen) awakenMaterial()

    Connections {
        target: Flags
        function onReduceMotionChanged() {
            if (!Flags.reduceMotion) return
            materialSweepAnim.stop()
            materialPulseAnim.stop()
            pill.materialSweep = -0.55
            pill.materialPulse = 0
        }
    }

    SequentialAnimation {
        id: materialSweepAnim

        PropertyAction { target: pill; property: "materialSweep"; value: -0.55 }
        NumberAnimation {
            target: pill
            property: "materialSweep"
            to: 1.28
            duration: Motion.shapeshift
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.emphasizedDecelCurve
        }
    }

    SequentialAnimation {
        id: materialPulseAnim

        PropertyAction { target: pill; property: "materialPulse"; value: 0 }
        NumberAnimation {
            target: pill
            property: "materialPulse"
            to: 1
            duration: Motion.standard
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: pill
            property: "materialPulse"
            to: 0
            duration: Motion.emphasizedLarge
            easing.type: Easing.InCubic
        }
    }

    // ---- tamaños-target por surface (*s) ----
    readonly property var surfaceSize: IslandGeometry.surfaceSizes
    readonly property var sizeFor: surfaceOpen && surfaceSize[pill.surface]
        ? surfaceSize[pill.surface] : IslandGeometry.fallbackSurface
    readonly property real authInputW: 400 * s
    // El buscador queda anclado por su propia altura. Cuando aparecen resultados
    // la superficie crece hacia abajo, sin recentrar el campo ni desplazarlo.
    readonly property real launcherSearchH: (44 + Theme.marginMd * 2) * s
    readonly property real launcherHeaderH: 78 * s
    readonly property bool launcherHeaderVisible: surface === "launcher" && !launcherClosing
    // target prioriza morph de notif (si está activo) sobre surfaces y rest.
    readonly property real targetW: activeNotif && notifAnimating && !isNaN(_notifTargetW) ? _notifTargetW
                                     : launcherReturning ? restContent.implicitWidth + padH * 2
                                     : surface === "auth" ? restContent.implicitWidth + authInputW + 56 * s
                                     : surfaceOpen ? sizeFor.width * s : restContent.implicitWidth + padH * 2
    readonly property real targetH: {
        if (activeNotif && notifAnimating && !isNaN(_notifTargetH)) return _notifTargetH
        if (launcherReturning) return coreH
        if (surface === "launcher" && launcherClosing) return launcherSearchH
        if (!surfaceOpen) return coreH
        if (surface === "auth") return Math.max(82, Math.max(44, Theme.fontSizeBodyLg + Flags.fontScale + 20)
            + 3 + Math.max(18, Theme.fontSizeLabel + 6) + 16) * s
        if (surface === "launcher") return launcherH
        if (surface === "media") return mediaH
        return sizeFor.height * s
    }
    readonly property real launcherH: {
        var sb = 44 * s                  // searchBox
        var headerH = launcherHeaderH    // cabecera: reloj + media reutilizados
        var padTop = 16 * s              // mTop del surface
        var padBot = 20 * s              // mBottom
        // si la surface aún no cargó (morph inicial) mide la search box, NO el
        // tamaño máximo: si no, el pill arranca a 460px y re-encoge al cargar,
        // arrastrando la search bar (se ve "desubicada" durante el morph).
        if (!surfaceItem) return headerH + sb + padTop + padBot
        // patrón caelestia: pill mide al contenido real —
        //   searchBox + (count * itemHeight + count * spacing) capped al máximo.
        // Esto da el efecto "crece con cada resultado" (igual que caelestia usa
        // appList.implicitHeight = (itemHeight + spacing) * Math.min(maxShown, count)).
        if (surfaceItem.closing || !surfaceItem.resultsVisible) {
            var calcH = surfaceItem.showCalculator ? (44 * s + 10 * s) : 0
            return headerH + sb + padTop + padBot + calcH
        }
        // lista — limitada al max definido por sizeFor.height
        var itemH = 72 * s               // AppItem.implicitHeight
        var sp = 4 * s                   // listView.spacing
        var count = Math.min(surfaceItem.resultsCount || 0, surfaceItem.maxVisibleResults || 6)
        var listH = count > 0 ? (itemH * count + sp * (count - 1)) : 0
        var dividerH = 1 * s
        var footerH = 34 * s                    // hintRow aproximado
        var maxListH = sizeFor.height * s - headerH - sb - padTop - padBot - dividerH - footerH
        var cappedListH = Math.max(0, Math.min(maxListH, listH))
        return headerH + sb + padTop + padBot + (12 * s /* Col spacing */ ) + dividerH
            + cappedListH + footerH
    }
    // Media surface: geometría horizontal premium; crece solo si el álbum
    // necesita una línea adicional.
    readonly property real mediaH: {
        if (!surfaceItem) return IslandGeometry.mediaSurface.height * s
        var base = IslandGeometry.mediaSurface.height * s
        if (surfaceItem.albumDistinct !== undefined
                ? surfaceItem.albumDistinct
                : (surfaceItem.album && surfaceItem.album.length > 0)) base += 16 * s
        return base
    }
    readonly property real radiusRest: coreH / 2
    // El radio abierto se adapta al panel: superficies anchas (wallpaper) usan
    // un radio generoso para que las esquinas NUNCA se vean filosas.
    readonly property real radiusOpen: Math.min(Math.max(18 * s, targetW * 0.055), Math.max(2, targetH / 2 - 2 * s))
    readonly property real targetRadius: activeNotif && notifAnimating && !isNaN(_notifTargetRadius) ? _notifTargetRadius
                                          : launcherReturning ? radiusRest
                                          : surface === "launcher" && targetH <= launcherSearchH ? targetH / 2
                                          : surface === "auth" ? targetH / 2 : surfaceOpen ? radiusOpen : radiusRest

    width: Math.min(targetW, 2000 * s)
    height: Math.min(targetH, 2000 * s)
    property real morphRadius: targetRadius
    transformOrigin: Item.Top
    // Hover is expressed by PillMaterial; geometry and all hit targets stay fixed.

    // Retargets conserve velocity, including reversals during a morph.
    readonly property int _morphDuration: notifAnimating ? Motion.notifCollapse : Motion.morph
    Behavior on width {
        // Workspace reveal owns its width: do not animate the moving target twice.
        enabled: !Flags.reduceMotion && (!restStatus.workspaceAnimating || pill.surfaceOpen || pill.notifAnimating)
        SmoothedAnimation { duration: pill._morphDuration; velocity: -1 }
    }
    Behavior on height {
        enabled: !Flags.reduceMotion
        SmoothedAnimation { duration: pill._morphDuration; velocity: -1 }
    }
    Behavior on morphRadius {
        enabled: !Flags.reduceMotion
        SmoothedAnimation { duration: pill._morphDuration; velocity: -1 }
    }

    readonly property real morphCloseness: {
        var dw = Math.max(0.0001, targetW)
        var dh = Math.max(0.0001, targetH)
        var d = Math.max(Math.abs(width - targetW) / dw, Math.abs(height - targetH) / dh)
        return Math.max(0, 1 - d)
    }
    // El contenido sigue el tamaño real del vidrio, también al invertir el morph.
    // Conservar el último destino evita que el cierre dependa del target de reposo.
    property real lastSurfaceW: 0
    property real lastSurfaceH: 0
    onTargetWChanged: if (surfaceOpen) lastSurfaceW = targetW
    onTargetHChanged: if (surfaceOpen) lastSurfaceH = targetH
    readonly property real restW: restContent.implicitWidth + padH * 2
    readonly property real surfaceGrowth: Math.max(0, Math.min(1, Math.min(
        (width - restW) / Math.max(1, lastSurfaceW - restW),
        (height - coreH) / Math.max(1, lastSurfaceH - coreH))))
    readonly property real surfaceContentProgress: Math.max(0, Math.min(1,
        (surfaceGrowth - 0.45) / 0.35))

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

    // ---- Breathing durante hold (sutil pulse del circle/pill) ----
    // Se activa solo en estado "hold", da vida a la isla (estilo iOS Dynamic Island)
    property real notifBreath: 0
    SequentialAnimation on notifBreath {
        id: notifBreathAnim
        running: !Flags.reduceMotion && pill.notifAnimating && pill.notifState === "hold"
        loops: Animation.Infinite
        // ease-in-out para feel Apple-like: suavidad sinusoidal
        NumberAnimation { from: 0; to: 1; duration: 1400; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0; duration: 1400; easing.type: Easing.InOutSine }
    }
    // radius extra durante hold: circle pulse sutil (±2px)
    readonly property real notifBreathRadius: (notifAnimating && notifState === "hold") ? notifBreath * 2 * s : 0
    // glow intensity durante hold (más prominente)
    readonly property real notifBreathGlow: (notifAnimating && notifState === "hold") ? 0.12 + notifBreath * 0.18 : 0

    //Cuando la pill está en modo notif, el target se computa según notifState.
    // Esto reescribe notifTargetW/H/Radius (declarados arriba como readonly con
    // función IIFE que leía width — los hacemos bindings reactivos a notifState).
    readonly property real _notifTargetW: {
        if (!activeNotif) return NaN
        if (notifAnimating && (notifState === "collapse-in" || notifState === "collapse-out")) return notifCircleD
        if (notifAnimating && (notifState === "expand" || notifState === "hold")) return notifPillW
        if (notifAnimating && notifState === "return") return Math.max(restContent.implicitWidth, 120 * s) + padH * 2
        return NaN
    }
    readonly property real _notifTargetH: {
        if (!activeNotif) return NaN
        if (notifAnimating && (notifState === "collapse-in" || notifState === "collapse-out")) return notifCircleD
        if (notifAnimating && (notifState === "expand" || notifState === "hold")) return notifPillH
        if (notifAnimating && notifState === "return") return coreH
        return NaN
    }
    readonly property real _notifTargetRadius: {
        if (!activeNotif) return NaN
        if (notifAnimating && (notifState === "collapse-in" || notifState === "collapse-out")) return notifCircleD / 2
        if (notifAnimating && (notifState === "expand" || notifState === "hold")) return Math.min(18 * s, notifPillH / 2 - 2 * s) + notifBreathRadius
        if (notifAnimating && notifState === "return") return coreH / 2
        return NaN
    }

    // ---- reloj ----
    // El reloj es always-on: con clockSeconds=false el texto (RichText) sólo
    // cambia al virar el minuto. No reasignamos `now` cada segundo (eso releía /
    // re-parseaba el RichText ~60×/min en reposo). Sólo lo movemos cuando la
    // unidad visible del formato cambia — cero cambio perceptible (refresca ≤
    // 1 s tras el viraje) y bajamos el trabajo always-on a ~1 update/min.
    property date now: new Date()
    Timer {
        interval: 1000; repeat: true; running: true
        onTriggered: {
            var d = new Date()
            if (Flags.clockSeconds) { pill.now = d; return }
            if (d.getMinutes() !== pill.now.getMinutes() || d.getHours() !== pill.now.getHours())
                pill.now = d
        }
    }

    // ---- workspaces (API Hyprland, defensive) ----
    readonly property string activeWsName: {
        var mons = Hyprland.monitors.values
        for (var i = 0; i < mons.length; i++)
            if (mons[i].name === pill.screenName)
                return mons[i].activeWorkspace ? mons[i].activeWorkspace.name : "1"
        return "1"
    }
    // Rueda de workspace a la izquierda; el indicador controla su expansión.
    // El primer evento del monitor se absorbe para evitar un flash al cargar.
    property bool wsReady: false
    onActiveWsNameChanged: {
        if (!pill.wsReady) { pill.wsReady = true; return }
        var a = parseInt(pill.activeWsName)
        if (a >= 1) restStatus.flashWorkspace(a)
    }

    /** escapa & < > para RichText: título/artista pueden llevar '&' (Spotify,
     *  "A & B") y romperían el <span> del marquee. */
    function esc(s) {
        // HTML-entitiza & < > para RichText. Construidos como concat para que el
        // entity NO se colapse a su literal. Orden: escapa & primero.
        var amp = "&" + "amp;", lt = "&" + "lt;", gt = "&" + "gt;"
        return ("" + s).replace(/&/g, amp).replace(/</g, lt).replace(/>/g, gt)
    }

    function resolveIcon(appIcon, appName) {
        if (appIcon && appIcon.length) {
            var raw = appIcon
            if (!Quickshell.iconPath(raw, true)) {
                var base = raw.replace(/\.desktop$/, "")
                if (base !== raw) raw = base
            }
            if (Quickshell.iconPath(raw, true)) return Quickshell.iconPath(raw)
        }
        if (appName && appName.length) {
            var entry = DesktopEntries.heuristicLookup(appName)
            if (entry && entry.icon && entry.icon.length) {
                var p = Quickshell.iconPath(entry.icon, true)
                if (p) return p
            }
        }
        return ""
    }


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

        // El reloj permanece como único contenido de reposo de la pill.
        Row {
            id: restContent
            height: pill.coreH
            y: pill.launcherHeaderVisible
                ? (pill.launcherHeaderH - height) / 2
                : (parent.height - height) / 2
            x: pill.surface === "auth" ? 18 * pill.s
                : pill.launcherHeaderVisible && Players.has
                    ? parent.width - implicitWidth - 26 * pill.s
                    : (parent.width - implicitWidth) / 2
            // spacing 0 a propósito: el gap wsFlash↔reloj vive DENTRO del chip
            // (chipW, que anima y arrastra pill.width vía este implicitWidth). Un
            // spacing >0 haría que el Row sumara el gap al instante al flipear
            // wsFlash.visible (opacity>0.01) — layout del Row NO se anima → el
            // reloj saltaría ~7px al abrir/cerrar el flash (tirón). Con spacing 0
            // el reloj se desliza PURAMENTE siguiendo el width animado del chip.
            spacing: 0
            z: 3
            opacity: pill.launcherHeaderVisible ? 1 : pill.surface === "auth" ? 1
                : ((pill.surfaceOpen && !pill.launcherReturning) || (pill.activeNotif && pill.notifAnimating)) ? 0
                : Math.pow(pill.morphCloseness, 1.2)
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: pill.surfaceOpen ? Motion.fast : Motion.standard; easing.type: Motion.easeStandard } }

            IslandRestStatus {
                id: restStatus
                s: pill.s
                coreH: pill.coreH
                capsLockOn: pill.capsLockOn
                now: pill.now
                onRequestCalendar: pill.requestSurface("calendar")
            }
        }

        Row {
            x: 26 * pill.s
            y: (pill.launcherHeaderH - height) / 2
            height: 42 * pill.s
            spacing: 12 * pill.s
            opacity: pill.launcherHeaderVisible && Players.has ? pill.surfaceReveal : 0
            visible: opacity > 0.01
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }

            IslandMediaSummary {
                s: pill.s
                coverDiameter: 42 * pill.s
                textWidth: Math.max(0, pill.width - restContent.implicitWidth - 126 * pill.s)
                spacing: 12 * pill.s
                metadataSpacing: 3 * pill.s
                titlePixelSize: Theme.fontSizeBodyLg * pill.s
                artistPixelSize: Theme.fontSizeBody * pill.s
                artUrl: Players.artUrl
                hasProgress: Players.active && Players.active.length > 0
                progress: hasProgress ? Math.max(0, Math.min(1,
                    Players.active.position / Players.active.length)) : 0
                title: Players.title
                artist: Players.artist
                showArtist: artist.length > 0
            }
        }

        // El divisor conserva el reloj como cabecera del launcher.
        Rectangle {
            id: launcherHeaderDivider
            x: 22 * pill.s
            y: pill.launcherHeaderH
            width: Math.max(0, parent.width - 44 * pill.s)
            height: 1 * pill.s
            color: Theme.sheen
            opacity: pill.launcherHeaderVisible ? 0.72 : 0
            visible: opacity > 0.01
            z: 2
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
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
            iconSource: pill.activeNotif ? pill.resolveIcon(pill.activeNotif.appIcon, pill.activeNotif.appName) : ""
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
        capsLockOn: pill.capsLockOn
        authContextWidth: restContent.implicitWidth + 56 * pill.s
        closing: pill.launcherClosing
        suspended: pill.surfaceNotifSuspended
        reveal: pill.launcherReturning ? 0 : pill.surfaceReveal
        onRequestClose: pill.requestClose()
        onRequestPage: (name) => pill.requestSurface(name)
    }
    }

    /** item de la surface activa (para que el host enrute teclado hacia él). */
    readonly property var surfaceItem: surfaceHost.loadedItem

    // ---- OSD unificado: morph de la pill (volChip) + overlay flotante ----
    // showVolumeOSD/showBrightnessOSD activan el chip interno (la pill morfea
    // horizontalmente como Dynamic Island). El overlay externo solo se muestra
    // como respaldo cuando la pill está en modo surface o notif morph (restContent
    // oculto → volChip no visible).
    // Incluye debounce de 16ms (1 frame) para coalescer cambios rápidos.
    property real _osdPendingProgress: 0
    property bool _osdPendingMuted: false
    property string _osdPendingKind: ""    // "volume" | "mic" | "brightness"
    property bool _osdPending: false
    Timer {
        id: osdDebounce
        interval: 16
        onTriggered: {
            if (!pill._osdPending) return
            pill._osdPending = false
            switch (pill._osdPendingKind) {
            case "volume":
                restStatus.showVolume(pill._osdPendingProgress, pill._osdPendingMuted)
                if (pill.surfaceOpen || (pill.activeNotif && pill.notifAnimating))
                    osd.showVolume(pill.s)
                break
            case "mic":
                restStatus.showMic(pill._osdPendingProgress, pill._osdPendingMuted)
                if (pill.surfaceOpen || (pill.activeNotif && pill.notifAnimating))
                    osd.showVolume(pill.s)
                break
            case "brightness":
                restStatus.showBrightness(pill._osdPendingProgress)
                if (pill.surfaceOpen || (pill.activeNotif && pill.notifAnimating))
                    osd.showBrightness(pill.s)
                break
            }
        }
    }
    function _queueOSD(kind, progress, muted) {
        pill._osdPendingKind = kind
        pill._osdPendingProgress = progress
        pill._osdPendingMuted = muted
        pill._osdPending = true
        osdDebounce.restart()
    }
    function showVolumeOSD() {
        var sink = Pipewire.defaultAudioSink
        if (sink && sink.audio)
            _queueOSD("volume", sink.audio.muted ? 0 : sink.audio.volume, sink.audio.muted)
    }
    function showSourceVolumeOSD() {
        var source = Pipewire.defaultAudioSource
        if (source && source.audio)
            _queueOSD("mic", source.audio.muted ? 0 : source.audio.volume, source.audio.muted)
    }
    function showBrightnessOSD() {
        if (typeof Brightness !== "undefined" && Brightness.available)
            _queueOSD("brightness", Brightness.percent / 100, false)
    }

    // Brightness changes (keybind o utils surface)
    Connections {
        target: Brightness
        function onBrightnessChanged(p) { pill.showBrightnessOSD() }
    }

    // ---- Caps Lock (polling ligero + trigger por layout) ----
    // Hyprland NO emite un evento socket2 por tecla (sólo `activelayout` cuando
    // cambia el layout, no Caps Lock) → un trigger "event-driven" por `keyboardkey`
    // nunca disparaba (ese evento no existe). Por eso: refresh inmediato cuando
    // cambia el layout/keymap (activelayout/submap) + un poll de 1s como respaldo.
    // El poll lanza UN único `hyprctl devices -j` (sin bash, sin python) y parsea
    // el JSON en QML — de 3 procesos/seg a 1 solo.
    property bool capsLockOn: false
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var n = "" + (event ? (event.name || event.event || event.type || "") : "")
            if (n === "activelayout" || n === "submap")
                getKbdState.running = true
        }
    }
    Timer {
        id: capsPoll
        interval: 1000
        repeat: true
        running: true
        onTriggered: if (!getKbdState.running) getKbdState.running = true
    }
    Process {
        id: getKbdState
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            id: kbdCollector
            onStreamFinished: {
                var txt = (kbdCollector.text || "").trim()
                if (!txt.length) return
                try {
                    var data = JSON.parse(txt)
                    var kbs = (data && data.keyboards) || []
                    for (var i = 0; i < kbs.length; i++) {
                        if (kbs[i] && kbs[i].main) {
                            pill.capsLockOn = (kbs[i].capsLock === true)
                            break
                        }
                    }
                } catch (e) {}
            }
        }
    }

    // ---- Battery status (UPower) ----
    function showBatteryOSD() {
        var d = UPower.displayDevice
        if (!d || !d.ready || !d.isLaptopBattery || !d.isPresent) return
        var charging = d.state === UPowerDeviceState.Charging
            || d.state === UPowerDeviceState.FullyCharged && !UPower.onBattery
        restStatus.showBattery(Math.round(d.percentage * 100), charging ? "charging"
            : d.state === UPowerDeviceState.PendingCharge ? "paused" : "discharging")
    }
    // Timer que recuerda la batería baja cada 60s mientras esté crítica y descargando
    Timer {
        id: batLowReminder
        interval: 60000
        repeat: true
        running: {
            var d = UPower.displayDevice
            return d && d.ready && d.isLaptopBattery && d.isPresent
                && UPower.onBattery && d.percentage <= 0.15
        }
        onTriggered: pill.showBatteryOSD()
    }
    Connections {
        target: UPower.displayDevice
        ignoreUnknownSignals: true
        function onStateChanged() { pill.showBatteryOSD() }
        function onPercentageChanged() { pill.showBatteryOSD() }
    }

    // Pipewire: dispara OSD cuando wpctl/pactl/etc cambian el volume o mute
    // del sink default. Pipewire.defaultAudioSink puede tardar en estar listo
    // (lazy bind) y puede cambiar si el usuario cambia el default sink vía
    // wpctl/pavucontrol. Re-bindea con un Timer + escucha `propertiesChanged`
    // del PwNode (signal estable en todas las versiones) que cubre cualquier
    // cambio en .audio.muted, .audio.volume, etc.
    property var _pwSink: Pipewire.defaultAudioSink
    property var _pwAudio: null
    property var _pwSource: Pipewire.defaultAudioSource
    property var _pwSourceAudio: null
    function rebindSink() {
        audioSinkConn.target = pill._pwSink
        var a = pill._pwSink ? pill._pwSink.audio : null
        audioAudioConn.target = a
        pill._pwAudio = a
    }
    function rebindSource() {
        audioSourceConn.target = pill._pwSource
        var a = pill._pwSource ? pill._pwSource.audio : null
        audioSourceAudioConn.target = a
        pill._pwSourceAudio = a
    }
    on_PwSinkChanged: rebindSink()
    on_PwSourceChanged: rebindSource()
    Timer {
        interval: 500; repeat: true; running: true
        onTriggered: {
            var s = Pipewire.defaultAudioSink
            var a = s ? s.audio : null
            if (s !== pill._pwSink || a !== pill._pwAudio) {
                console.log("[OSD] sink/audio changed from", pill._pwSink, "/", pill._pwAudio, "to", s, "/", a)
                pill._pwSink = s
                pill.rebindSink()
            }
            var src = Pipewire.defaultAudioSource
            var sa = src ? src.audio : null
            if (src !== pill._pwSource || sa !== pill._pwSourceAudio) {
                console.log("[OSD] source/audio changed from", pill._pwSource, "/", pill._pwSourceAudio, "to", src, "/", sa)
                pill._pwSource = src
                pill.rebindSource()
            }
        }
    }
    Component.onCompleted: {
        rebindSink(); rebindSource()
        getKbdState.running = true
    }
    // PwObjectTracker mantiene el sink/source "bound" para que las señales
    // de Pipewire (volumesChanged/mutedChanged) se disparen correctamente
    // tanto para cambios internos como externos (wpctl, pactl, etc.).
    PwObjectTracker {
        objects: [pill._pwSink, pill._pwSource].filter(n => n)
    }
    Connections {
        id: audioSinkConn
        target: null
        ignoreUnknownSignals: true
        function onPropertiesChanged() { pill.showVolumeOSD() }
    }
    Connections {
        id: audioAudioConn
        target: null
        ignoreUnknownSignals: true
        function onVolumesChanged() { pill.showVolumeOSD() }
        function onMutedChanged() { pill.showVolumeOSD() }
    }
    Connections {
        id: audioSourceConn
        target: null
        ignoreUnknownSignals: true
        function onPropertiesChanged() { pill.showSourceVolumeOSD() }
    }
    Connections {
        id: audioSourceAudioConn
        target: null
        ignoreUnknownSignals: true
        function onVolumesChanged() { pill.showSourceVolumeOSD() }
        function onMutedChanged() { pill.showSourceVolumeOSD() }
    }

    // wheel → volumen inline (no abre surface)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            var sink = Pipewire.defaultAudioSink
            if (sink && sink.audio && sink.ready) {
                var v = sink.audio.volume + (wheel.angleDelta.y > 0 ? 0.04 : -0.04)
                sink.audio.volume = Math.max(0, Math.min(1, v))
                pill.showVolumeOSD()
            }
        }
    }

    // OSD overlay (brillo/volumen/mic) → components/OsdOverlay.qml
}
