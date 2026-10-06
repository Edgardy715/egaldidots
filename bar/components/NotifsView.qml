pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
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
Item {
    id: root
    property real s: 1
    property bool open: false
    property bool closing: false
    property int count: 0
    property bool dnd: false
    property var notifications: []
    property var iconPaths: new Map()
    signal toggleDndRequested()
    signal clearAllRequested()
    signal dismissRequested(var notification)
    signal linkRequested(var notification, string link)
    signal actionRequested(var notification, var action)
    signal notificationLockRequested(var notification, var owner)
    signal notificationUnlockRequested(var notification, var owner)
    ContentMotion {
        id: historyMotion
        onConcealed: {
            root.clearAllRequested()
            shown = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingXl * root.s

        // ---- header ----
        SurfaceHeader {
            Layout.fillWidth: true
            title: "Notificaciones"
            iconName: Icons.iBell
            s: root.s
            trailing: Component {
                Rectangle {
                    visible: opacity > 0
                    opacity: root.count > 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                    width: countTxt.implicitWidth + 14 * root.s
                    height: 20 * root.s
                    radius: height / 2
                    color: Qt.alpha(Theme.accent, Theme.alphaSubtle)
                    border.color: Qt.alpha(Theme.accent, Theme.alphaStrong)
                    border.width: Theme.borderHairline
                    Text {
                        id: countTxt
                        anchors.centerIn: parent
                    text: root.count
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel * root.s
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd * root.s
            Text {
                text: qsTr("No molestar")
                color: Theme.iconSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeLabel * root.s
            }
            Toggle {
                objectName: "dndToggle"
                accessibleName: qsTr("No molestar")
                checked: root.dnd
                onToggled: root.toggleDndRequested()
            }
            Item { Layout.fillWidth: true }

            Rectangle {
                id: clearButton
                Layout.preferredWidth: clearRow.implicitWidth + 20 * root.s
                Layout.preferredHeight: 28 * root.s
                radius: Theme.radiusSm * root.s
                opacity: root.count > 0 ? 1 : 0.42
                color: clr.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaChip) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                border.color: clr.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaStrong) : Qt.alpha(Theme.foreground, Theme.alphaSoft)
                border.width: Theme.borderHairline
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                MotionArea {
                    id: clr
                    anchors.fill: parent
                    enabled: root.count > 0 && historyMotion.shown
                    accessibleName: qsTr("Limpiar todas las notificaciones")
                    hoverWash: false
                    onClicked: historyMotion.shown = false
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

        // ---- lista historial / empty ----
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            MotionList {
                id: lv
                opacity: historyMotion.progress
                scale: historyMotion.visualScale
                transform: Translate { y: historyMotion.offset * root.s }
                anchors.fill: parent
                clip: true
                visible: root.count > 0
                spacing: Theme.spacingLg * root.s
                cacheBuffer: 0
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel { values: root.notifications }
                delegate: NotifCardView {
                    width: lv.width
                    height: implicitHeight
                    s: root.s
                    compact: false
                    resolvedIconPath: root.iconPaths.get(modelData) || ""
                    onDismissRequested: root.dismissRequested(modelData)
                    onLinkRequested: link => root.linkRequested(modelData, link)
                    onActionRequested: action => root.actionRequested(modelData, action)
                    onLockRequested: (notification, owner) => root.notificationLockRequested(notification, owner)
                    onUnlockRequested: (notification, owner) => root.notificationUnlockRequested(notification, owner)
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingLg * s
                visible: opacity > 0
                opacity: root.count === 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 40 * s; Layout.preferredHeight: 40 * s; radius: width / 2
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
                    text: qsTr("Todo al día")
                    color: Theme.iconSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeBodyLg * s
                    font.weight: Font.Medium
                }
            }
        }
    }
}
