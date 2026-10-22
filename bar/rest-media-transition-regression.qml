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
        width: 640; height: 200
        color: "#242424"
        property string title: "Primera canción"
        property string artist: "Artista inicial"
        property string art: String(Qt.resolvedUrl("tests/fixtures/artwork-coral.svg"))
        IslandMediaSummary {
            id: summary
            x: 30; y: 35
            coverDiameter: 36; textWidth: 220
            title: scene.title; artist: scene.artist; artUrl: scene.art
            trackTransitions: true
            hasProgress: true; progress: 0.42
        }
        IslandMediaCover {
            id: normalCover
            x: 30; y: 110
            diameter: 34
            artUrl: scene.art
            trackTransitions: true
            trackKey: JSON.stringify([scene.title, scene.artist])
            hasProgress: true; progress: 0.42
        }
        IslandMediaMetadata {
            id: metadata
            x: 80; y: 108
            title: scene.title; artist: scene.artist
        }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "RestMediaTransition"
            when: scene.visible
            property bool finished: false
            function must(ok, message) {
                if (!ok) { console.error("FAIL:", message); Qt.exit(1); throw new Error(message) }
            }
            property int waitStep: 0
            function until(predicate, timeout) {
                waitStep++
                const deadline = Date.now() + (timeout || 2500)
                while (!predicate() && Date.now() < deadline) wait(16)
                must(predicate(), "timed out at state " + waitStep + ": " + coversState())
            }
            function coversState() {
                const cover = summary.children.find(item => item.trackCompression !== undefined)
                return JSON.stringify([normalCover.trackCompression, cover.trackCompression,
                    descendants(normalCover, item => item.displayedSource !== undefined).map(item => [item.displayedSource, item.source])])
            }
            function descendants(item, predicate) {
                let result = []
                if (predicate(item)) result.push(item)
                for (const child of item.children || []) result = result.concat(descendants(child, predicate))
                return result
            }
            function capture(name) {
                const dir = Quickshell.env("ISLA_TEST_OUTPUT")
                if (dir) grabImage(scene.contentItem).save(dir + "/" + name + ".png")
            }
            function test_track_changes() {
                until(() => Config.loaded)
                Config.update({appearance: {reduceMotion: false, mediaTransitions: true}})
                const covers = [normalCover, summary.children.find(item => item.trackCompression !== undefined)]
                const images = covers.map(cover => descendants(cover, item => item.displayedSource !== undefined)[0])
                until(() => images.every(image => image.ready))
                const coral = scene.art
                const blue = String(Qt.resolvedUrl("tests/fixtures/artwork-blue.svg"))
                const green = String(Qt.resolvedUrl("tests/fixtures/artwork-green.svg"))
                const labels = descendants(summary, item => item.reveal !== undefined)
                const geometry = covers.map(cover => [cover.x, cover.y, cover.width, cover.height])
                wait(300)
                capture("01-before")
                scene.title = "Segunda canción"
                scene.artist = "Otro artista"
                scene.art = blue
                wait(40)
                must(covers.every(cover => cover.trackCompression > 0 && cover.trackCompression < 1), "both rest covers react without snapping")
                must(labels.some(label => label.reveal > 0 && label.reveal < 1), "compact metadata crossfades")
                capture("02-changing")
                scene.title = "Última canción"
                scene.art = green
                wait(55)
                capture("03-retarget")
                until(() => images.every(image => image.displayedSource === green), 2500)
                until(() => covers.every(cover => cover.trackCompression === 0), 2500)
                until(() => labels.every(label => label.reveal === 1), 2500)
                must(covers.every((cover, i) => JSON.stringify([cover.x, cover.y, cover.width, cover.height]) === JSON.stringify(geometry[i])), "track motion preserves hit geometry")
                capture("04-settled")
                scene.title = "Otra canción del mismo álbum"
                wait(40)
                must(covers.every(cover => cover.trackCompression > 0), "same artwork still signals a new song")
                Config.update({appearance: {reduceMotion: true}})
                must(covers.every(cover => cover.trackCompression === 0), "reduced motion settles an in-flight change")
                scene.title = "Cambio reducido"
                scene.art = coral
                until(() => images.every(image => image.displayedSource === coral))
                must(covers.every(cover => cover.trackCompression === 0), "reduced motion never compresses covers")
                Config.update({appearance: {reduceMotion: false, mediaTransitions: false}})
                scene.title = "Transiciones desactivadas"
                must(covers.every(cover => cover.trackCompression === 0), "disabled transitions stay still")
                Config.update({appearance: {mediaTransitions: true}})
                summary.visible = false; normalCover.visible = false; metadata.visible = false
                scene.title = "Actualización oculta"
                scene.art = blue
                wait(350)
                must(covers.every(cover => cover.trackCompression === 0), "hidden rest stops track motion")
                summary.visible = true; normalCover.visible = true; metadata.visible = true
                must(covers.every(cover => cover.trackCompression === 0), "reopening does not replay an old change")
                normalCover.trackTransitions = false
                scene.title = "Panel abierto"
                must(normalCover.trackCompression === 0, "expanded companion disables rest choreography")
                wait(450)
                console.log("PASS: compact/split rest track change, latest artwork, same album, stable geometry, hidden/reopen, reduced and disabled motion")
                finished = true
            }
        }
    }
}
