import QtQuick

// Surface navigation only. Environment services and windows belong to shell.qml.
QtObject {
    id: root
    property string focusedMonitorName: ""
    property string pendingFocusSurface: ""
    onFocusedMonitorNameChanged: {
        if (!focusedMonitorName || !pendingFocusSurface) return
        const surface = pendingFocusSurface
        pendingFocusSurface = ""
        toggleSurface(focusedMonitorName, surface)
    }
    property bool reduceMotion: false
    // Sin reproductor, Media sólo mostraría un estado vacío: no se abre.
    property bool mediaAvailable: true
    onReduceMotionChanged: if (reduceMotion && launcherClosePhase !== 0) close()
    property int resultsDuration: 250
    property int morphDuration: 420
    signal authCloseRequested()
    signal fileOffered(string monitor, string path)
    signal fileActivationRequested(string monitor)

    property string openMon: ""
    property string openSurface: ""
    property string peekMon: ""
    property string mediaDockPendingMon: ""
    property string mediaDockPendingSurface: ""
    // El launcher necesita dos fases de salida para que resultados → buscador →
    // pill sea una sola transición. Mientras dura, la surface sigue montada.
    property int launcherClosePhase: 0

    // An authentication request supersedes pending dock/open/close work.
    function present(mon, surface) {
        pendingFocusSurface = ""
        launcherCloseResultsTimer.stop()
        launcherClosePillTimer.stop()
        launcherClosePhase = 0
        mediaDockPendingMon = ""
        mediaDockPendingSurface = ""
        openMon = mon
        openSurface = surface
    }

    // Geometry and velocity belong to PillMorphMotion; navigation only sets intent.
    function pull(mon, surface, opened, visibleMedia) {
        if (!mon) mon = focusedMonitorName
        if (opened === undefined) {
            if (["auto", "utils", "media", "notifs", "calendar"].indexOf(surface) < 0) return false
            if (surface === "auto") surface = mediaAvailable && visibleMedia ? "media" : "utils"
            opened = !(openMon === mon && openSurface === surface)
        }
        if (!mon || openSurface === "auth" || surface === "media" && !mediaAvailable) return false
        present(opened ? mon : "", opened ? surface : "")
        return true
    }

    function openFromDrop(mon, surface) {
        // Recording uses the existing recording/activity route.
        if (["media", "focus", "recording", "session"].indexOf(surface) < 0) return false
        return pull(mon, surface, true)
    }

    /** Monitor vacío → monitor con foco, para que los keybinds salten el jq. */
    function toggleSurface(mon, surface) {
        // Espacios vive dentro de Overview; el nombre antiguo sigue sirviendo a keybinds.
        if (surface === "workspaces") surface = "overview"
        // Apariencia se integró en Ajustes (su primera página).
        if (surface === "appearance") surface = "settings"
        if (!mon || mon.length === 0) mon = focusedMonitorName
        if (!mon) {
            pendingFocusSurface = pendingFocusSurface === surface ? "" : surface
            return
        }
        pendingFocusSurface = ""
        if (root.mediaDockPendingMon.length > 0) {
            const cancel = surface === root.mediaDockPendingSurface && root.mediaDockPendingMon === mon
            root.mediaDockPendingMon = ""
            if (cancel) return
        }
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
        if (surface === "media" && !root.mediaAvailable) return
        // Superficies que cubren la fila superior: la gota de media se funde primero.
        if (surface === "launcher" || surface === "wallpaper" || surface === "overview" || surface === "calendar") {
            root.mediaDockPendingSurface = surface
            root.mediaDockPendingMon = mon
            return
        }
        root.openMon = mon;
        root.openSurface = surface;
    }

    function finishMediaDock(mon) {
        if (!mon || root.mediaDockPendingMon !== mon) return
        root.openMon = mon
        root.openSurface = root.mediaDockPendingSurface
        root.mediaDockPendingMon = ""
    }

    // Fullscreen invalidates work for this monitor, including a dock still in flight.
    function dismissMonitor(mon) {
        if (mediaDockPendingMon === mon) {
            mediaDockPendingMon = ""
            mediaDockPendingSurface = ""
        }
        if (peekMon === mon) peekMon = ""
        if (openMon !== mon) return
        const wasAuth = openSurface === "auth"
        launcherCloseResultsTimer.stop()
        launcherClosePillTimer.stop()
        openSurface = ""
        openMon = ""
        launcherClosePhase = 0
        if (wasAuth) authCloseRequested()
    }

    function close() {
        pendingFocusSurface = ""
        root.mediaDockPendingMon = ""
        if (root.openSurface === "launcher") {
            if (root.reduceMotion) {
                launcherCloseResultsTimer.stop()
                launcherClosePillTimer.stop()
                root.openSurface = ""
                root.openMon = ""
                root.launcherClosePhase = 0
                return
            }
            if (root.launcherClosePhase !== 0) return
            root.launcherClosePhase = 1
            launcherCloseResultsTimer.restart()
            return
        }
        if (root.openSurface === "auth") {
            root.authCloseRequested()
        }
        root.openMon = "";
        root.openSurface = "";
    }


    property Timer resultsTimer: Timer {
        id: launcherCloseResultsTimer
        interval: root.resultsDuration
        repeat: false
        onTriggered: {
            if (root.openSurface !== "launcher" || root.launcherClosePhase !== 1) return
            root.launcherClosePhase = 2
            launcherClosePillTimer.restart()
        }
    }

    property Timer pillTimer: Timer {
        id: launcherClosePillTimer
        interval: root.morphDuration
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

}
