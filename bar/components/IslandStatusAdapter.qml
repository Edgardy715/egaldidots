import QtQuick
import "../Singletons"

Item {
    id: root
    property bool fallbackVisible: false
    property real s: 1
    property bool observeServices: true
    readonly property bool capsLockOn: root.observeServices && DesktopStatus.capsLockOn

    signal showVolume(real progress, bool muted)
    signal showMic(real progress, bool muted)
    signal showBrightness(real progress)
    signal showBattery(int percent, string status)
    signal fallbackVolumeRequested(real scaleFactor)
    signal fallbackBrightnessRequested(real scaleFactor)

    property real _osdPendingProgress: 0
    property bool _osdPendingMuted: false
    property string _osdPendingKind: ""
    property bool _osdPending: false
    Timer {
        id: osdDebounce
        interval: 16
        onTriggered: {
            if (!root._osdPending) return
            root._osdPending = false
            switch (root._osdPendingKind) {
            case "volume":
                root.showVolume(root._osdPendingProgress, root._osdPendingMuted)
                if (root.fallbackVisible) root.fallbackVolumeRequested(root.s)
                break
            case "mic":
                root.showMic(root._osdPendingProgress, root._osdPendingMuted)
                if (root.fallbackVisible) root.fallbackVolumeRequested(root.s)
                break
            case "brightness":
                root.showBrightness(root._osdPendingProgress)
                if (root.fallbackVisible) root.fallbackBrightnessRequested(root.s)
                break
            }
        }
    }
    function _queueOSD(kind, progress, muted) {
        root._osdPendingKind = kind
        root._osdPendingProgress = progress
        root._osdPendingMuted = muted
        root._osdPending = true
        osdDebounce.restart()
    }
    function showVolumeOSD() { DesktopStatus.showVolumeOSD() }
    function showSourceVolumeOSD() { DesktopStatus.showSourceVolumeOSD() }
    function showBrightnessOSD() { DesktopStatus.showBrightnessOSD() }
    function adjustVolume(delta) { DesktopStatus.adjustVolume(delta) }

    Connections {
        target: root.observeServices ? DesktopStatus : null
        enabled: root.observeServices
        function onVolumeOSD(progress, muted) { root._queueOSD("volume", progress, muted) }
        function onMicOSD(progress, muted) { root._queueOSD("mic", progress, muted) }
        function onBrightnessOSD(progress) { root._queueOSD("brightness", progress, false) }
        function onBatteryOSD(percent, status) { root.showBattery(percent, status) }
    }
}
