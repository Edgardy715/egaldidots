import QtQuick
import Quickshell
import "Singletons"

// Isolated IPC host for tests/settings-integration.py. Never part of shell.qml.
ShellRoot {
    Component.onCompleted: { Config.loaded }
    Timer { interval: 30000; running: true; onTriggered: Qt.exit(1) }
}
