import QtQuick
import Quickshell
import Quickshell.Io

// Explorer window host + its IPC handler (qs -c bar ipc call files open <ruta absoluta>).
// Shared by shell.qml and the isolated test host so the contract is defined once.
Scope {
    FilesHost { id: host }
    IpcHandler {
        target: "files"
        function open(path: string): bool { return host.open(path) }
        function toggle(): bool { return host.toggle() }
        function close(): bool { return host.close() }
        function status(): string { return JSON.stringify({ open: host.isOpen, path: host.currentPath }) }
    }
}
