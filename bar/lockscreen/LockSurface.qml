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
    property url avatarSource: "file://" + Config.userAvatar
    property bool preview: false
    signal unlockRequested(string secret)
    signal powerRequested(string action)
    signal entryActivated()

    readonly property real unit: Math.max(0.45, Math.min(1.2, height / 900, width / 560))
    readonly property real textScale: unit * Flags.fontScale
    readonly property color ink: "#f8f8fa"
    readonly property color secondary: "#bdffffff"
    property date now: new Date()
    property bool entered: false
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
    readonly property real wingWidth: 230 * unit
    readonly property bool canShowWings: width >= access.width + 2 * wingWidth + 40 * unit
    property real authProgress: entered && authActive ? 1 : 0
    readonly property real wingProgress: canShowWings ? smoothReveal(expansion, 0.9) : 0
    function smoothReveal(value, start) {
        const t = Math.max(0, Math.min(1, (value - start) / (1 - start)))
        return t * t * (3 - 2 * t)
    }
    function weatherIcon(code) {
        if ([200, 386, 389, 392, 395].includes(code)) return "thunderstorm"
        if ([179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377].includes(code)) return "ac_unit"
        if ([176, 263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359].includes(code)) return "rainy"
        if ([143, 248, 260].includes(code)) return "foggy"
        if (code === 113) return "sunny"
        if (code === 116) return "partly_cloudy_day"
        return "cloud"
    }
    function weatherLabel(code) {
        if (code === 113) return qsTr("Despejado")
        if (code === 116) return qsTr("Parcialmente nublado")
        if ([119, 122].includes(code)) return qsTr("Nublado")
        if ([143, 248, 260].includes(code)) return qsTr("Niebla")
        if (weatherIcon(code) === "thunderstorm") return qsTr("Tormenta")
        if (weatherIcon(code) === "ac_unit") return qsTr("Nieve")
        return qsTr("Lluvia")
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
    Rectangle { anchors.fill: parent; color: "#151822" }
    Item {
        id: wallpaperBackdrop
        anchors.fill: parent
        clip: true
        Image {
            id: wallpaperImage
            anchors.fill: parent
            anchors.margins: -64
            source: root.wallpaper ? "file://" + root.wallpaper : ""
            sourceSize: Qt.size(root.width + 128, root.height + 128)
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            visible: false
        }
        MultiEffect {
            anchors.fill: wallpaperImage
            source: wallpaperImage
            blurEnabled: true
            blurMax: 48
            blur: 0.15 + 0.5 * root.presentation
        }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#30060a12" }
            GradientStop { position: 0.5; color: "#20060a12" }
            GradientStop { position: 1; color: "#60060a12" }
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.secured && !root.authActive && !root.authenticated
        onClicked: root.activateInput("")
    }
    LockGlass {
        id: lockBody
        objectName: "lockBody"
        wallpaperItem: wallpaperBackdrop
        sampleX: x
        sampleY: y
        width: 190 * root.unit + (access.width - 190 * root.unit) * root.expansion + 2 * root.wingWidth * root.wingProgress
        height: IslandGeometry.restHeight * root.unit + (access.height - IslandGeometry.restHeight * root.unit) * root.expansion
        x: (root.width - width) / 2
        y: 26 * root.unit + (access.y - 26 * root.unit) * root.travel
        radius: (IslandGeometry.restHeight / 2 + (34 - IslandGeometry.restHeight / 2) * root.expansion) * root.unit
    }
    Item {
        id: weatherWing
        x: lockBody.x
        y: lockBody.y
        width: root.wingWidth * root.wingProgress
        height: lockBody.height
        clip: true
        opacity: root.wingProgress * root.retirementOpacity
        Rectangle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 1; height: parent.height - 48 * root.unit; color: "#28ffffff" }
        Column {
            x: 24 * root.unit; y: 22 * root.unit
            width: root.wingWidth - 48 * root.unit
            spacing: 10 * root.unit
            Text { text: qsTr("AHORA"); color: root.secondary; font.family: Theme.fontMedia; font.pixelSize: 10 * root.textScale; font.letterSpacing: 1.4 * root.unit }
            Row {
                visible: !!root.weather.temp
                spacing: 10 * root.unit
                MaterialIcon { iconName: root.weatherIcon(root.weather.code); color: root.ink; font.pixelSize: 40 * root.unit }
                Text { text: root.weather.temp || ""; color: root.ink; font.family: Theme.fontMedia; font.pixelSize: 42 * root.textScale; font.weight: Font.Medium }
            }
            Text { visible: !root.weather.temp; text: Qt.formatDate(root.now, "dd MMM"); color: root.ink; font.family: Theme.fontMedia; font.pixelSize: 34 * root.textScale; font.weight: Font.Medium }
            Text { width: parent.width; text: root.weather.temp ? root.weatherLabel(root.weather.code) : qsTr("Clima no disponible"); elide: Text.ElideRight; color: root.ink; font.family: Theme.fontMedia; font.pixelSize: 13 * root.textScale }
            Rectangle { width: parent.width; height: 1; color: "#28ffffff" }
            Text { text: root.weather.feels ? qsTr("Sensación %1  ·  Humedad %2").arg(root.weather.feels).arg(root.weather.humidity) : Qt.locale().toString(root.now, "dddd, d MMMM"); color: root.secondary; font.family: Theme.fontMedia; font.pixelSize: 11 * root.textScale }
        }
    }
    Item {
        id: mediaWing
        x: lockBody.x + lockBody.width - width
        y: lockBody.y
        width: root.wingWidth * root.wingProgress
        height: lockBody.height
        clip: true
        opacity: root.wingProgress * root.retirementOpacity
        Rectangle { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 1; height: parent.height - 48 * root.unit; color: "#28ffffff" }
        Column {
            x: 20 * root.unit; y: 22 * root.unit
            width: root.wingWidth - 40 * root.unit
            spacing: 12 * root.unit
            Text { text: qsTr("REPRODUCIENDO"); color: root.secondary; font.family: Theme.fontMedia; font.pixelSize: 10 * root.textScale; font.letterSpacing: 1.4 * root.unit }
            LockMedia {
                width: parent.width; height: implicitHeight
                unit: root.unit
                wallpaperItem: wallpaperBackdrop
                sampleX: mediaWing.x + x; sampleY: mediaWing.y + y
                player: Players.active; artUrl: Players.artUrl; trackKey: Players.trackKey
                embedded: true
                visible: hasPlayer
            }
            Text { visible: !Players.active; width: parent.width; wrapMode: Text.WordWrap; text: qsTr("Nada reproduciéndose"); color: root.ink; font.family: Theme.fontMedia; font.pixelSize: 13 * root.textScale }
        }
    }
    Row {
        id: statusRow
        anchors.horizontalCenter: parent.horizontalCenter
        y: lockBody.y + (lockBody.height - height) / 2
        spacing: 12 * root.unit
        opacity: 1 - root.smoothReveal(Math.min(1, root.presentation / 0.18), 0)
        MaterialIcon { iconName: root.authenticated ? "lock_open" : "lock"; font.pixelSize: 20 * root.unit; color: root.ink }
        Text { text: Qt.formatTime(root.now, "HH:mm"); font.family: Theme.fontMedia; font.pixelSize: 14 * root.textScale; color: root.ink }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 34 * root.unit
        spacing: 10 * root.unit
        opacity: root.contextOpacity
        MaterialIcon { iconName: "lock"; font.pixelSize: 18 * root.unit; color: root.secondary }
        Text { visible: UPower.displayDevice.isLaptopBattery; text: Math.round(UPower.displayDevice.percentage * 100) + "%"; font.family: Theme.fontMedia; font.pixelSize: 13 * root.textScale; color: root.secondary }
        Text { visible: root.preview; text: qsTr("Vista previa"); font.family: Theme.fontMedia; font.pixelSize: 12 * root.textScale; color: root.secondary }
    }
    Column {
        id: clock
        opacity: (root.entered ? 1 : 0) * (1 - root.authProgress) * root.retirementOpacity
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#65000000"; shadowBlur: 0.35; shadowVerticalOffset: 1 }
        anchors.horizontalCenter: parent.horizontalCenter
        y: (116 - 24 * root.authProgress) * root.unit
        spacing: 8 * root.unit
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale().toString(root.now, "dddd, d MMMM")
            font.family: Theme.fontMedia
            font.pixelSize: 20 * root.textScale
            font.weight: Font.Medium
            color: root.ink
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Flags.time12h ? Qt.formatTime(root.now, "h:mm AP").replace(/\s*[AP]M$/, "") : Qt.formatTime(root.now, "HH:mm")
            font.family: Theme.fontMedia
            font.pixelSize: 104 * root.unit
            font.weight: Font.Medium
            font.letterSpacing: -3 * root.unit
            color: root.ink
        }
    }

    Item {
        id: access
        anchors.horizontalCenter: parent.horizontalCenter
        y: 330 * root.unit
        width: Math.min(324 * root.unit * Math.max(1, Flags.fontScale * 0.8), root.width - 32)
        height: 286 * root.unit
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
            color: root.authenticated ? "#3839b67a" : root.errorText ? "#28d84962" : "#1cffffff"
            Behavior on color { ColorAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
            border.color: root.authenticated ? "#a6efd0" : root.errorText ? "#ffb4bc" : password.activeFocus ? "#70ffffff" : "#25ffffff"
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
                x: password.x; y: password.y
                width: password.width; height: password.height
                clip: true
                visible: !root.responseVisible && root.successProgress < 0.25
                onWidthChanged: Qt.callLater(field.updateDotOffset)
                Rectangle {
                    readonly property int first: Math.min(password.selectionStart, password.selectionEnd)
                    readonly property int last: Math.max(password.selectionStart, password.selectionEnd)
                    anchors.verticalCenter: parent.verticalCenter
                    x: passwordDots.x + first * field.dotStep - 2 * root.unit
                    width: Math.max(0, (last - first) * field.dotStep - 2 * root.unit)
                    height: 24 * root.unit; radius: 4 * root.unit
                    color: "#a6d9f4"
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
                            color: dotSlot.index >= password.selectionStart && dotSlot.index < password.selectionEnd ? "#a6d9f4" : root.ink
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
            MaterialIcon { iconName: "check_circle"; font.pixelSize: 24 * root.unit; color: "#b8f7d8" }
            Text { text: qsTr("Listo"); font.family: Theme.fontMedia; font.pixelSize: 16 * root.textScale; color: root.ink }
        }
        Text {
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
    LockMedia {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 634 * root.unit
        width: access.width; height: implicitHeight
        unit: root.unit
        wallpaperItem: wallpaperBackdrop
        sampleX: x
        sampleY: y
        player: Players.active
        artUrl: Players.artUrl
        trackKey: Players.trackKey
        visible: hasPlayer && root.height >= 540 && root.mediaOpacity > 0 && root.wingProgress < 1
        opacity: root.mediaOpacity * (1 - root.wingProgress)
    }
    LockButton {
        id: power
        opacity: root.contentOpacity
        enabled: !root.authenticated
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 26 * root.unit
        unit: root.unit; iconName: "power_settings_new"; text: qsTr("Opciones de energía")
        onClicked: { root.pendingPower = ""; powerMenu.open() }
    }
    Popup {
        id: powerMenu
        x: root.width - width - 26 * root.unit
        y: power.y - height - 12 * root.unit
        width: 230 * root.unit
        padding: 12 * root.unit
        background: Rectangle { radius: 24 * root.unit; color: "#ed20232c"; border.color: "#45ffffff" }
        contentItem: Column {
            spacing: 6 * root.unit
            Repeater {
                model: [ {label: qsTr("Suspender"), action: "suspend"}, {label: qsTr("Reiniciar"), action: "reboot"}, {label: qsTr("Apagar"), action: "poweroff"} ]
                delegate: MotionButton {
                    id: powerOption
                    required property var modelData
                    width: parent.width; height: 44 * root.unit
                    text: root.pendingPower === modelData.action ? qsTr("Confirmar %1").arg(modelData.label) : modelData.label
                    contentItem: Text {
                        transform: Translate { y: -Motion.labelTravel * powerOption.interaction.presence }
                        text: powerOption.text; color: root.ink
                        font.family: Theme.fontMedia; font.pixelSize: 13 * root.textScale
                        verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
                    }
                    background: Rectangle {
                        radius: 12 * root.unit
                        color: parent.hovered || parent.activeFocus ? "#30ffffff" : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.hover } }
                    }
                    onClicked: root.choosePower(modelData.action)
                }
            }
        }
        onClosed: if (root.authActive) password.forceActiveFocus(); else root.forceActiveFocus()
    }
}
