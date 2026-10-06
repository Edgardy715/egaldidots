import QtQuick
import "../"
import "../components"
import "../Singletons"

PillSurface {
    id: root
    mTop: Theme.marginLg
    mLeft: Theme.marginLg
    mRight: Theme.marginLg
    mBottom: Theme.marginLg

    readonly property var sink: adapter.sink
    readonly property var audio: adapter.audio
    readonly property real vol: adapter.vol
    readonly property bool muted: adapter.muted
    readonly property var source: adapter.source
    readonly property var sourceAudio: adapter.sourceAudio
    readonly property real sourceVol: adapter.sourceVol
    readonly property bool sourceMuted: adapter.sourceMuted
    readonly property var appStreams: adapter.appStreams

    function appIconFor(name: string): string { return adapter.appIconFor(name) }
    function clamp01(value): real { return adapter.clamp01(value) }
    function setVolume(device, value): void { adapter.setVolume(device, value) }

    MixerAdapter {
        id: adapter
        anchors.fill: parent
        s: root.s
    }
}
