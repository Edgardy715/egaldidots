import QtQuick
import Quickshell
import "../"
import "../Singletons"
import "../components"

PillSurface {
    id: root
    mTop: Theme.marginLg; mLeft: Theme.marginLg; mRight: Theme.marginLg; mBottom: Theme.marginLg

    Component.onCompleted: {
        Notifs.centerOpen = true
        Notifs.clearToasts()
    }
    Component.onDestruction: Notifs.centerOpen = false

    function resolveIconPath(md) {
        if (!md) return ""
        if (md.appIcon && md.appIcon.length) {
            var raw = md.appIcon
            if (!Quickshell.iconPath(raw, true)) {
                var base = raw.replace(/\.desktop$/, "")
                if (base !== raw) raw = base
            }
            if (Quickshell.iconPath(raw, true)) return Quickshell.iconPath(raw)
        }
        if (md.appName && md.appName.length) {
            var entry = DesktopEntries.heuristicLookup(md.appName)
            if (entry && entry.icon && entry.icon.length) {
                var path = Quickshell.iconPath(entry.icon, true)
                if (path) return path
            }
        }
        if (md.image && md.image.length) {
            var image = "" + md.image
            if (image.indexOf("image://icon/") === 0) {
                var name = image.slice(("image://icon/").length)
                if (name.charAt(0) === "/") return name
            } else if (image.indexOf("/") === 0 || image.indexOf("file://") === 0 || image.indexOf("http") === 0) {
                return image
            }
        }
        return ""
    }

    readonly property var iconPaths: {
        void Notifs.listVersion
        const resolved = new Map()
        for (const notification of Notifs.notClosed)
            resolved.set(notification, root.resolveIconPath(notification))
        return resolved
    }

    NotifsView {
        anchors.fill: parent
        s: root.s
        open: root.open
        closing: root.closing
        count: Notifs.count
        dnd: Notifs.dnd
        notifications: Notifs.notClosed
        iconPaths: root.iconPaths
        onToggleDndRequested: Notifs.toggleDnd()
        onClearAllRequested: Notifs.clearAll()
        onDismissRequested: notification => { if (notification) notification.popup = false }
        onLinkRequested: (notification, link) => {
            Qt.openUrlExternally(link)
            if (notification) notification.popup = false
        }
        onActionRequested: (notification, action) => {
            if (action && typeof action.invoke === "function") action.invoke()
        }
        onNotificationLockRequested: (notification, owner) => {
            if (notification && typeof notification.lock === "function") notification.lock(owner)
        }
        onNotificationUnlockRequested: (notification, owner) => {
            if (notification && typeof notification.unlock === "function") notification.unlock(owner)
        }
    }
}
