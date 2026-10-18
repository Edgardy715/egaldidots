import QtQuick
import Quickshell
import "components"

ShellRoot {
    settings.watchFiles: false
    readonly property string scenario: Quickshell.env("ISLA_LYRICS_TEST_CASE") || "fallback"
    LyricsController {
        id: lyrics
        endpoint: scenario === "live" ? "https://lrclib.net/api/get" : Quickshell.env("ISLA_LYRICS_TEST_ENDPOINT")
        title: scenario === "live" ? "HOY AQUÍ" : scenario === "retry" ? "flaky" : scenario === "outage" ? "outage" :
            scenario === "hang" ? "hang" : scenario === "hangout" ? "hangout" :
            scenario === "blank" ? "blank" : scenario === "empty" ? "missing" :
            scenario === "stale" || scenario === "close" ? "slow" : "fallback"
        artist: scenario === "live" ? "Rauw Alejandro" : "QA"
        album: scenario === "live" ? "PLAYA SATURNO" : "Album"
        duration: scenario === "live" ? 187.826 : 30
        Component.onCompleted: if (scenario === "hang" || scenario === "hangout") timeout.interval = 250
    }
    Timer {
        interval: 100
        running: true
        repeat: true
        property int ticks: 0
        property int step: 0
        property int generationAfterClose: 0
        onTriggered: {
            ticks++
            if (ticks > (scenario === "live" ? 200 : 100)) { console.error("FAIL: lyrics timeout", scenario, step, lyrics.status); Qt.exit(1); return }
            if (step === 0) {
                if (lyrics.status !== "idle") { console.error("FAIL: background request"); Qt.exit(1); return }
                lyrics.active = true
                step++
            } else if (scenario === "live") {
                if (lyrics.status === "ready" && lyrics.lines.length > 0) {
                    console.log("PASS: live lyrics", lyrics.synced, lyrics.lines.length); Qt.quit()
                } else if (lyrics.status === "error" || lyrics.status === "empty") {
                    console.error("FAIL: live lyrics", lyrics.status); Qt.exit(1)
                }
            } else if (scenario === "fallback" || scenario === "retry" || scenario === "blank" || scenario === "hang") {
                if (lyrics.status === "error" || lyrics.status === "empty") { console.error("FAIL: acquisition", scenario, lyrics.status); Qt.exit(1); return }
                if (lyrics.status === "ready") {
                    if (!lyrics.synced || lyrics.lines.length !== 2 || lyrics.lines[0].text !== "Primera línea de prueba") {
                        console.error("FAIL: wrong result", scenario); Qt.exit(1); return
                    }
                    if (scenario !== "hang" || ticks >= 17) { console.log("PASS: lyrics", scenario); Qt.quit() }
                }
            } else if (scenario === "outage" || scenario === "hangout") {
                if (lyrics.status === "error") { console.log("PASS: lyrics", scenario); Qt.quit() }
                else if (lyrics.status === "empty") { console.error("FAIL: outage shown as missing lyrics"); Qt.exit(1) }
            } else if (scenario === "stale") {
                if (step === 1 && ticks >= 3) { lyrics.title = "plain"; step++ }
                else if (step === 2 && lyrics.status === "ready") {
                    if (lyrics.synced || lyrics.lines[0].text !== "Texto nuevo") { console.error("FAIL: stale result"); Qt.exit(1); return }
                    step++
                } else if (step === 3 && ticks >= 18) {
                    if (lyrics.status !== "ready" || lyrics.lines[0].text !== "Texto nuevo") { console.error("FAIL: late response replaced track"); Qt.exit(1); return }
                    console.log("PASS: lyrics stale response"); Qt.quit()
                }
            } else if (scenario === "close") {
                if (step === 1 && ticks >= 3) { lyrics.active = false; generationAfterClose = lyrics.generation; step++ }
                else if (step === 2 && ticks >= 16) {
                    if (lyrics.status !== "idle" || lyrics.lines.length !== 0) { console.error("FAIL: closed request applied"); Qt.exit(1); return }
                    lyrics.title = "fallback"; lyrics.active = true; step++
                } else if (step === 3 && lyrics.status === "ready") {
                    lyrics.active = false; generationAfterClose = lyrics.generation; lyrics.active = true; step++
                } else if (step === 4) {
                    if (lyrics.status !== "ready" || lyrics.generation !== generationAfterClose) { console.error("FAIL: cached reopen"); Qt.exit(1); return }
                    console.log("PASS: lyrics close and cached reopen"); Qt.quit()
                }
            } else if (scenario === "empty") {
                if (step === 1 && lyrics.status === "empty") { lyrics.active = false; lyrics.active = true; step++ }
                else if (step === 2 && lyrics.status === "empty" && ticks >= 5) { console.log("PASS: lyrics empty retry on reopen"); Qt.quit() }
            }
        }
    }
}
