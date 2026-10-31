import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../Singletons"
import "../components"
import "../Singletons/UpdateText.js" as UpdateText

// One update source: a tonal surface with state pill, action and a bounded package list.
Rectangle {
    id: card
    required property string sourceKey
    required property string title
    required property string hint
    required property var status
    property bool checked: false
    property bool checking: false
    property bool busy: false
    property bool motionAllowed: true
    property int order: 0
    property bool expanded: false
    // Install state for this source: live progress while it runs, then its last result.
    property bool installing: false
    property bool cancelling: false
    property var progress: ({})
    property var outcome: null
    property bool installable: false
    signal installRequested()
    signal cancelRequested()

    readonly property var packages: status.packages || []
    readonly property bool unsupported: status.supported === false
    readonly property bool failed: !unsupported && !!status.error
    readonly property bool held: !failed && !!status.blocked
    readonly property bool installFailed: !installing && !!outcome && outcome.result === "error"
    readonly property bool pending: !failed && !unsupported && status.count > 0
    readonly property real fraction: UpdateText.fraction(progress)
    readonly property bool committed: installing && UpdateText.committed(progress)
    readonly property string stateText: installing ? (cancelling ? qsTr("Cancelando…") : qsTr("Actualizando"))
        : installFailed ? qsTr("Sin completar")
        : unsupported ? qsTr("No instalado")
        : failed ? UpdateText.checkPill(status.error)
        : checking && !checked ? qsTr("Comprobando…")
        : !checked ? qsTr("Sin comprobar")
        : held && !(status.count > 0) ? UpdateText.blockedPill(status)
        : status.count === 1 ? qsTr("1 pendiente") : status.count > 0 ? qsTr("%1 pendientes").arg(status.count) : qsTr("Al día")
    // One sentence under the title row: live phase, last result or why the source is paused.
    readonly property string message: installing ? UpdateText.phase(progress) + (committed ? " · " + qsTr("No apagues el equipo.") : "")
        : outcome ? UpdateText.outcome(outcome, sourceKey)
        : failed ? UpdateText.checkError(status.error)
        : held ? UpdateText.blocked(status)
        : sourceKey === "shell" && status.dirty ? UpdateText.blocked({blocked: "dirty"}) : ""
    readonly property color tone: failed || installFailed ? Theme.error : pending || installing ? Theme.accent : Theme.iconSecondary

    // Entrance: staggered fade + short rise, replayed when the page becomes visible.
    property bool shown: true
    opacity: shown ? 1 : 0
    transform: Translate { y: card.shown ? 0 : 8; Behavior on y { enabled: card.motionAllowed; NumberAnimation { duration: Motion.emphasized; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedDecelCurve } } }
    Behavior on opacity { enabled: card.motionAllowed; NumberAnimation { duration: Motion.emphasized; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedDecelCurve } }
    Timer { id: entrance; interval: Motion.stagger(card.order); onTriggered: card.shown = true }
    onVisibleChanged: {
        if (visible && !Flags.reduceMotion) { shown = false; entrance.restart() }
        else { entrance.stop(); shown = true }
    }

    implicitHeight: body.implicitHeight + 32
    radius: 14
    color: Qt.alpha(Theme.foreground, pending ? Theme.alphaFaint + 0.015 : Theme.alphaGhost + 0.01)
    border.width: 1
    border.color: Qt.alpha(pending ? Theme.accent : Theme.foreground, pending ? 0.28 : Theme.alphaGhost)
    Behavior on color { enabled: card.visible; ColorAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
    Behavior on border.color { enabled: card.visible; ColorAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 10
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            // Fixed slot: the confirmation signal while checking or on a result, a dot otherwise.
            Item {
                Layout.preferredWidth: 26; Layout.preferredHeight: 26; Layout.alignment: Qt.AlignVCenter
                ConfirmationIndicator {
                    id: sourceSignal
                    anchors.fill: parent; s: 26 / 48
                    progress: Math.max(0, card.fraction)
                    status: !card.visible ? "" : card.installing ? (card.fraction >= 0 ? "progress" : "busy")
                        : card.outcome ? (card.outcome.result === "success" ? "success" : card.outcome.result === "cancelled" ? "cancelled" : "error")
                        : card.checking && !card.unsupported ? "busy" : card.failed ? "error"
                        : card.checked && !card.unsupported && !card.held && !card.pending && !card.busy ? "success" : ""
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 8; height: 8; radius: 4
                    color: card.pending ? Theme.accent : Qt.alpha(Theme.foreground, Theme.alphaHairline)
                    opacity: sourceSignal.status === "" ? 1 : 0
                    Behavior on opacity { enabled: card.motionAllowed; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text {
                    Layout.fillWidth: true; text: card.title; elide: Text.ElideRight
                    color: Theme.foreground; font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.fontSizeBodyLg; font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true; text: card.hint
                    textFormat: Text.PlainText; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                    color: Theme.iconSecondary; font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.fontSizeBody - 1
                }
                TapHandler { enabled: card.packages.length > 0; onTapped: card.expanded = !card.expanded }
            }
            Rectangle {
                id: pill
                objectName: "updatesState-" + card.sourceKey
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: pillLabel.implicitWidth + 20; implicitHeight: pillLabel.implicitHeight + 8
                radius: height / 2
                color: Qt.alpha(card.tone, card.pending || card.failed || card.installing || card.installFailed ? Theme.alphaChip : Theme.alphaFaint)
                Behavior on color { enabled: card.visible; ColorAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                Behavior on implicitWidth { enabled: card.motionAllowed; NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                AnimatedLabel {
                    id: pillLabel
                    anchors.centerIn: parent
                    value: card.stateText; textFormat: Text.PlainText
                    color: card.tone
                    font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody; font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
            EdotsButton {
                objectName: "updatesInstall-" + card.sourceKey
                visible: !card.installing
                text: card.installFailed ? qsTr("Reintentar") : qsTr("Actualizar")
                accent: card.installable
                enabled: !card.busy && card.installable
                Accessible.name: qsTr("%1 %2").arg(text).arg(card.title)
                onClicked: card.installRequested()
            }
            // Cancel exists only while nothing has been applied; afterwards the step must finish.
            EdotsButton {
                objectName: "updatesCancel-" + card.sourceKey
                visible: card.installing
                text: card.cancelling ? qsTr("Cancelando…") : qsTr("Cancelar")
                enabled: !card.cancelling && !!card.progress.cancellable
                Accessible.name: qsTr("Cancelar la actualización de %1").arg(card.title)
                onClicked: card.cancelRequested()
            }
        }
        AnimatedLabel {
            objectName: "updatesMessage-" + card.sourceKey
            Layout.fillWidth: true; visible: card.message.length > 0
            value: card.message; textFormat: Text.PlainText; wrapMode: Text.WordWrap
            color: card.failed || card.installFailed ? Theme.error : card.installing ? Theme.foreground : Theme.iconSecondary
            font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
            font.features: { "tnum": 1 }
        }
        EdotsButton {
            objectName: "updatesPackages-" + card.sourceKey
            visible: card.packages.length > 0
            text: card.expanded ? qsTr("Ocultar paquetes") : qsTr("Ver paquetes")
            symbol: card.expanded ? "expand_less" : "expand_more"
            Accessible.name: text + " · " + card.title
            onClicked: card.expanded = !card.expanded
        }
        Item {
            id: packagesReveal
            objectName: "updatesPackageList-" + card.sourceKey
            Layout.fillWidth: true
            readonly property real listHeight: Math.min(list.contentHeight, 232)
            implicitHeight: listHeight * reveal
            clip: true
            readonly property real targetReveal: card.expanded && card.packages.length > 0 ? 1 : 0
            property real reveal: targetReveal
            function settle() { reveal = Qt.binding(() => targetReveal) }
            onVisibleChanged: if (!visible) settle()
            Connections {
                target: card
                function onMotionAllowedChanged() { if (!card.motionAllowed) packagesReveal.settle() }
            }
            Behavior on reveal {
                enabled: card.motionAllowed
                SmoothedAnimation { duration: Motion.standardSmall + 60; velocity: -1 }
            }
            ListView {
                id: list
                width: parent.width; height: packagesReveal.listHeight
                opacity: packagesReveal.reveal; visible: packagesReveal.reveal > 0
                model: card.packages; clip: true; boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                ScrollBar.vertical: ScrollBar { policy: list.interactive ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
                delegate: RowLayout {
                    id: row
                    required property string modelData
                    readonly property var parts: /^(\S+)\s+(.*?)\s*->\s*(.+)$/.exec(modelData)
                    width: ListView.view.width - 10; height: 28; spacing: 10
                    Text {
                        Layout.fillWidth: true; elide: Text.ElideRight; textFormat: Text.PlainText
                        text: row.parts ? row.parts[1] : row.modelData
                        color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                    }
                    Text {
                        visible: !!row.parts; textFormat: Text.PlainText
                        text: row.parts ? row.parts[2] + "  →  " + row.parts[3] : ""
                        color: Theme.iconSecondary; font.family: Config.appearance.fontMonoFamily; font.pixelSize: Theme.fontSizeBody - 1
                    }
                }
            }
        }
    }
}
