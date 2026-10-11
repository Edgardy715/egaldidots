import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"
import "components"

/** Overlay de notificaciones por pantalla; sólo aparece en el monitor enfocado.
 * Las tarjetas dejan pasar los clics fuera de sus límites y la pill conserva su morph de notificación.
 */
PanelWindow {
    id: win
    required property var modelData

    readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
    readonly property real topGap: 8 * Flags.topGap * s
    readonly property real restH: 38 * s + topGap
    readonly property bool focused: (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "") === (modelData ? modelData.name : "")

    screen: modelData
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell.notiftoast"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; left: true; right: true }
    implicitHeight: modelData ? modelData.height : 1080
    visible: focused

    // máscara de input = sólo el área de las cards (resto click-through)
    mask: toastMask
    Region {
        id: toastMask
        x: col.x
        y: col.y
        width: col.width
        height: col.height
    }

    Column {
        id: col
        anchors.top: parent.top
        anchors.topMargin: win.restH + 8 * s
        anchors.horizontalCenter: parent.horizontalCenter
        width: 340 * s
        spacing: Theme.spacingLg * s

        Repeater {
            model: Notifs.popups
            delegate: NotifCard {
                id: toastCard
                width: col.width
                s: win.s
                compact: true
                opacity: 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.fast
                        easing.type: Motion.easeStandard
                    }
                }
            }
        }
    }
}
