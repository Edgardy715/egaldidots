import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"
import "../components"
import "../Singletons"
import "../surfaces"

PanelWindow {
    id: overlay
    required property SurfaceRouter router
    required property var modelData
    readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
    readonly property real topGap: 8 * Flags.topGap * s
    readonly property bool compact: layoutTransition.compact
    readonly property bool layoutChanging: layoutTransition.active
    readonly property int layoutPhase: layoutTransition.phase
    readonly property bool layoutContentWithdrawn: sideModules.withdrawn && pill.restHeaderOpacity < 0.01
    BarLayoutTransition {
        id: layoutTransition
        requestedCompact: Config.appearance.barLayout === "compact"
        exitReady: overlay.layoutContentWithdrawn
            && fluidCompanion.phase === "idle"
            && (!overlay.mediaOpen || !pill.surfaceOpen && pill.morphCloseness > 0.999)
        settleReady: pill.morphCloseness > 0.999
    }
    readonly property var mediaSurfaceItem: compact ? pill.surfaceItem : fluidCompanion.surfaceItem
    readonly property real lateralAvailable: Math.max(0, compact ? Math.min(500 * s, (width - pill.restCenterWidth - 72 * s) / 2)
        : (width - Math.max(pill.width, pill.targetW)) / 2 - 48 * s)
    readonly property string surface: router.openMon === modelData.name ? router.openSurface : ""
    readonly property bool surfaceOpen: surface.length > 0
    readonly property bool overviewOpen: surface === "overview"
    readonly property bool mediaOpen: surface === "media"
    readonly property bool settingsOpen: surface === "settings"
    readonly property bool settingsReturning: !settingsOpen && settingsCompanion.active && surface !== "auth"
    property int profileRequest: 0
    readonly property bool settingsPickerOpen: settingsOpen && settingsCompanion.surfaceItem && settingsCompanion.surfaceItem.pathPickerOpen
    readonly property bool mixerPopupOpen: surface === "mixer" && pill.surfaceItem && !!pill.surfaceItem.popupOpen
    readonly property bool sessionOpen: surface === "session"
    readonly property bool wallpaperOpen: surface === "wallpaper"
    readonly property bool mediaPanelOpen: wallpaperOpen || overviewOpen
        || (surface === "calendar" && !settingsReturning)
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
    OverlayInputPolicy {
        id: inputPolicy
        monitorName: overlay.modelData ? overlay.modelData.name : ""
        focusedMonitorName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        monitors: Hyprland.monitors.values
        surface: overlay.surface
        launcherClosing: overlay.launcherClosing
        pillX: pill.x; pillY: pill.y
        pillWidth: pill.width; pillHeight: pill.height
        pillTargetW: pill.targetW; pillTargetH: pill.targetH
        mediaActive: !overlay.compact && fluidCompanion.active
        mediaX: fluidCompanion.xPos; mediaY: fluidCompanion.yPos
        mediaW: fluidCompanion.wPos; mediaH: fluidCompanion.hPos
        sessionActive: sessionCompanion.active
        sessionX: sessionCompanion.visualX; sessionY: sessionCompanion.yPos
        sessionW: sessionCompanion.wPos; sessionH: sessionCompanion.hPos
        settingsActive: overlay.settingsOpen && settingsCompanion.active
        settingsX: settingsCompanion.visualX; settingsY: settingsCompanion.yPos
        settingsW: settingsCompanion.wPos; settingsH: settingsCompanion.hPos
    }
    /** Este monitor es el que tiene foco (para que el overview/wallpaper sólo
     *  robe teclado en él y las flechas/Tab operen en la pantalla correcta). */
    readonly property bool monitorIsFocused: inputPolicy.monitorIsFocused
    /** Una surface abierta debe conservar siempre su ruta de cierre. No
     *  dependemos del monitor enfocado: una llamada IPC puede abrirla
     *  durante el mismo frame en que Hyprland aún no actualizó
     *  `focusedMonitor`, y eso dejaba ESC sin receptor. */
    readonly property bool kbFocusWanted: inputPolicy.kbFocusWanted
    // modal = agarra input full-screen + backdrop-dismiss. SOLO cuando una
    // surface real está abierta (overview/media/calendar/…). En reposo NUNCA:
    // ni hover ni peek capturan la pantalla (pill.pinned es sólo visual).
    // ANTES incluía `pill.pinned` → al hover de la pill el overlay ponía
    // fullRegion y toda la pantalla se tragaba clicks/scroll (el "mouse
    // congelado": el dismiss MouseArea se los comía; si el HoverHandler no
    // soltaba hovered, quedaba pegado para siempre). Tide-island usa unión
    // de regiones por-surface (nunca full-screen) — acá removemos la causa.
    readonly property bool modal: inputPolicy.modal

    /**
     * True mientras el workspace activo de este monitor tiene una
     * ventana en fullscreen real: la pill se retrae y la capa entera
     * es click-through. (defensivo: si lastIpcObject falta → false)
     */
    readonly property bool monFullscreen: inputPolicy.monFullscreen

    onMonFullscreenChanged: if (monFullscreen) {
        if (router.openMon === modelData.name) router.close();
        if (router.peekMon === modelData.name) router.peekMon = "";
    }

    screen: modelData
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // Every modal surface must receive keyboard input without a preliminary click.
    WlrLayershell.keyboardFocus: inputPolicy.exclusiveFocus
        ? WlrKeyboardFocus.Exclusive
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

    mask: inputPolicy.maskMode === "hidden" ? hiddenRegion : (inputPolicy.maskMode === "full" ? fullRegion : pillRegion)
    Region { id: hiddenRegion }
    Region {
        id: pillRegion
        readonly property real baseW: inputPolicy.baseW
        readonly property real baseH: inputPolicy.baseH
        x: inputPolicy.maskX
        y: inputPolicy.maskY
        width: inputPolicy.maskW
        height: inputPolicy.maskH
        onXChanged: changed()
        onYChanged: changed()
        onWidthChanged: changed()
        onHeightChanged: changed()
        Region {
            x: sideModules.x + sideModules.workspaceModule.x; y: sideModules.y + sideModules.workspaceModule.y
            width: sideModules.workspaceModule.interactive ? sideModules.workspaceModule.width : 0
            height: sideModules.workspaceModule.interactive ? sideModules.workspaceModule.height : 0
        }
        Region {
            x: sideModules.x + sideModules.userModule.x; y: sideModules.y + sideModules.userModule.y
            width: sideModules.userModule.interactive ? sideModules.userModule.width : 0
            height: sideModules.userModule.interactive ? sideModules.userModule.height : 0
        }
        Region {
            x: sideModules.x + sideModules.statusModule.x; y: sideModules.y + sideModules.statusModule.y
            width: sideModules.statusModule.interactive ? sideModules.statusModule.width : 0
            height: sideModules.statusModule.interactive ? sideModules.statusModule.height : 0
        }
        Region {
            x: sideModules.x + sideModules.mediaModule.x; y: sideModules.y + sideModules.mediaModule.y
            width: sideModules.mediaModule.interactive ? sideModules.mediaModule.width : 0
            height: sideModules.mediaModule.interactive ? sideModules.mediaModule.height : 0
        }
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
        enabled: overlay.surfaceOpen && !overlay.settingsPickerOpen
        acceptedButtons: Qt.AllButtons
        z: 0
        onPressed: (mouse) => {
            if (overlay.surfaceOpen) {
                if (inputPolicy.outsideBodies(mouse.x, mouse.y)) router.close();
            } else {
                router.peekMon = "";
            }
        }
    }

    // Askpass needs compositor-level focus, not just QML activeFocus.
    // Limit the grab to auth so ordinary surfaces keep their normal
    // click-through behavior.
    HyprlandFocusGrab {
        active: inputPolicy.authFocusGrab
        windows: [overlay]
    }

    function dismissSurface() {
        if (overlay.mediaOpen && overlay.mediaSurfaceItem && overlay.mediaSurfaceItem.lyricsOpen)
            overlay.mediaSurfaceItem.lyricsOpen = false
        else router.close()
    }

    // Atajo de respaldo a nivel de ventana: también cierra cuando una
    // surface (por ejemplo el TextInput del launcher) tiene el foco.
    Shortcut {
        sequence: "Escape"
        enabled: inputPolicy.escapeShortcutEnabled && !overlay.settingsPickerOpen && !overlay.mixerPopupOpen
        onActivated: overlay.dismissSurface()
    }
    Shortcut {
        sequence: "Meta+I"
        enabled: overlay.settingsOpen && !overlay.settingsPickerOpen
        onActivated: router.close()
    }

    FocusScope {
        id: focusScope
        anchors.fill: parent
        // Closed surfaces release keyboard input to the desktop.
        focus: overlay.kbFocusWanted
        onFocusChanged: if (focus) focusScope.forceActiveFocus()
        // re-grab de foco al asentar el morph: el primer forceActiveFocus()
        // puede correr antes de que el compositor otorgue teclado Exclusive
        // (race) y entonces Tab/flechas no llegarían. Re-clavamos una vez.
        Timer {
            running: overlay.kbFocusWanted && overlay.surface !== "auth"
            interval: Motion.morph + 40
            repeat: false
            onTriggered: if (overlay.kbFocusWanted) {
                if (!focusScope.activeFocus) focusScope.forceActiveFocus()
                if (overlay.settingsOpen && settingsCompanion.surfaceItem)
                    settingsCompanion.surfaceItem.activate()
            }
        }

        HoverHandler {
            parent: pill
            onHoveredChanged: pill.hovered = hovered
        }

        TopBarModules {
            id: sideModules
            objectName: "islandModules"
            x: overlay.compact ? pill.x : 0
            y: overlay.compact ? pill.y : 0
            width: overlay.compact ? pill.width : overlay.width
            height: overlay.compact ? pill.height : overlay.height
            z: overlay.compact ? 3 : 1
            compact: overlay.compact
            topGap: overlay.compact ? (height - 48 * overlay.s) / 2 : overlay.topGap
            opacity: !overlay.compact ? 1 : pill.opacity * ((!pill.surfaceOpen || pill.launcherReturning)
                && !pill.notifAnimating ? Math.pow(pill.morphCloseness, 1.2)
                    * Math.max(0, Math.min(1, (pill.width - pill.restW + 40 * overlay.s) / (40 * overlay.s))) : 0)
            s: overlay.s
            screenName: overlay.modelData.name
            availableWidth: overlay.lateralAvailable
            centerWidth: pill.restCenterWidth
            presented: !overlay.layoutChanging && inputPolicy.sideModulesPresented && (!overlay.compact || !pill.notifAnimating)
            onRequestSurface: name => {
                if (name === "profile") {
                    overlay.profileRequest++
                    if (!overlay.settingsOpen && router.mediaDockPendingSurface !== "settings")
                        router.toggleSurface(overlay.modelData.name, "settings")
                } else router.toggleSurface(overlay.modelData.name, name)
            }
        }

        // ---- navegación de teclado del overview ----
        // Tab recorre controles; →/↓ = siguiente ws · ←/↑ = anterior
        // h/l = izq/der · j/k = abajo/arriba (filas)
        // 1-9,0 = saltar al ws de la posición N del grupo
        // Enter/Space = ir al ws seleccionado · Esc = cerrar
        // Super+Tab = cerrar (toggle off, mismo bind que abrió)
        Keys.onPressed: (event) => {
            if (!overlay.surfaceOpen || overlay.settingsPickerOpen) return
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
                overlay.dismissSurface(); event.accepted = true; return
            }
            // La navegación por teclado (Tab/flechas/hjkl/números/Enter) solo
            // aplica al overview y al wallpaper picker.
            if (!overlay.overviewOpen && !overlay.wallpaperOpen) return
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) return
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
            if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_L || event.key === Qt.Key_J) dir = 1
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
            objectName: "islandPill"
            z: overlay.surface === "auth" ? 5 : 2
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
            layoutChanging: overlay.layoutChanging
            restHeight: overlay.compact ? IslandGeometry.compactRestHeight : IslandGeometry.restHeight
            restLeftWidth: overlay.compact ? sideModules.leftWidth : 0
            restRightWidth: overlay.compact ? sideModules.rightWidth : 0
            surface: (overlay.mediaOpen && (!overlay.compact || overlay.layoutChanging)) || overlay.sessionOpen || overlay.settingsOpen || overlay.settingsReturning ? "" : overlay.surface
            launcherClosing: overlay.launcherClosing
            launcherClosePhase: router.launcherClosePhase
            forcePinned: router.peekMon === overlay.modelData.name
            fluidJoined: (!overlay.compact && (!overlay.surfaceOpen || overlay.sessionOpen) && fluidCompanion.joined)
                || sessionCompanion.joined || settingsCompanion.joined
            fluidEdgeExposure: Math.min(
                !overlay.compact && (!overlay.surfaceOpen || overlay.sessionOpen) ? fluidCompanion.edgeExposure : 1,
                sessionCompanion.edgeExposure, settingsCompanion.edgeExposure)
            fluidCaptureExtra: settingsCompanion.active ? settingsCompanion.captureExtra
                : overlay.compact || overlay.surfaceOpen && !overlay.sessionOpen ? 0 : fluidCompanion.captureExtra
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
            open: overlay.sessionOpen && !overlay.settingsReturning
            expanded: overlay.sessionOpen && !overlay.settingsReturning
            bodyBusy: pill.surfaceOpen || pill.notifAnimating
            s: overlay.s
            screenName: overlay.modelData.name
            opacity: overlay.monFullscreen ? 0 : 1
            onRequestToggle: { if (overlay.sessionOpen) router.close() }
        }

        FluidCompanion {
            id: settingsCompanion
            anchors.fill: parent
            z: overlay.settingsReturning ? 1 : 4
            body: pill
            centered: true
            surfaceName: "settings"
            surfaceSize: IslandGeometry.settingsSurface
            expandedContent: Component {
                SettingsSurface {
                    profileRequest: overlay.profileRequest
                    s: overlay.s
                    open: overlay.settingsOpen || (settingsCompanion.active && settingsCompanion.cardContentProgress > 0.01)
                    closing: !overlay.settingsOpen
                    morphCloseness: settingsCompanion.cardContentProgress
                    onRequestClose: router.close()
                }
            }
            retainExpandedContent: true
            asynchronousExpandedContent: true
            open: overlay.settingsOpen
            expanded: overlay.settingsOpen
            bodyBusy: pill.surfaceOpen || pill.notifAnimating
            s: overlay.s
            screenName: overlay.modelData.name
            opacity: overlay.monFullscreen ? 0 : 1
            onRequestToggle: { if (overlay.settingsOpen) router.close() }
        }

        FluidMediaCompanion {
            id: fluidCompanion
            objectName: "islandMediaCompanion"
            z: fluidCompanion.cardFraction > 0.05 ? 3 : 1
            opacity: overlay.monFullscreen || overlay.compact ? 0 : 1
            anchors.fill: parent
            body: pill
            open: !overlay.layoutChanging && !overlay.compact && (Players.has || overlay.mediaOpen) && !overlay.launcherOpen && !overlay.mediaPanelOpen
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
            expanded: !overlay.layoutChanging && !overlay.compact && overlay.mediaOpen && !overlay.mediaDocking && !overlay.settingsReturning
            bodyBusy: overlay.surfaceOpen && !overlay.mediaOpen && !overlay.sessionOpen || pill.notifAnimating
            s: overlay.s
            screenName: overlay.modelData.name
            onRequestMedia: router.toggleSurface(overlay.modelData.name, "media")
        }
    }
}
