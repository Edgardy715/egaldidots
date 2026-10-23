pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../Singletons"

Item {
    id: root
    property int activeId: 1
    property int count: 5
    property var occupied: ({})
    property real s: 1
    property bool integrated: false
    property bool animateChanges: true
    property string style: "numbers"
    property real availableWidth: 320
    property int hoverId: 0
    onVisibleChanged: if (!visible) {
        hoverId = 0
        root.finishResize()
        lens.lensX = lens.targetX
        lens.velocityX = 0
    }
    function finishResize() {
        resizeBehavior.enabled = false
        root.width = root.targetWidth
        root.width = Qt.binding(() => root.targetWidth)
        resizeBehavior.enabled = Qt.binding(() => root.visible && root.animateChanges && !Flags.reduceMotion)
    }
    signal requestWorkspaces()
    signal workspaceRequested(int id)
    onActiveIdChanged: hoverId = 0
    readonly property real navWidth: (integrated ? 40 : 68) * s
    readonly property real slot: Math.min((style === "numbers" ? (integrated ? 28 : 38) : (integrated ? 22 : 24)) * s, Math.max(19 * s, (availableWidth - navWidth - 8 * s) / count))
    readonly property real inset: 4 * s
    readonly property real targetWidth: navWidth + count * slot + inset * 2
    readonly property bool fits: count > 0 && targetWidth <= availableWidth
    width: targetWidth
    Behavior on width {
        id: resizeBehavior
        enabled: root.visible && root.animateChanges && !Flags.reduceMotion
        SmoothedAnimation { velocity: -1; duration: Motion.morph }
    }
    onAnimateChangesChanged: if (!animateChanges) root.finishResize()
    height: 48 * s
    visible: fits

    Item {
        x: root.navWidth
        y: 5 * root.s
        width: root.width - x
        height: 38 * root.s
        PillMaterial { visible: !root.integrated; s: root.s; morphRadius: parent.height / 2; mode: "lateral" }
    }

    Item {
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: (root.integrated ? 36 : 44) * root.s
        height: width
        PillMaterial { visible: !root.integrated; s: root.s; morphRadius: parent.height / 2; mode: "lateral" }
        Rectangle {
            anchors.fill: parent
            visible: !root.integrated || navHit.containsMouse
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
        visible: root.style === "numbers"
        objectName: "workspaceLens"
        readonly property int destination: root.hoverId > 0 ? root.hoverId : Math.max(1, root.activeId)
        readonly property real targetX: Math.min(root.width - lens.width,
            root.navWidth + root.inset + (destination - 1) * root.slot + (root.slot - lens.width) / 2)
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
        y: (root.height - height) / 2
        width: (root.style === "numbers"
            ? (root.integrated ? Math.min(28, root.slot / root.s) : 46) : 20) * root.s
        height: width
        radius: height / 2
        transform: Scale {
            origin.x: lens.width / 2; origin.y: lens.height / 2
            xScale: 1 + lens.stretch / lens.width
            yScale: 1 - lens.stretch / (lens.height * 4)
        }
        layer.enabled: !root.integrated
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha(Theme.accent, 0.60)
            shadowBlur: 0.75
            shadowVerticalOffset: 2 * root.s
        }
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.cardTop, root.integrated ? 0.35 : 0.92) }
            GradientStop { position: 0.28; color: Qt.alpha(Theme.accent, root.integrated ? 0.18 : 0.40) }
            GradientStop { position: 0.76; color: Qt.alpha(Theme.accent, root.integrated ? 0.34 : 0.85) }
            GradientStop { position: 1; color: Qt.alpha(Theme.accent, root.integrated ? 0.18 : 0.36) }
        }
        border.width: Theme.borderHairline
        border.color: Qt.alpha(Theme.accent, root.integrated ? 0.26 : 0.70)
        FrameAnimation {
            id: lensMotion
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
                if (root.style === "pacman") {
                    pacman.chewPhase = (pacman.chewPhase + dt / 0.24) % 1
                    if (Math.abs(lens.velocityX) > 10) pacman.facingLeft = lens.velocityX < 0
                }
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
                    root.finishResize()
                    lens.lensX = lens.targetX
                    lens.velocityX = 0
                }
            }
        }
    }

    Shape {
        id: pacman
        objectName: "workspacePacman"
        property real chewPhase: 0
        property bool facingLeft: false
        readonly property bool chewing: visible && lensMotion.running
        property real mouthAngle: chewing ? 4 + 40 * (0.5 + 0.5 * Math.cos(chewPhase * 2 * Math.PI)) : 18
        Behavior on mouthAngle {
            enabled: !pacman.chewing && pacman.visible && !Flags.reduceMotion
            NumberAnimation { duration: 90 * Motion.mult; easing.type: Easing.OutCubic }
        }
        transform: Scale { origin.x: pacman.width / 2; xScale: pacman.facingLeft ? -1 : 1 }
        visible: root.style === "pacman"
        x: lens.x + (lens.width - width) / 2
        y: (root.height - height) / 2
        width: 20 * root.s; height: width
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: visible
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha(Theme.accent, 0.90)
            shadowBlur: 0.8
            blurMax: 16
        }
        ShapePath {
            strokeWidth: 0
            fillColor: Theme.accent
            PathAngleArc { centerX: 10 * root.s; centerY: 10 * root.s; radiusX: 9 * root.s; radiusY: 9 * root.s; startAngle: pacman.mouthAngle; sweepAngle: 360 - 2 * pacman.mouthAngle; moveToStart: true }
            PathLine { x: 10 * root.s; y: 10 * root.s }
            PathLine { x: (10 + 9 * Math.cos(pacman.mouthAngle * Math.PI / 180)) * root.s; y: (10 + 9 * Math.sin(pacman.mouthAngle * Math.PI / 180)) * root.s }
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
                readonly property real exposure: Math.max(0, Math.min(1,
                    (root.width - root.navWidth - root.inset - x - root.slot * 0.75) / (root.slot * 0.25)))
                opacity: exposure
                enabled: exposure > 0.99
                readonly property var workspaceState: root.occupied[wsId] || ({ occupied: false, urgent: false })
                readonly property real centerDistance: Math.abs(lens.x + lens.width / 2
                    - (root.navWidth + root.inset + x + width / 2))
                readonly property real highlight: Math.max(0, 1 - centerDistance / root.slot)
                readonly property real coverage: Math.max(0, Math.min(1,
                    (lens.width / 2 + 6 * root.s - centerDistance) / (10 * root.s)))
                width: root.slot
                height: root.height

                Text {
                    visible: root.style === "numbers"
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
                    id: workspaceMark
                    objectName: "workspaceMark-" + cell.wsId
                    layer.enabled: visible && root.style !== "pacman"
                        && (cell.highlight > 0.01 || cell.workspaceState.urgent || hit.containsMouse)
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Qt.alpha(Theme.accent, 0.85)
                        shadowBlur: 0.8
                        blurMax: 12
                    }
                    visible: root.style !== "numbers"
                    anchors.centerIn: parent
                    width: (root.style === "bars" ? 4 : root.style === "capsules" ? 6 + 14 * cell.highlight : root.style === "pacman" ? 4 : 6 + 4 * cell.highlight) * root.s
                    height: (root.style === "bars" ? 7 + 13 * cell.highlight : root.style === "capsules" ? 6 : root.style === "pacman" ? 4 : 6 + 4 * cell.highlight) * root.s
                    radius: Math.min(width, height) / 2
                    color: cell.workspaceState.urgent || cell.highlight > 0.5 ? Theme.accent : Theme.foreground
                    opacity: root.style === "pacman" ? (1 - cell.highlight) * (cell.workspaceState.occupied ? 0.8 : 0.35)
                        : hit.containsMouse || cell.workspaceState.urgent ? 1 : Math.max(cell.workspaceState.occupied ? 0.65 : 0.25, cell.highlight)
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.style === "numbers"
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
                    onActiveFocusChanged: { if (activeFocus) root.hoverId = cell.wsId; else if (root.hoverId === cell.wsId) root.hoverId = 0 }
                    onEntered: root.hoverId = cell.wsId
                    onExited: if (root.hoverId === cell.wsId) root.hoverId = 0
                    onClicked: root.workspaceRequested(cell.wsId)
                }
            }
        }
    }
}
