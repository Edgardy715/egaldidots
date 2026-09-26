import QtQuick

// Surface navigation only. Environment services and windows belong to shell.qml.
QtObject {
    id: root
    property string focusedMonitorName: ""
    property bool reduceMotion: false
    property int resultsDuration: 250
    property int morphDuration: 420
    signal authCloseRequested()

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
        launcherCloseResultsTimer.stop()
        launcherClosePillTimer.stop()
        launcherClosePhase = 0
        mediaDockPendingMon = ""
        mediaDockPendingSurface = ""
        openMon = mon
        openSurface = surface
    }

    /** Monitor vacío → monitor con foco, para que los keybinds salten el jq. */
    function toggleSurface(mon, surface) {
        if (!mon || mon.length === 0) mon = focusedMonitorName
        if (!mon) return
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
        if (surface === "launcher" || surface === "wallpaper" || surface === "overview") {
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

    function close() {
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
