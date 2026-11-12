pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

// Content only; the companion owns mass, gestures and its existing absorption.
Item {
    id: root
    property var activity: null
    property int count: 0
    property real s: 1
    property bool peek: false
    readonly property string status: !activity ? "" : activity.state === "done" ? "success"
        : activity.state === "failed" ? "error" : activity.progress >= 0 ? "progress" : "busy"
    readonly property bool animating: indicator.animating
    readonly property bool shaking: shake.running
    onStatusChanged: if (status === "error" && visible) shake.trigger()
    Component.onCompleted: if (status === "error" && visible) shake.trigger()
    ErrorShake { id: shake; amplitude: 4 * root.s }
    Row {
        anchors.centerIn: parent
        spacing: 8 * root.s
        transform: Translate { x: shake.offset }
        ConfirmationIndicator {
            id: indicator
            objectName: "activityProgress"
            anchors.verticalCenter: parent.verticalCenter
            width: 24 * root.s; height: width
            s: root.s
            status: root.status
            progress: root.activity?.progress ?? 0
            MaterialIcon {
                anchors.centerIn: parent
                visible: root.status === "busy" || root.status === "progress"
                iconName: root.activity?.icon || "work"
                color: Theme.foreground
                font.pixelSize: 12 * root.s
            }
        }
        Column {
            visible: root.peek
            width: visible ? 158 * root.s : 0
            spacing: 1 * root.s
            CrossfadeLabel {
                width: parent.width; height: 18 * root.s
                value: root.activity?.title || ""
                textFormat: Text.PlainText; elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s
                font.weight: Font.Medium
                color: root.status === "error" ? Theme.signalError : Theme.foreground
            }
            CrossfadeLabel {
                width: parent.width; height: 16 * root.s
                value: root.activity?.subtitle || ""
                textFormat: Text.PlainText; elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * root.s
                color: Theme.iconSecondary
            }
        }
        RollingNumber {
            objectName: "activityCount"
            anchors.verticalCenter: parent.verticalCenter
            value: root.count; widthSample: "8"
            visible: root.count > 1
            font.family: Theme.fontMedia; font.pixelSize: Theme.fontSizeBody * root.s
            color: Theme.foreground
        }
    }
}
