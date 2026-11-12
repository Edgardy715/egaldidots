import QtQuick
import Quickshell
import "components"

ShellRoot {
    id: test
    settings.watchFiles: false
    function check(ok, message) {
        if (!ok) { console.error("FAIL:", message); Qt.exit(1); throw new Error(message) }
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
            test.check(policy.sideModulesPresented, "idle bar is visible")
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
            policy.recordingActive = true
            policy.recordingX = 5; policy.recordingY = 4
            policy.recordingW = 30; policy.recordingH = 50
            test.check(policy.maskX === 5 && policy.maskY === 4 && policy.maskW === 295
                && policy.maskH === 50 && !policy.outsideBodies(10, 6)
                && policy.outsideBodies(1, 6), "recording uses reflected visual bounds")
            test.check(policy.maskMode === "pill" && !policy.exclusiveFocus,
                "recording hover never captures fullscreen input or keyboard")
            policy.recordingActive = false
            test.check(policy.outsideBodies(10, 6), "absorbed recording releases its input bounds")
            policy.mediaActive = false; policy.sessionActive = false
            policy.pointerPull = true
            policy.surface = "utils"
            policy.pillWidth = 420; policy.pillHeight = 480
            policy.pillTargetW = 400; policy.pillTargetH = 440
            test.check(!policy.exclusiveFocus && policy.maskMode === "pill",
                "pointer pull retains rest focus and mask while route opens")
            test.check(policy.maskX <= policy.pillX && policy.maskY <= policy.pillY
                && policy.maskX + policy.maskW >= policy.pillX + policy.pillWidth
                && policy.maskY + policy.maskH >= policy.pillY + policy.pillHeight,
                "pill region covers actual overstretched geometry")
            policy.pointerPull = false
            test.check(policy.exclusiveFocus && policy.maskMode === "full" && policy.escapeShortcutEnabled,
                "release open immediately enables keyboard and Escape")
            policy.pointerPull = true
            policy.surface = ""
            test.check(policy.exclusiveFocus && policy.maskMode === "full",
                "closing pointer pull retains its initial modal policy")
            policy.pointerPull = false
            test.check(!policy.exclusiveFocus && policy.maskMode === "pill",
                "release closed restores bounded input and releases keyboard")
            policy.pillWidth = 120; policy.pillHeight = 38
            policy.pillTargetW = 140; policy.pillTargetH = 40
            policy.surface = "calendar"
            test.check(policy.maskMode === "full" && policy.kbFocusWanted && policy.exclusiveFocus,
                "ordinary modal surface grabs keyboard for Escape and navigation")
            for (const name of ["mixer", "connectivity", "notifs", "utils", "appearance"]) {
                policy.surface = name
                test.check(policy.exclusiveFocus && policy.escapeShortcutEnabled, name + " receives modal keyboard")
            }
            test.check(!policy.sideModulesPresented, "ordinary surfaces hide lateral modules")
            policy.surface = "media"
            test.check(policy.exclusiveFocus && policy.escapeShortcutEnabled, "media lyrics and controls grab keyboard")
            policy.surface = "launcher"
            test.check(policy.exclusiveFocus && policy.escapeShortcutEnabled, "launcher grabs keyboard")
            policy.surface = "settings"
            test.check(policy.sideModulesPresented, "settings keeps live bar visible")
            policy.settingsActive = true
            policy.settingsX = 400; policy.settingsY = 200
            policy.settingsW = 800; policy.settingsH = 650
            test.check(policy.exclusiveFocus && !policy.outsideBodies(500, 400)
                && policy.outsideBodies(1300, 400), "settings focus and card hit region")
            policy.settingsActive = false
            policy.surface = "launcher"
            policy.launcherClosing = true
            test.check(policy.maskMode === "pill" && !policy.kbFocusWanted && !policy.exclusiveFocus,
                "launcher close releases modal focus")
            test.check(!policy.escapeShortcutEnabled, "closing launcher does not steal Escape from app")
            policy.launcherClosing = false
            policy.surface = "auth"
            test.check(policy.authFocusGrab && policy.exclusiveFocus && !policy.escapeShortcutEnabled,
                "auth focus and close policy")
            policy.monitors = [{name: "DP-1", activeWorkspace: {lastIpcObject: {hasfullscreen: true}}}]
            test.check(policy.monFullscreen && policy.maskMode === "hidden" && !policy.kbFocusWanted && !policy.exclusiveFocus,
                "fullscreen is click-through")
            test.check(!policy.authFocusGrab && !policy.modal && !policy.escapeShortcutEnabled,
                "fullscreen auth releases every keyboard path")
            test.check(!policy.sideModulesPresented, "fullscreen still hides lateral modules")
            policy.focusedMonitorName = "DP-2"
            test.check(!policy.monitorIsFocused, "focus follows monitor")
            console.log("PASS: overlay focus, fullscreen, regions and backdrop policy")
            Qt.exit(0)
        }
    }
}
