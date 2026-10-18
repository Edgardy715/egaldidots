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
        width: 720; height: 440
        minimumWidth: 720; maximumWidth: 720
        minimumHeight: 440; maximumHeight: 440
        color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 1)
        PillMaterial {
            surface: "media"
            morphRadius: 26
            artUrl: media.artUrl
        }
        property bool playing: false
        property real position: 6
        property bool seeking: true
        MediaView {
            id: media
            open: true
            musicPresentation: true
            artUrl: String(Qt.resolvedUrl("tests/fixtures/artwork-coral.svg"))
            cavaAvailable: true
            cavaHasFrame: true
            cavaValues: Array.from({length:32}, (_,i) => 0.15 + 0.7 * Math.abs(Math.sin(i * 0.72)))
            lyricsSupported: true
            lyricsStatus: "ready"
            lyricsSynced: true
            lyricLines: Array.from({length: 18}, (_, i) => ({time: i * 5, text: ["Dejamos que la noche respire", "La música encuentra su lugar", "Cada palabra sigue el ritmo", "Y vuelve a comenzar"][i % 4]}))
            playback: ({hasPlayer:true,isPlaying:scene.playing,title:"La noche en movimiento",artist:"Estudio Isla",album:"Sesiones",albumDistinct:true,canSeek:scene.seeking,canShuffle:true,canRepeat:true,canPrevious:true,canNext:true,canToggle:true,dragging:false,progress:scene.position/100,displayPosition:scene.position,length:100,displayTime:"0:06",remainingTime:"1:34",shuffleEnabled:false,repeatEnabled:false,repeatOne:false})
        }
        SignalSpy { id: toggles; target: media; signalName: "togglePlayingRequested" }
        SignalSpy { id: seeks; target: media; signalName: "seekRequested" }
        TestCase {
            id: checks
            name: "SwiftifyMedia"
            when: scene.visible
            property bool finished: false
            function capture(name) {
                const folder = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!folder) return
                let saved = false
                scene.contentItem.grabToImage(result => { saved = result.saveToFile(folder + "/" + name + ".png") })
                tryVerify(() => saved, 2500)
            }
            function test_motion_and_lyrics() {
                try {
                    Config.update({appearance:{reduceMotion:false,mediaTransitions:true}})
                    wait(120)
                    const cover = findChild(media, "mediaArtwork")
                    const toggle = findChild(media, "mediaToggle")
                    tryCompare(cover, "scale", 0.94)
                    compare(toggle.morph, 0)
                    capture("01-paused")
                    scene.playing = true
                    wait(60)
                    verify(cover.scale > 0.94 && cover.scale < 1)
                    verify(toggle.morph > 0 && toggle.morph < 1)
                    capture("02-play-transition")
                    scene.playing = false
                    wait(35)
                    scene.playing = true
                    tryCompare(cover, "scale", 1)
                    tryCompare(toggle, "morph", 1)
                    capture("03-playing")
                    const spectrum = findChild(media, "mediaRadialSpectrum")
                    compare(spectrum.count, 48)
                    const originalBands = media.cavaValues
                    media.cavaValues = Array(24).fill(0)
                    compare(spectrum.itemAt(0).height, 3, "silence has no invented motion")
                    media.cavaValues = Array(24).fill(0.4)
                    verify(spectrum.itemAt(0).height > 17, "moderate audio has a visible radial excursion")
                    media.cavaValues = Array(24).fill(1)
                    compare(spectrum.itemAt(0).height, 31)
                    media.cavaValues = originalBands
                    mouseClick(toggle, toggle.width / 2, toggle.height / 2)
                    compare(toggles.count, 1)
                    toggle.forceActiveFocus()
                    keyClick(Qt.Key_Space)
                    compare(toggles.count, 2)
                    compare(toggle.contentItem.fontInfo.family, "Isla Media Symbols", "bundled rounded filled icons")
                    media.lyricsOpen = true
                    const view = findChild(media, "mediaLyricsView")
                    const list = findChild(media, "mediaLyricsList")
                    wait(150)
                    scene.position = 31
                    wait(80)
                    compare(list.currentIndex, 6)
                    wait(500)
                    const row = list.itemAtIndex(6)
                    verify(row !== null)
                    compare(row.travel, 0)
                    tryCompare(row, "emphasis", 1)
                    verify(findChild(row, "lyricGlowLabel").layer.enabled, "sung glyphs carry neon")
                    capture("04-lyrics-follow")
                    scene.position = 36
                    wait(60)
                    const next = list.itemAtIndex(7)
                    verify(next !== null && Math.abs(next.travel) > 0, "visible rows follow as a wave")
                    capture("05-lyrics-wave")
                    scene.position = 41
                    wait(70)
                    scene.position = 36
                    wait(650)
                    compare(list.itemAtIndex(7).travel, 0, "retarget settles without residual offset")
                    verify(!findChild(row, "lyricGlowLabel").layer.enabled, "previous lyric stops glowing")
                    const active = list.itemAtIndex(7)
                    mouseClick(active, active.width / 2, active.height / 2)
                    compare(seeks.count, 1)
                    compare(seeks.signalArguments[0][0], 35)
                    active.forceActiveFocus()
                    keyClick(Qt.Key_Return)
                    compare(seeks.count, 2, "keyboard seeks too")
                    scene.seeking = false
                    active.seek()
                    compare(seeks.count, 2, "capability guard rejects seek")
                    list.forceActiveFocus()
                    keyClick(Qt.Key_Down)
                    verify(!view.following)
                    scene.position = 51
                    wait(60)
                    compare(list.currentIndex, -1)
                    wait(3400)
                    verify(view.following, "manual browsing automatically returns to the song")
                    compare(list.currentIndex, 10)
                    view.following = false
                    media.lyricsOpen = false
                    media.lyricsOpen = true
                    verify(view.following, "reopening restores following")
                    view.following = true
                    wait(80)
                    Config.update({appearance:{reduceMotion:true}})
                    compare(list.itemAtIndex(10).travel, 0)
                    scene.position = 56
                    wait(50)
                    compare(list.itemAtIndex(11).travel, 0)
                    capture("06-reduced")
                    media.lyricsOpen = false
                    scene.playing = false
                    compare(cover.scale, 1)
                    Config.update({appearance:{reduceMotion:false,mediaTransitions:false}})
                    scene.playing = true
                    compare(toggle.morph, 1)
                    scene.playing = false
                    compare(toggle.morph, 0)
                    media.lyricsOpen = true
                    scene.position = 61
                    wait(50)
                    compare(list.itemAtIndex(12).travel, 0)
                    Config.update({appearance:{mediaTransitions:true}})
                    scene.position = 6
                    wait(30)
                    scene.position = 81
                    wait(60)
                    compare(list.itemAtIndex(16).travel, 0, "large seek snaps instead of flying through rows")
                    media.lyricsStatus = "loading"
                    compare(findChild(media, "mediaLyricsStatus").text, "Letras · LRCLIB")
                    capture("07-loading")
                    media.lyricsStatus = "error"
                    compare(findChild(media, "mediaLyricsStatus").text, "Letras · LRCLIB")
                    capture("08-error")
                    media.lyricsStatus = "loading"
                    scene.position = 0
                    media.lyricLines = [{time:5,text:"Una canción nueva"},{time:10,text:"Con una entrada tardía"}]
                    wait(60)
                    compare(list.contentY, list.originY, "new lyrics reset old scroll before first timestamp")
                    media.lyricsStatus = "ready"
                    scene.position = 6
                    wait(60)
                    compare(list.currentIndex, 0)
                    media.lyricsSynced = false
                    wait(30)
                    compare(list.currentIndex, -1)
                    const plain = list.itemAtIndex(0)
                    plain.seek()
                    compare(seeks.count, 2, "plain lyrics cannot seek")
                    media.lyricsOpen = false
                    scene.seeking = true
                    scene.minimumHeight = 580
                    scene.maximumHeight = 580
                    scene.height = 580
                    Config.update({appearance:{fontScale:1.75}})
                    wait(180)
                    const transport = findChild(media, "mediaTransport")
                    verify(transport.mapToItem(media, 0, 0).y + transport.height <= media.height + 1, "large text preserves controls")
                    capture("09-large-text")
                    Config.update({appearance:{fontScale:1}})
                    scene.minimumWidth = 640
                    scene.maximumWidth = 640
                    scene.width = 640
                    scene.minimumHeight = 360
                    scene.maximumHeight = 360
                    scene.height = 360
                    wait(180)
                    verify(transport.mapToItem(media, 0, 0).x + transport.width <= media.width + 1, "compact player keeps controls inside")
                    capture("10-small")
                    media.open = false
                    scene.position = 66
                    wait(50)
                    verify(!view.motionAllowed)
                    console.log("PASS: playback shape/cover retarget, lyrics wave/seek/keyboard/capabilities/manual/reduced/hidden")
                    finished = true
                } catch (error) { console.error("FAIL: Swiftify media", error); failure.start() }
            }
        }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
    }
    Timer { id: failure; interval: 50; onTriggered: Qt.exit(1) }
    Timer { interval: 15000; running: true; onTriggered: Qt.exit(1) }
}
