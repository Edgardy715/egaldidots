import QtQuick
import QtTest
import Quickshell
import "components"

ShellRoot {
    settings.watchFiles: false
    QtObject {
        id: apps
        function search(query) { return [] }
        function launch(app) { throw new Error("Fixture must not launch an application") }
    }
    LauncherController { id: controller; appService: apps; open: true; query: view.query }
    Window {
        id: window
        visible: true; width: 700; height: 360
        LauncherView {
            id: view
            anchors.fill: parent
            open: true
            searchResults: controller.searchResults
            searching: controller.searching
            showCalculator: controller.showCalculator
            calcResult: controller.calcResult
        }
        TestCase {
            id: checks
            name: "LauncherInputSafety"
            when: window.visible
            property bool finished: false
            function type(input, text) {
                input.forceActiveFocus()
                keyClick(Qt.Key_A, Qt.ControlModifier)
                for (const character of text) keyClick(character)
            }
            function test_text_input() {
                wait(100)
                const input = findChild(view, "launcherSearch")
                verify(input !== null)
                type(input, "Qt.quit()")
                compare(view.query, "Qt.quit()")
                verify(!controller.showCalculator)
                wait(100)
                type(input, "asin(0)")
                compare(controller.calcResult, "0")
                type(input, "sqrt(9)+2")
                compare(controller.calcResult, "5")
                type(input, "buscar aplicacion")
                verify(!controller.showCalculator)
                console.log("PASS: typed QML expression has no effects, inverse math and ordinary app search remain usable")
                finished = true
            }
        }
        Timer { interval: 100; running: checks.finished; onTriggered: Qt.quit() }
    }
    Timer { interval: 6000; running: true; onTriggered: { console.error("FAIL: launcher input safety timeout"); Qt.exit(1) } }
}
