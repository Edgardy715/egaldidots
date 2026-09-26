import QtQuick
import Quickshell
import "surfaces"
ShellRoot {
    Item {
        width: 1000; height: 340
        OverviewSurface { id: overview; open: true; s: 1; screenName: "overview-test" }
    }
    function check(ok, message) {
        if (!ok) { console.error("FAIL", message); Qt.exit(1) }
    }
    Timer {
        interval: 300; running: true
        onTriggered: {
            check(overview.visibleIds.length === 4, "strip must show four workspaces")
            overview.goIndex(2)
            check(overview._selIndexWs === overview.visibleIds[1], "numeric selection")
            overview.cycle(1)
            check(overview._selIndexWs === overview.visibleIds[2], "arrow selection")
            overview.shiftGroup(1)
            check(overview.groupBase === 5 && overview._selIndexWs === 5, "next group")
            overview.shiftGroup(-1)
            overview.shiftGroup(-1)
            check(overview.groupBase === 1, "groups cannot go below workspace one")
            check(overview.tileW > 0 && overview.tileH > 0 && overview.tileH + 148 <= overview.height,
                  "preview and controls must fit")
            console.log("PASS: overview selection, groups, compact bounds")
            Qt.quit()
        }
    }
}
