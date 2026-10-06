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
    }
    ClipboardView {
        id: view
        anchors.fill: parent
        s: root.s
        open: root.open
        closing: root.closing
        entries: controller.entries
        filteredEntries: controller.filteredEntries
        loading: controller.loading
        copying: controller.copying
        clearing: controller.clearing
        errorMessage: controller.errorMessage
        previewDir: controller.previewDir
        previewSources: controller.previewSources
        previewFailures: controller.previewFailures
        onRequestClose: root.requestClose()
        onCopyRequested: entry => controller.copyEntry(entry)
        onClearRequested: controller.clearHistory()
        onHistoryConcealed: controller.finishClear()
        onPreviewRequested: (entryId, selectedPreview) => controller.requestPreview(entryId, selectedPreview)
    }
}
