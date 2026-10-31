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
        if (!sink || !sink.audio) return
        root._sinkLevel = root._level(sink)
        root.volumeOSD(sink.audio.muted ? 0 : sink.audio.volume, sink.audio.muted)
    }
    function showSourceVolumeOSD() {
        var source = root._pwSource
        if (!source || !source.audio) return
        root._sourceLevel = root._level(source)
        root.micOSD(source.audio.muted ? 0 : source.audio.volume, source.audio.muted)
    }
    // Node properties also change when a view starts or stops tracking the node
    // (the mixer closing), which is no reason to show the level again.
    // The node id is part of the level: a new default device at the same volume still shows it.
    function _level(node) { return node.id + ":" + node.audio.muted + ":" + node.audio.volume }
    property string _sinkLevel: ""
    property string _sourceLevel: ""
    function _sinkPropertiesChanged() {
        var a = root._pwSink ? root._pwSink.audio : null
        if (a && root._level(root._pwSink) !== root._sinkLevel) root.showVolumeOSD()
    }
    function _sourcePropertiesChanged() {
        var a = root._pwSource ? root._pwSource.audio : null
        if (a && root._level(root._pwSource) !== root._sourceLevel) root.showSourceVolumeOSD()
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
                root._refreshCapsLock()
        }
    }

    // Hyprland no emite eventos de Caps Lock. Leer el LED del kernel evita lanzar
    // hyprctl y parsear ~10 KB de JSON cada segundo; Hyprland sincroniza el LED de
    // los teclados, así que basta con que uno esté encendido. hyprctl queda como
    // respaldo sólo si el sistema no expone LEDs de capslock.
    property string capsLedPattern: "/sys/class/leds/*::capslock/brightness"
    property var _capsLedPaths: []
    property var _capsLedValues: ({})
    property bool _capsLedsResolved: false
    readonly property string capsLockSource: _capsLedPaths.length > 0 ? "leds"
        : _capsLedsResolved ? "hyprctl" : ""
    onMonitorServicesChanged: if (monitorServices) rediscoverCapsLeds()
    onCapsLedPatternChanged: rediscoverCapsLeds()

    function rediscoverCapsLeds() {
        if (capsLedDiscovery.running) {
            capsLedDiscovery.pending = true
            return
        }
        capsLedDiscovery.pattern = root.capsLedPattern
        capsLedDiscovery.running = true
    }
    function _refreshCapsLock() {
        if (root._capsLedPaths.length > 0) {
            for (var i = 0; i < capsLeds.instances.length; i++) capsLeds.instances[i].reload()
        } else if (root._capsLedsResolved && !getKbdState.running) {
            getKbdState.running = true
        }
    }
    function _setCapsLed(path, on) {
        root._capsLedValues[path] = on
        root._capsLockOn = root._capsLedPaths.some(p => root._capsLedValues[p] === true)
    }

    Process {
        id: capsLedDiscovery
        property string pattern: ""
        property bool pending: false
        command: ["sh", "-c", "for f in $1; do [ -r \"$f\" ] && printf '%s\\n' \"$f\"; done; exit 0",
                  "sh", pattern]
        onExited: if (pending) {
            pending = false
            root.rediscoverCapsLeds()
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (capsLedDiscovery.pending || capsLedDiscovery.pattern !== root.capsLedPattern) return
                root._capsLedValues = ({})
                root._capsLedPaths = (text || "").split("\n").filter(path => path.length > 0)
                root._capsLedsResolved = true
                root._refreshCapsLock()
            }
        }
    }
    Variants {
        id: capsLeds
        model: root.monitorServices ? root._capsLedPaths : []
        FileView {
            required property string modelData
            path: modelData
            watchChanges: false
            printErrors: false
            onLoaded: root._setCapsLed(modelData, text().trim() !== "0")
            // Teclado desconectado o renumerado: se vuelve a buscar sin martillear.
            onLoadFailed: if (!capsLedRetry.running) capsLedRetry.start()
        }
    }
    Timer { id: capsLedRetry; interval: 2000; onTriggered: root.rediscoverCapsLeds() }
    Timer {
        // Lectura de sysfs en el pool de E/S, sin procesos; respaldo hyprctl a 1 Hz.
        interval: root._capsLedPaths.length > 0 ? 250 : 1000
        repeat: true
        running: root.monitorServices && root._capsLedsResolved
        onTriggered: root._refreshCapsLock()
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
    Component.onCompleted: if (root.monitorServices) rediscoverCapsLeds()
    PwObjectTracker {
        objects: root.monitorServices ? [root._pwSink, root._pwSource].filter(node => node) : []
    }
    Connections {
        id: audioSinkConn
        target: root._pwSink || null
        enabled: root.monitorServices
        ignoreUnknownSignals: true
        function onPropertiesChanged() { root._sinkPropertiesChanged() }
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
        function onPropertiesChanged() { root._sourcePropertiesChanged() }
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
