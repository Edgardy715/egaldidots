import QtQuick
import Quickshell
import "../Singletons"

// Owns native notification lifetime and actions; NotifCardView only presents data.
Item {
    id: root
    required property var modelData
    property bool compact: false
    property real s: 1
    readonly property var md: modelData
    readonly property bool hasImage: md ? (!!md.image && md.image.length > 0) : false
    readonly property bool isIconUrl: hasImage && ("" + md.image).indexOf("image://icon/") === 0
    readonly property string iconUrlName: isIconUrl ? ("" + md.image).slice(("image://icon/").length) : ""
    readonly property bool isPathIcon: iconUrlName.length > 0 && iconUrlName.charAt(0) === "/"

    readonly property string resolvedIconPath: {
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
        if (hasImage && !isIconUrl) {
            var image = "" + md.image
            if (image.indexOf("/") === 0 || image.indexOf("file://") === 0 || image.indexOf("http") === 0)
                return image
        }
        return isPathIcon ? iconUrlName : ""
    }

    implicitWidth: view.implicitWidth
    implicitHeight: view.implicitHeight
    NotifCardView {
        id: view
        anchors.fill: parent
        modelData: root.modelData
        compact: root.compact
        s: root.s
        resolvedIconPath: root.resolvedIconPath
        onDismissRequested: if (root.md) root.md.popup = false
        onLinkRequested: link => {
            Qt.openUrlExternally(link)
            if (root.md) root.md.popup = false
        }
        onActionRequested: action => {
            if (action && typeof action.invoke === "function") action.invoke()
        }
        onLockRequested: (notification, owner) => {
            if (notification && typeof notification.lock === "function") notification.lock(owner)
        }
        onUnlockRequested: (notification, owner) => {
            if (notification && typeof notification.unlock === "function") notification.unlock(owner)
        }
    }
}
