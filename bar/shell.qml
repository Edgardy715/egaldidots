//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma IconTheme "hicolor"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"

/**
 * Isla · shell. Puerto de Ricelin `pill/shell.qml`: dos `PanelWindow` por
 * monitor (Variants sobre Quickshell.screens):
 *
 *  - `reserve`: tira vacía que sólo reserva struts (exclusionMode Normal,
 *    exclusiveZone = alto de la pill en reposo, aboveWindows, mask = Region
 *    vacío = click-through). Las ventanas tileadas nunca montan sobre la pill.
 *  - `overlay`: full-screen transparente, WlrLayer.Overlay, exclusionMode
 *    Ignore, namespace "quickshell.island"; ancla la única Pill top-centre y
 *    enruta el input con máscara tri-estado:
 *        monFullscreen ? hiddenRegion : (modal ? fullRegion : pillRegion)
 *    reposo → sólo la pill captura clicks (el resto va a ventanas); surface
 *    abierta → capa entera + backdrop-dismiss; fullscreen → click-through + pill
 *    retraída.
 *
 * `IpcHandler { target: "island" }` expone clock/mixer/media/calendar/peek/hide
 * para keybinds. Un monitor vacío resuelve al foco. Raw-event allowlist →
 * `refresh()` (sólo lo que cambia lo renderizado).
 */
