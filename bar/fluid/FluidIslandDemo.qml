import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real scaleFactor: 1
    required property var theme
    required property var flags
    readonly property real u: Math.max(0.58, Math.min(1.18, scaleFactor))
    readonly property real stageWidth: Math.min(width, 900 * u)
    readonly property real stageX: (width - stageWidth) / 2
    readonly property real islandY: 54 * u
    readonly property real baseW: Math.min(220 * u, stageWidth * 0.45)
    readonly property real baseH: 48 * u
    readonly property real baseX: stageX + (stageWidth - baseW) / 2

    // Persistent state: retarget() only changes destinations. Velocity is never
    // reset, so a new request continues from the physical state on screen.
    property real bodyX: baseX
    property real bodyY: islandY
    property real bodyW: baseW
    property real bodyH: baseH
    property real bodyVw: 0
    property real bodyTargetW: baseW
    property real dropX: baseX + baseW - 28 * u
    property real dropY: islandY + 5 * u
    property real dropW: 38 * u
    property real dropH: 38 * u
    property real vx: 0
    property real vy: 0
    property real vw: 0
    property real vh: 0
    property real targetX: dropX
    property real targetY: dropY
    property real targetW: dropW
    property real targetH: dropH
    property string phase: "reposo"
    property bool previousBond: false
    property real satelliteX: 0
    property real satelliteY: 0
    property real satelliteR: 0
    property real satelliteAge: 1
    property real satelliteVx: 0
    property real satelliteVy: 0
    property bool dropConcealed: false

    readonly property real gap: dropX - (bodyX + bodyW)
    readonly property real bodyRadius: bodyH / 2
    readonly property real dropRadius: Math.min(dropW, dropH) / 2
    readonly property real centerDistance: Math.hypot((dropX + dropW / 2) - (bodyX + bodyW - bodyRadius),
                                                     (dropY + dropH / 2) - (bodyY + bodyH / 2))
    readonly property real stretch: centerDistance / Math.max(1, bodyRadius + dropRadius)
    property bool bond: false
    readonly property bool dropActive: phase !== "reposo"
    readonly property bool joined: dropActive && !dropConcealed && bond
    readonly property real contentProgress: Math.max(0, Math.min(1, (dropW - 64 * u) / (210 * u)))

    function compactX(): real {
        return Math.min(stageX + stageWidth - 58 * u - 12 * u, bodyX + bodyW + 52 * u)
    }

    function retarget(name: string, x: real, y: real, w: real, h: real): void {
        phase = name
        if (name !== "absorbiendo" && name !== "reposo")
            dropConcealed = false
        targetX = x; targetY = y; targetW = w; targetH = h
        if (flags.reduceMotion) {
            dropX = x; dropY = y; dropW = w; dropH = h
            vx = 0; vy = 0; vw = 0; vh = 0
        }
    }

    function retargetBody(width: real): void {
        bodyTargetW = width
        if (flags.reduceMotion) {
            bodyW = width
            bodyVw = 0
        }
    }

    function birth(): void {
        retargetBody(baseW + 3 * u)
        retarget("nacimiento", bodyX + bodyW - 18 * u, islandY + 8 * u, 34 * u, 34 * u)
    }
    function separate(): void {
        const w = 58 * u
        if (phase === "reposo") {
            retargetBody(baseW + 7 * u)
            retarget("presionando", bodyX + bodyW - 20 * u, islandY + 7 * u, 34 * u, 34 * u)
        } else {
            retargetBody(baseW)
            retarget("expulsando", compactX(), islandY - 2 * u, w, 52 * u)
            vx += 38 * u
        }
    }
    function expand(): void {
        const w = Math.min(350 * u, stageWidth - 28 * u)
        retarget("expansión", stageX + (stageWidth - w) / 2, islandY + 72 * u, w, 196 * u)
    }
    function compact(): void {
        retargetBody(baseW)
        retarget("contrayendo", compactX(), islandY - 2 * u, 58 * u, 52 * u)
    }
    function merge(): void {
        retargetBody(baseW)
        retarget("contrayendo", compactX(), islandY - 2 * u, 58 * u, 52 * u)
        vx -= 18 * u
    }
    function toggleDirection(): void {
        if (phase === "expansión") compact()
        else if (phase === "reposo" || phase === "fusión") birth()
        else expand()
    }

    function spring(value: real, velocity: real, target: real, dt: real): var {
        // The outward pull is intentionally reluctant: it gives the neck time
        // to thin. Return is nearly critically damped, so it feels captured,
        // not flung back into place.
        let omega = 17
        let damping = 0.88
        if (phase === "expulsando") { omega = 10.5; damping = 0.82 }
        else if (phase === "retornando") { omega = 15.5; damping = 0.98 }
        else if (phase === "absorbiendo" || phase === "fusión") { omega = 19; damping = 1.04 }
        else if (phase === "contrayendo") { omega = 14; damping = 0.94 }
        if (flags.reduceMotion) { omega = 28; damping = 1.15 }
        const a = omega * omega * (target - value) - 2 * damping * omega * velocity
        velocity += a * dt
        value += velocity * dt
        if (Math.abs(target - value) < 0.08 && Math.abs(velocity) < 0.08)
            return [target, 0]
        return [value, velocity]
    }

    function updateBond(): void {
        if (!dropActive) { bond = false; return }
        bond = bond ? stretch < 1.30 : stretch < 1.02
    }

    function leaveSatellite(): void {
        const capX = bodyX + bodyW - bodyRadius
        const capY = bodyY + bodyRadius
        const dropCenterX = dropX + dropW / 2
        const dropCenterY = dropY + dropH / 2
        const t = bodyRadius / Math.max(1, centerDistance)
        satelliteX = capX + (dropCenterX - capX) * t
        satelliteY = capY + (dropCenterY - capY) * t
        satelliteR = Math.min(bodyRadius, dropRadius) * 0.22
        satelliteAge = 0
        satelliteVx = (dropCenterX - capX) * 0.08
        satelliteVy = (dropCenterY - capY) * 0.08
    }

    Timer {
        id: physics
        interval: 16
        repeat: true
        running: !root.flags.reduceMotion && (Math.abs(root.targetX - root.dropX) > 0.08
            || Math.abs(root.targetY - root.dropY) > 0.08 || Math.abs(root.targetW - root.dropW) > 0.08
            || Math.abs(root.targetH - root.dropH) > 0.08 || Math.abs(root.bodyTargetW - root.bodyW) > 0.08
            || Math.abs(root.vx) > 0.08 || Math.abs(root.vy) > 0.08 || Math.abs(root.bodyVw) > 0.08)
        onTriggered: {
            const dt = Math.min(0.032, interval / 1000)
            let next = root.spring(root.dropX, root.vx, root.targetX, dt); root.dropX = next[0]; root.vx = next[1]
            next = root.spring(root.dropY, root.vy, root.targetY, dt); root.dropY = next[0]; root.vy = next[1]
            next = root.spring(root.dropW, root.vw, root.targetW, dt); root.dropW = next[0]; root.vw = next[1]
            next = root.spring(root.dropH, root.vh, root.targetH, dt); root.dropH = next[0]; root.vh = next[1]
            // The island starts receiving only when the returning surface is
            // physically close. Both motions stay in one uninterrupted pass.
            if (root.phase === "retornando" && root.stretch < 1.10)
                root.retargetBody(root.baseW + 28 * root.u)
            next = root.spring(root.bodyW, root.bodyVw, root.bodyTargetW, dt); root.bodyW = next[0]; root.bodyVw = next[1]
            root.updateBond()
            if (root.previousBond && !root.bond && root.phase === "expulsando")
                root.leaveSatellite()
            root.previousBond = root.bond
            if (root.satelliteAge < 1) {
                root.satelliteAge = Math.min(1, root.satelliteAge + dt / 0.42)
                root.satelliteX += root.satelliteVx * dt
                root.satelliteY += root.satelliteVy * dt
                root.satelliteVx *= 0.90
                root.satelliteVy *= 0.90
            }
            const settled = Math.abs(root.targetX - root.dropX) < 0.08
                    && Math.abs(root.targetY - root.dropY) < 0.08 && Math.abs(root.targetW - root.dropW) < 0.08
                    && Math.abs(root.targetH - root.dropH) < 0.08
                    && Math.abs(root.bodyTargetW - root.bodyW) < 0.08
            if (root.phase === "presionando" && settled) {
                root.retargetBody(root.baseW)
                root.retarget("expulsando", root.compactX(), root.islandY - 2 * root.u, 58 * root.u, 52 * root.u)
                root.vx += 42 * root.u
            } else if (root.phase === "contrayendo" && settled) {
                root.retargetBody(root.baseW)
                root.retarget("retornando", root.bodyX + root.baseW - 30 * root.u,
                              root.bodyY + 3 * root.u, 50 * root.u, 42 * root.u)
            } else if (root.phase === "retornando" && settled) {
                root.dropConcealed = true
                root.retargetBody(root.baseW)
                root.phase = "absorbiendo"
            } else if (root.phase === "absorbiendo" && settled) {
                root.phase = "reposo"
            }
        }
    }
    onPhaseChanged: updateBond()

    FluidMetaballBridge {
        visible: root.joined
        x1: root.bodyX + root.bodyW - root.bodyH / 2
        y1: root.bodyY + root.bodyH / 2
        r1: root.bodyH / 2
        x2: root.dropX + root.dropW / 2
        y2: root.dropY + root.dropH / 2
        r2: Math.min(root.dropW, root.dropH) / 2
        waist: 0.42
        fill: Qt.lighter(root.theme.cardBot, 1.10)
    }

    Rectangle {
        // A short-lived residue makes a torn neck read as liquid transfer
        // instead of an object teleporting away.
        visible: root.satelliteAge < 1
        x: root.satelliteX - width / 2
        y: root.satelliteY - height / 2
        width: 2 * root.satelliteR * Math.pow(1 - root.satelliteAge, 1.4)
        height: width
        radius: width / 2
        color: Qt.lighter(root.theme.cardTop, 1.12)
        opacity: (1 - root.satelliteAge) * 0.9
        border.color: Qt.alpha(root.theme.foreground, root.theme.alphaHair)
        border.width: root.u
    }

    Rectangle {
        id: body
        // During capture the island is drawn in front of the drop. Its rounded
        // cap becomes the moving liquid boundary that engulfs the surface.
        z: (root.phase === "retornando" && root.bodyW > root.baseW + 10 * root.u)
            || root.phase === "absorbiendo" ? 2 : 0
        x: root.bodyX; y: root.bodyY; width: root.bodyW; height: root.bodyH
        radius: height / 2
        visible: true
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(root.theme.cardTop, 1.08) }
            GradientStop { position: 0.42; color: root.theme.cardTop }
            GradientStop { position: 1; color: Qt.darker(root.theme.cardBot, 1.12) }
        }
        border.color: root.joined ? "transparent" : Qt.alpha(root.theme.foreground, root.theme.alphaHairline)
        border.width: root.u
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: root.u
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.68
            height: root.u
            radius: height / 2
            color: root.joined ? "transparent" : Qt.alpha(root.theme.foreground, root.theme.alphaFaint)
        }
        Text {
            anchors.centerIn: parent
            text: Qt.formatTime(new Date(), "hh:mm")
            color: root.theme.iconPrimary
            font.family: root.theme.font
            font.pixelSize: 19 * root.u
        }
    }
    property alias bodyHit: body

    Rectangle {
        id: drop
        z: 1
        x: root.dropX; y: root.dropY; width: root.dropW; height: root.dropH
        radius: Math.min(width, height) / 2
        visible: root.dropActive && !root.dropConcealed
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(root.theme.cardTop, 1.08) }
            GradientStop { position: 0.42; color: root.theme.cardTop }
            GradientStop { position: 1; color: Qt.darker(root.theme.cardBot, 1.12) }
        }
        border.color: root.joined ? "transparent" : Qt.alpha(root.theme.foreground, root.theme.alphaHairline)
        border.width: root.u
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: root.u
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.52
            height: root.u
            radius: height / 2
            color: root.joined ? "transparent" : Qt.alpha(root.theme.foreground, root.theme.alphaFaint)
        }

        Item {
            anchors.fill: parent
            anchors.margins: 20 * root.u
            opacity: root.contentProgress
            visible: opacity > 0.01
            Text {
                id: title
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                text: qsTr("Surface player")
                color: root.theme.iconPrimary
                font.family: root.theme.font
                font.pixelSize: 16 * root.u
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                anchors.top: title.bottom; anchors.topMargin: 5 * root.u
                anchors.left: parent.left; anchors.right: parent.right
                text: qsTr("La misma gota; contenido estable")
                color: root.theme.iconSecondary
                font.family: root.theme.font
                font.pixelSize: 12 * root.u
                elide: Text.ElideRight
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: controls.top
                anchors.bottomMargin: 14 * root.u
                height: 4 * root.u; radius: height / 2
                color: Qt.alpha(root.theme.foreground, root.theme.alphaSubtle)
                Rectangle { width: parent.width * 0.42; height: parent.height; radius: parent.radius; color: root.theme.accent }
            }
            Text {
                id: controls
                anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                text: "◀   ❚❚   ▶"
                color: root.theme.iconPrimary
                font.pixelSize: 17 * root.u
            }
        }
        MouseArea { anchors.fill: parent; onClicked: root.toggleDirection() }
    }
    Item {
        id: dropInput
        x: drop.visible ? drop.x : 0
        y: drop.visible ? drop.y : 0
        width: drop.visible ? drop.width : 0
        height: drop.visible ? drop.height : 0
    }
    property alias dropHit: dropInput

    Item {
        id: bridgeInput
        x: Math.min(root.bodyX + root.bodyW - 8 * root.u, root.dropX)
        y: Math.min(root.bodyY, root.dropY)
        width: root.joined ? Math.max(0, root.dropX + root.dropW - x) : 0
        height: root.joined ? Math.max(root.bodyY + root.bodyH, root.dropY + root.dropH) - y : 0
    }
    property alias bridgeHit: bridgeInput

    Item {
        id: controlsPanel
        x: root.stageX + (root.stageWidth - width) / 2
        y: Math.min(root.height - height - 22 * root.u, islandY + 294 * root.u)
        width: 510 * root.u
        height: 38 * root.u
        Row {
            anchors.centerIn: parent
            spacing: 6 * root.u
            Repeater {
                model: [qsTr("Nacer"), qsTr("Separar"), qsTr("Expandir"), qsTr("Compactar"), qsTr("Fusionar")]
                delegate: Rectangle {
                    required property int index
                    required property string modelData
                    width: 94 * root.u; height: 28 * root.u; radius: height / 2
                    color: Qt.alpha(root.theme.cardBot, index === 2 ? 0.88 : 0.72)
                    border.color: Qt.alpha(root.theme.foreground, root.theme.alphaHairline); border.width: 1
                    Text { anchors.centerIn: parent; text: modelData; color: root.theme.iconPrimary; font.family: root.theme.font; font.pixelSize: 11 * root.u }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (index === 0) root.birth()
                            else if (index === 1) root.separate()
                            else if (index === 2) root.expand()
                            else if (index === 3) root.compact()
                            else root.merge()
                        }
                    }
                }
            }
        }
    }
    property alias controlsHit: controlsPanel

}
