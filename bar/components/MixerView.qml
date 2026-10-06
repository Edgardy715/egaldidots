pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Singletons"

Item {
    id: root
    property real s: 1
    property real vol: 0
    property bool muted: false
    property bool outputReady: false
    property real sourceVol: 0
    property bool sourceMuted: false
    property bool sourceReady: false
    property var appStreams: []

    signal outputVolumeRequested(real volume)
    signal outputMuteToggleRequested()
    signal sourceVolumeRequested(real volume)
    signal sourceMuteToggleRequested()
    signal streamVolumeRequested(var node, real volume)
    signal streamMuteToggleRequested(var node)

    function clamp01(value) { return Math.max(0, Math.min(1, value)) }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingLg * root.s

        // header
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingLg * root.s
            Text {
                text: "Volumen"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeTitle * root.s
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            Text {
                text: Math.round(root.vol * 100) + "%"
                color: Theme.foreground
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBodyLg * root.s
            }
        }

        // volume bar
        Slider {
            objectName: "outputVolumeSlider"
            Layout.fillWidth: true
            value: root.muted ? 0 : root.clamp01(root.vol)
            s: root.s
            enabled: !!root.outputReady
            activeFocusOnTab: enabled
            Accessible.role: Accessible.Slider
            Accessible.name: qsTr("Volumen de salida")
            Accessible.description: Math.round(root.vol * 100) + "%"
            Accessible.onIncreaseAction: root.outputVolumeRequested(root.vol + 0.05)
            Accessible.onDecreaseAction: root.outputVolumeRequested(root.vol - 0.05)
            Keys.onLeftPressed: root.outputVolumeRequested(root.vol - 0.05)
            Keys.onRightPressed: root.outputVolumeRequested(root.vol + 0.05)
            onSliderChanged: v => root.outputVolumeRequested(v)
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
                Layout.preferredWidth: 64 * root.s
                Layout.preferredHeight: 26 * root.s
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
                    objectName: "outputMuteToggle"
                    anchors.fill: parent
                    enabled: !!root.outputReady
                    accessibleName: qsTr("Alternar silencio del audio")
                    hoverWash: false
                    onClicked: { if (root.outputReady) root.outputMuteToggleRequested() }
                }

                AnimatedLabel {
                    scale: mt.motion.visualScale
                    transform: Translate { y: -Motion.labelTravel * mt.motion.presence }
                    anchors.centerIn: parent
                    value: root.muted ? qsTr("Silencio") : qsTr("Sonando")
                    color: root.muted ? Theme.accent : Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeSmall * root.s
                    font.weight: Font.Medium
                }

            }
        }

        // ---- micrófono ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingLg * root.s
            Text {
                text: "Micrófono"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeTitle * root.s
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            Text {
                text: Math.round(root.sourceVol * 100) + "%"
                color: Theme.foreground
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBodyLg * root.s
            }
        }

        // mic volume bar
        Slider {
            objectName: "sourceVolumeSlider"
            Layout.fillWidth: true
            value: root.sourceMuted ? 0 : root.clamp01(root.sourceVol)
            s: root.s
            enabled: root.sourceReady
            activeFocusOnTab: enabled
            Accessible.role: Accessible.Slider
            Accessible.name: qsTr("Volumen del micrófono")
            Accessible.description: Math.round(root.sourceVol * 100) + "%"
            Accessible.onIncreaseAction: root.sourceVolumeRequested(root.sourceVol + 0.05)
            Accessible.onDecreaseAction: root.sourceVolumeRequested(root.sourceVol - 0.05)
            Keys.onLeftPressed: root.sourceVolumeRequested(root.sourceVol - 0.05)
            Keys.onRightPressed: root.sourceVolumeRequested(root.sourceVol + 0.05)
            onSliderChanged: v => root.sourceVolumeRequested(v)
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
                Layout.preferredWidth: 64 * root.s
                Layout.preferredHeight: 26 * root.s
                radius: height / 2
                color: root.sourceMuted
                       ? (smt.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaMid) : Qt.alpha(Theme.accent, Theme.alphaChip))
                       : (smt.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaWash) : Qt.alpha(Theme.foreground, Theme.alphaFaint))
                border.color: Qt.alpha(Theme.foreground, Theme.alphaSoft)
                border.width: Theme.borderHairline
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                MotionArea {
                    id: smt
                    objectName: "sourceMuteToggle"
                    anchors.fill: parent
                    enabled: root.sourceReady
                    accessibleName: qsTr("Alternar silencio del micrófono")
                    hoverWash: false
                    onClicked: { if (root.sourceReady) root.sourceMuteToggleRequested() }
                }

                AnimatedLabel {
                    scale: smt.motion.visualScale
                    transform: Translate { y: -Motion.labelTravel * smt.motion.presence }
                    anchors.centerIn: parent
                    value: root.sourceMuted ? qsTr("Mudo") : qsTr("Activo")
                    color: root.sourceMuted ? Theme.accent : Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeSmall * root.s
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
            font.pixelSize: Theme.fontSizeBodyLg * root.s
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
                spacing: Theme.spacingSm * root.s
                Item { Layout.fillHeight: true }
                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    iconName: Icons.iMusic
                    color: Theme.iconSecondary
                    font.pixelSize: 24 * root.s
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Sin audio de aplicaciones")
                    color: Theme.iconSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeBody * root.s
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
                    spacing: Theme.spacingLg * root.s
                    Repeater {
                        model: root.appStreams
                        delegate: ColumnLayout {
                            id: streamDelegate
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm * root.s
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingMd * root.s
                                Image {
                                    id: appImage
                                    Layout.preferredWidth: 18 * root.s
                                    Layout.preferredHeight: 18 * root.s
                                    source: streamDelegate.modelData.icon
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                    sourceSize.width: 36
                                    sourceSize.height: 36
                                }
                                MaterialIcon {
                                    Layout.preferredWidth: 18 * root.s
                                    visible: appImage.status !== Image.Ready
                                    iconName: Icons.iVolume
                                    color: Theme.iconSecondary
                                    font.pixelSize: 18 * root.s
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: streamDelegate.modelData.appName
                                    elide: Text.ElideRight
                                    color: Theme.foreground
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSizeBody * root.s
                                }
                                Text {
                                    text: Math.round(streamDelegate.modelData.volume * 100) + "%"
                                    color: Theme.iconSecondary
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel * root.s
                                }
                                MaterialIcon {
                                    Layout.preferredWidth: 28 * root.s
                                    Layout.preferredHeight: 28 * root.s
                                    iconName: streamDelegate.modelData.muted ? Icons.iVolOff : Icons.iVolMed
                                    color: streamDelegate.modelData.muted ? Theme.accent : Theme.foreground
                                    font.pixelSize: Theme.fontSizeBody * root.s
                                    MotionArea {
                                        objectName: "streamMute-" + streamDelegate.modelData.appName
                                        anchors.fill: parent
                                        accessibleName: qsTr("Alternar silencio de %1").arg(streamDelegate.modelData.appName)
                                        hoverWash: false
                                        onClicked: root.streamMuteToggleRequested(streamDelegate.modelData.node)
                                    }
                                }
                            }
                            Slider {
                                Layout.fillWidth: true
                                value: streamDelegate.modelData.muted ? 0 : root.clamp01(streamDelegate.modelData.volume)
                                height_: 8
                                s: root.s
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Slider
                                Accessible.name: qsTr("Volumen de %1").arg(streamDelegate.modelData.appName)
                                Accessible.description: Math.round(streamDelegate.modelData.volume * 100) + "%"
                                Accessible.onIncreaseAction: root.streamVolumeRequested(streamDelegate.modelData.node, streamDelegate.modelData.volume + 0.05)
                                Accessible.onDecreaseAction: root.streamVolumeRequested(streamDelegate.modelData.node, streamDelegate.modelData.volume - 0.05)
                                Keys.onLeftPressed: root.streamVolumeRequested(streamDelegate.modelData.node, streamDelegate.modelData.volume - 0.05)
                                Keys.onRightPressed: root.streamVolumeRequested(streamDelegate.modelData.node, streamDelegate.modelData.volume + 0.05)
                                onSliderChanged: v => root.streamVolumeRequested(streamDelegate.modelData.node, v)
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
