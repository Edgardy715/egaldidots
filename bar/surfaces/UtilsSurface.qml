import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../components"
import "../Singletons"

/**
 * Isla · UtilsSurface. Panel limpio de ajustes rápidos del sistema:
 *  - Keep Awake: mantiene la pantalla activa (inhibe el idle del compositor)
 *  - Brillo: slider del backlight (solo si hay backlight; oculto en desktop)
 *  - Perfil de energía: rendimiento / balanceado / ahorro (power-profiles-daemon)
 *
 * v2 (refactor con componentes compartidos): GlassCard para las tarjetas,
 * SurfaceHeader para el header, IconTile para los iconos, Toggle iOS unificado,
 * Slider para el brillo, StaggerItem para entrada escalonada de tarjetas.
 */
PillSurface {
    id: root
    mTop: Theme.marginLg; mLeft: Theme.marginLg; mRight: Theme.marginLg; mBottom: Theme.marginMd
    clip: true

    readonly property bool showBrightness: Brightness.available

    // ── Perfil de energía (nivel surface, no por-tarjeta) ──
    property string activeProfile: "balanced"
    property var profiles: ["performance", "balanced", "power-saver"]

    function setProfile(p) {
        root.activeProfile = p
        Quickshell.execDetached(["powerprofilesctl", "set", p])
    }

    function profileIndex(): int {
        return root.profiles ? root.profiles.indexOf(root.activeProfile) : 0
    }

    // evita que la rueda llegue al control de volumen de la pill
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {}
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: Theme.spacingXl * s

        // ════════════════════ HEADER ════════════════════
        SurfaceHeader {
            Layout.fillWidth: true
            title: "Ajustes rápidos"
            subtitle: "Sistema"
            iconName: Icons.iSettings2
            s: root.s
            trailing: Component { MaterialIcon { iconName: Icons.iSettings2; color: Theme.accent; font.pixelSize: Theme.fontSizeHead * root.s } }
        }

        // ════════════════════ KEEP AWAKE ════════════════════
        StaggerItem {
            Layout.fillWidth: true
            staggerIndex: 0
            entered: root.open
            s: root.s

            GlassCard {
                anchors.fill: parent
                implicitHeight: keepBody.implicitHeight + 20 * s
                borderColor: KeepAwake.enabled ? Qt.alpha(Theme.accent, Theme.alphaSelected) : Theme.border
                borderWidth: 1
                Behavior on borderColor { ColorAnimation { duration: Motion.fast } }

                ColumnLayout {
                    id: keepBody
                    anchors.fill: parent
                    anchors.margins: 12 * s
                    spacing: Theme.spacingLg * s

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingLg * s

                        IconTile {
                            iconName: Icons.iCoffee
                            color: KeepAwake.enabled ? Theme.accent : Theme.foreground
                            size: 30
                            s: root.s
                            scale: KeepAwake.enabled ? 1.1 : 1
                            Behavior on scale { Anim { type: Anim.FastEffects } }
                        }

                        ColumnLayout {
                            spacing: Theme.spacingXxs * s
                            Layout.fillWidth: true
                            Text {
                                text: "Keep Awake"
                                color: Theme.foreground
                                font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg * s; font.weight: Font.DemiBold
                            }
                            Text {
                                text: KeepAwake.enabled ? "Pantalla activa · " + KeepAwake.elapsedTime : "Evita que la pantalla se apague"
                                color: KeepAwake.enabled ? Theme.accent : Theme.iconSecondary
                                font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * s
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Toggle {
                            accessibleName: qsTr("Mantener despierto")
                            checked: KeepAwake.enabled
                            onToggled: KeepAwake.toggle()
                        }
                    }

                    // descripción expandible
                    Text {
                        Layout.fillWidth: true
                        visible: !KeepAwake.enabled
                        text: "Mientras esté activo, la pantalla no se apagará ni el sistema entrará en reposo."
                        color: Theme.iconSecondary
                        font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * s
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
            entered: root.open && root.showBrightness
            s: root.s
            visible: root.showBrightness

            GlassCard {
                anchors.fill: parent
                implicitHeight: briBody.implicitHeight + 20 * s

                ColumnLayout {
                    id: briBody
                    anchors.fill: parent
                    anchors.margins: 12 * s
                    spacing: Theme.spacingLg * s

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingLg * s

                        IconTile {
                            iconName: Icons.iBrightness
                            size: 30
                            s: root.s
                        }

                        Text {
                            text: "Brillo"
                            color: Theme.foreground
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg * s; font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }

                        Text {
                            text: Math.round(Brightness.percent) + "%"
                            color: Theme.accent
                            font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeBody * s; font.weight: Font.DemiBold
                        }
                    }

                    // slider unificado
                    Slider {
                        Layout.fillWidth: true
                        value: Brightness.percent / 100
                        height_: 6
                        knob: true
                        s: root.s
                        onSliderLiveChanged: (v) => Brightness.setPercent(v * 100)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMd * s

                        // botones − / +
                        Rectangle {
                            Layout.preferredWidth: 30 * s; Layout.preferredHeight: 28 * s
                            radius: Theme.radiusMd * s
                            color: briMinusHover.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaWash) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                            border.width: Theme.borderHairline; border.color: Qt.alpha(Theme.border, Theme.alphaCritical)
                            Behavior on color { ColorAnimation { duration: Motion.fast } }

                            MotionArea {
                                id: briMinusHover
                                anchors.fill: parent
                                accessibleName: qsTr("Bajar brillo")
                                hoverWash: false
                                onClicked: Brightness.decrease()
                            }

                            MaterialIcon {
                                compressWithControl: true
                                interaction: briMinusHover.motion
                                anchors.centerIn: parent
                                iconName: Icons.iMinus
                                color: Theme.foreground
                                font.pixelSize: Theme.fontSizeTitleLg * s
                            }

                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            visible: !Brightness.lastWriteOk
                            text: "✗ permiso denegado"
                            color: Theme.accentStrong
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * s
                            opacity: 0
                            NumberAnimation on opacity { from: 0; to: 0.8; duration: Motion.fast }
                        }

                        Rectangle {
                            Layout.preferredWidth: 30 * s; Layout.preferredHeight: 28 * s
                            radius: Theme.radiusMd * s
                            color: briPlusHover.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaWash) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                            border.width: Theme.borderHairline; border.color: Qt.alpha(Theme.border, Theme.alphaCritical)
                            Behavior on color { ColorAnimation { duration: Motion.fast } }

                            MotionArea {
                                id: briPlusHover
                                anchors.fill: parent
                                accessibleName: qsTr("Subir brillo")
                                hoverWash: false
                                onClicked: Brightness.increase()
                            }

                            MaterialIcon {
                                compressWithControl: true
                                interaction: briPlusHover.motion
                                anchors.centerIn: parent
                                iconName: Icons.iPlus
                                color: Theme.foreground
                                font.pixelSize: Theme.fontSizeTitleLg * s
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
            entered: root.open
            s: root.s

            GlassCard {
                anchors.fill: parent
                implicitHeight: powBody.implicitHeight + 20 * s

                Component.onCompleted: getProfileCmd.running = true

                Process {
                    id: getProfileCmd
                    command: ["powerprofilesctl", "get"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            var v = (text || "").trim().toLowerCase()
                            if (v.length > 0) root.activeProfile = v
                        }
                    }
                }

                ColumnLayout {
                    id: powBody
                    anchors.fill: parent
                    anchors.margins: 12 * s
                    spacing: Theme.spacingLg * s

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingLg * s

                        IconTile {
                            iconName: Icons.iGauge
                            size: 30
                            s: root.s
                        }

                        ColumnLayout {
                            spacing: Theme.spacingXxs * s
                            Layout.fillWidth: true
                            Text {
                                text: "Perfil de energía"
                                color: Theme.foreground
                                font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg * s; font.weight: Font.DemiBold
                            }
                            Text {
                                text: {
                                    if (root.activeProfile === "performance") return "Máximo rendimiento · más consumo"
                                    if (root.activeProfile === "balanced") return "Equilibrio · recomendado"
                                    if (root.activeProfile === "power-saver") return "Máximo ahorro · menos consumo"
                                    return ""
                                }
                                color: Theme.iconSecondary
                                font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * s
                            }
                        }
                    }

                    // selector segmentado animado
                    Item {
                        id: segSelector
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32 * s

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusLg * s
                            color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
                            border.width: Theme.borderHairline; border.color: Qt.alpha(Theme.border, Theme.alphaCritical)
                        }

                        // píldora que se desliza entre opciones
                        Rectangle {
                            readonly property real segW: segSelector.width / 3
                            width: segW - 4 * s
                            height: segSelector.height - 4 * s
                            y: 2 * s
                            x: 2 * s + Math.max(0, root.profileIndex()) * segW
                            radius: Theme.radiusSm * s
                            color: Qt.alpha(Theme.accent, Theme.alphaIconOnAcc)
                            Behavior on x { Anim { type: Anim.FastSpatial; easing.bezierCurve: Motion.bounceCurve } }
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }

                        Row {
                            anchors.fill: parent
                            Repeater {
                                model: root.profiles
                                delegate: Item {
                                    required property string modelData
                                    width: parent.width / 3
                                    height: parent.height
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData === "performance" ? "Rendimiento"
                                            : modelData === "balanced" ? "Balanceado"
                                            : modelData === "power-saver" ? "Ahorro" : modelData
                                        color: root.activeProfile === modelData ? "#000" : Theme.foreground
                                        font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * s; font.weight: Font.Medium
                                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                                    }
                                    MotionArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        hoverWash: false
                                        onClicked: root.setProfile(modelData)
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
