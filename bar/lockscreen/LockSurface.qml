import QtQuick
import QtQuick.Effects
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Services.UPower
import "../components"
import "../Singletons"

Item {
    id: root
    required property string username
    property string wallpaper: ""
    property var palette: ({})
    property var weather: ({})
    property bool busy: false
    property bool authenticated: false
    property bool secured: false
    property bool responseVisible: false
    property string promptText: I18n.tr("Contraseña")
    property string errorText: ""
    property string displayName: Config.profile.displayName.trim() || username
    property url avatarSource: Config.userAvatarUrl
    property var player: null
    property string artUrl: ""
    property string trackKey: ""
    property bool preview: false
    // Desktop frame captured just before locking (lock.sh). It makes the lock
    // grow out of the desktop and return to it; without it the lock fades from
    // the theme background as before.
    property url snapshotSource: ""
    // Island rest rectangle on the captured desktop, in surface pixels.
    property rect islandRect: Qt.rect((width - 88) / 2, 11, 88, 32)
    signal unlockRequested(string secret)
    signal exitFinished()
    signal powerRequested(string action)
    signal entryActivated()

    readonly property real unit: Math.max(0.45, Math.min(1.2, height / 900, width / 560))
    readonly property real textScale: unit * Flags.fontScale
    readonly property color ink: Theme.foreground
    readonly property color secondary: Theme.iconSecondary
    property date now: Regional.now()
    property bool entered: false
    // Two linear timelines; every layer derives its own eased window from them,
    // so entry and exit are one choreography instead of chained timers.
    property real entryT: entered ? 1 : 0
    property real exitT: retiring ? 1 : 0
    readonly property real entrance: entryT
    readonly property int entryDuration: Motion.morph * 2
    readonly property int exitDuration: Motion.morph * 2.2
    Behavior on entryT { NumberAnimation { duration: Flags.reduceMotion ? 0 : root.entryDuration } }
    Behavior on exitT { NumberAnimation { duration: Flags.reduceMotion ? 0 : root.exitDuration } }
    onExitTChanged: if (retiring && exitT >= 1) exitFinished()
    function span(t, a, b) { return Math.max(0, Math.min(1, (t - a) / (b - a))) }
    function smooth(t) { return t * t * (3 - 2 * t) }
    function decel(t) { return 1 - Math.pow(1 - t, 3) }
    readonly property bool hasSnapshot: snapshotImage.status === Image.Ready
    // Entry windows.
    readonly property real pillArrive: decel(span(entryT, 0, 0.55))
    readonly property real pillShow: smooth(span(entryT, 0, 0.22))
    readonly property real statusIn: smooth(span(entryT, 0.3, 0.6))
    readonly property real clockIn: decel(span(entryT, 0.28, 0.82))
    readonly property real dateIn: decel(span(entryT, 0.36, 0.9))
    readonly property real hintIn: decel(span(entryT, 0.44, 1))
    readonly property real chromeIn: smooth(span(entryT, 0.55, 1))
    // Exit windows.
    readonly property real collapse: decel(span(exitT, 0.04, 0.4))
    readonly property real statusReturn: smooth(span(exitT, 0.2, 0.38)) * (1 - smooth(span(exitT, 0.58, 0.74)))
    readonly property real pillLeave: smooth(span(exitT, 0.55, 0.95))
    readonly property real pillFade: smooth(span(exitT, 0.74, 1))
    readonly property real desktopReturn: smooth(span(exitT, 0.38, 0.94))
    // Backdrop: desktop → blurred desktop → wallpaper, and the reverse on exit.
    readonly property real wallpaperShow: (hasSnapshot ? smooth(span(entryT, 0.12, 0.7)) : 1) * (hasSnapshot ? 1 - desktopReturn : 1)
    readonly property real veilShow: (hasSnapshot ? smooth(span(entryT, 0.08, 0.75)) : 1) * (hasSnapshot ? 1 - desktopReturn : 1)
    readonly property real snapshotBlur: retiring ? 1 - span(exitT, 0.38, 1) : decel(span(entryT, 0, 0.5))
    readonly property real wallpaperBlur: 0.55 * cardT
    // Island ↔ rest pill: 0 = island on the desktop, 1 = lock rest pill.
    readonly property real pillForm: Math.min(pillArrive, 1 - pillLeave)
    property real restingMedia: player?.isPlaying && !authActive && !authenticated ? 1 : 0
    Behavior on restingMedia { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.standard; velocity: -1 } }
    property bool authActive: false
    // Typing again acknowledges a rejection: the field returns to neutral
    // without waiting for the next PAM round.
    property bool errorDismissed: false
    readonly property bool showError: !!errorText && !errorDismissed && !authenticated
    LockCapsLock { id: capsLock; active: root.authActive && root.secured && !root.authenticated }
    property string pendingPower: ""
    property bool retiring: false
    readonly property bool departing: retiring && retirementOpacity <= 0.001
    // Card geometry: the auth presentation, folded back to the pill on success.
    readonly property real cardT: presentation * (1 - collapse)
    readonly property real fieldOffset: rejection.offset * 8 * unit
    property real successProgress: authenticated ? 1 : 0
    // One continuous trajectory: travel leads expansion, with no timer between them.
    readonly property real travel: 1 - Math.pow(1 - cardT, 3)
    readonly property real expansionPhase: Math.max(0, (cardT - 0.18) / 0.82)
    readonly property real expansion: expansionPhase * expansionPhase * (3 - 2 * expansionPhase)
    readonly property real contentExposure: smoothReveal(expansion, 0.84)
    readonly property real retirementOpacity: 1 - smooth(span(exitT, 0, 0.16))
    readonly property real contentOpacity: contentExposure * retirementOpacity
    readonly property real contextOpacity: smoothReveal(travel, 0.92) * retirementOpacity
    // Marea: the rest pill descends and widens into the password capsule.
    property real capWidth: Math.min((authenticated ? 220 : 340) * unit * Math.max(1, Flags.fontScale * 0.8), width - 48 * unit)
    Behavior on capWidth { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.standardLarge; velocity: -1 } }
    readonly property real capH: Math.round(56 * unit * Math.max(1, Flags.fontScale * 0.85))
    readonly property real capY: Math.round(height / 2 + 20 * unit)
    // Rejection slosh (unitless) and its offset in pixels for the regressions.
    readonly property real slosh: rejection.offset
    // Liquid beads: submit streams them into one drop that waits for PAM,
    // drains away on rejection and swells into the welcome on success.
    property bool gathering: false
    property real blobScale: 0
    property real blobDrain: 0
    property real blobBreath: 0
    function beadMs(ms) { return Flags.reduceMotion ? 0 : ms }
    // One media capsule for rest and access; it keeps the last player while it fades.
    property var lastPlayer: null
    onPlayerChanged: if (player) lastPlayer = player
    property real mediaShow: !!player && !authenticated && (authActive || !!player.isPlaying) ? 1 : 0
    Behavior on mediaShow { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.standardLarge; velocity: -1 } }
    readonly property var mediaPlayer: player || (mediaShow > 0.001 ? lastPlayer : null)
    property real authProgress: entered && authActive ? 1 : 0
    function smoothReveal(value, start) {
        const t = Math.max(0, Math.min(1, (value - start) / (1 - start)))
        return t * t * (3 - 2 * t)
    }
    property real presentation: entered && authActive ? 1 : 0
    Behavior on authProgress { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.standard; velocity: -1 } }
    Behavior on successProgress { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.standard; velocity: -1 } }
    Behavior on presentation { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.morph; velocity: -1 } }
    Component.onCompleted: { if (secured) entranceTimer.start(); forceActiveFocus() }
    Timer { id: entranceTimer; interval: Flags.reduceMotion ? 0 : 32; onTriggered: root.entered = true }
    Timer { id: idleReturn; interval: 15000; running: root.authActive && !password.text.length && !root.busy && !root.authenticated; onTriggered: root.authActive = false }
    function activateInput(initialText) {
        if (!secured || authenticated || retiring) return
        if (!authActive) entryActivated()
        authActive = true
        password.forceActiveFocus()
        if (initialText) password.insert(password.cursorPosition, initialText)
    }
    onAuthActiveChanged: {
        if (!authActive) {
            password.clear()
            forceActiveFocus()
        }
    }
    Keys.onPressed: event => {
        if (root.authActive || !root.secured || root.authenticated) return
        if (event.key === Qt.Key_Escape) return
        const first = event.text && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Tab ? event.text : ""
        root.activateInput(first)
        event.accepted = true
    }
    onAuthenticatedChanged: {
        if (!authenticated) return
        password.clear()
        rejection.stop()
        powerMenu.close()
        successHold.start()
    }
    Timer {
        id: successHold
        interval: Flags.reduceMotion ? 180 : Motion.standard + Motion.fast
        onTriggered: root.retiring = true
    }
    ErrorShake { id: rejection; amplitude: 1; cycles: 1.75 }
    SequentialAnimation {
        id: gatherAnim
        PauseAnimation { duration: Motion.fast }
        NumberAnimation { target: root; property: "blobScale"; to: 1; duration: Motion.standard; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
    }
    SequentialAnimation {
        running: root.busy && root.gathering && !Flags.reduceMotion && !root.authenticated
        loops: Animation.Infinite
        onRunningChanged: { if (running) breathSettle.stop(); else breathSettle.restart() }
        NumberAnimation { target: root; property: "blobBreath"; to: 0.12; duration: Motion.morph + Motion.fast; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "blobBreath"; to: 0; duration: Motion.morph + Motion.fast; easing.type: Easing.InOutSine }
    }
    NumberAnimation { id: breathSettle; target: root; property: "blobBreath"; to: 0; duration: root.beadMs(Motion.fast); easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: drainAnim
        NumberAnimation { target: root; property: "blobDrain"; to: 1; duration: root.beadMs(Motion.morph); easing.type: Easing.InQuad }
        ScriptAction { script: root.resetDrop() }
    }
    SequentialAnimation {
        id: releaseAnim
        NumberAnimation { target: root; property: "blobScale"; to: 0; duration: root.beadMs(Motion.standardSmall); easing.type: Easing.InCubic }
        ScriptAction { script: root.resetDrop() }
    }
    function resetDrop() {
        gatherAnim.stop()
        breathSettle.stop()
        gathering = false
        blobScale = 0
        blobDrain = 0
        blobBreath = 0
    }
    // Without a PAM answer (tests, aborted conversation) the drop dissolves.
    Timer {
        interval: 1500
        running: root.gathering && !root.busy && !root.authenticated && !drainAnim.running && !releaseAnim.running
        onTriggered: releaseAnim.restart()
    }
    onSecuredChanged: if (secured) { if (!entered) entranceTimer.start(); if (authActive) password.forceActiveFocus(); else forceActiveFocus() }
    onResponseVisibleChanged: if (responseVisible && gathering && !drainAnim.running) releaseAnim.restart()
    onBusyChanged: if (!busy && authActive) password.forceActiveFocus()
    onErrorTextChanged: if (errorText && !authenticated) {
        password.clear()
        errorDismissed = false
        authActive = true
        password.forceActiveFocus()
        rejection.trigger()
        if (gathering) { gatherAnim.stop(); releaseAnim.stop(); drainAnim.restart() }
    }
    function attemptUnlock() {
        if (!secured || busy || authenticated || !password.text.length || password.inputMethodComposing) return
        const secret = password.text
        if (!Flags.reduceMotion) {
            drainAnim.stop(); releaseAnim.stop()
            if (blobDrain > 0) blobScale = 0
            blobDrain = 0
            gathering = true
            gatherAnim.restart()
        }
        password.clear()
        unlockRequested(secret)
    }
    function choosePower(action) {
        if (authenticated) return
        if (action === "suspend" || pendingPower === action) {
            powerRequested(action)
            pendingPower = ""
            powerMenu.close()
        } else { pendingPower = action; confirmation.restart() }
    }
    Timer { interval: 1000; repeat: true; running: root.visible; onTriggered: root.now = Regional.now() }
    Timer { id: confirmation; interval: 3500; onTriggered: root.pendingPower = "" }
    Rectangle { anchors.fill: parent; color: Theme.background }
    // The captured desktop: exact on the first frame, so locking starts from
    // what was on screen, then blurred while the wallpaper takes over.
    Image {
        id: snapshotImage
        anchors.fill: parent
        source: root.snapshotSource
        asynchronous: false
        cache: false
        smooth: true
        fillMode: Image.Stretch
        visible: root.hasSnapshot && root.wallpaperShow < 0.999
        layer.enabled: visible && root.snapshotBlur > 0.001 && !Flags.reduceMotion
        layer.effect: MultiEffect { autoPaddingEnabled: false; blurEnabled: true; blurMax: 48; blur: root.snapshotBlur }
    }
    Item {
        id: wallpaperBackdrop
        anchors.fill: parent
        clip: true
        opacity: root.wallpaperShow
        visible: opacity > 0.001
        scale: 1 + 0.03 * (1 - root.decel(root.span(root.entryT, 0.12, 1)))
        Image {
            id: wallpaperImage
            anchors.fill: parent
            anchors.margins: -64
            source: root.wallpaper ? "file://" + root.wallpaper.split("/").map(encodeURIComponent).join("/") : ""
            sourceSize: Qt.size(root.width + 128, root.height + 128)
            asynchronous: !root.hasSnapshot
            fillMode: Image.PreserveAspectCrop
            // Blur only while the card asks for focus; at rest the wallpaper stays sharp.
            layer.enabled: root.wallpaperBlur > 0.004 && !Flags.reduceMotion
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 40; blur: root.wallpaperBlur }
        }
    }
    // Light veil: legibility without burying the wallpaper; deepens a little
    // while the card is open.
    Rectangle {
        anchors.fill: parent
        opacity: root.veilShow
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.background, 0.36 + 0.18 * root.cardT) }
            GradientStop { position: 0.5; color: Qt.alpha(Theme.background, 0.44 + 0.2 * root.cardT) }
            GradientStop { position: 1; color: Qt.alpha(Theme.background, 0.6 + 0.14 * root.cardT) }
        }
    }
    // Without a desktop frame the lock surface stays opaque while its wallpaper and content enter.
    Rectangle { anchors.fill: parent; color: Theme.background; opacity: root.hasSnapshot ? 0 : 1 - root.smooth(root.span(root.entryT, 0, 0.7)); visible: opacity > 0.001 }
    MouseArea {
        anchors.fill: parent
        enabled: root.secured && !root.authActive && !root.authenticated
        onClicked: root.activateInput("")
    }
    LockGlass {
        id: lockBody
        unit: root.unit
        objectName: "lockBody"
        readonly property real restW: 190 * root.unit
        readonly property real restH: IslandGeometry.restHeight * root.unit
        readonly property real restY: 26 * root.unit
        // Rest pill measured against the island: grows out of it on entry, returns on exit.
        readonly property real pillW: root.islandRect.width + (restW - root.islandRect.width) * root.pillForm
        readonly property real pillH: root.islandRect.height + (restH - root.islandRect.height) * root.pillForm
        readonly property real pillY: root.islandRect.y + (restY - root.islandRect.y) * root.pillForm
        opacity: root.pillShow * (1 - root.pillFade)
        visible: opacity > 0.001
        // Marea: the pill never turns into a card. It descends and widens into
        // the password capsule and stays a capsule the whole way.
        width: pillW + (root.capWidth - pillW) * root.expansion
        height: pillH + (root.capH - pillH) * root.expansion
        x: (root.width - width) / 2
        y: pillY + (root.capY - pillY) * root.travel
        radius: height / 2
        // A rejection sloshes the capsule like liquid in a tube: squeezed,
        // rebounding past rest, settling without a corrective step.
        transform: Scale {
            origin.x: lockBody.width / 2; origin.y: lockBody.height / 2
            xScale: 1 + 0.035 * root.slosh
            yScale: 1 - 0.13 * root.slosh
        }
        Rectangle {
            id: field
            objectName: "lockField"
            // The slosh deforms the material only; contents keep their shape.
            transform: Scale {
                origin.x: field.width / 2; origin.y: field.height / 2
                xScale: 1 / (1 + 0.035 * root.slosh)
                yScale: 1 / (1 - 0.13 * root.slosh)
            }
            property real dotOffset: 0
            property int nextDotId: 0
            readonly property real dotSize: Math.round(13 * root.unit)
            readonly property real dotStep: Math.round(20 * root.unit)
            function syncDots() {
                const difference = password.text.length - dotModel.count
                if (difference > 0) {
                    const at = Math.max(0, Math.min(dotModel.count, password.cursorPosition - difference))
                    for (let i = 0; i < difference; i++) dotModel.insert(at + i, {slot: nextDotId++})
                } else if (difference < 0) {
                    const at = Math.max(0, Math.min(dotModel.count + difference, password.cursorPosition))
                    dotModel.remove(at, -difference)
                }
                Qt.callLater(updateDotOffset)
            }
            function updateDotOffset() {
                const total = passwordDots.contentWidth
                const available = dotViewport.width
                if (available <= 0) return
                if (total <= available) {
                    dotOffset = (available - total) / 2
                    return
                }
                const caret = password.cursorPosition * dotStep + dotOffset
                if (caret > available - 6 * root.unit) dotOffset = available - 6 * root.unit - password.cursorPosition * dotStep
                else if (caret < 6 * root.unit) dotOffset = 6 * root.unit - password.cursorPosition * dotStep
                dotOffset = Math.max(available - total, Math.min(0, dotOffset))
            }
            anchors.fill: parent
            radius: height / 2
            opacity: root.contentExposure
            color: root.authenticated ? Qt.alpha(Theme.accent, 0.16) : root.showError ? Qt.alpha(Theme.error, 0.14) : "transparent"
            border.width: 1
            border.color: root.authenticated ? Qt.alpha(Theme.accent, 0.6) : root.showError ? Qt.alpha(Theme.error, 0.7) : password.activeFocus ? Qt.alpha(Theme.accent, 0.4) : "transparent"
            Behavior on color { ColorAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
            LockGlyph {
                x: Math.round(22 * root.unit)
                anchors.verticalCenter: parent.verticalCenter
                open: root.authenticated
                size: 18 * root.unit
                color: root.showError ? Qt.tint(root.secondary, Qt.alpha(Theme.error, 0.6)) : root.secondary
                opacity: Math.max(0, 1 - root.successProgress * 3)
            }
            TextField {
                id: password
                objectName: "lockPassword"
                // Symmetric margins keep the beads centred on the capsule, where
                // the submit drop gathers and the welcome appears.
                anchors.left: parent.left; anchors.leftMargin: 52 * root.unit
                anchors.right: parent.right; anchors.rightMargin: 52 * root.unit
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                padding: 0
                background: null
                color: root.responseVisible ? root.ink : "transparent"
                placeholderTextColor: "transparent"
                InputPlaceholder {
                    input: password
                    // InputPlaceholder drives its own opacity; the drop hides it through colour.
                    color: Qt.alpha(root.secondary, root.gathering ? 0 : 1)
                    Behavior on color { ColorAnimation { duration: root.beadMs(Motion.standard) } }
                    horizontalAlignment: Text.AlignHCenter
                    motionActive: root.authActive && root.contentOpacity > 0.01 && !root.retiring
                }
                placeholderText: root.promptText
                font.family: Theme.fontMedia; font.pixelSize: 15 * root.textScale
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
                passwordMaskDelay: 0
                cursorVisible: root.responseVisible
                cursorDelegate: InputCaret {
                    input: password
                    color: root.ink
                    motionActive: root.responseVisible && root.contentOpacity > 0.01 && !root.retiring
                }
                opacity: Math.max(0, 1 - root.successProgress * 4)
                enabled: root.secured && !root.busy && !root.authenticated
                selectByMouse: false
                Accessible.name: root.promptText
                onTextChanged: {
                    field.syncDots()
                    if (text.length && root.errorText) root.errorDismissed = true
                }
                onCursorPositionChanged: Qt.callLater(field.updateDotOffset)
                onAccepted: root.attemptUnlock()
                Keys.onEscapePressed: { clear(); root.authActive = false }
            }
            Item {
                id: dotViewport
                objectName: "lockPasswordDotViewport"
                x: password.x; y: 0
                width: password.width; height: parent.height
                clip: true
                visible: (!root.responseVisible || releaseAnim.running) && (password.length > 0 || root.gathering) && root.successProgress < 0.999
                onWidthChanged: Qt.callLater(field.updateDotOffset)
                Rectangle {
                    readonly property int first: Math.min(password.selectionStart, password.selectionEnd)
                    readonly property int last: Math.max(password.selectionStart, password.selectionEnd)
                    anchors.verticalCenter: parent.verticalCenter
                    x: passwordDots.x + first * field.dotStep + 1 * root.unit
                    width: Math.max(0, (last - first) * field.dotStep - 2 * root.unit)
                    height: 24 * root.unit; radius: height / 2
                    color: Theme.accent
                    opacity: last > first ? 0.34 : 0
                    Behavior on x { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.hover; easing.type: Easing.OutQuad } }
                    Behavior on width { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.hover; easing.type: Easing.OutQuad } }
                    Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast; easing.type: Motion.easeStandard } }
                }
                // Liquid beads: the bead layer is blurred, then thresholded back to
                // a crisp surface, so beads that come close fuse like droplets.
                // Reduced motion keeps plain round beads.
                Item {
                    id: liquid
                    anchors.fill: parent
                    readonly property bool active: !Flags.reduceMotion && dotViewport.visible && root.visible
                    layer.enabled: active
                    layer.effect: ShaderEffect {
                        property var source
                        property color ink: root.ink
                        property real threshold: 0.36
                        property real softness: 0.06
                        property real sheen: 0.45
                        fragmentShader: Qt.resolvedUrl("shaders/drops.frag.qsb")
                    }
                    Item {
                        id: beadField
                        anchors.fill: parent
                        layer.enabled: liquid.active
                        layer.effect: MultiEffect { autoPaddingEnabled: false; blurEnabled: true; blurMax: Math.round(24 * root.unit); blur: 1 }
                        ListModel { id: dotModel }
                        ListView {
                            id: passwordDots
                            objectName: "lockPasswordDots"
                            y: 0
                            height: parent.height
                            // A zero-width ListView cannot create its first delegate.
                            width: Math.max(1, dotModel.count * field.dotStep)
                            x: field.dotOffset
                            orientation: ListView.Horizontal
                            interactive: false
                            spacing: 0
                            model: dotModel
                            onContentWidthChanged: Qt.callLater(field.updateDotOffset)
                            Behavior on x { NumberAnimation { duration: root.beadMs(Motion.fast); easing.type: Motion.easeStandard } }
                            // A new bead falls in stretched, squashes on landing and
                            // wobbles still.
                            add: Transition {
                                SequentialAnimation {
                                    PropertyAction { property: "lift"; value: 1 }
                                    PropertyAction { property: "squash"; value: -0.55 }
                                    ParallelAnimation {
                                        NumberAnimation { property: "lift"; to: 0; duration: root.beadMs(Motion.fast); easing.type: Easing.InQuad }
                                        NumberAnimation { property: "squash"; to: -0.12; duration: root.beadMs(Motion.fast); easing.type: Easing.InQuad }
                                    }
                                    NumberAnimation { property: "squash"; to: 0.26; duration: root.beadMs(Motion.press); easing.type: Easing.OutQuad }
                                    NumberAnimation { property: "squash"; to: 0; duration: root.beadMs(Motion.standard); easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                                }
                            }
                            // A deleted bead flows into its neighbour; on submit
                            // every bead streams into the centre drop.
                            remove: Transition {
                                NumberAnimation { property: "absorb"; to: 1; duration: root.beadMs(root.gathering ? Motion.standard : Motion.standardSmall); easing.type: Easing.InOutCubic }
                            }
                            displaced: Transition { NumberAnimation { properties: "x,y"; duration: root.beadMs(Motion.standardSmall); easing.type: Motion.easeStandard } }
                            delegate: Item {
                                id: bead
                                required property int index
                                required property int slot
                                property real lift: 0
                                property real squash: 0
                                property real absorb: 0
                                property int lastIndex: 0
                                onIndexChanged: if (index >= 0) lastIndex = index
                                readonly property real reach: root.gathering && !drainAnim.running
                                    ? beadField.width / 2 - (passwordDots.x + x + width / 2)
                                    : (lastIndex > 0 ? -1 : 1) * field.dotStep
                                width: field.dotStep; height: passwordDots.height
                                Rectangle {
                                    width: field.dotSize; height: width; radius: width / 2
                                    x: (bead.width - width) / 2 + bead.reach * bead.absorb
                                    y: (bead.height - height) / 2 - bead.lift * 15 * root.unit
                                    color: !liquid.active && bead.index >= password.selectionStart && bead.index < password.selectionEnd ? Theme.accent : root.ink
                                    transform: [
                                        Scale {
                                            origin.x: field.dotSize / 2; origin.y: field.dotSize
                                            xScale: 1 + 0.6 * bead.squash
                                            yScale: 1 - bead.squash
                                        },
                                        Scale {
                                            origin.x: field.dotSize / 2; origin.y: field.dotSize / 2
                                            xScale: 1 - 0.72 * bead.absorb
                                            yScale: 1 - 0.72 * bead.absorb
                                        }
                                    ]
                                }
                            }
                        }
                        // The gathered drop: waits for PAM, drains on rejection,
                        // swells into the welcome on success.
                        Rectangle {
                            id: blob
                            objectName: "lockSubmitDrop"
                            readonly property real size: Math.round(22 * root.unit)
                            width: size; height: size; radius: size / 2
                            x: (beadField.width - size) / 2
                            y: (beadField.height - size) / 2 + root.blobDrain * beadField.height * 0.7
                            color: root.ink
                            visible: root.blobScale > 0.005
                            opacity: (1 - root.blobDrain) * (1 - root.smoothReveal(root.successProgress, 0.3))
                            transform: Scale {
                                readonly property real swell: root.blobScale * (1 + root.blobBreath + 0.5 * root.successProgress)
                                origin.x: blob.size / 2; origin.y: blob.size / 2
                                xScale: swell * (1 - 0.4 * root.blobDrain)
                                yScale: swell * (1 + 0.6 * root.blobDrain)
                            }
                        }
                    }
                }
            }
            LockButton {
                id: submit
                anchors.right: parent.right; anchors.rightMargin: 8 * root.unit
                anchors.verticalCenter: parent.verticalCenter
                unit: root.unit
                width: 40 * root.unit; height: width
                iconSize: 21 * root.unit
                flatStyle: !enabled
                opacity: Math.max(0, 1 - root.successProgress * 4)
                iconName: root.showError && !root.busy ? "refresh" : "arrow_forward"
                text: I18n.tr("Desbloquear")
                enabled: root.secured && !root.busy && !root.authenticated && password.text.length > 0
                onClicked: root.attemptUnlock()
            }
            Row {
                anchors.centerIn: parent
                spacing: 8 * root.unit
                opacity: Math.max(0, (root.successProgress - 0.3) / 0.7)
                scale: 0.85 + 0.15 * root.successProgress
                ConfirmationIndicator { anchors.verticalCenter: parent.verticalCenter; width: 22 * root.unit; height: width; s: root.unit; status: root.authenticated ? "success" : "" }
                Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Bienvenido"); font.family: Theme.fontMedia; font.pixelSize: 15 * root.textScale; font.weight: Font.Medium; color: root.ink }
            }
        }
    }
    Row {
        id: statusRow
        anchors.horizontalCenter: parent.horizontalCenter
        y: lockBody.y + (lockBody.height - height) / 2
        spacing: 10 * root.unit
        // Present at rest and again while the capsule folds back to announce the unlock.
        opacity: root.statusIn * (1 - root.smoothReveal(Math.min(1, root.cardT / 0.18), 0)) * (root.retiring ? root.statusReturn : 1)
        visible: opacity > 0.001
        scale: 0.94 + 0.06 * Math.min(root.statusIn, root.retiring ? 1 - root.pillLeave : 1)
        LockGlyph { open: root.authenticated; size: 20 * root.unit; color: root.ink; anchors.verticalCenter: parent.verticalCenter }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.authenticated ? I18n.tr("Desbloqueado") : I18n.tr("Bloqueado")
            font.family: Theme.fontMedia; font.pixelSize: 13 * root.textScale; font.weight: Font.Medium
            color: root.ink
        }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 30 * root.unit
        spacing: 12 * root.unit
        opacity: root.contextOpacity
        visible: opacity > 0.001
        Text { visible: !!root.weather.temp; text: root.weather.temp || ""; font.family: Theme.fontMedia; font.pixelSize: 13 * root.textScale; color: root.secondary }
        Text { visible: UPower.displayDevice.isLaptopBattery; text: Math.round(UPower.displayDevice.percentage * 100) + "%"; font.family: Theme.fontMedia; font.pixelSize: 13 * root.textScale; color: root.secondary }
        Text { visible: root.preview; text: I18n.tr("Vista previa"); font.family: Theme.fontMedia; font.pixelSize: 12 * root.textScale; color: root.secondary }
    }
    Column {
        id: clock
        objectName: "lockRestClock"
        // Shared element: typing docks the clock as a small time at the top
        // instead of dropping it, and releasing input brings it back.
        readonly property real dock: root.smooth(root.presentation)
        readonly property real dockScale: 0.34
        readonly property real restY: (root.height - height) / 2 - 34 * root.unit * root.restingMedia
        readonly property real dockY: 52 * root.unit
        width: Math.min(Math.max(clockTime.implicitWidth, clockDate.implicitWidth, clockHint.implicitWidth), root.width - 48 * root.unit)
        x: (root.width - width) / 2
        y: restY + (dockY - restY) * dock
        transform: Scale {
            origin.x: clock.width / 2; origin.y: 0
            xScale: 1 + (clock.dockScale - 1) * clock.dock
            yScale: 1 + (clock.dockScale - 1) * clock.dock
        }
        opacity: root.clockIn * root.retirementOpacity
        visible: opacity > 0.001
        layer.enabled: visible
        layer.smooth: true
        layer.mipmap: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#40000000"; shadowBlur: 0.25; shadowVerticalOffset: 2 }
        spacing: 8 * root.unit
        Text {
            id: clockTime
            width: Math.min(implicitWidth, parent.width)
            x: (parent.width - width) / 2
            text: Flags.time12h ? Qt.formatTime(root.now, "h:mm AP").replace(/\s*[AP]M$/, "") : Qt.formatTime(root.now, "HH:mm")
            font.family: Theme.fontMedia
            font.pixelSize: 124 * root.unit
            font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
            font.letterSpacing: -2 * root.unit
            renderType: Text.CurveRendering
            color: root.ink
            transform: Translate { y: 22 * root.unit * (1 - root.clockIn) }
        }
        Text {
            id: clockDate
            width: Math.min(implicitWidth, parent.width)
            x: (parent.width - width) / 2
            text: Regional.locale.toString(root.now, I18n.language === "en" ? "dddd, MMMM d" : "dddd, d 'de' MMMM")
            elide: Text.ElideRight
            font.family: Theme.fontMedia
            font.pixelSize: 18 * root.textScale
            font.weight: Font.Medium
            color: root.ink
            opacity: root.dateIn * (1 - root.smooth(root.span(clock.dock, 0, 0.45)))
            transform: Translate { y: 16 * root.unit * (1 - root.dateIn) }
        }
        Text {
            id: clockHint
            visible: root.secured
            width: Math.min(implicitWidth, parent.width)
            x: (parent.width - width) / 2
            text: I18n.tr("Escribe para desbloquear")
            font.family: Theme.fontMedia
            font.pixelSize: 14 * root.textScale
            color: root.secondary
            opacity: root.hintIn * (1 - root.smooth(root.span(clock.dock, 0, 0.3)))
            transform: Translate { y: 12 * root.unit * (1 - root.hintIn) }
        }
    }
    // Identity floats above the capsule, with no card behind it.
    Column {
        id: identity
        objectName: "lockIdentity"
        readonly property real reveal: root.smoothReveal(root.expansion, 0.5) * root.retirementOpacity
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(root.width - 48 * root.unit, 320 * root.unit)
        y: lockBody.y - height - 24 * root.unit + 14 * root.unit * (1 - reveal)
        opacity: reveal
        visible: opacity > 0.001
        scale: 0.92 + 0.08 * reveal
        spacing: 12 * root.unit
        UserAvatar {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76 * root.unit; height: width
            name: root.displayName; source: root.avatarSource
            fontFamily: Theme.fontMedia
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.displayName
            elide: Text.ElideRight
            font.family: Theme.fontMedia; font.weight: Font.DemiBold
            font.pixelSize: 17 * root.textScale; color: root.ink
        }
    }
    ConfirmationIndicator {
        // Leads the centred message.
        x: feedback.x + Math.max(0, (feedback.width - feedback.contentWidth) / 2) - width - 6 * root.unit
        y: feedback.y + Math.min(feedback.contentHeight, feedback.font.pixelSize * 1.4) / 2 - height / 2
        width: 18 * root.unit; height: width; s: root.unit
        opacity: feedback.opacity
        status: root.authenticated ? "" : root.busy ? "busy" : root.showError ? "error" : ""
    }
    Text {
        id: feedback
        objectName: "lockFeedback"
        readonly property bool capsWarning: capsLock.on && !root.busy && !root.showError && root.secured
        x: (root.width - width) / 2
        y: lockBody.y + lockBody.height + 16 * root.unit + 6 * root.unit * (1 - root.contentExposure)
        width: Math.min(root.width - 48 * root.unit, 380 * root.unit * Math.max(1, Flags.fontScale * 0.8))
        opacity: root.contentOpacity
        horizontalAlignment: Text.AlignHCenter
        text: root.authenticated ? "" : root.showError ? root.errorText : !root.secured ? I18n.tr("Protegiendo sesión…") : root.busy ? I18n.tr("Verificando…") : capsWarning ? I18n.tr("Bloq Mayús activado") : ""
        wrapMode: Text.WordWrap
        color: root.showError ? Qt.tint(Theme.foreground, Qt.alpha(Theme.error, 0.7)) : capsWarning ? Theme.foreground : root.secondary
        font.family: Theme.fontMedia; font.pixelSize: 12 * root.textScale
    }
    // One media capsule for rest and access: the same strip, never a second card.
    LockMedia {
        id: media
        objectName: "lockMedia"
        readonly property real reveal: root.chromeIn * root.mediaShow * root.retirementOpacity
        unit: root.unit
        player: root.mediaPlayer
        artUrl: root.artUrl
        trackKey: root.trackKey
        width: Math.min(440 * root.unit * Math.max(1, Flags.fontScale * 0.8), root.width - 2 * (26 + 44 + 14) * root.unit)
        height: implicitHeight
        x: (root.width - width) / 2
        y: root.height - height - 26 * root.unit + 18 * root.unit * (1 - reveal)
        opacity: reveal
        visible: opacity > 0.001
        scale: 0.96 + 0.04 * reveal
        enabled: root.secured && !root.authenticated && root.mediaShow > 0.99
    }
    LockButton {
        id: power
        objectName: "lockPowerButton"
        opacity: root.contentOpacity
        enabled: !root.authenticated
        expressive: true
        highlighted: powerMenu.opened
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 26 * root.unit
        unit: root.unit; iconName: "power_settings_new"; text: I18n.tr("Opciones de energía")
        onClicked: {
            if (powerMenu.visible) powerMenu.close()
            else { root.pendingPower = ""; powerMenu.open() }
        }
    }
    Popup {
        id: powerMenu
        objectName: "lockPowerMenu"
        property real reveal: 0
        x: root.width - width - 26 * root.unit
        y: power.y - height - 12 * root.unit
        width: Math.min(root.width - 32 * root.unit, 280 * root.unit * Math.max(1, Flags.fontScale))
        padding: 12 * root.unit
        focus: true
        opacity: reveal
        scale: 0.94 + 0.06 * reveal
        transformOrigin: Popup.BottomRight
        enter: Transition {
            NumberAnimation { target: powerMenu; property: "reveal"; to: 1; duration: Flags.reduceMotion ? 0 : Motion.emphasized; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.softFluid }
        }
        exit: Transition {
            NumberAnimation { target: powerMenu; property: "reveal"; to: 0; duration: Flags.reduceMotion ? 0 : Motion.fast; easing.type: Easing.InCubic }
        }
        background: Rectangle {
            radius: 24 * root.unit
            color: Qt.alpha(Theme.background, 0.94)
            LockGlass { anchors.fill: parent; radius: 24 * root.unit; unit: root.unit }
        }
        contentItem: Column {
            spacing: 6 * root.unit
            Text {
                width: parent.width
                height: 32 * root.textScale
                leftPadding: 12 * root.unit
                text: I18n.tr("Energía")
                color: root.secondary
                font.family: Theme.fontMedia
                font.pixelSize: 11 * root.textScale
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
            }
            Repeater {
                model: [
                    {label: I18n.tr("Suspender"), hint: I18n.tr("Conservar tu sesión"), action: "suspend", icon: "dark_mode"},
                    {label: I18n.tr("Reiniciar"), hint: I18n.tr("Volver a iniciar el equipo"), action: "reboot", icon: "restart_alt"},
                    {label: I18n.tr("Apagar"), hint: I18n.tr("Finalizar y apagar el equipo"), action: "poweroff", icon: "power_settings_new"}
                ]
                delegate: MotionButton {
                    id: powerOption
                    required property var modelData
                    required property int index
                    readonly property bool confirming: root.pendingPower === modelData.action
                    readonly property real exposure: Flags.reduceMotion ? 1 : root.smoothReveal(powerMenu.reveal, 0.12 + index * 0.13)
                    objectName: "lockPowerOption_" + modelData.action
                    width: parent.width; height: 62 * root.textScale
                    padding: 12 * root.unit
                    expressive: true
                    enabled: !root.authenticated && powerMenu.opened
                    opacity: exposure
                    transform: Translate { y: 8 * root.unit * (1 - powerOption.exposure) }
                    text: confirming ? I18n.tr("Confirmar %1").arg(modelData.label) : modelData.label
                    Accessible.name: text
                    contentItem: Item {
                        MaterialIcon {
                            id: optionIcon
                            width: 32 * root.unit; height: parent.height
                            interaction: powerOption.interaction
                            iconName: powerOption.confirming ? "check_circle" : powerOption.modelData.icon
                            font.pixelSize: 23 * root.unit
                            color: powerOption.confirming ? Theme.accent : root.ink
                            verticalAlignment: Text.AlignVCenter
                        }
                        Column {
                            anchors.left: optionIcon.right; anchors.leftMargin: 10 * root.unit
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            spacing: 3 * root.unit
                            Text {
                                width: parent.width
                                text: powerOption.text
                                color: powerOption.confirming ? Theme.accent : root.ink
                                font.family: Theme.fontMedia; font.pixelSize: 13 * root.textScale
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: powerOption.confirming ? I18n.tr("Pulsa de nuevo para confirmar") : powerOption.modelData.hint
                                color: root.secondary
                                font.family: Theme.fontMedia; font.pixelSize: 10 * root.textScale
                                elide: Text.ElideRight
                            }
                        }
                    }
                    background: Rectangle {
                        radius: 15 * root.unit
                        color: powerOption.confirming ? Qt.alpha(Theme.accent, Theme.alphaWash) : powerOption.hovered || powerOption.activeFocus ? Qt.alpha(Theme.foreground, Theme.alphaWash) : "transparent"
                        border.color: powerOption.activeFocus ? Qt.alpha(Theme.accent, 0.55) : "transparent"
                        Behavior on color { ColorAnimation { duration: Flags.reduceMotion ? 0 : Motion.hover } }
                    }
                    onClicked: root.choosePower(modelData.action)
                }
            }
        }
        onClosed: {
            confirmation.stop()
            root.pendingPower = ""
            if (root.authActive) password.forceActiveFocus(); else root.forceActiveFocus()
        }
    }
}
