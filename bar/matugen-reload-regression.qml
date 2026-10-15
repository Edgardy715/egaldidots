import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"
ShellRoot {
    settings.watchFiles: false
    IpcHandler {
        target: "island"
        function reloadColors(): bool { IslaPalette.forceReload(); return true; }
        function paletteStatus(): string {
            return JSON.stringify({loaded:IslaPalette.loaded,error:IslaPalette.error,
                wallpaper:IslaPalette.wallpaper,primary:String(IslaPalette.accent)})
        }
        function quit(): void { Qt.quit() }
    }
    Timer { interval: 15000; running: true; onTriggered: Qt.exit(1) }
}
