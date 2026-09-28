import QtQuick
import Quickshell
import "surfaces"

ShellRoot {
    id: test
    property int calls: 0
    property string lastAction: ""
    property int closes: 0
    QtObject {
        id: fake
        function suspend() { test.calls++; test.lastAction = "suspend" }
        function lock() { test.calls++; test.lastAction = "lock" }
        function logout() { test.calls++; test.lastAction = "logout" }
        function reboot() { test.calls++; test.lastAction = "reboot" }
        function shutdown() { test.calls++; test.lastAction = "shutdown" }
    }
    Item {
        width: 640; height: 470
        SessionSurface { id: surface; open: true; actions: fake; onRequestClose: test.closes++ }
    }
    function check(ok, message) { if (!ok) { console.error("FAIL: " + message); Qt.exit(1) } }
    Timer {
        interval: 50; running: true
        onTriggered: {
            for (let index = 1; index < 4; index++) {
                const before = test.calls
                surface.activate(index)
                surface.activate(index)
                test.check(test.calls === before && surface.pending === index, "tile clicks only prepare confirmation")
                surface.cancel()
                surface.confirm()
                test.check(test.calls === before, "cancel prevents execution")
                surface.activate(index)
                surface.confirm()
                test.check(test.calls === before + 1 && test.lastAction === surface.choices[index].action, "explicit confirmation")
                surface.confirm()
                test.check(test.calls === before + 1, "no duplicate execution")
            }
            surface.handleKey({ key: Qt.Key_4, isAutoRepeat: false, accepted: false })
            test.check(surface.pending === 3, "number shortcut")
            const beforeKeys = test.calls
            surface.handleKey({ key: Qt.Key_Return, isAutoRepeat: true, accepted: false })
            test.check(test.calls === beforeKeys, "held key cannot confirm")
            surface.handleKey({ key: Qt.Key_Escape, isAutoRepeat: false, accepted: false })
            test.check(surface.pending === -1 && test.closes === 3, "escape cancels before closing")
            surface.activate(3)
            surface.open = false
            surface.open = true
            test.check(surface.pending === -1, "reopen resets confirmation")
            surface.select(-1)
            test.check(surface.focused === 4, "keyboard wraps")
            surface.activate(0)
            test.check(test.lastAction === "lock" && test.closes === 4, "lock and close")
            surface.activate(4)
            test.check(test.lastAction === "suspend" && test.closes === 5, "suspend and close")
            console.log("PASS: session confirmation, cancellation, repeat-click isolation, reopen and fake actions")
            Qt.quit()
        }
    }
}
