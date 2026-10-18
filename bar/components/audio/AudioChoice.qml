pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import "../../Singletons"
import ".."

ComboBox {
    id: root
    property real s: 1
    property var options: []
    property string selectedValue: ""
    property Item popupBounds: null
    property string label: ""
    signal chosen(string value)
    signal menuOpened(var menu)
    model: options
    textRole: "description"
    valueRole: "name"
    implicitHeight: Math.max(36 * s, Theme.fontSizeBody * s + 18 * s)
    implicitWidth: 200 * s
    currentIndex: options.findIndex(option => String(option.name) === selectedValue)
    hoverEnabled: true
    Accessible.name: label
    onActivated: index => {
        chosen(String(options[index].name))
        currentIndex = Qt.binding(() => root.options.findIndex(option => String(option.name) === root.selectedValue))
    }
    onVisibleChanged: if (!visible) popup.close()
    onEnabledChanged: if (!enabled) popup.close()
    contentItem: Text {
        text: root.displayText || qsTr("No disponible")
        font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s
        color: root.enabled ? Theme.foreground : Theme.iconSecondary
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        leftPadding: 12 * root.s; rightPadding: 34 * root.s
    }
    indicator: MaterialIcon {
        x: root.width - width - 10 * root.s; y: (root.height - height) / 2
        width: 16 * root.s; height: width
        iconName: "expand_more"; font.pixelSize: 16 * root.s
        hovered: root.hovered || root.activeFocus
        color: Theme.iconSecondary
        rotation: root.popup.visible && !Flags.reduceMotion ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Motion.standardSmall; easing.type: Easing.OutCubic } }
    }
    background: Rectangle {
        radius: 10 * root.s
        color: Qt.alpha(Theme.foreground, root.hovered || root.popup.visible ? Theme.alphaWash : Theme.alphaFaint)
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? Theme.accent : Theme.hair
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }
    delegate: ItemDelegate {
        id: option
        required property int index
        required property var modelData
        width: ListView.view.width
        implicitHeight: Math.max(40 * root.s, caption.implicitHeight + 16 * root.s)
        enabled: modelData.available !== false && modelData.available !== "no"
        highlighted: root.highlightedIndex === index
        hoverEnabled: true
        contentItem: Text {
            id: caption
            text: option.modelData.description + (option.enabled ? "" : qsTr(" · No disponible"))
            font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s
            color: option.enabled ? Theme.foreground : Theme.iconSecondary
            elide: Text.ElideRight
            leftPadding: 8 * root.s; rightPadding: 26 * root.s
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 8 * root.s
            color: Qt.alpha(Theme.foreground, option.highlighted || option.hovered ? Theme.alphaWash : 0)
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
        MaterialIcon {
            anchors.right: parent.right; anchors.rightMargin: 8 * root.s; anchors.verticalCenter: parent.verticalCenter
            width: 16 * root.s; height: width
            visible: root.currentIndex === option.index
            iconName: "check"; color: Theme.accent; font.pixelSize: 16 * root.s
        }
    }
    popup: Popup {
        parent: Overlay.overlay
        popupType: Popup.Item
        focus: true
        padding: 6 * root.s
        width: root.width
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onAboutToShow: {
            root.menuOpened(root.popup)
            const anchor = root.mapToItem(parent, 0, 0)
            const bounds = root.popupBounds || root.Window.contentItem
            const top = bounds.mapToItem(parent, 0, 0).y + 8
            const bottom = bounds.mapToItem(parent, 0, bounds.height).y - 8
            const below = Math.max(0, bottom - anchor.y - root.height - 4)
            const above = Math.max(0, anchor.y - top - 4)
            const down = below >= Math.min(220 * root.s, above)
            height = Math.max(0, Math.min(280 * root.s, root.count * 42 * root.s + padding * 2, down ? below : above))
            x = anchor.x; y = down ? anchor.y + root.height + 4 : anchor.y - height - 4
            choices.positionViewAtIndex(Math.max(0, root.currentIndex), ListView.Contain)
        }
        contentItem: ListView {
            id: choices
            clip: true; model: root.delegateModel
            currentIndex: root.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
        }
        background: Rectangle { color: Theme.surfaceContainer; radius: 12 * root.s; border.width: 1; border.color: Theme.hair }
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Flags.reduceMotion ? 0 : Motion.fast }
            NumberAnimation { property: "scale"; from: Flags.reduceMotion ? 1 : 0.98; to: 1; duration: Motion.standardSmall; easing.type: Easing.OutCubic }
        }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Flags.reduceMotion ? 0 : Motion.fast } }
    }
}
