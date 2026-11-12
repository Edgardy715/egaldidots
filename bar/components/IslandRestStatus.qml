import QtQuick
import "../"
import "../Singletons"

/** The compact status section shown before the optional media chip. */
Row {
    id: root

    property real s: 1
    property real coreH: 38
    property bool capsLockOn: false
    property date now: Regional.now()
    signal requestCalendar()
    property string activityText: ""
    property string recordingPhase: ""
    property int recordingCountdown: 0

    readonly property bool workspaceAnimating: workspaceFlash.shown || workspaceFlash.width > 0.01

    spacing: 0

    function flashWorkspace(number) {
        workspaceFlash.direction = number < workspaceFlash.number ? -1 : 1
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
        width: shown ? 24 * root.s : 0
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
        // The badge leaves before the slot closes: it fades and shrinks in the
        // middle of the narrowing gap, so the clock never slides over a digit.
        readonly property real reveal: {
            const t = Math.max(0, Math.min(1, (width / (24 * root.s) - 0.55) / 0.45))
            return t * t * (3 - 2 * t)
        }
        property int direction: 1
        // Just the number: no capsule inside the capsule, so nothing collides with the rim.
        Item {
            anchors.fill: parent
            opacity: workspaceFlash.reveal
            scale: 0.8 + 0.2 * workspaceFlash.reveal
            visible: opacity > 0.001
            Accessible.role: Accessible.StaticText
            Accessible.name: I18n.tr("Escritorio %1").arg(workspaceFlash.number)
            // Only the old and the new number roll, never every desktop between them;
            // the first number of a flash appears without a roll.
            ClockReel {
                anchors.centerIn: parent
                text: String(workspaceFlash.number)
                widthSample: "0"
                direction: workspaceFlash.direction
                motionEnabled: !Flags.reduceMotion && workspaceFlash.reveal > 0.01
                font.family: Theme.fontDisplay
                font.pixelSize: 15 * root.s
                font.weight: Font.DemiBold
                color: Theme.accent
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
        opacity: root.capsLockOn ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { Anim { type: Anim.FastEffects } }
    }
    Item {
        width: root.capsLockOn ? 6 * root.s : 0; height: 1
        Behavior on width { enabled: !Flags.reduceMotion; SmoothedAnimation { velocity: -1; duration: Motion.standardSmall } }
    }

    IslandActivityChip {
        id: activityChip
        s: root.s; coreH: root.coreH
        label: root.activityText
        recordingPhase: root.recordingPhase
        recordingCountdown: root.recordingCountdown
    }

    Item {
        id: clockArea
        width: clockText.implicitWidth
        height: root.coreH

        Row {
            id: clockText
            scale: clockHit.motion.visualScale
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1.5 * root.s
            height: root.coreH
            property font clockFont: Qt.font({family: Theme.fontDisplay, pixelSize: Theme.fontSizeHeadline * root.s, weight: Font.DemiBold, underline: clockHit.activeFocus, features: Theme.fontNumeric})
            ClockReel {
                objectName: "clockHours"
                // Una hora de un dígito no reserva el hueco de dos: «9:41», no «9 :41».
                widthSample: text.length > 1 ? "00" : "0"
                width: implicitWidth; height: root.coreH
                font: clockText.clockFont
                text: String(root.now.getHours() % 12 || 12)
            }
            Text {
                height: root.coreH
                verticalAlignment: Text.AlignVCenter
                text: ":"; font: clockText.clockFont; color: Theme.foreground
            }
            ClockReel {
                objectName: "clockMinutes"
                width: implicitWidth; height: root.coreH
                font: clockText.clockFont
                text: Qt.formatDateTime(root.now, "mm")
            }
            TextMetrics { id: amMetrics; font: periodText.font; text: "AM" }
            TextMetrics { id: pmMetrics; font: periodText.font; text: "PM" }
            Text {
                id: periodText
                width: Math.max(amMetrics.advanceWidth, pmMetrics.advanceWidth) + 4 * root.s
                height: root.coreH
                leftPadding: 4 * root.s
                verticalAlignment: Text.AlignVCenter
                text: Qt.formatDateTime(root.now, "ap").toUpperCase()
                color: Theme.iconSecondary
                font.family: Theme.fontDisplay
                font.pixelSize: 12 * root.s
                font.weight: Font.DemiBold
                font.underline: clockHit.activeFocus
            }
        }
        MotionArea {
            id: clockHit
            objectName: "clockCalendarHit"
            feedbackEnabled: false
            accessibleName: I18n.tr("Abrir calendario")
            anchors.fill: parent
            anchors.margins: -6 * root.s
            cursorShape: Qt.PointingHandCursor
            onClicked: root.requestCalendar()
        }
    }
}
