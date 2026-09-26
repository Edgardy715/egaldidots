import QtQuick
import Quickshell
import "Singletons"

ShellRoot {
    function check(condition, message) {
        if (!condition) { console.error("FAIL: " + message); Qt.exit(1) }
    }
    Timer {
        interval: 50
        repeat: true
        running: true
        property bool started: false
        onTriggered: {
            if (!Config.loaded || started) return
            started = true
            check(Config.error === "", "load defaults")
            check(Config.update({ appearance: { fontScale: 1.25, fontMediaFamily: "Inter" }, extension: { keep: 7 } }).ok, "update")
            check(Flags.fontScale === 1.25 && Theme.fontSizeBody === 15, "reactive consumers")
            check(!Config.update({ appearance: { fontScale: -2, time12h: false } }).ok, "reject invalid batch")
            check(Flags.fontScale === 1.25 && Flags.time12h, "no partial apply")
            Config.discard()
            check(Flags.fontScale === 1 && !Config.dirty, "discard preserves binding")
            Config.update({ appearance: { fontScale: 1.1 }, extension: { keep: 7 } })
            check(Config.save(), "save accepted")
            completed.start()
        }
    }
    Timer {
        id: completed
        interval: 50
        repeat: true
        onTriggered: {
            if (Config.saving) return
            check(!Config.error && !Config.dirty, "async save: " + Config.error)
            check(Config.snapshot().document.extension.keep === 7, "extension persisted")
            check(Flags.fontScale === 1.1, "saved value")
            console.log("PASS: config reactive update, rejection, discard and atomic async save")
            Qt.quit()
        }
    }
    Timer { interval: 8000; running: true; onTriggered: { console.error("FAIL: config timeout: " + Config.error); Qt.exit(1) } }
}
