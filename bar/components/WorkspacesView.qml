pragma ComponentBehavior: Bound
import QtQuick
import "../"
import "../Singletons"
import "../components"

PillSurface {
    id: root

    mTop: Theme.marginLg
    mLeft: Theme.marginLg
    mRight: Theme.marginLg
    mBottom: Theme.marginLg

    readonly property int count: 10
    property int activeId: 1
    property var workspaceData: ({})
    signal workspaceRequested(int id)

    Item {
        id: header

        property int markerId: Math.max(1, Math.min(root.count, root.activeId))
        property bool movingForward: true

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34 * root.s

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Espacios")
            color: Theme.foreground
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontSizeBodyLg * root.s
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Espacio %1").arg(root.activeId)
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeCaption * root.s
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Theme.borderHairline
            color: Qt.alpha(Theme.foreground, Theme.alphaHair)
        }

        Rectangle {
            id: activeTrack
            property real slotWidth: header.width / root.count
            property real targetLeft: (header.markerId - 1) * slotWidth
            property real targetRight: header.markerId * slotWidth
            property real leftEdge: targetLeft
            property real rightEdge: targetRight
            x: leftEdge
            anchors.bottom: parent.bottom
            width: Math.max(0, rightEdge - leftEdge)
            height: 3 * root.s
            radius: height / 2
            color: Theme.accent
            Behavior on leftEdge {
                enabled: !Flags.reduceMotion && root.open
                SmoothedAnimation { duration: header.movingForward ? 400 : 300; velocity: -1 }
            }
            Behavior on rightEdge {
                enabled: !Flags.reduceMotion && root.open
                SmoothedAnimation { duration: header.movingForward ? 300 : 400; velocity: -1 }
            }
        }
    }

    onActiveIdChanged: {
        header.movingForward = activeId > header.markerId
        header.markerId = Math.max(1, Math.min(count, activeId))
    }

    Grid {
        id: atlas

        anchors.top: header.bottom
        anchors.topMargin: Theme.spacingMd * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        columns: 5
        spacing: Theme.spacingMd * root.s

        Repeater {
            model: root.count

            delegate: StaggerItem {
                id: workspace

                required property int index
                readonly property int wsId: index + 1
                readonly property var info: root.workspaceData[wsId] || { occupied: false, windows: 0 }
                readonly property bool active: root.activeId === wsId
                readonly property bool occupied: info.occupied
                readonly property int windowCount: info.windows

                entered: root.contentReady
                staggerIndex: index
                s: root.s
                width: (atlas.width - (atlas.columns - 1) * atlas.spacing) / atlas.columns
                height: (atlas.height - atlas.spacing) / 2
                scaleFrom: 0.98

                Rectangle {
                    id: card

                    anchors.fill: parent
                    radius: Theme.radiusLg * root.s
                    transformOrigin: Item.Center
                    scale: mouse.motion.visualScale
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: workspace.active
                                ? Qt.alpha(Theme.accent, 0.14)
                                : Qt.alpha(Theme.foreground, workspace.occupied ? 0.095 : 0.035)
                        }
                        GradientStop {
                            position: 1
                            color: workspace.active
                                ? Qt.alpha(Theme.accent, 0.06)
                                : Qt.alpha(Theme.background, 0.10)
                        }
                    }
                    border.width: Theme.borderHairline
                    border.color: workspace.active
                        ? Qt.alpha(Theme.accent, 0.56)
                        : Qt.alpha(Theme.foreground, mouse.containsMouse ? Theme.alphaSoft : Theme.alphaHair)

                    InnerGlow {
                        anchors.fill: parent
                        opacity: workspace.active ? 0.9 : 0
                        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.topMargin: 5 * root.s
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: workspace.active ? parent.width * 0.42 : 0
                        height: 2 * root.s
                        radius: height / 2
                        color: Theme.accent

                        Behavior on width { Anim { type: Anim.Emphasized } }
                    }

                    Text {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 8 * root.s
                        text: workspace.wsId
                        color: workspace.active ? Theme.foreground : (workspace.occupied ? Theme.foreground : Theme.dim)
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontSizeBodyLg * root.s
                        font.weight: workspace.active ? Font.DemiBold : Font.Medium
                    }

                    Item {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 8 * root.s
                        anchors.bottomMargin: 8 * root.s
                        width: 28 * root.s
                        height: 10 * root.s
                        visible: workspace.occupied

                        Row {
                            anchors.bottom: parent.bottom
                            spacing: 3 * root.s

                            Repeater {
                                model: Math.min(3, workspace.windowCount)
                                delegate: Rectangle {
                                    required property int index
                                    width: 6 * root.s
                                    height: (5 + index * 2) * root.s
                                    radius: 2 * root.s
                                    color: workspace.active
                                        ? Qt.alpha(Theme.foreground, 0.84)
                                        : Qt.alpha(Theme.accent, 0.72)
                                }
                            }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: 8 * root.s
                        anchors.bottomMargin: 7 * root.s
                        visible: workspace.windowCount > 0
                        text: workspace.windowCount
                        color: workspace.active ? Qt.alpha(Theme.foreground, 0.74) : Theme.dim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeCaption * root.s
                        font.weight: Font.DemiBold
                    }
                }

                MotionArea {
                    id: mouse
                    accessibleName: qsTr("Ir al escritorio %1").arg(workspace.wsId)

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.workspaceRequested(workspace.wsId)
                }
            }
        }
    }
}
