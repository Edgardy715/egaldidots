import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../"
import "../components"
import "../Singletons"

/**
 * Isla · MixerSurface. Volumen del sink por defecto (Pipewire): barra táctil +
 * % con mono-font (eco pulseaudio waybar) + mute. Entra con morphCloseness vía
 * PillSurface. Wheel del body ya ajusta inline; aquí es control fino.
 *
 * v2: añade streams per-app (Pipewire.nodes.isStream) — cada app con su propio
 * slider horizontal + mute. Filtra todo lo que tenga application.name en
 * properties (videojuegos / browsers / electron). Inspira en el mixer de
 * caelestia dashboard sin saturar (lista compacta con row por stream).
 */
PillSurface {
    id: root
    mTop: Theme.marginLg; mLeft: Theme.marginLg; mRight: Theme.marginLg; mBottom: Theme.marginLg

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: root.sink ? root.sink.audio : null
    readonly property real vol: root.audio ? root.audio.volume : 0
    readonly property bool muted: root.audio ? root.audio.muted : false
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sourceAudio: root.source ? root.source.audio : null
    readonly property real sourceVol: root.sourceAudio ? root.sourceAudio.volume : 0
    readonly property bool sourceMuted: root.sourceAudio ? root.sourceAudio.muted : false

    /** streams de Pipewire con application.name (output audio apps).
     *  Derivado reactivo de Pipewire.nodes — se re-evalúa cuando el listado cambia.
     *  PATRÓN caelestia: iterar Pipewire.nodes.values (el model no se indexa
     *  directamente). OJO: algunos streams (browsers vía portal, ej. Zen/Firefox)
     *  quedan con `ready:false` y `properties` vacías pero SÍ tienen audio y
     *  `name` poblado → usar `n.name` como fallback y NO exigir `ready`. */
    readonly property var appStreams: {
        var nodes = Pipewire.nodes.values
        var out = []
        if (!nodes) return out
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (!n.isStream) continue
            var props = n.properties || {}
            // application.name es la marca de audio apps; media.name cubre clips;
            // n.name cubre streams sin properties (Zen/Firefox via portal)
            var appName = props["application.name"] || props["media.name"] || n.description || n.name || ""
            if (!appName || appName === "Unknown") continue
            // sólo streams con audio activo
            if (!n.audio) continue
            out.push({ node: n, appName: appName, icon: root.appIconFor(appName) })
        }
        return out
    }

    /** lookup de ícono por app name: match con .desktop entries para ícono real.
     *  Sin fallback → devuelve "" si Quickshell no encuentra nada. */
    function appIconFor(name: string): string {
        var raw = Quickshell.iconPath(name, true)
        if (raw) return Quickshell.iconPath(name)
        return ""
    }

    function clamp01(v) { return Math.max(0, Math.min(1, v)) }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingXl * s

        // header
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingLg * s
            Text {
                text: root.muted ? "Volumen · silenciado" : "Volumen"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeTitle * s
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            Text {
                text: (root.muted ? "M" : "♪")
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBodyLg * s
            }
        }

        // volume bar
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 12 * s
            Rectangle {
                id: track
                anchors.fill: parent
                radius: height / 2
                color: Qt.alpha(Theme.foreground, Theme.alphaSoft)
                border.color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
                border.width: Theme.borderHairline
                Rectangle {
                    width: parent.width * (root.muted ? 0 : root.clamp01(root.vol))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                    Behavior on width { Anim { type: Anim.FastEffects } }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
            onPressed: (m) => { if (root.audio && root.sink.ready) root.audio.volume = root.clamp01(m.x / width) }
            onPositionChanged: (m) => { if (root.audio && root.sink.ready && pressed) root.audio.volume = root.clamp01(m.x / width) }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: Math.round(root.vol * 100) + "%"
                color: Theme.dim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBodyLg * s
            }
            Item { Layout.fillWidth: true }
            Rectangle {  // mute toggle
                Layout.preferredWidth: 64 * s
                Layout.preferredHeight: 26 * s
                radius: height / 2
                // wash al hover sobre el tinte base (acento si silenciado)
                color: root.muted
                       ? (mt.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaMid) : Qt.alpha(Theme.accent, Theme.alphaChip))
                       : (mt.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaWash) : Qt.alpha(Theme.foreground, Theme.alphaFaint))
                border.color: Qt.alpha(Theme.foreground, Theme.alphaSoft)
                border.width: Theme.borderHairline
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                Text {
                    anchors.centerIn: parent
                    text: root.muted ? "Silencio" : "Sonando"
                    color: root.muted ? Theme.accent : Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeSmall * s
                    font.weight: Font.Medium
                }
                MouseArea {
                    id: mt
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.audio && root.sink.ready) root.audio.muted = !root.audio.muted }
                }
            }
        }

        // ---- micrófono ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingLg * s
            Text {
                text: root.sourceMuted ? "Micrófono · silenciado" : "Micrófono"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeTitle * s
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            MaterialIcon {
                iconName: Icons.getMicVolumeIcon(root.sourceVol, root.sourceMuted)
                color: Theme.accent
                font.pixelSize: Theme.fontSizeBodyLg * s
            }
        }

        // mic volume bar
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 12 * s
            Rectangle {
                id: micTrack
                anchors.fill: parent
                radius: height / 2
                color: Qt.alpha(Theme.foreground, Theme.alphaSoft)
                border.color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
                border.width: Theme.borderHairline
                Rectangle {
                    width: parent.width * (root.sourceMuted ? 0 : root.clamp01(root.sourceVol))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                    Behavior on width { Anim { type: Anim.FastEffects } }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: (m) => { if (root.sourceAudio && root.source.ready) root.sourceAudio.volume = root.clamp01(m.x / width) }
                onPositionChanged: (m) => { if (root.sourceAudio && root.source.ready && pressed) root.sourceAudio.volume = root.clamp01(m.x / width) }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: Math.round(root.sourceVol * 100) + "%"
                color: Theme.dim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBodyLg * s
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 64 * s
                Layout.preferredHeight: 26 * s
                radius: height / 2
                color: root.sourceMuted
                       ? (smt.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaMid) : Qt.alpha(Theme.accent, Theme.alphaChip))
                       : (smt.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaWash) : Qt.alpha(Theme.foreground, Theme.alphaFaint))
                border.color: Qt.alpha(Theme.foreground, Theme.alphaSoft)
                border.width: Theme.borderHairline
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                Text {
                    anchors.centerIn: parent
                    text: root.sourceMuted ? "Mudo" : "Activo"
                    color: root.sourceMuted ? Theme.accent : Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeSmall * s
                    font.weight: Font.Medium
                }
                MouseArea {
                    id: smt
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.sourceAudio && root.source.ready) root.sourceAudio.muted = !root.sourceAudio.muted }
                }
            }
        }

        Item { Layout.fillWidth: true; Layout.preferredHeight: 1; visible: root.appStreams.length > 0
            Rectangle { anchors.fill: parent; color: Theme.border; opacity: 0.5 }
        }

        // ---- streams per-app ----
        Repeater {
            model: root.appStreams
            delegate: StaggerItem {
                id: streamItem
                Layout.fillWidth: true
                staggerIndex: index
                entered: root.open
                s: root.s

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingLg * s

                    // app name (truncado)
                    Text {
                        text: modelData.appName
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeLabel * s
                        elide: Text.ElideRight
                        Layout.preferredWidth: 70 * s
                    }

                    // stream slider
                    Slider {
                        Layout.fillWidth: true
                        value: modelData.node.audio.volume
                        height_: 10
                        s: root.s
                        onSliderChanged: (v) => {
                            modelData.node.audio.muted = false
                            modelData.node.audio.volume = v
                        }
                    }

                    // mute button
                    MaterialIcon {
                        iconName: modelData.node.audio.muted ? Icons.iVolOff : Icons.iVolMed
                        color: modelData.node.audio.muted ? Theme.accentStrong : Theme.foreground
                        font.pixelSize: Theme.fontSizeBody * s
                        Layout.preferredWidth: 24 * s
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.node.audio.muted = !modelData.node.audio.muted
                        }
                    }
                }
            }
        }

        // hint cuando no hay streams
        Text {
            Layout.fillWidth: true
            visible: root.appStreams.length === 0
            text: "No hay apps reproduciendo audio."
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeLabel * s
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.6
        }

        Item { Layout.fillHeight: true }
    }
}
