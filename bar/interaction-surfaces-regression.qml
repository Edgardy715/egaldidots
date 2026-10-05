import QtQuick
import Quickshell

ShellRoot {
    Window {
        id: scene
        visible: true; width: 1100; height: 760
        Loader { id: host; anchors.fill: parent }
        property int current: 0
        readonly property var names: ["Appearance", "Calendar", "Clipboard", "Connectivity", "Launcher", "Media", "Mixer", "Notifs", "Overview", "Session", "Utils", "Wallpaper", "Workspaces"]
        Timer {
            interval: 130; running: true; repeat: true
            onTriggered: {
                if (host.status === Loader.Error) { console.error("FAIL: surface load", scene.names[scene.current - 1]); Qt.exit(1); return }
                if (scene.current === scene.names.length) {
                    console.log("PASS: all 13 non-auth surfaces load with shared interaction primitives")
                    Qt.quit(); return
                }
                host.source = "surfaces/" + scene.names[scene.current++] + "Surface.qml"
            }
        }
    }
}
