import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "components"
import "Singletons"
import "settings" as Edots

ShellRoot {
    settings.watchFiles: false
    FileView { id: fixtures; path: Quickshell.env("ISLA_PALETTE_FIXTURES"); printErrors: false }
    Window {
        id: window
        visible: true
        width: 1040; height: 740
        Item {
            id: stage
            width: 1000; height: 700
            anchors.centerIn: parent
            Rectangle { anchors.fill: parent; color: Theme.background }
            MediaView {
                id: media
                anchors.fill: null
                x: 16; y: 16; width: 560; height: 660
                open: true; morphCloseness: 1; musicPresentation: true
                playback: ({hasPlayer:true, isPlaying:true, albumDistinct:true, title:"Isla · Material You", artist:"Paleta del wallpaper", album:"Roles semánticos", canSeek:true, canShuffle:true, canRepeat:true, canPrevious:true, canNext:true, canToggle:true, dragging:false, progress:0.4, displayPosition:48, remaining:72, length:120, repeatOne:false, shuffleEnabled:false, repeatEnabled:false, displayTime:"0:48", remainingTime:"1:12"})
            }
            Rectangle {
                x: 600; y: 24; width: 376; height: 652; radius: 20
                color: Theme.cardBot
                Column {
                    x: 24; y: 24; width: 328; spacing: 20
                    Text { text: IslaPalette.mode === "dark" ? "Matugen · oscuro" : "Matugen · claro"; color: Theme.foreground; font.family: Theme.font; font.pixelSize: 22 }
                    Text { text: "Texto secundario y controles"; color: Theme.iconSecondary; font.family: Theme.font; font.pixelSize: 14 }
                    IslaTextField { width: 328; height: 56; placeholderText: "Buscar…"; text: "Material You"; font.pixelSize: 14 }
                    Row {
                        spacing: 20
                        Toggle { checked: true }
                        Toggle { checked: false }
                        CtrlBtn { primary: true; iconName: "play_arrow" }
                    }
                    Rectangle {
                        width: 328; height: 64; radius: 12; color: Theme.accentContainer
                        Text { anchors.centerIn: parent; text: "Selección · primary container"; color: Theme.accentContainerContent; font.pixelSize: 14 }
                    }
                    Rectangle {
                        width: 328; height: 64; radius: 12; color: Theme.errorContainer
                        Text { anchors.centerIn: parent; text: "Error · revisión necesaria"; color: Theme.errorContainerContent; font.pixelSize: 14 }
                    }
                    Edots.SettingRow {
                        width: 328
                        fieldKey: "reduceMotion"
                        field: Object.assign({}, Config.schema.sections.appearance.reduceMotion, {description:""})
                        value: true
                        reducedMotion: true
                    }
                    LauncherView { id: launcher; width: 328; height: 120; open: true; query: "Sin resultados"; searchResults: []; searching: false }
                }
            }
        }
        TestCase {
            id: checks
            name: "MatugenPalette"
            when: fixtures.loaded && window.visible
            property bool finished: false
            function check(value, message) { if (!value) { console.error("FAIL: Matugen", message); Qt.exit(1); throw new Error(message) } }
            function luminance(c) {
                const lin = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
                return lin(c.r)*0.2126 + lin(c.g)*0.7152 + lin(c.b)*0.0722
            }
            function contrast(a,b) { return (Math.max(luminance(a),luminance(b))+.05)/(Math.min(luminance(a),luminance(b))+.05) }
            function test_material_roles() {
                Config.update({paths:{paletteFile:"/tmp/isla-no-live-palette.json"},appearance:{reduceMotion:true}})
                const cases = JSON.parse(fixtures.text())
                for (const sample of cases) {
                    check(IslaPalette._apply(JSON.stringify(sample)), "valid palette " + sample.name)
                    wait(100)
                    for (const pair of [[Theme.foreground, Theme.background], [Theme.iconSecondary, Theme.cardTop],
                        [Theme.primaryContent, Theme.accent], [Theme.accentContainerContent, Theme.accentContainer],
                        [Theme.errorContainerContent, Theme.errorContainer]]) check(contrast(pair[0],pair[1]) >= 4.5, "contrast " + sample.name)
                    let worst = 100
                    for (let step = 30; step <= 100; ++step) {
                        const intensity = step / 100
                        Config.update({appearance:{stateIntensity:intensity}})
                        wait(0)
                        const faces = [Qt.tint(Theme.cardBot, Theme.stateFill), Qt.tint(Theme.cardTop, Theme.stateFill),
                            Qt.tint(Theme.cardBot, Theme.stateFillLight), Qt.tint(Theme.cardTop, Theme.stateFillLight)]
                        const score = ink => Math.min(...faces.map(face => contrast(ink, face)))
                        const actual = score(Theme.stateContent)
                        const previous = score(intensity >= 0.6 ? Theme.primaryContent : Theme.foreground)
                        const optimal = Math.max(...[Theme.primaryContent, Theme.foreground, Qt.rgba(0,0,0,1), Qt.rgba(1,1,1,1)].map(score))
                        check(actual >= 4.5 || actual + 0.0001 >= optimal, "best available state ink " + sample.name + " " + intensity)
                        check(previous < 4.5 ? actual + 0.0001 >= previous : actual >= 4.5, "state contrast regression " + sample.name + " " + intensity)
                        worst = Math.min(worst, actual)
                    }
                    Config.update({appearance:{stateIntensity:1}})
                    console.log("STATE_CONTRAST", sample.name, "minimum", worst.toFixed(2))
                    const colors = IslaPalette.colors
                    check(!IslaPalette._apply('{"generator":"matugen"}'), "reject incomplete palette")
                    check(IslaPalette.colors === colors, "invalid palette keeps last valid colors")
                    const directory = Quickshell.env("ISLA_TEST_OUTPUT")
                    if (directory) {
                        let saved = false
                        stage.grabToImage(image => { saved = image.saveToFile(directory + "/" + sample.name + ".png") })
                        tryVerify(() => saved, 3000)
                    }
                }
                console.log("PASS: six real Matugen palettes, 426 state intensities, semantic contrast, last-valid retention and integrated media/controls")
                finished = true
            }
        }
        Timer { interval: 100; running: checks.finished; onTriggered: Qt.quit() }
    }
    Timer { interval: 18000; running: true; onTriggered: { console.error("FAIL: Matugen palette timeout"); Qt.exit(1) } }
}
