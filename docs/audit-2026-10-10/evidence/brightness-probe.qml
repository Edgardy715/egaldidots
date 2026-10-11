import QtQuick
import QtTest
import Quickshell
import "components"
ShellRoot {
 settings.watchFiles: false
 Window {
  id: window; visible: true; width: 620; height: 700
  QuickControlsView { id: view; anchors.fill: parent; showBrightness: true; contentReady: true; brightnessPercent: 50; onBrightnessSetPercent: value => { checks.writes++; brightnessPercent = value } }
  TestCase {
   id: checks; name: "BrightnessKeyboard"; when: window.visible
   property int writes: 0
   property bool finished: false
   function test_probe() {
    wait(400)
    const slider = findChild(view, "brightnessSlider")
    verify(slider !== null)
    slider.forceActiveFocus(); keyClick(Qt.Key_Right)
    console.log("PROBE brightness right writes/value/tab/role", writes, view.brightnessPercent, slider.activeFocusOnTab, slider.Accessible.role)
    mouseClick(slider, slider.width * 0.75, slider.height / 2)
    console.log("PROBE brightness mouse writes/value", writes, view.brightnessPercent)
    finished = true
   }
  }
  Timer { interval: 100; running: checks.finished; onTriggered: Qt.quit() }
 }
 Timer { interval: 4000; running: true; onTriggered: Qt.quit() }
}
