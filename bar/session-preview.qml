import QtQuick
import QtQuick.Effects
import Quickshell
import "surfaces"
import "components"
import "Singletons"

ShellRoot {
    QtObject {
        id: fake
        function lock() {}
        function suspend() {}
        function logout() {}
        function reboot() {}
        function shutdown() {}
    }
    Window {
        visible: true; width: 1200; height: 900
        title: "Isla · Vista previa de sesión"
        Item {
            id: scene
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: "#151822" }
            Image { id: wall; anchors.fill: parent; source: IslaPalette.wallpaper ? "file://" + IslaPalette.wallpaper : ""; sourceSize: Qt.size(1200, 900); fillMode: Image.PreserveAspectCrop; visible: false; asynchronous: true }
            MultiEffect { anchors.fill: parent; source: wall; blurEnabled: true; blurMax: 48; blur: 0.65 }
            Rectangle { anchors.fill: parent; color: "#40000000" }
            Item {
                anchors.centerIn: parent
                width: Number(Quickshell.env("ISLA_SESSION_PREVIEW_WIDTH")) || 640
                height: 470
                GlassCard { anchors.fill: parent; radius_: 34 }
                SessionSurface { open: true; actions: fake }
            }
        }
        Timer {
            interval: 1600; running: Quickshell.env("ISLA_SESSION_PREVIEW_SHOT") !== ""
            onTriggered: scene.grabToImage(result => { result.saveToFile(Quickshell.env("ISLA_SESSION_PREVIEW_SHOT")); Qt.quit() })
        }
    }
}
