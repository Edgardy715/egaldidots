import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    QtObject {
        id: apps
        property int calls: 0
        function search(query) { calls++; return [{id: query, name: query, icon: ""}] }
        function launch(app) { throw new Error("Fixture must not launch apps") }
    }
    LauncherController { id: controller; appService: apps; query: view.query }
    Window {
        id: window
        visible: true; width: 700; height: 400
        color: Theme.background
        Rectangle { anchors.fill: parent; color: Theme.background }
        LauncherView {
            id: view
            anchors.fill: parent
            open: controller.open
            closing: controller.closing
            searching: controller.searching
            searchResults: controller.searchResults
            showCalculator: controller.showCalculator
            calcResult: controller.calcResult
            property var launches: []
            property int closes: 0
            onLaunchRequested: app => launches.push(app.id)
            onRequestClose: closes++
        }
        TestCase {
            name: "LauncherPending"
            when: window.visible
            function resultDelegate(item) {
                if (item.resultIndex !== undefined) return item
                for (const child of item.children || []) {
                    const result = resultDelegate(child)
                    if (result) return result
                }
                return null
            }
            function test_currentQueryOnly() {
                try {
                    controller.open = true
                    const input = findChild(view, "launcherSearch")
                    input.text = "old"
                    tryCompare(controller, "lastQuery", "old")
                    tryVerify(() => resultDelegate(view) !== null)
                    const delegate = resultDelegate(view)
                    input.text = "new"
                    verify(controller.searching)
                    verify(!delegate.enabled, "pending results cannot receive pointer input")
                    view.launchCurrent()
                    compare(view.launches.length, 0, "Enter cannot launch an old result")
                    compare(view.closes, 0)
                    tryCompare(controller, "lastQuery", "new")
                    tryVerify(() => resultDelegate(view)?.modelData.id === "new")
                    const output = Quickshell.env("ISLA_TEST_OUTPUT")
                    if (output) {
                        wait(500)
                        let captured = false
                        window.contentItem.grabToImage(image => { captured = image.saveToFile(output + "/launcher.png") })
                        tryVerify(() => captured)
                    }
                    view.launchCurrent()
                    compare(view.launches.join(), "new")
                    controller.closing = true
                    view.launchCurrent()
                    compare(view.launches.length, 1, "closing content is inert")
                    controller.open = false
                    controller.closing = false
                    const calls = apps.calls
                    input.text = "hidden"
                    wait(120)
                    compare(apps.calls, calls, "hidden edits do not search")
                    controller.open = true
                    input.text = "new"
                    tryCompare(controller, "lastQuery", "new")
                    verify(apps.calls > calls, "reopening the same query refreshes results")
                    console.log("PASS: launcher rejects stale activation, hidden search and closing input")
                } catch (error) {
                    console.error("FAIL: launcher pending: " + error)
                    Qt.exit(1)
                }
            }
        }
    }
}
