import QtQuick
import QtQuick.Effects
import QtQuick.Controls.Basic
import "components"
import "Singletons"

// Isla login: bar/lockscreen/LockSurface.qml as an SDDM greeter. Same
// choreography, capsule, liquid beads, glyph and power menu; the island grows
// into the rest pill on entry and returns on login. No media, weather or
// battery. It only talks to the `sddm` context object, runs no commands and
// reads nothing outside this theme directory except the avatar SDDM supplies
// (install.sh copies components, shader, fonts, wallpaper and colours here).
Item {
    id: root
    width: 1280
    height: 800

    function cfg(key) { return config.stringValue(key) || "" }
    function hex(key, fallback) {
        const v = cfg(key)
        return /^#[0-9a-fA-F]{6}$/.test(v) ? v : fallback
    }
    function ranged(key, lo, hi) {
        const v = parseFloat(cfg(key))
        return isFinite(v) ? Math.max(lo, Math.min(hi, v)) : 1
    }
    function asset(key) { return /^[A-Za-z0-9._-]+$/.test(cfg(key)) ? Qt.resolvedUrl(cfg(key)) : "" }

    FontLoader { id: textFont; source: root.asset("font") }
    FontLoader { id: iconFont; source: root.asset("iconFont") }
    Component.onCompleted: {
        Theme.background = hex("bgColor", Theme.background)
        Theme.foreground = hex("foreground", Theme.foreground)
        Theme.iconSecondary = hex("secondary", Theme.iconSecondary)
        Theme.accent = hex("accent", Theme.accent)
        Theme.error = hex("error", Theme.error)
        Theme.cardTop = hex("cardTop", Theme.cardTop)
        Theme.cardBot = hex("cardBot", Theme.cardBot)
        Theme.outline = hex("outline", Theme.outline)
        Flags.time12h = config.boolValue("clock12h")
        Flags.reduceMotion = config.boolValue("reduceMotion")
        Flags.motionScale = ranged("motionScale", 0.25, 2)
        Flags.fontScale = ranged("fontScale", 0.75, 1.75)
        if (secured) entranceTimer.start()
        forceActiveFocus()
    }
    Binding { target: Theme; property: "fontMedia"; value: textFont.status === FontLoader.Ready ? textFont.name : "sans-serif" }

    readonly property var locale: Qt.locale(/^[a-z]{2}(_[A-Z]{2})?$/.test(cfg("locale")) ? cfg("locale") : "es_ES")
    readonly property bool english: locale.name.startsWith("en")
    function tr(es, en) { return english ? en : es }

    // SDDM state. Model roles are read through invisible items: SDDM models are not arrays.
    property int userIndex: Math.max(0, userModel.lastIndex)
    property int sessionIndex: Math.max(0, sessionModel.lastIndex)
    readonly property var user: users.count > userIndex ? users.itemAt(userIndex) : null
    readonly property string userName: user ? user.uName : userModel.lastUser
    readonly property var session: sessions.count > sessionIndex ? sessions.itemAt(sessionIndex) : null
    Repeater {
        id: users
        model: userModel
        delegate: Item {
            required property var model
            readonly property string uName: model.name || ""
            readonly property string uReal: model.realName || ""
            readonly property string uIcon: model.icon || ""
        }
    }
    Repeater {
        id: sessions
        model: sessionModel
        delegate: Item {
            required property var model
            readonly property string sName: model.name || ""
        }
    }
    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            // Reassign so a repeated failure triggers the rejection again.
            root.errorText = ""
            root.errorText = root.tr("Contraseña incorrecta", "Incorrect password")
        }
        function onLoginSucceeded() { root.busy = false; root.authenticated = true }
    }

    // ---- From here on: LockSurface's model, unchanged except where noted. ----
    readonly property bool secured: true
    property bool busy: false
    property bool authenticated: false
    readonly property bool responseVisible: false
    readonly property string promptText: tr("Contraseña", "Password")
    property string errorText: ""
    readonly property string displayName: user && user.uReal ? user.uReal : userName
    // The island's rest rectangle: the login grows out of it and returns to it.
    readonly property rect islandRect: Qt.rect((width - 88) / 2, 11, 88, 32)

    readonly property real unit: Math.max(0.45, Math.min(1.2, height / 900, width / 560))
    readonly property real textScale: unit * Flags.fontScale
    readonly property color ink: Theme.foreground
    readonly property color secondary: Theme.iconSecondary
    property date now: new Date()
    property bool entered: false
    property real entryT: entered ? 1 : 0
    property real exitT: retiring ? 1 : 0
    readonly property int entryDuration: Motion.morph * 2
    readonly property int exitDuration: Motion.morph * 2.2
    Behavior on entryT { NumberAnimation { duration: Flags.reduceMotion ? 0 : root.entryDuration } }
    Behavior on exitT { NumberAnimation { duration: Flags.reduceMotion ? 0 : root.exitDuration } }
    function span(t, a, b) { return Math.max(0, Math.min(1, (t - a) / (b - a))) }
    function smoothstep(t) { return t * t * (3 - 2 * t) }
    function decel(t) { return 1 - Math.pow(1 - t, 3) }
    readonly property real pillArrive: decel(span(entryT, 0, 0.55))
    readonly property real pillShow: smoothstep(span(entryT, 0, 0.22))
    readonly property real statusIn: smoothstep(span(entryT, 0.3, 0.6))
    readonly property real clockIn: decel(span(entryT, 0.28, 0.82))
    readonly property real dateIn: decel(span(entryT, 0.36, 0.9))
    readonly property real hintIn: decel(span(entryT, 0.44, 1))
    readonly property real chromeIn: smoothstep(span(entryT, 0.55, 1))
    readonly property real collapse: decel(span(exitT, 0.04, 0.4))
    readonly property real statusReturn: smoothstep(span(exitT, 0.2, 0.38)) * (1 - smoothstep(span(exitT, 0.58, 0.74)))
    readonly property real pillLeave: smoothstep(span(exitT, 0.55, 0.95))
    readonly property real pillFade: smoothstep(span(exitT, 0.74, 1))
    // No desktop frame before login: the wallpaper enters from the theme background.
    readonly property real wallpaperBlur: 0.55 * cardT
    readonly property real pillForm: Math.min(pillArrive, 1 - pillLeave)
    property bool authActive: false
    property bool errorDismissed: false
    readonly property bool showError: !!errorText && !errorDismissed && !authenticated
    readonly property bool capsOn: keyboard.capsLock
    property string pendingPower: ""
    property bool retiring: false
    readonly property real cardT: presentation * (1 - collapse)
    property real successProgress: authenticated ? 1 : 0
    readonly property real travel: 1 - Math.pow(1 - cardT, 3)
    readonly property real expansionPhase: Math.max(0, (cardT - 0.18) / 0.82)
    readonly property real expansion: expansionPhase * expansionPhase * (3 - 2 * expansionPhase)
    readonly property real contentExposure: smoothReveal(expansion, 0.84)
    readonly property real retirementOpacity: 1 - smoothstep(span(exitT, 0, 0.16))
    readonly property real contentOpacity: contentExposure * retirementOpacity
    property real capWidth: Math.min((authenticated ? 220 : 340) * unit, width - 48 * unit)
    Behavior on capWidth { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.standardLarge; velocity: -1 } }
    readonly property real capH: Math.round(56 * unit)
    readonly property real capY: Math.round(height / 2 + 20 * unit)
    readonly property real slosh: rejection.offset
    property bool gathering: false
    property real blobScale: 0
    property real blobDrain: 0
    property real blobBreath: 0
    function beadMs(ms) { return Flags.reduceMotion ? 0 : ms }
    function smoothReveal(value, start) {
        const t = Math.max(0, Math.min(1, (value - start) / (1 - start)))
        return t * t * (3 - 2 * t)
    }
    property real presentation: entered && authActive ? 1 : 0
    Behavior on successProgress { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.standard; velocity: -1 } }
    Behavior on presentation { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.morph; velocity: -1 } }
    Timer { id: entranceTimer; interval: Flags.reduceMotion ? 0 : 32; onTriggered: root.entered = true }
    Timer { interval: 15000; running: root.authActive && !password.text.length && !root.busy && !root.authenticated; onTriggered: root.authActive = false }
    function activateInput(initialText) {
        if (authenticated || retiring) return
        authActive = true
        password.forceActiveFocus()
        if (initialText) password.insert(password.cursorPosition, initialText)
    }
    onAuthActiveChanged: if (!authActive) { password.clear(); forceActiveFocus() }
    Keys.onPressed: event => {
        if (root.authActive || root.authenticated) return
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
    Timer { id: successHold; interval: Flags.reduceMotion ? 180 : Motion.standard + Motion.fast; onTriggered: root.retiring = true }
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
    // SDDM can drop a login without replying (invalid session, test mode):
    // give the field back instead of waiting forever.
    Timer {
        interval: 30000
        running: root.busy && !root.authenticated
        onTriggered: {
            root.busy = false
            root.errorText = ""
            root.errorText = root.tr("No se pudo iniciar sesión", "Could not sign in")
        }
    }
    // Without an answer (test mode never replies) the drop dissolves.
    Timer {
        interval: 1500
        running: root.gathering && !root.busy && !root.authenticated && !drainAnim.running && !releaseAnim.running
        onTriggered: releaseAnim.restart()
    }
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
        if (busy || authenticated || !password.text.length || password.inputMethodComposing) return
        const secret = password.text
        if (!Flags.reduceMotion) {
            drainAnim.stop(); releaseAnim.stop()
            if (blobDrain > 0) blobScale = 0
            blobDrain = 0
            gathering = true
            gatherAnim.restart()
        }
        password.clear()
        busy = true
        sddm.login(userName, secret, sessionIndex)
    }
    function choosePower(action) {
        if (authenticated) return
        if (action === "suspend" || pendingPower === action) {
            pendingPower = ""
            powerMenu.close()
            if (action === "suspend") sddm.suspend()
            else if (action === "reboot") sddm.reboot()
            else if (action === "poweroff") sddm.powerOff()
        } else { pendingPower = action; confirmation.restart() }
    }
    Timer { interval: 1000; repeat: true; running: root.visible; onTriggered: root.now = new Date() }
    Timer { id: confirmation; interval: 3500; onTriggered: root.pendingPower = "" }

    // Isla's glass (PillMaterial without media, reception or drift): shadow,
    // cardTop → cardBot body at the island's opacity and a hairline edge.
    component Glass: Item {
        id: glass
        property real radius: height / 2
        readonly property real reading: Math.max(0, Math.min(1, (height / root.unit - 38) / 58))
        readonly property real bodyAlpha: Math.min(1, 0.34 + 0.66 * (0.15 + 0.25 * reading))
        Rectangle {
            anchors.fill: parent
            radius: glass.radius
            color: Theme.cardBot
            opacity: 0.32 * glass.reading
            visible: opacity > 0.001
            layer.enabled: visible
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.72); shadowBlur: 0.95; shadowVerticalOffset: 7 * root.unit }
        }
        Rectangle {
            anchors.fill: parent
            radius: glass.radius
            border.width: 1
            border.color: Qt.alpha(Theme.foreground, 0.13)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Theme.cardTop, Math.min(1, glass.bodyAlpha + 0.08 * glass.reading)) }
                GradientStop { position: 0.46; color: Qt.alpha(Theme.cardBot, glass.bodyAlpha) }
                GradientStop { position: 1; color: Qt.alpha(Qt.darker(Theme.cardBot, 1 + 0.16 * glass.reading), Math.min(1, glass.bodyAlpha + 0.04 * glass.reading)) }
            }
        }
    }

    Rectangle { anchors.fill: parent; color: Theme.background }
    Item {
        id: wallpaperBackdrop
        anchors.fill: parent
        clip: true
        scale: 1 + 0.03 * (1 - root.decel(root.span(root.entryT, 0.12, 1)))
        Image {
            anchors.fill: parent
            anchors.margins: -64
            source: root.asset("background")
            sourceSize: Qt.size(root.width + 128, root.height + 128)
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            layer.enabled: root.wallpaperBlur > 0.004 && !Flags.reduceMotion
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 40; blur: root.wallpaperBlur }
        }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.background, 0.36 + 0.18 * root.cardT) }
            GradientStop { position: 0.5; color: Qt.alpha(Theme.background, 0.44 + 0.2 * root.cardT) }
            GradientStop { position: 1; color: Qt.alpha(Theme.background, 0.6 + 0.14 * root.cardT) }
        }
    }
    Rectangle { anchors.fill: parent; color: Theme.background; opacity: 1 - root.smoothstep(root.span(root.entryT, 0, 0.7)); visible: opacity > 0.001 }
    MouseArea {
        anchors.fill: parent
        enabled: !root.authActive && !root.authenticated
        onClicked: root.activateInput("")
    }
    Glass {
        id: lockBody
        readonly property real restW: 190 * root.unit
        readonly property real restH: 38 * root.unit
        readonly property real restY: 26 * root.unit
        readonly property real pillW: root.islandRect.width + (restW - root.islandRect.width) * root.pillForm
        readonly property real pillH: root.islandRect.height + (restH - root.islandRect.height) * root.pillForm
        readonly property real pillY: root.islandRect.y + (restY - root.islandRect.y) * root.pillForm
        opacity: root.pillShow * (1 - root.pillFade)
        visible: opacity > 0.001
        width: pillW + (root.capWidth - pillW) * root.expansion
        height: pillH + (root.capH - pillH) * root.expansion
        x: (root.width - width) / 2
        y: pillY + (root.capY - pillY) * root.travel
        transform: Scale {
            origin.x: lockBody.width / 2; origin.y: lockBody.height / 2
            xScale: 1 + 0.035 * root.slosh
            yScale: 1 - 0.13 * root.slosh
        }
        Rectangle {
            id: field
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
                anchors.left: parent.left; anchors.leftMargin: 52 * root.unit
                anchors.right: parent.right; anchors.rightMargin: 52 * root.unit
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                padding: 0
                background: null
                color: "transparent"
                placeholderTextColor: "transparent"
                InputPlaceholder {
                    input: password
                    color: Qt.alpha(root.secondary, root.gathering ? 0 : 1)
                    Behavior on color { ColorAnimation { duration: root.beadMs(Motion.standard) } }
                    horizontalAlignment: Text.AlignHCenter
                    motionActive: root.authActive && root.contentOpacity > 0.01 && !root.retiring
                }
                placeholderText: root.promptText
                font.family: Theme.fontMedia; font.pixelSize: 15 * root.textScale
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password
                passwordMaskDelay: 0
                cursorVisible: false
                // Greeter only: no clipboard, prediction or capitalisation on the secret.
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                opacity: Math.max(0, 1 - root.successProgress * 4)
                enabled: !root.busy && !root.authenticated
                selectByMouse: false
                Accessible.name: root.promptText
                onTextChanged: {
                    field.syncDots()
                    if (text.length && root.errorText) root.errorDismissed = true
                }
                onCursorPositionChanged: Qt.callLater(field.updateDotOffset)
                onAccepted: root.attemptUnlock()
                Keys.onEscapePressed: { clear(); root.authActive = false }
                Keys.onPressed: event => {
                    if (event.matches(StandardKey.Paste) || event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)) event.accepted = true
                }
            }
            Item {
                id: dotViewport
                x: password.x; y: 0
                width: password.width; height: parent.height
                clip: true
                visible: (password.length > 0 || root.gathering) && root.successProgress < 0.999
                onWidthChanged: Qt.callLater(field.updateDotOffset)
                // Liquid beads: the bead layer is blurred, then thresholded back
                // to a crisp surface, so beads that come close fuse like droplets.
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
                            y: 0
                            height: parent.height
                            width: Math.max(1, dotModel.count * field.dotStep)
                            x: field.dotOffset
                            orientation: ListView.Horizontal
                            interactive: false
                            spacing: 0
                            model: dotModel
                            onContentWidthChanged: Qt.callLater(field.updateDotOffset)
                            Behavior on x { NumberAnimation { duration: root.beadMs(Motion.fast); easing.type: Motion.easeStandard } }
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
                                    color: root.ink
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
                        Rectangle {
                            id: blob
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
                anchors.right: parent.right; anchors.rightMargin: 8 * root.unit
                anchors.verticalCenter: parent.verticalCenter
                unit: root.unit
                width: 40 * root.unit; height: width
                iconSize: 21 * root.unit
                flatStyle: !enabled
                opacity: Math.max(0, 1 - root.successProgress * 4)
                iconName: root.showError && !root.busy ? "refresh" : "arrow_forward"
                text: root.tr("Iniciar sesión", "Sign in")
                enabled: !root.busy && !root.authenticated && password.text.length > 0
                onClicked: root.attemptUnlock()
            }
            Row {
                anchors.centerIn: parent
                spacing: 8 * root.unit
                opacity: Math.max(0, (root.successProgress - 0.3) / 0.7)
                scale: 0.85 + 0.15 * root.successProgress
                ConfirmationIndicator { anchors.verticalCenter: parent.verticalCenter; width: 22 * root.unit; height: width; s: root.unit; status: root.authenticated ? "success" : "" }
                Text { anchors.verticalCenter: parent.verticalCenter; text: root.tr("Bienvenido", "Welcome"); font.family: Theme.fontMedia; font.pixelSize: 15 * root.textScale; font.weight: Font.Medium; color: root.ink }
            }
        }
    }
    // Rest pill: the lock glyph and this machine's name.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: lockBody.y + (lockBody.height - height) / 2
        spacing: 10 * root.unit
        opacity: root.statusIn * (1 - root.smoothReveal(Math.min(1, root.cardT / 0.18), 0)) * (root.retiring ? root.statusReturn : 1)
        visible: opacity > 0.001
        scale: 0.94 + 0.06 * Math.min(root.statusIn, root.retiring ? 1 - root.pillLeave : 1)
        LockGlyph { open: root.authenticated; size: 20 * root.unit; color: root.ink; anchors.verticalCenter: parent.verticalCenter }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.authenticated ? root.tr("Desbloqueado", "Unlocked") : (sddm.hostName || "Isla")
            font.family: Theme.fontMedia; font.pixelSize: 13 * root.textScale; font.weight: Font.Medium
            color: root.ink
        }
    }
    Column {
        id: clock
        readonly property real dock: root.smoothstep(root.presentation)
        readonly property real dockScale: 0.34
        readonly property real restY: (root.height - height) / 2
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
            text: root.locale.toString(root.now, root.english ? "dddd, MMMM d" : "dddd, d 'de' MMMM")
            elide: Text.ElideRight
            font.family: Theme.fontMedia
            font.pixelSize: 18 * root.textScale
            font.weight: Font.Medium
            color: root.ink
            opacity: root.dateIn * (1 - root.smoothstep(root.span(clock.dock, 0, 0.45)))
            transform: Translate { y: 16 * root.unit * (1 - root.dateIn) }
        }
        Text {
            id: clockHint
            width: Math.min(implicitWidth, parent.width)
            x: (parent.width - width) / 2
            text: root.tr("Escribe para iniciar sesión", "Type to sign in")
            font.family: Theme.fontMedia
            font.pixelSize: 14 * root.textScale
            color: root.secondary
            opacity: root.hintIn * (1 - root.smoothstep(root.span(clock.dock, 0, 0.3)))
            transform: Translate { y: 12 * root.unit * (1 - root.hintIn) }
        }
    }
    // Identity floats above the capsule, with no card behind it.
    Column {
        id: identity
        readonly property real reveal: root.smoothReveal(root.expansion, 0.5) * root.retirementOpacity
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(root.width - 48 * root.unit, 320 * root.unit)
        y: lockBody.y - height - 24 * root.unit + 14 * root.unit * (1 - reveal)
        opacity: reveal
        visible: opacity > 0.001
        scale: 0.92 + 0.08 * reveal
        spacing: 12 * root.unit
        // UserAvatar without Quickshell's ClippingRectangle: a masked face.
        Rectangle {
            id: avatar
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76 * root.unit; height: width; radius: width / 2
            color: Qt.alpha(Theme.accent, 0.10)
            border.color: Qt.alpha(Theme.foreground, 0.18)
            border.width: 1
            Text {
                anchors.centerIn: parent
                text: root.displayName.slice(0, 1).toLocaleUpperCase()
                font.family: Theme.fontMedia
                font.pixelSize: avatar.width * 0.42
                font.weight: Font.Light
                color: "#f8f8fa"
                visible: face.status !== Image.Ready
            }
            Image {
                id: face
                anchors.fill: parent
                anchors.margins: 2
                source: root.user && root.user.uIcon ? root.user.uIcon : ""
                sourceSize: Qt.size(256, 256)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                visible: false
            }
            MultiEffect {
                anchors.fill: face
                source: face
                visible: face.status === Image.Ready
                maskEnabled: true
                maskSource: faceMask
            }
            Item {
                id: faceMask
                anchors.fill: face
                layer.enabled: true
                visible: false
                Rectangle { anchors.fill: parent; radius: width / 2 }
            }
        }
        Item {
            width: parent.width
            height: nameText.implicitHeight
            Text {
                id: nameText
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, parent.width - 2 * switchUser.width)
                horizontalAlignment: Text.AlignHCenter
                text: root.displayName
                elide: Text.ElideRight
                font.family: Theme.fontMedia; font.weight: Font.DemiBold
                font.pixelSize: 17 * root.textScale; color: root.ink
            }
            // Only multi-user systems get a switcher.
            LockButton {
                id: switchUser
                visible: users.count > 1
                anchors.left: nameText.right; anchors.leftMargin: 6 * root.unit
                anchors.verticalCenter: nameText.verticalCenter
                unit: root.unit
                width: 30 * root.unit; height: width; iconSize: 17 * root.unit
                flatStyle: true
                iconName: "swap_horiz"
                text: root.tr("Cambiar de usuario", "Switch user")
                // A password typed for one account is never sent for another.
                enabled: !root.busy && !root.authenticated
                onClicked: {
                    password.clear()
                    root.errorText = ""
                    root.userIndex = (root.userIndex + 1) % users.count
                    root.activateInput("")
                }
            }
        }
    }
    ConfirmationIndicator {
        x: feedback.x + Math.max(0, (feedback.width - feedback.contentWidth) / 2) - width - 6 * root.unit
        y: feedback.y + Math.min(feedback.contentHeight, feedback.font.pixelSize * 1.4) / 2 - height / 2
        width: 18 * root.unit; height: width; s: root.unit
        opacity: feedback.opacity
        status: root.authenticated ? "" : root.busy ? "busy" : root.showError ? "error" : ""
    }
    Text {
        id: feedback
        readonly property bool capsWarning: root.capsOn && !root.busy && !root.showError
        x: (root.width - width) / 2
        y: lockBody.y + lockBody.height + 16 * root.unit + 6 * root.unit * (1 - root.contentExposure)
        width: Math.min(root.width - 48 * root.unit, 380 * root.unit)
        opacity: root.contentOpacity
        horizontalAlignment: Text.AlignHCenter
        text: root.authenticated ? "" : root.showError ? root.errorText : root.busy ? root.tr("Verificando…", "Verifying…") : capsWarning ? root.tr("Bloq Mayús activado", "Caps Lock is on") : ""
        wrapMode: Text.WordWrap
        color: root.showError ? Qt.tint(Theme.foreground, Qt.alpha(Theme.error, 0.7)) : capsWarning ? Theme.foreground : root.secondary
        font.family: Theme.fontMedia; font.pixelSize: 12 * root.textScale
    }
    // Session: greeter only. Cycles through installed sessions.
    MotionButton {
        id: sessionButton
        visible: sessions.count > 0
        enabled: !root.authenticated && !root.busy
        opacity: root.chromeIn * root.retirementOpacity
        anchors.left: parent.left; anchors.bottom: parent.bottom
        anchors.margins: 26 * root.unit
        height: 44 * root.unit
        leftPadding: 14 * root.unit; rightPadding: 18 * root.unit
        text: root.session ? root.session.sName : ""
        Accessible.name: root.tr("Sesión: %1", "Session: %1").arg(text)
        contentItem: Row {
            spacing: 8 * root.unit
            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                interaction: sessionButton.interaction
                iconName: "desktop_windows"
                font.pixelSize: 20 * root.unit
                color: Theme.iconPrimary
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sessionButton.text
                font.family: Theme.fontMedia; font.pixelSize: 13 * root.textScale; font.weight: Font.Medium
                color: root.ink
            }
        }
        background: Rectangle {
            radius: height / 2
            color: sessionButton.down ? Qt.alpha(Theme.foreground, Theme.alphaWashStrong) : sessionButton.hovered ? Qt.alpha(Theme.foreground, Theme.alphaWash) : Qt.alpha(Theme.foreground, Theme.alphaSoft)
            border.color: sessionButton.activeFocus ? Theme.accent : Theme.border
            Behavior on color { ColorAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
        }
        onClicked: {
            root.sessionIndex = (root.sessionIndex + 1) % sessions.count
            if (root.authActive) password.forceActiveFocus(); else root.forceActiveFocus()
        }
    }
    readonly property var powerActions: [
        {label: tr("Suspender", "Suspend"), hint: tr("Dormir el equipo", "Put the computer to sleep"), action: "suspend", icon: "dark_mode", can: sddm.canSuspend},
        {label: tr("Reiniciar", "Restart"), hint: tr("Volver a iniciar el equipo", "Start the computer again"), action: "reboot", icon: "restart_alt", can: sddm.canReboot},
        {label: tr("Apagar", "Shut down"), hint: tr("Apagar el equipo", "Turn the computer off"), action: "poweroff", icon: "power_settings_new", can: sddm.canPowerOff}
    ].filter(o => o.can)
    LockButton {
        id: power
        visible: root.powerActions.length > 0
        opacity: root.chromeIn * root.retirementOpacity
        enabled: !root.authenticated
        expressive: true
        highlighted: powerMenu.opened
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 26 * root.unit
        unit: root.unit; iconName: "power_settings_new"; text: root.tr("Opciones de energía", "Power options")
        onClicked: {
            if (powerMenu.visible) powerMenu.close()
            else { root.pendingPower = ""; powerMenu.open() }
        }
    }
    Popup {
        id: powerMenu
        property real reveal: 0
        x: root.width - width - 26 * root.unit
        y: power.y - height - 12 * root.unit
        width: Math.min(root.width - 32 * root.unit, 280 * root.unit)
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
            Glass { anchors.fill: parent; radius: 24 * root.unit }
        }
        contentItem: Column {
            spacing: 6 * root.unit
            Text {
                width: parent.width
                height: 32 * root.textScale
                leftPadding: 12 * root.unit
                text: root.tr("Energía", "Power")
                color: root.secondary
                font.family: Theme.fontMedia
                font.pixelSize: 11 * root.textScale
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
            }
            Repeater {
                model: root.powerActions
                delegate: MotionButton {
                    id: powerOption
                    required property var modelData
                    required property int index
                    readonly property bool confirming: root.pendingPower === modelData.action
                    readonly property real exposure: Flags.reduceMotion ? 1 : root.smoothReveal(powerMenu.reveal, 0.12 + index * 0.13)
                    width: parent.width; height: 62 * root.textScale
                    padding: 12 * root.unit
                    expressive: true
                    enabled: !root.authenticated && powerMenu.opened
                    opacity: exposure
                    transform: Translate { y: 8 * root.unit * (1 - powerOption.exposure) }
                    text: confirming ? root.tr("Confirmar %1", "Confirm %1").arg(modelData.label) : modelData.label
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
                                text: powerOption.confirming ? root.tr("Pulsa de nuevo para confirmar", "Press again to confirm") : powerOption.modelData.hint
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
