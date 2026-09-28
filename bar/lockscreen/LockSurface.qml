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

    readonly property real unit: Math.max(0.45, Math.min(1.2, height / 900, width / 560))
    readonly property real textScale: unit * Flags.fontScale
    readonly property color ink: "#f8f8fa"
    readonly property color secondary: "#bdffffff"
    property date now: new Date()
    property bool entered: false
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
    function smoothReveal(value, start) {
        const t = Math.max(0, Math.min(1, (value - start) / (1 - start)))
        return t * t * (3 - 2 * t)
    }
    property real presentation: entered && !departing ? 1 : 0
    Behavior on successProgress { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.standard; velocity: -1 } }
    Behavior on retirementOpacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
    Behavior on presentation { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.morph; velocity: -1 } }
    Component.onCompleted: { if (secured) entranceTimer.start(); password.forceActiveFocus() }
    Timer { id: entranceTimer; interval: Flags.reduceMotion ? 0 : 32; onTriggered: root.entered = true }
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
        NumberAnimation { target: root; property: "fieldOffset"; to: -7 * root.unit; duration: Motion.fast * 0.35; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "fieldOffset"; to: 6 * root.unit; duration: Motion.fast * 0.55; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "fieldOffset"; to: -3 * root.unit; duration: Motion.fast * 0.45; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "fieldOffset"; to: 0; duration: Motion.fast * 0.5; easing.type: Easing.OutQuad }
    }
    onSecuredChanged: if (secured) { if (!entered) entranceTimer.start(); password.forceActiveFocus() }
    onBusyChanged: if (!busy) password.forceActiveFocus()
    onErrorTextChanged: if (errorText && !authenticated) {
        password.clear()
        password.forceActiveFocus()
        if (!Flags.reduceMotion) rejection.restart()
    }
    function attemptUnlock() {
        if (!secured || busy || authenticated || !password.text.length) return
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
    LockGlass {
        id: lockBody
        objectName: "lockBody"
        wallpaperItem: wallpaperBackdrop
        sampleX: x
        sampleY: y
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
        opacity: root.contextOpacity
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#65000000"; shadowBlur: 0.35; shadowVerticalOffset: 1 }
        anchors.horizontalCenter: parent.horizontalCenter
        y: 116 * root.unit
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
            width: lockBody.width - 44 * root.unit
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
                color: root.ink
                placeholderTextColor: root.secondary
                placeholderText: root.promptText
                font.family: Theme.fontMedia; font.pixelSize: 15 * root.textScale
                echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
                passwordMaskDelay: 0
                opacity: Math.max(0, 1 - root.successProgress * 4)
                enabled: root.secured && !root.busy && !root.authenticated
                selectByMouse: false
                Accessible.name: root.promptText
                onAccepted: root.attemptUnlock()
                Keys.onEscapePressed: clear()
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
        visible: hasPlayer && root.height >= 540
        opacity: root.mediaOpacity
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
        onClosed: password.forceActiveFocus()
    }
}
