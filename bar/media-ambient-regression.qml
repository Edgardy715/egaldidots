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
        width: 820; height: 520
        color: Theme.background
        property string art: String(Qt.resolvedUrl("tests/fixtures/artwork-coral.svg"))

        ArtworkImage {
            id: sharedArtwork
            visible: false
            width: 416; height: 416
            source: scene.art
            sourceSize: Qt.size(416, 416)
            preloadAmbient: true
            transitionsEnabled: Flags.mediaTransitions
            motionVisible: panel.visible
        }
        Item {
            id: panel
            x: 28; y: 28; width: 764; height: 460
            PillMaterial {
                id: material
                surface: "media"
                artUrl: scene.art
                artworkTransition: sharedArtwork
                mediaPlaying: true
                mediaSettled: true
                morphRadius: 26
            }
            MediaView {
                id: view
                anchors.fill: parent
                open: true
                musicPresentation: true
                artUrl: scene.art
                artworkTransition: sharedArtwork
                playback: ({hasPlayer: true, isPlaying: material.mediaPlaying,
                    title: "Ambiente de prueba", artist: "Isla", album: "Estudio", albumDistinct: true,
                    canSeek: false, canShuffle: false, canRepeat: false, canPrevious: false,
                    canNext: false, canToggle: false, dragging: false, displayPosition: 85,
                    length: 215, shuffleEnabled: false, repeatEnabled: false,
                    repeatOne: false, progress: 0.45, displayTime: "1:25", remainingTime: "−2:10"})
            }
        }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "MediaAmbient"
            when: scene.visible
            property bool finished: false
            function capture(name) {
                const folder = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!folder) return
                let saved = false
                scene.contentItem.grabToImage(result => { saved = result.saveToFile(folder + "/" + name + ".png") })
                tryVerify(() => saved, 2500)
            }
            function test_ambient_lifecycle() {
                try {
                    Config.update({appearance: {reduceMotion: false, mediaTransitions: true}})
                    const ambient = findChild(material, "mediaAmbient")
                    const image = findChild(material, "mediaAmbientImage")
                    const clock = findChild(material, "mediaAmbientClock")
                    verify(ambient && image && clock)
                    compare(ambient.textureSize.width, 192)
                    compare(ambient.textureSize.height, 128)
                    compare(image.sourceSize.width, 256)
                    compare(image.sourceSize.height, 256)
                    tryVerify(() => image.ready)
                    tryVerify(() => clock.running)
                    const start = ambient.phase
                    wait(180)
                    verify(ambient.phase > start, "active playback advances drift")
                    capture("01-playing")

                    scene.art = String(Qt.resolvedUrl("tests/fixtures/artwork-blue.svg"))
                    tryVerify(() => sharedArtwork.transitioning)
                    wait(40)
                    compare(image.effectiveBlend, sharedArtwork.blend, "one shared crossfade clock")
                    tryCompare(image, "displayedSource", scene.art)
                    capture("02-blue")

                    material.mediaPlaying = false
                    const pausePhase = ambient.phase
                    wait(570)
                    verify(ambient.phase >= pausePhase, "pause eases forward")
                    verify(!clock.running, "pause stops frame timer")
                    const stopped = ambient.phase
                    wait(110)
                    compare(ambient.phase, stopped, "pause preserves phase")
                    capture("03-paused")

                    material.mediaPlaying = true
                    tryVerify(() => clock.running)
                    wait(120)
                    verify(ambient.phase > stopped, "resume continues phase")
                    material.mediaSettled = false
                    wait(570)
                    verify(!clock.running, "morphing panel stops drift")
                    material.mediaSettled = true
                    tryVerify(() => clock.running)

                    panel.visible = false
                    verify(!clock.running, "hidden panel has no frame timer")
                    const hiddenPhase = ambient.phase
                    wait(110)
                    compare(ambient.phase, hiddenPhase)
                    panel.visible = true
                    tryVerify(() => clock.running)

                    Config.update({appearance: {reduceMotion: true}})
                    tryVerify(() => !clock.running, 1000, "reduced motion stops drift")
                    capture("04-reduced")
                    Config.update({appearance: {reduceMotion: false, mediaTransitions: false}})
                    tryVerify(() => !clock.running, 1000, "disabled transitions stop drift")
                    console.log("PASS: low-res decode/blur, active, pause, hidden, settled, reduced and shared artwork clock")
                } catch (error) {
                    console.error("FAIL: " + error + " " + error.stack)
                    throw error
                } finally {
                    Config.discard()
                    finished = true
                }
            }
        }
    }
}
