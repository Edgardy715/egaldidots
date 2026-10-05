import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../"
import "../components"
import "../Singletons"

/**
 * Audio del sink, micrófono y streams Pipewire. Los controles comparten Slider
 * y la lista de aplicaciones usa el espacio restante del vidrio.
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
    function setVolume(device, v) {
        if (!device || !device.audio) return
        device.audio.volume = clamp01(v)
        device.audio.muted = false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingLg * s

        // header
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingLg * s
            Text {
                text: "Volumen"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeTitle * s
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            Text {
                text: Math.round(root.vol * 100) + "%"
                color: Theme.foreground
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBodyLg * s
            }
        }

        // volume bar
        Slider {
            Layout.fillWidth: true
            value: root.muted ? 0 : root.clamp01(root.vol)
            s: root.s
            enabled: !!root.sink && root.sink.ready
            activeFocusOnTab: enabled
            Accessible.role: Accessible.Slider
            Accessible.name: qsTr("Volumen de salida")
            Accessible.description: Math.round(root.vol * 100) + "%"
            Accessible.onIncreaseAction: root.setVolume(root.sink, root.vol + 0.05)
            Accessible.onDecreaseAction: root.setVolume(root.sink, root.vol - 0.05)
            Keys.onLeftPressed: root.setVolume(root.sink, root.vol - 0.05)
            Keys.onRightPressed: root.setVolume(root.sink, root.vol + 0.05)
            onSliderChanged: v => root.setVolume(root.sink, v)
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "transparent"
                border.color: Theme.accent
                border.width: parent.activeFocus ? Theme.borderHairline : 0
                Accessible.ignored: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            Rectangle {
  // mute toggle
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

                MotionArea {
                    id: mt
                    anchors.fill: parent
                    enabled: !!root.sink && root.sink.ready
                    accessibleName: qsTr("Alternar silencio del audio")
                    hoverWash: false
                    onClicked: { if (root.audio && root.sink.ready) root.audio.muted = !root.audio.muted }
                }

                AnimatedLabel {
                    scale: mt.motion.visualScale
                    transform: Translate { y: -Motion.labelTravel * mt.motion.presence }
                    anchors.centerIn: parent
                    value: root.muted ? qsTr("Silencio") : qsTr("Sonando")
                    color: root.muted ? Theme.accent : Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeSmall * s
                    font.weight: Font.Medium
                }

            }
        }

        // ---- micrófono ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingLg * s
            Text {
                text: "Micrófono"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeTitle * s
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            Text {
                text: Math.round(root.sourceVol * 100) + "%"
                color: Theme.foreground
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBodyLg * s
            }
        }

        // mic volume bar
        Slider {
            Layout.fillWidth: true
            value: root.sourceMuted ? 0 : root.clamp01(root.sourceVol)
            s: root.s
            enabled: !!root.source && root.source.ready
            activeFocusOnTab: enabled
            Accessible.role: Accessible.Slider
            Accessible.name: qsTr("Volumen del micrófono")
            Accessible.description: Math.round(root.sourceVol * 100) + "%"
            Accessible.onIncreaseAction: root.setVolume(root.source, root.sourceVol + 0.05)
            Accessible.onDecreaseAction: root.setVolume(root.source, root.sourceVol - 0.05)
            Keys.onLeftPressed: root.setVolume(root.source, root.sourceVol - 0.05)
            Keys.onRightPressed: root.setVolume(root.source, root.sourceVol + 0.05)
            onSliderChanged: v => root.setVolume(root.source, v)
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "transparent"
                border.color: Theme.accent
                border.width: parent.activeFocus ? Theme.borderHairline : 0
                Accessible.ignored: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
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

                MotionArea {
                    id: smt
                    anchors.fill: parent
                    enabled: !!root.source && root.source.ready
                    accessibleName: qsTr("Alternar silencio del micrófono")
                    hoverWash: false
                    onClicked: { if (root.sourceAudio && root.source.ready) root.sourceAudio.muted = !root.sourceAudio.muted }
                }

                AnimatedLabel {
                    scale: smt.motion.visualScale
                    transform: Translate { y: -Motion.labelTravel * smt.motion.presence }
                    anchors.centerIn: parent
                    value: root.sourceMuted ? qsTr("Mudo") : qsTr("Activo")
                    color: root.sourceMuted ? Theme.accent : Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeSmall * s
                    font.weight: Font.Medium
                }

            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: Theme.borderHairline; color: Theme.hair }

        Text {
            Layout.fillWidth: true
            text: qsTr("Aplicaciones")
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeBodyLg * s
            font.weight: Font.DemiBold
        }

        // ---- streams per-app ----
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                anchors.fill: parent
                visible: root.appStreams.length === 0
                spacing: Theme.spacingSm * s
                Item { Layout.fillHeight: true }
                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    iconName: Icons.iMusic
                    color: Theme.iconSecondary
                    font.pixelSize: 24 * s
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Sin audio de aplicaciones")
                    color: Theme.iconSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeBody * s
                }
                Item { Layout.fillHeight: true }
            }

            Flickable {
                anchors.fill: parent
                visible: root.appStreams.length > 0
                contentHeight: streamColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: streamColumn
                    width: parent.width
                    spacing: Theme.spacingLg * s
                    Repeater {
                        model: root.appStreams
                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm * s
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingMd * s
                                Image {
                                    id: appImage
                                    Layout.preferredWidth: 18 * s
                                    Layout.preferredHeight: 18 * s
                                    source: modelData.icon
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                    sourceSize.width: 36
                                    sourceSize.height: 36
                                }
                                MaterialIcon {
                                    Layout.preferredWidth: 18 * s
                                    visible: appImage.status !== Image.Ready
                                    iconName: Icons.iVolume
                                    color: Theme.iconSecondary
                                    font.pixelSize: 18 * s
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.appName
                                    elide: Text.ElideRight
                                    color: Theme.foreground
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSizeBody * s
                                }
                                Text {
                                    text: Math.round(modelData.node.audio.volume * 100) + "%"
                                    color: Theme.iconSecondary
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel * s
                                }
                                MaterialIcon {
                                    Layout.preferredWidth: 28 * s
                                    Layout.preferredHeight: 28 * s
                                    iconName: modelData.node.audio.muted ? Icons.iVolOff : Icons.iVolMed
                                    color: modelData.node.audio.muted ? Theme.accent : Theme.foreground
                                    font.pixelSize: Theme.fontSizeBody * s
                                    MotionArea {
                                        anchors.fill: parent
                                        accessibleName: qsTr("Alternar silencio de %1").arg(modelData.appName)
                                        hoverWash: false
                                        onClicked: modelData.node.audio.muted = !modelData.node.audio.muted
                                    }
                                }
                            }
                            Slider {
                                Layout.fillWidth: true
                                value: modelData.node.audio.muted ? 0 : root.clamp01(modelData.node.audio.volume)
                                height_: 8
                                s: root.s
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Slider
                                Accessible.name: qsTr("Volumen de %1").arg(modelData.appName)
                                Accessible.description: Math.round(modelData.node.audio.volume * 100) + "%"
                                Accessible.onIncreaseAction: root.setVolume(modelData.node, modelData.node.audio.volume + 0.05)
                                Accessible.onDecreaseAction: root.setVolume(modelData.node, modelData.node.audio.volume - 0.05)
                                Keys.onLeftPressed: root.setVolume(modelData.node, modelData.node.audio.volume - 0.05)
                                Keys.onRightPressed: root.setVolume(modelData.node, modelData.node.audio.volume + 0.05)
                                onSliderChanged: v => root.setVolume(modelData.node, v)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: "transparent"
                                    border.color: Theme.accent
                                    border.width: parent.activeFocus ? Theme.borderHairline : 0
                                    Accessible.ignored: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
