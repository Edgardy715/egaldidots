import QtQuick
import "../Singletons"
import "../"

/**
 * Isla · VolumeChip. Chip efímero de volumen/mic/brillo (Dynamic Island) con
 * glyph + anillo de progreso + porcentaje. Auto-hide tras 1.2s. Extraído de
 * Pill.qml (monolito → components/).
 *
 * Uso:
 *   VolumeChip {
 *       id: volChip
 *       s: pill.s; coreH: pill.coreH
 *   }
 *   volChip.showVolume(p, muted) / volChip.showMic(p, muted) / volChip.showBrightness(p)
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
    property real progress: 0
    property bool isMuted: false
    property string kind: "volume" // "volume" | "mic" | "brightness"

    readonly property real pad: 8 * s
    readonly property real dialD: Math.max(14 * s, coreH * 0.48 - 2 * s)
    readonly property real pctW: 34 * s
    readonly property real airR: 8 * s
    readonly property real chipW: pad + dialD + 4*s + pctW + pad + airR

    width: shown ? chipW : 0

    Behavior on width { Anim { type: Anim.Morph } }
    Behavior on opacity { Anim { type: Anim.Morph } }

    Timer {
        id: volChipHide
        interval: 1200
        onTriggered: root.shown = false
    }

    function showVolume(progress, muted) {
        root.kind = "volume"
        root.progress = muted ? 0 : progress
        root.isMuted = muted
        root.shown = true
        volChipHide.restart()
    }

    function showMic(progress, muted) {
        root.kind = "mic"
        root.progress = muted ? 0 : progress
        root.isMuted = muted
        root.shown = true
        volChipHide.restart()
    }

    function showBrightness(progress) {
        root.kind = "brightness"
        root.progress = progress
        root.isMuted = false
        root.shown = true
        volChipHide.restart()
    }

    function glyph() {
        switch (root.kind) {
        case "brightness":
            return Icons.iBrightness
        case "mic":
            return Icons.getMicVolumeIcon(root.progress, root.isMuted)
        default:
            return Icons.getVolumeIcon(root.progress, root.isMuted)
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.rightMargin: root.airR
        radius: height / 2
        color: Qt.alpha(Theme.accent, Theme.alphaWash)
        border.color: Qt.alpha(Theme.accent, Theme.alphaSelected)
        border.width: Theme.borderHairline

        Row {
            anchors.fill: parent
            anchors.leftMargin: root.pad
            spacing: Theme.spacingSm * root.s

            LevelDial {
                id: dial
                anchors.verticalCenter: parent.verticalCenter
                diameter: root.dialD
                kind: root.kind
                level: root.progress
                muted: root.isMuted
                iconName: root.glyph()
            }

            // Cada paso de volumen gira sólo los dígitos que cambian (odómetro).
            RollingNumber {
                anchors.verticalCenter: parent.verticalCenter
                value: Math.round(Math.max(0, Math.min(1, dial.level)) * 100)
                suffix: "%"
                alignment: Qt.AlignLeft
                color: Theme.accent
                font.family: Theme.font
                font.features: Theme.fontNumeric
                font.pixelSize: Theme.fontSizeLabel * root.s
                font.weight: Font.DemiBold
            }
        }
    }
}
