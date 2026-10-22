//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "settings"

ShellRoot {
    settings.watchFiles: false
    Window {
        visible: true
        width: 1100; height: 800
        color: Theme.background
        Item {
            id: stage
            width: 1000; height: 700
            EdotsWindow { id: editor; anchors.fill: parent }
        }
    }
    property bool sampling: false
    property real lastFrame: 0
    property var intervals: []
    FrameAnimation {
        running: sampling
        onTriggered: {
            const now = Date.now()
            if (lastFrame) intervals.push(now - lastFrame)
            lastFrame = now
        }
    }
    function find(item, predicate) {
        if (predicate(item)) return item
        for (const child of item.children || []) {
            const result = find(child, predicate)
            if (result) return result
        }
        return null
    }
    TestCase {
        name: "SettingsNavigation"
        when: Config.loaded
        function test_navigation() {
            try {
                Config.update({appearance: {reduceMotion: false, fontScale: 1}})
                wait(900)
                const page = find(editor, item => item.drafts !== undefined && item.entries !== undefined)
                verify(page !== null)
                page.setDraft("profile", "displayName", "Navigation draft")
                const observedCounts = []
                page.entriesChanged.connect(() => observedCounts.push(page.entries.length))
                for (let cycle = 0; cycle < 2; cycle++) {
                    intervals = []; lastFrame = 0; sampling = true
                    for (const destination of [1, 2, 3, 4, 5, 0]) {
                        const first = intervals.length
                        observedCounts.length = 0
                        editor.page = destination
                        wait(700)
                        console.log("METRIC: page=" + destination + " cycle=" + cycle
                            + " maxms=" + Math.max(...intervals.slice(first)))
                        if (destination === 1) compare(page.entries.length, 0, "composition has no hidden form rows")
                        verify(observedCounts.every(count => count <= page.entries.length), "no intermediate full-section model")
                        if (destination !== 3) compare(findChild(editor, "fontPicker"), null, "non-font rows have no font editor")
                    }
                    sampling = false
                    const sorted = intervals.slice().sort((a, b) => a - b)
                    console.log("METRIC: settings navigation " + (cycle ? "warm" : "cold")
                        + " frames=" + sorted.length + " p95ms=" + sorted[Math.floor(sorted.length * 0.95)]
                        + " maxms=" + sorted[sorted.length - 1])
                }
                editor.page = 1
                wait(700)
                stage.width = 760
                tryVerify(() => page.entries.some(entry => entry.key === "barLayout"))
                stage.width = 1000
                tryVerify(() => page.entries.length === 0)
                editor.searchQuery = "avatar"
                tryVerify(() => page.entries.length === 2, 1000)
                editor.searchQuery = ""
                tryVerify(() => page.entries.length === 0)
                editor.page = 2
                wait(40)
                editor.page = 1
                wait(40)
                editor.page = 4
                Config.update({appearance: {reduceMotion: true}})
                tryVerify(() => page.entries.length === 2 && page.entries.some(entry => entry.key === "displayName"))
                verify(page.hasDrafts, "navigation retains drafts")
                verify(page.commitDrafts(), "hidden draft can still be committed")
                compare(Config.profile.displayName, "Navigation draft")
                Config.discard()
                console.log("PASS: settings navigation cold/warm and retained drafts")
            } catch (error) {
                console.error("FAIL: settings navigation: " + error)
                Qt.exit(1)
            }
        }
    }
}
