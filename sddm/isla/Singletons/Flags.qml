pragma Singleton
import QtQuick

// Greeter stand-in for Isla's Flags. Main.qml fills it from theme.conf, which
// install.sh writes from Isla's settings; nothing is read from a home here.
QtObject {
    property bool reduceMotion: false
    property real motionScale: 1
    property real fontScale: 1
    property bool time12h: false
}
