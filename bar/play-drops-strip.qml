import QtQuick
import Quickshell
import "components"
import "Singletons"

// Tira fija de la división de la gota de play (split 0 → 1) para revisar formas.
ShellRoot {
    settings.watchFiles: false
    Window {
        title: "play-drops-strip"
        visible: true
        width: 1000; height: 140
        color: Theme.cardBot
        Row {
            id: strip
            anchors.centerIn: parent; spacing: 4
            Repeater {
                model: 11
                MediaTransportButton {
                    required property int index
                    primary: true; size: 76; iconSize: 30; motionEnabled: false
                    primaryColor: "#c792ea"; iconName: "pause"; playing: true
                    Component.onCompleted: split = index / 10
                }
            }
        }
        Timer {
            interval: 900; running: true
            onTriggered: strip.grabToImage(r => { r.saveToFile(Quickshell.env("STRIP_OUT")); Qt.quit() })
        }
    }
}
