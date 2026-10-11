//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
import QtQuick
import Quickshell
import "Singletons"
import "settings"
ShellRoot {
    EdotsButton { id: actionButton }
    SettingsPage { id: page; config: Config; width: 700; height: 500 }
    IslandStudio { id: studio; width: 700; height: 270 }
    SettingRow {
        id: fontRow; width: 500
        fieldKey: "fontFamily"; field: Config.schema.sections.appearance.fontFamily
        value: "Google Sans Flex"
    }
    Item {
    Repeater {
        id: symbols
        model: ["palette", "dashboard", "animation", "text_fields", "person", "settings", "lock", "volume_up", "wifi", "skip_previous", "calendar_month", "play_arrow", "notifications", "skip_next", "expand_more", "tune", "apps", "battery_full", "visibility", "check", "close"]
        EdotsIcon { required property string modelData; iconName: modelData; font.pixelSize: 20 }
    }
    }
    function stroke(icon) {
        return icon.children.find(child => child.objectName === "animatedSymbol")
    }
    function fontControl(item) {
        if (item.objectName === "fontPicker") return item
        for (const child of item.children || []) {
            const result = fontControl(child)
            if (result) return result
        }
        return null
    }
    property int phase: 0
    function check(ok, message) { if (!ok) throw new Error(message) }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (!Config.loaded) return
            if (phase === 0) {
                check(actionButton.contrastInk(Qt.rgba(0.682, 0.357, 0.31, 1)) === "#ffffff", "dark accent text contrast")
                check(actionButton.contrastInk(Qt.rgba(0.8, 0.9, 0.7, 1)) === "#000000", "light accent text contrast")
                for (let i = 0; i < symbols.count; i++) {
                    const icon = symbols.itemAt(i)
                    check(icon.vectorIcon, "animated geometry: " + icon.iconName)
                    check(stroke(icon).animating, "arrival gesture: " + icon.iconName)
                }
                check(fontControl(fontRow).editText === "Google Sans Flex", "font initial selection")
                fontRow.value = "Edots custom unavailable font"
                page.query = "avatar"
                check(page.entries.length === 2 && page.entries.some(entry => entry.section === "paths")
                      && page.entries.some(entry => entry.section === "modules"), "global search")
                page.updateField("appearance", "fontScale", 1.2)
                check(Config.appearance.fontScale === 1.2 && Config.dirty, "live update")
                page.updateField("appearance", "fontScale", 0)
                check(page.validationError.length > 0 && Config.appearance.fontScale === 1.2, "invalid retention")
                Config.discard(); page.clearValidation()
                check(!Config.dirty && !page.validationError, "discard")
                page.setDraft("profile", "displayName", "Edots test")
                page.section = "modules"; page.query = ""
                check(page.hasDrafts && page.commitDrafts(), "hidden draft commit")
                check(Config.profile.displayName === "Edots test", "draft applied")
                page.setDraft("appearance", "topGap", "")
                check(!page.commitDrafts() && page.hasDrafts && page.validationError, "empty numeric draft retained")
                Config.discard(); page.clearValidation()
                check(!page.hasDrafts && !page.validationError, "draft discard")
                page.query = "tamano texto"
                check(page.entries.length === 1 && page.entries[0].key === "fontScale", "accent insensitive AND search")
                page.query = ""; page.fieldKeys = ["appearance.motionScale", "modules.animateChanges"]
                check(page.entries.length === 2, "cross-section curated group")
                page.fieldKeys = ["appearance.pillBlur"]
                check(page.entries.length === 0, "inactive hidden")
                page.showUnavailable = true
                check(page.entries.length === 1, "inactive discoverable")
                page.updateField("appearance", "fontScale", 1.3)
                page.setDraft("profile", "displayName", "Keep me")
                page.resetField("appearance", "fontScale")
                check(Config.appearance.fontScale === Config.schema.sections.appearance.fontScale.default && page.hasDrafts, "scoped reset preserves other drafts")
                Config.discard(); page.clearValidation()
                studio.scene = 1
            } else if (phase === 1) {
                check(fontControl(fontRow).editText === "Edots custom unavailable font", "custom font retained")
                fontRow.value = "Inter"
                symbols.itemAt(0).visible = false
                check(!stroke(symbols.itemAt(0)).animating, "hidden icon stops")
                studio.scene = 2
                Config.update({appearance: {reduceMotion: true}})
            } else {
                for (let i = 0; i < symbols.count; i++) check(!stroke(symbols.itemAt(i)).animating && stroke(symbols.itemAt(i)).progress === 1, "reduced motion settles all icons")
                check(fontControl(fontRow).editText === "Inter", "font external update and discard")
                Config.update({appearance: {motionScale: 0.7}})
                check(Config.appearance.reduceMotion, "speed preserves reduced motion")
                check(studio.scene === 2, "retarget")
                Config.discard()
                console.log("PASS: Edots global search, update, validation, discard and interrupted scene load")
                Qt.quit()
            }
            phase++
        }
    }
}
