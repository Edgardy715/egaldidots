import QtQuick
import Quickshell.Widgets
import "../fluid" as Fluid
import "../Singletons"

/** Shared droplet engine. Motion is integrated in right-facing coordinates;
 * leftSide reflects geometry only, never text or controls. */
Item {
    id: root

    required property Item body
    property bool open: false
    property bool expanded: false
    property bool bodyBusy: false
    property real s: 1
    property string screenName: ""
    property bool leftSide: false
    property string surfaceName: "media"
    property size surfaceSize: IslandGeometry.mediaSurface
    property Component compactContent
    property real compactWidth: collapsedW
    readonly property var surfaceItem: surfaceHost.loadedItem
    readonly property real visualX: leftSide ? 2 * bodyX + bodyW - xPos - wPos : xPos
    readonly property real visualCapX: leftSide ? bodyX - captureExtra + bodyRadius : capX
    readonly property bool pressed: compactHit.enabled && compactHit.pressed && compactHit.containsMouse
    signal requestToggle()

    readonly property real bodyX: body ? body.x : 0
    readonly property real bodyY: body ? body.y : 0
    readonly property real bodyW: body ? body.width : 0
    readonly property real bodyH: body ? body.height : IslandGeometry.restHeight * s
    readonly property real bodyRadius: bodyH / 2
    readonly property real moduleW: 218 * s
    readonly property real moduleH: IslandGeometry.restHeight * s
    readonly property real collapsedW: 42 * s
    readonly property real cardW: Math.max(280 * s,
        Math.min(surfaceSize.width * s, (leftSide ? bodyX - gap : width - cardX) - 12 * s))
    readonly property real cardH: surfaceSize.height * s
    readonly property real gap: 12 * s
    readonly property real cardX: bodyX + bodyW + gap
    readonly property real cardY: bodyY
    readonly property real capX: bodyX + bodyW + captureExtra - bodyRadius
    readonly property real capY: bodyY + bodyRadius

    property string phase: "idle"
    property real xPos: 0
    property real yPos: 0
    property real wPos: 34 * s
    property real hPos: 34 * s
    property real targetX: 0
    property real targetY: 0
    property real targetW: 34 * s
    property real targetH: 34 * s
    property real vx: 0
    property real vy: 0
    property real vw: 0
    property real vh: 0
    property real captureExtra: 0
    property real captureTarget: 0
    property real captureV: 0
    property bool concealed: false
    property bool bond: false
    property bool hovered: false

    readonly property bool active: phase !== "idle" && !concealed
    readonly property bool transitioning: phase !== "idle"
    readonly property real dropRadius: Math.min(wPos, hPos) / 2
    readonly property real stretch: Math.hypot(xPos + wPos / 2 - capX, yPos + hPos / 2 - capY)
        / Math.max(1, bodyRadius + dropRadius)
    readonly property bool joined: active && bond && !bodyBusy
    readonly property real titleProgress: expanded || cardFraction > 0.05 ? 0
        : Math.max(0, Math.min(1, (wPos - 100 * s) / (80 * s)))
    readonly property real cardFraction: Math.max(0, Math.min(1,
        (hPos - moduleH) / Math.max(1, cardH - moduleH)))
    readonly property real cardContentProgress: Math.max(0, Math.min(1,
        (cardFraction - 0.45) / 0.35))
    readonly property real contentExposure: {
        const center = Math.max(0, Math.min(1,
            (xPos + wPos / 2 - bodyX - bodyW) / Math.max(1, dropRadius + 3 * s)))
        const separation = Math.max(0, Math.min(1, (stretch - 0.75) / 0.53))
        return bodyBusy ? center : Math.min(center, separation)
    }
    readonly property real cardRadius: Math.min(wPos, hPos) / 2 * (1 - cardFraction)
        + 24 * s * cardFraction
    // Start the trailing contraction while the return still has velocity.
    // The receiving cap must cover the compact drop before it can be hidden.
    readonly property bool coveredByBody: wPos <= moduleH + 3 * s
        && hPos <= moduleH + 3 * s
        && Math.hypot(xPos + wPos / 2 - capX, yPos + hPos / 2 - capY)
            + Math.max(wPos, hPos) / 2 <= bodyRadius + 3 * s
        && contentExposure < 0.01
    readonly property bool settled: Math.abs(targetX - xPos) < 0.08
        && Math.abs(targetY - yPos) < 0.08 && Math.abs(targetW - wPos) < 0.08
        && Math.abs(targetH - hPos) < 0.08 && Math.abs(captureTarget - captureExtra) < 0.08
    function retarget(nextPhase: string, x: real, y: real, w: real, h: real): void {
        phase = nextPhase
        concealed = false
        targetX = x; targetY = y; targetW = w; targetH = h
        if (nextPhase !== "retornando" && nextPhase !== "absorbiendo") captureTarget = 0
        if (Flags.reduceMotion) {
            xPos = x; yPos = y; wPos = w; hPos = h
            vx = 0; vy = 0; vw = 0; vh = 0
            if (nextPhase === "retornando") {
                concealed = true
                captureExtra = 0; captureV = 0
                bond = false
                phase = "idle"
            }
        }
    }

    function start(): void {
        captureExtra = expanded || Flags.reduceMotion ? 0 : 6 * s
        captureTarget = 0; captureV = 0
        xPos = bodyX + bodyW - 18 * s
        yPos = bodyY + (bodyH - 34 * s) / 2
        wPos = 34 * s; hPos = 34 * s
        vx = 0; vy = 0; vw = 0; vh = 0
        if (expanded) {
            retarget("media", cardX, cardY, cardW, cardH)
        } else {
            retarget("nacimiento", xPos, yPos, wPos, hPos)
            birthTimer.restart()
        }
    }

    function close(): void {
        if (phase === "idle" || phase === "retornando" || phase === "absorbiendo") return
        captureTarget = 0
        retarget("retornando", bodyX + bodyW - 20 * s,
                 bodyY + (bodyH - IslandGeometry.restHeight * s) / 2,
                 IslandGeometry.restHeight * s, IslandGeometry.restHeight * s)
    }

    function syncHoverSize(): void {
        if (phase === "idle") return
        if (expanded) {
            birthTimer.stop()
            retarget("media", cardX, cardY, cardW, cardH)
            return
        }
        if (phase === "nacimiento" || phase === "retornando" || phase === "absorbiendo") return
        const compactW = hovered ? moduleW : compactWidth
        retarget("companion", bodyX + bodyW + gap, bodyY, compactW, moduleH)
    }

    function spring(value: real, velocity: real, target: real, dt: real): var {
        let omega = 16
        let damping = 0.92
        if (phase === "separando") { omega = 11; damping = 0.84 }
        else if (phase === "retornando" || phase === "absorbiendo") { omega = 15.5; damping = 0.98 }
        if (Flags.reduceMotion) { omega = 28; damping = 1.15 }
        const a = omega * omega * (target - value) - 2 * damping * omega * velocity
        velocity += a * dt
        value += velocity * dt
        if (Math.abs(target - value) < 0.08 && Math.abs(velocity) < 0.08) return [target, 0]
        return [value, velocity]
    }

    function updateBond(): void {
        if (!active || bodyBusy) { bond = false; return }
        bond = bond ? stretch < 1.30 : stretch < 1.02
    }

    onOpenChanged: {
        if (open && (phase === "idle" || phase === "absorbiendo")) Qt.callLater(() => {
            if (root.open && (root.phase === "idle" || root.phase === "absorbiendo")) root.start()
        })
        else if (open && phase === "retornando")
            retarget(expanded ? "media" : "companion",
                     bodyX + bodyW + gap, bodyY,
                     expanded ? cardW : compactWidth,
                     expanded ? cardH : moduleH)
        else if (open) syncHoverSize()
        else close()
    }
    Component.onCompleted: {
        if (open && phase === "idle") start()
    }
    onExpandedChanged: if (open) syncHoverSize()
    onWidthChanged: if (expanded) syncHoverSize()
    function followBody(): void {
        if (phase === "retornando") {
            targetX = bodyX + bodyW - 20 * s
            targetY = bodyY + (bodyH - moduleH) / 2
        } else if (phase === "companion" || phase === "media") syncHoverSize()
    }
    onBodyXChanged: followBody()
    onBodyWChanged: followBody()
    onBodyYChanged: followBody()
    onBodyHChanged: followBody()
    onBodyBusyChanged: updateBond()
    onHoveredChanged: syncHoverSize()
    onCompactWidthChanged: syncHoverSize()

    Timer {
        id: birthTimer
        interval: Flags.reduceMotion ? 0 : 32
        repeat: false
        onTriggered: if (root.phase === "nacimiento") {
            root.retarget("separando", root.bodyX + root.bodyW + root.gap,
                          root.bodyY, root.compactWidth, root.moduleH)
            if (Flags.reduceMotion) {
                root.phase = "companion"
                root.bond = false
            } else root.vx += 36 * root.s
        }
    }

    FrameAnimation {
        running: !Flags.reduceMotion && root.phase !== "idle"
            && (!root.settled || root.phase === "separando"
                || root.phase === "retornando" || root.phase === "absorbiendo")
        onTriggered: root.advanceMotion(Math.min(0.032, frameTime))
    }

    function advanceMotion(dt: real): void {
        let next = root.spring(root.xPos, root.vx, root.targetX, dt); root.xPos = next[0]; root.vx = next[1]
        next = root.spring(root.yPos, root.vy, root.targetY, dt); root.yPos = next[0]; root.vy = next[1]
        next = root.spring(root.wPos, root.vw, root.targetW, dt); root.wPos = next[0]; root.vw = next[1]
        next = root.spring(root.hPos, root.vh, root.targetH, dt); root.hPos = next[0]; root.vh = next[1]
        root.updateBond()
        if (root.phase === "retornando" && root.stretch < 1.10) root.captureTarget = 20 * root.s
        next = root.spring(root.captureExtra, root.captureV, root.captureTarget, dt)
        root.captureExtra = next[0]; root.captureV = next[1]
        if (root.phase === "separando" && root.settled) {
            root.phase = "companion"
        } else if (root.phase === "retornando" && root.coveredByBody) {
            root.concealed = true
            root.captureTarget = 0
            root.phase = "absorbiendo"
        } else if (root.phase === "absorbiendo" && root.settled) {
            root.phase = "idle"
            root.bond = false
        }
    }

    Fluid.FluidMetaballBridge {
        z: 0
        visible: root.joined
        x1: root.visualCapX; y1: root.capY; r1: root.bodyRadius
        x2: root.visualX + root.wPos / 2; y2: root.yPos + root.hPos / 2; r2: root.dropRadius
        waist: 0.42
        fill: Qt.lighter(Theme.cardBot, 1.10)
    }

    Item {
        id: module
        z: 1
        x: root.visualX; y: root.yPos; width: root.wPos; height: root.hPos
        visible: root.active

        PillMaterial {
            anchors.fill: parent
            s: root.s
            morphRadius: root.cardRadius
            materialAwake: true
            materialAccent: Theme.accent
            mode: root.surfaceName
            suppressEdge: root.joined || root.contentExposure < 0.3
        }

        Loader {
            anchors.fill: parent
            sourceComponent: root.compactContent
        }

        PillSurfaceHost {
            id: surfaceHost
            z: 2
            open: root.expanded
            surface: root.expanded ? root.surfaceName : ""
            scaleFactor: root.s
            morphCloseness: root.cardContentProgress
            morphRadius: root.cardRadius
            surfaceRadius: root.cardRadius
            screenName: root.screenName
            bgColor: "transparent"
            onRequestClose: root.requestToggle()
        }

        MotionArea {
            id: compactHit
            accessibleName: qsTr("Abrir panel multimedia")
            feedbackEnabled: false
            anchors.fill: parent
            enabled: !root.expanded && root.cardFraction < 0.05
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.hovered = true
            onExited: root.hovered = false
            onClicked: root.requestToggle()
        }
    }
}
