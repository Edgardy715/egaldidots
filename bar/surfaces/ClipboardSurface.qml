import QtQuick
import "../"
import "../Singletons"
import "../components"

PillSurface {
    id: root
    mTop: Theme.marginMd; mLeft: Theme.marginMd; mRight: Theme.marginMd; mBottom: Theme.marginMd
    property alias query: view.query
    property alias selectedIndex: view.selectedIndex
    readonly property var entries: controller.entries
    readonly property var filteredEntries: controller.filteredEntries
    readonly property var selectedEntry: view.selectedEntry
    readonly property bool loading: controller.loading
    readonly property bool copying: controller.copying
    readonly property bool clearing: controller.clearing
    readonly property string errorMessage: controller.errorMessage
    function showPreview() { view.openEntry(view.selectedEntry, false) }
    function filterEntries() { controller.filterEntries(); view.resetSelection() }
    function copyEntry(entry) { controller.copyEntry(entry) }
    function clearHistory() { controller.clearHistory() }

    ClipboardController {
        id: controller
        open: root.open
        closing: root.closing
        query: view.query
        onCloseRequested: root.requestClose()
        onConcealRequested: view.concealHistory()
        onResetQueryRequested: view.resetQuery()
        onLibraryActionFinished: (action, success, entryId) => view.libraryResult(action, success, entryId)
    }
    ClipboardView {
        id: view
        anchors.fill: parent
        s: root.s
        open: root.open
        closing: root.closing
        collections: controller.collections
        section: controller.section
        libraryBusy: controller.libraryBusy
        onSectionRequested: sectionId => controller.setSection(sectionId)
        onSaveRequested: (entry, collectionId) => controller.saveEntry(entry, collectionId)
        onRemoveSavedRequested: entry => controller.removeSavedEntry(entry)
        onMoveRequested: (entry, collectionId) => controller.moveEntry(entry, collectionId)
        onCreateCollectionRequested: name => controller.createCollection(name)
        onRenameCollectionRequested: (collectionId, name) => controller.renameCollection(collectionId, name)
        onDeleteCollectionRequested: collectionId => controller.deleteCollection(collectionId)
        entries: controller.entries
        filteredEntries: controller.filteredEntries
        loading: controller.loading
        copying: controller.copying
        clearing: controller.clearing
        errorMessage: controller.errorMessage
        previewDir: controller.previewDir
        textSources: controller.textSources
        textFailures: controller.textFailures
        onTextRequested: id => controller.requestText(id)
        previewSources: controller.previewSources
        previewFailures: controller.previewFailures
        onRequestClose: root.requestClose()
        onCopyRequested: entry => controller.copyEntry(entry)
        onClearRequested: controller.clearHistory()
        onRefreshRequested: controller.loadEntries()
        onHistoryConcealed: controller.finishClear()
        onPreviewRequested: (entryId, selectedPreview) => controller.requestPreview(entryId, selectedPreview)
    }
}
