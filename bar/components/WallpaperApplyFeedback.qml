import QtQuick
import QtQuick.Shapes
import "../Singletons"

Item {
    id: root
    property real s: 1
    property string phase: ""
    property string errorText: ""
    property bool allowed: true
    property string displayedPhase: ""
    property real checkProgress: 0
    readonly property bool shown: allowed && phase.length > 0
    readonly property bool success: displayedPhase === "done"
    readonly property bool failed: displayedPhase === "error"
    readonly property bool busy: displayedPhase === "preparing" || displayedPhase === "transition"
    readonly property color confirmationGreen: "#34c759"
    width: 204 * s; height: (204 + Math.max(0, Flags.fontScale - 1) * 48) * s
    opacity: shown ? 1 : 0
    visible: opacity > 0.001
    scale: Flags.reduceMotion ? 1 : 0.9 + 0.1 * opacity
    Accessible.role: Accessible.AlertMessage
    Accessible.name: failed ? errorText : success ? qsTr("Fondo de pantalla aplicado") : qsTr("Aplicando fondo de pantalla")
    onPhaseChanged: {
        if (phase.length > 0) displayedPhase = phase
    }
    onDisplayedPhaseChanged: {
        checkDraw.stop()
        checkProgress = 0
        if (displayedPhase === "done") checkDraw.restart()
    }
    Connections {
        target: Flags
        function onReduceMotionChanged() { if (Flags.reduceMotion && root.success) checkDraw.complete() }
    }
    Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.standardSmall; easing.type: Motion.easeStandard } }
    Item {
        id: emblem
        width: 96 * root.s; height: width
        anchors.horizontalCenter: parent.horizontalCenter
        y: 24 * root.s
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 3 * root.s
            border.color: Qt.alpha(Theme.foreground, 0.12)
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.confirmationGreen
            opacity: root.success ? 1 : 0
            scale: Flags.reduceMotion ? 1 : 0.8 + 0.2 * opacity
            Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.standard; easing.type: Motion.easeStandard } }
        }
        Shape {
            id: progressRing
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: root.success || root.failed ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
            RotationAnimation on rotation {
                from: 0; to: 360; duration: 1100; loops: Animation.Infinite
                running: root.busy && root.visible && root.allowed && !Flags.reduceMotion
            }
            ShapePath {
                strokeWidth: 3 * root.s
                strokeColor: Theme.accent
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: 48 * root.s; centerY: 48 * root.s
                    radiusX: 45 * root.s; radiusY: 45 * root.s
                    startAngle: -90; sweepAngle: 285
                }
            }
        }
        MaterialIcon {
            anchors.centerIn: parent
            iconName: root.failed ? "priority_high" : "wallpaper"
            color: root.failed ? Theme.error : Theme.foreground
            font.pixelSize: 32 * root.s
            opacity: root.success ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            visible: root.success
            ShapePath {
                strokeWidth: 6 * root.s
                strokeColor: "#062b13"
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                trim.end: root.checkProgress
                startX: 25 * root.s; startY: 48 * root.s
                PathLine { x: 41 * root.s; y: 64 * root.s }
                PathLine { x: 72 * root.s; y: 32 * root.s }
            }
        }
    }
    Text {
        anchors.top: emblem.bottom
        anchors.topMargin: 16 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 24 * root.s
        horizontalAlignment: Text.AlignHCenter
        text: root.success ? qsTr("Fondo listo") : root.failed ? qsTr("No se completó") : root.displayedPhase === "preparing" ? qsTr("Preparando…") : qsTr("Aplicando…")
        color: Theme.foreground
        font.family: Theme.font
        font.pixelSize: Theme.fontSizeBodyLg * root.s
        font.weight: Font.DemiBold
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 167 * root.s
        width: parent.width - 24 * root.s
        visible: root.failed
        horizontalAlignment: Text.AlignHCenter
        maximumLineCount: 2
        elide: Text.ElideRight
        wrapMode: Text.Wrap
        text: root.errorText
        color: Theme.iconSecondary
        font.family: Theme.font
        font.pixelSize: Theme.fontSizeSmall * root.s
    }
    SequentialAnimation {
        id: checkDraw
        PauseAnimation { duration: Flags.reduceMotion ? 0 : Motion.press }
        NumberAnimation { target: root; property: "checkProgress"; to: 1; duration: Flags.reduceMotion ? 0 : Motion.emphasized; easing.type: Motion.easeStandard }
    }
}
