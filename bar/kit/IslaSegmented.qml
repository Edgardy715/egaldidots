import QtQuick
import "../components" as Components
import "../Singletons"

// Control segmentado Quicksilver: canal hundido; la opción elegida se eleva
// como vidrio y una gota de cinabrio viaja debajo de su etiqueta.
Item {
    id: group
    property var options: []
    property var optionLabels: null
    property var current
    property bool editable: true
    // En línea el Flow no puede deducir su ancho del implícito (los apila en columna).
    property bool inline: false
    property string label: ""
    property string description: ""
    signal chosen(var value)

    property alias choices: repeater
    implicitHeight: flow.implicitHeight + 8
    implicitWidth: (inline ? rowWidth : flow.implicitWidth) + 8
    readonly property int selectedIndex: (options || []).indexOf(current)
    // itemAt() no notifica: la revisión obliga a releerlo cuando el Repeater crea o retira chips.
    property int chipRevision: 0
    readonly property Item selectedChip: chipRevision >= 0 && selectedIndex >= 0 ? repeater.itemAt(selectedIndex) : null
    property bool placed: false
    // Suma exacta de las opciones para que quepan en una fila.
    readonly property real rowWidth: {
        let width = 0
        for (let i = 0; chipRevision >= 0 && i < repeater.count; i++) {
            const chip = repeater.itemAt(i)
            if (chip) width += chip.implicitWidth + (i > 0 ? 4 : 0)
        }
        return width
    }
    Timer { interval: 60; running: true; onTriggered: group.placed = true }
    MercuryChannel {
        width: Math.min(parent.width, flow.childrenRect.width + 8)
        height: parent.height
        radius: 15
        opacity: group.editable ? 1 : 0.5
    }
    Components.LiquidSelection {
        id: lozenge
        readonly property Item chip: group.selectedChip
        targetX: chip ? flow.x + chip.x : 0
        targetY: chip ? flow.y + chip.y : 0
        targetWidth: chip ? chip.width : 0
        targetHeight: chip ? chip.height : 0
        immediate: !group.placed || !group.visible
        radius: 11
        color: Qt.alpha(Theme.foreground, Theme.dark ? 0.10 : 0.06)
        border.width: 1
        border.color: Qt.alpha(Theme.foreground, Theme.dark ? 0.10 : 0.12)
        opacity: chip ? (group.editable ? 1 : 0.5) : 0
        Behavior on opacity { enabled: group.visible; NumberAnimation { duration: Motion.fast } }
        // Luz cenital del vidrio elevado.
        Rectangle {
            x: parent.radius * 0.7; y: 1
            width: Math.max(0, parent.width - 2 * x); height: 1
            color: Qt.alpha("#ffffff", Theme.dark ? 0.16 : 0.5)
        }
        // La gota marca la elección; se estira con el vidrio al viajar.
        MercuryBead {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 4
            width: Math.min(parent.width * 0.5, 12 + Math.max(0, parent.width - (lozenge.chip ? lozenge.chip.width : parent.width)) * 0.5)
            height: 5
            tintAmount: 1
            glint: 0.7
            border.width: 0
        }
    }
    Flow {
        id: flow
        x: 4; y: 4
        width: group.inline ? group.rowWidth : parent.width - 8
        spacing: 4
        Repeater {
            id: repeater
            model: group.options || []
            onItemAdded: group.chipRevision++
            onItemRemoved: group.chipRevision++
            Components.MotionButton {
                id: choice
                required property string modelData
                required property int index
                readonly property bool selected: group.current === choice.modelData
                objectName: "choice-" + modelData
                text: group.optionLabels ? I18n.tr(group.optionLabels[index]) : modelData
                checkable: false
                checked: selected
                enabled: group.editable
                implicitHeight: Math.max(36, Theme.fontSizeBodyLg * 1.5 + 14)
                implicitWidth: choiceLabel.implicitWidth + 32
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.fontSizeBodyLg
                Accessible.name: I18n.tr(group.label) + ": " + text
                Accessible.role: Accessible.RadioButton
                Accessible.checkable: true
                Accessible.checked: selected
                Accessible.description: I18n.tr(group.description || "")
                onClicked: group.chosen(choice.modelData)
                background: Rectangle {
                    radius: 11
                    color: !choice.selected && choice.hovered ? Qt.alpha(Theme.foreground, 0.07) : "transparent"
                    border.width: choice.activeFocus ? 2 : 0
                    border.color: Theme.accent
                    Behavior on color { enabled: group.visible; ColorAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
                }
                contentItem: Text {
                    id: choiceLabel
                    text: choice.text
                    font: choice.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: choice.selected ? Theme.foreground : Qt.alpha(Theme.foreground, 0.62)
                    Behavior on color { enabled: group.visible; ColorAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                }
            }
        }
    }
}
