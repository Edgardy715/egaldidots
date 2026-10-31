import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "Singletons"
import "components"
import "settings" as Edots

ShellRoot {
    settings.watchFiles: false
    FileView { id: palettes; path: Quickshell.env("ISLA_PALETTE_FIXTURES"); printErrors: false }
    Window {
        id: window
        title: "Isla · accesibilidad del material"
        visible: true
        width: 900; height: 600
        color: Theme.background
        Item {
            anchors.centerIn: parent
            width: 840; height: 520
            Column {
                width: parent.width; spacing: 20
                Text { text: "Reducir transparencia · " + IslaPalette.mode; color: Theme.foreground; font.family: Theme.font; font.pixelSize: Theme.fontSizeTitle }
                Item {
                    width: parent.width; height: 240
                    Row {
                        anchors.fill: parent
                        Repeater { model: 12; Rectangle { required property int index; width: 70; height: 240; color: index % 2 ? "#ffffff" : "#000000" } }
                    }
                    Item {
                        x: 20; y: 20; width: 390; height: 200
                        PillMaterial { id: pill; morphRadius: 24; surface: "calendar" }
                        Column {
                            x: 24; y: 30; width: parent.width - 48; spacing: 12
                            Text { text: "Isla"; color: Theme.foreground; font.family: Theme.font; font.pixelSize: Theme.fontSizeHead }
                            Text { width: parent.width; text: "Lectura sobre un fondo de alto contraste"; wrapMode: Text.WordWrap; color: Theme.iconSecondary; font.family: Theme.font; font.pixelSize: Theme.fontSizeBody }
                            Toggle { checked: true }
                        }
                    }
                    GlassCard {
                        id: card
                        x: 430; y: 20; width: 390; height: 200
                        Column {
                            x: 24; y: 30; width: parent.width - 48; spacing: 12
                            Text { text: "Tarjetas"; color: Theme.foreground; font.family: Theme.font; font.pixelSize: Theme.fontSizeHead }
                            Text { width: parent.width; text: "La opacidad elegida se conserva"; wrapMode: Text.WordWrap; color: Theme.iconSecondary; font.family: Theme.font; font.pixelSize: Theme.fontSizeBody }
                        }
                    }
                }
                Edots.SettingRow {
                    id: row
                    width: parent.width
                    fieldKey: "reduceTransparency"
                    field: Config.schema.sections.appearance.reduceTransparency
                    value: Flags.reduceTransparency
                    reducedMotion: true
                    onChangeRequested: value => Config.update({appearance: {reduceTransparency: value}})
                }
            }
        }
        TestCase {
            name: "MaterialAccessibility"
            when: Config.loaded && (!palettes.path || palettes.loaded)
            function check(ok, message) { if (!ok) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message) } }
            function test_material() {
                Config.update({paths: {paletteFile: "/tmp/isla-material-no-live-palette.json"}})
                if (palettes.loaded) {
                    const cases = JSON.parse(palettes.text())
                    check(IslaPalette._apply(JSON.stringify(cases[Number(Quickshell.env("ISLA_PALETTE_INDEX") || 0)])), "palette")
                }
                for (const layout of ["split", "compact"]) {
                    check(Config.update({appearance: {barLayout: layout, glassAlpha: 0.2, reduceTransparency: false}}).ok, "update")
                    compare(Flags.glassAlpha, 0.2)
                    check(pill.bodyAlpha < 1, "glass enabled")
                    Config.update({appearance: {reduceTransparency: true}})
                    compare(Flags.glassAlpha, 1)
                    compare(pill.bodyAlpha, 1)
                    compare(Config.appearance.glassAlpha, 0.2)
                    Config.update({appearance: {reduceTransparency: false}})
                    compare(Flags.glassAlpha, 0.2)
                }
                Config.discard()
                compare(Flags.glassAlpha, Config.appearance.glassAlpha)
                Config.update({paths: {paletteFile: "/tmp/isla-material-no-live-palette.json"}, appearance: {reduceTransparency: true, fontScale: 1.75, stateIntensity: 0.6}})
                if (palettes.loaded) {
                    const cases = JSON.parse(palettes.text())
                    check(IslaPalette._apply(JSON.stringify(cases[Number(Quickshell.env("ISLA_PALETTE_INDEX") || 0)])), "capture palette")
                }
                wait(100)
                check(row.editable && row.focusEditor(), "accessible editor")
                check(row.implicitHeight > 44, "large text row")
                console.log("PASS: material opacity, live restore, discard, both layouts and enlarged editor")
                wait(Number(Quickshell.env("ISLA_CAPTURE_HOLD_MS") || 100))
                Qt.quit()
            }
        }
    }
    Timer { interval: 15000; running: true; onTriggered: { console.error("FAIL: material timeout"); Qt.exit(1) } }
}
