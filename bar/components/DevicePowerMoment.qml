import QtQuick
import "../Singletons"

/**
 * Isla · DevicePowerMoment. Momento corto de corriente en la pill: al enchufar,
 * el rayo de Tidemark se dibuja y el porcentaje rueda (RollingNumber); al
 * desenchufar sólo se ve el porcentaje. Sin tarjeta. Recibe todo por
 * propiedades; `exposure` (0..1) sirve a la composición para ceder el
 * contenido de reposo mientras dura.
 */
Item {
    id: root
    property real s: 1
    property real coreH: 38
    property bool shown: false
    property bool charging: false
    property int percent: 0
    readonly property real exposure: shown ? 1 : 0
    readonly property alias glyph: glyph

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    width: row.width
    height: coreH * 0.48
    opacity: shown ? 1 : 0
    visible: opacity > 0.01
    scale: shown ? 1 : 0.94
    Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
    Behavior on scale { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingMd * root.s
        BatteryIndicator {
            id: glyph
            objectName: "devicePowerGlyph"
            anchors.verticalCenter: parent.verticalCenter
            s: root.s
            level: root.percent / 100
            charging: root.shown && root.charging
        }
        RollingNumber {
            objectName: "devicePowerNumber"
            anchors.verticalCenter: parent.verticalCenter
            value: root.percent
            suffix: "%"
            color: glyph.tint
            font.family: Theme.font
            font.features: Theme.fontNumeric
            font.pixelSize: Theme.fontSizeBodyLg * root.s
            font.weight: Font.DemiBold
            suffixFont: font
            alignment: Qt.AlignRight
        }
    }
}
