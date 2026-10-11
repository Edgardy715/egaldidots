import QtQuick
import Quickshell
import "Singletons"
import "settings"
import "components"
import "settings/ModuleSelection.js" as ModuleSelection

ShellRoot {
    OverlayInputPolicy { id: policy; surface: "settings" }
    Window {
        visible: true
        width: 1000; height: 380
        TopBarModules { id: modules; presented: policy.sideModulesPresented; width: 1000; height: 110; screenName: "composer-test" }
        ModuleComposer { id: composer; y: 140; width: parent.width; config: Config }
        SettingsPage { id: searchPage; y: 420; width: 600; height: 180; config: Config; query: "compacta" }
        EdotsWindow { id: smallWindow; visible: false; width: 760; height: 560; page: 1 }
    }
    function check(ok, message) { if (!ok) { console.error("FAIL: " + message); Qt.exit(1) } }
    function findButton(item, name) {
        if (item.objectName === "module-" + name) return item
        for (const child of item.children) {
            const found = findButton(child, name)
            if (found) return found
        }
        return null
    }
    function click(name) {
        const button = findButton(composer, name)
        check(button && button.enabled, name + " remains clickable")
        button.clicked()
        check(button.checked === ModuleSelection.selected(Config.modules, name) && button.accent === button.checked,
            name + " native/visual state matches Config")
    }
    function layoutButton(name) {
        function find(item) {
            if (item.objectName === "layout-" + name) return item
            for (const child of item.children) {
                const found = find(child)
                if (found) return found
            }
            return null
        }
        return find(composer)
    }
    function findNamed(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const found = findNamed(child, name)
            if (found) return found
        }
        return null
    }
    Timer {
        id: verifyRendered
        interval: 700
        onTriggered: {
            check(modules.workspaceModule.exposure === 1 && modules.workspaceModule.visible, "restored rail renders")
            check(modules.statusModule.exposure === 1 && modules.statusModule.visible, "restored status renders")
            check(modules.statusItem.showAudio && modules.statusItem.showNetwork, "restored children reach actual bar")
            console.log("PASS: composition restores parent, children and rendered bar")
            Qt.quit()
        }
    }
    Timer {
        interval: 30; running: true
        onTriggered: {
            if (!Config.loaded) { restart(); return }
            check(Config.appearance.barLayout === "split", "split layout defaults on")
            check(searchPage.entries.length === 1 && searchPage.entries[0].key === "barLayout", "compact layout discoverable by search")
            const searchedChoice = findNamed(searchPage, "choice-compact")
            check(searchedChoice && searchedChoice.text === "Compacta", "global search shows human-readable choice")
            searchedChoice.clicked()
            check(Config.appearance.barLayout === "compact" && searchedChoice.checked, "search choice updates Config")
            Config.discard()
            check(Config.appearance.barLayout === "split" && !searchedChoice.checked, "search choice follows discard")
            check(smallWindow.pageFields[1].includes("appearance.barLayout") && smallWindow.pageFields[1].includes("modules.apps"), "small composition exposes layout and modules")
            searchPage.query = ""
            searchPage.section = "modules"
            searchPage.fieldKeys = smallWindow.pageFields[1]
            check(searchPage.entries.some(entry => entry.key === "barLayout") && searchPage.entries.some(entry => entry.key === "apps"), "small composition fields render")
            const compact = layoutButton("compact")
            const split = layoutButton("split")
            check(compact && split && compact.enabled && split.checked && !compact.checked, "layout choices initialize")
            compact.clicked()
            check(Config.appearance.barLayout === "compact" && compact.checked && compact.accent && !split.checked, "compact selector updates Config")
            Config.discard()
            check(Config.appearance.barLayout === "split" && split.checked && !compact.checked, "discard restores selector")
            compact.clicked()
            split.clicked()
            check(Config.appearance.barLayout === "split", "split selector restores original layout")
            click("systemStatus")
            check(!Config.modules.systemStatus, "parent disabled")
            check(!findButton(composer, "apps").checked, "hidden children are not shown as active")
            click("apps")
            check(Config.modules.apps && Config.modules.systemStatus && Config.modules.audio && Config.modules.network,
                "selecting hidden child restores parent and preserves siblings")
            click("apps")
            check(!Config.modules.apps, "visible child can be removed")
            click("apps")
            check(Config.modules.apps, "child restored")
            click("workspaceRail")
            check(!Config.modules.workspaceRail, "rail disabled")
            click("workspaceRail")
            check(Config.modules.workspaceRail, "rail restored")
            verifyRendered.start()
        }
    }
}
