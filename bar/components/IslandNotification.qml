import QtQuick
import "../Singletons"
import "RubberBand.js" as RubberBand

/** Inline notification shown while the island has morphed to notification size. */
Item {
    id: root

    property var notification: null
    property real s: 1
    property real pillWidth: 380
    property real pillHeight: 72
    property real closeness: 0
    property real breath: 0
    property bool holding: false
    property bool iconResolved: false
    property string iconSource: ""
    property var gestureMotion: null
    property bool gesturesEnabled: Config._effective.gestures.enabled
    readonly property alias gesture: drag
    onNotificationChanged: {
        if (notification && !drag.candidate && !drag.pendingNotificationAction) drag.resetNotificationContent()
    }
    signal gestureStarted()
    signal gestureFinished(string action)
    signal gestureSettled(string name, bool opened)
    PillPullGesture {
        id: drag
        motion: root.gestureMotion
        enabled: root.gesturesEnabled && root.gestureMotion !== null
        mode: "notification"
        s: root.s
        reduceMotion: Flags.reduceMotion
        plannedW: IslandGeometry.notificationsSurface.width * root.s
        plannedH: IslandGeometry.notificationsSurface.height * root.s
        plannedRadius: 24 * root.s
        rubberBand: (value, limit) => RubberBand.rubberBand(value, limit, 0.55)
        onNotificationStarted: root.gestureStarted()
        onNotificationFinished: action => root.gestureFinished(action)
        onSettled: (name, opened) => root.gestureSettled(name, opened)
    }
    property bool dragIntent: false
    PointHandler {
        id: dragPoint
        enabled: drag.enabled
        acceptedButtons: Qt.LeftButton
        onActiveChanged: {
            if (active) { root.dragIntent = false; drag.press(point.scenePosition.x, point.scenePosition.y, Date.now(), false, "") }
            else if (!dragHandler.active) drag.release(Date.now())
        }
        onPointChanged: if (active && drag.candidate) root.dragIntent = drag.wantsMove(point.scenePosition.x, point.scenePosition.y)
    }
    DragHandler {
        id: dragHandler
        enabled: drag.enabled
        target: null
        acceptedButtons: Qt.LeftButton
        dragThreshold: root.dragIntent ? Math.max(Motion.pullThreshold * root.s, 1) : 32766
        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType
            | PointerHandler.ApprovesTakeOverByAnything
        onActiveChanged: {
            if (active) drag.move(centroid.scenePosition.x, centroid.scenePosition.y, Date.now())
            else if (!dragPoint.active) drag.release(Date.now())
        }
        onCentroidChanged: if (active) drag.move(centroid.scenePosition.x, centroid.scenePosition.y, Date.now())
        onCanceled: drag.cancel()
    }
    property real contentOffset: 0
    property bool gestureActive: false

    width: pillWidth
    height: pillHeight
    opacity: closeness
    visible: opacity > 0.01
    clip: true
    // breath ya llega modulado por el nivel de hold (PillMorphMotion); no se
    // anima otra vez un valor que ya está animado.
    scale: gestureActive || drag.candidate ? 1 : 1.0 + breath * 0.025

    Row {
        anchors.centerIn: parent
        transform: Translate { x: root.contentOffset + drag.contentOffset }
        opacity: Math.max(0, 1 - Math.abs(root.contentOffset + drag.contentOffset) / Math.max(1, root.pillWidth * 0.65))
        spacing: Theme.spacingXl * root.s
        visible: root.notification !== null

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 48 * root.s
            height: 48 * root.s
            visible: root.notification && root.iconResolved

            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 10 * root.s
                height: parent.height + 10 * root.s
                radius: width / 2
                color: root.notification?.isCritical ? Theme.accentStrong : Theme.accent
                opacity: root.breath * 0.15 + 0.04
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 8 * root.s * (1 + root.breath * 0.5)
                height: parent.height + 8 * root.s * (1 + root.breath * 0.5)
                radius: width / 2
                color: "transparent"
                border.width: Theme.borderHairlineSoft * root.s
                border.color: root.notification?.isCritical
                    ? Qt.alpha(Theme.accentStrong, 0.25 + root.breath * 0.25)
                    : Qt.alpha(Theme.accent, 0.20 + root.breath * 0.25)
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: width / 2
                color: Qt.alpha(root.notification?.isCritical ? Theme.accentStrong : Theme.accent, Theme.alphaSubtle)
                border.color: Qt.alpha(root.notification?.isCritical ? Theme.accentStrong : Theme.accent, Theme.alphaCritical)
                border.width: Theme.borderHairlineSoft * root.s
                scale: 1.0 + root.breath * 0.06
            }
            Image {
                anchors.centerIn: parent
                width: 30 * root.s
                height: 30 * root.s
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                smooth: true
                cache: false
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 48 * root.s
            height: 48 * root.s
            radius: width / 2
            visible: !root.notification || !root.iconResolved
            color: Qt.alpha(root.notification?.isCritical ? Theme.accentStrong : Theme.accent, Theme.alphaSubtle)
            border.color: Qt.alpha(root.notification?.isCritical ? Theme.accentStrong : Theme.accent, Theme.alphaCritical)
            border.width: Theme.borderHairlineSoft * root.s
            MaterialIcon {
                anchors.centerIn: parent
                iconName: root.notification
                    ? Icons.getNotifIcon(root.notification.summary, root.notification.urgency)
                    : Icons.iBell
                color: root.notification?.isCritical ? Theme.accentStrong : Theme.accent
                font.pixelSize: Theme.fontSizeIcon * root.s
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXs * root.s
            Text {
                text: root.notification?.appName ?? ""
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
                width: root.pillWidth - 100 * root.s
                visible: text.length > 0
            }
            Text {
                text: root.notification?.summary ?? ""
                color: root.notification?.isCritical ? Theme.accent : Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: root.pillWidth - 100 * root.s
            }
            Text {
                text: root.notification?.body ?? ""
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall * root.s
                elide: Text.ElideRight
                width: root.pillWidth - 100 * root.s
                visible: text.length > 0
            }
        }
    }
}
