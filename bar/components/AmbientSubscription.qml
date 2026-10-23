import QtQuick
import "../Singletons"

QtObject {
    id: root
    property bool running: false
    property bool registered: false
    signal triggered(real dt)
    function sync() {
        if (registered === running) return
        AmbientClock.subscribers += running ? 1 : -1
        registered = running
    }
    onRunningChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (registered) AmbientClock.subscribers--
    property Connections clockConnection: Connections {
        target: AmbientClock
        enabled: root.running
        function onAdvanced(dt) { root.triggered(dt) }
    }
}
