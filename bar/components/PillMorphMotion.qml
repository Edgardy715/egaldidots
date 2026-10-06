import QtQuick

// One owner for retargetable dimensions, content exposure and notification breath.
Item {
    id: root
    property real s: 1
    property real targetW: 0
    property real targetH: 0
    property real targetRadius: 0
    property real restW: 0
    property real coreH: 38
    property bool surfaceOpen: false
    property bool workspaceAnimating: false
    property bool notifAnimating: false
    property bool notifHolding: false
    property bool reduceMotion: false
    property int morphDuration: 0
    property int notifCollapseDuration: 0
    readonly property int duration: notifAnimating ? notifCollapseDuration : morphDuration

    width: Math.min(targetW, 2000 * s)
    height: Math.min(targetH, 2000 * s)
    property real radius: targetRadius
    Behavior on width {
        enabled: !root.reduceMotion && (!root.workspaceAnimating || root.surfaceOpen || root.notifAnimating)
        SmoothedAnimation { duration: root.duration; velocity: -1 }
    }
    Behavior on height {
        enabled: !root.reduceMotion
        SmoothedAnimation { duration: root.duration; velocity: -1 }
    }
    Behavior on radius {
        enabled: !root.reduceMotion
        SmoothedAnimation { duration: root.duration; velocity: -1 }
    }
    readonly property real closeness: {
        var dw = Math.max(0.0001, targetW)
        var dh = Math.max(0.0001, targetH)
        var d = Math.max(Math.abs(width - targetW) / dw, Math.abs(height - targetH) / dh)
        return Math.max(0, 1 - d)
    }
    property real lastSurfaceW: 0
    property real lastSurfaceH: 0
    onTargetWChanged: if (surfaceOpen) lastSurfaceW = targetW
    onTargetHChanged: if (surfaceOpen) lastSurfaceH = targetH
    readonly property real surfaceGrowth: Math.max(0, Math.min(1, Math.min(
        (width - restW) / Math.max(1, lastSurfaceW - restW),
        (height - coreH) / Math.max(1, lastSurfaceH - coreH))))
    readonly property real contentProgress: Math.max(0, Math.min(1,
        (surfaceGrowth - 0.45) / 0.35))

    property real breath: 0
    SequentialAnimation on breath {
        running: !root.reduceMotion && root.notifHolding
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: 1400; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0; duration: 1400; easing.type: Easing.InOutSine }
    }
    readonly property real breathRadius: notifHolding ? breath * 2 * s : 0
    readonly property real breathGlow: notifHolding ? 0.12 + breath * 0.18 : 0
}
