import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property bool open: false
    property bool closing: false
    property string query: ""
    property var entries: []
    property var savedEntries: []
    readonly property var savedEntriesById: {
        const result = ({})
        for (const entry of savedEntries) result[entry.id] = entry
        return result
    }
    property var sessionSavedIds: ({})
    property var collections: []
    property string section: "history"
    property bool libraryBusy: false
    property var pendingLibraryAction: null
    property string pendingLibraryHistoryId: ""
    property string pendingLibrarySavedId: ""
    property string libraryOutputText: ""
    property bool libraryOutputReady: false
    property bool libraryExited: false
    property int librarySerial: 0
    property int handledLibrarySerial: 0
    property var libraryRefresh: null
    signal libraryActionFinished(string action, bool success, string entryId)
    readonly property string libraryScript: Qt.resolvedUrl("../services/clipboard_library.py").toString().replace(/^file:\/\//, "")
    readonly property string libraryListScript: Qt.resolvedUrl("../services/clipboard-list.sh").toString().replace(/^file:\/\//, "")
    property var filteredEntries: []
    property bool loading: true
    property bool copying: false
    property bool clearing: false
    property bool clearPending: false
    property string errorMessage: ""
    property string previewDir: ""
    property var previewSources: ({})
    property var previewFailures: ({})
    property var textSources: ({})
    property var textFailures: ({})
    property var textRequests: ({})
    property string listOutputText: ""
    property bool listOutputReady: false
    property bool listExited: false
    property int listExitCode: -1
    property bool listReloadPending: false
    signal closeRequested()
    signal concealRequested()
    signal resetQueryRequested()

    Component.onDestruction: if (previewDir.length) Quickshell.execDetached(["rm", "-rf", "--", previewDir])
    Process {
        id: previewDirProcess
        command: ["mktemp", "-d", (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/isla-clipboard.XXXXXX"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.previewDir = text.trim() }
    }
    ListModel { id: previewJobs; objectName: "clipboardPreviewJobs" }
    ListModel { id: textJobs }
    Repeater {
        model: textJobs
        delegate: Item {
            id: textJob
            required property int index
            readonly property string entryId: (textJobs.get(index) || {}).entryId || ""
            property bool outputReady: false
            property bool exited: false
            property bool completed: false
            property int exitCode: -1
            property string outputText: ""
            function finish() {
                if (completed || !outputReady || !exited) return
                completed = true
                root.finishTextRequest(entryId, exitCode === 0, outputText)
                const finishedId = entryId
                Qt.callLater(() => root.removeTextJob(finishedId))
            }
            Process {
                running: !textJob.completed && /^\d+$/.test(textJob.entryId)
                command: ["cliphist", "decode", textJob.entryId]
                stdout: StdioCollector {
                    onStreamFinished: {
                        textJob.outputText = text
                        textJob.outputReady = true
                        textJob.finish()
                    }
                }
                onExited: code => {
                    textJob.exitCode = code
                    textJob.exited = true
                    textJob.finish()
                }
            }
        }
    }
    Repeater {
        model: previewJobs
        delegate: ClipboardPreviewAdapter {
            required property int index
            entryId: (previewJobs.get(index) || {}).entryId || ""
            selectedPreview: !!(previewJobs.get(index) || {}).selectedPreview
            previewDir: root.previewDir
            requested: !root.clearing && /^\d+$/.test(entryId)
            onImageSourceChanged: if (imageSource.length) root.setPreview(entryId, selectedPreview, imageSource, false)
            onFailedChanged: if (failed) root.setPreview(entryId, selectedPreview, "", true)
        }
    }
    Repeater {
        model: previewJobs
        delegate: Item {
            id: savedPreview
            required property int index
            readonly property string entryId: (previewJobs.get(index) || {}).entryId || ""
            readonly property bool selectedPreview: !!(previewJobs.get(index) || {}).selectedPreview
            readonly property string target: root.previewDir + "/" + entryId + (selectedPreview ? "-preview.png" : ".png")
            Process {
                running: /^s-[0-9a-f]{32}$/.test(savedPreview.entryId) && root.previewDir.length > 0 && !root.clearing
                    && !root.previewSources[root.previewKey(savedPreview.entryId, savedPreview.selectedPreview)]
                    && !root.previewFailures[root.previewKey(savedPreview.entryId, savedPreview.selectedPreview)]
                command: ["python3", root.libraryScript, "preview", savedPreview.entryId, savedPreview.target,
                    savedPreview.selectedPreview ? "full" : "thumb"]
                onExited: code => root.setPreview(savedPreview.entryId, savedPreview.selectedPreview,
                    code === 0 ? "file://" + savedPreview.target : "", code !== 0)
            }
        }
    }
    function previewKey(id, selected) { return id + (selected ? "|full" : "|thumb") }
    function requestPreview(id, selected) {
        if (clearing || clearPending || !/^(\d+|s-[0-9a-f]{32})$/.test(id)) return
        var key = previewKey(id, selected)
        if (previewSources[key] || previewFailures[key]) return
        for (var i = 0; i < previewJobs.count; i++) {
            var job = previewJobs.get(i)
            if (job.entryId === id && job.selectedPreview === selected) return
        }
        previewJobs.append({entryId: id, selectedPreview: selected})
    }
    function setPreview(id, selected, source, failed) {
        if (clearing || clearPending) return
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
        if (source.length || failed) Qt.callLater(() => root.removePreviewJob(id, selected))
    }
    function removePreviewJob(id, selected) {
        for (var i = 0; i < previewJobs.count; i++) {
            const job = previewJobs.get(i)
            if (job.entryId === id && job.selectedPreview === selected) {
                previewJobs.remove(i)
                return
            }
        }
    }
    function requestText(id) {
        if (!/^\d+$/.test(id) || Object.prototype.hasOwnProperty.call(textSources, id)
                || textFailures[id] || textRequests[id]) return
        var requests = Object.assign({}, textRequests)
        requests[id] = true
        textRequests = requests
        textJobs.append({entryId: id})
    }
    function finishTextRequest(id, success, value) {
        var requests = Object.assign({}, textRequests)
        delete requests[id]
        textRequests = requests
        if (success) {
            var sources = Object.assign({}, textSources)
            sources[id] = value
            textSources = sources
        } else {
            var failures = Object.assign({}, textFailures)
            failures[id] = true
            textFailures = failures
        }
    }
    function removeTextJob(id) {
        for (var i = 0; i < textJobs.count; i++)
            if (textJobs.get(i).entryId === id) { textJobs.remove(i); return }
    }
    function clearHistoryTextCache() {
        textSources = ({})
        textFailures = ({})
        textRequests = ({})
        textJobs.clear()
    }
    onOpenChanged: {
        if (open) { loadLibrary(); loadEntries() }
        else searchDebounce.stop()
    }
    onQueryChanged: searchDebounce.restart()
    Timer {
        id: searchDebounce
        interval: 50
        onTriggered: root.filterEntries()
    }
    function loadEntries() {
        if (listProcess.running) { listReloadPending = true; return }
        loading = true
        errorMessage = ""
        clearHistoryTextCache()
        listOutputText = ""
        listOutputReady = false
        listExited = false
        listExitCode = -1
        listProcess.running = true
    }
    Process {
        id: listProcess
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            id: listOutput
            onStreamFinished: {
                root.listOutputText = listOutput.text || ""
                root.listOutputReady = true
                root.finishListLoad()
            }
        }
        onExited: code => {
            root.listExitCode = code
            root.listExited = true
            root.finishListLoad()
        }
    }
    function finishListLoad() {
        if (!listExited || !listOutputReady) return
        var output = listOutputText
        var code = listExitCode
        listExited = false
        listOutputReady = false
        if (code === 0) showEntries(output)
        else {
            loading = false
            errorMessage = qsTr("No se pudo cargar el historial.")
        }
        if (listReloadPending) {
            listReloadPending = false
            loadEntries()
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
                var saved = savedEntriesById[sessionSavedIds[parts[0]]]
                parsed.push({id: parts[0], text: isImage ? "" : (saved ? saved.text : content),
                    historyText: isImage ? "" : content,
                    isImage: isImage, preview: isImage ? content : content.substring(0, 100),
                    saved: !!saved, savedId: saved ? saved.id : "", collectionId: saved ? saved.collectionId : ""})
            }
        }
        entries = parsed
        loading = false
        filterEntries()
    }
    function filterEntries() {
        var source = section === "history" ? entries : section === "saved" ? savedEntries
            : savedEntries.filter(function(e) { return e.collectionId === section })
        if (!query || !query.trim().length) filteredEntries = source
        else {
            var lowerQuery = query.toLowerCase()
            filteredEntries = source.filter(function(e) {
                return e.text.toLowerCase().indexOf(lowerQuery) >= 0
            })
        }
    }
    function setSection(id) {
        if (id !== "history" && id !== "saved" && !collections.some(function(c) { return c.id === id })) return
        section = id
        filterEntries()
    }
    function loadLibrary() { runLibrary("list", []) }
    function runLibrary(action, args) {
        if (libraryBusy) return false
        libraryBusy = true
        librarySerial++
        handledLibrarySerial = 0
        pendingLibraryAction = action
        libraryOutputText = ""
        libraryOutputReady = false
        libraryExited = false
        libraryProcess.command = action === "list" ? ["sh", libraryListScript]
            : ["python3", libraryScript, action].concat(args)
        libraryProcess.running = true
        return true
    }
    function saveEntry(entry, collectionId) {
        if (!entry || (entry.saved && collectionId === undefined) || copying || clearing || clearPending || !/^\d+$/.test(entry.id)) return false
        if (collectionId !== undefined && collectionId !== "" && !/^c-[0-9a-f]{32}$/.test(collectionId)) return false
        var args = [entry.id, entry.isImage ? "1" : "0", entry.text, entry.preview]
        if (collectionId !== undefined) args.push(collectionId)
        if (!runLibrary("save", args)) return false
        pendingLibraryHistoryId = entry.id
        return true
    }
    function removeSavedEntry(entry) {
        var id = entry && (entry.savedId || entry.id)
        if (!/^s-[0-9a-f]{32}$/.test(id || "")) return false
        if (!runLibrary("remove", [id])) return false
        pendingLibrarySavedId = id
        return true
    }
    function createCollection(name) { return runLibrary("create", [name]) }
    function renameCollection(id, name) {
        if (!/^c-[0-9a-f]{32}$/.test(id)) return false
        return runLibrary("rename", [id, name])
    }
    function deleteCollection(id) {
        if (!/^c-[0-9a-f]{32}$/.test(id)) return false
        return runLibrary("delete", [id])
    }
    function moveEntry(entry, collectionId) {
        var id = entry && (entry.savedId || entry.id)
        if (!/^s-[0-9a-f]{32}$/.test(id || "") ||
            (collectionId && !/^c-[0-9a-f]{32}$/.test(collectionId))) return false
        return runLibrary("move", [id, collectionId || ""])
    }
    Process {
        id: libraryProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.libraryOutputText = text
                root.libraryOutputReady = true
                if (root.libraryExited) root.handleLibraryOutput(text)
            }
        }
        onExited: code => {
            var serial = root.librarySerial
            root.libraryExited = true
            if (root.libraryOutputReady) root.handleLibraryOutput(root.libraryOutputText)
            else if (code !== 0) Qt.callLater(function() {
                if (root.libraryBusy && root.librarySerial === serial && !root.libraryOutputReady)
                    root.handleLibraryOutput("")
            })
        }
    }
    function handleLibraryOutput(output) {
            if (!root.libraryBusy || root.handledLibrarySerial === root.librarySerial) return
            root.handledLibrarySerial = root.librarySerial
            var action = root.pendingLibraryAction
            var historyId = root.pendingLibraryHistoryId
            var savedId = root.pendingLibrarySavedId
            root.pendingLibraryAction = null
            root.pendingLibraryHistoryId = ""
            root.pendingLibrarySavedId = ""
            root.libraryBusy = false
            var result = null
            try { result = JSON.parse(output || "") } catch (e) { }
            if (!result || !result.ok) {
                root.errorMessage = result && result.error === "collection_exists" ? qsTr("Ya existe una colección con ese nombre.") : qsTr("No se pudo actualizar la biblioteca.")
                if (action === "list" && root.libraryRefresh) {
                    const refresh = root.libraryRefresh
                    root.libraryRefresh = null
                    root.libraryActionFinished(refresh.action, false, refresh.entryId)
                } else if (action !== "list") {
                    root.libraryActionFinished(action, false, historyId || savedId)
                }
                return
            }
            root.errorMessage = ""
            if (action === "save" && historyId) {
                var saved = Object.assign({}, root.sessionSavedIds)
                saved[historyId] = result.data.id
                root.sessionSavedIds = saved
            } else if (action === "remove" && savedId) {
                var kept = {}
                for (var key in root.sessionSavedIds)
                    if (root.sessionSavedIds[key] !== savedId) kept[key] = root.sessionSavedIds[key]
                root.sessionSavedIds = kept
            }
            if (action === "list") {
                root.collections = result.data.collections
                root.savedEntries = result.data.entries.map(function(e) {
                    return Object.assign({}, e, {saved: true})
                })
                root.entries = root.entries.map(function(e) {
                    var saved = root.savedEntriesById[root.sessionSavedIds[e.id]]
                    return Object.assign({}, e, {text: saved ? saved.text : (e.historyText === undefined ? e.text : e.historyText), saved: !!saved,
                        savedId: saved ? saved.id : "", collectionId: saved ? saved.collectionId : ""})
                })
                if (root.section !== "history" && root.section !== "saved" &&
                    !root.collections.some(function(c) { return c.id === root.section })) root.section = "saved"
                root.filterEntries()
                if (root.libraryRefresh) {
                    const refresh = root.libraryRefresh
                    root.libraryRefresh = null
                    root.libraryActionFinished(refresh.action, true, refresh.entryId)
                }
            } else {
                var entryId = result.data.id || savedId || ""
                root.libraryRefresh = {action: action, entryId: entryId}
                root.loadLibrary()
            }
    }
    function copyEntry(entry) {
        if (!entry || copying || clearing || !/^(\d+|s-[0-9a-f]{32})$/.test(entry.id)) return
        copying = true
        errorMessage = ""
        copyProcess.command = entry.saved && /^s-[0-9a-f]{32}$/.test(entry.id)
            ? ["python3", libraryScript, "copy", entry.id]
            : ["bash", "-o", "pipefail", "-c",
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
        if (loading || copying || clearing || libraryBusy || entries.length === 0) return
        clearing = true
        errorMessage = ""
        clearProcess.running = true
    }
    Process {
        id: clearProcess
        command: ["python3", root.libraryScript, "wipe"]
        onExited: code => {
            if (code === 0) {
                root.clearPending = true
                root.clearHistoryTextCache()
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
        var savedJobs = []
        var keptSources = ({})
        var keptFailures = ({})
        for (var key in previewSources) if (/^s-[0-9a-f]{32}\|/.test(key)) keptSources[key] = previewSources[key]
        for (var failure in previewFailures) if (/^s-[0-9a-f]{32}\|/.test(failure)) keptFailures[failure] = previewFailures[failure]
        for (var i = 0; i < previewJobs.count; i++) {
            var job = previewJobs.get(i)
            if (/^s-[0-9a-f]{32}$/.test(job.entryId)) savedJobs.push({entryId: job.entryId, selectedPreview: job.selectedPreview})
            else if (/^\d+$/.test(job.entryId) && previewDir.length) {
                Quickshell.execDetached(["rm", "-f", "--", previewDir + "/" + job.entryId + ".png",
                    previewDir + "/" + job.entryId + "-preview.png"])
            }
        }
        previewJobs.clear()
        previewSources = keptSources
        previewFailures = keptFailures
        for (var j = 0; j < savedJobs.length; j++)
            if (!keptSources[previewKey(savedJobs[j].entryId, savedJobs[j].selectedPreview)])
                previewJobs.append(savedJobs[j])
        entries = []
        sessionSavedIds = ({})
        resetQueryRequested()
        filterEntries()
        clearing = false
    }
}
