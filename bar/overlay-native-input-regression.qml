import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "components"
import "windows"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    SurfaceRouter { id: router; focusedMonitorName: Quickshell.screens[0].name }
    ShellRuntime { router: router }
    IslandOverlay { id: overlay; modelData: Quickshell.screens[0]; router: router }
    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (const child of item.data || item.children || []) {
            const result = find(child, name)
            if (result) return result
        }
        return null
    }
    function pillItem() { return find(overlay.contentItem, "islandPill").surfaceItem }
    function settingsItem() { return find(overlay.contentItem, "settingsSearch") }
    IpcHandler {
        target: "nativeInputTest"
        function open(name: string): void { router.toggleSurface("", name) }
        function state(): string {
            const item = overlay.settingsOpen ? settingsItem() : pillItem()
            return JSON.stringify({surface: router.openSurface, wantsKeyboard: overlay.kbFocusWanted,
                fullscreen: overlay.monFullscreen, pending: router.mediaDockPendingMon,
                reduced: Flags.reduceMotion, routerReduced: router.reduceMotion,
                query: item && item.query !== undefined ? item.query : "",
                results: item && item.resultsCount !== undefined ? item.resultsCount : 0,
                searching: item && item.searching !== undefined ? item.searching : false,
                search: item && item.text !== undefined ? item.text : ""})
        }
        function selectWorkspace(): void { const item = pillItem(); item.workspaceRequested(item.activeId) }
        function settingsSearch(): void { const editor = find(overlay.contentItem, "settingsSearch"); editor.forceActiveFocus() }
        function motion(reduced: bool): void { Config.update({appearance: {reduceMotion: reduced}}) }
    }
}
