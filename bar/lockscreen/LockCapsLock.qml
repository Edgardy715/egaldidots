import QtQuick
import Quickshell
import Quickshell.Io

// Caps Lock state for the lock screen alone. DesktopStatus would also pull in
// PipeWire, brightness and battery OSD wiring, which the lock process does not
// need. Reads the keyboard LEDs from sysfs only while `active`.
Item {
    id: root
    property bool active: false
    readonly property bool on: _on && active
    property bool _on: false
    property var _paths: []
    property var _values: ({})
    visible: false

    function refresh() {
        for (let i = 0; i < leds.instances.length; i++) leds.instances[i].reload()
    }
    function _set(path, value) {
        _values[path] = value
        _on = _paths.some(p => _values[p] === true)
    }

    Process {
        running: true
        command: ["sh", "-c", "for f in /sys/class/leds/*::capslock/brightness; do [ -r \"$f\" ] && printf '%s\\n' \"$f\"; done; exit 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._values = ({})
                root._paths = (text || "").split("\n").filter(path => path.length > 0)
            }
        }
    }
    Variants {
        id: leds
        model: root._paths
        FileView {
            required property string modelData
            path: modelData
            watchChanges: false
            printErrors: false
            onLoaded: root._set(modelData, text().trim() !== "0")
        }
    }
    Timer {
        interval: 250
        repeat: true
        running: root.active && root._paths.length > 0
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
