import QtQuick
import Quickshell
import "lockscreen"
import "Singletons"

ShellRoot {
    id: test
    property int unlocks: 0
    property int powers: 0
    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.exit(1) }
    }
    function findInput(item) {
        if (item.objectName === "lockPassword") return item
        for (let child of item.children) {
            const found = findInput(child)
            if (found) return found
        }
        return null
    }
    Window {
        visible: true; width: 1000; height: 900
        LockSurface {
            id: surface
            anchors.fill: parent
            username: "Test"
            avatarSource: ""
            onUnlockRequested: secret => { test.check(secret === "fixture", "submitted value"); test.unlocks++ }
            onPowerRequested: action => { test.powers++ }
        }
    }
    Timer {
        interval: 500; running: true
        onTriggered: {
            const input = test.findInput(surface)
            test.check(!!input, "password field available")
            input.text = "fixture"
            surface.attemptUnlock()
            test.check(test.unlocks === 0, "unsecured session cannot authenticate")
            surface.secured = true
            surface.busy = true
            surface.attemptUnlock()
            test.check(test.unlocks === 0, "busy blocks duplicate submit")
            surface.busy = false
            surface.attemptUnlock()
            test.check(test.unlocks === 1 && input.text === "", "submit clears password")
            surface.attemptUnlock()
            test.check(test.unlocks === 1, "empty submit blocked")
            input.text = "fixture"
            surface.errorText = "Error de prueba"
            test.check(input.text === "", "error clears password")
            surface.choosePower("reboot")
            test.check(test.powers === 0, "reboot needs confirmation")
            surface.choosePower("poweroff")
            test.check(test.powers === 0, "different action needs confirmation")
            surface.choosePower("poweroff")
            test.check(test.powers === 1, "confirmed action emitted")
            input.text = "fixture"
            surface.authenticated = true
            surface.attemptUnlock()
            surface.choosePower("suspend")
            test.check(test.unlocks === 1 && test.powers === 1, "success blocks further actions")
            test.check(input.text === "" && !input.enabled, "success clears and disables password")
            const result = Config.update({appearance: {reduceMotion: true}})
            test.check(result.ok, "temporary config ready")
            surface.entered = false
            surface.entered = true
            console.log("PASS: lockscreen input guards, secret clearing, power confirmation and reduced motion loaded")
            Qt.quit()
        }
    }
}
