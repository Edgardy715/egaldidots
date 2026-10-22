import QtQuick
import Quickshell
import QtTest
import "components"

ShellRoot {
    Window {
        id: scene
        visible: true
        width: 320
        height: 120
        property int step: 0
        property int copied: 0
        property string collectionId: ""
        property string textId: ""
        property string imageId: ""
        property bool textRequested: false
        property string lastLibraryAction: ""
        function fail(message) { console.error("FAIL: " + message); Qt.exit(1) }
        TestCase { id: checks; when: false }
        ClipboardController {
            id: first
            open: true
            onConcealRequested: Qt.callLater(first.finishClear)
            onCloseRequested: scene.copied++
            onLibraryActionFinished: (action, success, entryId) => {
                scene.lastLibraryAction = success ? action + ":" + entryId : "failed:" + action
            }
        }
        ClipboardController {
            id: reopened
            open: false
            onCloseRequested: scene.copied++
        }
        Timer {
            interval: 40
            repeat: true
            running: true
            onTriggered: {
                if (first.errorMessage || reopened.errorMessage) { scene.fail("controller error: " + first.errorMessage + " " + reopened.errorMessage); return }
                switch (scene.step) {
                case 0:
                    if (!first.loading && !first.libraryBusy && first.entries.length === 3) {
                        if (!scene.textRequested) {
                            scene.textRequested = true
                            first.requestText(first.entries[0].id)
                        } else if (first.textSources[first.entries[0].id] === "full untruncated text\n") {
                            if (!first.collections.length) {
                                if (!first.createCollection("Work")) scene.fail("collection rejected")
                                else scene.step = -1
                            } else if (!first.saveEntry(first.entries[0], first.collections[0].id)) scene.fail("save text to collection rejected")
                            else scene.step++
                        }
                    }
                    break
                case -1:
                    if (!first.libraryBusy && first.collections.length === 1) {
                        scene.collectionId = first.collections[0].id
                        if (!first.saveEntry(first.entries[0], scene.collectionId)) scene.fail("save text to collection rejected")
                        else scene.step = 1
                    }
                    break
                case 1:
                    if (!first.libraryBusy && first.savedEntries.length === 1) {
                        first.query = "tail-history"
                        first.filterEntries()
                        if (first.filteredEntries.length !== 1 || first.filteredEntries[0].id !== "3") {
                            scene.fail("library refresh truncated unsaved history text"); return
                        }
                        first.query = ""
                        first.filterEntries()
                        scene.textId = first.savedEntries[0].id
                        if (first.savedEntries[0].text !== "full untruncated text\n" || first.entries[0].text !== "full untruncated text\n"
                                || first.entries[0].preview !== "short" || first.savedEntries[0].collectionId !== scene.collectionId
                                || scene.lastLibraryAction !== "save:" + scene.textId) scene.fail("saved history text, preview, collection, or refresh signal incomplete")
                        else if (!first.saveEntry(first.entries[1])) scene.fail("save image rejected")
                        else scene.step++
                    }
                    break
                case 2:
                    if (!first.libraryBusy && first.savedEntries.length === 2) {
                        scene.imageId = first.savedEntries[0].id
                        if (!first.savedEntries[0].isImage || !first.renameCollection(scene.collectionId, "Notes")) scene.fail("image or rename")
                        else scene.step++
                    }
                    break
                case 3:
                    if (!first.libraryBusy && first.collections.length === 1 && first.collections[0].name === "Notes") {
                        scene.step++
                    }
                    break
                case 4:
                    if (!first.libraryBusy && first.collections[0].name === "Notes") {
                        first.moveEntry(first.savedEntries[0], scene.collectionId)
                        scene.step++
                    }
                    break
                case 5:
                    if (!first.libraryBusy && first.savedEntries[0].collectionId === scene.collectionId) {
                        first.setSection(scene.collectionId)
                        if (first.filteredEntries.length !== 2 || !first.filteredEntries.some(function(e) { return e.id === scene.imageId })) { scene.fail("collection filter"); return }
                        first.setSection("saved")
                        if (first.filteredEntries.length !== 2) { scene.fail("saved filter"); return }
                        first.query = "untruncated"
                        first.filterEntries()
                        if (first.filteredEntries.length !== 1 || first.filteredEntries[0].id !== scene.textId) { scene.fail("full text search"); return }
                        first.query = ""
                        first.setSection("history")
                        first.deleteCollection(scene.collectionId)
                        scene.step++
                    }
                    break
                case 6:
                    if (!first.libraryBusy && first.collections.length === 0) {
                        if (first.savedEntries.length !== 2 || first.savedEntries[0].collectionId !== "") { scene.fail("delete lost item"); return }
                        first.requestPreview(scene.imageId, false)
                        scene.step = 61
                    }
                    break
                case 61:
                    if (first.previewSources[scene.imageId + "|thumb"]
                            && checks.findChild(first, "clipboardPreviewJobs").count === 0) {
                        first.clearHistory()
                        scene.step = 7
                    }
                    break
                case 7:
                    if (!first.clearing && !first.clearPending && first.entries.length === 0) {
                        if (first.savedEntries.length !== 2 || !first.previewSources[scene.imageId + "|thumb"]) { scene.fail("wipe lost saved preview"); return }
                        reopened.open = true
                        scene.step++
                    }
                    break
                case 8:
                    if (!reopened.loading && !reopened.libraryBusy && reopened.savedEntries.length === 2 && reopened.previewDir.length) {
                        if (reopened.entries.length !== 0) { scene.fail("history not wiped"); return }
                        reopened.setSection("saved")
                        reopened.requestPreview(scene.imageId, false)
                        reopened.requestPreview(scene.imageId, true)
                        scene.step++
                    }
                    break
                case 9:
                    if (reopened.previewFailures[scene.imageId + "|thumb"] || reopened.previewFailures[scene.imageId + "|full"]) { scene.fail("saved preview failed"); return }
                    if (reopened.previewSources[scene.imageId + "|thumb"] && reopened.previewSources[scene.imageId + "|full"]
                            && checks.findChild(reopened, "clipboardPreviewJobs").count === 0) {
                        reopened.copyEntry(reopened.savedEntries.find(function(e) { return e.id === scene.textId }))
                        scene.step++
                    }
                    break
                case 10:
                    if (scene.copied === 1 && !reopened.copying) {
                        reopened.copyEntry(reopened.savedEntries.find(function(e) { return e.id === scene.imageId }))
                        scene.step++
                    }
                    break
                case 11:
                    if (scene.copied === 2 && !reopened.copying) {
                        console.log("PASS: clipboard library controller integration")
                        Qt.quit()
                    }
                    break
                }
            }
        }
        Timer { interval: 10000; running: true; onTriggered: scene.fail("timeout at step " + scene.step + " sources=" + JSON.stringify(reopened.previewSources) + " failures=" + JSON.stringify(reopened.previewFailures) + " dir=" + reopened.previewDir) }
    }
}
