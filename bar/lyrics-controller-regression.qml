import QtQuick
import Quickshell
import "components"

ShellRoot {
    settings.watchFiles: false
    LyricsController {
        id: lyrics
        endpoint: Quickshell.env("ISLA_LYRICS_TEST_ENDPOINT")
        title: "synced"
        artist: "QA"
        duration: 30
    }
    Timer {
        interval: 350
        running: true
        repeat: true
        property int step: 0
        property int held: 0
        function check(value, message) { if (!value) throw new Error(message + ": " + lyrics.status) }
        onTriggered: {
            try {
                if (step === 0) { check(lyrics.status === "idle", "no background request"); lyrics.active = true }
                else if (step === 1) { check(lyrics.status === "ready" && lyrics.synced && lyrics.lines.length === 3, "synced result"); lyrics.active = false; held = lyrics.generation; lyrics.active = true }
                else if (step === 2) { check(lyrics.generation === held && lyrics.status === "ready", "cached reopen"); lyrics.title = "plain" }
                else if (step === 3) { check(lyrics.status === "ready" && !lyrics.synced, "plain result"); lyrics.title = "empty" }
                else if (step === 4) { check(lyrics.status === "empty" && lyrics.lines.length === 0, "not found"); lyrics.title = "broken" }
                else if (step === 5) { check(lyrics.status === "error", "malformed result"); lyrics.title = "instrumental" }
                else if (step === 6) { check(lyrics.status === "instrumental", "instrumental"); lyrics.title = "slow" }
                else if (step === 7) { check(lyrics.status === "loading", "pending request"); lyrics.title = "synced"; check(lyrics.lines.length === 0, "clear stale lyrics immediately") }
                else if (step === 8) { check(lyrics.status === "ready", "latest track ready") }
                else if (step === 9) { check(lyrics.lines[0].text === "Primera línea de prueba", "ignore late response"); lyrics.title = "slow" }
                else if (step === 10) { check(lyrics.status === "loading", "pending before close"); lyrics.active = false }
                else if (step === 11) { check(lyrics.status === "idle" && lyrics.lines.length === 0, "close cancels") }
                else { check(lyrics.status === "idle", "late response after close"); console.log("PASS: on-demand lyrics, cached reopen, plain/empty/error/instrumental, stale track and close cancellation"); Qt.quit() }
                step++
            } catch (error) { console.error("FAIL: lyrics controller", error); Qt.exit(1) }
        }
    }
    Timer { interval: 7000; running: true; onTriggered: Qt.exit(1) }
}
