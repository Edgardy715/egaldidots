import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "components"

ShellRoot {
    id: test
    function check(value, message) {
        if (!value) { console.error("FAIL: " + message); Qt.exit(1) }
    }
    QtObject {
        id: player
        property bool isPlaying: false
        property bool canControl: true
        property bool canSeek: true
        property bool positionSupported: true
        property bool lengthSupported: true
        property bool shuffleSupported: true
        property bool loopSupported: true
        property bool canGoPrevious: true
        property bool canGoNext: true
        property bool canTogglePlaying: true
        property bool shuffle: false
        property int loopState: MprisLoopState.None
        property real length: 120
        property real position: 30
        property real rate: 1
        property string trackTitle: "Track"
        property string trackArtist: "Artist"
        property string trackAlbum: "Album"
        property int commands: 0
        function previous() { commands++ }
        function next() { commands++ }
        function togglePlaying() { commands++; isPlaying = !isPlaying }
    }
    MediaSession { id: session; player: player; active: true; trackKey: "first" }
    Timer {
        interval: 20; running: true
        onTriggered: {
            test.check(session.progress === 0.25, "initial progress")
            session.seekTo(500)
            test.check(player.position === 120, "seek clamp")
            session.seekTo(NaN)
            test.check(player.position === 120, "nonfinite seek ignored")
            session.beginDrag(0.5)
            session.trackKey = "second"
            session.commitDrag(0.8)
            test.check(!session.dragging && player.position === 120, "track change cancels seek")
            session.beginDrag(0.5)
            session.player = null
            session.commitDrag(0.8)
            test.check(!session.canSeek && !session.dragging, "player loss cancels seek")
            session.player = player
            player.canControl = false
            session.previous(); session.next(); session.togglePlaying(); session.toggleShuffle(); session.cycleRepeat()
            test.check(player.commands === 0 && !player.shuffle && player.loopState === MprisLoopState.None, "unsupported actions")
            player.canControl = true
            session.previous(); session.next(); session.togglePlaying(); session.toggleShuffle(); session.cycleRepeat()
            test.check(player.commands === 3 && player.shuffle && session.repeatOne, "supported actions")
            session.cycleRepeat(); test.check(player.loopState === MprisLoopState.Playlist, "repeat playlist")
            session.cycleRepeat(); test.check(player.loopState === MprisLoopState.None, "repeat off")
            player.position = 30
            advance.start()
        }
    }
    Timer {
        id: advance; interval: 200
        onTriggered: {
            test.check(session.position > 30, "active position clock")
            session.active = false
            stopped.value = session.position
            stopped.start()
        }
    }
    Timer {
        id: stopped; interval: 150; property real value: 0
        onTriggered: {
            test.check(session.position === value, "inactive clock stopped")
            console.log("PASS: media session capabilities, seek, track/player interruption, repeat and clock lifecycle")
            Qt.quit()
        }
    }
    Timer { interval: 3000; running: true; onTriggered: { console.error("FAIL: timeout"); Qt.exit(1) } }
}
