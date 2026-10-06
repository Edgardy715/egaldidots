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
    wallpaperSource: Wallpapers.current ? "file://" + encodeURI(Wallpapers.current) : ""
    hasMedia: Players.has
    mediaArtUrl: Players.artUrl
    mediaHasProgress: !!Players.active && Players.active.length > 0
    mediaProgress: mediaHasProgress ? Math.max(0, Math.min(1, Players.active.position / Players.active.length)) : 0
    mediaTitle: Players.title
    mediaArtist: Players.artist
    onWorkspaceRequested: id => {
        if (id > 0) Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + id + " })"])
    }
}
