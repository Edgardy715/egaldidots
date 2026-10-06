pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Settings.js" as Settings

// Filesystem/IPC adapter. Settings.js owns the format and validation; Flags is
// a read-only compatibility facade for existing surfaces.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || home + "/.config"
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || home + "/.cache"
    readonly property string configFile: Quickshell.env("ISLA_CONFIG") || configHome + "/isla/shell.json"
    readonly property var context: ({ home: home, configHome: configHome, cacheHome: cacheHome })
    readonly property var schema: Settings.schema(context)
    readonly property var catalog: Settings.catalog(context)
    readonly property var modules: _effective.modules
    readonly property var profile: _effective.profile
    readonly property string userAvatar: _effective.paths.userAvatar
    readonly property var appearance: _effective.appearance
    readonly property string walColorsFile: _effective.paths.walColorsFile
    readonly property string wallpaperDir: _effective.paths.wallpaperDir
    readonly property string wallpaperCacheDir: _effective.paths.wallpaperCacheDir
    readonly property string wallpaperApplyScript: _effective.paths.wallpaperApplyScript
    readonly property bool dirty: JSON.stringify(_document) !== JSON.stringify(_diskDocument)
    readonly property bool saving: _saveStage !== ""
    property string error: ""
    property bool loaded: false

    property var _effective: Settings.defaults(context)
    property var _document: ({})
    property var _diskDocument: ({})
    property string _diskText: ""
    property string _saveStage: ""
    property var _saveDocument: ({})
    property string _saveText: ""

    function snapshot() {
        return { file: configFile, loaded: loaded, dirty: dirty, saving: saving,
            error: error, document: Settings.copy(_document), effective: Settings.copy(_effective) }
    }

    function validate(document) { return Settings.validate(document, context) }

    function update(patch) {
        if (!loaded || saving) return { ok: false, errors: ["Settings are loading or saving"] }
        try {
            const next = Settings.merge(_document, patch)
            const result = validate(next)
            if (result.ok) {
                _document = next
                _effective = result.effective
            }
            return result
        } catch (exception) { return { ok: false, errors: [String(exception)] } }
    }

    function discard() {
        if (saving) return false
        _document = Settings.copy(_diskDocument)
        _effective = validate(_diskDocument).effective
        return true
    }

    function reload() {
        if (saving) return false
        file.reload()
        return true
    }

    function acceptText(text, missing) {
        try {
            const document = missing ? {} : JSON.parse(text)
            const result = validate(document)
            if (!result.ok) throw new Error(result.errors.join("; "))
            _diskText = text
            _diskDocument = Settings.copy(document)
            _document = document
            _effective = result.effective
            error = ""
        } catch (exception) {
            error = "Invalid settings: " + exception
            console.warn("[Isla Config] " + error)
        }
        // On initial failure defaults remain usable; later failures retain the
        // complete last valid snapshot.
        loaded = true
    }

    function save() {
        if (!loaded || saving || error.length) return false
        if (!dirty) return true
        _saveDocument = Settings.copy(_document)
        _saveText = JSON.stringify(_saveDocument, null, 2) + "\n"
        _saveStage = "checking"
        file.reload()
        return true
    }

    function checkedDisk(text, missing) {
        if (text !== _diskText || (!missing && !text.trim().length)) {
            error = "Settings changed on disk; reload before saving"
            _saveStage = ""
            return
        }
        _saveStage = "directory"
        directory.running = true
    }

    // Native atomic writes preserve the old file on write failure. Saving is
    // asynchronous; clients observe saving/error instead of treating acceptance
    // of a save request as confirmation that it reached disk.
    Process {
        id: directory
        command: ["mkdir", "-p", "--", root.configFile.slice(0, root.configFile.lastIndexOf("/")) || "."]
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0 || exitStatus !== 0) {
                root.error = "Could not create settings directory"
                root._saveStage = ""
                return
            }
            root._saveStage = "writing"
            file.setText(root._saveText)
        }
    }

    FileView {
        id: file
        path: root.configFile
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: { if (!root.saving) reload() }
        onLoaded: {
            if (root._saveStage === "checking") root.checkedDisk(file.text())
            else if (!root.saving) root.acceptText(file.text())
        }
        onLoadFailed: function(reason) {
            if (reason === FileViewError.FileNotFound) {
                if (root._saveStage === "checking") root.checkedDisk("", true)
                else if (!root.saving) root.acceptText("", true)
            } else {
                root.error = "Could not read " + root.configFile
                root.loaded = true
                root._saveStage = ""
                console.warn("[Isla Config] " + root.error)
            }
        }
        onSaved: {
            root._diskDocument = Settings.copy(root._saveDocument)
            root._diskText = root._saveText
            root.error = ""
            root._saveStage = ""
            // Atomic replacement changes the watched inode. Reload re-arms the
            // native watcher; an identical reload need not emit loaded again.
            reload()
        }
        onSaveFailed: function(reason) {
            root.error = "Could not save settings (" + reason + ")"
            root._saveStage = ""
        }
    }

    IpcHandler {
        target: "settings"
        function get(): string { return JSON.stringify(root.snapshot()) }
        function schema(): string { return JSON.stringify(root.schema) }
        function catalog(): string { return JSON.stringify(root.catalog) }
        function validate(document: string): string {
            try { return JSON.stringify(root.validate(JSON.parse(document))) }
            catch (exception) { return JSON.stringify({ ok: false, errors: [String(exception)] }) }
        }
        function update(patch: string): string {
            try { return JSON.stringify(root.update(JSON.parse(patch))) }
            catch (exception) { return JSON.stringify({ ok: false, errors: [String(exception)] }) }
        }
        function save(): bool { return root.save() }
        function discard(): bool { return root.discard() }
        function reload(): bool { return root.reload() }
    }
}
