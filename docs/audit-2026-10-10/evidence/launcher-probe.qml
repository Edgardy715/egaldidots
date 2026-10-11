import QtQuick
import Quickshell
import "../../../bar/components" as Components
ShellRoot {
 settings.watchFiles: false
 QtObject { id: fakeApps; function search(query) { return [] } function launch(app) {} }
 Components.LauncherController { id: controller; appService: fakeApps }
 Timer { interval: 100; running: true; onTriggered: {
  for (const expression of ["2+2", "sin(0)", "asin(0)", "acos(1)", "atan(0)", "controller.open", "controller.appService.search(1)"]) console.log("PROBE", expression, controller.evaluateMath(expression))
  console.log("PROBE before Qt.quit")
  controller.evaluateMath("Qt.quit()")
  console.log("PROBE returned from eval; quitting requested")
 } }
 Timer { interval: 2000; running: true; onTriggered: { console.log("PROBE survived"); Qt.quit() } }
}
