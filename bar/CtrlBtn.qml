import QtQuick
import "Singletons"
import "components"

// Fixed circular hit target; visual body compresses independently.
Item {
    id: root
    property string glyph: ""
    property string iconName: ""
    property string accessibleName: iconName.length > 0 ? iconName : glyph
    property bool active: false
    property bool primary: false
    property bool dim: false
    property real s: 1
    property int size: 40
    property real iconSize: Math.round(size * 0.52)
    signal clicked()

    width: size * s
    height: size * s
    opacity: dim ? 0.32 : 1
    activeFocusOnTab: !dim
    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName
    property bool keyboardDown: false
    enabled: !dim
    Keys.onPressed: event => {
        if (event.isAutoRepeat || (event.key !== Qt.Key_Space && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)) return
        keyboardDown = true; event.accepted = true
    }
    Keys.onReleased: event => {
        if (event.isAutoRepeat || !keyboardDown || (event.key !== Qt.Key_Space && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)) return
        keyboardDown = false; root.clicked(); event.accepted = true
    }
    onActiveFocusChanged: if (!activeFocus) keyboardDown = false
    onEnabledChanged: if (!enabled) keyboardDown = false
    Behavior on opacity { NumberAnimation { duration: Motion.hover } }

    InteractionMotion {
        id: response
        hovered: hover.containsMouse; pressed: root.keyboardDown || (hover.pressed && hover.containsMouse)
        focused: root.activeFocus; enabled: !root.dim; extent: root.size
    }
    readonly property real diam: size * s

    Rectangle {
        anchors.centerIn: parent
        width: root.diam
        height: root.diam
        radius: height / 2
        color: root.primary ? Qt.alpha(Theme.foreground, hover.containsMouse ? 1 : 0.90) : root.active
               ? Qt.alpha(Theme.accent, hover.containsMouse ? 0.88 : 0.72)
               : (hover.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaGlow) : "transparent")
        border.color: root.active ? Qt.alpha(Theme.accentSoft, Theme.alphaCritical)
                                  : Qt.alpha(Theme.foreground, hover.containsMouse ? 0.35 : 0.0)
        border.width: Theme.borderHairline
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Theme.accent
            border.width: Theme.borderHairline
            visible: root.activeFocus
        }
        scale: response.visualScale
        transformOrigin: Item.Center
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

        MaterialIcon {
            anchors.centerIn: parent
            iconName: root.iconName
            fill: 1
            transport: true
            visible: root.iconName.length > 0
            interaction: response
            hovered: response.engaged
            pressed: response.pressed
            color: root.primary ? Theme.background : root.active ? Theme.iconOnAccent
                               : (hover.containsMouse ? Theme.foreground : Qt.alpha(Theme.foreground, Theme.alphaIconSec))
            font.pixelSize: root.iconSize * root.s
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
        Text {
            anchors.centerIn: parent
            text: root.glyph
            visible: root.iconName.length === 0
            color: root.primary ? Theme.background : root.active ? Theme.iconOnAccent
                               : (hover.containsMouse ? Theme.foreground : Qt.alpha(Theme.foreground, Theme.alphaIconSec))
            font.family: Theme.fontMono
            font.pixelSize: root.iconSize * root.s
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.dim ? Qt.ArrowCursor : Qt.PointingHandCursor
        enabled: !root.dim
        onClicked: if (!root.dim) root.clicked()
    }
}
