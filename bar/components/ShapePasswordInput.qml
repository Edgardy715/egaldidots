import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Singletons"

/** Minimal Apple-like password dots with a soft insertion animation. */
Item {
    id: root

    property string password: ""
    property real s: 1
    implicitWidth: dots.implicitWidth
    height: 8 * root.s

    Row {
        id: dots
        anchors.centerIn: parent
        spacing: 8 * root.s
        height: 8 * root.s

        Repeater {
            model: root.password.length

            Rectangle {
                required property int index
                width: 7 * root.s
                height: width
                radius: width / 2
                color: Theme.foreground
                opacity: 0
                scale: 0.55

                Component.onCompleted: entry.start()

                SequentialAnimation {
                    id: entry
                    ParallelAnimation {
                        NumberAnimation { target: parent; property: "opacity"; to: 1; duration: Motion.fast }
                        NumberAnimation { target: parent; property: "scale"; to: 1; duration: Motion.fast; easing.bezierCurve: Motion.bounceCurve }
                    }
                }
            }
        }
    }
}
