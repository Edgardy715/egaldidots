pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    property int subscribers: 0
    property double lastTick: 0
    readonly property bool running: subscribers > 0 && !Flags.reduceMotion
    signal advanced(real dt)
    onRunningChanged: lastTick = Date.now()
    Timer {
        interval: 83
        repeat: true
        running: root.running
        onTriggered: {
            const now = Date.now()
            const dt = Math.min(0.25, Math.max(0, (now - root.lastTick) / 1000))
            root.lastTick = now
            root.advanced(dt)
        }
    }
}
