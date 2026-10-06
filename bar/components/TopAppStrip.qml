pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../Singletons"

Item {
    id: root
    property real s: 1
    property var apps: []
    property var appEntries: ({})
    property bool animateChanges: true
    property var previousApps: []
    readonly property string singleAppName: apps.length === 1
        ? (appEntries[apps[0]] ? appEntries[apps[0]].name : apps[0]) : ""
    readonly property bool nameShown: apps.length === 1 && visible
        && (intro.running || appHover.containsMouse)
    readonly property real nameWidth: Math.min(appName.implicitWidth, 120 * s) + 7 * s
    onAppsChanged: {
        if (apps.length === 1 && visible && previousApps.indexOf(apps[0]) < 0) intro.restart()
        else if (apps.length !== 1) intro.stop()
        previousApps = apps.slice()
    }
    onVisibleChanged: if (!visible) intro.stop()
    Timer { id: intro; interval: 1800 }
    height: 28 * s

    Item {
        x: 26 * root.s
        width: Math.max(0, appList.width - 26 * root.s)
        height: appList.height
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        Text {
            id: appName
            objectName: "statusAppName"
            anchors.left: parent.left
            anchors.leftMargin: 7 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - 7 * root.s)
            text: root.singleAppName
            elide: Text.ElideRight
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeSmall * root.s
            opacity: root.nameShown ? Math.min(1, parent.width / Math.max(1, root.nameWidth)) : 0
            Behavior on opacity {
                enabled: root.visible && root.animateChanges && !Flags.reduceMotion
                NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
            }
            Accessible.ignored: true
        }
    }

    MotionList {
        id: appList
        objectName: "statusApps"
        x: 0
        width: Math.max(0, root.width)
        anchors.verticalCenter: parent.verticalCenter
        height: 28 * root.s
        orientation: ListView.Horizontal
        currentIndex: -1
        interactive: contentWidth > width
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        model: ScriptModel { values: root.apps }
        add: Transition {
            enabled: root.visible && root.animateChanges && !Flags.reduceMotion
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.standardSmall; easing.type: Motion.easeStandard }
                NumberAnimation { property: "scale"; from: 0.8; to: 1; duration: Motion.standardSmall; easing.type: Motion.easeStandard }
                NumberAnimation { property: "y"; from: 4 * root.s; to: 0; duration: Motion.standardSmall; easing.type: Motion.easeStandard }
            }
        }
        remove: Transition {
            enabled: root.visible && root.animateChanges && !Flags.reduceMotion
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: Motion.fast; easing.type: Motion.easeStandard }
                NumberAnimation { property: "scale"; to: 0.8; duration: Motion.fast; easing.type: Motion.easeStandard }
            }
        }
        displaced: Transition {
            enabled: root.visible && root.animateChanges && !Flags.reduceMotion
            NumberAnimation { property: "x"; duration: Motion.standardSmall; easing.type: Motion.easeStandard }
        }
        delegate: Item {
            id: app
            required property string modelData
            readonly property var entry: root.appEntries[modelData] || null
            readonly property string iconPath: Quickshell.iconPath(entry && entry.icon ? entry.icon : modelData.toLowerCase(), true)
            width: 26 * root.s
            height: 28 * root.s
            Accessible.role: Accessible.StaticText
            Accessible.name: entry && entry.name ? entry.name : modelData
            Image {
                id: appImage
                anchors.centerIn: parent
                width: 19 * root.s; height: width
                source: app.iconPath
                sourceSize: Qt.size(32, 32)
                visible: appImage.status === Image.Ready
                fillMode: Image.PreserveAspectFit
                Accessible.ignored: true
            }
            MaterialIcon {
                anchors.centerIn: parent
                visible: appImage.status !== Image.Ready
                iconName: /terminal|kitty|alacritty|foot|wezterm|konsole/i.test(app.modelData) ? Icons.iTerminal : "apps"
                color: Theme.iconSecondary
                font.pixelSize: Theme.fontSizeBodyLg * root.s
            }
        }
    }
    MouseArea {
        id: appHover
        objectName: "statusAppHover"
        x: appList.x; y: appList.y
        width: appList.width; height: appList.height
        enabled: root.visible && root.apps.length === 1
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
