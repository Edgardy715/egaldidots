//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
import QtQuick
import Quickshell
import "settings"
ShellRoot {
    EdotsPageMotion { id: motion }
    property int phase: 0
    function check(ok, label) { if (!ok) throw new Error(label) }
    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: {
            if (phase === 0) motion.requestedPage = 1
            if (phase === 1) {
                check(motion.displayedPage === 0 && motion.exposure < 1, "outgoing page retained")
                const exposure = motion.exposure
                motion.requestedPage = 4
                check(Math.abs(exposure - motion.exposure) < 0.001, "retarget has no opacity jump")
            }
            if (phase === 2) motion.requestedPage = 2
            if (phase === 14) {
                check(motion.displayedPage === 2 && motion.exposure === 1 && Math.abs(motion.travel) < 0.01, "latest target settles")
                motion.requestedPage = 5
                motion.reduced = true
                check(!motion.transitioning && motion.displayedPage === 5 && motion.exposure === 1, "reduced motion resolves in-flight")
                motion.reduced = false; motion.requestedPage = 1; motion.active = false
                check(!motion.transitioning && motion.displayedPage === 1, "hidden stops motion")
                motion.requestedPage = 3
                check(motion.displayedPage === 3, "hidden navigation immediate")
                console.log("PASS: Edots page exit, retarget continuity, last destination, reduced motion and hidden stop")
                Qt.quit()
            }
            phase++
        }
    }
}
