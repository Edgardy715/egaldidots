import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "components"

ShellRoot {
    settings.watchFiles: false
    id: root
    readonly property bool live: Quickshell.env("ISLA_MEDIA_CLOCK_CASE") === "live"
    readonly property var spotify: {
        if (!root.live) return null
        const list = Mpris.players.values
        for (let i = 0; i < list.length; i++)
            if ((list[i].dbusName || "").toLowerCase().indexOf("spotify") >= 0) return list[i]
        return null
    }
    QtObject {
        id: fake
        property bool isPlaying: false
        property bool canControl: true
        property bool canSeek: true
        property bool positionSupported: true
        property bool lengthSupported: true
        property real length: 120
        property real position: 30
        property real rate: 1
        property string trackTitle: "Mock"
        property string trackArtist: "QA"
        property string trackAlbum: "Test"
    }
    MediaSession {
        id: session
        player: root.live ? root.spotify : fake
        active: true
        trackKey: root.live ? (root.spotify ? root.spotify.trackTitle : "") : "first"
    }
    Timer {
        id: sample
        interval: 1000
        repeat: true
        running: !root.live && fake.isPlaying
        property real anchor: 30
        property real started: 0
        onTriggered: fake.position = anchor + (Date.now() - started) / 1000 * fake.rate
    }
    Timer {
        interval: 100
        running: true
        repeat: true
        property int ticks: 0
        property real started: 0
        property real frozen: 0
        function close(actual, expected, tolerance, what) {
            if (Math.abs(actual - expected) > tolerance) {
                console.error("FAIL: media clock", what, actual.toFixed(3), expected.toFixed(3)); Qt.exit(1)
            }
        }
        onTriggered: {
            ticks++
            if (root.live) {
                if (!root.spotify) { console.error("FAIL: Spotify MPRIS unavailable"); Qt.exit(2); return }
                const diff = Math.abs(session.displayPosition - root.spotify.position)
                close(session.displayPosition, root.spotify.position, 0.15, "live MPRIS position")
                console.log("CLOCK", ticks, root.spotify.isPlaying, root.spotify.position.toFixed(3), session.displayPosition.toFixed(3), diff.toFixed(3))
                if (ticks >= 30) { console.log("PASS: live media clock"); Qt.quit() }
                return
            }
            if (ticks === 1) {
                fake.isPlaying = true
                started = Date.now()
                sample.anchor = 30; sample.started = started
            } else if (ticks === 7 || ticks === 15) {
                close(session.displayPosition, 30 + (Date.now() - started) / 1000, 0.15, "sparse MPRIS samples")
                if (ticks === 15) {
                    fake.position = 30 + (Date.now() - started) / 1000
                    fake.isPlaying = false
                    frozen = session.displayPosition
                }
            } else if (ticks === 19) {
                close(session.displayPosition, frozen, 0.02, "pause holds position")
                fake.position = 50
                close(session.displayPosition, 50, 0.02, "external seek")
            } else if (ticks === 20) {
                fake.rate = 2
                fake.isPlaying = true
                started = Date.now()
                sample.anchor = 50; sample.started = started
            } else if (ticks === 27) {
                close(session.displayPosition, 50 + (Date.now() - started) / 1000 * 2, 0.2, "playback rate")
                fake.position = 0
                session.trackKey = "second"
                close(session.displayPosition, 0, 0.02, "track change")
                fake.isPlaying = false
                session.active = false
                frozen = session.displayPosition
            } else if (ticks === 31) {
                close(session.displayPosition, frozen, 0.02, "closed clock")
                fake.position = 12
                session.active = true
                close(session.displayPosition, 12, 0.02, "reopen position")
                console.log("PASS: sparse-signal clock, pause, seek, rate, track change and reopen")
                Qt.quit()
            }
            if (ticks > 45) { console.error("FAIL: media clock timeout"); Qt.exit(1) }
        }
    }
}
