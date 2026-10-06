import QtQuick

QtObject {
    id: root
    property string monitorName: ""
    property string focusedMonitorName: ""
    property var monitors: []
    property string surface: ""
    property bool launcherClosing: false

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
    property bool sessionActive: false
    property real sessionX: 0
    property real sessionY: 0
    property real sessionW: 0
    property real sessionH: 0

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
    readonly property bool kbFocusWanted: surfaceOpen && !monFullscreen && !launcherClosing
    readonly property bool modal: surfaceOpen && !launcherClosing
    readonly property bool exclusiveFocus: (surface === "launcher" && !launcherClosing)
        || surface === "wallpaper" || surface === "overview" || surface === "clipboard"
        || surface === "session" || surface === "auth"
    readonly property bool authFocusGrab: surface === "auth" && surfaceOpen
    readonly property bool escapeShortcutEnabled: surfaceOpen && surface !== "session" && surface !== "auth"
    readonly property string maskMode: monFullscreen ? "hidden" : modal ? "full" : "pill"

    readonly property real baseW: Math.max(pillWidth, pillTargetW)
    readonly property real baseH: Math.max(pillHeight, pillTargetH)
    readonly property real maskX: Math.min(pillX + (pillWidth - baseW) / 2,
        sessionActive ? sessionX : pillX)
    readonly property real maskY: Math.min(pillY, mediaActive ? mediaY : pillY)
    readonly property real maskW: Math.max(pillX + baseW,
        mediaActive ? mediaX + mediaW : pillX + baseW) - maskX
    readonly property real maskH: Math.max(pillY + baseH,
        mediaActive ? mediaY + mediaH : pillY + baseH,
        sessionActive ? sessionY + sessionH : pillY + baseH) - maskY

    function outsideBodies(x, y) {
        var inPill = x >= pillX && x <= pillX + baseW
            && y >= pillY && y <= pillY + baseH
        var inMedia = mediaActive && x >= mediaX && x <= mediaX + mediaW
            && y >= mediaY && y <= mediaY + mediaH
        var inSession = sessionActive && x >= sessionX && x <= sessionX + sessionW
            && y >= sessionY && y <= sessionY + sessionH
        return !inPill && !inMedia && !inSession
    }
}
