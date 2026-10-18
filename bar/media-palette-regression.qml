import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "components"
ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        width: 720; height: 440
        minimumWidth: 720; maximumWidth: 720
        minimumHeight: 440; maximumHeight: 440
        color: Qt.rgba(Theme.cardBot.r, Theme.cardBot.g, Theme.cardBot.b, 1)
        PillMaterial { surface: "media"; artUrl: scene.art; morphRadius: 26 }
        property string art: String(Qt.resolvedUrl("tests/fixtures/artwork-coral.svg"))
        MediaView {
            id: view
            open: true
            musicPresentation: true
            musicAccent: MediaPalette.accent
            artUrl: scene.art
            cavaAvailable: true; cavaHasFrame: true
            cavaValues: Array(24).fill(0.5)
            Component.onCompleted: playback = Object.assign({}, playback, {hasPlayer:true,isPlaying:true,title:"Colores de la música",artist:"Isla",canToggle:true,canPrevious:true,canNext:true,canShuffle:true,canRepeat:true,canSeek:true,length:100,progress:0.5,displayPosition:50})
        }
        IslandMediaCover { id: drop; x: 25; y: 390; diameter: 34; hasProgress: true; progress: 0.6; musicAccent: MediaPalette.accent }
        IslandMediaVisualizer { id: compact; x: 67; y: 388; hasMedia: true; isPlaying: true; hasFrame: true; values: Array(24).fill(0.6); musicAccent: MediaPalette.accent }
        TestCase {
            id: checks
            name: "MediaPalette"
            when: scene.visible
            property bool finished: false
            function shot(name) {
                const folder = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!folder) return
                let saved = false
                scene.contentItem.grabToImage(result => {saved = result.saveToFile(folder + "/" + name + ".png")})
                tryVerify(() => saved, 2500)
            }
            function test_colors() {
                try {
                    Config.update({appearance:{reduceMotion:false,mediaTransitions:true}})
                    MediaPalette.source = scene.art
                    tryVerify(() => MediaPalette.extracted !== null, 5000)
                    tryCompare(MediaPalette, "accent", MediaPalette.target)
                    const coral = String(MediaPalette.accent)
                    compare(String(view.musicAccent), coral)
                    compare(String(drop.musicAccent), coral)
                    compare(String(compact.musicAccent), coral)
                    const timeline = findChild(view, "mediaTimeline")
                    compare(String(timeline.musicAccent), coral)
                    const toggle = findChild(view, "mediaToggle")
                    compare(String(toggle.primaryColor), coral, "rotating button shares artwork color")
                    compare(String(toggle.primaryInk), "#000000")
                    verify(findChild(view, "mediaNeonField").visible, "neon is emitted inside the media surface")
                    shot("01-coral")
                    scene.art = String(Qt.resolvedUrl("tests/fixtures/artwork-blue.svg"))
                    MediaPalette.source = scene.art
                    tryVerify(() => String(MediaPalette.target) !== String(coral), 5000)
                    wait(60)
                    verify(String(MediaPalette.accent) !== String(coral) && String(MediaPalette.accent) !== String(MediaPalette.target))
                    compare(drop.musicAccent, timeline.musicAccent, "shared exact transition color")
                    shot("02-transition")
                    tryCompare(MediaPalette, "accent", MediaPalette.target)
                    verify(MediaPalette.accent.hslHue > 0.45 && MediaPalette.accent.hslHue < 0.7)
                    shot("03-blue")
                    MediaPalette.source = String(Qt.resolvedUrl("tests/fixtures/artwork-green.svg"))
                    MediaPalette.source = "file:///nonexistent/isla-palette.svg"
                    tryCompare(MediaPalette, "extracted", null, 5000)
                    tryCompare(MediaPalette, "accent", Theme.accent)
                    MediaPalette.source = ""
                    compare(MediaPalette.target, Theme.accent)
                    Config.update({appearance:{reduceMotion:true}})
                    MediaPalette.source = scene.art
                    tryVerify(() => MediaPalette.extracted !== null, 5000)
                    compare(MediaPalette.accent, MediaPalette.target, "reduced resolves color immediately")
                    MediaPalette.source = ""
                    compare(MediaPalette.accent, Theme.accent)
                    console.log("PASS: artwork extraction, shared accent/fade, latest source, missing art fallback, reduced")
                    finished = true
                } catch(error) { console.error("FAIL: media palette",error); Qt.exit(1) }
            }
        }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
    }
    Timer { interval: 20000; running: true; onTriggered: Qt.exit(1) }
}
