pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"
import "../Singletons"
import "../components"

/** Surface del historial; ShellRuntime controla el ciclo de centerOpen.
 * Al abrirla, oculta los toasts visibles sin quitarlos del historial.
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
    signal closeRequested(var notification)
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
            title: I18n.tr("Notificaciones")
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
                    Behavior on width { SmoothedAnimation { velocity: -1; duration: Motion.fast } }
                    AnimatedLabel {
                        id: countTxt
                        anchors.centerIn: parent
                        value: String(root.count)
                        color: Theme.accent
                        font.family: Theme.font
                        font.features: Theme.fontNumeric
                        font.weight: Font.DemiBold
                        font.pixelSize: Theme.fontSizeLabel * root.s
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd * root.s
            Text {
                text: I18n.tr("No molestar")
                color: Theme.iconSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeLabel * root.s
            }
            Toggle {
                objectName: "dndToggle"
                accessibleName: I18n.tr("No molestar")
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
                Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                color: clr.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaChip) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                MotionArea {
                    id: clr
                    anchors.fill: parent
                    enabled: root.count > 0 && historyMotion.shown
                    accessibleName: I18n.tr("Limpiar todas las notificaciones")
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
                        text: I18n.tr("Limpiar todo")
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
                // Kept alive while the last card plays its remove transition.
                visible: root.count > 0 || lastRemoval.running
                spacing: Theme.spacingLg * root.s
                cacheBuffer: 0
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel { values: root.notifications }
                delegate: NotifCardView {
                    objectName: "historyCard"
                    width: lv.width
                    height: implicitHeight
                    s: root.s
                    compact: false
                    resolvedIconPath: root.iconPaths.get(modelData) || ""
                    onDismissRequested: root.dismissRequested(modelData)
                    onCloseRequested: root.closeRequested(modelData)
                    onLinkRequested: link => root.linkRequested(modelData, link)
                    onActionRequested: action => root.actionRequested(modelData, action)
                    onLockRequested: (notification, owner) => root.notificationLockRequested(notification, owner)
                    onUnlockRequested: (notification, owner) => root.notificationUnlockRequested(notification, owner)
                }
            }

            Timer {
                id: lastRemoval
                interval: Motion.fast + 40
                property int previous: root.count
                Component.onCompleted: previous = root.count
            }
            Connections {
                target: root
                function onCountChanged() {
                    // Clear-all already concealed the list; only a lone close plays out.
                    if (root.count === 0 && lastRemoval.previous > 0 && historyMotion.progress > 0.5
                            && !Flags.reduceMotion) lastRemoval.restart()
                    lastRemoval.previous = root.count
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingLg * root.s
                visible: opacity > 0
                opacity: root.count === 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 40 * root.s; Layout.preferredHeight: 40 * root.s; radius: width / 2
                    color: Qt.alpha(Theme.accent, Theme.alphaSoft)
                    MaterialIcon {
                        anchors.centerIn: parent
                                    color: Theme.accent
                        font.pixelSize: Theme.fontSizeHead * root.s
                        Accessible.ignored: true
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: I18n.tr("Todo al día")
                    color: Theme.iconSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeBodyLg * root.s
                    font.weight: Font.Medium
                }
            }
        }
    }
}
