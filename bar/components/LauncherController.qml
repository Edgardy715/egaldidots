import QtQuick
import Quickshell
import "../Singletons"

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

    // Evaluates a math expression safely
    function evaluateMath(expr) {
        try {
            // Replace common math functions/operators
            var jsExpr = expr
                .replace(/π|pi/gi, "Math.PI")
                .replace(/e\b/gi, "Math.E")
                .replace(/sqrt\(/gi, "Math.sqrt(")
                .replace(/sin\(/gi, "Math.sin(")
                .replace(/cos\(/gi, "Math.cos(")
                .replace(/tan\(/gi, "Math.tan(")
                .replace(/asin\(/gi, "Math.asin(")
                .replace(/acos\(/gi, "Math.acos(")
                .replace(/atan\(/gi, "Math.atan(")
                .replace(/log\(/gi, "Math.log(")
                .replace(/ln\(/gi, "Math.log(")
                .replace(/exp\(/gi, "Math.exp(")
                .replace(/abs\(/gi, "Math.abs(")
                .replace(/floor\(/gi, "Math.floor(")
                .replace(/ceil\(/gi, "Math.ceil(")
                .replace(/round\(/gi, "Math.round(")
                .replace(/\^/g, "**")
                .replace(/×/g, "*")
                .replace(/÷/g, "/");

            // Basic validation - only allow safe characters
            if (!/^[0-9+\-*/().,\s\w%]+$/.test(jsExpr)) {
                return null;
            }

            // Evaluate
            var result = eval(jsExpr);
            if (isFinite(result) && !isNaN(result)) {
                // Format nicely
                if (Number.isInteger(result)) {
                    return String(result);
                } else {
                    return Number(result.toFixed(10)).toString(); // Remove trailing zeros
                }
            }
        } catch (e) {
            // Ignore errors
        }
        return null;
    }

    onQueryChanged: {
        searchDebounce.restart()

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
            lastQuery = ""
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
            if (root.lastQuery === root.query) return
            root.lastQuery = root.query
            root.searchResults = root.appService.search(root.query)
        }
    }
    function launch(app) { appService.launch(app) }
    function copyResult(value) { Quickshell.execDetached(["wl-copy", value]) }
}
