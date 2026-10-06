import QtQuick
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    id: test
    settings.watchFiles: false
    property var actions: []
    property var streamToken: ({ token: 7 })

    Window {
        id: scene
        visible: true
        width: 640; height: 700
        color: Theme.background
        MixerView {
            id: view
            anchors.fill: parent
            s: 1.25
            vol: 0.42
            muted: false
            outputReady: true
            sourceVol: 0.25
            sourceMuted: true
            sourceReady: true
            appStreams: [{ node: test.streamToken, appName: "fixture-app", icon: "", volume: 0.38, muted: false }]
            onOutputVolumeRequested: value => test.actions.push(["output-volume", value])
            onOutputMuteToggleRequested: test.actions.push(["output-mute"])
            onSourceVolumeRequested: value => test.actions.push(["source-volume", value])
            onSourceMuteToggleRequested: test.actions.push(["source-mute"])
            onStreamVolumeRequested: (node, value) => test.actions.push(["stream-volume", node, value])
            onStreamMuteToggleRequested: node => test.actions.push(["stream-mute", node])
        }
    }

    function findObject(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const found = findObject(child, name)
            if (found) return found
        }
        return null
    }
    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.exit(1) }
    }

    Timer {
        interval: 250
        running: true
        onTriggered: {
            test.check(test.findObject(view, "outputVolumeSlider") !== null, "output control rendered")
            test.check(test.findObject(view, "sourceMuteToggle") !== null, "source control rendered")
            test.check(test.findObject(view, "streamMute-fixture-app") !== null, "stream control rendered")
            view.outputVolumeRequested(0.75)
            view.outputMuteToggleRequested()
            view.sourceMuteToggleRequested()
            view.streamMuteToggleRequested(test.streamToken)
            test.check(test.actions.length === 4, "all audio actions forwarded")
            test.check(test.actions[0][0] === "output-volume" && test.actions[0][1] === 0.75, "output volume payload")
            test.check(test.actions[1][0] === "output-mute" && test.actions[2][0] === "source-mute", "mute actions")
            test.check(test.actions[3][0] === "stream-mute" && test.actions[3][1] === test.streamToken, "opaque stream token forwarded")
            test.check(test.streamToken.token === 7, "stream payload remains unchanged")
            console.log("PASS: mixer view renders injected audio controls and emits mock actions without mutating payloads")
            Qt.quit()
        }
    }
}
