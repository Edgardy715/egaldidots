import QtQuick
import Quickshell

ShellRoot {
    settings.watchFiles: false
    QtObject {
        id: fakeAuth
        property var flow: null
        property bool active: false
        property bool sudoActive: false
        property bool sudoCanRespond: false
        property bool sudoSubmitting: false
        property bool sudoSuccess: false
        property bool sudoError: false
        property string sudoPrompt: ""
        property bool polkitSubmitting: false
        property bool polkitSuccess: false
        property bool polkitError: false
        property string polkitMessage: ""
        signal authenticationRequestStarted()
        signal sudoRequestStarted()
        function submit(secret) { return false }
        function submitSudo(secret) { return false }
        function cancel() {}
        function cancelSudo() {}
        function beginSudoRetry() {}
    }
    Window {
        id: scene
        visible: true; width: 1100; height: 760
        Loader { id: host; anchors.fill: parent }
        property int current: 0
        readonly property var names: ["Auth", "Appearance", "Calendar", "Clipboard", "Connectivity", "Launcher", "Media", "Mixer", "Notifs", "Overview", "Session", "Utils", "Wallpaper", "Workspaces"]
        Timer {
            interval: 130; running: true; repeat: true
            onTriggered: {
                if (host.status === Loader.Error) { console.error("FAIL: surface load", scene.names[scene.current - 1]); Qt.exit(1); return }
                if (scene.current === scene.names.length) {
                    console.log("PASS: all 14 surfaces load with shared interaction primitives")
                    Qt.quit(); return
                }
                const name = scene.names[scene.current++]
                const source = "surfaces/" + name + "Surface.qml"
                if (name === "Auth") host.setSource(source, {backend: fakeAuth})
                else host.source = source
            }
        }
    }
}
