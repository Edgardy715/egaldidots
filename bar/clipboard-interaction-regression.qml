import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        visible: true
        width: 620
        height: 540
        minimumWidth: 620; minimumHeight: 540
        maximumWidth: 620; maximumHeight: 540
        color: Theme.background
        Rectangle { anchors.fill: parent; color: Theme.background }
        ClipboardView {
            id: view
            anchors.fill: parent
            anchors.margins: 20
            open: true
            loading: false
            entries: [
                {id: "1", text: "Una nota para mañana", preview: "Una nota para mañana", isImage: false},
                {id: "2", text: "", preview: "[[ binary data png 640x320 ]]", isImage: true},
                {id: "3", text: "https://quickshell.org", preview: "https://quickshell.org", isImage: false},
                {id: "4", text: "Texto con <etiquetas>", preview: "Texto con <etiquetas>", isImage: false},
                {id: "5", text: "Última nota", preview: "Última nota", isImage: false}
            ]
            filteredEntries: entries
            collections: [{id: "work", name: "Trabajo"}, {id: "ideas", name: "Ideas"}]
            previewSources: ({"2|full": Quickshell.env("ISLA_CLIPBOARD_IMAGE") || "", "2|thumb": Quickshell.env("ISLA_CLIPBOARD_IMAGE") || ""})
            onPreviewRequested: (id, full) => { if (full) checks.fullRequests++ }
            onCopyRequested: entry => checks.copied = entry.id
            onSectionRequested: id => section = id
            onCreateCollectionRequested: name => {
                checks.created = name
                collections = collections.concat([{id: "created", name: name}])
            }
        }
        Timer { interval: 50; running: checks.done; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "ClipboardInteraction"
            when: window.visible
            property bool done: false
            property int fullRequests: 0
            property string copied: ""
            property string created: ""
            function check(value, label) {
                if (!value) { console.error("FAIL: clipboard interaction", label); Qt.exit(1); throw Error(label) }
            }
            function find(item, name) {
                if (item.objectName === name) return item
                for (const child of item.children) { const found = find(child, name); if (found) return found }
                return null
            }
            function shot(name) {
                const directory = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!directory) return
                var saved = false
                window.contentItem.grabToImage(result => { saved = result.saveToFile(directory + "/" + name + ".png") })
                tryVerify(() => saved)
            }
            function test_navigation() {
                wait(700)
                const list = find(view, "clipboardList")
                const search = find(view, "clipboardSearch")
                check(list && search, "controls loaded")
                search.forceActiveFocus()
                const y = list.y
                const height = list.height
                mouseMove(list, 50, 30)
                wait(100)
                keyClick(Qt.Key_Down)
                wait(250)
                check(view.selectedIndex === 1, "image selected by arrow")
                check(list.y === y && list.height === height, "preview keeps list geometry")
                check(search.activeFocus, "arrow keeps search focus")
                shot("image")
                check(fullRequests === 0, "closed preview never decodes full images on selection")
                view.showingDetails = true
                wait(180)
                check(fullRequests > 0, "explicit preview requests full image")
                shot("preview")
                keyClick(Qt.Key_Escape)
                check(!view.showingDetails, "Escape closes requested preview before surface")
                search.forceActiveFocus()
                keyClick(Qt.Key_Down)
                wait(300)
                check(view.selectedIndex === 2, "stationary pointer does not override keyboard")
                check(list.y === y && list.height === height, "text keeps list geometry")
                for (var i = 0; i < 12; ++i) { keyClick(Qt.Key_Down); wait(20) }
                wait(300)
                check(view.selectedIndex === 4, "rapid navigation stays deterministic through scroll " + view.selectedIndex)
                mouseMove(list, 50, 35)
                mouseMove(list, 52, 36)
                wait(100)
                check(view.selectedIndex !== 4, "intentional pointer motion resumes selection")
                const hovered = view.selectedIndex
                mouseClick(list, 52, 36)
                check(copied === view.entries[hovered].id, "click copies hovered entry")
                const stableId = view.selectedEntry.id
                view.entries = view.entries.map(e => Object.assign({}, e, {saved: true}))
                wait(50)
                check(view.selectedEntry.id === stableId, "metadata refresh preserves selection " + stableId + " -> " + view.selectedEntry.id + " selectionId=" + view.selectionId)
                check(list.currentIndex === -1, "native currentIndex must never drive mouse scrolling")
                view.errorMessage = "No se pudo guardar. Inténtalo de nuevo."
                wait(100)
                check(list.y === y && list.height === height, "error has reserved footer space")
                shot("error")
                view.errorMessage = ""
                view.editCollection("")
                wait(200)
                for (const key of [Qt.Key_R, Qt.Key_E, Qt.Key_C, Qt.Key_U, Qt.Key_R, Qt.Key_S, Qt.Key_O, Qt.Key_S]) keyClick(key)
                keyClick(Qt.Key_Return)
                check(created.toLowerCase() === "recursos", "collection created by keyboard")
                check(search.activeFocus, "editor restores search focus")
                view.editCollection("")
                view.errorMessage = "No se pudo crear la colección."
                wait(50)
                check(view.editingCollection, "failed collection keeps editor open")
                view.errorMessage = ""
                keyClick(Qt.Key_Escape)
                check(!view.editingCollection, "Escape dismisses editor")
                Config.update({appearance: {reduceMotion: true}})
                search.forceActiveFocus()
                keyClick(Qt.Key_Down)
                wait(100)
                check(list.y === y && list.height === height, "reduced geometry stable")
                shot("text-reduced")
                view.section = "saved"
                view.entries = [{id: "saved1", text: "Idea guardada para después", preview: "Idea guardada para después", isImage: false, saved: true, collectionId: "ideas"}]
                wait(150)
                shot("saved")
                const original = view.entries
                view.section = "history"
                view.entries = Array.from({length: 40}, (_, i) => ({id: String(i + 10), text: "Entrada " + (i + 1), preview: "Entrada " + (i + 1), isImage: i % 3 === 0}))
                wait(120)
                list.contentY = 0
                const origin = list.contentY
                for (var j = 0; j < 14; ++j) {
                    mouseMove(list, 60 + j % 2, list.height - 2 - j % 2)
                    wait(20)
                }
                check(Math.abs(list.contentY - origin) < 0.01, "hovering partial bottom row never scrolls " + list.contentY)
                mouseWheel(list, 70, 100, 0, -120)
                wait(250)
                check(list.contentY > origin, "wheel still scrolls through passive mouse observer")
                list.contentY = 170
                wait(80)
                const scrolled = list.contentY
                for (var k = 0; k < 14; ++k) {
                    mouseMove(list, 62 + k % 2, list.height - 3 - k % 2)
                    wait(20)
                }
                check(Math.abs(list.contentY - scrolled) < 0.01, "hover after scroll cannot cascade down " + list.contentY)
                mouseMove(list, 66, 20)
                wait(60)
                check(list.contentY === scrolled, "top edge hover cannot scroll either")
                shot("long-list")
                view.entries = original
                list.contentY = 0
                view.section = "saved"
                view.editCollection("ideas")
                wait(150)
                shot("collection-editor")
                console.log("PASS: clipboard fixed geometry, pointer/keyboard, scroll, collection editor, reduced motion")
                done = true
            }
        }
        Timer { interval: 12000; running: true; onTriggered: { console.error("FAIL: clipboard interaction timeout"); Qt.exit(1) } }
    }
}
