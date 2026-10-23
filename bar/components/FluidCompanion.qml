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
    property real hoverWidth: 218 * s
    property real compactY: bodyY
    property string compactAccessibleName: qsTr("Abrir panel multimedia")
    readonly property var surfaceItem: expandedContent
        ? (expandedLoader.status === Loader.Ready ? expandedLoader.item : null) : surfaceHost.loadedItem
    readonly property real visualX: leftSide ? 2 * bodyX + bodyW - xPos - wPos : xPos
    readonly property real visualCapX: leftSide ? bodyX - captureExtra + bodyRadius : capX
    readonly property bool pressed: compactHit.enabled && compactHit.pressed && compactHit.containsMouse
    signal requestToggle()
    function receive() { if (root.active && root.expanded) companionMaterial.receive(0.55) }
    Connections {
        target: root.surfaceItem
        ignoreUnknownSignals: true
        function onFeedbackRequested(kind) { if (kind !== "paused" && kind !== "cancel") root.receive() }
    }

    readonly property real bodyX: body ? body.x : 0
    readonly property real bodyY: body ? body.y : 0
    readonly property real bodyW: body ? body.width : 0
    readonly property real bodyH: body ? body.height : IslandGeometry.restHeight * s
    readonly property real bodyRadius: bodyH / 2
    readonly property real moduleW: hoverWidth
    readonly property real moduleH: IslandGeometry.restHeight * s
    readonly property real collapsedW: 42 * s
    readonly property real returnH: centered ? Math.min(moduleH, bodyH) : moduleH
    // Every droplet sinks home round: a pill-wide capsule joined below the pill
    // reads as a flat-bottomed trapezoid through the neck hull.
    readonly property real returnW: returnH
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
    // Smooth-union radius: generous at contact, pinching with the same tension
    // as the waist so the neck reaches zero thickness before the bond breaks.
    readonly property real neckBlend: (10 + 22 * neckWaist / 0.42) * s
    // PillMaterial reads more opaque as it grows; each neck end copies its body.
    function readingExposure(height) { return Math.max(0, Math.min(1, (height / s - 38) / 58)) }
    function glassAlpha(exposure) { return Flags.glassAlpha + (1 - Flags.glassAlpha) * (0.15 + 0.25 * exposure) }
    readonly property real bodyExposure: readingExposure(bodyH)
    readonly property real dropExposure: readingExposure(hPos)
    // Part of the droplet inside the receiving pill is hidden, not stacked.
    readonly property bool overlapsBody: {
        const left = bodyX - (leftSide ? captureExtra : 0)
        const right = bodyX + bodyW + (leftSide || centered ? 0 : captureExtra)
        return visualX < right && visualX + wPos > left && yPos < bodyY + bodyH && yPos + hPos > bodyY
    }
    // Halo, border and sheen sit outside the droplet; they fade out before any
    // overlap so the cut layer never clips them.
    readonly property real edgeClearance: {
        const left = bodyX - (leftSide ? captureExtra : 0)
        const right = bodyX + bodyW + (leftSide || centered ? 0 : captureExtra)
        const gap = Math.max(left - visualX - wPos, visualX - right, bodyY - yPos - hPos, yPos - bodyY - bodyH)
        return Math.max(0, Math.min(1, gap / (7 * s)))
    }
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
    // A bud or gathering card stays a blob; corners settle to 24 before any
    // content is more than faint, so the editor is never clipped by blob corners.
    readonly property real cardRadius: {
        const round = Math.min(wPos, hPos) / 2
        if (round <= 24 * s) return round
        // Squared size term: an empty mid-size card reads as a blob, not a tile.
        const size = Math.min(1, (2 * round - 48 * s) / (160 * s))
        return round + (24 * s - round) * Math.min(1, Math.max(size * size, 4 * cardContentProgress))
    }
    // Expanded cards bud off and gather back as a round droplet clear of the
    // body, so the pill never carries a card-sized block through the neck.
    readonly property real budSize: moduleH
    readonly property real budX: centered ? capX - budSize / 2
        : capX + 1.45 * (bodyRadius + budSize / 2) - budSize / 2
    readonly property real budY: centered ? capY + 1.45 * (bodyRadius + budSize / 2) - budSize / 2
        : bodyY + (bodyH - budSize) / 2
    // Start the trailing contraction while the return still has velocity.
    readonly property bool coveredByBody: {
        if (wPos > returnW + 3 * s
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
        if (expanded && !Flags.reduceMotion) {
            retarget("brotando", budX, budY, budSize, budSize)
            if (centered) vy += 1200 * s
            else vx += 1200 * s
        } else if (expanded) {
            retarget("media", cardX, cardY, cardW, cardH)
        } else {
            retarget("nacimiento", xPos, yPos, wPos, hPos)
            birthTimer.restart()
        }
    }

    function close(): void {
        if (phase === "idle" || phase === "retornando" || phase === "absorbiendo"
                || phase === "recogiendo") return
        captureTarget = 0
        if (phase === "media" && !Flags.reduceMotion && Math.min(wPos, hPos) > gatherSize) {
            retarget("recogiendo", budX, budY, budSize, budSize)
            return
        }
        returnHome()
    }

    // Below this the gathering card is a blob well inside the pill width.
    readonly property real gatherSize: 66 * s
    function returnHome(): void {
        retarget("retornando", centered ? bodyX + (bodyW - returnW) / 2 : bodyX + bodyW - 20 * s,
                 bodyY + (bodyH - returnH) / 2, returnW, returnH)
    }

    // A card blooms only clear of the pill; reopening while joined or inside
    // it buds off again with the current velocity instead of growing in the neck.
    function bloom(): void {
        birthTimer.stop()
        if (!Flags.reduceMotion && phase !== "media" && (bond || overlapsBody || concealed))
            retarget("brotando", budX, budY, budSize, budSize)
        else
            retarget("media", cardX, cardY, cardW, cardH)
    }
    function syncHoverSize(): void {
        if (phase === "idle") return
        if (phase === "brotando" && expanded) return
        if (expanded) {
            bloom()
            return
        }
        if (phase === "nacimiento" || phase === "retornando" || phase === "absorbiendo") return
        const compactW = hovered ? moduleW : compactWidth
        retarget("companion", bodyX + bodyW + gap, compactY, compactW, moduleH)
    }

    function spring(value: real, velocity: real, target: real, dt: real): var {
        let omega = 16
        let damping = 0.92
        if (phase === "separando") { omega = 11; damping = 0.84 }
        else if (phase === "brotando") { omega = 26; damping = 0.96 }
        else if (phase === "recogiendo") { omega = 19; damping = 0.98 }
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
        else if (open && expanded && (phase === "retornando" || phase === "absorbiendo" || phase === "recogiendo"))
            bloom()
        else if (open && (phase === "retornando" || phase === "absorbiendo" || phase === "recogiendo"))
            retarget("companion", bodyX + bodyW + gap, compactY, compactWidth, moduleH)
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
        } else if (phase === "brotando" || phase === "recogiendo") {
            targetX = budX; targetY = budY
        } else if (phase === "companion" || phase === "media") syncHoverSize()
    }
    onBodyXChanged: followBody()
    onBodyWChanged: followBody()
    onBodyYChanged: followBody()
    onCompactYChanged: followBody()
    onBodyHChanged: followBody()
    onReturnWChanged: if (phase === "retornando") followBody()
    onReturnHChanged: if (phase === "retornando") followBody()
    onBodyBusyChanged: updateBond()
    onHoveredChanged: syncHoverSize()
    onCompactWidthChanged: syncHoverSize()
    onHoverWidthChanged: if (hovered) syncHoverSize()

    Timer {
        id: birthTimer
        interval: Flags.reduceMotion ? 0 : 32
        repeat: false
        onTriggered: if (root.phase === "nacimiento") {
            root.retarget("separando", root.bodyX + root.bodyW + root.gap,
                          root.compactY, root.compactWidth, root.moduleH)
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
                root.open ? (root.expanded ? root.cardY : root.compactY) : root.targetY,
                root.open ? (root.expanded ? root.cardW : root.compactWidth) : root.targetW,
                root.open ? (root.expanded ? root.cardH : root.moduleH) : root.targetH)
            root.captureExtra = 0; root.captureTarget = 0; root.captureV = 0
            root.bond = false
        }
    }

    FrameAnimation {
        running: !Flags.reduceMotion && root.phase !== "idle"
            && (!root.settled || root.phase === "separando" || root.phase === "brotando"
                || root.phase === "recogiendo"
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
        if (root.phase === "brotando" && ((!root.bond && root.stretch >= 1.30) || root.settled)) {
            root.retarget("media", root.cardX, root.cardY, root.cardW, root.cardH)
        } else if (root.phase === "recogiendo"
                && (Math.min(root.wPos, root.hPos) < root.gatherSize || root.settled)) {
            root.returnHome()
        } else if (root.phase === "separando" && root.settled) {
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

    Fluid.FluidNeck {
        z: 0
        visible: root.joined && root.neckBlend > 0.5
        bodyLeft: root.bodyX - (root.leftSide ? root.captureExtra : 0)
        bodyTop: root.bodyY
        bodyWidth: root.bodyW + (root.centered ? 0 : root.captureExtra)
        bodyHeight: root.bodyH
        bodyCorner: root.bodyRadius
        dropLeft: root.visualX; dropTop: root.yPos
        dropWidth: root.wPos; dropHeight: root.hPos
        dropCorner: root.cardRadius
        blend: root.neckBlend
        readonly property real bodyAlpha: root.glassAlpha(root.bodyExposure)
        readonly property real dropAlpha: root.glassAlpha(root.dropExposure)
        bodyColor0: Qt.alpha(Theme.cardTop, Math.min(1, bodyAlpha + 0.08 * root.bodyExposure))
        bodyColor1: Qt.alpha(Theme.cardBot, bodyAlpha)
        bodyColor2: Qt.alpha(Qt.darker(Theme.cardBot, 1 + 0.16 * root.bodyExposure), Math.min(1, bodyAlpha + 0.04 * root.bodyExposure))
        dropColor0: Qt.alpha(Theme.cardTop, Math.min(1, dropAlpha + 0.08 * root.dropExposure))
        dropColor1: Qt.alpha(Theme.cardBot, dropAlpha)
        dropColor2: Qt.alpha(Qt.darker(Theme.cardBot, 1 + 0.16 * root.dropExposure), Math.min(1, dropAlpha + 0.04 * root.dropExposure))
        accent: Theme.accent
        // Accent band of a resting pill and of the awake droplet material.
        bodyBand: 0.028 * 0.62 * (1 - 0.65 * root.bodyExposure)
        bodyBandHeight: Math.max(30 * root.s, 0.22 * root.bodyH)
        dropBand: 0.075 * 0.88 * (1 - 0.65 * root.dropExposure)
        dropBandHeight: Math.max(30 * root.s, 0.22 * root.hPos)
    }

    Item {
        id: module
        z: 1
        x: root.visualX; y: root.yPos; width: root.wPos; height: root.hPos
        visible: root.active
        // Remove the received portion; translucent glass cannot occlude another layer.
        // Also while crossing unbonded: a wide droplet overlaps before it joins.
        layer.enabled: root.overlapsBody && (root.joined || root.phase === "nacimiento" || root.phase === "brotando"
            || root.phase === "separando" || root.phase === "retornando" || root.phase === "absorbiendo")
        layer.smooth: true
        layer.effect: ShaderEffect {
            readonly property real bodyLeft: root.bodyX - (root.leftSide ? root.captureExtra : 0) - module.x
            readonly property real bodyWidth: root.bodyW + (root.centered ? 0 : root.captureExtra)
            readonly property size itemSize: Qt.size(module.width, module.height)
            readonly property vector4d bodyBox: Qt.vector4d(bodyLeft + bodyWidth / 2,
                root.bodyY - module.y + root.bodyH / 2, bodyWidth / 2, root.bodyH / 2)
            readonly property real bodyRadius: Math.min(root.bodyRadius, bodyWidth / 2, root.bodyH / 2)
            readonly property real bodyAlpha: root.glassAlpha(root.bodyExposure)
            fragmentShader: Qt.resolvedUrl("../fluid/shaders/fluid_cut.frag.qsb")
        }

        PillMaterial {
            id: companionMaterial
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
            edgeExposure: root.edgeClearance * (root.joined ? root.edgeExposure
                : !root.centered && root.contentExposure < 0.3 ? 0 : 1)
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
            accessibleName: root.compactAccessibleName
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
