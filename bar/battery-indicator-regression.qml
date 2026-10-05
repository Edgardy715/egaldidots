import QtQuick
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    readonly property var cases: [
        { level: 0.75, charging: false, paused: false, color: Theme.iconSecondary },
        { level: 0.52, charging: true, paused: false, color: "#30d158" },
        { level: 0.52, charging: false, paused: true, color: "#8e8e93" },
        { level: 0.35, charging: false, paused: false, color: "#ffd60a" },
        { level: 0.15, charging: false, paused: false, color: "#ff453a" }
    ]

    Window {
        visible: true
        width: 400
        height: 95
        color: "#1d1f21"
        Row {
            anchors.centerIn: parent
            spacing: 28
            Repeater {
                id: indicators
                model: cases
                BatteryIndicator {
                    required property var modelData
                    s: 2
                    level: modelData.level
                    charging: modelData.charging
                    chargePaused: modelData.paused
                }
            }
        }
    }

    Timer {
        interval: 800
        running: true
        onTriggered: {
            for (let i = 0; i < cases.length; i++) {
                const indicator = indicators.itemAt(i)
                if (!indicator || Math.abs(indicator.charge - cases[i].level) > 0.001
                    || indicator.tint.toString().toLowerCase() !== cases[i].color.toString().toLowerCase()) {
                    console.error("FAIL: battery state", i)
                    Qt.exit(1)
                    return
                }
            }
            console.log("PASS: normal, charging, paused, warning and low battery")
            Qt.exit(0)
        }
    }
}
