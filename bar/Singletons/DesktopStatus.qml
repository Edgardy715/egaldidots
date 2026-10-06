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

    signal volumeOSD(real progress, bool muted)
    signal micOSD(real progress, bool muted)
    signal brightnessOSD(real progress)
    signal batteryOSD(int percent, string status)

    function showVolumeOSD() {
        var sink = Pipewire.defaultAudioSink
        if (sink && sink.audio)
            root.volumeOSD(sink.audio.muted ? 0 : sink.audio.volume, sink.audio.muted)
    }
    function showSourceVolumeOSD() {
        var source = Pipewire.defaultAudioSource
        if (source && source.audio)
            root.micOSD(source.audio.muted ? 0 : source.audio.volume, source.audio.muted)
    }
    function showBrightnessOSD() {
        if (typeof Brightness !== "undefined" && Brightness.available)
            root.brightnessOSD(Brightness.percent / 100)
    }
    function adjustVolume(delta) {
        var sink = Pipewire.defaultAudioSink
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

    property var _pwSink: Pipewire.defaultAudioSink
    property var _pwAudio: null
    property var _pwSource: Pipewire.defaultAudioSource
    property var _pwSourceAudio: null
    function rebindSink() {
        audioSinkConn.target = root._pwSink
        var audio = root._pwSink ? root._pwSink.audio : null
        audioAudioConn.target = audio
        root._pwAudio = audio
    }
    function rebindSource() {
        audioSourceConn.target = root._pwSource
        var audio = root._pwSource ? root._pwSource.audio : null
        audioSourceAudioConn.target = audio
        root._pwSourceAudio = audio
    }
    on_PwSinkChanged: if (root.monitorServices) rebindSink()
    on_PwSourceChanged: if (root.monitorServices) rebindSource()
    Timer {
        interval: 500
        repeat: true
        running: root.monitorServices
        onTriggered: {
            var sink = Pipewire.defaultAudioSink
            var audio = sink ? sink.audio : null
            if (sink !== root._pwSink || audio !== root._pwAudio) {
                root._pwSink = sink
                root.rebindSink()
            }
            var source = Pipewire.defaultAudioSource
            var sourceAudio = source ? source.audio : null
            if (source !== root._pwSource || sourceAudio !== root._pwSourceAudio) {
                root._pwSource = source
                root.rebindSource()
            }
        }
    }
    Component.onCompleted: {
        if (!root.monitorServices) return
        root.rebindSink()
        root.rebindSource()
        getKbdState.running = true
    }
    PwObjectTracker {
        objects: root.monitorServices ? [root._pwSink, root._pwSource].filter(node => node) : []
    }
    Connections {
        id: audioSinkConn
        target: null
        enabled: root.monitorServices
        ignoreUnknownSignals: true
        function onPropertiesChanged() { root.showVolumeOSD() }
    }
    Connections {
        id: audioAudioConn
        target: null
        enabled: root.monitorServices
        ignoreUnknownSignals: true
        function onVolumesChanged() { root.showVolumeOSD() }
        function onMutedChanged() { root.showVolumeOSD() }
    }
    Connections {
        id: audioSourceConn
        target: null
        enabled: root.monitorServices
        ignoreUnknownSignals: true
        function onPropertiesChanged() { root.showSourceVolumeOSD() }
    }
    Connections {
        id: audioSourceAudioConn
        target: null
        enabled: root.monitorServices
        ignoreUnknownSignals: true
        function onVolumesChanged() { root.showSourceVolumeOSD() }
        function onMutedChanged() { root.showSourceVolumeOSD() }
    }
}
