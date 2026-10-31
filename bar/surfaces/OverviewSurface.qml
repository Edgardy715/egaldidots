import QtQuick
import Quickshell
import "../components"
import "../Singletons"

OverviewView {
    id: root
    mon: WinMap.monitors.find(m => m.name === root.screenName) || WinMap.monitors[0] || null
    loading: !WinMap.ready
    windowsByWorkspace: {
        void WinMap.windowList
        const result = ({})
        for (const id of root.visibleIds) result[id] = WinMap.windowsOn(id, root.monId)
        return result
    }
    toplevelByAddress: WinMap.toplevelByAddress
    wallpaperSource: Wallpapers.current ? Wallpapers.fileSource(Wallpapers.current, 0) : ""
    hasMedia: Players.has
    mediaArtUrl: Players.artUrl
    mediaHasProgress: Players.lengthOf(Players.active) > 0
    mediaProgress: Players.progressOf(Players.active)
    mediaTitle: Players.title
    mediaArtist: Players.artist
    onWorkspaceRequested: id => {
        if (id > 0) Qt.callLater(Quickshell.execDetached, ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + id + " })"])
    }
}
