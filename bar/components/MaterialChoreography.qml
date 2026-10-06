import QtQuick

Item {
    id: root
    property bool reduceMotion: false
    property int shapeshiftDuration: 820
    property int pulseRiseDuration: 250
    property int pulseFallDuration: 500
    property var emphasizedDecelCurve: [0.05, 0.7, 0.1, 1.0, 1, 1]

    property int epoch: 0
    property real sweep: -0.55
    property real pulse: 0

    function awaken() {
        if (root.reduceMotion) return
        root.epoch++
        materialSweepAnim.restart()
        materialPulseAnim.restart()
    }

    onReduceMotionChanged: {
        if (!root.reduceMotion) return
        materialSweepAnim.stop()
        materialPulseAnim.stop()
        root.sweep = -0.55
        root.pulse = 0
    }

    SequentialAnimation {
        id: materialSweepAnim
        PropertyAction { target: root; property: "sweep"; value: -0.55 }
        NumberAnimation {
            target: root
            property: "sweep"
            to: 1.28
            duration: root.shapeshiftDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.emphasizedDecelCurve
        }
    }

    SequentialAnimation {
        id: materialPulseAnim
        PropertyAction { target: root; property: "pulse"; value: 0 }
        NumberAnimation {
            target: root
            property: "pulse"
            to: 1
            duration: root.pulseRiseDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "pulse"
            to: 0
            duration: root.pulseFallDuration
            easing.type: Easing.InCubic
        }
    }
}
