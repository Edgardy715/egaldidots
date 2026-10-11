import QtQuick
import QtQuick.Controls.Basic
import "../components"
import "../Singletons"

TextField {
    id: root
    property bool invalid: false
    property bool chrome: true
    property real cornerRadius: 12
    readonly property bool motionActive: visible && (!Window.window || Window.window.visible)
    implicitHeight: Math.max(44, Theme.fontSizeBodyLg * 1.5 + 20)
    leftPadding: 14
    rightPadding: 14
    font.family: Config.appearance.fontFamily
    font.pixelSize: Theme.fontSizeBodyLg
    color: Theme.foreground
    placeholderTextColor: "transparent"
    selectionColor: Qt.alpha(Theme.accent, 0.35)
    selectedTextColor: Theme.foreground
    selectByMouse: true
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    cursorDelegate: InputCaret { input: root; motionActive: root.motionActive }
    InputPlaceholder { input: root; motionActive: root.motionActive }
    background: Rectangle {
        visible: root.chrome
        implicitHeight: 44
        radius: root.cornerRadius
        color: Qt.alpha(Theme.foreground, root.activeFocus ? 0.085 : root.hovered ? 0.065 : 0.035)
        border.width: 1
        border.color: root.invalid ? Theme.error : root.activeFocus ? Theme.accent : Qt.alpha(Theme.foreground, root.hovered ? 0.22 : 0.12)
        opacity: root.enabled ? 1 : 0.45
        Behavior on color { enabled: root.motionActive; ColorAnimation { duration: Motion.hover } }
        Behavior on border.color { enabled: root.motionActive; ColorAnimation { duration: Motion.hover } }
        Behavior on opacity { enabled: root.motionActive; NumberAnimation { duration: Motion.fast } }
        Rectangle {
            anchors.fill: parent; anchors.margins: -2
            color: "transparent"; radius: parent.radius + 2
            border.width: 2; border.color: root.invalid ? Theme.error : Theme.accent
            opacity: root.activeFocus ? 0.65 : 0
            Behavior on opacity { enabled: root.motionActive; NumberAnimation { duration: Motion.hover } }
        }
    }
}
