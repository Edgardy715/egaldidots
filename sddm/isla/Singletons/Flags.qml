pragma Singleton
import QtQuick

// Greeter stand-in for Isla's Flags: defaults only, nothing read from a home.
QtObject {
    property bool reduceMotion: false
    readonly property real motionScale: 1
    readonly property real fontScale: 1
    property bool time12h: false
}
