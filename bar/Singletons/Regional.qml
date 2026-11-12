pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Time zone and region. The wall clock is shifted instead of switching the process
// TZ: `shift(date)` returns a Date whose local getters read as the chosen zone.
Singleton {
    id: root
    readonly property string zone: (Config.regional?.timeZone ?? "system")
    readonly property string region: (Config.regional?.region ?? "system")
    readonly property var locale: region === "system" ? Qt.locale() : Qt.locale(region)
    // 0 = Sunday … 6 = Saturday, as Date.getDay() counts (Qt.locale uses 7 for Sunday).
    readonly property int weekStart: locale.firstDayOfWeek % 7
    // Chosen zone minus the system zone, in ms; 0 while following the system.
    property real offsetMs: 0

    function shift(date) { return offsetMs === 0 ? date : new Date(date.getTime() + offsetMs) }
    function now() { return shift(new Date()) }

    function refresh() {
        if (zone === "system") { offsetMs = 0; return }
        probe.running = false
        probe.command = ["env", "TZ=" + zone, "date", "+%z"]
        probe.running = true
    }

    // Config loads after this singleton exists, so the first real zone arrives as a change.
    onZoneChanged: refresh()

    // DST can change the offset while running; re-read it hourly.
    Timer { interval: 3600000; repeat: true; running: root.zone !== "system"; onTriggered: root.refresh() }

    Process {
        id: probe
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /^([+-])(\d\d)(\d\d)/.exec(text.trim())
                if (!m) return
                const target = (m[1] === "-" ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3])) * 60000
                root.offsetMs = target + new Date().getTimezoneOffset() * 60000
            }
        }
    }
}
