import QtQuick
import Quickshell
import "Singletons"
import "components"
ShellRoot {
    Window { visible: true; width: 200; height: 48; IslandRestStatus { id: status; now: new Date(2026, 8, 26, 12, 45) } }
    property real originalWidth: 0
    property int positionUpdates: 0
    Connections {
        target: Players.active
        function onPositionChanged() { positionUpdates++ }
    }
    function check(ok, message) {
        if (!ok) { console.error("FAIL", message); Qt.exit(1) }
    }
    Timer {
        interval: 30; running: true
        onTriggered: { originalWidth = status.implicitWidth; status.flashWorkspace(2) }
    }
    Timer {
        interval: 300; running: true
        onTriggered: {
            check(status.implicitWidth > originalWidth && status.implicitWidth <= originalWidth + 44, "workspace reveal must stay within its reserved width")
            status.flashWorkspace(10)
        }
    }
    Timer {
        interval: 2700; running: true
        onTriggered: {
            check(status.implicitWidth === originalWidth, "workspace return must retain width")
            check(!Players.live || !Players.active.positionSupported || positionUpdates > 0,
                  "playing progress must refresh")
            console.log("PASS: workspace expands and returns; position updates:", positionUpdates)
            Qt.quit()
        }
    }
}
