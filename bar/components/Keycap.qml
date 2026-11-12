import QtQuick
import "../Singletons"

// One key of a shortcut. Arrives with a short settle (scale 0.86 → 1, 120 ms)
// so recorded keys read as "typed in"; reduced motion shows it at rest.
Rectangle {
    id: cap
    property string text: ""
    property real s: 1
    property real size: Theme.fontSizeBody * s
    property bool emphasis: false
    property bool muted: false
    property bool reducedMotion: Flags.reduceMotion
    implicitWidth: Math.max(implicitHeight, label.implicitWidth + 14 * s)
    implicitHeight: Math.round(size * 1.95)
    radius: 7 * s
    color: emphasis ? Qt.alpha(Theme.accent, Theme.alphaSelected) : Qt.alpha(Theme.foreground, muted ? Theme.alphaFaint : Theme.alphaSoft)
    border.width: 1
    border.color: emphasis ? Qt.alpha(Theme.accent, 0.7) : Qt.alpha(Theme.foreground, Theme.alphaSubtle)
    Behavior on color { enabled: !cap.reducedMotion; ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
    // Bottom lip: a keycap, not a tag.
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 1
        height: 2 * cap.s; radius: cap.radius
        color: Qt.alpha(Theme.foreground, cap.muted ? 0.04 : 0.09)
    }
    Text {
        id: label
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1 * cap.s
        text: cap.text
        color: cap.muted ? Qt.alpha(Theme.foreground, 0.5) : Theme.foreground
        font.family: Config.appearance.fontFamily
        font.pixelSize: cap.size
        font.weight: Font.Medium
    }
    Accessible.role: Accessible.StaticText
    Accessible.name: text
    transformOrigin: Item.Center
    scale: 1
    Component.onCompleted: if (!reducedMotion && visible) arrive.start()
    NumberAnimation on scale { id: arrive; running: false; from: 0.86; to: 1; duration: Motion.hover; easing.type: Easing.OutBack }
}
