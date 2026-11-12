import QtQuick
import "../Singletons"
import "../"
import Quickshell.Services.Pipewire

/**
 * Isla · OsdOverlay. Barra de feedback OSD (volumen/brillo/mic) que aparece 1.2s
 * bajo la pill cuando cambia alguno. Solía ser un componente inline de Pill.qml;
 * extraído a components/ para reducir el monolito.
 *
 * Uso:
 *   OsdOverlay {
 *       id: osd
 *       anchors.top: parent.bottom
 *       anchors.horizontalCenter: parent.horizontalCenter
 *   }
 *   osd.showVolume(s)      / osd.showBrightness(s) / osd.showMic(...)
 */
Rectangle {
    id: overlay
    property real s: 1
    property real value: 0
    property string kind: ""      // "volume" | "brightness" | "mic"
    property string glyph: ""
    property bool muted: false
    property bool shown: false

    // tamaño y posición
    width: 168 * s
    height: 36 * s
    radius: height / 2
    color: Qt.rgba(Theme.cardTop.r, Theme.cardTop.g, Theme.cardTop.b, 0.85)
    border.width: Theme.borderHairline
    border.color: Theme.border

    visible: opacity > 0.01
    opacity: shown ? 1 : 0
    scale: Flags.reduceMotion ? 1 : shown ? 1.0 : 0.92
    transformOrigin: Item.Top
    Behavior on opacity {
        Anim { type: overlay.shown ? Anim.FastIn : Anim.FastOut }
    }
    Behavior on scale {
        Anim { type: overlay.shown ? Anim.FastIn : Anim.FastOut }
    }

    InnerGlow {
        anchors.fill: parent
        focusX: 0.42 + overlay.value * 0.40
        focusY: 0.78
        opacity: 0.65
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12 * s
        anchors.rightMargin: 12 * s
        spacing: Theme.spacingMd * s

        LevelDial {
            id: dial
            anchors.verticalCenter: parent.verticalCenter
            diameter: parent.height - 6 * s
            kind: overlay.kind
            level: overlay.value
            muted: overlay.muted
            iconName: overlay.glyph
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: overlay.kind === "volume" ? I18n.tr("Volumen") : (overlay.kind === "mic" ? I18n.tr("Micrófono") : I18n.tr("Brillo"))
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeSmall * s
        }
        RollingNumber {
            anchors.verticalCenter: parent.verticalCenter
            value: Math.round(Math.max(0, Math.min(1, dial.level)) * 100)
            suffix: "%"
            alignment: Qt.AlignLeft
            color: Theme.accent
            font.family: Theme.font
            font.features: Theme.fontNumeric
            font.pixelSize: Theme.fontSizeSmall * s
            font.weight: Font.DemiBold
        }
    }

    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: overlay.shown = false
    }

    function show(kind, v, s, muted) {
        overlay.kind = kind
        overlay.muted = !!muted
        overlay.value = v
        switch (kind) {
        case "brightness":
            overlay.glyph = Icons.iBrightness
            break
        case "mic":
            overlay.glyph = Icons.getMicVolumeIcon(v, v < 0.01)
            break
        default:
            overlay.glyph = Icons.getVolumeIcon(v, v < 0.01)
            break
        }
        overlay.s = s || 1
        overlay.shown = true
        hideTimer.restart()
    }
    function showVolume(s) {
        var sink = Pipewire.defaultAudioSink
        if (sink && sink.audio) show("volume", sink.audio.muted ? 0 : sink.audio.volume, s, sink.audio.muted)
    }
    function showBrightness(s) {
        if (typeof Brightness !== "undefined" && Brightness.available)
            show("brightness", Brightness.percent / 100, s)
    }
}
