import QtQuick
import Quickshell
import "components"

ShellRoot {
    id: test
    settings.watchFiles: false
    function check(ok, message) {
        if (!ok) { console.error("FAIL:", message); Qt.exit(1) }
    }
    QtObject {
        id: apps
        property int calls: 0
        function search(query) { calls++; return [{name: query}] }
        function launch(app) { throw new Error("fixture must not launch " + app) }
    }
    LauncherController { id: controller; appService: apps }
    Timer {
        interval: 1
        running: true
        onTriggered: {
            controller.open = true
            controller.query = "2+2"
            test.check(controller.showCalculator && controller.calcResult === "4", "calculator result")
            test.check(controller.evaluateMath("alert(1)") === null, "invalid expression rejected")
            searched.start()
        }
    }
    Timer {
        id: searched
        interval: 110
        onTriggered: {
            test.check(apps.calls === 1 && controller.searchResults[0].name === "2+2", "debounced search")
            controller.query = "cancel"
            controller.closing = true
            canceled.start()
        }
    }
    Timer {
        id: canceled
        interval: 110
        onTriggered: {
            test.check(apps.calls === 1, "close cancels pending search")
            console.log("PASS: launcher search debounce, calculator and close cancellation")
            Qt.exit(0)
        }
    }
}
