import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

// Caps Lock desde LEDs sysfs falsos: descubrimiento, OR entre teclados,
// teclado retirado con redescubrimiento y respaldo hyprctl sin LEDs.
ShellRoot {
    id: test
    readonly property string dir: "/tmp/isla-capslock-test-" + Quickshell.processId
    property int step: 0
    property double deadline: 0

    function fail(message) {
        console.error("FAIL: " + message + " · source=" + DesktopStatus.capsLockSource
            + " paths=" + JSON.stringify(DesktopStatus._capsLedPaths) + " on=" + DesktopStatus.capsLockOn)
        cleanup.next = 1
        cleanup.running = true
    }
    function shell(script) {
        writer.command = ["sh", "-c", script, "sh", test.dir]
        writer.running = true
    }
    function waitFor(check, label, next) {
        test.deadline = Date.now() + 3000
        poll.check = check
        poll.label = label
        poll.next = next
        poll.start()
    }

    Process {
        id: writer
        onExited: (code) => {
            if (code !== 0) return test.fail("fixture command " + code)
            test.advance()
        }
    }
    Process {
        id: cleanup
        property int next: 0
        command: ["rm", "-rf", test.dir]
        onExited: Qt.exit(next)
    }
    Timer {
        id: poll
        property var check
        property string label
        property var next
        interval: 25
        repeat: true
        onTriggered: {
            if (check()) {
                stop()
                next()
            } else if (Date.now() > test.deadline) {
                stop()
                test.fail(label)
            }
        }
    }

    function advance() {
        step++
        switch (step) {
        case 1:
            DesktopStatus.capsLedPattern = test.dir + "/*::capslock/brightness"
            return waitFor(() => DesktopStatus._capsLedPaths.length === 2 && !DesktopStatus.capsLockOn
                    && DesktopStatus.capsLockSource === "leds", "discover two LEDs off", advance)
        case 2:
            return shell("printf '1\\n' > \"$1/b::capslock/brightness\"")
        case 3:
            return waitFor(() => DesktopStatus.capsLockOn, "one LED on turns Caps Lock on", advance)
        case 4:
            return shell("printf '0\\n' > \"$1/b::capslock/brightness\"")
        case 5:
            return waitFor(() => !DesktopStatus.capsLockOn, "LED off turns Caps Lock off", advance)
        case 6:
            return shell("rm -r \"$1/a::capslock\"")
        case 7:
            return waitFor(() => DesktopStatus._capsLedPaths.length === 1, "removed keyboard rediscovered", advance)
        case 8:
            DesktopStatus.capsLedPattern = test.dir + "/none/*::capslock/brightness"
            return waitFor(() => DesktopStatus.capsLockSource === "hyprctl"
                    && DesktopStatus._capsLedPaths.length === 0, "fallback without LEDs", advance)
        case 9:
            console.log("PASS: Caps Lock from sysfs LEDs (discovery, OR, removal, hyprctl fallback)")
            cleanup.next = 0
            cleanup.running = true
        }
    }

    Component.onCompleted: {
        // Inicializa el singleton y deja que termine su descubrimiento real.
        if (!DesktopStatus.monitorServices) return fail("services disabled")
        shell("mkdir -p \"$1/a::capslock\" \"$1/b::capslock\" && printf '0\\n' > \"$1/a::capslock/brightness\""
            + " && printf '0\\n' > \"$1/b::capslock/brightness\"")
    }
}
