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
        property string title: "Isla · música en continuidad"
        ArtworkImage {
            id: sharedArtwork
            visible: false
            source: scene.art
            sourceSize: Qt.size(416, 416)
            preloadAmbient: true
            transitionsEnabled: Flags.mediaTransitions
            motionVisible: panel.visible
        }
        Item {
            id: panel
            x: 22; y: 24; width: 776; height: 460
            PillMaterial { id: material; surface: "media"; artUrl: scene.art; morphRadius: 26; artworkTransition: sharedArtwork }
            MediaView {
                id: view
                anchors.fill: parent
                open: true
                musicPresentation: true
                artUrl: scene.art
                artworkTransition: sharedArtwork
                playback: ({hasPlayer: true, isPlaying: true, title: scene.title, artist: "Artista de prueba", album: "Estudio", albumDistinct: true,
                    canSeek: false, canShuffle: false, canRepeat: false, canPrevious: false, canNext: false, canToggle: false,
                    dragging: false, displayPosition: 85, length: 215, shuffleEnabled: false, repeatEnabled: false, repeatOne: false, progress: 0.45, displayTime: "1:25", remainingTime: "−2:10"})
            }
        }
        ArtworkImage {
            id: image
            width: 64; height: 64; x: 700; y: 30; radius: 12
            source: scene.art
            transitionsEnabled: Flags.mediaTransitions
        }
        CrossfadeLabel {
            id: label
            width: 360; height: 30; x: 30; y: 485
            value: scene.title
            animated: Flags.mediaTransitions
            color: Theme.foreground
            font.pixelSize: 18
        }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "MediaPresentation"
            when: scene.visible
            property bool finished: false
            function capture(name) {
                const folder = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!folder) return
                let saved = false
                scene.contentItem.grabToImage(result => { saved = result.saveToFile(folder + "/" + name + ".png") })
                tryVerify(() => saved, 2500)
            }
            function test_retarget_and_loading() {
                try {
                Config.update({appearance: {reduceMotion: false, mediaTransitions: true}})
                tryVerify(() => image.ready)
                const coral = scene.art
                const blue = String(Qt.resolvedUrl("tests/fixtures/artwork-blue.svg"))
                const green = String(Qt.resolvedUrl("tests/fixtures/artwork-green.svg"))
                capture("01-coral")
                scene.art = blue
                compare(image.displayedSource, coral, "keep old decoded image during replacement")
                tryVerify(() => image.transitioning)
                wait(55)
                verify(image.blend > 0 && image.blend < 1)
                verify(image.ready, "outgoing art remains available throughout fade")
                capture("02-midfade")
                scene.art = green
                scene.title = "Segundo título"
                wait(45)
                verify(label.reveal > 0 && label.reveal < 1)
                scene.title = "Último título sin deformación"
                tryCompare(image, "displayedSource", green)
                tryCompare(label, "displayed", scene.title)
                tryCompare(label, "reveal", 1)
                const ambient = findChild(material, "mediaAmbientImage")
                const cover = findChild(view, "mediaArtworkImage")
                tryCompare(ambient, "displayedSource", green)
                tryCompare(cover, "displayedSource", green)
                compare(ambient.sourceSize.width, 256, "ambient decode stays fixed")
                scene.art = coral
                tryVerify(() => sharedArtwork.transitioning)
                wait(25)
                compare(ambient.effectiveBlend, cover.effectiveBlend, "ambient and artwork share exact progress")
                compare(cover.effectiveBlend, sharedArtwork.blend)
                tryCompare(sharedArtwork, "displayedSource", coral)
                const title = findChild(view, "mediaTitle")
                const transport = findChild(view, "mediaTransport")
                const transportY = transport.mapToItem(view, 0, 0).y
                scene.title = "Un título suficientemente largo para ocupar dos líneas sin desplazar los metadatos ni los controles del reproductor"
                wait(40)
                compare(transport.mapToItem(view, 0, 0).y, transportY, "metadata changes do not move transport")
                tryCompare(title, "reveal", 1)
                const textItem = findChild(title, "crossfadeText")
                compare(textItem.lineCount, 2, "long title still wraps")
                capture("03a-two-line-title")
                scene.title = "Breve"
                wait(40)
                compare(transport.mapToItem(view, 0, 0).y, transportY)
                scene.art = green
                tryCompare(sharedArtwork, "displayedSource", green)
                tryCompare(title, "reveal", 1)
                capture("03-green")
                scene.art = coral
                tryVerify(() => image.transitioning)
                Config.update({appearance: {reduceMotion: true}})
                verify(!image.transitioning)
                tryCompare(image, "displayedSource", coral)
                scene.title = "Movimiento reducido"
                compare(label.displayed, scene.title)
                compare(label.reveal, 1)
                Config.update({appearance: {reduceMotion: false, mediaTransitions: false}})
                scene.art = blue
                tryCompare(image, "displayedSource", blue)
                verify(!image.transitioning)
                scene.title = "Cambios directos"
                compare(label.displayed, scene.title)
                const slowSource = Quickshell.env("ISLA_SLOW_ARTWORK")
                if (slowSource) {
                    scene.art = slowSource
                    tryVerify(() => image.loading)
                    wait(100)
                    compare(image.displayedSource, blue, "old art survives actual delayed network load")
                    scene.art = green
                    tryCompare(image, "displayedSource", green)
                    wait(500)
                    compare(image.displayedSource, green, "cancelled response cannot replace newest track")
                    scene.art = slowSource + "?fresh"
                    tryVerify(() => image.loading)
                    compare(image.displayedSource, green)
                    tryCompare(image, "displayedSource", slowSource + "?fresh")
                }
                scene.art = ""
                compare(image.ready, false)
                compare(ambient.ready, false)
                scene.art = "file:///nonexistent/isla-artwork-test.svg"
                wait(100)
                verify(!image.ready, "failed art clears old track")
                scene.art = green
                tryVerify(() => image.ready)
                Config.update({appearance: {mediaTransitions: true}})
                scene.art = coral
                tryVerify(() => image.transitioning)
                panel.visible = false
                image.visible = false
                label.visible = false
                verify(!image.transitioning)
                compare(label.reveal, 1)
                tryCompare(ambient, "displayedSource", coral)
                panel.visible = true
                image.visible = true
                label.visible = true
                capture("04-reopened")
                Config.update({appearance: {materialDepth: 0}})
                capture("05-material-flat")
                Config.update({appearance: {materialDepth: 1}})
                capture("06-material-depth")
                Config.update({appearance: {materialDepth: 0.25}})
                console.log("PASS: retained art, interrupted/latest URL, shared ambient, metadata, error, hidden, disabled and reduced motion")
                finished = true
                } catch (error) { console.error("FAIL: media presentation", error, error.stack); Qt.exit(1) }
            }
        }
    }
    Timer { interval: 15000; running: true; onTriggered: { console.error("FAIL: media presentation timeout"); Qt.exit(1) } }
}
