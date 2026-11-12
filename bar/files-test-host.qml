import QtQuick
import Quickshell
import "Singletons"
import "components/files"

// Isolated IPC host for tests/files-ipc.py: the same FilesIpc as shell.qml, no pill.
ShellRoot {
    settings.watchFiles: false
    FilesIpc {}
    Component.onCompleted: { Config.loaded }
    Timer { interval: 60000; running: true; onTriggered: Qt.exit(1) }
}
