import QtQuick
import Quickshell
import "../Singletons"
import "Calculator.js" as Calculator

Item {
    id: root
    property bool open: false
    property bool closing: false
    property var appService: Apps
    property string query: ""
    property var searchResults: []
    property string lastQuery: "\u0000"
    property var calcResult: null
    property bool showCalculator: false
    readonly property bool searching: open && !closing && (searchDebounce.running || lastQuery !== query)

    function evaluateMath(expr) { return Calculator.evaluate(expr) }

    onQueryChanged: {
        if (open && !closing) searchDebounce.restart()

        // Check for calculator mode
        var trimmed = query.trim()
        if (trimmed.length > 0) {
            var result = evaluateMath(trimmed)
            calcResult = result
            showCalculator = result !== null
        } else {
            calcResult = null
            showCalculator = false
        }
    }

    onOpenChanged: {
        if (open) {
            searchResults = []
            lastQuery = "\u0000"
            if (!closing) searchDebounce.restart()
        } else searchDebounce.stop()
    }
    onClosingChanged: {
        if (closing) searchDebounce.stop()
        else if (open) searchDebounce.restart()
    }
    Timer {
        id: searchDebounce
        interval: 80
        onTriggered: {
            if (!root.open || root.closing) return
            if (root.lastQuery === root.query) return
            root.lastQuery = root.query
            root.searchResults = root.appService.search(root.query)
        }
    }
    function launch(app) { appService.launch(app) }
    function copyResult(value) { Quickshell.execDetached(["wl-copy", value]) }
}
