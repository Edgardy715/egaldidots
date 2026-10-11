import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "windows"
ShellRoot {
 settings.watchFiles: false
 SurfaceRouter { id: router; focusedMonitorName: Quickshell.screens[0].name }
 IslandOverlay { id: overlay; modelData: Quickshell.screens[0]; router: router }
 IpcHandler {
  target: "auditFocus"
  function open(name: string): void { router.toggleSurface("", name) }
  function state(): string { return JSON.stringify({surface: router.openSurface, wantsKeyboard: overlay.kbFocusWanted}) }
  function quit(): void { Qt.quit() }
 }
 Timer { interval: 60000; running: true; onTriggered: Qt.quit() }
}
