import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../Singletons"

// Desktop data for the always-present clock, workspace flash and media header.
Item {
    id: root
    property string screenName: ""
    property bool workspaceReady: false
    property var notification: null
    property date now: new Date()
    readonly property string activeWsName: {
        const monitor = Hyprland.monitors.values.find(m => m.name === root.screenName)
        return monitor && monitor.activeWorkspace ? monitor.activeWorkspace.name : "1"
    }
    readonly property bool hasMedia: Players.has
    readonly property string artUrl: Players.artUrl
    readonly property string title: Players.title
    readonly property string artist: Players.artist
    readonly property bool hasProgress: !!Players.active && Players.active.length > 0
    readonly property real progress: hasProgress ? Math.max(0, Math.min(1, Players.active.position / Players.active.length)) : 0
    readonly property string notificationIcon: notification ? resolveIcon(notification.appIcon, notification.appName) : ""
    signal workspaceChanged(int number)
    onActiveWsNameChanged: {
        if (!workspaceReady) return
        const number = parseInt(activeWsName)
        if (number >= 1) workspaceChanged(number)
    }
    Timer {
        interval: 1000; repeat: true; running: true
        onTriggered: {
            const date = new Date()
            if (Flags.clockSeconds || date.getMinutes() !== root.now.getMinutes() || date.getHours() !== root.now.getHours())
                root.now = date
        }
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
}
