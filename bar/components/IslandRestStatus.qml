import QtQuick
import "../"
import "../Singletons"

/** The compact status section shown before the optional media chip. */
Row {
    id: root

    property real s: 1
    property real coreH: 38
    property bool capsLockOn: false
    property date now: new Date()
    signal requestCalendar()

    readonly property bool workspaceAnimating: workspaceFlash.shown || workspaceFlash.width > 0.01

    spacing: 0

    function flashWorkspace(number) {
        workspaceFlash.number = number
        workspaceFlash.shown = true
        workspaceFlashHold.restart()
    }
    function showVolume(progress, muted) { volumeChip.showVolume(progress, muted) }
    function showMic(progress, muted) { volumeChip.showMic(progress, muted) }
    function showBrightness(progress) { volumeChip.showBrightness(progress) }
    function showBattery(percent, status) { batteryChip.show(percent, status) }

    Item {
        id: workspaceFlash
        property bool shown: false
        property int number: 1
        width: shown ? 44 * root.s : 0
        height: root.coreH
        clip: true
        Behavior on width {
            enabled: !Flags.reduceMotion
            SmoothedAnimation { duration: Motion.morph; velocity: -1 }
        }
        Timer {
            id: workspaceFlashHold
            interval: 1600
            onTriggered: workspaceFlash.shown = false
        }
        Rectangle {
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: 30 * root.s
            height: 26 * root.s
            radius: 9 * root.s
            color: Qt.alpha(Theme.accent, Theme.alphaWash)
            opacity: Math.max(0, Math.min(1, (parent.width / (44 * root.s) - 0.3) / 0.7))
            ListView {
                id: workspaceReel
                anchors.fill: parent
                clip: true
                interactive: false
                highlight: Item {}
                model: Math.max(11, workspaceFlash.number + 2)
                currentIndex: workspaceFlash.number
                preferredHighlightBegin: 0
                preferredHighlightEnd: height
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveDuration: Flags.reduceMotion ? 0 : Motion.emphasizedLarge
                highlightMoveVelocity: -1
                delegate: Text {
                    required property int index
                    width: workspaceReel.width
                    height: workspaceReel.height
                    text: index
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: Theme.fontDisplay
                    font.pixelSize: 17 * root.s
                    font.weight: Font.DemiBold
                    color: Theme.foreground
                }
                Accessible.name: qsTr("Escritorio %1").arg(workspaceFlash.number)
            }
        }
    }

    VolumeChip { id: volumeChip; s: root.s; coreH: root.coreH }
    BatteryChip { id: batteryChip; s: root.s; coreH: root.coreH }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "⇪"
        color: Theme.accent
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeSmall * root.s
        visible: root.capsLockOn
        opacity: root.capsLockOn ? 1 : 0
        Behavior on opacity { Anim { type: Anim.FastEffects } }
    }
    Item { width: root.capsLockOn ? 6 * root.s : 0; height: 1; visible: root.capsLockOn }

    Item {
        id: clockArea
        width: clockText.implicitWidth
        height: root.coreH

        Text {
            id: clockText
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1.5 * root.s
            height: root.coreH
            verticalAlignment: Text.AlignVCenter
            color: Theme.foreground
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontSizeHeadline * root.s
            font.weight: Font.DemiBold
            textFormat: Text.RichText
            text: {
                const hour = root.now.getHours() % 12 || 12
                return "<span style='color:" + ("" + Theme.foreground) + "'>"
                    + hour + ":" + Qt.formatDateTime(root.now, "mm")
                    + "</span> <span style='color:" + ("" + Theme.dim) + "; font-size:"
                    + Math.round(12 * root.s) + "px'>"
                    + Qt.formatDateTime(root.now, "ap").toUpperCase() + "</span>"
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6 * root.s
                cursorShape: Qt.PointingHandCursor
                onClicked: root.requestCalendar()
            }
        }
    }
}
