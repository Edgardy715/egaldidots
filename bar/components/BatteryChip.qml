import QtQuick
import "../Singletons"
import "../"

/**
 * Isla · BatteryChip. Chip efímero de batería (Dynamic Island). Aparece al
 * conectar/desconectar cargador o batería baja. Auto-hide 3s. Extraído de
 * Pill.qml (monolito → components/).
 *
 * Uso:
 *   BatteryChip {
 *       id: batChip
 *       s: pill.s; coreH: pill.coreH
 *   }
 *   batChip.show(percent, status)
 */
Item {
    id: root
    property real s: 1
    property real coreH: 38

    anchors.verticalCenter: parent.verticalCenter
    height: coreH * 0.48
    opacity: shown ? 1 : 0
    visible: opacity > 0.01
    clip: true

    property bool shown: false
    property int percent: 0
    property string status: ""

    readonly property real pad: 8 * s
    readonly property real glyphW: 27 * s
    readonly property real pctW: 34 * s
    readonly property real airR: 8 * s
    readonly property real chipW: pad + glyphW + 4*s + pctW + pad + airR

    width: shown ? chipW : 0

    Behavior on width { Anim { type: Anim.Morph } }
    Behavior on opacity { Anim { type: Anim.Morph } }

    Timer { id: batChipHide; interval: 3000; onTriggered: root.shown = false }

    function show(percent, status) {
        root.percent = percent
        root.status = status
        root.shown = true
        batChipHide.restart()
    }

    Rectangle {
        anchors.fill: parent
        anchors.rightMargin: root.airR
        radius: height / 2
        color: Qt.alpha(batteryGlyph.tint, Theme.alphaWash)
        border.color: Qt.alpha(batteryGlyph.tint, Theme.alphaSelected)
        border.width: Theme.borderHairline

        Row {
            anchors.fill: parent
            anchors.leftMargin: root.pad
            spacing: Theme.spacingSm * root.s
            BatteryIndicator {
                id: batteryGlyph
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                level: root.percent / 100
                charging: root.status === "charging"
                chargePaused: root.status === "paused"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.percent + "%"
                color: batteryGlyph.tint
                font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel * root.s
                font.weight: Font.DemiBold
            }
        }
    }
}
