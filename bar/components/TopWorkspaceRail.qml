pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "../Singletons"

Item {
    id: root
    property int activeId: 1
    property int count: 5
    property var occupied: ({})
    property real s: 1
    property real availableWidth: 320
    property int hoverId: 0
    onVisibleChanged: if (!visible) {
        hoverId = 0
        lens.lensX = lens.targetX
        lens.velocityX = 0
    }
    signal requestWorkspaces()
    signal workspaceRequested(int id)
    onActiveIdChanged: hoverId = 0
    readonly property real navWidth: 68 * s
    readonly property real slot: Math.min(38 * s, Math.max(19 * s, (availableWidth - navWidth - 8 * s) / count))
    readonly property real inset: 4 * s
    readonly property bool fits: count > 0 && width <= availableWidth
    width: navWidth + count * slot + inset * 2
    height: 48 * s
    visible: fits

    Item {
        x: root.navWidth
        y: 5 * root.s
        width: root.width - x
        height: 38 * root.s
        PillMaterial { s: root.s; morphRadius: parent.height / 2; mode: "lateral" }
    }

    Item {
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: 44 * root.s
        height: 44 * root.s
        PillMaterial { s: root.s; morphRadius: parent.height / 2; mode: "lateral" }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Theme.accent, 0.05) }
                GradientStop { position: 1; color: Qt.alpha(Theme.accent, 0.34) }
            }
            border.width: Theme.borderHairline
            border.color: Qt.alpha(Theme.accent, 0.19)
        }
        MaterialIcon {
            anchors.centerIn: parent
            iconName: "apps"
            color: navHit.containsMouse ? Theme.foreground : Theme.iconSecondary
            font.pixelSize: Theme.fontSizeBodyLg * 1.1 * root.s
            interaction: navHit.motion
        }
        MotionArea {
            id: navHit
            anchors.fill: parent
            feedbackEnabled: false
            accessibleName: qsTr("Abrir espacios de trabajo")
            onClicked: root.requestWorkspaces()
        }
    }
    Rectangle {
        id: lens
        objectName: "workspaceLens"
        readonly property int destination: root.hoverId > 0 ? root.hoverId : Math.max(1, root.activeId)
        readonly property real targetX: root.navWidth + root.inset + (destination - 1) * root.slot
            + (root.slot - 46 * root.s) / 2
        property real lensX: targetX
        property real velocityX: 0
        readonly property real distance: Math.abs(targetX - lensX)
        readonly property real stretch: Math.min(7 * root.s, Math.abs(velocityX) * 0.025)
        readonly property real travel: Math.min(1, Math.abs(velocityX) / 320)
        Component.onCompleted: lensX = targetX
        onTargetXChanged: if (Flags.reduceMotion || !root.visible) {
            lensX = targetX
            velocityX = 0
        }
        x: lensX
        y: 1 * root.s
        width: 46 * root.s
        height: 46 * root.s
        radius: height / 2
        transform: Scale {
            origin.x: lens.width / 2; origin.y: lens.height / 2
            xScale: 1 + lens.stretch / lens.width
            yScale: 1 - lens.stretch / (lens.height * 4)
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha(Theme.accent, 0.78)
            shadowBlur: 0.45
            shadowVerticalOffset: 2 * root.s
        }
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.cardTop, 0.92) }
            GradientStop { position: 0.28; color: Qt.alpha(Theme.accent, 0.40) }
            GradientStop { position: 0.76; color: Qt.alpha(Theme.accent, 0.85) }
            GradientStop { position: 1; color: Qt.alpha(Theme.accent, 0.36) }
        }
        border.width: Theme.borderHairline
        border.color: Qt.alpha(Theme.accent, 0.70)
        FrameAnimation {
            running: root.visible && !Flags.reduceMotion
                && (lens.distance > 0.5 || Math.abs(lens.velocityX) > 10)
            onTriggered: {
                const dt = Math.min(0.05, frameTime)
                const omega = root.hoverId > 0 ? 28 : 23
                const damping = 0.94
                const offset = lens.lensX - lens.targetX
                const speed = lens.velocityX
                const damped = omega * Math.sqrt(1 - damping * damping)
                const phase = damped * dt
                const decay = Math.exp(-damping * omega * dt)
                lens.lensX = lens.targetX + decay * (offset * Math.cos(phase)
                    + (speed + damping * omega * offset) / damped * Math.sin(phase))
                lens.velocityX = decay * (speed * Math.cos(phase)
                    - (omega * omega * offset + damping * omega * speed) / damped * Math.sin(phase))
                if (lens.distance < 0.5 && Math.abs(lens.velocityX) < 10) {
                    lens.lensX = lens.targetX
                    lens.velocityX = 0
                }
            }
        }
        Connections {
            target: Flags
            function onReduceMotionChanged() {
                if (Flags.reduceMotion) {
                    lens.lensX = lens.targetX
                    lens.velocityX = 0
                }
            }
        }
    }

    Row {
        x: root.navWidth + root.inset
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: root.count
            delegate: Item {
                id: cell
                required property int index
                readonly property int wsId: index + 1
                readonly property var workspaceState: root.occupied[wsId] || ({ occupied: false, urgent: false })
                readonly property real centerDistance: Math.abs(lens.x + lens.width / 2
                    - (root.navWidth + root.inset + x + width / 2))
                readonly property real highlight: Math.max(0, 1 - centerDistance / root.slot)
                readonly property real coverage: Math.max(0, Math.min(1,
                    (lens.width / 2 + 6 * root.s - centerDistance) / (10 * root.s)))
                width: root.slot
                height: root.height

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    text: cell.wsId
                    color: cell.workspaceState.urgent && cell.highlight < 0.5 && !hit.containsMouse
                        ? Theme.accent : root.hoverId > 0 && cell.wsId === root.activeId && root.hoverId !== root.activeId
                            ? Theme.accent : Qt.alpha(Theme.foreground, hit.containsMouse ? 1
                                : Math.max(cell.workspaceState.occupied ? 0.7 : 0.36, cell.highlight))
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSizeBodyLg * root.s
                    font.weight: Font.DemiBold
                    opacity: 1 - lens.travel * cell.coverage
                    scale: hit.pressed ? 0.94 : 1
                    Behavior on scale { NumberAnimation { duration: Motion.fast } }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 33 * root.s
                    width: 3 * root.s
                    height: width
                    radius: width / 2
                    color: Theme.accent
                    opacity: cell.workspaceState.occupied ? 1 - cell.coverage : 0
                }
                MotionArea {
                    id: hit
                    anchors.fill: parent
                    feedbackEnabled: false
                    accessibleName: qsTr("Ir al escritorio %1").arg(cell.wsId)
                    onEntered: root.hoverId = cell.wsId
                    onExited: if (root.hoverId === cell.wsId) root.hoverId = 0
                    onClicked: root.workspaceRequested(cell.wsId)
                }
            }
        }
    }
}
