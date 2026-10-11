import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "windows"

ShellRoot {
    settings.watchFiles: false
    SurfaceRouter { id: router; focusedMonitorName: Quickshell.screens[0].name; reduceMotion: true }
    IslandOverlay { id: overlay; modelData: Quickshell.screens[0]; router: router }
    IpcHandler {
        target: "nativeInputTest"
        function open(name: string): void { router.toggleSurface("", name) }
        function state(): string { return JSON.stringify({surface: router.openSurface, wantsKeyboard: overlay.kbFocusWanted}) }
    }
}
