import QtQuick
import "../Singletons"

// Existing MouseArea gestures and grabs are retained. Never transform this item.
MouseArea {
    id: root
    property real feedbackRadius: parent && parent.radius !== undefined ? parent.radius : Theme.radiusSm
    property bool feedbackEnabled: true
    property bool hoverWash: true
    property string accessibleName: ""
    property bool focusOnTab: true
    activeFocusOnTab: focusOnTab && accessibleName.length > 0
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Keys.onPressed: event => {
        if (!enabled || event.isAutoRepeat || (event.key !== Qt.Key_Space && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)) return
        keyboardDown = true
        event.accepted = true
    }
    Keys.onReleased: event => {
        if (event.isAutoRepeat || !keyboardDown || (event.key !== Qt.Key_Space && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)) return
        keyboardDown = false
        if (enabled) clicked(null)
        event.accepted = true
    }
    property bool keyboardDown: false
    onActiveFocusChanged: if (!activeFocus) keyboardDown = false
    onEnabledChanged: if (!enabled) keyboardDown = false
    property alias motion: response
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    InteractionMotion {
        id: response
        hovered: root.containsMouse
        pressed: root.keyboardDown || (root.pressed && root.containsMouse)
        focused: root.activeFocus
        enabled: root.enabled
        extent: Math.min(root.width, root.height)
    }
    Rectangle {
        anchors.fill: parent
        scale: response.visualScale
        radius: root.feedbackRadius
        visible: root.feedbackEnabled
        color: Qt.alpha(Theme.foreground, (root.hoverWash ? 0.035 * response.presence : 0) + 0.065 * response.pressure)
        border.width: root.activeFocus ? Theme.borderHairline : 0
        border.color: Theme.accent
        Accessible.ignored: true
    }
}
