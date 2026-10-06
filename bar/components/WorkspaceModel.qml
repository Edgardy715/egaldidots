import QtQuick
import Quickshell
import Quickshell.Hyprland

// Shared desktop adapter for the rail and workspace panel.
QtObject {
    id: root
    required property string screenName
    property int minimumCount: 5
    property var monitors: Hyprland.monitors.values
    property var workspaces: Hyprland.workspaces.values
    readonly property var monitor: monitors.find(m => m.name === screenName) || null
    readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
    readonly property int count: {
        let last = Math.max(minimumCount, activeId)
        for (const ws of workspaces)
            if (ws.monitor && ws.monitor.name === screenName && ws.id > 0) last = Math.max(last, ws.id)
        return last
    }
    readonly property var occupied: {
        const result = ({})
        for (const ws of workspaces) {
            if (!ws.monitor || ws.monitor.name !== screenName || ws.id < 1) continue
            const windows = ws.lastIpcObject ? (ws.lastIpcObject.windows || 0) : 0
            result[ws.id] = { occupied: windows > 0, windows: windows, urgent: !!ws.urgent }
        }
        return result
    }
    function activate(id: int): void {
        if (id < 1 || id > count) return
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + id + " })"])
    }
}
