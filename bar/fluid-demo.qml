import QtQuick
import Quickshell
import Quickshell.Wayland
import "Singletons"
import "fluid" as Fluid

// Standalone config: run with `quickshell -p bar/fluid-demo.qml`.
// It is never imported by bar/shell.qml.
ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window
            required property var modelData
            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell.fluid-island-demo"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true; left: true; right: true }
            implicitHeight: Math.min(440, modelData ? modelData.height : 440)

            mask: inputMask
            Region {
                id: inputMask
                item: demo.bodyHit
                Region { item: demo.dropHit }
                Region { item: demo.bridgeHit }
                Region { item: demo.controlsHit }
            }

            Fluid.FluidIslandDemo {
                id: demo
                anchors.fill: parent
                scaleFactor: (window.modelData ? window.modelData.height / 1080 : 1) * Flags.uiScale
                theme: Theme
                flags: Flags
            }
        }
    }
}
