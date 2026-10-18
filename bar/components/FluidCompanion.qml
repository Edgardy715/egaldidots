import QtQuick
import Qt5Compat.GraphicalEffects
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
    property bool centered: false
    property string surfaceName: "media"
    property string artUrl: ""
    property var artworkTransition: null
    property bool mediaPlaying: false
    property size surfaceSize: IslandGeometry.mediaSurface
    property Component compactContent
    property Component expandedContent
    property bool retainExpandedContent: false
    property bool asynchronousExpandedContent: false
    property real compactWidth: collapsedW
    readonly property var surfaceItem: expandedContent
        ? (expandedLoader.status === Loader.Ready ? expandedLoader.item : null) : surfaceHost.loadedItem
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
    readonly property real returnH: centered ? Math.min(moduleH, bodyH) : moduleH
    readonly property real returnW: centered ? Math.min(cardW, Math.max(returnH, bodyW - (bodyH - returnH))) : moduleH
    readonly property real cardW: centered ? Math.min(surfaceSize.width * s, width - 32 * s)
        : Math.max(280 * s, Math.min(surfaceSize.width * s,
            (leftSide ? bodyX - gap : width - cardX) - 12 * s))
    readonly property real cardH: centered ? Math.min(surfaceSize.height * s, height - 48 * s)
        : surfaceSize.height * s
    readonly property real gap: 12 * s
    readonly property real cardX: centered ? (width - cardW) / 2 : bodyX + bodyW + gap
    readonly property real cardY: centered ? (height - cardH) / 2 : bodyY
    readonly property real capX: centered ? bodyX + bodyW / 2 : bodyX + bodyW + captureExtra - bodyRadius
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
    readonly property real neckWaist: {
        const tension = Math.max(0, Math.min(1, (stretch - 1.02) / (1.30 - 1.02)))
        return 0.42 * (1 - tension * tension * (3 - 2 * tension))
    }
    readonly property real edgeExposure: joined ? 1 - neckWaist / 0.42 : 1
    readonly property real titleProgress: expanded || cardFraction > 0.05 ? 0
        : Math.max(0, Math.min(1, (wPos - 100 * s) / (80 * s)))
    readonly property real cardFraction: Math.max(0, Math.min(1,
        (hPos - moduleH) / Math.max(1, cardH - moduleH)))
    readonly property real cardContentProgress: {
        const widthFraction = (wPos - collapsedW) / Math.max(1, cardW - collapsedW)
        const size = Math.min(cardFraction, widthFraction)
        // A scaled editor can remain legible through contraction without reflow.
        return expandedContent ? Math.max(0, Math.min(1, (size - 0.06) / 0.64))
            : Math.max(0, Math.min(1, (size - 0.45) / 0.35))
    }
    readonly property real contentExposure: {
        const center = Math.max(0, Math.min(1,
            (xPos + wPos / 2 - bodyX - bodyW) / Math.max(1, dropRadius + 3 * s)))
        const separation = Math.max(0, Math.min(1, (stretch - 0.75) / 0.53))
        return bodyBusy ? center : Math.min(center, separation)
    }
    readonly property real cardRadius: Math.min(Math.min(wPos, hPos) / 2, 24 * s)
    // Start the trailing contraction while the return still has velocity.
    // Centered panels land as an inset capsule matching the receiving pill.
    readonly property bool coveredByBody: {
        if (wPos > (centered ? bodyW : moduleH) + 3 * s
                || hPos > returnH + 3 * s || contentExposure >= 0.01) return false
        const left = bodyX + bodyRadius
        const right = bodyX + bodyW + captureExtra - bodyRadius
        const cy = yPos + hPos / 2
        const first = xPos + dropRadius
        const last = xPos + wPos - dropRadius
        const d1 = Math.hypot(first - Math.max(left, Math.min(right, first)), cy - capY)
        const d2 = Math.hypot(last - Math.max(left, Math.min(right, last)), cy - capY)
        return Math.max(d1, d2) + dropRadius <= bodyRadius + 0.08 * s
    }
    readonly property bool settled: Math.abs(targetX - xPos) < 0.08
        && Math.abs(targetY - yPos) < 0.08 && Math.abs(targetW - wPos) < 0.08
        && Math.abs(targetH - hPos) < 0.08 && Math.abs(captureTarget - captureExtra) < 0.08
        && Math.abs(vx) < 0.08 && Math.abs(vy) < 0.08
        && Math.abs(vw) < 0.08 && Math.abs(vh) < 0.08 && Math.abs(captureV) < 0.08
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
        xPos = centered ? bodyX + (bodyW - 34 * s) / 2 : bodyX + bodyW - 18 * s
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
        retarget("retornando", centered ? bodyX + (bodyW - returnW) / 2 : bodyX + bodyW - 20 * s,
                 bodyY + (bodyH - returnH) / 2, returnW, returnH)
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
        // Exact damped motion keeps the same trajectory at every refresh rate.
        const offset = value - target
        const decay = Math.exp(-damping * omega * dt)
        const damped = omega * Math.sqrt(Math.abs(1 - damping * damping))
        const phaseTime = damped * dt
        const cosine = damping < 1 ? Math.cos(phaseTime) : Math.cosh(phaseTime)
        const sine = (damping < 1 ? Math.sin(phaseTime) : Math.sinh(phaseTime)) / damped
        value = target + decay * (offset * cosine + (velocity + damping * omega * offset) * sine)
        velocity = decay * (velocity * cosine - (omega * omega * offset + damping * omega * velocity) * sine)
        if (Math.abs(target - value) < 0.08 && Math.abs(velocity) < 0.08) return [target, 0]
        return [value, velocity]
    }

    function updateBond(): void {
        if (!active || bodyBusy) { bond = false; return }
        // Returning grows the neck from zero at the same threshold where it breaks.
        bond = stretch < (bond || phase === "retornando" ? 1.30 : 1.02)
    }

    onOpenChanged: {
        if (open && phase === "idle") Qt.callLater(() => {
            if (root.open && root.phase === "idle") root.start()
        })
        else if (open && (phase === "retornando" || phase === "absorbiendo"))
            retarget(expanded ? "media" : "companion",
                     expanded ? cardX : bodyX + bodyW + gap,
                     expanded ? cardY : bodyY,
                     expanded ? cardW : compactWidth,
                     expanded ? cardH : moduleH)
        else if (open) syncHoverSize()
        else close()
    }
    Component.onCompleted: {
        if (open && phase === "idle") start()
    }
    onExpandedChanged: {
        if (open) syncHoverSize()
    }
    onWidthChanged: if (expanded) syncHoverSize()
    onHeightChanged: if (centered && expanded) syncHoverSize()
    function followBody(): void {
        if (phase === "retornando") {
            targetX = centered ? bodyX + (bodyW - returnW) / 2 : bodyX + bodyW - 20 * s
            targetY = bodyY + (bodyH - returnH) / 2
            targetW = returnW
            targetH = returnH
        } else if (phase === "companion" || phase === "media") syncHoverSize()
    }
    onBodyXChanged: followBody()
    onBodyWChanged: followBody()
    onBodyYChanged: followBody()
    onBodyHChanged: followBody()
    onReturnWChanged: if (phase === "retornando") followBody()
    onReturnHChanged: if (phase === "retornando") followBody()
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

    Connections {
        target: Flags
        function onReduceMotionChanged() {
            if (Flags.reduceMotion) expandedLoadAnimation.complete()
            if (!Flags.reduceMotion || root.phase === "idle") return
            birthTimer.stop()
            root.retarget(root.open ? (root.expanded ? "media" : "companion") : "retornando",
                root.open ? (root.expanded ? root.cardX : root.bodyX + root.bodyW + root.gap) : root.targetX,
                root.open ? (root.expanded ? root.cardY : root.bodyY) : root.targetY,
                root.open ? (root.expanded ? root.cardW : root.compactWidth) : root.targetW,
                root.open ? (root.expanded ? root.cardH : root.moduleH) : root.targetH)
            root.captureExtra = 0; root.captureTarget = 0; root.captureV = 0
            root.bond = false
        }
    }

    FrameAnimation {
        running: !Flags.reduceMotion && root.phase !== "idle"
            && (!root.settled || root.phase === "separando"
                || root.phase === "retornando" || root.phase === "absorbiendo")
        onTriggered: root.advanceMotion(frameTime)
    }

    function advanceMotion(dt: real): void {
        let next = root.spring(root.xPos, root.vx, root.targetX, dt); root.xPos = next[0]; root.vx = next[1]
        next = root.spring(root.yPos, root.vy, root.targetY, dt); root.yPos = next[0]; root.vy = next[1]
        next = root.spring(root.wPos, root.vw, root.targetW, dt); root.wPos = next[0]; root.vw = next[1]
        next = root.spring(root.hPos, root.vh, root.targetH, dt); root.hPos = next[0]; root.vh = next[1]
        root.updateBond()
        if (!root.centered && root.phase === "retornando" && root.stretch < 1.10) root.captureTarget = 20 * root.s
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
        waist: root.neckWaist
        fill: Qt.lighter(Theme.cardBot, 1.10)
    }

    Item {
        id: module
        z: 1
        x: root.visualX; y: root.yPos; width: root.wPos; height: root.hPos
        visible: root.active
        // Remove the received portion; translucent glass cannot occlude another layer.
        layer.enabled: root.centered && root.phase === "retornando" && root.joined
        layer.effect: OpacityMask {
            invert: true
            maskSource: Item {
                layer.enabled: true
                width: module.width; height: module.height
                Rectangle {
                    visible: root.phase === "retornando" && root.joined
                    x: root.bodyX - module.x; y: root.bodyY - module.y
                    width: root.bodyW; height: root.bodyH
                    radius: root.bodyRadius
                    color: "white"
                }
            }
        }

        PillMaterial {
            anchors.fill: parent
            s: root.s
            morphRadius: root.cardRadius
            materialAwake: true
            materialAccent: Theme.accent
            mode: root.surfaceName
            surface: root.surfaceName === "media" && (root.expanded || surfaceHost.displayedSurface === "media") ? "media" : ""
            artUrl: root.artUrl
            artworkTransition: root.artworkTransition
            mediaPlaying: root.mediaPlaying
            mediaSettled: root.expanded && root.cardContentProgress > 0.95
            suppressEdge: root.joined || (!root.centered && root.contentExposure < 0.3)
            edgeExposure: root.joined ? root.edgeExposure
                : !root.centered && root.contentExposure < 0.3 ? 0 : 1
        }

        Loader {
            anchors.fill: parent
            sourceComponent: root.compactContent
        }

        PillSurfaceHost {
            id: surfaceHost
            artworkTransition: root.artworkTransition
            z: 2
            open: root.expanded && !root.expandedContent
            surface: root.expanded && !root.expandedContent ? root.surfaceName : ""
            scaleFactor: root.s
            morphCloseness: root.cardContentProgress
            morphRadius: root.cardRadius
            surfaceRadius: root.cardRadius
            screenName: root.screenName
            bgColor: "transparent"
            onRequestClose: root.requestToggle()
        }

        ClippingRectangle {
            anchors.fill: parent
            z: 2
            radius: root.cardRadius
            color: "transparent"
            visible: root.expandedContent && root.active && root.cardContentProgress > 0.01
            enabled: visible && root.expanded && root.cardContentProgress > 0.9
            opacity: root.cardContentProgress
            Loader {
                id: expandedLoader
                asynchronous: root.asynchronousExpandedContent
                property real loadReveal: 0
                opacity: root.asynchronousExpandedContent ? loadReveal : 1
                Behavior on loadReveal {
                    enabled: expandedLoader.status === Loader.Ready && root.active && !Flags.reduceMotion
                    NumberAnimation { id: expandedLoadAnimation; duration: Motion.standardSmall; easing.type: Motion.easeStandard }
                }
                onLoaded: loadReveal = 1
                onStatusChanged: if (status !== Loader.Ready) loadReveal = 0
                // Keep editor layout stable while the shell contracts around it.
                anchors.centerIn: parent
                width: root.cardW
                height: root.cardH
                scale: Math.min(root.wPos / width, root.hPos / height)
                // Prepare retained editors while idle, before the user opens them.
                active: !!root.expandedContent && (root.expanded || root.retainExpandedContent)
                sourceComponent: root.expandedContent
            }
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
