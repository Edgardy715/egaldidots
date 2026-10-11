import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "surfaces"
ShellRoot {
 settings.watchFiles: false
 FloatingWindow {
  id: win
  title: "Isla QA isolated launcher"
  implicitWidth: 800
  implicitHeight: 460
  color: "#151515"
  LauncherSurface { id: launcher; anchors.fill: parent; open: true; morphCloseness: 1 }
 }
 IpcHandler { target: "auditLauncher"; function state(): string { return JSON.stringify({query: launcher.query, calculator: launcher.showCalculator, result: launcher.calcResult}) } }
 Timer { interval: 200; running: true; onTriggered: console.log("READY: native launcher isolated; no action requested") }
 Timer { interval: 45000; running: true; onTriggered: Qt.quit() }
}
