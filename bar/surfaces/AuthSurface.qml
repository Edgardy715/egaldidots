import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../"
import "../Singletons"
import "../components"

PillSurface {
    id: root

    mTop: Theme.marginNone
    mLeft: Theme.marginNone
    mRight: Theme.marginNone
    mBottom: Theme.marginNone

    readonly property var flow: Auth.flow
    readonly property bool sudoMode: Auth.sudoActive
    property bool editing: false
    readonly property bool hasError: !editing && (root.sudoMode ? Auth.sudoError
        : !!root.flow && root.flow.supplementaryIsError)
    readonly property bool successState: root.successVisible
        || (root.sudoMode && Auth.sudoSuccess)
    readonly property bool verifying: root.sudoMode ? Auth.sudoSubmitting
        : root.submitting && !root.successVisible
    readonly property color successColor: "#62dfa0"
    readonly property color errorColor: "#ff6e7d"
    readonly property color stateColor: root.hasError ? root.errorColor
        : root.successState ? root.successColor : Theme.accent
    readonly property string response: passwordInput.text
    property bool submitting: false
    property bool successVisible: false
    property real errorOffset: 0
    onHasErrorChanged: if (hasError) { errorShake.restart(); retryTimer.restart() }
    Timer {
        id: retryTimer
        interval: 900
        onTriggered: {
            if (root.sudoMode && !root.verifying && !Auth.sudoSuccess) {
                Auth.beginSudoRetry()
                root.focusInput()
            }
        }
    }
    SequentialAnimation {
        id: errorShake
        NumberAnimation { target: root; property: "errorOffset"; to: -5; duration: 55 }
        NumberAnimation { target: root; property: "errorOffset"; to: 4; duration: 70 }
        NumberAnimation { target: root; property: "errorOffset"; to: -2; duration: 65 }
        NumberAnimation { target: root; property: "errorOffset"; to: 0; duration: 80 }
    }

    focus: open
    activeFocusOnTab: true

    onActiveFocusChanged: console.log("[AuthSurface] activeFocus:", activeFocus,
        "focus:", focus, "open:", open)

    function focusInput(): void {
        passwordInput.forceActiveFocus()
    }

    function submitResponse(): void {
        if (root.verifying) return
        root.editing = false
        if (root.sudoMode) {
            if (root.response.length === 0) return
            const sudoValue = root.response
            passwordInput.clear()
            Auth.submitSudo(sudoValue)
            return
        }
        if (!root.flow || !root.flow.isResponseRequired || root.response.length === 0)
            return
        const value = root.response
        passwordInput.clear()
        root.submitting = true
        Auth.submit(value)
    }

    function cancel(): void {
        if (root.sudoMode) Auth.cancelSudo()
        else Auth.cancel()
        root.requestClose()
    }

    onOpenChanged: {
        passwordInput.clear()
        root.submitting = false
        root.successVisible = false
        if (open) focusTimer.restart()
    }

    Timer {
        id: focusTimer
        interval: Motion.morph + 40
        repeat: false
        onTriggered: {
            if (!root.open) return
            root.forceActiveFocus()
            passwordInput.forceActiveFocus()
        }
    }

    // Keep the native password input aligned with its placeholder.
    TextInput {
        id: passwordInput
        x: authSlot.x + 44 * root.s
        y: authSlot.y
        width: Math.max(1, authSlot.width - 92 * root.s)
        height: authSlot.height
        z: 10
        visible: root.open && !root.verifying && !root.successState
        opacity: root.hasError ? 0 : 1
        focus: root.open
        activeFocusOnTab: true
        echoMode: TextInput.Password
        selectByMouse: false
        color: Theme.foreground
        font.family: Theme.font
        font.pixelSize: 14 * root.s
        font.letterSpacing: 2 * root.s
        verticalAlignment: TextInput.AlignVCenter
        passwordCharacter: "•"
        passwordMaskDelay: 0
        clip: true
        readOnly: root.verifying
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText

        onTextEdited: {
            if (root.sudoMode) Auth.beginSudoRetry()
            root.editing = true
        }

        onAccepted: root.submitResponse()
        Keys.onEscapePressed: root.cancel()
    }
    Connections {
        target: Auth
        function onSudoRequestStarted() {
            passwordInput.clear()
            root.editing = false
            Qt.callLater(root.focusInput)
        }
    }
    Connections {
        target: root.flow
        function onAuthenticationFailed() {
            passwordInput.clear()
            root.editing = false
            root.submitting = false
            Qt.callLater(root.focusInput)
        }
        function onIsResponseRequiredChanged() {
            if (root.flow && root.flow.isResponseRequired) root.submitting = false
        }
    }
    onVerifyingChanged: if (!verifying && open) Qt.callLater(root.focusInput)
    Item {
        id: authSlot
        transform: Translate { x: root.errorOffset }
        anchors.right: parent.right
        anchors.rightMargin: 12 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width, 350 * root.s)
        height: parent.height


        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: -12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.borderHairline
            height: Math.min(parent.height - 24 * root.s, 28 * root.s)
            radius: width / 2
            color: Qt.alpha(Theme.foreground, Theme.alphaHair)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8 * root.s
            anchors.rightMargin: 0
            spacing: 14 * root.s

            MaterialIcon {
                Layout.preferredWidth: 22 * root.s
                Layout.preferredHeight: 22 * root.s
                iconName: root.hasError ? "close" : root.successState ? "check" : "lock"
                fill: root.hasError || root.successState ? 1 : 0
                color: root.hasError || root.successState ? root.stateColor : Theme.foreground
                font.pixelSize: 22 * root.s
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Accessible.ignored: true
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true



                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.verifying && !root.hasError && !root.successState
                        && root.response.length === 0
                    text: qsTr("Ingresa tu contraseña…")
                    color: Theme.iconSecondary
                    font.family: Theme.font
                    font.pixelSize: 14 * root.s
                    elide: Text.ElideRight
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.verifying || root.successState || root.hasError
                    text: root.hasError
                        ? (root.flow && root.flow.supplementaryMessage.length > 0
                            ? root.flow.supplementaryMessage : qsTr("Contraseña incorrecta"))
                        : root.successState ? qsTr("Acceso concedido") : qsTr("Verificando…")
                    color: root.stateColor
                    font.family: Theme.font
                    font.pixelSize: 14 * root.s
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
            }

            Item {
                Layout.preferredWidth: 38 * root.s
                Layout.preferredHeight: 38 * root.s
                visible: !root.verifying && !root.hasError && !root.successState
                scale: submitMouse.pressed ? 0.94 : 1
                Behavior on scale { Anim { type: Anim.FastEffects } }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.response.length > 0
                        ? Qt.alpha(Theme.accent, Theme.alphaStrong)
                        : Qt.alpha(Theme.foreground, Theme.alphaSoft)
                    border.width: root.response.length > 0 ? 1 : 0
                    border.color: root.response.length > 0
                        ? Qt.alpha(Theme.accent, Theme.alphaStrong) : Theme.border
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: "arrow_forward"
                    color: root.response.length > 0 ? Theme.foreground : Theme.iconSecondary
                    font.pixelSize: 20 * root.s
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Accessible.ignored: true
                }

                MouseArea {
                    id: submitMouse
                    anchors.fill: parent
                    enabled: root.response.length > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.submitResponse()
                }
            }

            Item {
                Layout.preferredWidth: 38 * root.s
                Layout.preferredHeight: 38 * root.s
                visible: root.verifying

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: Theme.accent
                        strokeWidth: 2.5 * root.s
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 19 * root.s
                            centerY: 19 * root.s
                            radiusX: 15 * root.s
                            radiusY: 15 * root.s
                            startAngle: -90
                            sweepAngle: 285
                            moveToStart: true
                        }
                    }

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: root.verifying && root.visible
                    }
                }
            }

            Item {
                Layout.preferredWidth: 38 * root.s
                Layout.preferredHeight: 38 * root.s
                visible: root.hasError || root.successState
                scale: visible ? 1 : 0.75
                opacity: visible ? 1 : 0
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.alpha(root.stateColor, Theme.alphaGlow)
                    border.width: Theme.borderHairline
                    border.color: Qt.alpha(root.stateColor, Theme.alphaStrong)
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: root.hasError ? "close" : "check"
                    fill: 1
                    color: root.stateColor
                    font.pixelSize: 21 * root.s
                    Accessible.ignored: true
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            enabled: root.open
            acceptedButtons: Qt.LeftButton
            onClicked: root.forceActiveFocus()
        }
    }
}
