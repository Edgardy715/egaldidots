import QtQuick
import Quickshell
import Quickshell.Wayland
ShellRoot {
 id: root
 settings.watchFiles: false
 property var original: null
 property bool sawA: false
 property bool sawB: false
 Component.onCompleted: original = ToplevelManager.activeToplevel
 Connections {
  target: ToplevelManager
  function onActiveToplevelChanged() {
   const t = ToplevelManager.activeToplevel
   console.log('FOCUS', t ? t.appId : '', t ? t.title : '')
   if (t && t.title === a.title) root.sawA = true
   if (t && t.title === b.title) root.sawB = true
  }
 }
 Window { id: a; title: 'Isla pet focus probe A'; width: 120; height: 80; visible: false }
 Window { id: b; title: 'Isla pet focus probe B'; width: 120; height: 80; visible: false }
 Timer { interval: 500; running: true; onTriggered: { a.visible = true; a.requestActivate() } }
 Timer { interval: 1500; running: true; onTriggered: { b.visible = true; b.requestActivate() } }
 Timer { interval: 2500; running: true; onTriggered: { a.requestActivate() } }
 Timer { interval: 3500; running: true; onTriggered: {
  a.visible = false; b.visible = false
  if (root.original) root.original.activate()
  console.log((root.sawA && root.sawB ? 'PASS' : 'FAIL') + ': activeToplevel tracks focus on Hyprland')
  Qt.exit(root.sawA && root.sawB ? 0 : 1)
 } }
}
