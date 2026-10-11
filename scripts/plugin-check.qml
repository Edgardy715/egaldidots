import QtQuick
import Quickshell
import Wpscan

ShellRoot {
    WallpaperScanner { }
    Timer {
        interval: 100
        running: true
        onTriggered: Qt.quit()
    }
}
