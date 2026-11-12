import QtQuick
import "../components" as Components
import "../Singletons"

// Control segmentado plano: la selección es una pastilla que viaja con goma
// entre opciones y un punto de acento bajo la etiqueta.
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
    // Pastilla con dos bordes de muelle: el que va delante es rígido y llega
    // primero (~130 ms), el de atrás es blando y lo sigue (~290 ms), así que se
    // estira al viajar y se recoge al llegar. Los muelles conservan la velocidad:
    // clics rápidos seguidos encadenan el viaje sin frenazos.
    Rectangle {
        id: lozenge
        readonly property Item chip: group.selectedChip
        readonly property real targetLeft: chip ? flow.x + chip.x : 0
        readonly property real targetRight: chip ? flow.x + chip.x + chip.width : 0
        readonly property real targetTop: chip ? flow.y + chip.y : 0
        readonly property real targetBottom: chip ? flow.y + chip.y + chip.height : 0
        readonly property bool still: !group.placed || !group.visible || Flags.reduceMotion
        property bool towardRight: true
        property bool towardDown: true
        // Borde delantero rígido, trasero blando (ω en rad/s).
        readonly property real leadOmega: 30
        readonly property real trailOmega: 14
        // Decide qué borde lidera antes de mover los bordes.
        function retarget() {
            towardRight = targetLeft + targetRight >= edgeL.value + edgeR.value
            towardDown = targetTop + targetBottom >= edgeT.value + edgeB.value
            edgeL.target = targetLeft; edgeR.target = targetRight
            edgeT.target = targetTop; edgeB.target = targetBottom
        }
        onTargetLeftChanged: retarget()
        onTargetRightChanged: retarget()
        onTargetTopChanged: retarget()
        onTargetBottomChanged: retarget()
        Component.onCompleted: retarget()
        KitSpring { id: edgeL; animate: !lozenge.still; omega: lozenge.towardRight ? lozenge.trailOmega : lozenge.leadOmega; zeta: lozenge.towardRight ? 0.85 : 1 }
        KitSpring { id: edgeR; animate: !lozenge.still; omega: lozenge.towardRight ? lozenge.leadOmega : lozenge.trailOmega; zeta: lozenge.towardRight ? 1 : 0.85 }
        KitSpring { id: edgeT; animate: !lozenge.still; omega: lozenge.towardDown ? lozenge.trailOmega : lozenge.leadOmega; zeta: lozenge.towardDown ? 0.85 : 1 }
        KitSpring { id: edgeB; animate: !lozenge.still; omega: lozenge.towardDown ? lozenge.leadOmega : lozenge.trailOmega; zeta: lozenge.towardDown ? 1 : 0.85 }
        x: edgeL.value
        y: edgeT.value
        width: Math.max(0, edgeR.value - edgeL.value)
        height: Math.max(0, edgeB.value - edgeT.value)
        radius: 11
        color: Theme.dark ? Qt.alpha(Theme.foreground, 0.16) : "#ffffff"
        opacity: chip ? (group.editable ? 1 : 0.5) : 0
        Behavior on opacity { enabled: group.visible; NumberAnimation { duration: Motion.fast } }
        // La gota marca la elección; se estira con el vidrio al viajar.
        MercuryBead {
            id: dot
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 4
            width: Math.min(parent.width * 0.7, 12 + Math.max(0, parent.width - (lozenge.chip ? lozenge.chip.width : parent.width)) * 0.9)
            height: 5
            border.width: 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: dot.inkAlt }
                GradientStop { position: 1; color: dot.ink }
            }
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
                    // Sólo con teclado: tras un clic no queda un aro de foco.
                    border.width: choice.visualFocus ? 2 : 0
                    border.color: Theme.accent
                    Behavior on color { enabled: group.visible; ColorAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
                }
                // La escala del contentItem es de MotionButton (pulsación); el rebote
                // va en la etiqueta interior para que no se peleen.
                contentItem: Item {
                    implicitWidth: choiceLabel.implicitWidth
                    implicitHeight: choiceLabel.implicitHeight
                    Text {
                        id: choiceLabel
                        anchors.fill: parent
                        text: choice.text
                        font: choice.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: choice.selected ? Theme.foreground : Qt.alpha(Theme.foreground, 0.62)
                        Behavior on color { enabled: group.visible; ColorAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                        // Pop al elegir: la etiqueta se encoge un instante y rebota.
                        scale: 1
                        Connections {
                            target: choice
                            function onSelectedChanged() { if (choice.selected && group.placed && group.visible && !Flags.reduceMotion) pop.restart() }
                        }
                        SequentialAnimation {
                            id: pop
                            // Espera a que llegue el borde delantero de la pastilla.
                            PauseAnimation { duration: 70 }
                            NumberAnimation { target: choiceLabel; property: "scale"; to: 0.93; duration: 90; easing.type: Easing.OutQuad }
                            NumberAnimation { target: choiceLabel; property: "scale"; to: 1; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
                        }
                    }
                }
            }
        }
    }
}
