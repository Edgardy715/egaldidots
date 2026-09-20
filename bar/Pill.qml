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
 * (Behavior width/height/morphRadius · Motion.morphCurve, CERO springs). Molde
 * Ricelin Pill.qml — vidrio = gradiente cardTop→cardBot + borde 1px + sheen
 * (catch-light) + MultiEffect SÓLO sombra + inner-glow del acento que respira
 * (el "lo vivo respira" del waybar). Blur real = compositor (layerrule).
 *
 * Rest: dots de workspaces (izq) + reloj (centro, tap→calendar) + chip de media
 * (der, sólo si hay MPRIS, tap→media). Surfaces via Loader. Wheel = volumen.
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
    readonly property bool pinned: hovered || forcePinned
    readonly property string cavaConsumerId: "pill:" + (screenName || "default")

    signal requestSurface(string name)
    signal requestClose()

    // ---- metrics ----
    readonly property real coreH: 38 * s
    readonly property real padH: 18 * s

    // ---- notification morph (Dynamic Island style) ----
    // activeNotif = NotifData mostrandose (o null). La pill se morph->circle->notif->hold->circle->rest
    property var activeNotif: null
    // ¿resolveIcon encontró un icono real? (false → mostrar genericBadge con glyph fallback)
    readonly property bool _notifIconResolved: activeNotif
        && pill.resolveIcon(activeNotif.appIcon, activeNotif.appName).length > 0
    property bool notifAnimating: false
    // La surface abierta conserva su estado durante una notificación, pero su
    // árbol visual se retira antes del morph para que no se deforme junto al
    // contenido de la notificación. Se revela de nuevo cuando la pill ya volvió
    // a su geometría estable.
    property bool surfaceNotifSuspended: false
    property real surfaceReveal: 1
    // target del círculo intermedio (más pequeño que la pill en reposo)
    readonly property real notifCircleD: coreH * 0.55
    // target del pill de notif (ancho fijo ~380*s, alto compacto)
    readonly property real notifPillW: 380 * s
    readonly property real notifPillH: 72 * s

    readonly property bool surfaceOpen: surface.length > 0
    readonly property bool launcherReturning: surface === "launcher"
        && launcherClosing && launcherClosePhase === 2
    readonly property string mode: surfaceOpen && !launcherReturning ? surface : (hovered ? "hover" : "rest")
    readonly property bool materialAwake: hovered || (surfaceOpen && !launcherReturning) || notifAnimating
    readonly property color materialAccent: surface === "wallpaper" && surfaceItem && surfaceItem.previewAccent
        ? surfaceItem.previewAccent : Theme.accent
    property int materialEpoch: 0
    property real materialSweep: -0.55
    property real materialPulse: 0

    function awakenMaterial() {
        materialEpoch++
        materialSweepAnim.restart()
        materialPulseAnim.restart()
    }

    function syncCava() {
        Cava.setConsumer(cavaConsumerId, Players.live && surface !== "auth")
    }

    Component.onDestruction: Cava.setConsumer(cavaConsumerId, false)
    onSurfaceChanged: { awakenMaterial(); syncCava() }
    onHoveredChanged: if (hovered && !surfaceOpen) awakenMaterial()

    Connections {
        target: Players
        function onLiveChanged() { pill.syncCava() }
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
    readonly property var surfaceSize: ({
        mixer: Qt.size(340, 380),
        media: Qt.size(640, 300),
        calendar: Qt.size(340, 420),
        workspaces: Qt.size(360, 200),
        notifs: Qt.size(380, 540),
        // Selector de fondos: hero central, tarjetas laterales y controles claros.
        wallpaper: Qt.size(1180, 430),
        // launcher: superficie vertical centrada, con la pill multimedia
        // reutilizada como cabecera real.
        launcher: Qt.size(680, 620),
        // utils: tarjetas KeepAwake + Brillo + Perfil de energía.
        utils: Qt.size(360, 420),
        // session: 4 botones logout/shutdown/reboot/lock en grid 2×2.
        session: Qt.size(360, 240),
        // auth: expansión horizontal inline; conserva reloj y media a la izquierda.
        auth: Qt.size(0, 0),
        // overview: la pill se agranda a un panel generoso (top-centre, baja con
        // el morph — igual que el calendar). El contenido (OverviewSurface) se
        // adapta al área con tiles screen-aspect + tabs + reloj + previews vivos.
        overview: Qt.size(1120, 760),
        // connectivity: panel completo de Wi-Fi + Bluetooth con listas de redes
        // y dispositivos, escaneo, conexión y vinculación.
        connectivity: Qt.size(360, 480),
        // clipboard: historial de portapapeles con cliphist (búsqueda + imágenes).
        clipboard: Qt.size(580, 480)
    })
    readonly property var sizeFor: surfaceOpen && surfaceSize[pill.surface] ? surfaceSize[pill.surface] : Qt.size(320, 300)
    readonly property real authInputW: 350 * s
    // El buscador queda anclado por su propia altura. Cuando aparecen resultados
    // la superficie crece hacia abajo, sin recentrar el campo ni desplazarlo.
    readonly property real launcherSearchH: (44 + Theme.marginMd * 2) * s
    readonly property real launcherHeaderH: 94 * s
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
        if (surface === "auth") return 58 * s
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
        if (!surfaceItem) return 300 * s
        var base = 300 * s
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
    scale: hovered && !surfaceOpen && !notifAnimating ? 1.015 : 1
    Behavior on scale { Anim { type: Anim.FastEffects } }
    transform: Translate {
        y: pill.hovered && !pill.surfaceOpen && !pill.notifAnimating ? -1.5 * pill.s : 0
        Behavior on y { Anim { type: Anim.FastSpatial } }
    }

    // Behavior: curvas diferenciadas por fase para feel Apple-like.
    // collapse-in (rest→circle): easeOutCubic, rápido y limpio
    // expand (circle→pill): easeOutExpo con overshoot mínimo (bezier custom)
    // hold: sin animación de tamaño
    // collapse-out (pill→circle): easeInOutCubic
    // return (circle→rest): easeOutCubic
    // Morph easing/duration per phase (Apple-like feel)
    readonly property int _morphDuration: (activeNotif && notifAnimating) ? (
        (notifState === "collapse-in" || notifState === "return") ? Motion.notifCollapse :
        (notifState === "expand") ? 350 : // Duración extendida para efecto de resorte
        (notifState === "collapse-out") ? Motion.notifCollapse :
        Motion.notifCollapse
    ) : Motion.morph

    readonly property var _morphBezier: (activeNotif && notifAnimating && notifState === "expand")
        ? [0.3, 1.28, 0.4, 1.0, 1, 1]  // overshoot sutil = falso spring
        : (activeNotif && notifAnimating)
            ? [0.25, 1, 0.5, 1, 1, 1]
            : Motion.morphCurve

    readonly property int _morphEasingType: (activeNotif && notifAnimating) ? (
        (notifState === "collapse-in" || notifState === "return") ? Easing.OutCubic :
        (notifState === "collapse-out") ? Easing.InOutCubic : Easing.BezierSpline
    ) : Easing.BezierSpline
    Behavior on width {
        NumberAnimation {
            duration: pill._morphDuration
            easing.type: pill._morphEasingType
            easing.bezierCurve: pill._morphBezier
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: pill._morphDuration
            easing.type: pill._morphEasingType
            easing.bezierCurve: pill._morphBezier
        }
    }
    Behavior on morphRadius {
        NumberAnimation {
            duration: pill._morphDuration
            easing.type: pill._morphEasingType
            easing.bezierCurve: pill._morphBezier
        }
    }

    readonly property real morphCloseness: {
        var dw = Math.max(0.0001, targetW)
        var dh = Math.max(0.0001, targetH)
        var d = Math.max(Math.abs(width - targetW) / dw, Math.abs(height - targetH) / dh)
        return Math.max(0, 1 - d)
    }

    // ---- State machine: morph notif Dynamic Island ----
    // Ciclo: rest -> collapse(circle) -> expand(notif pill) -> hold(1-2s) -> collapse(circle) -> return(rest)
    // La animation es spring-driven (ver Behavior on width/height/morphRadius arriba).
    // El content gate usa morphCloseness: restContent opacity ~closeness al rest target,
    // notifContent opacity ~closeness al notif pill target (SOLO visible cuando está cerca
    // del tamaño final — el contenido nunca se "corta" durante la transformación).
    //
    // Estados: "idle" | "collapse-in" | "circle" | "expand" | "hold" | "collapse-out" | "return"
    property string notifState: "idle"

    readonly property var np: Notifs.activePopup
    onNpChanged: {
        if (np) {
            // Si había una restauración pendiente y entra otra notificación,
            // mantenemos la surface fuera hasta que termine toda la secuencia.
            surfaceRestoreTimer.stop()
            // Llega una nueva notif (o se reasigna la actual). Si estamos en idle
            // → ciclo normal. Si ya estamos mostrando otra → forzar la salida y
            // promover esta (la pill termina collapse-out y al volver a idle
            // el binding np will re-evaluate; si Notifs.advancePopup() asigna la
            // siguiente, esta misma función entrará por la rama idle).
            // Bug #3: la rama anterior ignoraba !np durante collapse-in/expand,
            // dejando la pill atascada en tamaño intermedio si la notif se cerraba.
            // Bug #4: la rama anterior solo actuaba si np && idle, así que una
            // notif que llegaba mientras había otra activa quedaba esperando en
            // cola sin feedback visual. Ahora: si np cambia y es distinta a la
            // activa (o no había activa), promovemos de inmediato.
            if (notifState === "idle") {
                pill.activeNotif = np
                pill.notifAnimating = true
                pill._notifToCircleIn()
            } else if (pill.activeNotif !== np) {
                // swap: termina la actual rápido y promueve la nueva
                pill._notifToCircleOut()
            }
        } else if (!np && notifState !== "idle") {
            // la notif expiró o fue cerrada — avance de cola
            if (notifState === "hold" || notifState === "expand" || notifState === "collapse-in")
                pill._notifToCircleOut()
            // si ya está en collapse-out/return, dejar terminar
        }
    }

    function _notifToCircleIn() {
        if (surfaceOpen) {
            surfaceReveal = 0
            surfaceNotifSuspended = true
        }
        notifState = "collapse-in"
        // target = circle (spring anima)
        // esperar a que el spring se asiente (cercano al circle), entonces expand
        notifHoldIn.restart()
    }
    Timer {
        id: notifHoldIn
        interval: Motion.notifCollapse + 50
        repeat: false
        onTriggered: {
            if (pill.notifState === "collapse-in") {
                pill.notifState = "expand"
                // target = notif pill (spring anima de circle -> notif)
                notifExpandTimer.restart()
            }
        }
    }
    Timer {
        id: notifExpandTimer
        interval: Motion.notifExpand + 80
        repeat: false
        onTriggered: {
            if (pill.notifState === "expand") {
                pill.notifState = "hold"
                // hold 1-2s
                notifHoldTimer.restart()
            }
        }
    }
    Timer {
        id: notifHoldTimer
        interval: Math.round((Motion.notifHoldMin + Motion.notifHoldMax) / 2)
        repeat: false
        onTriggered: {
            if (pill.notifState === "hold") {
                pill._notifToCircleOut()
            }
        }
    }
    function _notifToCircleOut() {
        surfaceRestoreTimer.stop()
        notifState = "collapse-out"
        // target = circle (spring anima de notif -> circle)
        notifCollapseOutTimer.restart()
    }
    Timer {
        id: notifCollapseOutTimer
        interval: Motion.notifCollapse + 50
        repeat: false
        onTriggered: {
            if (pill.notifState === "collapse-out") {
                pill.notifState = "return"
                // target = rest (spring anima de circle -> rest)
                notifReturnTimer.restart()
            }
        }
    }
    Timer {
        id: notifReturnTimer
        interval: Motion.notifExpand + 80
        repeat: false
        onTriggered: {
            if (pill.notifState === "return") {
                pill.notifState = "idle"
                pill.notifAnimating = false
                pill.activeNotif = null
                if (pill.surfaceOpen) surfaceRestoreTimer.restart()
                // avanzar la cola — si hay más popups, se asigna la siguiente
                Notifs.advancePopup()
            }
        }
    }
    Timer {
        id: surfaceRestoreTimer
        // El target vuelve primero al tamaño de reposo y luego a la surface.
        // Esperamos a que ese segundo morph se asiente antes de revelar el
        // contenido para evitar cualquier frame mezclado.
        interval: Motion.morph + 70
        repeat: false
        onTriggered: {
            if (pill.notifAnimating || pill.activeNotif || !pill.surfaceOpen) return
            pill.surfaceReveal = 0
            pill.surfaceNotifSuspended = false
            pill.surfaceReveal = 1
        }
    }

    onSurfaceOpenChanged: {
        if (!surfaceOpen) {
            surfaceRestoreTimer.stop()
            surfaceNotifSuspended = false
            surfaceReveal = 1
        }
    }

    // ---- Breathing durante hold (sutil pulse del circle/pill) ----
    // Se activa solo en estado "hold", da vida a la isla (estilo iOS Dynamic Island)
    property real notifBreath: 0
    SequentialAnimation on notifBreath {
        id: notifBreathAnim
        running: pill.notifAnimating && pill.notifState === "hold"
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
    // ---- indicador efímero de workspace ----
    // En reposo la isla SÓLO muestra el reloj (cero dots). Al cambiar de ws el chip
    // wsFlash se extiende (morf morphCurve) revelando el número del ws activo,
    // mantiene ~1.25s y se retrae — la isla "responde" al cambio y vuelve a calma.
    // Armado: el primer cambio de activeWsName (bootstrap de Hyprland.monitors) se
    // absorbe sin flash. Los siguientes (cambios manuales de ws) flaashean.
    property bool wsReady: false
    onActiveWsNameChanged: {
        if (!pill.wsReady) { pill.wsReady = true; return }
        var a = parseInt(pill.activeWsName)
        if (a >= 1) wsFlash.flash(a)
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
    }
    // ---- contenido (sobre el body) ----
    Item {
        id: content
        anchors.fill: parent
        z: 1

        // rest content
        Row {
            id: restContent
            y: pill.launcherHeaderVisible
                ? (pill.launcherHeaderH - implicitHeight) / 2
                : (parent.height - implicitHeight) / 2
            x: pill.surface === "auth" ? 18 * pill.s : (parent.width - implicitWidth) / 2
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

            // wsFlash — una señal breve de orientación. El número llega dentro de
            // una cápsula de foco, sin contador que compita con la transición del
            // workspace que ocurre detrás de la isla.
            Item {
                id: wsFlash
                anchors.verticalCenter: parent.verticalCenter
                width: shown ? chipW : 0
                height: pill.coreH * 0.52
                opacity: shown ? 1 : 0
                visible: opacity > 0.01

                property bool shown: false
                property int wsNum: 1
                readonly property real labelW: wsFlashLabel.implicitWidth + 24 * pill.s
                readonly property real chipW: labelW + 18 * pill.s

                Behavior on width { Anim { type: Anim.Morph } }
                Behavior on opacity { Anim { type: Anim.Morph } }

                Timer { id: wsFlashHold; interval: Math.round(1250 * Motion.mult); repeat: false; onTriggered: wsFlash.shown = false }
                function flash(num) {
                    wsNum = num
                    shown = true
                    wsFlashHold.restart()
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.alpha(Theme.accent, Theme.alphaWash)
                    border.width: Theme.borderHairline
                    border.color: Qt.alpha(Theme.accent, Theme.alphaSoft)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8 * pill.s
                        width: 4 * pill.s
                        height: parent.height * 0.42
                        radius: width / 2
                        color: Theme.accent
                    }

                    Text {
                        anchors.centerIn: parent
                        id: wsFlashLabel
                        text: "" + wsFlash.wsNum
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeBodyLg * pill.s
                        font.weight: Font.DemiBold
                    }
                }
            }

            // volChip — feedback dinámico de volumen/brillo/mic (Dynamic Island).
            // components/VolumeChip.qml
            VolumeChip {
                id: volChip
                s: pill.s
                coreH: pill.coreH
            }

            // batChip — indicador efímero de batería (Dynamic Island).
            // components/BatteryChip.qml
            BatteryChip {
                id: batChip
                s: pill.s
                coreH: pill.coreH
            }

            // capsLock — indicador persistente de Caps Lock (solo visible si activo)
            Text {
                id: capsInd
                anchors.verticalCenter: parent.verticalCenter
                text: "⇪"
                color: Theme.accent
                font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall * pill.s
                visible: pill.capsLockOn
                opacity: pill.capsLockOn ? 1 : 0
                Behavior on opacity { Anim { type: Anim.FastEffects } }
            }
            Item { width: pill.capsLockOn ? 6 * pill.s : 0; height: 1; visible: pill.capsLockOn }

            // reloj — 12h minimalista, Inter. AM/PM en dim (Apple-level: la hora
            // "grita", el meridiano susurra). Tap → calendar.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.foreground
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSizeHeadline * pill.s
                font.weight: Font.DemiBold
                textFormat: Text.RichText
                // Nota Qt: `h` sólo es 12h si `ap` va en el MISMO format-string;
                // separado (como aquí para pintar hora vs meridiano distinto) cae a
                // 24h → "17:24 PM". Hora 12h computada a mano, minutos con `mm`.
                text: {
                    var h = pill.now.getHours() % 12 || 12
                    return "<span style='color:" + ("" + Theme.foreground) + "'>"
                           + h + ":" + Qt.formatDateTime(pill.now, "mm")
                           + "</span> <span style='color:" + ("" + Theme.dim) + "; font-size:" + Math.round(12 * pill.s) + "px'>"
                           + Qt.formatDateTime(pill.now, "ap").toUpperCase()
                           + "</span>"
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6 * pill.s
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.requestSurface("calendar")
                }
            }

            // ---- media chip (now-playing compacto "vivo") ----
            // Sin cápsula propia (la isla ya es vidrio): a la izq un combo cover
            // circular que RESPIRA mientras suena, ENMARcado por un anillo de
            // progreso acento (PathAngleArc, round-cap, cabeza "cometa"). A la
            // der el título + artista con marquee seamless — scroll sólo si
            // desborda Y suena; en pausa o si cabe, quieto. "Lo vivo": todo
            // gated por Players.live → pausado = calma total, cero CPU.
            // Tap → surface media. El hover del chip NO captura input (fix del
            // mouse: modal sólo va por surfaceOpen); sólo escala sutil.
            Item {
                id: mediaChip
                anchors.verticalCenter: parent.verticalCenter
                readonly property real comboD: pill.coreH - 4 * pill.s   // Ø cover+ring (cabe en coreH)
                readonly property real ringW: 1.8 * pill.s
                readonly property real ringGap: 2 * pill.s
                readonly property real coverD: mediaChip.comboD - 2 * (mediaChip.ringW + mediaChip.ringGap)
                readonly property real textW: pill.surface === "auth" ? 0 : 132 * pill.s
                readonly property real gap: pill.surface === "auth" ? 0 : 10 * pill.s
                // aire lead a la izq del cover: con spacing:0 el cover arrancaba a 0px
                // del reloj (PM chocaba con el anillo de música). leadGap hueco dentro
                // del chip desplaza el Row interno → respiro reloj↔cover, animado con
                // el width (sin snap, mismo truco que wsFlash).
                readonly property real leadGap: 14 * pill.s
                width: Players.has ? mediaChip.leadGap + mediaChip.comboD + mediaChip.gap + mediaChip.textW : 0
                height: pill.coreH
                visible: Players.has
                opacity: visible ? 1 : 0
                scale: mediaHover.containsMouse ? 1.03 : 1.0
                Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                Behavior on scale  { Anim { type: Anim.FastEffects } }
                Behavior on width  { Anim { type: Anim.Morph } }

                // ---- progreso interpolado (segundos; mismo idioma que MediaSurface) ----
                property real pPos: 0
                property real lastTick: 0
                property bool pReady: false
                property var pPlayer: null
                property string pTrackKey: ""
                property bool waitingForStableSample: false
                function _numOr(v, fallback) {
                    return typeof v === 'number' && isFinite(v) ? v : fallback
                }
                readonly property real pLen: (Players.active && typeof Players.active.length === 'number'
                                               && isFinite(Players.active.length) && Players.active.length > 0)
                    ? Players.active.length : 0
                readonly property real pFrac: mediaChip.pLen > 0
                    ? Math.max(0, Math.min(1, mediaChip.pPos / mediaChip.pLen)) : 0
                property real pFracAnim: 0
                NumberAnimation {
                    id: progressAnim
                    target: mediaChip
                    property: "pFracAnim"
                    duration: Motion.fast
                    easing.bezierCurve: Motion.standardDecelCurve
                }
                function setFrac(animate) {
                    var next = mediaChip.pFrac
                    if (!animate) {
                        progressAnim.stop()
                        mediaChip.pFracAnim = next
                        return
                    }
                    progressAnim.to = next
                    progressAnim.restart()
                }
                function resetSample(active) {
                    mediaChip.pReady = false
                    mediaChip.pPlayer = active || null
                    mediaChip.pTrackKey = Players.trackKeyNoArt || ""
                    mediaChip.pPos = 0
                    mediaChip.lastTick = 0
                    mediaChip.setFrac(false)
                }
                function deferSync(clear) {
                    mediaChip.waitingForStableSample = true
                    if (clear) mediaChip.resetSample(Players.active)
                    stableSampleTimer.restart()
                }
                function syncPos(jump) {
                    if (mediaChip.waitingForStableSample) return
                    var active = Players.active
                    var pos = active ? mediaChip._numOr(active.position, NaN) : NaN
                    if (!active || !isFinite(pos) || mediaChip.pLen <= 0) {
                        mediaChip.resetSample(active)
                        return
                    }
                    var discontinuity = !!jump || !mediaChip.pReady || mediaChip.pPlayer !== active
                        || Math.abs(pos - mediaChip.pPos) > 1.0
                    mediaChip.pPlayer = active
                    mediaChip.pTrackKey = Players.trackKeyNoArt || ""
                    mediaChip.pPos = Math.max(0, Math.min(mediaChip.pLen, pos))
                    mediaChip.pReady = true
                    mediaChip.lastTick = Date.now()
                    mediaChip.setFrac(!discontinuity)
                }
                onVisibleChanged: if (visible) mediaChip.deferSync(true)
                Connections {
                    target: Players.active
                    ignoreUnknownSignals: true
                    function onPositionChanged() {
                        if (!mediaChip.waitingForStableSample) mediaChip.syncPos(false)
                    }
                    function onLengthChanged() { mediaChip.deferSync(!mediaChip.pReady) }
                    function onIsPlayingChanged() {
                        if (!Players.live) {
                            mediaChip.lastTick = 0
                            return
                        }
                        // Firefox/YouTube puede publicar una posición transitoria
                        // al mismo tiempo que PlaybackStatus pasa a Playing.
                        mediaChip.deferSync(!mediaChip.pReady || mediaChip.pPlayer !== Players.active)
                    }
                }
                Connections {
                    target: Players
                    ignoreUnknownSignals: true
                    function onActiveChanged() { mediaChip.deferSync(true) }
                    function onTrackKeyNoArtChanged() {
                        mediaChip.deferSync(true)
                        marquee.scrollX = 0
                        marquee.armed = false
                    }
                }
                Timer {
                    id: stableSampleTimer
                    interval: 180
                    repeat: false
                    onTriggered: {
                        mediaChip.waitingForStableSample = false
                        mediaChip.syncPos(true)
                    }
                }
                Timer {
                    interval: 160; repeat: true
                    running: mediaChip.visible && Players.live && mediaChip.pReady && mediaChip.pLen > 0
                    onTriggered: {
                        if (!Players.live || mediaChip.lastTick <= 0) return
                        var now = Date.now()
                        var elapsed = Math.max(0, Math.min(0.75, (now - mediaChip.lastTick) / 1000))
                        var rate = mediaChip._numOr(Players.active.rate, 1)
                        mediaChip.pPos = Math.min(mediaChip.pLen, mediaChip.pPos + elapsed * Math.max(0, rate))
                        mediaChip.lastTick = now
                        mediaChip.setFrac(true)
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: mediaChip.leadGap
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: mediaChip.gap

                    // ---- combo: anillo de progreso + cover que respira ----
                    Item {
                        id: coverComboWrap
                        anchors.verticalCenter: parent.verticalCenter
                        width: mediaChip.comboD; height: mediaChip.comboD

                        // track del anillo (ring tenue, base)
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width; height: parent.height
                            radius: height / 2; color: "transparent"
                            border.color: Qt.alpha(Theme.foreground, Theme.alphaSoft)
                            border.width: mediaChip.ringW
                            visible: mediaChip.pLen > 0
                        }
                        // anillo de progreso acento (arco que crece con pFracAnim)
                        Shape {
                            anchors.centerIn: parent
                            width: parent.width; height: parent.height
                            preferredRendererType: Shape.CurveRenderer
                            visible: mediaChip.pLen > 0
                            ShapePath {
                                strokeColor: Theme.accent
                                strokeWidth: mediaChip.ringW
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: coverComboWrap.width / 2; centerY: coverComboWrap.height / 2
                                    radiusX: coverComboWrap.width / 2 - mediaChip.ringW / 2
                                    radiusY: coverComboWrap.height / 2 - mediaChip.ringW / 2
                                    startAngle: -90
                                    sweepAngle: 360 * mediaChip.pFracAnim
                                    moveToStart: true
                                }
                            }
                        }
                        // cover estática dentro de una ventana circular fija.
                        // Verificado empíricamente en GPU real:
                        //   · `clip:+radius` recorta hijos a la CAJA (no al redondeo) → cover
                        //     cuadrado;
                        //   · `layer.effect: MultiEffect.maskSource` recorta al círculo OK,
                        //     pero pinta el COLOR de la máscara (blanco), no el arte → disco
                        //     blanco;
                        //   · `OpacityMask` con source VISIBLE filtra el cuadrado (leak de
                        //     esquinas);
                        //   · `OpacityMask` con source Y maskSource `visible:false` (este)
                        //     = arte en círculo, esquinas transparentes. Único correcto.
                        // Ambos `visible:false` → nunca pinta disco blanco; el fade vive en
                        // el OpacityMask y la orientación no salta mientras suena.
                        Item {
                            id: coverWrap
                            anchors.centerIn: parent
                            width: mediaChip.coverD; height: mediaChip.coverD
                            scale: mediaHover.pressed ? 0.96 : (mediaHover.containsMouse ? 1.025 : 1)
                            Behavior on scale { Anim { type: Anim.FastEffects } }
                            // arte + máscara: ambos `visible:false` → OpacityMask los
                            // captura como texturas; nada se pinta directo a la escena.
                            Image {
                                id: coverImg
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop; cache: true; asynchronous: true; smooth: true
                                source: Players.artUrl && Players.artUrl.length > 0 ? Players.artUrl : ""
                                sourceSize: Qt.size(mediaChip.coverD * 2, mediaChip.coverD * 2)
                                visible: false
                            }
                            Rectangle {
                                id: coverMask
                                anchors.fill: parent; radius: height / 2; color: "#ffffff"
                                visible: false
                            }
                            // fallback Material mientras carga o si no hay arte
                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: "music_note"
                                color: Theme.iconSecondary
                                font.pixelSize: mediaChip.coverD * 0.58
                                visible: coverImg.status !== Image.Ready
                                Accessible.ignored: true
                            }
                            // el arte enmascarado; aquí vive el cross-fade.
                            OpacityMask {
                                id: coverDisc
                                anchors.fill: parent
                                source: coverImg; maskSource: coverMask
                                opacity: coverImg.status === Image.Ready ? 1 : 0
                                Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                            }
                            // borde circular estático (frame), la "pista" del disco
                            Rectangle {
                                anchors.fill: parent; radius: height / 2; color: "transparent"
                                border.color: Theme.border; border.width: Theme.borderHairline; antialiasing: true
                            }
                        }
                    }

                    // ---- título + artista con marquee seamless ----
                    Item {
                        id: textClip
                        anchors.verticalCenter: parent.verticalCenter
                        width: mediaChip.textW; height: pill.coreH
                        clip: true
                        readonly property string richText: {
                            var t = pill.esc(Players.title || "—")
                            var a = pill.esc(Players.artist || "")
                            var core = "<span style='color:" + ("" + Theme.foreground) + ";font-weight:500'>" + t + "</span>"
                            if (a.length > 0) core += "<span style='color:" + ("" + Theme.dim) + "'>   " + a + "</span>"
                            return core
                        }
                        readonly property bool overflow: marqueeText.implicitWidth > textClip.width

                        Item {
                            id: marquee
                            anchors.verticalCenter: parent.verticalCenter
                            height: textClip.height
                            property real scrollX: 0
                            property bool armed: false
                            readonly property real sepPx: 40 * pill.s   // separación entre copias (loop seamless)
                            Text {
                                id: marqueeText
                                anchors.verticalCenter: parent.verticalCenter
                                textFormat: Text.RichText
                                color: Theme.foreground
                                font.family: Theme.font
                                font.pixelSize: 12.5 * pill.s
                                font.weight: Font.Medium
                                font.letterSpacing: 0.05 * pill.s
                                text: textClip.richText
                                x: textClip.overflow ? marquee.scrollX
                                                     : (textClip.width - marqueeText.implicitWidth) / 2
                            }
                            Text {
                                // 2ª copia para loop seamless — sólo visible mientras scrollea
                                anchors.verticalCenter: parent.verticalCenter
                                textFormat: Text.RichText
                                color: Theme.foreground
                                font.family: Theme.font
                                font.pixelSize: 12.5 * pill.s
                                font.weight: Font.Medium
                                font.letterSpacing: 0.05 * pill.s
                                text: textClip.richText
                                x: marqueeText.x + marqueeText.implicitWidth + marquee.sepPx
                                visible: textClip.overflow && marquee.armed
                            }
                            Timer {
                                interval: 700
                                running: textClip.overflow && Players.live && mediaChip.visible
                                onTriggered: marquee.armed = true
                            }
                            NumberAnimation on scrollX {
                                from: 0
                                to: -(marqueeText.implicitWidth + marquee.sepPx)
                                duration: Math.max(2200, Math.round((marqueeText.implicitWidth + marquee.sepPx) / 0.045))
                                loops: Animation.Infinite
                                running: textClip.overflow && marquee.armed && Players.live && mediaChip.visible
                                easing.type: Easing.Linear
                            }
                        }
                    }
                }

                MouseArea {
                    id: mediaHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.requestSurface("media")
                }
            }

            // Onda compacta: cinco muestras reales de CAVA, centradas y limitadas
            // por el perfil para preservar la silueta incluso con audio intenso.
            Item {
                id: mediaLive
                anchors.verticalCenter: parent.verticalCenter
                width: Players.has && pill.surface !== "auth" ? 26 * pill.s : 0
                height: pill.coreH
                visible: Players.has
                opacity: visible ? 1 : 0
                Behavior on width { Anim { type: Anim.Morph } }
                Behavior on opacity { Anim { type: Anim.DefaultEffects } }

                Row {
                    anchors.centerIn: parent
                    spacing: 2.5 * pill.s

                    Repeater {
                        model: 5
                        delegate: Item {
                            required property int index
                            readonly property var profile: [0.35, 0.70, 1.00, 0.70, 0.35]
                            readonly property var bands: [2, 7, 12, 16, 21]
                            readonly property real minHeight: 2.5 * pill.s
                            readonly property real maxHeight: profile[index] * 18 * pill.s
                            readonly property real signal: Players.live && Cava.hasFrame
                                ? (Cava.values[bands[index]] || 0) : 0
                            width: 2.5 * pill.s
                            height: mediaLive.height

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: parent.minHeight + parent.signal
                                    * (parent.maxHeight - parent.minHeight)
                                radius: width / 2
                                color: Qt.alpha(Theme.accent, 0.72 + parent.signal * 0.28)
                                Behavior on height { Anim { type: Anim.FastEffects } }
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.requestSurface("media")
                }
            }
        }

        // La cabecera no es otra pill: es el mismo contenido multimedia de
        // reposo, recolocado dentro del vidrio expandido.
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

        // ---- NotifContent (Dynamic Island morph) ----
        // visible solo cuando la pill está en fase notif (expand/hold), con gate en morphCloseness
        // al target de notif pill (no al rest). Así el contenido aparece SOLO cuando ya
        // alcanzó el tamaño final del notif pill, nunca "cortado" durante la transformación.
        Item {
            id: notifContent
            anchors.centerIn: parent
            width: notifPillW
            height: notifPillH
            // closeness al target notif (expand/hold). Cuando está lejos (circle/rest) = 0.
            // Usamos morphCloseness que ya mide cercanía al target actual.
            readonly property real notifCloseness: activeNotif && notifAnimating &&
                (notifState === "expand" || notifState === "hold") ? morphCloseness : 0
            opacity: notifCloseness
            visible: opacity > 0.01
            clip: true
            // breathing scale durante hold (sutil)
            scale: (pill.notifAnimating && pill.notifState === "hold") ? (1.0 + pill.notifBreath * 0.025) : 1.0
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }

            // El contenido del notif pill: icono + summary + body (inline, sin NotifCard).
            // activeNotif tiene: summary, body, appName, appIcon, image, isCritical
            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingXl * pill.s
                visible: pill.activeNotif !== null

                // icono: círculo con glow acento + imagen, "breathing" en hold
                Item {
                    id: notifIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48 * pill.s
                    height: 48 * pill.s
                    visible: pill.activeNotif && pill._notifIconResolved

                    // glow fondo sutil detrás del icono
                    Rectangle {
                        id: iconGlowBg
                        anchors.centerIn: parent
                        width: parent.width + 10 * pill.s
                        height: parent.height + 10 * pill.s
                        radius: width / 2
                        color: pill.activeNotif && pill.activeNotif.isCritical ? Theme.accentStrong : Theme.accent
                        opacity: (pill.notifBreath * 0.15) + 0.04
                        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }
                    }
                    // glow ring exterior que respira (sutil)
                    Rectangle {
                        id: iconGlow
                        anchors.centerIn: parent
                        width: parent.width + 8 * pill.s * (1 + pill.notifBreath * 0.5)
                        height: parent.height + 8 * pill.s * (1 + pill.notifBreath * 0.5)
                        radius: width / 2
                        color: "transparent"
                        border.width: Theme.borderHairlineSoft *  pill.s
                        border.color: pill.activeNotif && pill.activeNotif.isCritical
                            ? Qt.alpha(Theme.accentStrong, 0.25 + pill.notifBreath * 0.25)
                            : Qt.alpha(Theme.accent, 0.20 + pill.notifBreath * 0.25)
                    }

                    // círculo base con escala que respira
                    Rectangle {
                        id: iconBase
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        radius: width / 2
                        color: Qt.alpha(pill.activeNotif && pill.activeNotif.isCritical ? Theme.accentStrong : Theme.accent, Theme.alphaSubtle)
                        border.color: Qt.alpha(pill.activeNotif && pill.activeNotif.isCritical ? Theme.accentStrong : Theme.accent, Theme.alphaCritical)
                        border.width: Theme.borderHairlineSoft *  pill.s
                        scale: 1.0 + pill.notifBreath * 0.06
                        Behavior on scale { NumberAnimation { duration: 300 } }
                    }

                    // imagen del icono (más grande, 30px)
                    Image {
                        anchors.centerIn: parent
                        width: 30 * pill.s
                        height: 30 * pill.s
                        source: pill.activeNotif ? pill.resolveIcon(pill.activeNotif.appIcon, pill.activeNotif.appName) : ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        cache: false
                    }
                }

                // fallback: badge genérico si no hay icon resolvible (appIcon vacío o sin match)
                Rectangle {
                    id: genericBadge
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48 * pill.s
                    height: 48 * pill.s
                    radius: width / 2
                    visible: !pill.activeNotif || !pill._notifIconResolved
                    color: Qt.alpha(pill.activeNotif && pill.activeNotif.isCritical ? Theme.accentStrong : Theme.accent, Theme.alphaSubtle)
                    border.color: Qt.alpha(pill.activeNotif && pill.activeNotif.isCritical ? Theme.accentStrong : Theme.accent, Theme.alphaCritical)
                    border.width: Theme.borderHairlineSoft *  pill.s
                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: pill.activeNotif
                            ? Icons.getNotifIcon(pill.activeNotif.summary, pill.activeNotif.urgency)
                            : Icons.iBell
                        color: pill.activeNotif && pill.activeNotif.isCritical ? Theme.accentStrong : Theme.accent
                        font.pixelSize: Theme.fontSizeIcon * pill.s
                    }
                }

                // texto: appName (caption) + summary (bold) + body (dim)
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXs * pill.s
                    Text {
                        text: pill.activeNotif ? pill.activeNotif.appName : ""
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 10.5 * pill.s
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        width: pill.notifPillW - 100 * pill.s
                        visible: text.length > 0
                    }
                    Text {
                        text: pill.activeNotif ? pill.activeNotif.summary : ""
                        color: pill.activeNotif && pill.activeNotif.isCritical ? Theme.accent : Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeBodyLg * pill.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        width: pill.notifPillW - 100 * pill.s
                    }
                    Text {
                        text: pill.activeNotif ? pill.activeNotif.body : ""
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeSmall * pill.s
                        elide: Text.ElideRight
                        width: pill.notifPillW - 100 * pill.s
                        visible: text.length > 0
                    }
                }
            }
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
        morphCloseness: pill.morphCloseness
        morphRadius: pill.morphRadius
        surfaceRadius: material.bodyRadius
        screenName: pill.screenName
        bgColor: pill.bgColor
        closing: pill.launcherClosing
        suspended: pill.surfaceNotifSuspended
        reveal: pill.launcherReturning ? 0 : pill.surfaceReveal
        onRequestClose: pill.requestClose()
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
                volChip.showVolume(pill._osdPendingProgress, pill._osdPendingMuted)
                if (pill.surfaceOpen || (pill.activeNotif && pill.notifAnimating))
                    osd.showVolume(pill.s)
                break
            case "mic":
                volChip.showMic(pill._osdPendingProgress, pill._osdPendingMuted)
                if (pill.surfaceOpen || (pill.activeNotif && pill.notifAnimating))
                    osd.showVolume(pill.s)
                break
            case "brightness":
                volChip.showBrightness(pill._osdPendingProgress)
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
        if (typeof UPower === "undefined") return
        var d = UPower.displayDevice
        if (!d || !d.isPresent) return
        batChip.show(d.percent, d.status)
    }
    // Timer que recuerda la batería baja cada 60s mientras esté crítica y descargando
    Timer {
        id: batLowReminder
        interval: 60000
        repeat: true
        running: {
            if (typeof UPower === "undefined" || !UPower.displayDevice) return false
            var d = UPower.displayDevice
            return d && d.isPresent && d.percent <= 15 && d.status !== "charging"
        }
        onTriggered: pill.showBatteryOSD()
    }
    Connections {
        target: UPower.displayDevice
        ignoreUnknownSignals: true
        function onStatusChanged() { pill.showBatteryOSD() }
        function onPercentChanged() { pill.showBatteryOSD() }
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
        rebindSink(); rebindSource(); syncCava()
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
