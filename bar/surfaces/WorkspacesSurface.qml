import QtQuick
import Quickshell
import Quickshell.Hyprland
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
    readonly property int activeId: {
        var monitors = Hyprland.monitors.values
        for (var i = 0; i < monitors.length; i++) {
            if (monitors[i].name === root.screenName)
                return monitors[i].activeWorkspace ? monitors[i].activeWorkspace.id : 1
        }
        return 1
    }
    readonly property var workspaceData: {
        var data = []
        for (var i = 1; i <= root.count; i++) data[i] = { occupied: false, windows: 0 }

        var workspaces = Hyprland.workspaces.values
        for (var j = 0; j < workspaces.length; j++) {
            var workspace = workspaces[j]
            if (!workspace.monitor || workspace.monitor.name !== root.screenName) continue
            if (workspace.id < 1 || workspace.id > root.count) continue
            var ipc = workspace.lastIpcObject
            var windows = ipc ? (ipc.windows || 0) : 0
            data[workspace.id] = { occupied: windows > 0, windows: windows }
        }
        return data
    }

    Item {
        id: header

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

                readonly property int wsId: index + 1
                readonly property var info: root.workspaceData[wsId] || { occupied: false, windows: 0 }
                readonly property bool active: root.activeId === wsId
                readonly property bool occupied: info.occupied
                readonly property int windowCount: info.windows

                entered: root.open
                staggerIndex: index
                s: root.s
                width: (atlas.width - (atlas.columns - 1) * atlas.spacing) / atlas.columns
                height: (atlas.height - atlas.spacing) / 2
                scaleFrom: 0.92

                Rectangle {
                    id: glow

                    anchors.fill: parent
                    anchors.margins: -2 * root.s
                    radius: card.radius + 2 * root.s
                    color: Qt.alpha(Theme.accent, 0.10)
                    opacity: workspace.active ? 0.8 : 0

                    Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                }

                Rectangle {
                    id: card

                    anchors.fill: parent
                    radius: Theme.radiusLg * root.s
                    transformOrigin: Item.Center
                    scale: workspace.active ? 1 : (mouse.containsMouse ? 1.035 : 1)
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: workspace.active
                                ? Qt.alpha(Theme.accent, 0.34)
                                : Qt.alpha(Theme.foreground, workspace.occupied ? 0.095 : 0.035)
                        }
                        GradientStop {
                            position: 1
                            color: workspace.active
                                ? Qt.alpha(Theme.accent, 0.17)
                                : Qt.alpha(Theme.background, 0.10)
                        }
                    }
                    border.width: Theme.borderHairline
                    border.color: workspace.active
                        ? Qt.alpha(Theme.accent, 0.90)
                        : Qt.alpha(Theme.foreground, mouse.containsMouse ? Theme.alphaSoft : Theme.alphaHair)

                    Behavior on scale { Anim { type: Anim.FastEffects } }

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

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + workspace.wsId + " })"])
                }
            }
        }
    }
}
