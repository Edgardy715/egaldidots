import QtQuick
import QtQuick.Controls.Basic

// Native Button owns activation, focus and cancellation; visuals own motion.
Button {
    id: root
    property bool expressive: false
    property alias interaction: response
    hoverEnabled: true
    InteractionMotion {
        id: response
        hovered: root.hovered; pressed: root.down; focused: root.activeFocus
        enabled: root.enabled; expressive: root.expressive
        extent: Math.min(root.width, root.height)
    }
    Binding { target: root.background; property: "scale"; value: response.visualScale; when: root.background !== null }
    Binding { target: root.contentItem; property: "scale"; value: response.visualScale; when: root.contentItem !== null }
}
