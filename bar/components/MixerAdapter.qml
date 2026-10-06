import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root
    property real s: 1
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: root.sink ? root.sink.audio : null
    readonly property real vol: root.audio ? root.audio.volume : 0
    readonly property bool muted: root.audio ? root.audio.muted : false
    readonly property bool outputReady: !!root.sink && root.sink.ready
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sourceAudio: root.source ? root.source.audio : null
    readonly property real sourceVol: root.sourceAudio ? root.sourceAudio.volume : 0
    readonly property bool sourceMuted: root.sourceAudio ? root.sourceAudio.muted : false
    readonly property bool sourceReady: !!root.source && root.source.ready
    readonly property var appStreams: {
        var nodes = Pipewire.nodes.values
        var out = []
        if (!nodes) return out
        for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i]
            if (!node.isStream) continue
            var props = node.properties || {}
            var appName = props["application.name"] || props["media.name"] || node.description || node.name || ""
            if (!appName || appName === "Unknown" || !node.audio) continue
            out.push({
                node: node,
                appName: appName,
                icon: root.appIconFor(appName),
                volume: node.audio.volume,
                muted: node.audio.muted
            })
        }
        return out
    }

    function appIconFor(name: string): string {
        return Quickshell.iconPath(name, true) ? Quickshell.iconPath(name) : ""
    }
    function clamp01(value): real { return Math.max(0, Math.min(1, value)) }
    function setVolume(device, value): void {
        if (!device || !device.audio) return
        device.audio.volume = root.clamp01(value)
        device.audio.muted = false
    }
    function toggleMute(device): void {
        if (!device || !device.audio || !device.ready) return
        device.audio.muted = !device.audio.muted
    }
    function toggleStreamMute(node): void {
        if (!node || !node.audio) return
        node.audio.muted = !node.audio.muted
    }

    MixerView {
        anchors.fill: parent
        s: root.s
        vol: root.vol
        muted: root.muted
        outputReady: root.outputReady
        sourceVol: root.sourceVol
        sourceMuted: root.sourceMuted
        sourceReady: root.sourceReady
        appStreams: root.appStreams
        onOutputVolumeRequested: value => root.setVolume(root.sink, value)
        onOutputMuteToggleRequested: root.toggleMute(root.sink)
        onSourceVolumeRequested: value => root.setVolume(root.source, value)
        onSourceMuteToggleRequested: root.toggleMute(root.source)
        onStreamVolumeRequested: (node, value) => root.setVolume(node, value)
        onStreamMuteToggleRequested: node => root.toggleStreamMute(node)
    }
}
