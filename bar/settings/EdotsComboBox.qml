import QtQuick
import QtQuick.Controls.Basic
import "../components"
import "../Singletons"

// Native ComboBox owns editing, completion, keyboard navigation and activation.
ComboBox {
    id: root
    property string configuredText: ""
    property bool invalid: false
    property Item popupBounds: null
    readonly property bool motionActive: visible && (!Window.window || Window.window.visible)
    readonly property real optionHeight: Math.max(42, Theme.fontSizeBodyLg * 1.5 + 16)
    signal textEdited(string text)
    signal editingFinished(string text)
    objectName: "fontPicker"
    implicitHeight: Math.max(44, Theme.fontSizeBodyLg * 1.5 + 20)
    editable: true
    selectTextByMouse: true
    hoverEnabled: true
    leftPadding: 14; rightPadding: 44
    font.family: Config.appearance.fontFamily
    font.pixelSize: Theme.fontSizeBodyLg
    model: Qt.fontFamilies()
    focusPolicy: Qt.StrongFocus

    function syncText() {
        if (editText === configuredText) return
        currentIndex = model.indexOf(configuredText)
        editText = configuredText
    }
    onConfiguredTextChanged: Qt.callLater(syncText)
    Component.onCompleted: Qt.callLater(syncText)
    onVisibleChanged: if (!visible) popup.close()
    onEnabledChanged: if (!enabled) popup.close()
    Shortcut {
        sequence: "Alt+Down"
        enabled: root.enabled && root.visible && (root.activeFocus || editor.activeFocus)
        onActivated: root.popup.open()
    }

    contentItem: EdotsTextField {
        id: editor
        chrome: false
        leftPadding: 0; rightPadding: 0
        text: root.editText
        enabled: root.editable
        readOnly: root.down
        font: root.font
        onTextEdited: root.textEdited(text)
        onEditingFinished: Qt.callLater(function() {
            // Opening the menu transfers focus; it must not commit the old value.
            if (!root.popup.visible) root.editingFinished(root.editText)
        })
    }
    indicator: Item {
        x: root.width - width - 6
        width: 34; height: 34
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            anchors.fill: parent; radius: 9
            color: Qt.alpha(Theme.foreground, 0.07)
            opacity: root.hovered || root.popup.visible ? 1 : 0
            Behavior on opacity { enabled: root.motionActive; NumberAnimation { duration: Motion.hover } }
        }
        EdotsIcon {
            anchors.centerIn: parent
            iconName: "expand_more"; font.pixelSize: Theme.fontSizeHead; color: Theme.foreground
            controlHovered: root.hovered || root.activeFocus
            selected: root.popup.visible
            rotation: Flags.reduceMotion ? 0 : root.popup.visible ? 180 : 0
            Behavior on rotation { enabled: root.motionActive && !Flags.reduceMotion; SmoothedAnimation { duration: Motion.standardSmall; velocity: -1 } }
            Accessible.ignored: true
        }
    }
    background: Rectangle {
        radius: 12
        color: Qt.alpha(Theme.foreground, root.popup.visible || editor.activeFocus ? 0.085 : root.hovered ? 0.065 : 0.035)
        border.width: 1
        border.color: root.invalid ? Theme.error : root.popup.visible || root.activeFocus ? Theme.accent : Qt.alpha(Theme.foreground, 0.12)
        opacity: root.enabled ? 1 : 0.45
        Behavior on color { enabled: root.motionActive; ColorAnimation { duration: Motion.hover } }
        Behavior on border.color { enabled: root.motionActive; ColorAnimation { duration: Motion.hover } }
        Behavior on opacity { enabled: root.motionActive; NumberAnimation { duration: Motion.fast } }
        Rectangle {
            anchors.fill: parent; anchors.margins: -2
            color: "transparent"; radius: parent.radius + 2
            border.width: 2; border.color: root.invalid ? Theme.error : Theme.accent
            opacity: root.activeFocus || editor.activeFocus ? 0.65 : 0
            Behavior on opacity { enabled: root.motionActive; NumberAnimation { duration: Motion.hover } }
        }
    }
    delegate: ItemDelegate {
        id: option
        required property int index
        required property var modelData
        width: ListView.view.width
        implicitHeight: root.optionHeight
        leftPadding: 14; rightPadding: 40
        highlighted: root.highlightedIndex === index
        hoverEnabled: true
        contentItem: Text {
            text: option.modelData; font.family: option.modelData; font.pixelSize: Theme.fontSizeBodyLg
            color: Theme.foreground; elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 8
            color: Qt.alpha(Theme.foreground, option.highlighted ? 0.10 : option.hovered ? 0.055 : 0)
            Behavior on color { enabled: root.popup.visible; ColorAnimation { duration: Motion.hover } }
        }
        EdotsIcon {
            anchors.right: parent.right; anchors.rightMargin: 13; anchors.verticalCenter: parent.verticalCenter
            visible: root.currentIndex === option.index
            iconName: "check"; font.pixelSize: Theme.fontSizeTitleLg; color: Theme.foreground
            controlHovered: option.hovered; selected: option.highlighted
            Accessible.ignored: true
        }
        Accessible.name: String(modelData)
    }
    popup: Popup {
        id: menu
        parent: Overlay.overlay
        popupType: Popup.Item
        width: root.width
        padding: 8
        margins: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onAboutToShow: {
            const anchor = root.mapToItem(parent, 0, 0)
            const bounds = root.popupBounds || root.Window.contentItem
            const top = bounds ? bounds.mapToItem(parent, 0, 0).y + 12 : 12
            const bottom = bounds ? bounds.mapToItem(parent, 0, bounds.height).y - 12 : root.Window.height - 12
            const below = Math.max(0, bottom - anchor.y - root.height - 6)
            const above = Math.max(0, anchor.y - top - 6)
            const down = below >= Math.min(240, above)
            height = Math.min(280, root.count * root.optionHeight + 16, down ? below : above)
            x = anchor.x
            y = down ? anchor.y + root.height + 6 : anchor.y - height - 6
            list.positionViewAtIndex(Math.max(0, root.currentIndex), ListView.Contain)
        }
        contentItem: ListView {
            id: list
            objectName: "fontOptions"
            clip: true
            model: root.delegateModel
            currentIndex: root.highlightedIndex
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }
        background: Rectangle {
            radius: 15
            color: Theme.surfaceContainer
            border.width: 1; border.color: Qt.alpha(Theme.foreground, 0.18)
        }
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.fast }
                NumberAnimation { property: "scale"; from: Flags.reduceMotion ? 1 : 0.98; to: 1; duration: Motion.standardSmall; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: Motion.hover }
                NumberAnimation { property: "scale"; to: Flags.reduceMotion ? 1 : 0.985; duration: Motion.hover; easing.type: Easing.OutCubic }
            }
        }
    }
}
