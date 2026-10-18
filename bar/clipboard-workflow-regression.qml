import QtQuick
import QtTest
import Quickshell
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        visible: true
        width: 760; height: 680
        minimumWidth: width; maximumWidth: width
        minimumHeight: height; maximumHeight: height
        color: Theme.background
        Rectangle { anchors.fill: parent; color: Theme.background }
        Pill {
            id: pill
            x: (parent.width - width) / 2
            y: 30
            screenName: "clipboard-workflow"
            surface: "clipboard"
            onRequestClose: surface = ""
        }
        Timer { interval: 50; running: checks.done; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "ClipboardWorkflow"
            when: window.visible
            property bool done: false
            function check(ok, message) {
                if (!ok) { console.error("FAIL: clipboard workflow", message); Qt.exit(1); throw Error(message) }
            }
            function find(item, name) {
                if (!item) return null
                if (item.objectName === name) return item
                for (const child of item.children) { const found = find(child, name); if (found) return found }
                return null
            }
            function shot(name) {
                const directory = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!directory) return
                var saved = false
                const target = name === "surface" ? pill : window.contentItem
                target.grabToImage(result => { saved = result.saveToFile(directory + "/" + name + ".png") })
                tryVerify(() => saved)
            }
            function test_workflow() {
                tryVerify(() => pill.surfaceItem !== null, 4000)
                const view = find(pill, "clipboardView")
                check(!!view, "actual pill hosts clipboard view")
                tryVerify(() => !view.loading && !view.libraryBusy && view.filteredEntries.length === 40, 4000)
                wait(600)
                const list = find(view, "clipboardList")
                const first = list.itemAtIndex(0)
                check(!!first, "first row exists")
                shot("list")
                shot("surface")
                const saveRow = find(first, "clipboardRowPreview")
                mouseClick(saveRow, saveRow.width / 2, saveRow.height / 2)
                tryVerify(() => view.showingDetails)
                const details = find(view, "clipboardDetails")
                const id = view.detailEntry.id
                wait(60)
                check(view.detailProgress > 0 && view.detailProgress < 1, "preview has visible progressive entry")
                shot("preview-entering")
                view.closeDetails()
                wait(40)
                const interrupted = view.detailProgress
                view.openEntry(view.filteredEntries[0], false)
                check(Math.abs(view.detailProgress - interrupted) < 0.05, "preview reversal retargets without snapping")
                tryVerify(() => !details.textLoading, 4000)
                check(details.fullText.indexOf("línea 90") >= 0, "preview decodes full text beyond list summary")
                wait(500)
                shot("preview-text")
                const preview = find(view, "clipboardPreviewScroll")
                const body = preview.contentItem
                const before = body.contentY
                mouseWheel(preview, preview.width / 2, preview.height / 2, 0, -120)
                wait(300)
                check(body.contentY > before, "preview wheel scrolls long text")
                const scroll = body.contentY
                for (var i = 0; i < 12; ++i) mouseMove(preview, 20 + i, preview.height - 4)
                wait(200)
                check(Math.abs(body.contentY - scroll) < 1, "preview pointer cannot drag scroll down")
                const mainScroll = list.contentY
                view.selectedIndex = 20
                check(view.detailEntry.id === id && details.entry.id === id, "preview target does not follow hidden selection")
                check(!find(view, "clipboardSearch").enabled, "background search cannot mutate preview")
                const create = find(view, "clipboardDetailNewCollection")
                mouseClick(create, create.width / 2, create.height / 2)
                tryVerify(() => view.editingCollection)
                const name = find(view, "clipboardCollectionName")
                name.text = "Proyectos"
                name.forceActiveFocus()
                keyClick(Qt.Key_Return)
                tryVerify(() => !view.libraryBusy && !view.editingCollection && view.collections.some(c => c.name === "Proyectos"), 4000)
                const collection = view.collections.find(c => c.name === "Proyectos")
                check(details.chosenCollectionId === collection.id, "new collection is selected as destination")
                const save = find(view, "clipboardSaveButton")
                mouseClick(save, save.width / 2, save.height / 2)
                tryVerify(() => !view.libraryBusy && details.resultStatus === "success", 4000)
                check(view.detailEntry.saved && view.detailEntry.collectionId === collection.id, "save to chosen collection completed")
                check(details.fullText.indexOf("línea 90") >= 0, "saving must not replace full preview with list summary")
                check(body.contentY > before, "creating collection and saving preserve preview scroll")
                check(details.resultText.indexOf("Proyectos") >= 0, "real success names chosen collection")
                wait(500)
                shot("saved-confirmation")
                details.backRequested()
                wait(400)
                check(!view.showingDetails && list.contentY === mainScroll, "back preserves list scroll")
                const imageRow = list.itemAtIndex(1)
                check(!!imageRow, "image row available for quick organize")
                const imageSave = find(imageRow, "clipboardRowSave")
                mouseClick(imageSave, imageSave.width / 2, imageSave.height / 2)
                check(view.organizingOnly && details.organizerPage, "Guardar opens dedicated collection page")
                const imageIdBeforePreview = view.detailEntry.id
                view.textFailures = Object.assign({}, view.textFailures, {[imageIdBeforePreview]:true})
                tryCompare(view, "detailProgress", 1, 2000)
                check(!view.previewSources[imageIdBeforePreview + "|full"], "quick organizer does not decode full preview")
                check(list.contentY === mainScroll, "save page preserves list position")
                check(list.opacity === 0 && details.height > 300, "initial list is fully retired behind save page")
                check(!save.enabled && !details.destinationChosen, "existing collections require explicit destination before save")
                shot("save-page")
                const existing = find(details, "clipboardDestinationOption0")
                mouseClick(existing, existing.width / 2, existing.height / 2)
                check(details.destinationChosen && details.chosenCollectionId === collection.id, "mouse selects existing collection directly")
                mouseClick(save, save.width / 2, save.height / 2)
                tryVerify(() => !view.libraryBusy && details.resultStatus === "success", 4000)
                check(view.detailEntry.collectionId === collection.id, "entry saved directly to existing collection")
                const newDestination = find(details, "clipboardOrganizerNewCollection")
                mouseClick(newDestination, newDestination.width / 2, newDestination.height / 2)
                name.text = "Referencias"
                name.forceActiveFocus()
                keyClick(Qt.Key_Return)
                tryVerify(() => !view.libraryBusy && !view.editingCollection && view.collections.length === 2, 4000)
                const references = view.collections.find(c => c.name === "Referencias")
                check(details.chosenCollectionId === references.id, "save page creates and selects its destination")
                details.focusDestination()
                wait(80)
                check(details.collectionIndex === details.destinations.findIndex(c => c.id === references.id), "keyboard focus follows newly created collection")
                keyClick(Qt.Key_Return)
                check(details.chosenCollectionId === references.id, "Enter preserves the new collection destination")
                mouseClick(save, save.width / 2, save.height / 2)
                tryVerify(() => !view.libraryBusy && details.resultStatus === "success", 4000)
                check(!details.textFailed, "image organizer must not report a text failure")
                wait(300)
                shot("save-page-success")
                details.backRequested()
                wait(400)
                view.openEntry(view.filteredEntries[1], false)
                tryVerify(() => view.detailEntry.isImage, 2000)
                tryVerify(() => !!view.previewSources[view.detailEntry.id + "|full"], 4000)
                wait(500)
                shot("preview-image")
                const chosen = details.chosenCollectionId
                const combo = find(view, "clipboardDestination")
                mouseClick(combo, combo.width / 2, combo.height / 2)
                wait(100)
                wait(160)
                shot("collection-choices")
                keyClick(Qt.Key_Up)
                keyClick(Qt.Key_Return)
                wait(150)
                check(details.chosenCollectionId !== chosen, "dropdown selects destination without navigating hidden list")
                mouseClick(combo, combo.width / 2, combo.height / 2)
                wait(100)
                const noCollection = find(details, "clipboardDestinationOption" + details.destinations.findIndex(c => c.id === ""))
                check(!!noCollection, "native destination options available to mouse")
                mouseClick(noCollection, noCollection.width / 2, noCollection.height / 2)
                check(details.chosenCollectionId === "", "mouse chooses destination explicitly")
                const imageId = view.detailEntry.id
                mouseClick(save, save.width / 2, save.height / 2)
                tryVerify(() => !view.libraryBusy && details.resultStatus === "success", 4000)
                check(view.detailEntry.id === imageId && view.detailEntry.saved, "image save target stays stable")
                details.newCollectionRequested()
                name.text = "proyectos"
                name.forceActiveFocus()
                keyClick(Qt.Key_Return)
                tryVerify(() => !view.libraryBusy && view.errorMessage.indexOf("Ya existe") >= 0, 4000)
                check(view.editingCollection && view.collections.length === 2, "duplicate name keeps editor and existing destination")
                keyClick(Qt.Key_Escape)
                check(!view.editingCollection && view.showingDetails, "cancel duplicate creation restores preview")
                details.backRequested()
                view.sectionRequested("saved")
                tryVerify(() => view.filteredEntries.length === 2 && view.filteredEntries[0].saved)
                view.openEntry(view.filteredEntries[0], false)
                const removedId = view.detailEntry.id
                details.removeRequested(view.detailEntry)
                tryVerify(() => !view.libraryBusy && !view.showingDetails && view.filteredEntries.length === 1, 4000)
                check(!view.filteredEntries.some(e => e.id === removedId), "removed saved item cannot leave live copy controls")
                Config.update({appearance: {reduceMotion: true}})
                details.backRequested()
                check(view.detailProgress === 0, "reduced preview exit resolves directly")
                view.openEntry(view.filteredEntries[0], false)
                check(view.detailProgress === 1, "reduced preview entry resolves directly")
                const finalId = view.detailEntry.id
                view.selectedIndex = 20
                const copy = find(view, "clipboardDetailCopy")
                mouseClick(copy, copy.width / 2, copy.height / 2)
                tryVerify(() => pill.surface === "", 3000)
                console.log("PASS: actual pill clipboard preview scroll, stable target, full text, collection create/select/save, confirmation, back and reduced")
                done = true
            }
        }
        Timer { interval: 22000; running: true; onTriggered: { console.error("FAIL: clipboard workflow timeout"); Qt.exit(1) } }
    }
}
