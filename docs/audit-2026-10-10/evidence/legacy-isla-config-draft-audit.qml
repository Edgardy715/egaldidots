import QtQuick
import Quickshell
import "file:/home/zdito/.config/quickshell/bar/Singletons"
import "file:/home/zdito/.config/quickshell/bar/settings"
ShellRoot {
    SettingsPage { id: page; config: Config; width: 700; height: 500 }
    IpcHandler {
        target: "audit"
        function draft(): bool { page.setDraft("profile", "displayName", "Mi borrador"); return page.hasDrafts }
        function commit(): bool { return page.commitDrafts() }
    }
}