ShellRoot {
    id: root

    settings.watchFiles: true

    property string openMon: ""
    property string openSurface: ""
    property string peekMon: ""
    // El launcher necesita dos fases de salida para que resultados → buscador →
    // pill sea una sola transición. Mientras dura, la surface sigue montada.
    property int launcherClosePhase: 0

    function refresh() {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    Component.onCompleted: {
        // fuerza instanciación de singletons referenciándolos explícitamente
        refresh()
        Brightness.available
        Session.lockCmd
        Auth.active
        KeepAwake.enabled      // fuerza singleton KeepAwake
    }

    // Polkit entrega las solicitudes gráficas directamente a la pill. Las
    // solicitudes de sudo en un terminal siguen perteneciendo a su TTY.
    Connections {
        target: Auth
        function openAuthSurface() {
            var mon = Hyprland.focusedMonitor
            if (!mon && Quickshell.screens.length > 0)
                mon = Quickshell.screens[0]
            root.openMon = mon ? mon.name : ""
            root.openSurface = "auth"
            console.log("[Auth] surface monitor:", root.openMon)
        }
        function onAuthenticationRequestStarted() {
            openAuthSurface()
        }
        function onSudoRequestStarted() {
            console.log("[Auth] opening sudo surface")
            openAuthSurface()
        }
        function onActiveChanged() {
            if (Auth.active) {
                openAuthSurface()
            } else if (Auth.sudoActive) {
                openAuthSurface()
            } else if (root.openSurface === "auth") {
                root.close()
            }
        }
        function onSudoActiveChanged() {
            if (Auth.sudoActive) openAuthSurface()
            else if (!Auth.active && root.openSurface === "auth") root.close()
        }
    }

    /**
     * El overview es ahora una surface de la pill (como calendar/mixer): al
     * abrirse manda el morph del body a surfaceSize["overview"]. Cuando es la
     * surface "overview" la que se abre, refresca WinMap para tener geometría
     * de ventanas fresca (las mini-ventanas vivas la leen).
     *
     * `WinMap.active` gatea el polling vivo de hyprctl: sólo mientras el
     * overview está abierto. Cerrar (o saltar a otra surface) → active=false →
     * WinMap deja de agendar hyprctl por cada raw-event (cero trabajo en reposo).
     * La 1ª carga del Component.onCompleted de WinMap queda intacta → data
     * fresca al instante al (re)abrir el overview.
     */
    onOpenSurfaceChanged: {
        WinMap.active = (root.openSurface === "overview")
        if (WinMap.active) WinMap.updateAll()
        // centro de notifs: ahoga toasts mientras abierto (Notifs.shouldShowPopup).
        Notifs.centerOpen = (root.openSurface === "notifs")
    }

    /** Sólo estos raw-events cambian lo que la pill renderiza. */
    readonly property var refreshEvents: ({
        workspace: true, workspacev2: true,
        createworkspace: true, createworkspacev2: true,
        destroyworkspace: true, destroyworkspacev2: true,
        moveworkspace: true, moveworkspacev2: true,
        renameworkspace: true, activespecial: true,
        focusedmon: true, focusedmonv2: true,
        openwindow: true, closewindow: true,
        movewindow: true, movewindowv2: true,
        fullscreen: true,
        monitoradded: true, monitoraddedv2: true, monitorremoved: true
    })

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.refreshEvents[event.name]) root.refresh();
        }
    }

    /** Monitor vacío → monitor con foco, para que los keybinds salten el jq. */
    function toggleSurface(mon, surface) {
        if (!mon || mon.length === 0)
            mon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        if (surface === "launcher" && root.openMon === mon
                && root.openSurface === "launcher" && root.launcherClosePhase !== 0) {
            root.launcherClosePhase = 0
            launcherCloseResultsTimer.stop()
            launcherClosePillTimer.stop()
            return
        }
        if (root.launcherClosePhase !== 0) {
            root.launcherClosePhase = 0
            launcherCloseResultsTimer.stop()
            launcherClosePillTimer.stop()
        }
        if (root.openMon === mon && root.openSurface === surface) {
            root.close();
            return;
        }
        root.openMon = mon;
        root.openSurface = surface;
    }

    function close() {
        if (root.openSurface === "launcher") {
            if (root.launcherClosePhase !== 0) return
            root.launcherClosePhase = 1
            launcherCloseResultsTimer.restart()
            return
        }
        if (root.openSurface === "auth") {
            if (Auth.sudoActive) Auth.cancelSudo()
            if (Auth.active) Auth.cancel()
        }
        root.openMon = "";
        root.openSurface = "";
    }

    Timer {
        id: launcherCloseResultsTimer
        interval: Motion.standard
        repeat: false
        onTriggered: {
            if (root.openSurface !== "launcher" || root.launcherClosePhase !== 1) return
            root.launcherClosePhase = 2
            launcherClosePillTimer.restart()
        }
    }

    Timer {
        id: launcherClosePillTimer
        interval: Motion.morph
        repeat: false
        onTriggered: {
            if (root.openSurface !== "launcher" || root.launcherClosePhase !== 2) return
            root.openMon = ""
            root.openSurface = ""
            root.launcherClosePhase = 0
        }
    }

    function peek(mon) {
        root.peekMon = root.peekMon === mon ? "" : mon;
    }

    IpcHandler {
        target: "island"
        function clock(mon: string): bool     { root.toggleSurface(mon, "calendar"); return true; }
        function calendar(mon: string): bool   { root.toggleSurface(mon, "calendar"); return true; }
        function mixer(mon: string): bool      { root.toggleSurface(mon, "mixer"); return true; }
        function media(mon: string): bool {
            if (Players.list.length > 0) {
                root.toggleSurface(mon, "media");
                return true;
            }
            return false;
        }
        function workspaces(mon: string): bool { root.toggleSurface(mon, "workspaces"); return true; }
        function notifs(mon: string): bool   { root.toggleSurface(mon, "notifs"); return true; }
        function wallpaper(mon: string): bool { root.toggleSurface(mon, "wallpaper"); return true; }
        function launcher(mon: string): bool { root.toggleSurface(mon, "launcher"); return true; }
        /** Clipboard history (cliphist). Super+V por defecto. */
        function clipboard(mon: string): bool { root.toggleSurface(mon, "clipboard"); return true; }
        /** Utilities (KeepAwake + Brillo + QuickToggles). Super+U por defecto. */
        function utils(mon: string): bool { root.toggleSurface(mon, "utils"); return true; }
        /** Connectivity panel: Wi-Fi + Bluetooth completo. */
        function connectivity(mon: string): bool { root.toggleSurface(mon, "connectivity"); return true; }
        /** Session menu: logout/shutdown/reboot/lock. Super+M abre el panel. */
        function session(mon: string): bool { root.toggleSurface(mon, "session"); return true; }
        function peek(mon: string): bool       { root.peek(mon); return true; }
        function hide(): bool                  { root.close(); return true; }
        /** Abre cualquier surface por nombre — puerta para scripting. */
        function page(mon: string, name: string): bool { root.toggleSurface(mon, name); return true; }
        /** Overview (alt+tab estilo windows): surface de la pill con mini-ventanas
         *  vivas + navegación por teclado. Toggle con `qs -c bar ipc call island
         *  overview ""` (Super+Tab). Mientras está abierto el overlay toma foco de
         *  teclado Exclusive → Tab/flechas ciclan ventanas, Enter focusa, Esc sale. */
        function overview(mon: string): bool { root.toggleSurface(mon, "overview"); return true; }
        /** Recarga los colores de pywal tras un cambio de wallpaper.
         *  Lo invoca el script de setWallpaper via:
         *  qs -c bar ipc call island reloadColors "" */
        function reloadColors(): bool { IslaPalette.forceReload(); return true; }
        /** Recarga completa de quickshell (hard reload). Útil si algo se congela.
         *  qs -c bar ipc call island reload */
        function reload(): bool { Quickshell.reload(true); return true; }
    }

    // ---- reserve (struts, click-through) ----
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: reserve
            required property var modelData
            readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
            readonly property real topGap: 8 * Flags.topGap * s
            readonly property real restHeight: 38 * s
            /** trim del aire pill→ventana sin tocar gaps_out del desktop. */
            readonly property real reservedH: Math.max(0, restHeight + topGap - 12 * (1 - Flags.appGap) * s)

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: reservedH
            aboveWindows: true

            anchors { top: true; left: true; right: true }
            implicitHeight: reservedH

            mask: emptyReserve
            Region { id: emptyReserve }
        }
    }

    // ---- overlay (Pill + mask tri-estado) ----
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            required property var modelData
            readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
            readonly property real topGap: 8 * Flags.topGap * s
            readonly property string surface: root.openMon === modelData.name ? root.openSurface : ""
            readonly property bool surfaceOpen: surface.length > 0
            readonly property bool overviewOpen: surface === "overview"
            readonly property bool wallpaperOpen: surface === "wallpaper"
            readonly property bool launcherOpen: surface === "launcher"
            readonly property bool launcherClosing: launcherOpen && root.launcherClosePhase !== 0
            readonly property bool launcherReturning: launcherOpen && root.launcherClosePhase === 2
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
                if (root.openMon === modelData.name) root.close();
                if (root.peekMon === modelData.name) root.peekMon = "";
            }

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            // Spotlight necesita poseer el teclado de forma determinista. El modo
            // OnDemand (usado por `focusable`) depende de la ventana previa y a
            // veces no recibe ni texto ni Escape en Hyprland.
            WlrLayershell.keyboardFocus: overlay.launcherOpen && !overlay.launcherClosing
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
                x: pill.x + (pill.width - baseW) / 2
                y: pill.y
                width: baseW
                height: baseH
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
                        var inside = mouse.x >= pillRegion.x && mouse.x <= pillRegion.x + pillRegion.width
                                  && mouse.y >= pillRegion.y && mouse.y <= pillRegion.y + pillRegion.height;
                        if (!inside) root.close();
                    } else {
                        root.peekMon = "";
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
                enabled: overlay.surfaceOpen
                onActivated: root.close()
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
                    running: overlay.kbFocusWanted
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
                    var it = pill.surfaceItem
                    if ((event.modifiers & Qt.MetaModifier) && event.key === Qt.Key_Tab) {
                        root.close(); event.accepted = true; return
                    }
                    // ESC cierra cualquier surface abierta (notifs, calendar, mixer…)
                    if (event.key === Qt.Key_Escape) {
                        root.close(); event.accepted = true; return
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

            // Normal surfaces share this focus scope, but the auth field must
            // own keyboard focus itself or sudo's askpass bridge receives no
            // characters and exits with "no password provided".
            Timer {
                id: authFocusTimer
                interval: Motion.morph + 120
                repeat: false
                running: overlay.surface === "auth" && !overlay.monFullscreen
                onTriggered: {
                    if (overlay.surface !== "auth" || overlay.monFullscreen) return
                    if (pill.surfaceItem) {
                        if (pill.surfaceItem.focusInput)
                            pill.surfaceItem.focusInput()
                        else {
                            pill.surfaceItem.focus = true
                            pill.surfaceItem.forceActiveFocus()
                        }
                        console.log("[Auth] auth focus requested, active:",
                            pill.surfaceItem.activeFocus)
                    } else {
                        restart()
                    }
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
                                       (overlay.height - pill.surfaceSize.launcher.height * overlay.s) / 2)
                        : overlay.wallpaperOpen
                            ? Math.max(overlay.topGap * 2, 18 * overlay.s)
                            : overlay.topGap
                    anchors.horizontalCenter: parent.horizontalCenter

                    Behavior on anchors.topMargin {
                        NumberAnimation {
                            duration: Motion.morph
                            easing.type: Motion.easeMorph
                            easing.bezierCurve: Motion.morphCurve
                        }
                    }
                    s: overlay.s
                    screenName: overlay.modelData.name
                    surface: overlay.surface
                    launcherClosing: overlay.launcherClosing
                    launcherClosePhase: root.launcherClosePhase
                    forcePinned: root.peekMon === overlay.modelData.name

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

                    onRequestSurface: (name) => root.toggleSurface(overlay.modelData.name, name)
                    onRequestClose: root.close()

                    // ---- notification morph (Dynamic Island) ----
                    // La pill morfea para mostrar la notif activa (reemplaza Toast).
                    // Solo el monitor con foco muestra el morph; resto ve pill en reposo.
                    activeNotif: overlay.monitorIsFocused ? Notifs.activePopup : null
                }
            }
        }
    }

    // ---- Toast desactivado (reemplazado por morph de la pill) ----
    // Variants {
    //     model: Quickshell.screens
    //     Toast {}
    // }
}
