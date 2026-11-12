import QtQuick
import QtQuick.Effects

// Isla login: the lock screen's composition (rest pill, clock, password capsule)
// as an SDDM greeter. It only talks to the `sddm` context object; it runs no
// commands and reads nothing outside this theme directory.
Rectangle {
    id: root
    width: 1280
    height: 800
    color: c("bgColor", "#14140c")

    function c(key, fallback) {
        const v = config.stringValue(key)
        return v && /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(v) ? v : fallback
    }

    readonly property color ink: c("foreground", "#e6e3d5")
    readonly property color secondary: c("secondary", "#cac7b6")
    readonly property color accent: c("accent", "#cbcb76")
    readonly property color danger: c("error", "#ffb4ab")
    readonly property color cardTop: c("cardTop", "#2b2a22")
    readonly property color cardBot: c("cardBot", "#1c1c14")
    readonly property string family: interFont.status === FontLoader.Ready ? interFont.name : "sans-serif"
    readonly property real unit: Math.max(0.45, Math.min(1.2, height / 900, width / 560))
    readonly property var locale: Qt.locale(config.stringValue("locale") || "es_ES")

    property date now: new Date()
    property bool authActive: false
    property bool busy: false
    property string errorText: ""
    property int userIndex: Math.max(0, userModel.lastIndex)
    property int sessionIndex: Math.max(0, sessionModel.lastIndex)
    property string pendingPower: ""

    readonly property var user: users.count > userIndex ? users.itemAt(userIndex) : null
    readonly property string userName: user ? user.uName : userModel.lastUser
    readonly property string displayName: user && user.uReal ? user.uReal : userName
    readonly property var session: sessions.count > sessionIndex ? sessions.itemAt(sessionIndex) : null

    FontLoader { id: interFont; source: config.stringValue("font") ? Qt.resolvedUrl(config.stringValue("font")) : "" }

    // Model roles read through invisible items: SDDM models are not JS arrays.
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

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    Timer { id: idleReturn; interval: 15000; running: root.authActive && password.length === 0 && !root.busy; onTriggered: root.authActive = false }
    Timer { id: powerConfirm; interval: 3500; onTriggered: root.pendingPower = "" }

    function activate() {
        authActive = true
        password.forceActiveFocus()
    }
    function submit() {
        if (busy || password.length === 0) return
        busy = true
        errorText = ""
        sddm.login(userName, password.text, sessionIndex)
    }
    function power(action) {
        if (pendingPower !== action) { pendingPower = action; powerConfirm.restart(); return }
        pendingPower = ""
        if (action === "suspend") sddm.suspend()
        else if (action === "reboot") sddm.reboot()
        else if (action === "poweroff") sddm.powerOff()
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            password.clear()
            root.busy = false
            root.errorText = qsTr("Contraseña incorrecta")
            shake.restart()
            password.forceActiveFocus()
        }
        function onLoginSucceeded() { root.errorText = "" }
    }

    // Backdrop: wallpaper, sharp at rest and softened while the capsule asks for focus.
    Image {
        id: wallpaper
        anchors.fill: parent
        anchors.margins: -48
        source: config.stringValue("background") ? Qt.resolvedUrl(config.stringValue("background")) : ""
        sourceSize: Qt.size(root.width + 96, root.height + 96)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        property real blur: root.authActive ? 0.55 : 0
        Behavior on blur { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        layer.enabled: blur > 0.004
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 40; blur: wallpaper.blur }
    }
    Rectangle {
        id: veil
        anchors.fill: parent
        property real deep: root.authActive ? 1 : 0
        Behavior on deep { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(root.color, 0.36 + 0.18 * veil.deep) }
            GradientStop { position: 0.5; color: Qt.alpha(root.color, 0.44 + 0.2 * veil.deep) }
            GradientStop { position: 1; color: Qt.alpha(root.color, 0.6 + 0.14 * veil.deep) }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: root.activate() }

    component Glass: Rectangle {
        radius: height / 2
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(root.cardTop, 0.82) }
            GradientStop { position: 1; color: Qt.alpha(root.cardBot, 0.9) }
        }
        border.width: 1
        border.color: Qt.alpha(root.ink, 0.12)
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: parent.radius * 0.6 }
            anchors.topMargin: 1
            height: 1
            color: Qt.alpha(root.ink, 0.16)
        }
    }

    // Lock glyph drawn from primitives so the theme needs no icon font.
    component LockGlyph: Item {
        property color tint: root.ink
        width: 12 * root.unit; height: 15 * root.unit
        Rectangle {
            x: parent.width * 0.18; width: parent.width * 0.64; height: parent.height * 0.62
            radius: width / 2; color: "transparent"; border.width: Math.max(1.5, 1.8 * root.unit); border.color: parent.tint
        }
        Rectangle {
            y: parent.height * 0.42; width: parent.width; height: parent.height * 0.58
            radius: 2.5 * root.unit; color: parent.tint
        }
    }

    // Rest pill, as on the lock screen.
    Glass {
        id: restPill
        width: pillRow.implicitWidth + 36 * root.unit
        height: 40 * root.unit
        x: (root.width - width) / 2
        y: 26 * root.unit
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 9 * root.unit
            LockGlyph { anchors.verticalCenter: parent.verticalCenter }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sddm.hostName || qsTr("Isla")
                font.family: root.family; font.pixelSize: 15 * root.unit; font.weight: Font.Medium
                color: root.ink
            }
        }
    }

    // Clock: centred at rest, docks upward when the capsule opens.
    Column {
        id: clock
        property real dock: root.authActive ? 1 : 0
        Behavior on dock { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }
        width: root.width - 48 * root.unit
        x: 24 * root.unit
        y: root.height * (0.36 - 0.14 * dock) - height / 2
        scale: 1 - 0.32 * dock
        transformOrigin: Item.Top
        spacing: 8 * root.unit
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#40000000"; shadowBlur: 0.25; shadowVerticalOffset: 2 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, config.boolValue("clock12h") ? "h:mm" : "HH:mm")
            font.family: root.family; font.pixelSize: 124 * root.unit; font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
            font.letterSpacing: -2 * root.unit
            renderType: Text.CurveRendering
            color: root.ink
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.locale.toString(root.now, root.locale.name.startsWith("es") ? "dddd, d 'de' MMMM" : "dddd, MMMM d")
            font.family: root.family; font.pixelSize: 18 * root.unit; font.weight: Font.Medium
            color: root.ink
            opacity: 1 - clock.dock
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Escribe para iniciar sesión")
            font.family: root.family; font.pixelSize: 14 * root.unit
            color: root.secondary
            opacity: 1 - clock.dock
        }
    }

    // Identity and password capsule.
    Item {
        id: auth
        property real shown: root.authActive ? 1 : 0
        Behavior on shown { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        width: Math.min(root.width - 48 * root.unit, 340 * root.unit)
        height: identity.height + 18 * root.unit + capsule.height + 14 * root.unit + feedback.height
        x: (root.width - width) / 2
        y: root.height * 0.5 - identity.height + 20 * root.unit * (1 - shown)
        opacity: shown
        visible: opacity > 0.001

        Column {
            id: identity
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10 * root.unit
            Rectangle {
                id: avatar
                anchors.horizontalCenter: parent.horizontalCenter
                width: 76 * root.unit; height: width; radius: width / 2
                color: Qt.alpha(root.cardTop, 0.9)
                border.width: 1; border.color: Qt.alpha(root.ink, 0.14)
                clip: true
                Text {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    text: root.displayName.slice(0, 1).toUpperCase()
                    font.family: root.family; font.pixelSize: 30 * root.unit; font.weight: Font.DemiBold
                    color: root.ink
                }
                Image {
                    id: face
                    anchors.fill: parent
                    source: root.user && root.user.uIcon ? root.user.uIcon : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: face
                    visible: face.status === Image.Ready
                    maskEnabled: true
                    maskSource: avatarMask
                }
                Item {
                    id: avatarMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    Rectangle { anchors.fill: parent; radius: width / 2 }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8 * root.unit
                Text {
                    text: root.displayName
                    font.family: root.family; font.pixelSize: 17 * root.unit; font.weight: Font.DemiBold
                    color: root.ink
                }
                // Only multi-user systems get a switcher.
                Text {
                    visible: users.count > 1
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⇄"
                    font.pixelSize: 15 * root.unit
                    color: userSwitch.containsMouse ? root.accent : root.secondary
                    MouseArea {
                        id: userSwitch
                        anchors.fill: parent; anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.userIndex = (root.userIndex + 1) % users.count; password.clear(); root.activate() }
                    }
                }
            }
        }

        Glass {
            id: capsule
            anchors.horizontalCenter: parent.horizontalCenter
            y: identity.height + 18 * root.unit
            width: parent.width
            height: 52 * root.unit
            border.color: root.errorText ? Qt.alpha(root.danger, 0.7) : password.activeFocus ? Qt.alpha(root.accent, 0.4) : Qt.alpha(root.ink, 0.12)
            transform: Translate { id: shakeShift }

            TextInput {
                id: password
                anchors.fill: parent
                opacity: 0
                echoMode: TextInput.Password
                passwordMaskDelay: 0
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                enabled: !root.busy
                focus: true
                selectByMouse: false
                persistentSelection: false
                onTextChanged: {
                    if (length > 0) { root.authActive = true; root.errorText = "" }
                    idleReturn.restart()
                }
                Keys.onReturnPressed: root.submit()
                Keys.onEnterPressed: root.submit()
                Keys.onEscapePressed: { clear(); root.authActive = false }
                // Clipboard paste is a common way to leak secrets on shared machines.
                Keys.onPressed: event => { if (event.matches(StandardKey.Paste) || event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)) event.accepted = true }
            }

            Text {
                anchors.centerIn: parent
                visible: password.length === 0
                text: root.busy ? qsTr("Iniciando sesión…") : qsTr("Contraseña")
                font.family: root.family; font.pixelSize: 15 * root.unit
                color: root.secondary
            }
            Row {
                anchors.centerIn: parent
                spacing: 7 * root.unit
                Repeater {
                    model: Math.min(password.length, 22)
                    delegate: Rectangle {
                        width: 13 * root.unit; height: width; radius: width / 2
                        color: root.busy ? root.accent : root.ink
                    }
                }
            }
        }

        Text {
            id: feedback
            anchors.horizontalCenter: parent.horizontalCenter
            y: capsule.y + capsule.height + 14 * root.unit
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.errorText || (keyboard.capsLock ? qsTr("Bloq Mayús activado") : " ")
            font.family: root.family; font.pixelSize: 12 * root.unit
            color: root.errorText ? Qt.tint(root.ink, Qt.alpha(root.danger, 0.7)) : root.secondary
        }

        SequentialAnimation {
            id: shake
            NumberAnimation { target: shakeShift; property: "x"; to: -10 * root.unit; duration: 60; easing.type: Easing.OutQuad }
            NumberAnimation { target: shakeShift; property: "x"; to: 8 * root.unit; duration: 90; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeShift; property: "x"; to: -4 * root.unit; duration: 90; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeShift; property: "x"; to: 0; duration: 110; easing.type: Easing.OutQuad }
        }
    }

    component Chip: Glass {
        id: chip
        property string label
        property bool confirming: false
        signal activated()
        width: chipText.implicitWidth + 28 * root.unit
        height: 34 * root.unit
        border.color: confirming ? Qt.alpha(root.accent, 0.6) : chipArea.containsMouse ? Qt.alpha(root.ink, 0.24) : Qt.alpha(root.ink, 0.12)
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            font.family: root.family; font.pixelSize: 13 * root.unit; font.weight: Font.Medium
            color: chip.confirming ? root.accent : root.ink
        }
        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.activated()
        }
    }

    // Session: cycles through installed sessions.
    Chip {
        anchors { left: parent.left; bottom: parent.bottom; margins: 24 * root.unit }
        visible: label !== ""
        label: root.session ? root.session.sName : ""
        onActivated: { root.sessionIndex = (root.sessionIndex + 1) % sessions.count; password.forceActiveFocus() }
    }

    // Power: a second press within 3.5 s confirms, as on the lock screen.
    Row {
        anchors { right: parent.right; bottom: parent.bottom; margins: 24 * root.unit }
        spacing: 8 * root.unit
        Chip {
            visible: sddm.canSuspend
            label: confirming ? qsTr("¿Suspender?") : qsTr("Suspender")
            confirming: root.pendingPower === "suspend"
            onActivated: root.power("suspend")
        }
        Chip {
            visible: sddm.canReboot
            label: confirming ? qsTr("¿Reiniciar?") : qsTr("Reiniciar")
            confirming: root.pendingPower === "reboot"
            onActivated: root.power("reboot")
        }
        Chip {
            visible: sddm.canPowerOff
            label: confirming ? qsTr("¿Apagar?") : qsTr("Apagar")
            confirming: root.pendingPower === "poweroff"
            onActivated: root.power("poweroff")
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
