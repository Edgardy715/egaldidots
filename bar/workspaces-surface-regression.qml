import QtQuick
import QtTest
import Quickshell
import "components"
import "surfaces"

ShellRoot {
    settings.watchFiles: false
    WorkspaceModel {
        id: desktop
        screenName: "left"
        minimumCount: panel.count
        monitors: [{name: "left", activeWorkspace: {id: 2}}]
        workspaces: [{id: 2, monitor: {name: "left"}, lastIpcObject: {windows: 3}},
            {id: 3, monitor: {name: "right"}, lastIpcObject: {windows: 8}}]
    }
    Window {
        id: scene
        visible: true
        width: 600; height: 340
        WorkspacesView {
            id: panel
            open: true
            activeId: desktop.activeId
            workspaceData: desktop.occupied
        }
        SignalSpy { id: navigation; target: panel; signalName: "workspaceRequested" }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "WorkspacesSurface"
            when: scene.visible
            property bool finished: false
            function test_panel() {
                compare(panel.count, 10)
                compare(desktop.count, 10)
                compare(panel.activeId, 2)
                compare(panel.workspaceData[2].windows, 3)
                verify(panel.workspaceData[3] === undefined)
                wait(700)
                mouseClick(panel, panel.width - 20, panel.height - 20)
                compare(navigation.count, 1)
                compare(navigation.signalArguments[0][0], 10)
                desktop.monitors = [{name: "left", activeWorkspace: {id: 12}}]
                compare(panel.activeId, 12)
                compare(panel.count, 10)
                compare(desktop.count, 12)
                desktop.screenName = "missing"
                compare(panel.activeId, 1)
                compare(Object.keys(panel.workspaceData).length, 0)
                console.log("PASS: workspace panel retains ten slots, monitor data and navigation to empty slot ten")
                finished = true
            }
        }
    }
}
