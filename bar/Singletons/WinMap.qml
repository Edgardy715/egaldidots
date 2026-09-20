pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Isla · WinMap. Data del overview: pollea `hyprctl clients/workspaces/monitors/
 * activeworkspace -j` bajo demanda (debounced por raw-events), igual que el
 * HyprlandData de quickshell-overview (verificado en este mismo Quickshell 0.3.0).
 * La geometría por-ventana (at/size/fullscreen/floating/workspace/monitor) NO
 * está en Quickshell.Hyprland → hay que leer hyprctl. Los live-captures vienen
 * de `Quickshell.Wayland.ToplevelManager` (matcheados por `0x+address`).
 *
 * `ready` latch: las props derivadas esperan a la 1ª carga para no leer undefined.
 * `toplevelByAddress` es un binding readonly que recomputa solo cuando
 * `ToplevelManager.toplevels` (ObjectListModel) o `windowList` notifican cambio.
 */
Singleton {
    id: root

    property var windowList: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var monitors: []
    property var activeWorkspace: null
    property bool ready: false

    /** gate: sólo pollea hyprctl mientras el overview de la pill lo consume.
     *  En reposo el overview está cerrado → active=false → onRawEvent retorna
     *  temprano = cero spawns de `hyprctl -j clients/workspaces/monitors/…` por
     *  cada evento de Hyprland. La shell fija active=(openSurface==="overview").
     *  `Component.onCompleted` y `updateAll()` lo siguen ignorando (carga fresca
     *  al abrir / al arranque) — el guard sólo aplica a los events vivos. */
    property bool active: false

    readonly property var toplevelByAddress: {
        // touch windowList so this re-evaluates on every clients refresh too
        void root.windowList
        var out = ({})
        var vs = ToplevelManager.toplevels.values
        for (var i = 0; i < vs.length; i++) {
            var t = vs[i]
            var ht = t ? t.HyprlandToplevel : null
            if (ht && ht.address !== undefined) {
                var raw = "" + ht.address
                var a = (raw.indexOf("0x") === 0 || raw.indexOf("0X") === 0) ? raw : "0x" + raw
                if (a.length > 2) out[a] = t
            }
        }
        return out
    }

    property bool pW: false
    property bool pM: false
    property bool pWs: false
    property bool pA: false

    function schedule(w, m, ws, a) {
        pW = pW || !!w
        pM = pM || !!m
        pWs = pWs || !!ws
        pA = pA || !!a
        debounce.restart()
    }
    function flush() {
        if (pW) { pW = false; getClients.running = true }
        if (pM) { pM = false; getMonitors.running = true }
        if (pWs) { pWs = false; getWorkspaces.running = true }
        if (pA) { pA = false; getActiveWorkspace.running = true }
    }
    function updateAll() { schedule(true, true, true, true); flush() }

    Component.onCompleted: { schedule(true, true, true, true); flush() }

    Timer { id: debounce; interval: 40; repeat: false; onTriggered: root.flush() }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.active) return
            var n = "" + (event ? (event.name || event.event || event.type || "") : "")
            if (n === "openlayer" || n === "closelayer" || n === "screencast") return
            if (n === "openwindow" || n === "closewindow" || n === "movewindow"
                    || n === "movewindowv2" || n === "windowtitle") {
                root.schedule(true, false, true, false); return
            }
            if (n === "workspace" || n === "workspacev2" || n === "focusedmon"
                    || n === "focusedmonv2" || n === "activewindow") {
                root.schedule(false, false, true, true); return
            }
            if (n.indexOf("monitor") === 0 || n === "configreloaded") {
                root.schedule(true, true, true, true); return
            }
            root.schedule(true, true, true, true)
        }
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                var list = JSON.parse(clientsCollector.text || "[]")
                root.windowList = list
                var byAddr = ({})
                for (var i = 0; i < list.length; i++) byAddr[list[i].address] = list[i]
                root.windowByAddress = byAddr
                root.ready = true
            }
        }
    }

    Process {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            id: workspacesCollector
            onStreamFinished: {
                var ws = JSON.parse(workspacesCollector.text || "[]")
                root.workspaces = ws
                var ids = []
                for (var i = 0; i < ws.length; i++) if (ws[i].id >= 1) ids.push(ws[i].id)
                ids.sort(function (a, b) { return a - b })
                root.workspaceIds = ids
            }
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                root.monitors = JSON.parse(monitorsCollector.text || "[]")
            }
        }
    }

    Process {
        id: getActiveWorkspace
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: activeWorkspaceCollector
            onStreamFinished: {
                root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text || "{}")
            }
        }
    }

    /** Cuenta y lista ordenada de ventanas por workspace (opc. filtradas por monitor).
     *  Si monId es inválido (< 0) NO filtra por monitor: el overview debe seguir
     *  mostrando/ordenando ventanas mientras WinMap resuelve los monitores (los
     *  procesos hyprctl son asíncronos y monId puede tardar ~100ms en resolverse). */
    function winCount(wsId) {
        var c = 0, wl = root.windowList
        for (var i = 0; i < wl.length; i++)
            if (wl[i].workspace && wl[i].workspace.id === wsId) c++
        return c
    }
    function windowsOn(wsId, monId) {
        var out = [], wl = root.windowList
        for (var i = 0; i < wl.length; i++) {
            var w = wl[i]
            if (w.workspace && w.workspace.id === wsId) {
                if (monId !== undefined && monId >= 0 && w.monitor !== monId) continue
                out.push(w)
            }
        }
        out.sort(function (a, b) {
            var pa = a.pinned ? 1 : 0, pb = b.pinned ? 1 : 0
            if (pa !== pb) return pb - pa
            var fa = a.floating ? 1 : 0, fb = b.floating ? 1 : 0
            if (fa !== fb) return fb - fa
            return (a.focusHistoryID || 0) - (b.focusHistoryID || 0)
        })
        return out
    }
}
