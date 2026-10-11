import QtQuick
import Quickshell
import "components"
import "windows"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    SurfaceRouter {
        id: router
        focusedMonitorName: Quickshell.screens[0].name
        reduceMotion: true
    }
    IslandOverlay { id: overlay; modelData: Quickshell.screens[0]; router: router }
    function check(ok, message) {
        if (!ok) { console.error("FAIL:", message); Qt.exit(1) }
    }
    Timer {
        interval: 900; repeat: true; running: true
        property int step: 0
        onTriggered: {
            if (!Config.loaded) return
            switch (step++) {
            case 0:
                check(Config.update({appearance: {barLayout: "split", reduceMotion: true}}).ok, "split patch")
                break
            case 1: router.toggleSurface("", "media"); break
            case 2:
                check(!overlay.compact && overlay.mediaOpen && overlay.mediaSurfaceItem, "split media opens in companion")
                Config.update({appearance: {barLayout: "compact"}})
                break
            case 3:
                check(overlay.compact && overlay.mediaOpen && overlay.mediaSurfaceItem && overlay.mediaSurfaceItem.open, "open media moves into compact body")
                router.toggleSurface("", "launcher")
                break
            case 4:
                check(overlay.launcherOpen && !overlay.mediaDocking, "compact launcher completes dock route")
                router.toggleSurface("", "settings")
                break
            case 5:
                check(overlay.settingsOpen && !overlay.mediaDocking, "compact settings completes dock route")
                Config.update({appearance: {barLayout: "split"}})
                break
            case 6:
                check(!overlay.compact && overlay.settingsOpen, "layout switch preserves settings route")
                router.toggleSurface("", "media")
                break
            case 7:
                check(overlay.mediaOpen && overlay.mediaSurfaceItem, "split media restores after settings")
                Config.update({appearance: {barLayout: "compact"}})
                break
            case 8:
                check(overlay.compact && overlay.mediaSurfaceItem, "compact media restores after layout switch")
                router.close()
                break
            case 9:
                check(!overlay.surfaceOpen, "close releases route")
                console.log("PASS: split/compact media routing, open-panel layout switch, launcher/settings dock and close")
                Qt.quit()
            }
        }
    }
}
