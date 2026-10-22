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
    property string promptText: qsTr("Contraseña")
    property string errorText: ""
    property string displayName: Config.profile.displayName.trim() || username
    property url avatarSource: Config.userAvatarUrl
    property var player: null
    property string artUrl: ""
    property string trackKey: ""
    property bool preview: false
    signal unlockRequested(string secret)
    signal powerRequested(string action)
    signal entryActivated()

    readonly property real unit: Math.max(0.45, Math.min(1.2, height / 900, width / 560))
    readonly property real textScale: unit * Flags.fontScale
    readonly property color ink: Theme.foreground
    readonly property color secondary: Theme.iconSecondary
    property date now: new Date()
    property bool entered: false
    property real entrance: entered ? 1 : 0
    property real restingMedia: player?.isPlaying && !authActive && !authenticated ? 1 : 0
    Behavior on entrance { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.morph; easing.type: Easing.OutCubic } }
    Behavior on restingMedia { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.standard; velocity: -1 } }
    property bool authActive: false
    property string pendingPower: ""
    property bool retiring: false
    readonly property bool departing: retiring && retirementOpacity <= 0.001
    property real fieldOffset: 0
    property real successProgress: authenticated ? 1 : 0
    // One continuous trajectory: travel leads expansion, with no timer between them.
    readonly property real travel: 1 - Math.pow(1 - presentation, 3)
    readonly property real expansionPhase: Math.max(0, (presentation - 0.18) / 0.82)
    readonly property real expansion: expansionPhase * expansionPhase * (3 - 2 * expansionPhase)
    readonly property real contentExposure: smoothReveal(expansion, 0.84)
    property real retirementOpacity: retiring ? 0 : 1
    readonly property real contentOpacity: contentExposure * retirementOpacity
    readonly property real contextOpacity: smoothReveal(travel, 0.92) * retirementOpacity
    readonly property real mediaOpacity: smoothReveal(expansion, 0.94) * retirementOpacity
    readonly property bool wideRest: width >= 1040 * unit && Flags.fontScale <= 1.3
    readonly property bool canPlaceAccessMedia: accessMedia.hasPlayer && height >= access.height + accessMediaPanel.height + 120 * unit
    property real authProgress: entered && authActive ? 1 : 0
    function smoothReveal(value, start) {
        const t = Math.max(0, Math.min(1, (value - start) / (1 - start)))
        return t * t * (3 - 2 * t)
    }
    property real presentation: entered && authActive && !departing ? 1 : 0
    Behavior on authProgress { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.standard; velocity: -1 } }
    Behavior on successProgress { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.standard; velocity: -1 } }
    Behavior on retirementOpacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
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
        fieldOffset = 0
        powerMenu.close()
        successHold.start()
    }
    Timer {
        id: successHold
        interval: Flags.reduceMotion ? 180 : Motion.standard + Motion.fast
        onTriggered: root.retiring = true
    }
    Connections {
        target: Flags
        function onReduceMotionChanged() {
            if (Flags.reduceMotion) { rejection.stop(); root.fieldOffset = 0 }
        }
    }
    SequentialAnimation {
        id: rejection
        NumberAnimation { target: root; property: "fieldOffset"; to: -6 * root.unit; duration: 50 }
        NumberAnimation { target: root; property: "fieldOffset"; to: 6 * root.unit; duration: 50 }
        NumberAnimation { target: root; property: "fieldOffset"; to: -4 * root.unit; duration: 50 }
        NumberAnimation { target: root; property: "fieldOffset"; to: 4 * root.unit; duration: 50 }
        NumberAnimation { target: root; property: "fieldOffset"; to: 0; duration: 50 }
    }
    onSecuredChanged: if (secured) { if (!entered) entranceTimer.start(); if (authActive) password.forceActiveFocus(); else forceActiveFocus() }
    onBusyChanged: if (!busy && authActive) password.forceActiveFocus()
    onErrorTextChanged: if (errorText && !authenticated) {
        password.clear()
        authActive = true
        password.forceActiveFocus()
        if (!Flags.reduceMotion) rejection.restart()
    }
    function attemptUnlock() {
        if (!secured || busy || authenticated || !password.text.length || password.inputMethodComposing) return
        const secret = password.text
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
    Timer { interval: 1000; repeat: true; running: root.visible; onTriggered: root.now = new Date() }
    Timer { id: confirmation; interval: 3500; onTriggered: root.pendingPower = "" }
    Rectangle { anchors.fill: parent; color: Theme.background }
    Item {
        id: wallpaperBackdrop
        anchors.fill: parent
        clip: true
        scale: 1 + 0.025 * (1 - root.entrance)
        Image {
            id: wallpaperImage
            anchors.fill: parent
            anchors.margins: -64
            source: root.wallpaper ? "file://" + root.wallpaper.split("/").map(encodeURIComponent).join("/") : ""
            sourceSize: Qt.size(root.width + 128, root.height + 128)
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            visible: true
        }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.background, 0.68) }
            GradientStop { position: 0.5; color: Qt.alpha(Theme.background, 0.78) }
            GradientStop { position: 1; color: Qt.alpha(Theme.background, 0.82) }
        }
    }
    // The lock surface stays opaque while its wallpaper and content enter.
    Rectangle { anchors.fill: parent; color: Theme.background; opacity: 1 - root.entrance }
    MouseArea {
        anchors.fill: parent
        enabled: root.secured && !root.authActive && !root.authenticated
        onClicked: root.activateInput("")
    }
    LockGlass {
        id: lockBody
        unit: root.unit
        objectName: "lockBody"
        opacity: root.entrance
        width: 190 * root.unit + (access.width - 190 * root.unit) * root.expansion
        height: IslandGeometry.restHeight * root.unit + (access.height - IslandGeometry.restHeight * root.unit) * root.expansion
        x: (root.width - width) / 2
        y: 26 * root.unit + (access.y - 26 * root.unit) * root.travel
        radius: (IslandGeometry.restHeight / 2 + (34 - IslandGeometry.restHeight / 2) * root.expansion) * root.unit
    }
    Row {
        id: statusRow
        anchors.horizontalCenter: parent.horizontalCenter
        y: lockBody.y + (lockBody.height - height) / 2
        spacing: 12 * root.unit
        opacity: root.entrance * (1 - root.smoothReveal(Math.min(1, root.presentation / 0.18), 0))
        MaterialIcon { iconName: root.authenticated ? "lock_open" : "lock"; font.pixelSize: 20 * root.unit; color: root.ink }
        Text { text: qsTr("Bloqueado"); font.family: Theme.fontMedia; font.pixelSize: 13 * root.textScale; color: root.ink }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 34 * root.unit
        spacing: 12 * root.unit
        opacity: root.contextOpacity
        MaterialIcon { iconName: "lock"; font.pixelSize: 18 * root.unit; color: root.secondary }
        Text { visible: !!root.weather.temp; text: root.weather.temp || ""; font.family: Theme.fontMedia; font.pixelSize: 13 * root.textScale; color: root.secondary }
        Text { visible: UPower.displayDevice.isLaptopBattery; text: Math.round(UPower.displayDevice.percentage * 100) + "%"; font.family: Theme.fontMedia; font.pixelSize: 13 * root.textScale; color: root.secondary }
        Text { visible: root.preview; text: qsTr("Vista previa"); font.family: Theme.fontMedia; font.pixelSize: 12 * root.textScale; color: root.secondary }
    }
    Column {
        id: clock
        objectName: "lockRestClock"
        width: Math.min(Math.max(clockTime.implicitWidth, clockDate.implicitWidth, clockHint.implicitWidth), root.width - 48 * root.unit)
        x: (root.width - width) / 2 + (root.wideRest ? (80 * root.unit - (root.width - width) / 2) * root.restingMedia : 0)
        y: (root.height - height) / 2 - (root.wideRest ? 0 : 120 * root.unit * root.restingMedia)
        opacity: root.entrance * (1 - root.authProgress) * root.retirementOpacity
        transform: Translate { y: 18 * root.unit * (1 - root.entrance) }
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#40000000"; shadowBlur: 0.25; shadowVerticalOffset: 2 }
        spacing: 8 * root.unit
        Text {
            id: clockTime
            width: parent.width
            horizontalAlignment: Text.AlignLeft
            text: Flags.time12h ? Qt.formatTime(root.now, "h:mm AP").replace(/\s*[AP]M$/, "") : Qt.formatTime(root.now, "HH:mm")
            font.family: Theme.fontMedia
            font.pixelSize: 124 * root.unit
            font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
            font.letterSpacing: -2 * root.unit
            renderType: Text.CurveRendering
            color: root.ink
        }
        Text {
            id: clockDate
            width: parent.width
            horizontalAlignment: Text.AlignLeft
            text: Qt.locale("es_DO").toString(root.now, "dddd, d 'de' MMMM")
            elide: Text.ElideRight
            font.family: Theme.fontMedia
            font.pixelSize: 18 * root.textScale
            font.weight: Font.Medium
            color: root.ink
        }
        Text {
            id: clockHint
            visible: root.secured
            width: parent.width
            text: qsTr("Escribe para desbloquear")
            font.family: Theme.fontMedia
            font.pixelSize: 14 * root.textScale
            color: root.ink
        }
    }

    Loader {
        id: restingPlayer
        objectName: "lockRestingPlayer"
        x: root.wideRest ? root.width - width - 80 * root.unit : (root.width - width) / 2
        y: (root.wideRest ? (root.height - height) / 2 : clock.y + clock.height + 32 * root.unit) + 12 * root.unit * (1 - root.restingMedia)
        width: root.wideRest ? Math.min(600 * root.unit, root.width * 0.46) : Math.min(360 * root.unit * Math.max(1, Flags.fontScale * 0.8), root.width - 48)
        height: item ? item.implicitHeight : 344 * root.unit
        opacity: root.entrance * root.restingMedia * (1 - root.authProgress) * root.retirementOpacity
        visible: opacity > 0.001
        enabled: root.secured && !root.authActive && !root.authenticated && root.restingMedia > 0.99
        active: root.restingMedia > 0 || !!root.player?.isPlaying && !root.authActive
        sourceComponent: LockMedia {
            unit: root.unit
            player: root.player; artUrl: root.artUrl; trackKey: root.trackKey
        }
    }

    Item {
        id: access
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(48 * root.unit, (root.height - height - (root.canPlaceAccessMedia ? accessMediaPanel.height + 20 * root.unit : 0)) / 2)
        width: Math.min(324 * root.unit * Math.max(1, Flags.fontScale * 0.8), root.width - 32)
        height: Math.max(286 * root.unit, feedback.y + feedback.implicitHeight + 22 * root.unit)
        transform: Translate { y: lockBody.y - access.y }
        opacity: root.retirementOpacity
        enabled: !root.retiring
        Column {
            width: access.width - 44 * root.unit
            opacity: root.smoothReveal(root.expansion, 0.56)
            anchors.horizontalCenter: parent.horizontalCenter
            y: 30 * root.unit
            spacing: 16 * root.unit
            UserAvatar {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 84 * root.unit; height: width
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
        Rectangle {
            id: field
            property real dotOffset: 0
            property int nextDotId: 0
            readonly property real dotSize: Math.round(16 * root.unit)
            readonly property real dotStep: dotSize + 2 * root.unit
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
            opacity: root.contentExposure
            objectName: "lockField"
            x: (parent.width - width) / 2; y: 184 * root.unit
            width: root.authenticated ? Math.min(176 * root.unit, parent.width - 44 * root.unit) : parent.width - 44 * root.unit
            height: 46 * root.unit
            transform: Translate { x: root.fieldOffset }
            Behavior on width { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.standard; velocity: -1 } }
            radius: 15 * root.unit
            color: root.authenticated ? "#3839b67a" : root.errorText ? "#28d84962" : Qt.alpha(Theme.foreground, Theme.alphaSoft)
            Behavior on color { ColorAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
            border.color: root.authenticated ? "#a6efd0" : root.errorText ? "#ffb4bc" : password.activeFocus ? Qt.alpha(Theme.accent, Theme.alphaStrong) : Theme.border
            TextField {
                id: password
                objectName: "lockPassword"
                anchors.left: parent.left; anchors.leftMargin: 18 * root.unit
                anchors.right: submit.left; anchors.rightMargin: 8 * root.unit
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                padding: 0
                background: null
                color: root.responseVisible ? root.ink : "transparent"
                placeholderTextColor: "transparent"
                InputPlaceholder {
                    input: password
                    color: root.secondary
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
                onTextChanged: field.syncDots()
                onCursorPositionChanged: Qt.callLater(field.updateDotOffset)
                onAccepted: root.attemptUnlock()
                Keys.onEscapePressed: { clear(); root.authActive = false }
            }
            Item {
                id: dotViewport
                objectName: "lockPasswordDotViewport"
                x: password.x; y: password.y
                width: password.width; height: password.height
                clip: true
                visible: !root.responseVisible && password.length > 0 && root.successProgress < 0.25
                onWidthChanged: Qt.callLater(field.updateDotOffset)
                Rectangle {
                    readonly property int first: Math.min(password.selectionStart, password.selectionEnd)
                    readonly property int last: Math.max(password.selectionStart, password.selectionEnd)
                    anchors.verticalCenter: parent.verticalCenter
                    x: passwordDots.x + first * field.dotStep - 2 * root.unit
                    width: Math.max(0, (last - first) * field.dotStep - 2 * root.unit)
                    height: 24 * root.unit; radius: 4 * root.unit
                    color: Theme.accent
                    opacity: last > first ? 0.28 : 0
                    Behavior on x { NumberAnimation { duration: Flags.reduceMotion ? 0 : 80; easing.type: Easing.OutQuad } }
                    Behavior on width { NumberAnimation { duration: Flags.reduceMotion ? 0 : 80; easing.type: Easing.OutQuad } }
                    Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : 120; easing.type: Easing.OutCubic } }
                }
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
                    spacing: 2 * root.unit
                    model: dotModel
                    onContentWidthChanged: Qt.callLater(field.updateDotOffset)
                    Behavior on x { NumberAnimation { duration: Flags.reduceMotion || !root.visible ? 0 : Motion.fast; easing.type: Easing.OutCubic } }
                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: Flags.reduceMotion || !root.visible ? 0 : Motion.fast; easing.type: Easing.OutCubic }
                            NumberAnimation { property: "y"; from: 2 * root.unit; to: 0; duration: Flags.reduceMotion || !root.visible ? 0 : Motion.fast; easing.type: Easing.OutCubic }
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Flags.reduceMotion || !root.visible ? 0 : Motion.fast; easing.type: Easing.OutCubic }
                        }
                    }
                    remove: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "y"; to: 1 * root.unit; duration: Flags.reduceMotion || !root.visible ? 0 : Motion.fast; easing.type: Easing.InCubic }
                            NumberAnimation { property: "opacity"; to: 0; duration: Flags.reduceMotion || !root.visible ? 0 : Motion.fast; easing.type: Easing.InCubic }
                        }
                    }
                    displaced: Transition { NumberAnimation { properties: "x,y"; duration: Flags.reduceMotion || !root.visible ? 0 : Motion.fast; easing.type: Easing.OutCubic } }
                    delegate: Item {
                        id: dotSlot
                        required property int index
                        required property int slot
                        width: field.dotSize; height: passwordDots.height
                        transformOrigin: Item.Center
                        Rectangle {
                            anchors.centerIn: parent
                            width: field.dotSize; height: width
                            radius: Math.round(width * 0.24)
                            color: dotSlot.index >= password.selectionStart && dotSlot.index < password.selectionEnd ? Theme.accent : root.ink
                        }
                    }
                }
            }
            LockButton {
                id: submit
                anchors.right: parent.right; anchors.rightMargin: 4 * root.unit
                anchors.verticalCenter: parent.verticalCenter
                unit: root.unit
                width: 36 * root.unit; height: 36 * root.unit
                flatStyle: true
                opacity: Math.max(0, 1 - root.successProgress * 4)
                iconName: root.busy ? "hourglass_top" : root.errorText ? "refresh" : "arrow_forward"
                text: qsTr("Desbloquear")
                enabled: root.secured && !root.busy && !root.authenticated && password.text.length > 0
                onClicked: root.attemptUnlock()
            }
        }
        Row {
            anchors.centerIn: field
            spacing: 8 * root.unit
            opacity: root.contentExposure * Math.max(0, (root.successProgress - 0.25) / 0.75)
            scale: 0.85 + 0.15 * root.successProgress
            ConfirmationIndicator { width: 24 * root.unit; height: width; s: root.unit; status: root.authenticated ? "success" : "" }
            Text { text: qsTr("Listo"); font.family: Theme.fontMedia; font.pixelSize: 16 * root.textScale; color: root.ink }
        }
        ConfirmationIndicator {
            x: feedback.x - 20 * root.unit
            anchors.verticalCenter: feedback.verticalCenter
            width: 18 * root.unit; height: width; s: root.unit
            status: root.authenticated ? "" : root.busy ? "busy" : root.errorText ? "error" : ""
        }
        Text {
            id: feedback
            objectName: "lockFeedback"
            opacity: root.contentExposure
            x: 22 * root.unit; y: 243 * root.unit
            width: parent.width - 44 * root.unit
            horizontalAlignment: Text.AlignHCenter
            text: root.authenticated ? qsTr("Bienvenido") : root.errorText || (!root.secured ? qsTr("Protegiendo sesión…") : root.busy ? qsTr("Verificando…") : "")
            wrapMode: Text.WordWrap
            color: root.errorText ? "#ffc0c6" : root.secondary
            font.family: Theme.fontMedia; font.pixelSize: 11 * root.textScale
        }
    }
    Item {
        id: accessMediaPanel
        anchors.horizontalCenter: parent.horizontalCenter
        y: access.y + access.height + 20 * root.unit
        width: access.width + 32 * root.unit
        height: accessMedia.implicitHeight + 32 * root.unit
        visible: root.canPlaceAccessMedia && root.mediaOpacity > 0
        opacity: root.mediaOpacity
        LockGlass { anchors.fill: parent; radius: 28 * root.unit; unit: root.unit }
        LockMedia {
            id: accessMedia
            x: 16 * root.unit; y: 16 * root.unit
            width: parent.width - 32 * root.unit; height: implicitHeight
            unit: root.unit
            objectName: "lockAccessPlayer"
            player: root.player
            artUrl: root.artUrl
            trackKey: root.trackKey
        }
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
        unit: root.unit; iconName: "power_settings_new"; text: qsTr("Opciones de energía")
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
                text: qsTr("Energía")
                color: root.secondary
                font.family: Theme.fontMedia
                font.pixelSize: 11 * root.textScale
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
            }
            Repeater {
                model: [
                    {label: qsTr("Suspender"), hint: qsTr("Conservar tu sesión"), action: "suspend", icon: "dark_mode"},
                    {label: qsTr("Reiniciar"), hint: qsTr("Volver a iniciar el equipo"), action: "reboot", icon: "restart_alt"},
                    {label: qsTr("Apagar"), hint: qsTr("Finalizar y apagar el equipo"), action: "poweroff", icon: "power_settings_new"}
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
                    text: confirming ? qsTr("Confirmar %1").arg(modelData.label) : modelData.label
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
                                text: powerOption.confirming ? qsTr("Pulsa de nuevo para confirmar") : powerOption.modelData.hint
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
