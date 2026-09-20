import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"
import "components"

/**
 * Isla · Toast. Ventana popup top-centre — lo EFÍMERO de la notif (NO morfea la
 * pill: el morph es un panel único atado al click/foco; toasts son múltiples y
 * deben poder caer sin robarle la pill). Per-screen via Variants en shell.qml.
 * Sólo el monitor con foco lo muestra (resto visible:false). capa Overlay,
 * namespace quickshell.notiftoast (blurreado en windowRules.conf).
 *
 * Repeater de NotifCard compact dentro de Column. Las transiciones add/remove
 * se manejan vía Behavior on opacity/y del delegate (cero springs, morphCurve).
 * Máscara de input = sólo el bounding de las cards (resto click-through → no
 * bloquea la pill ni ventanas). visible: focused → aunque vacío, sigue dibujado
 * transparente con máscara vacía (cero captura, cero CPU en reposo).
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
