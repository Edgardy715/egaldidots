import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property bool open: false
    property bool closing: false
    property string query: ""
    property var entries: []
    property var filteredEntries: []
    property bool loading: true
    property bool copying: false
    property bool clearing: false
    property bool clearPending: false
    property string errorMessage: ""
    property string previewDir: ""
    property var previewSources: ({})
    property var previewFailures: ({})
    signal closeRequested()
    signal concealRequested()
    signal resetQueryRequested()

    Component.onDestruction: if (previewDir.length) Quickshell.execDetached(["rm", "-rf", "--", previewDir])
    Process {
        command: ["mktemp", "-d", (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/isla-clipboard.XXXXXX"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.previewDir = text.trim() }
    }
    ListModel { id: previewJobs }
    Repeater {
        model: previewJobs
        delegate: ClipboardPreviewAdapter {
            required property int index
            entryId: previewJobs.get(index).entryId
            selectedPreview: previewJobs.get(index).selectedPreview
            previewDir: root.previewDir
            onImageSourceChanged: if (imageSource.length) root.setPreview(entryId, selectedPreview, imageSource, false)
            onFailedChanged: if (failed) root.setPreview(entryId, selectedPreview, "", true)
        }
    }
    function previewKey(id, selected) { return id + (selected ? "|full" : "|thumb") }
    function requestPreview(id, selected) {
        if (!/^\d+$/.test(id)) return
        var key = previewKey(id, selected)
        if (previewSources[key] || previewFailures[key]) return
        for (var i = 0; i < previewJobs.count; i++) {
            var job = previewJobs.get(i)
            if (job.entryId === id && job.selectedPreview === selected) return
        }
        previewJobs.append({entryId: id, selectedPreview: selected})
    }
    function setPreview(id, selected, source, failed) {
        var key = previewKey(id, selected)
        if (source.length) {
            var sources = Object.assign({}, previewSources)
            sources[key] = source
            previewSources = sources
        } else if (failed) {
            var failures = Object.assign({}, previewFailures)
            failures[key] = true
            previewFailures = failures
        }
    }
    onOpenChanged: {
        if (open) loadEntries()
        else searchDebounce.stop()
    }
    onQueryChanged: searchDebounce.restart()
    Timer {
        id: searchDebounce
        interval: 50
        onTriggered: root.filterEntries()
    }
    function loadEntries() {
        loading = true
        errorMessage = ""
        listProcess.running = true
    }
    Process {
        id: listProcess
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            id: listOutput
            onStreamFinished: root.showEntries(listOutput.text || "")
        }
        onExited: code => {
            if (code !== 0) {
                root.loading = false
                root.errorMessage = qsTr("No se pudo cargar el historial.")
            }
        }
    }
    function showEntries(output) {
        if (!open || closing) return
        var lines = output.split("\n")
        var parsed = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line.length) continue
            var parts = line.split("\t")
            if (parts.length >= 2) {
                var content = parts.slice(1).join("\t")
                var isImage = content.startsWith("[[ binary data ") && content.endsWith("]]")
                parsed.push({id: parts[0], text: isImage ? "" : content,
                    isImage: isImage, preview: isImage ? content : content.substring(0, 100)})
            }
        }
        entries = parsed
        loading = false
        filterEntries()
    }
    function filterEntries() {
        if (!query || !query.trim().length) filteredEntries = entries
        else {
            var lowerQuery = query.toLowerCase()
            filteredEntries = entries.filter(function(e) {
                return e.text.toLowerCase().indexOf(lowerQuery) >= 0
            })
        }
    }
    function copyEntry(entry) {
        if (!entry || copying || clearing || !/^\d+$/.test(entry.id)) return
        copying = true
        errorMessage = ""
        copyProcess.command = ["bash", "-o", "pipefail", "-c",
            'cliphist decode "$1" | wl-copy', "cliphist-copy", entry.id]
        copyProcess.running = true
    }
    Process {
        id: copyProcess
        onExited: code => {
            root.copying = false
            if (code === 0) root.closeRequested()
            else root.errorMessage = qsTr("No se pudo copiar la entrada.")
        }
    }
    function clearHistory() {
        if (loading || copying || clearing || entries.length === 0) return
        clearing = true
        errorMessage = ""
        clearProcess.running = true
    }
    Process {
        id: clearProcess
        command: ["cliphist", "wipe"]
        onExited: code => {
            if (code === 0) {
                root.clearPending = true
                root.concealRequested()
            } else {
                root.clearing = false
                root.errorMessage = qsTr("No se pudo limpiar el historial.")
            }
        }
    }
    function finishClear() {
        if (!clearPending) return
        clearPending = false
        entries = []
        resetQueryRequested()
        filterEntries()
        clearing = false
    }
}
