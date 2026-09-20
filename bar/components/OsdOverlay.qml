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
    property bool shown: false

    // tamaño y posición
    width: 220 * s
    height: 36 * s
    radius: height / 2
    color: Qt.rgba(Theme.cardTop.r, Theme.cardTop.g, Theme.cardTop.b, 0.85)
    border.width: Theme.borderHairline
    border.color: Theme.border

    visible: opacity > 0.01
    opacity: shown ? 1 : 0
    scale: shown ? 1.0 : 0.92
    Behavior on opacity {
        Anim { type: Anim.FastEffects }
    }
    Behavior on scale {
        Anim { type: Anim.FastEffects }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12 * s
        anchors.rightMargin: 12 * s
        spacing: Theme.spacingMd * s

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            iconName: overlay.glyph
            color: Theme.accent
            font.pixelSize: Theme.fontSizeTitle * s
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: overlay.kind === "volume" ? "Volume" : (overlay.kind === "mic" ? "Mic" : "Brillo")
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeSmall * s
        }
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 90 * s
            height: 6 * s
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.12)
            }
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(1, overlay.value))
                radius: height / 2
                color: Theme.accent
                Behavior on width {
                    Anim { type: Anim.FastEffects }
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(overlay.value * 100) + "%"
            color: Theme.accent
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall * s
            font.weight: Font.DemiBold
        }
    }

    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: overlay.shown = false
    }

    function show(kind, v, s) {
        overlay.kind = kind
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
        overlay.shown = true
        overlay.s = s || 1
        hideTimer.restart()
    }
    function showVolume(s) {
        var sink = Pipewire.defaultAudioSink
        if (sink && sink.audio) show("volume", sink.audio.muted ? 0 : sink.audio.volume, s)
    }
    function showBrightness(s) {
        if (typeof Brightness !== "undefined" && Brightness.available)
            show("brightness", Brightness.percent / 100, s)
    }
}
