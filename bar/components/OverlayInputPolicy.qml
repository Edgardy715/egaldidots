import QtQuick

QtObject {
    id: root
    property string monitorName: ""
    property string focusedMonitorName: ""
    property var monitors: []
    property string surface: ""
    property bool launcherClosing: false
    property bool pointerPull: false
    property bool heldPullFocus: false
    // Scroll-close on an open surface: the card shrinks under a fixed pointer, so the
    // mask must hold while the wheel gesture lives (focus is untouched).
    property bool wheelHold: false
    property string heldPullMask: "pill"
    onPointerPullChanged: if (pointerPull) {
        heldPullFocus = requestedFocus
        heldPullMask = requestedMask
    }

    property real pillX: 0
    property real pillY: 0
    property real pillWidth: 0
    property real pillHeight: 0
    property real pillTargetW: 0
    property real pillTargetH: 0
    property bool mediaActive: false
    property real mediaX: 0
    property real mediaY: 0
    property real mediaW: 0
    property real mediaH: 0
    property bool recordingActive: false
    property real recordingX: 0
    property real recordingY: 0
    property real recordingW: 0
    property real recordingH: 0
    property bool sessionActive: false
    property real sessionX: 0
    property real sessionY: 0
    property real sessionW: 0
    property real sessionH: 0
    property bool settingsActive: false
    property real settingsX: 0
    property real settingsY: 0
    property real settingsW: 0
    property real settingsH: 0

    readonly property bool surfaceOpen: surface.length > 0
    readonly property bool monitorIsFocused: focusedMonitorName === monitorName
    readonly property bool monFullscreen: {
        for (var i = 0; i < monitors.length; i++) {
            if (monitors[i].name === monitorName) {
                var ws = monitors[i].activeWorkspace
                var o = ws ? ws.lastIpcObject : null
                return o ? !!o.hasfullscreen : false
            }
        }
        return false
    }
    readonly property bool requestedFocus: surfaceOpen && !monFullscreen && !launcherClosing
    readonly property string requestedMask: monFullscreen ? "hidden" : requestedFocus ? "full" : "pill"
    // Changing layer focus or mask mode during a press cancels Hyprland's pointer grab.
    readonly property bool kbFocusWanted: !monFullscreen && (pointerPull ? heldPullFocus : requestedFocus)
    readonly property bool sideModulesPresented: (!surfaceOpen || surface === "settings") && !monFullscreen
    readonly property bool modal: kbFocusWanted
    readonly property bool exclusiveFocus: kbFocusWanted
    readonly property bool authFocusGrab: surface === "auth" && kbFocusWanted
    readonly property bool escapeShortcutEnabled: kbFocusWanted && surface !== "session" && surface !== "auth"
    readonly property string maskMode: monFullscreen ? "hidden" : pointerPull ? heldPullMask : wheelHold ? "full" : requestedMask

    readonly property real baseW: Math.max(pillWidth, pillTargetW)
    readonly property real baseH: Math.max(pillHeight, pillTargetH)
    readonly property real maskX: Math.min(pillX + (pillWidth - baseW) / 2,
        recordingActive ? recordingX : pillX, sessionActive ? sessionX : pillX, settingsActive ? settingsX : pillX)
    readonly property real maskY: Math.min(pillY, mediaActive ? mediaY : pillY,
        recordingActive ? recordingY : pillY, sessionActive ? sessionY : pillY,
        settingsActive ? settingsY : pillY)
    readonly property real maskW: Math.max(pillX + baseW,
        mediaActive ? mediaX + mediaW : pillX + baseW,
        recordingActive ? recordingX + recordingW : pillX + baseW,
        settingsActive ? settingsX + settingsW : pillX + baseW) - maskX
    readonly property real maskH: Math.max(pillY + baseH,
        mediaActive ? mediaY + mediaH : pillY + baseH,
        recordingActive ? recordingY + recordingH : pillY + baseH,
        sessionActive ? sessionY + sessionH : pillY + baseH,
        settingsActive ? settingsY + settingsH : pillY + baseH) - maskY

    function outsideBodies(x, y) {
        var inPill = x >= pillX && x <= pillX + baseW
            && y >= pillY && y <= pillY + baseH
        var inMedia = mediaActive && x >= mediaX && x <= mediaX + mediaW
            && y >= mediaY && y <= mediaY + mediaH
        var inRecording = recordingActive && x >= recordingX && x <= recordingX + recordingW
            && y >= recordingY && y <= recordingY + recordingH
        var inSession = sessionActive && x >= sessionX && x <= sessionX + sessionW
            && y >= sessionY && y <= sessionY + sessionH
        var inSettings = settingsActive && x >= settingsX && x <= settingsX + settingsW
            && y >= settingsY && y <= settingsY + settingsH
        return !inPill && !inMedia && !inRecording && !inSession && !inSettings
    }
}
