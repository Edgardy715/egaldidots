import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"
import "../components"
import "../Singletons"

PanelWindow {
    id: overlay
    required property SurfaceRouter router
    required property var modelData
    readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
    readonly property real topGap: 8 * Flags.topGap * s
    readonly property string surface: router.openMon === modelData.name ? router.openSurface : ""
    readonly property bool surfaceOpen: surface.length > 0
    readonly property bool overviewOpen: surface === "overview"
    readonly property bool mediaOpen: surface === "media"
    readonly property bool sessionOpen: surface === "session"
    readonly property bool wallpaperOpen: surface === "wallpaper"
    readonly property bool mediaPanelOpen: wallpaperOpen || overviewOpen
    property bool mediaPanelReturning: false
    onMediaPanelOpenChanged: {
        mediaPanelReturnTimer.stop()
        mediaPanelReturning = !mediaPanelOpen && !Flags.reduceMotion
        if (mediaPanelReturning) mediaPanelReturnTimer.restart()
    }
    Timer {
        id: mediaPanelReturnTimer
        interval: Motion.morph
        onTriggered: overlay.mediaPanelReturning = false
    }
    readonly property bool launcherOpen: surface === "launcher"
    readonly property bool mediaDocking: router.mediaDockPendingMon === modelData.name
    readonly property bool launcherClosing: launcherOpen && router.launcherClosePhase !== 0
    readonly property bool launcherReturning: launcherOpen && router.launcherClosePhase === 2
    /** Este monitor es el que tiene foco (para que el overview/wallpaper sólo
     *  robe teclado en él y las flechas/Tab operen en la pantalla correcta). */
    readonly property bool monitorIsFocused:
        (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "") === (modelData ? modelData.name : "")
    /** Una surface abierta debe conservar siempre su ruta de cierre. No
     *  dependemos del monitor enfocado: una llamada IPC puede abrirla
     *  durante el mismo frame en que Hyprland aún no actualizó
     *  `focusedMonitor`, y eso dejaba ESC sin receptor. */
    readonly property bool kbFocusWanted: surfaceOpen && !monFullscreen && !launcherClosing
    // modal = agarra input full-screen + backdrop-dismiss. SOLO cuando una
    // surface real está abierta (overview/media/calendar/…). En reposo NUNCA:
    // ni hover ni peek capturan la pantalla (pill.pinned es sólo visual).
    // ANTES incluía `pill.pinned` → al hover de la pill el overlay ponía
    // fullRegion y toda la pantalla se tragaba clicks/scroll (el "mouse
    // congelado": el dismiss MouseArea se los comía; si el HoverHandler no
    // soltaba hovered, quedaba pegado para siempre). Tide-island usa unión
    // de regiones por-surface (nunca full-screen) — acá removemos la causa.
    readonly property bool modal: surfaceOpen && !launcherClosing

    /**
     * True mientras el workspace activo de este monitor tiene una
     * ventana en fullscreen real: la pill se retrae y la capa entera
     * es click-through. (defensivo: si lastIpcObject falta → false)
     */
    readonly property bool monFullscreen: {
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++) {
            if (mons[i].name === modelData.name) {
                var ws = mons[i].activeWorkspace;
                var o = ws ? ws.lastIpcObject : null;
                return o ? !!o.hasfullscreen : false;
            }
        }
        return false;
    }

    onMonFullscreenChanged: if (monFullscreen) {
        if (router.openMon === modelData.name) router.close();
        if (router.peekMon === modelData.name) router.peekMon = "";
    }

    screen: modelData
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // Spotlight necesita poseer el teclado de forma determinista. El modo
    // OnDemand (usado por `focusable`) depende de la ventana previa y a
    // veces no recibe ni texto ni Escape en Hyprland.
    WlrLayershell.keyboardFocus: (overlay.launcherOpen && !overlay.launcherClosing) || overlay.wallpaperOpen || overlay.overviewOpen || overlay.surface === "session" || overlay.surface === "auth"
        ? WlrKeyboardFocus.Exclusive
        : overlay.kbFocusWanted ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    // Foco de teclado SOLO mientras el overview está abierto en este
    // monitor (con foco). Antes era siempre None (la pill es mouse-only y
    // Exclusive robaba teclado de la app foco al abrir una surface normal);
    // ahora el overview SÍ necesita flechas/Tab y las demás surfaces no.
    // Sin HyprlandFocusGrab (que causaba la race que cerraba en seco): el
    // foco lo pide la propia capa y lo libera al cerrar → robusto.
    WlrLayershell.namespace: "quickshell.island"

    anchors { top: true; left: true; right: true; bottom: true }

    mask: monFullscreen ? hiddenRegion : (modal ? fullRegion : pillRegion)
    Region { id: hiddenRegion }
    Region {
        id: pillRegion
        readonly property real baseW: Math.max(pill.width, pill.targetW)
        readonly property real baseH: Math.max(pill.height, pill.targetH)
        x: Math.min(pill.x + (pill.width - baseW) / 2,
                    sessionCompanion.active ? sessionCompanion.visualX : pill.x)
        y: Math.min(pill.y, fluidCompanion.active ? fluidCompanion.yPos : pill.y)
        width: Math.max(pill.x + baseW,
            fluidCompanion.active ? fluidCompanion.xPos + fluidCompanion.wPos : pill.x + baseW) - x
        height: Math.max(pill.y + baseH,
            fluidCompanion.active ? fluidCompanion.yPos + fluidCompanion.hPos : pill.y + baseH,
            sessionCompanion.active ? sessionCompanion.yPos + sessionCompanion.hPos : pill.y + baseH) - y
        onXChanged: changed()
        onYChanged: changed()
        onWidthChanged: changed()
        onHeightChanged: changed()
    }
    Region {
        id: fullRegion
        width: overlay.width
        height: overlay.height
    }

    // backdrop glass del overview: dim sutil cuando está abierto. No es
    // la "pantalla oscura" del approach con ventana aparte — apenas atenúa
    // para que la pill-morph (con el overview dentro) domine visualmente.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, Theme.shadowOpacity > 0 ? 0.5 : 0.42)
        opacity: overlay.overviewOpen ? 0.34 : 0
        visible: opacity > 0.005
        z: 0
        Behavior on opacity {
            Anim { type: Anim.DefaultEffects }
        }
    }

    // backdrop dismiss: click fuera de la pill → cierra (overview o surface).
    // enabled sigue a modal (= surfaceOpen): reposo/peek nunca capturan.
    MouseArea {
        anchors.fill: parent
        enabled: overlay.surfaceOpen
        acceptedButtons: Qt.AllButtons
        z: 0
        onPressed: (mouse) => {
            if (overlay.surfaceOpen) {
                var inside = mouse.x >= pill.x && mouse.x <= pill.x + pillRegion.baseW
                          && mouse.y >= pill.y && mouse.y <= pill.y + pillRegion.baseH;
                var inMedia = fluidCompanion.active
                    && mouse.x >= fluidCompanion.xPos
                    && mouse.x <= fluidCompanion.xPos + fluidCompanion.wPos
                    && mouse.y >= fluidCompanion.yPos
                    && mouse.y <= fluidCompanion.yPos + fluidCompanion.hPos
                var inSession = sessionCompanion.active
                    && mouse.x >= sessionCompanion.visualX
                    && mouse.x <= sessionCompanion.visualX + sessionCompanion.wPos
                    && mouse.y >= sessionCompanion.yPos
                    && mouse.y <= sessionCompanion.yPos + sessionCompanion.hPos
                if (!inside && !inMedia && !inSession) router.close();
            } else {
                router.peekMon = "";
            }
        }
    }

    // Askpass needs compositor-level focus, not just QML activeFocus.
    // Limit the grab to auth so ordinary surfaces keep their normal
    // click-through behavior.
    HyprlandFocusGrab {
        active: overlay.surface === "auth" && overlay.surfaceOpen
        windows: [overlay]
    }

    // Atajo de respaldo a nivel de ventana: también cierra cuando una
    // surface (por ejemplo el TextInput del launcher) tiene el foco.
    Shortcut {
        sequence: "Escape"
        enabled: overlay.surfaceOpen && !overlay.sessionOpen && overlay.surface !== "auth"
        onActivated: router.close()
    }

    FocusScope {
        id: focusScope
        anchors.fill: parent
        // cobra activeFocus cuando el overview pide teclado (Exclusive en la
        // capa); en reposo/surfaces normales focus=false ⇒ no roba.
        focus: overlay.kbFocusWanted
        onFocusChanged: if (focus) focusScope.forceActiveFocus()
        // re-grab de foco al asentar el morph: el primer forceActiveFocus()
        // puede correr antes de que el compositor otorgue teclado Exclusive
        // (race) y entonces Tab/flechas no llegarían. Re-clavamos una vez.
        Timer {
            running: overlay.kbFocusWanted && overlay.surface !== "auth"
            interval: Motion.morph + 40
            repeat: false
            onTriggered: if (overlay.kbFocusWanted) focusScope.forceActiveFocus()
        }

        HoverHandler {
            onHoveredChanged: pill.hovered = hovered
        }

        // ---- navegación de teclado del overview ----
        // Tab/→/↓ = siguiente ws · Shift+Tab/←/↑ = anterior
        // h/l = izq/der · j/k = abajo/arriba (filas)
        // 1-9,0 = saltar al ws de la posición N del grupo
        // Enter/Space = ir al ws seleccionado · Esc = cerrar
        // Super+Tab = cerrar (toggle off, mismo bind que abrió)
        Keys.onPressed: (event) => {
            if (!overlay.surfaceOpen) return
            var it = overlay.sessionOpen ? sessionCompanion.surfaceItem : pill.surfaceItem
            if (overlay.surface === "session" && it && it.handleKey) {
                it.handleKey(event)
                if (event.accepted) return
            }
            if ((event.modifiers & Qt.MetaModifier) && event.key === Qt.Key_Tab) {
                router.close(); event.accepted = true; return
            }
            // ESC cierra cualquier surface abierta (notifs, calendar, mixer…)
            if (event.key === Qt.Key_Escape) {
                router.close(); event.accepted = true; return
            }
            // La navegación por teclado (Tab/flechas/hjkl/números/Enter) solo
            // aplica al overview y al wallpaper picker.
            if (!overlay.overviewOpen && !overlay.wallpaperOpen) return
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (it && it.commitSelection) it.commitSelection()
                event.accepted = true; return
            }
            // números 1-9, 0 → salto directo al ws de esa posición del grupo
            if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9 && !(event.modifiers & Qt.ControlModifier)) {
                if (it && it.goIndex) it.goIndex(event.key === Qt.Key_0 ? 0 : event.key - Qt.Key_0)
                event.accepted = true; return
            }
            var dir = 0
            if (event.key === Qt.Key_Tab) dir = (event.modifiers & Qt.ShiftModifier) ? -1 : 1
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_L || event.key === Qt.Key_J) dir = 1
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_H || event.key === Qt.Key_K) dir = -1
            if (dir !== 0) {
                // j/k (vertical) mueven por filas, h/l y flechas por columnas
                if ((event.key === Qt.Key_J || event.key === Qt.Key_K)
                        && it && it.cycleRow) it.cycleRow(dir)
                else if (it && it.cycle) it.cycle(dir)
                event.accepted = true
            }
        }

        // wheel sobre la grilla → desplaza el grupo de workspaces
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            enabled: overlay.overviewOpen
            onWheel: (wheel) => {
                if (pill.surfaceItem && pill.surfaceItem.shiftGroup)
                    pill.surfaceItem.shiftGroup(wheel.angleDelta.y > 0 ? -1 : 1)
        }
    }

    Pill {
            id: pill
            z: 2
            anchors.top: parent.top
            // El launcher es "spotlight-style" → se centra verticalmente en
            // la pantalla (no top, como el resto de surfaces). Las notifs/
            // calendar/mixer/etc se quedan top-centre como siempre; el launcher
            // baja al centro con la misma curva morph del pill (cociente
            // topMargin = (screen.height - pill.height) / 2). El Behavior
            // existente anima la transición.
            // El wallpaper da un respiro extra bajo el borde superior para
            // NO parecer un dock pegado a la pantalla (actúa flotante).
            anchors.topMargin: overlay.launcherOpen
                ? overlay.launcherReturning
                    ? overlay.topGap
                    : Math.max(overlay.topGap * 2,
                               (overlay.height - IslandGeometry.launcherSurface.height * overlay.s) / 2)
                : overlay.wallpaperOpen
                    ? Math.max(overlay.topGap * 2, 18 * overlay.s)
                    : overlay.topGap
            anchors.horizontalCenter: parent.horizontalCenter

            Behavior on anchors.topMargin {
                enabled: !Flags.reduceMotion
                SmoothedAnimation { duration: Motion.morph; velocity: -1 }
            }
            s: overlay.s
            screenName: overlay.modelData.name
            surface: overlay.mediaOpen || overlay.sessionOpen ? "" : overlay.surface
            launcherClosing: overlay.launcherClosing
            launcherClosePhase: router.launcherClosePhase
            forcePinned: router.peekMon === overlay.modelData.name
            fluidJoined: ((!overlay.surfaceOpen || overlay.sessionOpen) && fluidCompanion.joined)
                || sessionCompanion.joined
            fluidCaptureExtra: overlay.surfaceOpen && !overlay.sessionOpen ? 0 : fluidCompanion.captureExtra
            fluidCaptureLeftExtra: sessionCompanion.captureExtra
            opacity: overlay.monFullscreen ? 0 : 1
            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.morph
                    easing.type: Motion.easeMorph
                    easing.bezierCurve: Motion.morphCurve
                }
            }
            transform: Translate {
                y: overlay.monFullscreen ? -(pill.height + overlay.topGap) : 0
                Behavior on y {
                    NumberAnimation {
                        duration: Motion.morph
                        easing.type: Motion.easeMorph
                        easing.bezierCurve: Motion.morphCurve
                    }
                }
            }

            onRequestSurface: (name) => router.toggleSurface(overlay.modelData.name, name)
            onRequestClose: router.close()

            // ---- notification morph (Dynamic Island) ----
            // La pill morfea para mostrar la notif activa (reemplaza Toast).
            // Solo el monitor con foco muestra el morph; resto ve pill en reposo.
            notificationsEnabled: overlay.monitorIsFocused
        }

        FluidCompanion {
            id: sessionCompanion
            anchors.fill: parent
            z: 3
            body: pill
            leftSide: true
            surfaceName: "session"
            surfaceSize: IslandGeometry.sessionSurface
            open: overlay.sessionOpen
            expanded: overlay.sessionOpen
            bodyBusy: pill.surfaceOpen || pill.notifAnimating
            s: overlay.s
            screenName: overlay.modelData.name
            opacity: overlay.monFullscreen ? 0 : 1
            onRequestToggle: { if (overlay.sessionOpen) router.close() }
        }

        FluidMediaCompanion {
            id: fluidCompanion
            z: fluidCompanion.cardFraction > 0.05 ? 3 : 1
            opacity: overlay.monFullscreen ? 0 : 1
            anchors.fill: parent
            body: pill
            open: (Players.has || overlay.mediaOpen) && !overlay.launcherOpen && !overlay.mediaPanelOpen
                && !overlay.mediaPanelReturning && !overlay.mediaDocking
            onPhaseChanged: if (phase === "idle" && overlay.mediaDocking)
                Qt.callLater(() => router.finishMediaDock(overlay.modelData.name))
            Connections {
                target: overlay
                function onMediaDockingChanged() {
                    if (overlay.mediaDocking && fluidCompanion.phase === "idle")
                        Qt.callLater(() => router.finishMediaDock(overlay.modelData.name))
                }
            }
            expanded: overlay.mediaOpen && !overlay.mediaDocking
            bodyBusy: overlay.surfaceOpen && !overlay.mediaOpen && !overlay.sessionOpen || pill.notifAnimating
            s: overlay.s
            screenName: overlay.modelData.name
            onRequestMedia: router.toggleSurface(overlay.modelData.name, "media")
        }
    }
}
