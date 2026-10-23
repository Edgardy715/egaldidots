import QtQuick
import "../Singletons"

QtObject {
    id: root
    property var clock: AmbientClock
    property bool running: false
    property var registeredClock: null
    signal triggered(real dt)
    function sync() {
        const next = running ? clock : null
        if (registeredClock === next) return
        if (registeredClock) registeredClock.subscribers--
        registeredClock = next
        if (registeredClock) registeredClock.subscribers++
    }
    onRunningChanged: sync()
    onClockChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (registeredClock) registeredClock.subscribers--
    property Connections clockConnection: Connections {
        target: root.clock
        enabled: root.running
        function onAdvanced(dt) { root.triggered(dt) }
    }
}
