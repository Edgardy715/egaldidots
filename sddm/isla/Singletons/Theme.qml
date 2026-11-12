pragma Singleton
import QtQuick

// Greeter stand-in for Isla's Theme. Main.qml fills the colours from theme.conf;
// the tokens below mirror bar/Singletons/Theme.qml.
QtObject {
    property color foreground: "#e6e3d5"
    property color background: "#14140c"
    property color accent: "#cbcb76"
    property color error: "#ffb4ab"
    property color iconSecondary: "#cac7b6"
    property color cardTop: "#2b2a22"
    property color cardBot: "#1c1c14"
    property color outline: "#49473a"
    property string fontMedia: "sans-serif"
    readonly property color iconPrimary: foreground
    readonly property color border: Qt.alpha(outline, 0.55)
    readonly property real alphaSoft: 0.10
    readonly property real alphaWash: 0.12
    readonly property real alphaWashStrong: 0.20
    readonly property color signalSuccess: "#32d975"
    readonly property color signalError: "#ff4d61"
    readonly property real strokeRing: 0.045
    readonly property real strokeSymbol: 0.055
    readonly property real fontSizeBodyLg: 13
}
