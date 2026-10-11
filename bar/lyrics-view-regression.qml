import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        width: IslandGeometry.mediaSurface.width
        height: IslandGeometry.mediaSurface.height
        MediaView {
            id: media
            open: true
            lyricsSupported: true
            lyricsStatus: "ready"
            lyricsSynced: true
            lyricLines: [{time:0,text:"Primera línea sintética"},{time:5,text:"Segunda línea sintética"},{time:10,text:"Una línea larga de prueba que debe ajustarse al ancho disponible sin invadir los controles"},{time:15,text:"Última línea de prueba"}]
            playback: ({hasPlayer:true,isPlaying:false,title:"Canción de prueba",artist:"Artista QA",albumDistinct:false,canSeek:true,canShuffle:false,canRepeat:false,canPrevious:false,canNext:false,canToggle:true,dragging:false,progress:0.3,displayPosition:6,length:30,displayTime:"0:06",remainingTime:"0:24"})
        }
        SignalSpy { id: retry; target: media; signalName: "lyricsRetryRequested" }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "LyricsView"
            when: scene.visible
            property bool finished: false
            function test_lyrics() {
                try {
                    wait(100)
                    const button = findChild(media, "mediaLyricsToggle")
                    mouseClick(button, button.width / 2, button.height / 2)
                    verify(media.lyricsOpen)
                    const list = findChild(media, "mediaLyricsList")
                    wait(100)
                    compare(list.currentIndex, 1)
                    const row = list.itemAtIndex(1)
                    verify(row && row.width <= list.width && row.color === Theme.foreground)
                    list.forceActiveFocus()
                    keyClick(Qt.Key_Down)
                    compare(list.currentIndex, -1)
                    keyClick(Qt.Key_Escape)
                    verify(!media.lyricsOpen)
                    media.lyricsOpen = true
                    media.lyricsSynced = false
                    wait(50)
                    compare(list.currentIndex, -1)
                    media.lyricsStatus = "empty"
                    wait(50)
                    verify(!list.visible)
                    media.lyricsSupported = false
                    verify(!media.lyricsOpen && !button.visible)
                    console.log("PASS: lyrics toggle, timed highlight, manual browsing, plain/empty, Escape and unsupported player")
                    finished = true
                } catch (error) { console.error("FAIL: lyrics view", error); failure.start() }
            }
        }
    }
    Timer { id: failure; interval: 50; onTriggered: Qt.exit(1) }
    Timer { interval: 5000; running: true; onTriggered: Qt.exit(1) }
}
