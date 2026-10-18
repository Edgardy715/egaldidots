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
    readonly property real checkProgress: emblem.drawProgress
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
    Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.standardSmall; easing.type: Motion.easeStandard } }
    ConfirmationIndicator {
        id: emblem
        width: 96 * root.s; height: width
        anchors.horizontalCenter: parent.horizontalCenter
        y: 24 * root.s
        s: root.s
        status: root.success ? "success" : root.failed ? "error" : root.busy ? "busy" : ""
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
}
