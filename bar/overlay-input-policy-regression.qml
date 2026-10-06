import QtQuick
import Quickshell
import "components"

ShellRoot {
    id: test
    settings.watchFiles: false
    function check(ok, message) {
        if (!ok) { console.error("FAIL:", message); Qt.exit(1) }
    }
    OverlayInputPolicy {
        id: policy
        monitorName: "DP-1"
        focusedMonitorName: "DP-1"
        pillX: 100; pillY: 10
        pillWidth: 120; pillHeight: 38
        pillTargetW: 140; pillTargetH: 40
    }
    Timer {
        interval: 1
        running: true
        onTriggered: {
            test.check(policy.maskMode === "pill" && !policy.modal && !policy.kbFocusWanted,
                "rest captures only pill")
            test.check(policy.maskX === 90 && policy.maskW === 150 && policy.maskH === 40,
                "morph target stays inside input region")
            test.check(policy.outsideBodies(95, 20) && !policy.outsideBodies(110, 20),
                "backdrop uses actual pill bounds")
            policy.mediaActive = true
            policy.mediaX = 250; policy.mediaY = 20; policy.mediaW = 50; policy.mediaH = 30
            policy.sessionActive = true
            policy.sessionX = 40; policy.sessionY = 15; policy.sessionW = 40; policy.sessionH = 30
            test.check(policy.maskX === 40 && policy.maskW === 260 && !policy.outsideBodies(260, 25)
                && !policy.outsideBodies(50, 25), "both companions extend capture")
            policy.surface = "calendar"
            test.check(policy.maskMode === "full" && policy.kbFocusWanted && !policy.exclusiveFocus,
                "ordinary surface uses on-demand focus")
            policy.surface = "launcher"
            test.check(policy.exclusiveFocus && policy.escapeShortcutEnabled, "launcher grabs keyboard")
            policy.launcherClosing = true
            test.check(policy.maskMode === "pill" && !policy.kbFocusWanted && !policy.exclusiveFocus,
                "launcher close releases modal focus")
            policy.launcherClosing = false
            policy.surface = "auth"
            test.check(policy.authFocusGrab && policy.exclusiveFocus && !policy.escapeShortcutEnabled,
                "auth focus and close policy")
            policy.monitors = [{name: "DP-1", activeWorkspace: {lastIpcObject: {hasfullscreen: true}}}]
            test.check(policy.monFullscreen && policy.maskMode === "hidden" && !policy.kbFocusWanted,
                "fullscreen is click-through")
            policy.focusedMonitorName = "DP-2"
            test.check(!policy.monitorIsFocused, "focus follows monitor")
            console.log("PASS: overlay focus, fullscreen, regions and backdrop policy")
            Qt.exit(0)
        }
    }
}
