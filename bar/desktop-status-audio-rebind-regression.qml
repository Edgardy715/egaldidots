import QtQuick
import Quickshell
import "Singletons"

ShellRoot {
    id: test
    property var events: []

    QtObject {
        id: sinkA
        property QtObject audio: QtObject {
            property real volume: 0.42
            property bool muted: false
            signal volumesChanged()
        }
        signal propertiesChanged()
    }
    QtObject {
        id: sinkB
        property QtObject audio: QtObject {
            property real volume: 0.65
            property bool muted: false
            signal volumesChanged()
        }
        signal propertiesChanged()
    }
    QtObject {
        id: sourceA
        property QtObject audio: QtObject {
            property real volume: 0.31
            property bool muted: false
            signal volumesChanged()
        }
        signal propertiesChanged()
    }
    QtObject {
        id: sourceB
        property QtObject audio: QtObject {
            property real volume: 0.73
            property bool muted: false
            signal volumesChanged()
        }
        signal propertiesChanged()
    }

    Connections {
        target: DesktopStatus
        function onVolumeOSD(progress, muted) { test.events.push(["volume", progress, muted]) }
        function onMicOSD(progress, muted) { test.events.push(["mic", progress, muted]) }
    }

    function fail(message) {
        console.error("FAIL: " + message)
        Qt.exit(1)
    }
    function checkRebound() {
        sinkA.audio.volume = 0.9
        sinkA.audio.volume = 0.91
        sinkA.audio.volumesChanged()
        sourceA.audio.volume = 0.9
        sourceA.audio.volume = 0.91
        sourceA.audio.volumesChanged()
        if (events.length !== 2) return fail("old audio objects remained connected after hotplug: " + JSON.stringify(events))

        sinkB.audio.volume = 0.66
        sinkB.audio.volumesChanged()
        sinkB.audio.muted = true
        sourceB.audio.volume = 0.74
        sourceB.audio.volumesChanged()
        if (events.length !== 5 || JSON.stringify(events[2]) !== JSON.stringify(["volume", 0.66, false])
                || JSON.stringify(events[3]) !== JSON.stringify(["volume", 0, true])
                || JSON.stringify(events[4]) !== JSON.stringify(["mic", 0.74, false]))
            return fail("new audio objects did not drive OSD: " + JSON.stringify(events))

        DesktopStatus._pwSink = null
        DesktopStatus._pwSource = null
        sinkB.audio.volume = 0.67
        sinkB.audio.volumesChanged()
        sourceB.audio.volume = 0.75
        sourceB.audio.volumesChanged()
        if (events.length !== 5) return fail("disconnected audio objects still emitted OSD")

        DesktopStatus.monitorServices = false
        DesktopStatus._pwSink = sinkA
        DesktopStatus._pwSource = sourceA
        DesktopStatus.monitorServices = true
        sinkA.audio.volume = 0.92
        sinkA.audio.volumesChanged()
        sourceA.audio.volume = 0.92
        sourceA.audio.volumesChanged()
        if (events.length !== 7 || events[5][0] !== "volume" || events[6][0] !== "mic")
            return fail("monitorServices failed to re-enable audio observers: " + JSON.stringify(events))

        DesktopStatus.monitorServices = false
        DesktopStatus._pwSink = null
        DesktopStatus._pwSource = null
        console.log("PASS: Pipewire default nodes and audio interfaces rebind on hotplug; disabled observers stay quiet")
        Qt.quit()
    }

    Component.onCompleted: {
        DesktopStatus.monitorServices = false
        DesktopStatus._pwSink = sinkA
        DesktopStatus._pwSource = sourceA
        sinkA.audio.volume = 0.43
        sourceA.audio.volume = 0.32
        if (events.length !== 0) return fail("monitorServices=false delivered audio OSD")

        DesktopStatus.monitorServices = true
        sinkA.audio.volume = 0.44
        sinkA.audio.volumesChanged()
        sourceA.audio.volume = 0.33
        sourceA.audio.volumesChanged()
        if (events.length !== 2 || events[0][0] !== "volume" || events[1][0] !== "mic")
            return fail("initial audio observers did not deliver OSD: " + JSON.stringify(events))

        DesktopStatus._pwSink = sinkB
        DesktopStatus._pwSource = sourceB
        Qt.callLater(test.checkRebound)
    }
}
