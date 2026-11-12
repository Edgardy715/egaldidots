import QtQuick
import "../Singletons"

/**
 * Isla · DeviceMomentCard. Contenido de la tarjeta de dispositivo que brota bajo
 * la isla (Bluetooth conectado, USB montado). Sólo presenta: recibe datos por
 * propiedades y avisa por señales; el estado y los procesos viven en
 * DeviceMoments.
 */
Item {
    id: root
    property real s: 1
    property real pillWidth: 340
    property real pillHeight: 84
    property real closeness: 1
    // "bluetooth" | "storage"
    property string kind: "bluetooth"
    property string glyph: "bluetooth_audio"
    property string title: ""
    // Texto secundario (tamaño del volumen); vacío para Bluetooth sin batería.
    property string subtitle: ""
    // [{label, level}] con level entre 0 y 1; vacío → «Conectado».
    property var batteries: []
    // "idle" | "ejecting" | "ejected" | "error"
    property string ejectState: "idle"
    property string errorText: ""
    readonly property bool storage: kind === "storage"
    readonly property bool lowBattery: batteries.some(b => b.level < 0.15)
    readonly property alias hovered: hover.hovered
    signal activated()
    signal openRequested()
    signal ejectRequested()
    signal hoverChanged(bool hovered)

    width: pillWidth
    height: pillHeight
    opacity: closeness
    visible: opacity > 0.01
    clip: true

    HoverHandler { id: hover; onHoveredChanged: root.hoverChanged(hovered) }

    // Toda la tarjeta abre Conectividad (Bluetooth); el almacenamiento sólo
    // responde a sus botones.
    MouseArea {
        objectName: "deviceCardArea"
        anchors.fill: parent
        enabled: !root.storage
        cursorShape: root.storage ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingXl * root.s
        spacing: Theme.spacingLg * root.s
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 48 * root.s
            height: 48 * root.s
            radius: width / 2
            color: Qt.alpha(Theme.accent, Theme.alphaSubtle)
            border.color: Qt.alpha(Theme.accent, Theme.alphaCritical)
            border.width: Theme.borderHairlineSoft * root.s
            MaterialIcon {
                anchors.centerIn: parent
                iconName: root.glyph
                color: Theme.accent
                font.pixelSize: Theme.fontSizeIcon * root.s
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXs * root.s
            width: root.pillWidth - (root.storage ? 232 : 100) * root.s
            Text {
                objectName: "deviceCardTitle"
                width: parent.width
                text: root.title
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                objectName: "deviceCardStatus"
                width: parent.width
                visible: text.length > 0
                text: root.ejectState === "error" ? root.errorText
                    : root.ejectState === "ejecting" ? I18n.tr("Expulsando…")
                    : root.storage ? root.subtitle
                    : root.batteries.length ? "" : I18n.tr("Conectado")
                color: root.ejectState === "error" ? Theme.error : Theme.dim
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                elide: Text.ElideRight
            }
            Row {
                objectName: "deviceCardBatteries"
                visible: !root.storage && root.batteries.length > 0
                spacing: Theme.spacingMd * root.s
                Repeater {
                    model: root.storage ? [] : root.batteries
                    delegate: Row {
                        id: cell
                        required property var modelData
                        spacing: Theme.spacingXs * root.s
                        BatteryIndicator {
                            anchors.verticalCenter: parent.verticalCenter
                            s: root.s
                            level: cell.modelData.level
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (cell.modelData.label.length ? cell.modelData.label + " " : "") + Math.round(cell.modelData.level * 100) + "%"
                            color: cell.modelData.level < 0.15 ? Theme.error : Theme.dim
                            font.family: Theme.font
                            font.features: Theme.fontNumeric
                            font.pixelSize: 11 * root.s
                        }
                    }
                }
            }
        }
    }

    // Abrir / Expulsar
    Row {
        visible: root.storage
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingXl * root.s
        spacing: Theme.spacingMd * root.s
        Repeater {
            model: [
                { id: "open", label: I18n.tr("Abrir") },
                { id: "eject", label: I18n.tr("Expulsar") }
            ]
            delegate: Rectangle {
                id: action
                required property var modelData
                readonly property bool busy: modelData.id === "eject" && root.ejectState === "ejecting"
                width: 66 * root.s
                height: 32 * root.s
                radius: height / 2
                opacity: root.ejectState === "ejecting" || root.ejectState === "ejected" ? 0.5 : 1
                color: Qt.alpha(modelData.id === "eject" ? Theme.accent : Theme.foreground, Theme.alphaSoft)
                Text {
                    anchors.centerIn: parent
                    text: action.modelData.label
                    color: action.modelData.id === "eject" ? Theme.accent : Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeLabel * root.s
                    font.weight: Font.Medium
                }
                MotionArea {
                    objectName: "deviceCardAction-" + action.modelData.id
                    anchors.fill: parent
                    enabled: root.ejectState !== "ejecting" && root.ejectState !== "ejected"
                    accessibleName: action.modelData.label
                    onClicked: action.modelData.id === "eject" ? root.ejectRequested() : root.openRequested()
                }
            }
        }
    }
}
