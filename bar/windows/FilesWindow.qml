import QtQuick
import Quickshell
import "../components/files"

// Floating window of the file explorer. Transparent: the glass is drawn by FilesView with Theme
// tokens. Created by FilesHost on open and destroyed on close; a compositor close (visible ->
// false) asks the host to destroy it. Size/centering come from a Hyprland windowrule.
FloatingWindow {
    id: win

    property string startPath: ""
    property string selectName: ""
    readonly property alias view: filesView
    signal closeRequested()

    title: "Azog · Archivos"
    color: "transparent"
    implicitWidth: 1000
    implicitHeight: 660
    onVisibleChanged: if (!visible) closeRequested()

    function openTarget(folder, name) { filesView.openTarget(folder, name) }

    FilesView {
        id: filesView
        anchors.fill: parent
        startPath: win.startPath
        selectName: win.selectName
        active: win.visible
        onCloseRequested: win.closeRequested()
    }
}
