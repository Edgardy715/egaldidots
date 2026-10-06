import QtQuick
import QtTest
import Quickshell
import "components"

ShellRoot {
    settings.watchFiles: false
    WorkspaceModel {
        id: model
        screenName: "left"
        monitors: [{name: "left", activeWorkspace: {id: 2}}, {name: "right", activeWorkspace: {id: 8}}]
        workspaces: [{id: 2, monitor: {name: "left"}, lastIpcObject: {windows: 3}, urgent: true},
            {id: 7, monitor: {name: "left"}, lastIpcObject: {windows: 0}},
            {id: 9, monitor: {name: "right"}, lastIpcObject: {windows: 1}}]
    }
    Window {
        id: scene
        visible: true
        width: 440; height: 80
        TopWorkspaceRail {
            id: rail
            activeId: model.activeId
            count: model.count
            occupied: model.occupied
            availableWidth: 420
        }
        SignalSpy { id: navigation; target: rail; signalName: "workspaceRequested" }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "WorkspaceModel"
            when: scene.visible
            property bool finished: false
            function test_model() {
                compare(model.activeId, 2)
                compare(model.count, 7)
                verify(model.occupied[2].occupied && model.occupied[2].urgent)
                verify(!model.occupied[7].occupied && model.occupied[9] === undefined)
                mouseClick(rail, rail.navWidth + rail.inset + rail.slot / 2, 24)
                compare(navigation.count, 1)
                compare(navigation.signalArguments[0][0], 1)
                model.screenName = "right"
                compare(model.activeId, 8)
                compare(model.count, 9)
                verify(model.occupied[9].occupied && model.occupied[2] === undefined)
                model.monitors = []
                model.workspaces = []
                compare(model.activeId, 1)
                compare(model.count, 5)
                compare(Object.keys(model.occupied).length, 0)
                console.log("PASS: workspace monitor isolation, active/count/occupancy, fallback and visual navigation signal")
                finished = true
            }
        }
    }
}
