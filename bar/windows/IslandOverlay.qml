import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"
import "../components"
import "../Singletons"
import "../surfaces"
import "../body"

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
            && recordingCompanion.phase === "idle"
            && (!overlay.mediaOpen || !pill.surfaceOpen && pill.morphCloseness > 0.999)
        settleReady: pill.morphCloseness > 0.999
    }
    readonly property var mediaSurfaceItem: compact || pulledMedia ? pill.surfaceItem : fluidCompanion.surfaceItem
    readonly property real lateralAvailable: Math.max(0, compact ? Math.min(500 * s, (width - pill.restCenterWidth - 72 * s) / 2)
        : (width - Math.max(pill.width, pill.targetW)) / 2 - 48 * s)
    readonly property real recordingLeftBoundary: !compact && sideModules.workspaceModule.active
        ? sideModules.x + sideModules.workspaceModule.x + sideModules.workspaceModule.width + 12 * s : 12 * s
    readonly property bool recordingHasRoom: Math.min(pill.x, (width - Math.max(pill.width, pill.targetW)) / 2)
        - recordingLeftBoundary >= Math.max(recordingCompanion.compactWidth, recordingCompanion.hoverWidth) + recordingCompanion.gap
    readonly property string surface: router.openMon === modelData.name ? router.openSurface : ""
    readonly property bool surfaceOpen: surface.length > 0
    readonly property bool overviewOpen: surface === "overview"
    property bool pulledMedia: false
    property bool recordingFromDrop: false
    property bool notificationFromDrop: false
    // Tarjeta de dispositivo (Bluetooth/USB): reutiliza el brote centrado de las
    // notificaciones, sólo en el monitor enfocado y cediendo ante una notificación.
    readonly property bool deviceCardShown: monitorIsFocused && !!DeviceMoments.card
        && (DeviceMoments.cardOpen || DeviceMoments.returning) && !pill.notifDropOpen && !notificationFromDrop
    readonly property bool deviceCardOpen: deviceCardShown && DeviceMoments.cardOpen
    property bool notificationDropOpening: false
    readonly property var pullSettings: Config._effective.gestures
    readonly property bool pullMediaVisible: router.mediaAvailable && Players.has
        && (mediaOpen || (compact ? sideModules.mediaModule.interactive : fluidCompanion.visible && fluidCompanion.open))
    readonly property string pullTarget: pill.pullGesture.resolveTarget(pullSettings.pullTarget, pullMediaVisible, Activities.hasLive)
    function togglePull(target) {
        const visibleMedia = pullMediaVisible
        if (target === "auto") target = pullTarget
        if (target === "focus" && Activities.hasLive) Activities.requestList = true
        const wantsMedia = target === "media" || target === "auto" && visibleMedia
        if (wantsMedia) pulledMedia = true
        const accepted = router.pull(modelData.name, target, target === "focus" ? surface !== "focus" : undefined, visibleMedia)
        if (!accepted && surface !== "media") pulledMedia = false
        return accepted
    }
    onSurfaceChanged: {
        if (surface !== "media") pulledMedia = false
        if (surface !== "recording" && surface !== "focus") recordingFromDrop = false
        if (surface !== "notifs") notificationFromDrop = false
    }
    readonly property bool mediaOpen: surface === "media"
    readonly property bool settingsOpen: surface === "settings"
    readonly property bool settingsReturning: !settingsOpen && settingsCompanion.active && surface !== "auth"
    property int profileRequest: 0
    readonly property bool settingsPickerOpen: settingsOpen && settingsCompanion.surfaceItem && settingsCompanion.surfaceItem.pathPickerOpen
    readonly property bool settingsClearsSearch: settingsOpen && settingsCompanion.surfaceItem
        && settingsCompanion.surfaceItem.escapeClearsSearch
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
    // Monitor de Hyprland de este overlay y su área de trabajo (descontando zonas reservadas).
    readonly property var hyprMonitor: {
        const list = Hyprland.monitors.values
        for (let i = 0; i < list.length; ++i) if (modelData && list[i].name === modelData.name) return list[i]
        return null
    }
    readonly property rect workArea: {
        const r = hyprMonitor && hyprMonitor.lastIpcObject && hyprMonitor.lastIpcObject.reserved
            ? hyprMonitor.lastIpcObject.reserved : [0, 0, 0, 0]
        return Qt.rect(r[0], r[1], Math.max(1, width - r[0] - r[2]), Math.max(1, height - r[1] - r[3]))
    }
    readonly property bool mediaDocking: router.mediaDockPendingMon === modelData.name
    readonly property bool launcherClosing: launcherOpen && router.launcherClosePhase !== 0
    readonly property bool launcherReturning: launcherOpen && router.launcherClosePhase === 2
    // El launcher es la propia pill: se recoge en gota, cae a su sitio y se abre;
    // al cerrar se recoge, sube y vuelve a ser la pill (LauncherDropMotion).
    readonly property bool launcherCardOpen: launcherOpen && !launcherClosing
    // Mientras viaja o asienta, la gota de media sigue absorbida en la pill.
    readonly property bool launcherFlightBusy: launcherDrop.active || launcherSettling
    // Tras volver arriba la pill aún se ensancha a su reposo: la gota de media
    // espera a que termine para no brotar contra una pill que crece.
    property bool launcherSettling: false
    function updateLauncherSettling() {
        if (launcherDrop.active) launcherSettling = true
        else if (launcherSettling && !launcherOpen && (pill.morphCloseness > 0.999 || pill.surfaceOpen))
            launcherSettling = false
    }
    onLauncherOpenChanged: updateLauncherSettling()
    Connections {
        target: launcherDrop
        function onActiveChanged() { overlay.updateLauncherSettling() }
    }
    Connections {
        target: pill
        function onMorphClosenessChanged() { overlay.updateLauncherSettling() }
        function onSurfaceOpenChanged() { overlay.updateLauncherSettling() }
    }
    LauncherDropMotion {
        id: launcherDrop
        s: overlay.s
        open: overlay.launcherCardOpen
        reduceMotion: Flags.reduceMotion
        // Mismo sitio que el launcher anclado arriba de antes: centrado en pantalla.
        landing: Math.max(overlay.topGap * 2, (overlay.height - IslandGeometry.launcherSurface.height * overlay.s) / 2)
            - overlay.topGap
        dropSize: pill.dropSize
        pillW: pill.width
        pillH: pill.height
        holdAtTop: !overlay.compact && fluidCompanion.active
    }
    OverlayInputPolicy {
        id: inputPolicy
        objectName: "islandInputPolicy"
        monitorName: overlay.modelData ? overlay.modelData.name : ""
        focusedMonitorName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        monitors: Hyprland.monitors.values
        surface: overlay.surface
        launcherClosing: overlay.launcherClosing
        pointerPull: (pill.pullGesture.candidate || pill.pullGesture.active) && !pill.pullGesture.scrolling
        wheelHold: pill.pullGesture.scrolling && pill.pullGesture.wasOpen
            || fluidCompanion.gestureCandidate || recordingCompanion.gestureCandidate || sessionCompanion.gestureCandidate || notificationCompanion.gestureCandidate
        pillX: pill.x; pillY: pill.y
        pillWidth: pill.width; pillHeight: pill.height
        pillTargetW: pill.targetW; pillTargetH: pill.targetH
        mediaActive: !overlay.compact && fluidCompanion.active
        mediaX: fluidCompanion.xPos; mediaY: fluidCompanion.yPos
        mediaW: fluidCompanion.wPos; mediaH: fluidCompanion.hPos
        recordingActive: recordingCompanion.active && !overlay.monFullscreen
        recordingX: recordingCompanion.visualX; recordingY: recordingCompanion.yPos
        recordingW: recordingCompanion.wPos; recordingH: recordingCompanion.hPos
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
    // Un solo progreso para retirar pill y gotas en fullscreen: antes la pill
    // se deslizaba/desvanecía y las gotas desaparecían de golpe, quedando
    // sueltas. Con reduceMotion se resuelve sin recorrido.
    property real fullscreenHide: monFullscreen ? 1 : 0
    Behavior on fullscreenHide {
        enabled: !Flags.reduceMotion
        NumberAnimation {
            duration: Motion.morph
            easing.type: Motion.easeMorph
            easing.bezierCurve: Motion.morphCurve
        }
    }
    readonly property real fullscreenLift: -fullscreenHide * (pill.height + topGap)

    function dismissInFullscreen() {
        if (monFullscreen) router.dismissMonitor(modelData.name)
    }
    onMonFullscreenChanged: dismissInFullscreen()
    Connections {
        target: router
        function onOpenSurfaceChanged() { Qt.callLater(overlay.dismissInFullscreen) }
        function onOpenMonChanged() { Qt.callLater(overlay.dismissInFullscreen) }
        function onMediaDockPendingMonChanged() { Qt.callLater(overlay.dismissInFullscreen) }
        function onPeekMonChanged() { Qt.callLater(overlay.dismissInFullscreen) }
    }

    screen: modelData
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // Every modal surface must receive keyboard input without a preliminary click.
    WlrLayershell.keyboardFocus: inputPolicy.exclusiveFocus
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
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
            x: notificationCompanion.visualX; y: notificationCompanion.yPos
            width: notificationCompanion.active ? notificationCompanion.wPos : 0
            height: notificationCompanion.active ? notificationCompanion.hPos : 0
        }
        Region {
            x: messenger.hitItem.x; y: messenger.hitItem.y
            width: messenger.acceptsClick ? messenger.hitItem.width : 0
            height: messenger.acceptsClick ? messenger.hitItem.height : 0
            shape: RegionShape.Ellipse
        }
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
    // The dim stays below the compositor's blur threshold (layer rule ignore_alpha 0.15):
    // crossing it switched a full-screen blur on or off in a single frame. A whole-screen
    // change also starts and ends gently; a decelerating curve put a quarter of it in frame one.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, Theme.shadowOpacity > 0 ? 0.4 : 0.36)
        opacity: overlay.overviewOpen ? 0.34 : 0
        visible: opacity > 0.005
        z: 0
        Behavior on opacity {
            NumberAnimation { duration: Motion.standardLarge; easing.type: Easing.InOutSine }
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
        enabled: inputPolicy.escapeShortcutEnabled && !overlay.settingsPickerOpen && !overlay.mixerPopupOpen && !overlay.settingsClearsSearch
        onActivated: overlay.dismissSurface()
    }
    Shortcut {
        sequence: "Meta+I"
        enabled: overlay.settingsOpen && !overlay.settingsPickerOpen
        onActivated: router.close()
    }

    FocusScope {
        id: focusScope
        objectName: "islandOverlayContent"
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
            onPointChanged: {
                pill.pointerX = point.position.x
                pill.pointerY = point.position.y
            }
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
            // Depth: while a surface owns attention the side modules recede a step (opacity only,
            // no travel, so reduceMotion keeps it); each module composites as one layer meanwhile.
            property real lateralDepth: !overlay.compact && pill.surfaceOpen && !pill.launcherReturning ? 0.82 : 1
            Behavior on lateralDepth { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            depth: lateralDepth
            opacity: !overlay.compact ? 1 : pill.opacity * ((!pill.surfaceOpen || pill.launcherReturning)
                && !pill.notifMorphing ? pill.morphRestReturn
                    * Math.max(0, Math.min(1, (pill.width - pill.restW + 40 * overlay.s) / (40 * overlay.s))) : 0)
            s: overlay.s
            screenName: overlay.modelData.name
            availableWidth: overlay.lateralAvailable
            centerWidth: pill.restCenterWidth
            presented: !overlay.layoutChanging && inputPolicy.sideModulesPresented && (!overlay.compact || !pill.notifMorphing)
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

    BodyMessenger {
        id: messenger
        objectName: "bodyMessenger"
        anchors.fill: parent
        z: 1
        hitParent: overlay.contentItem
        engine: pill.bodyPresentation.engine
        bodyShader: pill.bodyPresentation.shader
        bodyOrigin: Qt.point(pill.x + pill.bodyPresentation.x - pill.bodyPresentation.margin,
            pill.y + pill.bodyPresentation.y - pill.bodyPresentation.margin)
        reduceMotion: Flags.reduceMotion
        acceptFiles: Config.appearance.personality && Config.appearance.bodyMessenger === true
        enabled: acceptFiles && pill.bodyPresentation.resting && pill.bodyPresentation.running
            && pill.bodyPresentation.shaderSupported && !pill.bodyPresentation.shaderFailed
            && !overlay.monFullscreen
    }
    Binding { target: pill.bodyPresentation; property: "messengerActive"; value: messenger.shaderActive }
    Binding { target: pill.bodyPresentation; property: "docked"; value: messenger.docked }
    Binding { target: pill.bodyPresentation; property: "dock"; value: messenger.dock }
    Binding { target: pill.bodyPresentation; property: "dockHovered"; value: messenger.dockHovered }
    Binding { target: pill.bodyPresentation; property: "dockPressed"; value: messenger.dockPressed }
    Binding { target: messenger; property: "dockProgress"; value: pill.bodyPresentation.dockProgress }
    Connections {
        target: overlay.router
        function onFileActivationRequested(monitor) {
            if (monitor === overlay.modelData.name) messenger.activate()
        }
        function onFileOffered(monitor, path) {
            if (monitor === overlay.modelData.name) messenger.offerFile(path)
        }
    }
    Connections {
        target: Recording
        function onSaved(path) {
            const monitor = overlay.router.focusedMonitorName || (Quickshell.screens.length ? Quickshell.screens[0].name : "")
            if (monitor === overlay.modelData.name) messenger.offerFile(path)
        }
    }

    Pill {
            id: pill
            objectName: "islandPill"
            z: overlay.surface === "auth" ? 5 : 2
            anchors.top: parent.top
            // El launcher viaja con la pill: launcherDrop.offset la baja como gota
            // hasta el centro de la pantalla y la vuelve a subir al cerrar.
            // El wallpaper da un respiro extra bajo el borde superior para
            // NO parecer un dock pegado a la pantalla (actúa flotante).
            anchors.topMargin: (overlay.wallpaperOpen
                ? Math.max(overlay.topGap * 2, 18 * overlay.s)
                : overlay.topGap) + launcherDrop.offset
            anchors.horizontalCenter: parent.horizontalCenter

            Behavior on anchors.topMargin {
                enabled: !Flags.reduceMotion && !launcherDrop.active && !overlay.launcherOpen
                SmoothedAnimation { duration: Motion.morph; velocity: -1 }
            }
            s: overlay.s
            screenName: overlay.modelData.name
            notificationExternalSettling: notificationCompanion.active && !notificationCompanion.settled
            recordingDetached: recordingCompanion.open || recordingCompanion.active
            companionBlocked: overlay.launcherOpen || overlay.launcherFlightBusy || overlay.surface === "auth"
            companionCodeFocused: {
                const top = Hyprland.activeToplevel
                const app = top && top.lastIpcObject ? String(top.lastIpcObject.class || "").toLowerCase() : ""
                return /(^|[. -])(kitty|alacritty|foot|wezterm|ghostty|konsole|code|codium|zed|neovide|emacs|terminal)([. -]|$)/.test(app)
            }
            layoutChanging: overlay.layoutChanging
            interactionOpen: overlay.surfaceOpen
            restHeight: overlay.compact ? IslandGeometry.compactRestHeight : IslandGeometry.restHeight
            restLeftWidth: overlay.compact ? sideModules.leftWidth : 0
            restRightWidth: overlay.compact ? sideModules.rightWidth : 0
            surface: (overlay.mediaOpen && !overlay.pulledMedia && (!overlay.compact || overlay.layoutChanging)) || overlay.sessionOpen || overlay.settingsOpen || overlay.settingsReturning
                || overlay.notificationFromDrop && overlay.surface === "notifs"
                || overlay.recordingFromDrop && (overlay.surface === "recording" || overlay.surface === "focus") ? "" : overlay.surface
            launcherClosing: overlay.launcherClosing
            launcherClosePhase: router.launcherClosePhase
            dropMode: launcherDrop.dropMode
            forcePinned: router.peekMon === overlay.modelData.name
            fluidCompanion0: fluidCompanion
            fluidCompanion1: sessionCompanion
            fluidCompanion2: settingsCompanion
            fluidCompanion3: recordingCompanion
            fluidCompanion4: notificationCompanion
            fluidJoined: (!overlay.compact && (!overlay.surfaceOpen || overlay.sessionOpen) && fluidCompanion.joined)
                || sessionCompanion.joined || settingsCompanion.joined || recordingCompanion.joined
                || notificationCompanion.joined
            fluidEdgeExposure: Math.min(
                !overlay.compact && (!overlay.surfaceOpen || overlay.sessionOpen) ? fluidCompanion.edgeExposure : 1,
                sessionCompanion.edgeExposure, settingsCompanion.edgeExposure, recordingCompanion.edgeExposure,
                notificationCompanion.edgeExposure)
            fluidCaptureExtra: settingsCompanion.active ? settingsCompanion.captureExtra
                : overlay.compact || overlay.surfaceOpen && !overlay.sessionOpen ? 0 : fluidCompanion.captureExtra
            fluidCaptureLeftExtra: Math.max(sessionCompanion.captureExtra, recordingCompanion.captureExtra)
            opacity: 1 - overlay.fullscreenHide
            visible: opacity > 0.005
            transform: Translate { y: overlay.fullscreenLift }

            pullEnabled: overlay.pullSettings.enabled && !overlay.sessionOpen && !overlay.settingsOpen
                && !overlay.settingsReturning && !overlay.monFullscreen
                && !launcherDrop.dropMode && !launcherDrop.moving
                && (overlay.surfaceOpen || overlay.pullTarget !== "media" || overlay.router.mediaAvailable)
            pullTarget: overlay.pullTarget
            onPullPrepare: name => {
                if (name === "media") overlay.pulledMedia = true
                if (name === "focus" && Activities.hasLive) Activities.requestList = true
                // Deferred: pointer/wheel handlers emit this mid-delivery, and
                // swapping surfaces there frees items Qt is still iterating.
                Qt.callLater(() => overlay.router.pull(overlay.modelData.name, name, true))
            }
            onPullSettled: (name, opened) => {
                if (name === "media" && opened) overlay.pulledMedia = true
                Qt.callLater(() => overlay.router.pull(overlay.modelData.name, name, opened))
            }
            onRequestSurface: (name) => router.toggleSurface(overlay.modelData.name, name)
            onRequestClose: router.close()

            // ---- notification morph (Dynamic Island) ----
            // La pill morfea para mostrar la notif activa (reemplaza Toast).
            // Solo el monitor con foco muestra el morph; resto ve pill en reposo.
            notificationsEnabled: overlay.monitorIsFocused
        }

        // Las apps nacen de la isla: la gota del icono lanzado vuela hasta su ventana.
        // Sólo dibuja durante el vuelo; no captura entrada ni toca la máscara.
        LaunchFlight {
            id: launchFlight
            objectName: "islandLaunchFlight"
            anchors.fill: parent
            z: 3
            s: overlay.s
            monitorName: overlay.modelData ? overlay.modelData.name : ""
            fullscreen: overlay.monFullscreen
            bodyX: pill.x; bodyY: pill.y
            bodyW: pill.width; bodyH: pill.height
            bodyRadius: pill.morphRadius
            workArea: overlay.workArea
            workspaceTarget: sideModules.workspaceModule.active
                ? Qt.rect(sideModules.x + sideModules.workspaceModule.x, sideModules.y + sideModules.workspaceModule.y,
                          sideModules.workspaceModule.width, sideModules.workspaceModule.height)
                : Qt.rect(0, 0, 0, 0)
            visibleWorkspaceId: overlay.hyprMonitor && overlay.hyprMonitor.activeWorkspace ? overlay.hyprMonitor.activeWorkspace.id : -1
            Connections {
                target: Apps
                function onLaunchAnnounced(info) {
                    if (overlay.launcherOpen) launchFlight.begin(info)
                }
            }
        }

        FluidRecordingCompanion {
            id: recordingCompanion
            objectName: "islandRecordingCompanion"
            anchors.fill: parent
            z: 3
            body: pill
            waterBody: pill.bodyPresentation
            leftSide: true
            s: overlay.s
            screenName: overlay.modelData.name
            recordingActive: Recording.engaged
            focusRemainingSeconds: FocusSession.remainingSeconds
            activity: Activities.primary
            activityCount: Activities.count
            recordingPhase: Recording.uncertain ? "unknown" : Recording.phase
            elapsedText: Recording.timeText
            tallBar: overlay.compact
            countdown: Recording.countdown
            focusActive: !Recording.engaged && FocusSession.active
            open: (Recording.engaged || FocusSession.active || Activities.count > 0) && !overlay.layoutChanging && !overlay.monFullscreen
                && overlay.recordingHasRoom && !overlay.sessionOpen && sessionCompanion.phase === "idle"
                && !overlay.settingsOpen && settingsCompanion.phase === "idle"
            bodyBusy: pill.surfaceOpen || pill.notifMorphing
            opacity: 1 - overlay.fullscreenHide
            transform: Translate { y: overlay.fullscreenLift }
            gesturesEnabled: overlay.pullSettings.enabled
            expanded: overlay.recordingFromDrop && (overlay.surface === "recording" || overlay.surface === "focus")
            onRequestOpen: name => {
                if (Activities.count > 0) Activities.requestList = true
                if (router.openFromDrop(overlay.modelData.name, name)) overlay.recordingFromDrop = true
            }
            onRequestRecording: {
                if (Activities.count > 0) Activities.requestList = true
                router.toggleSurface(overlay.modelData.name, recordingCompanion.surfaceName)
            }
        }

        FluidCompanion {
            id: sessionCompanion
            anchors.fill: parent
            z: 3
            body: pill
            waterBody: pill.bodyPresentation
            leftSide: true
            gesturesEnabled: overlay.pullSettings.enabled
            onRequestOpen: name => router.openFromDrop(overlay.modelData.name, name)
            surfaceName: "session"
            surfaceSize: IslandGeometry.sessionSurface
            open: overlay.sessionOpen && !overlay.settingsReturning && recordingCompanion.phase === "idle"
            expanded: overlay.sessionOpen && !overlay.settingsReturning
            bodyBusy: pill.surfaceOpen || pill.notifMorphing
            s: overlay.s
            screenName: overlay.modelData.name
            opacity: 1 - overlay.fullscreenHide
            transform: Translate { y: overlay.fullscreenLift }
            onRequestToggle: { if (overlay.sessionOpen) router.close() }
        }

        FluidCompanion {
            id: settingsCompanion
            anchors.fill: parent
            z: overlay.settingsReturning ? 1 : 4
            body: pill
            waterBody: pill.bodyPresentation
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
            bodyBusy: pill.surfaceOpen || pill.notifMorphing
            s: overlay.s
            screenName: overlay.modelData.name
            opacity: 1 - overlay.fullscreenHide
            transform: Translate { y: overlay.fullscreenLift }
            onRequestToggle: { if (overlay.settingsOpen) router.close() }
        }

        // Informational notifications bud below the pill; it keeps its content.
        // Its gesture keeps the same focus/mask capture as the pill and side drops.
        FluidCompanion {
            id: notificationCompanion
            objectName: "islandNotificationCompanion"
            anchors.fill: parent
            z: 5
            body: pill
            waterBody: pill.bodyPresentation
            centered: true
            below: true
            springRate: 1.5
            surfaceName: overlay.deviceCardShown ? "device" : overlay.notificationFromDrop ? "notifs" : "notification"
            surfaceSize: overlay.deviceCardShown ? Qt.size(380, DeviceMoments.card && DeviceMoments.card.kind === "storage" ? 112 : 84)
                : overlay.notificationFromDrop ? IslandGeometry.notificationsSurface : Qt.size(380, 72)
            property QtObject notificationDragMotion: QtObject {
                property real width: notificationCompanion.wPos
                property real height: notificationCompanion.hPos
                property real radius: notificationCompanion.cardRadius
                property real coreH: notificationCompanion.moduleH
                property real restW: coreH
                property bool integrating: !notificationCompanion.settled
                property real velW: notificationCompanion.vw
                property real velH: notificationCompanion.vh
                property bool grabbed: false
                property bool gestureSpring: false
                property real grabW: width
                property real grabH: height
                property real grabRadius: radius
                property real grabProgress: 0
                function grab() {
                    grabW = width; grabH = height; grabRadius = radius
                    grabbed = true
                }
                onGrabWChanged: if (grabbed) {
                    notificationCompanion.wPos = grabW
                    notificationCompanion.xPos = notificationCompanion.bodyX + (notificationCompanion.bodyW - grabW) / 2
                }
                onGrabHChanged: if (grabbed) notificationCompanion.hPos = grabH
                function release(vw, vh, gesture) {
                    notificationCompanion.vw = vw; notificationCompanion.vh = vh
                    grabbed = false
                    notificationCompanion.gestureCandidate = false
                }
            }
            expandedContentDelay: 0.6
            expandedContent: overlay.deviceCardShown ? deviceContent : overlay.notificationFromDrop ? null : notificationContent
            Component {
                id: deviceContent
                DeviceMomentCard {
                    readonly property var moment: DeviceMoments.card
                    readonly property bool isStorage: !!moment && moment.kind === "storage"
                    s: overlay.s
                    pillWidth: notificationCompanion.cardW
                    pillHeight: notificationCompanion.cardH
                    closeness: 1
                    kind: isStorage ? "storage" : "bluetooth"
                    glyph: isStorage ? "usb" : moment ? (DeviceMoments.kindGlyphs[moment.deviceKind] || "bluetooth") : "bluetooth"
                    title: moment ? moment.name : ""
                    subtitle: isStorage ? moment.sizeLabel : ""
                    batteries: moment && !isStorage ? DeviceMoments.batteriesOf(moment.device) : []
                    ejectState: DeviceMoments.cardState
                    errorText: DeviceMoments.cardError
                    onHoverChanged: hovered => DeviceMoments.cardHovered = hovered
                    onActivated: DeviceMoments.activateCard()
                    onOpenRequested: DeviceMoments.openMount()
                    onEjectRequested: DeviceMoments.eject()
                }
            }
            Component {
                id: notificationContent
                IslandNotification {
                    gestureMotion: notificationCompanion.notificationDragMotion
                    gesturesEnabled: overlay.pullSettings.enabled
                    onGestureStarted: {
                        notificationCompanion.gestureCandidate = true
                        pill.pauseNotification()
                    }
                    onGestureFinished: action => {
                        if (action === "open") {
                            overlay.notificationDropOpening = true
                        }
                        pill.finishNotification(action)
                    }
                    onGestureSettled: (name, opened) => {
                        if (opened) Qt.callLater(() => {
                            overlay.notificationFromDrop = true
                            overlay.router.pull(overlay.modelData.name, "notifs", true)
                            overlay.notificationDropOpening = false
                            notificationCompanion.bloom()
                        })
                    }

                    notification: pill.activeNotif
                    s: overlay.s
                    pillWidth: notificationCompanion.cardW
                    pillHeight: notificationCompanion.cardH
                    closeness: 1
                    iconResolved: pill._notifIconResolved
                    iconSource: pill.notificationIcon
                }
            }
            retainExpandedContent: true
            open: pill.notifDropOpen || overlay.notificationFromDrop || overlay.notificationDropOpening || overlay.deviceCardOpen
            expanded: pill.notifDropOpen || overlay.notificationFromDrop || overlay.notificationDropOpening || overlay.deviceCardOpen
            bodyBusy: pill.surfaceOpen
            s: overlay.s
            screenName: overlay.modelData.name
            opacity: 1 - overlay.fullscreenHide
            transform: Translate { y: overlay.fullscreenLift }
        }

        // Contexto de prioridad para los momentos de dispositivo: sólo el monitor
        // enfocado lo publica y sólo él los muestra.
        Binding {
            target: DeviceMoments
            property: "context"
            when: overlay.monitorIsFocused
            value: ({
                surfaceOpen: overlay.surfaceOpen,
                fullscreen: overlay.monFullscreen,
                gesture: inputPolicy.pointerPull,
                notification: !!pill.activeNotif || pill.notifDropOpen,
                dnd: Notifs.dnd
            })
        }
        Connections {
            target: DeviceMoments
            enabled: overlay.monitorIsFocused
            function onNoticeRequested(text, kind) { pill.notice(text, kind) }
            function onSurfaceRequested(surface) { router.toggleSurface(overlay.modelData.name, surface) }
        }
        Connections {
            target: pill
            function onNotifDropOpenChanged() { if (pill.notifDropOpen) DeviceMoments.interrupt() }
        }

        FluidMediaCompanion {
            id: fluidCompanion
            objectName: "islandMediaCompanion"
            z: fluidCompanion.cardFraction > 0.05 ? 3 : 1
            opacity: overlay.compact ? 0 : 1 - overlay.fullscreenHide
            transform: Translate { y: overlay.fullscreenLift }
            visible: opacity > 0.005
            anchors.fill: parent
            body: pill
            waterBody: pill.bodyPresentation
            gesturesEnabled: overlay.pullSettings.enabled
            onRequestOpen: name => router.openFromDrop(overlay.modelData.name, name)
            open: !dismissedUntilTrackChange && !overlay.pulledMedia && !overlay.layoutChanging && !overlay.compact && (Players.has || overlay.mediaOpen) && !overlay.launcherOpen && !overlay.launcherFlightBusy && !overlay.mediaPanelOpen
                && !overlay.mediaPanelReturning && !overlay.mediaDocking
            // Once the drop is concealed inside the body the dock is visually done;
            // its hidden springs settling to idle used to hold the launcher ~0.5 s.
            // The returning drop's content is gone once its centre is inside the
            // body; a surface growing in place covers the rest, so waiting for the
            // capture to stretch around it only held it ~0.2 s. The launcher carries
            // the body away from the top row and must wait until the drop is hidden.
            readonly property bool docked: phase === "idle" || phase === "absorbiendo" && concealed
                || phase === "retornando" && contentExposure <= 0 && router.mediaDockPendingSurface !== "launcher"
            onDockedChanged: if (docked && overlay.mediaDocking)
                Qt.callLater(() => router.finishMediaDock(overlay.modelData.name))
            // Safety net: a dock that never conceals must not hold the surface.
            Timer {
                interval: 900
                running: overlay.mediaDocking
                onTriggered: router.finishMediaDock(overlay.modelData.name)
            }
            Connections {
                target: overlay
                function onMediaDockingChanged() {
                    if (overlay.mediaDocking && fluidCompanion.docked)
                        Qt.callLater(() => router.finishMediaDock(overlay.modelData.name))
                }
            }
            expanded: !overlay.pulledMedia && !overlay.layoutChanging && !overlay.compact && overlay.mediaOpen && !overlay.mediaDocking && !overlay.settingsReturning
            bodyBusy: overlay.surfaceOpen && !overlay.mediaOpen && !overlay.sessionOpen || pill.notifMorphing
            s: overlay.s
            screenName: overlay.modelData.name
            onRequestMedia: router.toggleSurface(overlay.modelData.name, "media")
        }
    }
}
