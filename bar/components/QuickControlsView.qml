pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../"
import "../Singletons"

Item {
    id: root
    property real s: 1
    property bool contentReady: false
    property bool showBrightness: false
    property real brightnessPercent: 0
    property bool brightnessLastWriteOk: true
    property bool keepAwakeEnabled: false
    property string keepAwakeElapsedTime: "--:--"
    property string activeProfile: "balanced"
    property var profiles: ["performance", "balanced", "power-saver"]

    signal requestPage(string name)
    signal keepAwakeToggleRequested()
    signal brightnessSetPercent(real percent)
    signal brightnessStepRequested(real amount)
    signal profileSelected(string profile)

    function profileIndex(): int {
        return root.profiles ? root.profiles.indexOf(root.activeProfile) : 0
    }

    clip: true

    // evita que la rueda llegue al control de volumen de la pill
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {}
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: Theme.spacingXl * root.s

        // ════════════════════ HEADER ════════════════════
        SurfaceHeader {
            Layout.fillWidth: true
            title: "Ajustes rápidos"
            subtitle: "Sistema"
            iconName: Icons.iSettings2
            s: root.s
            trailing: Component {
                Item {
                    width: 88 * root.s
                    height: 32 * root.s
                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingSm * root.s
                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: Icons.iSettings2
                            color: Theme.accent
                            font.pixelSize: Theme.fontSizeBodyLg * root.s
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Apariencia")
                            color: Theme.iconSecondary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSizeLabel * root.s
                        }
                    }
                    MotionArea {
                        objectName: "appearanceAction"
                        anchors.fill: parent
                        accessibleName: qsTr("Abrir ajustes de apariencia")
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestPage("appearance")
                    }
                }
            }
        }

        // ════════════════════ KEEP AWAKE ════════════════════
        StaggerItem {
            Layout.fillWidth: true
            staggerIndex: 0
            entered: root.contentReady
            s: root.s

            GlassCard {
                anchors.fill: parent
                s: root.s
                implicitHeight: keepBody.implicitHeight + 20 * root.s
                borderColor: root.keepAwakeEnabled ? Qt.alpha(Theme.accent, Theme.alphaSelected) : Theme.border
                glow: root.keepAwakeEnabled ? 0.7 : 0
                borderWidth: 1
                Behavior on borderColor { ColorAnimation { duration: Motion.fast } }

                ColumnLayout {
                    id: keepBody
                    anchors.fill: parent
                    anchors.margins: 12 * root.s
                    spacing: Theme.spacingLg * root.s

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingLg * root.s

                        IconTile {
                            iconName: Icons.iCoffee
                            color: root.keepAwakeEnabled ? Theme.accent : Theme.foreground
                            size: 30
                            s: root.s
                            scale: root.keepAwakeEnabled ? 1.1 : 1
                            Behavior on scale { Anim { type: Anim.FastEffects } }
                        }

                        ColumnLayout {
                            spacing: Theme.spacingXxs * root.s
                            Layout.fillWidth: true
                            Text {
                                text: "Keep Awake"
                                color: Theme.foreground
                                font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg * root.s; font.weight: Font.DemiBold
                            }
                            Text {
                                text: root.keepAwakeEnabled ? "Pantalla activa · " + root.keepAwakeElapsedTime : "Evita que la pantalla se apague"
                                color: root.keepAwakeEnabled ? Theme.accent : Theme.iconSecondary
                                font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * root.s
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Toggle {
                            objectName: "keepAwakeToggle"
                            accessibleName: qsTr("Mantener despierto")
                            checked: root.keepAwakeEnabled
                            onToggled: root.keepAwakeToggleRequested()
                        }
                    }

                    // descripción expandible
                    Text {
                        Layout.fillWidth: true
                        visible: !root.keepAwakeEnabled
                        text: "Mientras esté activo, la pantalla no se apagará ni el sistema entrará en reposo."
                        color: Theme.iconSecondary
                        font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * root.s
                        wrapMode: Text.WordWrap
                        opacity: 0.9
                    }
                }
            }
        }

        // ════════════════════ BRILLO ════════════════════
        StaggerItem {
            Layout.fillWidth: true
            staggerIndex: 1
            entered: root.contentReady && root.showBrightness
            s: root.s
            visible: root.showBrightness

            GlassCard {
                anchors.fill: parent
                s: root.s
                implicitHeight: briBody.implicitHeight + 20 * root.s

                ColumnLayout {
                    id: briBody
                    anchors.fill: parent
                    anchors.margins: 12 * root.s
                    spacing: Theme.spacingLg * root.s

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingLg * root.s

                        IconTile {
                            iconName: Icons.iBrightness
                            size: 30
                            s: root.s
                        }

                        Text {
                            text: "Brillo"
                            color: Theme.foreground
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg * root.s; font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }

                        Text {
                            objectName: "brightnessPercent"
                            text: Math.round(root.brightnessPercent) + "%"
                            color: Theme.accent
                            font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeBody * root.s; font.weight: Font.DemiBold
                        }
                    }

                    // slider unificado
                    Slider {
                        objectName: "brightnessSlider"
                        Layout.fillWidth: true
                        value: root.brightnessPercent / 100
                        height_: 6
                        knob: true
                        s: root.s
                        onSliderLiveChanged: (v) => root.brightnessSetPercent(v * 100)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMd * root.s

                        // botones − / +
                        Rectangle {
                            Layout.preferredWidth: 30 * root.s; Layout.preferredHeight: 28 * root.s
                            radius: Theme.radiusMd * root.s
                            color: briMinusHover.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaWash) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                            border.width: Theme.borderHairline; border.color: Qt.alpha(Theme.border, Theme.alphaCritical)
                            Behavior on color { ColorAnimation { duration: Motion.fast } }

                            MotionArea {
                                id: briMinusHover
                                objectName: "brightnessDecrease"
                                anchors.fill: parent
                                accessibleName: qsTr("Bajar brillo")
                                hoverWash: false
                                onClicked: root.brightnessStepRequested(-10)
                            }

                            MaterialIcon {
                                compressWithControl: true
                                interaction: briMinusHover.motion
                                anchors.centerIn: parent
                                iconName: Icons.iMinus
                                color: Theme.foreground
                                font.pixelSize: Theme.fontSizeTitleLg * root.s
                            }

                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            objectName: "brightnessWriteError"
                            visible: !root.brightnessLastWriteOk
                            text: "✗ permiso denegado"
                            color: Theme.accentStrong
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * root.s
                            opacity: 0
                            NumberAnimation on opacity { from: 0; to: 0.8; duration: Motion.fast }
                        }

                        Rectangle {
                            Layout.preferredWidth: 30 * root.s; Layout.preferredHeight: 28 * root.s
                            radius: Theme.radiusMd * root.s
                            color: briPlusHover.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaWash) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                            border.width: Theme.borderHairline; border.color: Qt.alpha(Theme.border, Theme.alphaCritical)
                            Behavior on color { ColorAnimation { duration: Motion.fast } }

                            MotionArea {
                                id: briPlusHover
                                objectName: "brightnessIncrease"
                                anchors.fill: parent
                                accessibleName: qsTr("Subir brillo")
                                hoverWash: false
                                onClicked: root.brightnessStepRequested(10)
                            }

                            MaterialIcon {
                                compressWithControl: true
                                interaction: briPlusHover.motion
                                anchors.centerIn: parent
                                iconName: Icons.iPlus
                                color: Theme.foreground
                                font.pixelSize: Theme.fontSizeTitleLg * root.s
                            }

                        }
                    }
                }
            }
        }

        // ════════════════════ PERFIL DE ENERGÍA ════════════════════
        StaggerItem {
            Layout.fillWidth: true
            staggerIndex: 2
            entered: root.contentReady
            s: root.s

            GlassCard {
                anchors.fill: parent
                s: root.s
                implicitHeight: powBody.implicitHeight + 20 * root.s

                ColumnLayout {
                    id: powBody
                    anchors.fill: parent
                    anchors.margins: 12 * root.s
                    spacing: Theme.spacingLg * root.s

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingLg * root.s

                        IconTile {
                            iconName: Icons.iGauge
                            size: 30
                            s: root.s
                        }

                        ColumnLayout {
                            spacing: Theme.spacingXxs * root.s
                            Layout.fillWidth: true
                            Text {
                                text: "Perfil de energía"
                                color: Theme.foreground
                                font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg * root.s; font.weight: Font.DemiBold
                            }
                            Text {
                                objectName: "powerProfileSummary"
                                text: {
                                    if (root.activeProfile === "performance") return "Máximo rendimiento · más consumo"
                                    if (root.activeProfile === "balanced") return "Equilibrio · recomendado"
                                    if (root.activeProfile === "power-saver") return "Máximo ahorro · menos consumo"
                                    return ""
                                }
                                color: Theme.iconSecondary
                                font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * root.s
                            }
                        }
                    }

                    // selector segmentado animado
                    Item {
                        id: segSelector
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32 * root.s

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusLg * root.s
                            color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
                            border.width: Theme.borderHairline; border.color: Qt.alpha(Theme.border, Theme.alphaCritical)
                        }

                        // píldora que se desliza entre opciones
                        Rectangle {
                            readonly property real segW: segSelector.width / 3
                            width: segW - 4 * root.s
                            height: segSelector.height - 4 * root.s
                            y: 2 * root.s
                            x: 2 * root.s + Math.max(0, root.profileIndex()) * segW
                            radius: Theme.radiusSm * root.s
                            color: Theme.foreground
                            Behavior on x { enabled: !Flags.reduceMotion; Anim { type: Anim.FastSpatial } }
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }

                        Row {
                            anchors.fill: parent
                            Repeater {
                                model: root.profiles
                                delegate: Item {
                                    id: profileOption
                                    required property string modelData
                                    width: parent.width / 3
                                    height: parent.height
                                    Text {
                                        id: profileLabel
                                        anchors.centerIn: parent
                                        text: profileOption.modelData === "performance" ? "Rendimiento"
                                            : profileOption.modelData === "balanced" ? "Balanceado"
                                            : profileOption.modelData === "power-saver" ? "Ahorro" : profileOption.modelData
                                        color: root.activeProfile === profileOption.modelData ? Theme.background : Theme.foreground
                                        font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * root.s; font.weight: Font.Medium
                                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                                    }
                                    MotionArea {
                                        objectName: "profile-" + profileOption.modelData
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        accessibleName: qsTr("Perfil de energía: %1").arg(profileLabel.text)
                                        Accessible.role: Accessible.RadioButton
                                        Accessible.checked: root.activeProfile === profileOption.modelData
                                        hoverWash: false
                                        onClicked: root.profileSelected(profileOption.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
