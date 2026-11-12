import QtQuick
import Quickshell
import Wpscan
import Qt5Compat.GraphicalEffects

ShellRoot {
    WallpaperScanner { }
    Timer {
        interval: 100
        running: true
        onTriggered: Qt.quit()
    }
}
