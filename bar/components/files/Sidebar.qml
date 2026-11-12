import QtQuick
import "../../Singletons"
import "PathUtil.js" as PathUtil

// Places and drives column. Leaf component: `places` and `drives` arrive as properties (see
// PlacesData) and a click leaves as navigateTo(path). Unmounted drives are shown dimmed and inert.
Item {
    id: root

    property var places: []        // [{name, path, icon}]
    property var drives: []        // [{name, path, mounted, size}]
    property string currentPath: ""
    signal navigateTo(string path)

    implicitWidth: 180

    Flickable {
        anchors.fill: parent
        contentHeight: column.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: column
            width: parent.width
            spacing: 2
            Text {
                visible: root.places.length > 0
                text: I18n.tr("Lugares")
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall
                color: Qt.alpha(Theme.foreground, Theme.alphaDisabled)
                leftPadding: Theme.spacingXl
                topPadding: Theme.spacingMd
                bottomPadding: Theme.spacingSm
            }
            Repeater {
                model: root.places
                delegate: Row_ {
                    required property var modelData
                    label: I18n.tr(modelData.name)
                    icon: modelData.icon
                    enabledRow: true
                    current: PathUtil.normalize(root.currentPath) === PathUtil.normalize(modelData.path)
                    onActivated: root.navigateTo(modelData.path)
                }
            }
            Text {
                visible: root.drives.length > 0
                text: I18n.tr("Unidades")
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall
                color: Qt.alpha(Theme.foreground, Theme.alphaDisabled)
                leftPadding: Theme.spacingXl
                topPadding: Theme.spacingXl
                bottomPadding: Theme.spacingSm
            }
            Repeater {
                model: root.drives
                delegate: Row_ {
                    required property var modelData
                    label: modelData.name
                    icon: "hard_drive"
                    detail: modelData.mounted ? modelData.size : I18n.tr("No montada")
                    enabledRow: modelData.mounted
                    current: modelData.mounted && PathUtil.normalize(root.currentPath) === PathUtil.normalize(modelData.path)
                    onActivated: root.navigateTo(modelData.path)
                }
            }
        }
    }

    component Row_: Rectangle {
        id: item
        property string label: ""
        property string icon: ""
        property string detail: ""
        property bool enabledRow: true
        property bool current: false
        signal activated()
        width: parent ? parent.width : 0
        height: 34
        radius: Theme.radiusSm
        color: current ? Qt.alpha(Theme.accent, Theme.alphaFaint * 2)
             : (area.containsMouse && enabledRow ? Qt.alpha(Theme.foreground, Theme.alphaFaint) : "transparent")
        opacity: enabledRow ? 1 : Theme.alphaDisabled
        Behavior on color { enabled: !Flags.reduceMotion; ColorAnimation { duration: Motion.fast } }
        Text {
            id: glyph
            x: Theme.spacingXl
            anchors.verticalCenter: parent.verticalCenter
            text: item.icon
            font.family: "Material Symbols Rounded"
            font.pixelSize: 20
            color: item.current ? Theme.accent : Qt.alpha(Theme.foreground, Theme.alphaIconSec)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: glyph.x + glyph.width + Theme.spacingMd
            width: parent.width - x - (detailText.visible ? detailText.width + Theme.spacingXl : Theme.spacingMd)
            text: item.label
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.foreground
        }
        Text {
            id: detailText
            visible: item.detail.length > 0
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingMd
            text: item.detail
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeCaption
            color: Qt.alpha(Theme.foreground, Theme.alphaDisabled)
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: item.enabledRow
            cursorShape: Qt.PointingHandCursor
            onClicked: item.activated()
        }
    }
}
