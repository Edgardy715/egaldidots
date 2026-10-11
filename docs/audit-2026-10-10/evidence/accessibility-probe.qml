import QtQuick
import QtTest
import Quickshell
import "components"
import "." as Bar
ShellRoot {
 settings.watchFiles: false
 Window {
  id: window; visible: true; width: 460; height: 220
  MotionArea { id: hit; x: 20; y: 20; width: 100; height: 80; accessibleName: "QA action"; onClicked: checks.clicks++ }
  Bar.CtrlBtn { id: button; x: 140; y: 20; iconName: "play_arrow"; onClicked: checks.buttonClicks++ }
  Toggle { id: toggle; x: 220; y: 20; onToggled: value => { checked = value; checks.toggles++ } }
  Slider { id: slider; x: 20; y: 160; width: 300; value: 0.5; knob: true; onSliderChanged: v => value = v }
  TestCase {
   id: checks; name: "AccessibleActivation"; when: window.visible
   property int clicks: 0
   property bool finished: false
   property int buttonClicks: 0
   property int toggles: 0
   function test_probe() {
    wait(100)
    mouseClick(hit, 50, 40)
    console.log("PROBE mouse activation", clicks)
    hit.forceActiveFocus(); keyClick(Qt.Key_Space)
    console.log("PROBE keyboard activation", clicks)
    hit.Accessible.pressAction()
    console.log("PROBE accessible activation", clicks)
    console.log("PROBE accessible role/name", hit.Accessible.role, hit.Accessible.name)
    button.Accessible.pressAction()
    toggle.Accessible.pressAction()
    toggle.Accessible.toggleAction()
    console.log("PROBE transport/toggle accessibility", buttonClicks, toggles)
    slider.forceActiveFocus(); keyClick(Qt.Key_Right)
    console.log("PROBE slider right value/tab/role", slider.value, slider.activeFocusOnTab, slider.Accessible.role)
    mouseClick(slider, 280, slider.height / 2)
    console.log("PROBE slider mouse value", slider.value)
    finished = true
   }
  }
 }
 Timer { interval: 100; running: checks.finished; onTriggered: Qt.quit() }
 Timer { interval: 3000; running: true; onTriggered: Qt.quit() }
}
