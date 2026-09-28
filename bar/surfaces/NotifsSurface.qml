import QtQuick
import QtQuick.Layouts
import "../"
import "../Singletons"
import "../components"

/**
 * Isla · NotifsSurface. El CENTRO de notificaciones — surface que morfea la pill
 * (como calendar/mixer). Lista historial (NotifCard full), header con count chip
 * + toggle DND + Limpiar. Al abrir: Notifs.centerOpen=true + clearToasts() (oculta
 * popups en pantalla, no los borra del historial) — el lifecycle de centerOpen lo
 * clava shell.qml en onOpenSurfaceChanged (cierra→false), igual que WinMap.active.
 * Empty state "Todo al día" cuando no hay notClosed. Cero springs.
 *
 * v2: header con SurfaceHeader + Toggle unificado, stagger de entrada de la lista.
 */
PillSurface {
    id: root
    mTop: Theme.marginLg; mLeft: Theme.marginLg; mRight: Theme.marginLg; mBottom: Theme.marginLg

    Component.onCompleted: {
        Notifs.centerOpen = true
        Notifs.clearToasts()
    }
    Component.onDestruction: {
        Notifs.centerOpen = false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingXl * s

        // ---- header ----
        SurfaceHeader {
            Layout.fillWidth: true
            title: "Notificaciones"
            iconName: Icons.iBell
            s: root.s
            trailing: Component {
                RowLayout {
                    spacing: Theme.spacingMd * root.s

                    // count chip
                    Rectangle {
                        visible: Notifs.count > 0
                        Layout.preferredWidth: countTxt.implicitWidth + 14 * root.s
                        Layout.preferredHeight: 20 * root.s
                        radius: height / 2
                        color: Qt.alpha(Theme.accent, Theme.alphaSubtle)
                        border.color: Qt.alpha(Theme.accent, Theme.alphaStrong); border.width: Theme.borderHairline
                        Text {
                            id: countTxt
                            anchors.centerIn: parent
                            text: Notifs.count
                            color: Theme.accent
                            font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeLabel * root.s
                        }
                    }

                    // DND toggle
                    Toggle {
                        accessibleName: qsTr("No molestar")
                        checked: Notifs.dnd
                        onToggled: Notifs.toggleDnd()
                    }

                    // Limpiar
                    Rectangle {
                        id: clearButton
                        Layout.preferredWidth: clearRow.implicitWidth + 20 * root.s
                        Layout.preferredHeight: 28 * root.s
                        radius: Theme.radiusSm * root.s
                        opacity: Notifs.count > 0 ? 1 : 0.42
                        color: clr.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaChip) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                        border.color: clr.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaStrong) : Qt.alpha(Theme.foreground, Theme.alphaSoft)
                        border.width: Theme.borderHairline
                        transformOrigin: Item.Center
                        Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                        Behavior on border.color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                        MotionArea {
                            id: clr
                            anchors.fill: parent
                            enabled: Notifs.count > 0
                            accessibleName: qsTr("Limpiar todas las notificaciones")
                            hoverWash: false
                            onClicked: Notifs.clearAll()
                        }

                        Row {
                            id: clearRow
                            anchors.centerIn: parent
                            spacing: Theme.spacingXs * root.s
                            MaterialIcon {
                                compressWithControl: true
                                interaction: clr.motion
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: Icons.iClearAll
                                hovered: clr.containsMouse
                                color: clr.containsMouse ? Theme.accent : Theme.iconSecondary
                                font.pixelSize: 15 * root.s
                            }
                            Text {
                                scale: clr.motion.visualScale
                                transform: Translate { y: -Motion.labelTravel * clr.motion.presence }
                                id: clearTxt
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Limpiar todo")
                                color: clr.containsMouse ? Theme.accent : Theme.foreground
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSizeLabel * root.s
                                font.weight: Font.Medium
                            }
                        }

                    }
                }
            }
        }

        // ---- lista historial / empty ----
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            Flickable {
                id: lv
                anchors.fill: parent
                clip: true
                visible: Notifs.count > 0
                contentWidth: width
                contentHeight: col2.height
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: col2
                    width: lv.width
                    spacing: Theme.spacingLg * root.s
                    Repeater {
                        model: Notifs.notClosed
delegate: StaggerItem {
                            id: wrap
                            // modelData del Repeater → propagamos al NotifCard.
                            // Antes NotifCard requería `required property var
                            // modelData`, lo que deshabilita la inyección del
                            // context property en todo el árbol (ver Qt docs:
                            // "model, modelData, index roles are not accessible
                            // if the delegate contains required properties
                            // unless it has also required properties with
                            // matching names"). Ahora NotifCard es opcional y
                            // hacemos el binding explícito. La propiedad local
                            // `notif` evita shadowing del context property.
                            property var notif: modelData
                            width: col2.width
                            staggerIndex: index
                            entered: root.open
                            s: root.s
                            NotifCard {
                                width: col2.width
                                s: root.s
                                compact: false
                                modelData: wrap.notif
                            }
                        }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignCenter
                spacing: Theme.spacingLg * s
                visible: Notifs.count === 0
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 40 * s; height: 40 * s; radius: width / 2
                    color: Qt.alpha(Theme.accent, Theme.alphaSoft)
                    border.color: Qt.alpha(Theme.accent, Theme.alphaEmphasis); border.width: Theme.borderHairlineSoft *  s
                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: Icons.iBell
                        color: Theme.accent
                        font.pixelSize: Theme.fontSizeHead * s
                        Accessible.ignored: true
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Todo al día"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeBodyLg * s
                    font.weight: Font.Medium
                }
            }
        }
    }
