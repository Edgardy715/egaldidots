pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property bool capsLockOn: _capsLockOn
    property bool _capsLockOn: false
    property bool monitorServices: true
    readonly property string batteryStatus: {
        const device = UPower.displayDevice
        if (!device || !device.ready || !device.isLaptopBattery || !device.isPresent) return ""
        return device.state === UPowerDeviceState.Charging
            || device.state === UPowerDeviceState.FullyCharged && !UPower.onBattery ? "charging"
            : device.state === UPowerDeviceState.PendingCharge ? "paused" : "discharging"
    }

    signal volumeOSD(real progress, bool muted)
    signal micOSD(real progress, bool muted)
    signal brightnessOSD(real progress)
    signal batteryOSD(int percent, string status)

    function showVolumeOSD() {
        var sink = root._pwSink
        if (sink && sink.audio)
            root.volumeOSD(sink.audio.muted ? 0 : sink.audio.volume, sink.audio.muted)
    }
    function showSourceVolumeOSD() {
        var source = root._pwSource
        if (source && source.audio)
            root.micOSD(source.audio.muted ? 0 : source.audio.volume, source.audio.muted)
    }
    function showBrightnessOSD() {
        if (typeof Brightness !== "undefined" && Brightness.available)
            root.brightnessOSD(Brightness.percent / 100)
    }
    function adjustVolume(delta) {
        var sink = root._pwSink
        if (sink && sink.audio && sink.ready) {
            sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + delta))
            root.showVolumeOSD()
        }
    }
    function showBatteryOSD() {
        var device = UPower.displayDevice
        if (!device || !device.ready || !device.isLaptopBattery || !device.isPresent) return
        var charging = device.state === UPowerDeviceState.Charging
            || device.state === UPowerDeviceState.FullyCharged && !UPower.onBattery
        root.batteryOSD(Math.round(device.percentage * 100), charging ? "charging"
            : device.state === UPowerDeviceState.PendingCharge ? "paused" : "discharging")
    }

    Connections {
        target: Brightness
        enabled: root.monitorServices
        function onBrightnessChanged(p) { root.showBrightnessOSD() }
    }
    Connections {
        target: Hyprland
        enabled: root.monitorServices
        function onRawEvent(event) {
            var name = "" + (event ? (event.name || event.event || event.type || "") : "")
            if (root.monitorServices && (name === "activelayout" || name === "submap"))
                getKbdState.running = true
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.monitorServices
        onTriggered: if (!getKbdState.running) getKbdState.running = true
    }
    Process {
        id: getKbdState
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            id: kbdCollector
            onStreamFinished: {
                var text = (kbdCollector.text || "").trim()
                if (!text.length) return
                try {
                    var data = JSON.parse(text)
                    var keyboards = (data && data.keyboards) || []
                    for (var i = 0; i < keyboards.length; i++) {
                        if (keyboards[i] && keyboards[i].main) {
                            root._capsLockOn = keyboards[i].capsLock === true
                            break
                        }
                    }
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 60000
        repeat: true
        running: {
            if (!root.monitorServices) return false
            var device = UPower.displayDevice
            return device && device.ready && device.isLaptopBattery && device.isPresent
                && UPower.onBattery && device.percentage <= 0.15
        }
        onTriggered: root.showBatteryOSD()
    }
    Connections {
        target: UPower.displayDevice
        enabled: root.monitorServices
        ignoreUnknownSignals: true
        function onStateChanged() { root.showBatteryOSD() }
        function onPercentageChanged() { root.showBatteryOSD() }
    }

    property var _pwSink: Pipewire.defaultAudioSink || null
    property var _pwAudio: root._pwSink ? root._pwSink.audio : null
    property var _pwSource: Pipewire.defaultAudioSource || null
    property var _pwSourceAudio: root._pwSource ? root._pwSource.audio : null
    Component.onCompleted: if (root.monitorServices) getKbdState.running = true
    PwObjectTracker {
        objects: root.monitorServices ? [root._pwSink, root._pwSource].filter(node => node) : []
    }
    Connections {
        id: audioSinkConn
        target: root._pwSink || null
        enabled: root.monitorServices
        ignoreUnknownSignals: true
        function onPropertiesChanged() { root.showVolumeOSD() }
    }
    Connections {
        id: audioAudioConn
        target: root._pwAudio || null
        enabled: root.monitorServices
        ignoreUnknownSignals: true
        function onVolumesChanged() { root.showVolumeOSD() }
        function onMutedChanged() { root.showVolumeOSD() }
    }
    Connections {
        id: audioSourceConn
        target: root._pwSource || null
        enabled: root.monitorServices
        ignoreUnknownSignals: true
        function onPropertiesChanged() { root.showSourceVolumeOSD() }
    }
    Connections {
        id: audioSourceAudioConn
        target: root._pwSourceAudio || null
        enabled: root.monitorServices
        ignoreUnknownSignals: true
        function onVolumesChanged() { root.showSourceVolumeOSD() }
        function onMutedChanged() { root.showSourceVolumeOSD() }
    }
}
