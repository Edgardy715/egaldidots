import QtQuick
import QtTest
import Quickshell
import "body"

ShellRoot {
    settings.watchFiles: false
    BodyEvents { id: policy; active: true; nightEnabled: true }
    TestCase {
        id: checks
        name: "BodyEvents"
        when: true
        property bool passed: false
        property bool finished: false
        function test_policy() {
            try {
                policy.hour = 12
                compare(policy.mood, "curiosa")
                policy.focused = true
                compare(policy.mood, "timida")
                policy.focusEnabled = false
                compare(policy.mood, "curiosa")
                policy.idle = true
                compare(policy.mood, "dormida")
                policy.idle = false; policy.hour = 23.5
                compare(policy.mood, "dormida")
                policy.nightEnabled = false
                compare(policy.mood, "curiosa")
                policy.react("finished")
                compare(policy.mood, "contenta")
                wait(1000); policy.react("received"); wait(800)
                compare(policy.mood, "contenta") // Retarget extends a finite reaction.
                tryCompare(policy, "reaction", "", 1300)
                policy.react("received"); policy.systemEnabled = false
                compare(policy.reaction, "")
                policy.react("received"); compare(policy.reaction, "")
                policy.systemEnabled = true; policy.react("attention")
                compare(policy.mood, "curiosa")
                policy.active = false
                compare(policy.reaction, "")
                verify(!policy.hold.running)
                policy.react("received"); compare(policy.reaction, "")
                passed = true
                console.info("PASS: body event priority, local night, focus, finite retarget and disable")
            } finally { finished = true }
        }
    }
    Timer { interval: 100; running: checks.finished; onTriggered: Qt.exit(checks.passed ? 0 : 1) }
}
