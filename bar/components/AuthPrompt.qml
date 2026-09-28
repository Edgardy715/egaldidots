import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../"
import "../Singletons"

// Presentation only: the injected backend owns authorization and request lifetime.
PillSurface {
    id: root
    required property var backend
    property bool capsLockOn: false
    property real contextWidth: 170 * s
    readonly property real fieldHeight: Math.max(44, Theme.fontSizeBodyLg + Flags.fontScale + 20) * s
    readonly property real detailHeight: Math.max(18, Theme.fontSizeLabel + 6) * s
    property bool editing: false
    property bool sendRejected: false
    property real errorOffset: 0
    readonly property var flow: backend.flow
    readonly property bool sudoMode: backend.sudoActive && !backend.active && !backend.polkitSuccess
    readonly property bool successState: sudoMode ? backend.sudoSuccess : backend.polkitSuccess
    readonly property bool hasError: !editing && !successState && !verifying && (sudoMode ? backend.sudoError : backend.polkitError)
    readonly property bool verifying: !successState && (sudoMode ? backend.sudoSubmitting
        : backend.polkitSubmitting || (backend.active && flow && !flow.isResponseRequired && !flow.isCompleted))
    readonly property bool canRespond: root.active && !verifying && !successState && (sudoMode
        ? backend.sudoCanRespond : backend.active && !!flow && flow.isResponseRequired && !flow.isCompleted)
    readonly property bool responseVisible: !sudoMode && !!flow && flow.responseVisible
    readonly property string response: password.text
    readonly property var identities: !sudoMode && flow ? flow.identities : []
    readonly property string prompt: sudoMode && backend.sudoPrompt ? backend.sudoPrompt : !sudoMode && flow && flow.inputPrompt ? flow.inputPrompt
        : qsTr("Contraseña")
    readonly property string requestMessage: sudoMode ? qsTr("Autorización de sudo")
        : flow && flow.message ? flow.message : qsTr("Autorización del sistema")
    readonly property string detail: successState ? qsTr("Acceso concedido")
        : sendRejected ? qsTr("No se pudo enviar la respuesta. Revisa el campo.")
        : hasError ? (sudoMode ? (backend.sudoCanRespond ? qsTr("Contraseña incorrecta. Inténtalo de nuevo.") : qsTr("No se pudo autorizar"))
            : backend.polkitMessage || qsTr("No se pudo autenticar. Inténtalo de nuevo."))
        : verifying ? qsTr("Verificando…")
        : capsLockOn && !responseVisible ? qsTr("Bloq Mayús activado")
        : !sudoMode && flow && flow.supplementaryMessage && !flow.supplementaryIsError
            ? flow.supplementaryMessage : requestMessage
    readonly property bool lightMaterial: Theme.background.r * 0.2126 + Theme.background.g * 0.7152 + Theme.background.b * 0.0722 > 0.5
    readonly property color stateColor: hasError ? (lightMaterial ? "#b83249" : "#ff8896")
        : successState ? (lightMaterial ? "#1b7852" : "#8ce5b6") : Theme.foreground
    readonly property real exposure: Math.max(0, Math.min(1,
        (morphCloseness - 0.72) / 0.28,
        (width - contextWidth - 376 * s) / (24 * s)))
    readonly property bool fieldFocused: password.activeFocus
    readonly property int identityIndex: selectedIdentityIndex()

    function selectedIdentityIndex() {
        for (let i = 0; i < identities.length; i++) if (flow && identities[i] === flow.selectedIdentity) return i
        return 0
    }
    function resetInput() {
        password.clear()
        editing = false
        sendRejected = false
        rejection.stop()
        errorOffset = 0
        accounts.popup.close()
    }
    function focusInput() {
        if (canRespond && visible) password.forceActiveFocus(Qt.OtherFocusReason)
    }
    function submitResponse() {
        if (!canRespond || !response.length || password.inputMethodComposing) return
        const secret = response
        password.clear()
        const accepted = sudoMode ? backend.submitSudo(secret) : backend.submit(secret)
        if (!accepted) {
            sendRejected = true
            if (canRespond) password.text = secret
            Qt.callLater(root.focusInput)
            return
        }
        sendRejected = false
        editing = false
    }
    function cancel() {
        resetInput()
        if (sudoMode) backend.cancelSudo()
        else backend.cancel()
        requestClose()
    }
    function reject() {
        password.clear()
        if (root.active && root.visible && !Flags.reduceMotion) rejection.restart()
        Qt.callLater(root.focusInput)
    }
    function selectIdentity(index) {
        if (!canRespond || !flow || index < 0 || index >= identities.length) return
        resetInput()
        flow.selectedIdentity = identities[index]
        Qt.callLater(root.focusInput)
    }
    onActiveChanged: {
        resetInput()
        if (active) Qt.callLater(root.focusInput)
    }
    onVisibleChanged: {
        if (visible) Qt.callLater(root.focusInput)
        else { password.clear(); rejection.stop(); errorOffset = 0; fieldColor.complete(); fieldBorder.complete() }
    }
    onFlowChanged: { resetInput(); Qt.callLater(root.focusInput) }
    onSudoModeChanged: { resetInput(); Qt.callLater(root.focusInput) }
    onCanRespondChanged: if (canRespond) Qt.callLater(root.focusInput)
    onHasErrorChanged: if (hasError) reject()
    onSuccessStateChanged: if (successState) resetInput()
    Component.onCompleted: Qt.callLater(root.focusInput)
    Component.onDestruction: password.clear()
    Keys.onEscapePressed: event => { event.accepted = true; root.cancel() }
    Connections {
        target: root.backend
        function onAuthenticationRequestStarted() { root.resetInput(); Qt.callLater(root.focusInput) }
        function onSudoRequestStarted() { root.resetInput(); if (root.hasError) root.reject(); else Qt.callLater(root.focusInput) }
    }
    Connections {
        target: root.flow
        function onAuthenticationFailed() { root.editing = false; if (!root.hasError) root.reject() }
        function onSelectedIdentityChanged() { root.resetInput(); Qt.callLater(root.focusInput) }
        function onIsResponseRequiredChanged() { password.clear(); Qt.callLater(root.focusInput) }
    }
    Connections {
        target: Flags
        function onReduceMotionChanged() { if (Flags.reduceMotion) { rejection.stop(); root.errorOffset = 0 } }
    }
    SequentialAnimation {
        id: rejection
        NumberAnimation { target: root; property: "errorOffset"; to: -4 * root.s; duration: Motion.press; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "errorOffset"; to: 3 * root.s; duration: Motion.press; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "errorOffset"; to: 0; duration: Motion.fast; easing.type: Easing.OutCubic }
    }
    Item {
        id: slot
        anchors.right: parent.right
        anchors.rightMargin: 12 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width, 400 * root.s)
        height: root.fieldHeight + 3 * root.s + root.detailHeight
        opacity: root.exposure
        transform: Translate { y: Flags.reduceMotion ? 0 : (1 - root.exposure) * 3 * root.s }
        Rectangle {
            x: -12 * root.s; y: 8 * root.s
            width: Theme.borderHairline; height: parent.height - 16 * root.s
            color: Qt.alpha(Theme.foreground, Theme.alphaHair)
        }
        Item {
            id: field
            width: Math.max(1, parent.width - 36 * root.s); height: root.fieldHeight
            transform: Translate { x: root.errorOffset }
            Rectangle {
                anchors.fill: parent; radius: 16 * root.s
                color: Qt.alpha(root.stateColor, root.hasError ? 0.07 : 0.035)
                border.width: Theme.borderHairline
                border.color: Qt.alpha(root.stateColor, root.hasError || root.successState ? 0.35 : password.activeFocus ? 0.19 : 0.07)
                Behavior on color { enabled: root.active && root.visible && root.exposure > 0; ColorAnimation { id: fieldColor; duration: Motion.fast } }
                Behavior on border.color { enabled: root.active && root.visible && root.exposure > 0; ColorAnimation { id: fieldBorder; duration: Motion.fast } }
            }
            MaterialIcon {
                x: 12 * root.s; anchors.verticalCenter: parent.verticalCenter
                iconName: root.successState ? "lock_open" : "lock"
                font.pixelSize: 19 * root.s; color: root.stateColor
                Accessible.ignored: true
            }
            TextField {
                id: password
                objectName: "authPassword"
                x: 40 * root.s; width: Math.max(1, parent.width - 92 * root.s); height: parent.height
                leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
                echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
                passwordCharacter: "•"; passwordMaskDelay: 0
                placeholderText: root.successState ? qsTr("Autorizado") : root.verifying ? qsTr("Verificando…") : root.prompt
                placeholderTextColor: root.successState ? root.stateColor : Theme.iconSecondary
                color: Theme.foreground; font.family: Theme.font; font.pixelSize: (Theme.fontSizeBodyLg + Flags.fontScale) * root.s
                selectByMouse: true
                readOnly: !root.canRespond
                activeFocusOnTab: true
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | (root.responseVisible ? Qt.ImhNone : Qt.ImhHiddenText)
                Accessible.name: root.prompt
                Accessible.description: root.detail
                background: Item {}
                onTextEdited: {
                    root.editing = true
                    root.sendRejected = false
                    if (root.sudoMode) root.backend.beginSudoRetry()
                }
                onAccepted: root.submitResponse()
                Keys.onEscapePressed: event => { event.accepted = true; root.cancel() }
                KeyNavigation.tab: submit.enabled ? submit : accounts.visible && accounts.enabled ? accounts : dismiss
                KeyNavigation.backtab: dismiss
            }
            MotionButton {
                id: submit
                objectName: "authSubmit"
                x: parent.width - width - 5 * root.s; y: (parent.height - height) / 2
                width: 34 * root.s; height: width
                enabled: root.canRespond && root.response.length > 0
                Accessible.name: qsTr("Autorizar")
                background: Rectangle {
                    radius: 12 * root.s
                    color: root.successState ? Qt.alpha(root.stateColor, 0.13) : submit.enabled ? Qt.alpha(Theme.foreground, 0.14 + 0.06 * submit.interaction.presence) : "transparent"
                }
                contentItem: Item {
                    MaterialIcon {
                        anchors.centerIn: parent
                        interaction: submit.interaction
                        iconName: root.successState ? "check" : root.verifying ? "hourglass_top" : "arrow_forward"
                        visible: !root.verifying || Flags.reduceMotion
                        font.pixelSize: 20 * root.s
                        color: root.successState ? root.stateColor : Theme.foreground
                        opacity: submit.enabled || root.verifying || root.successState ? 1 : 0.4
                    }
                    BusyIndicator {
                        anchors.centerIn: parent
                        width: 24 * root.s; height: width; padding: 0
                        palette.dark: Theme.foreground
                        visible: root.verifying && !Flags.reduceMotion
                        running: visible && root.visible && root.exposure > 0 && (!Window.window || Window.window.visible)
                    }
                }
                onClicked: root.submitResponse()
                KeyNavigation.tab: accounts.visible && accounts.enabled ? accounts : dismiss
                KeyNavigation.backtab: password
            }
        }
        MotionButton {
            id: dismiss
            objectName: "authCancel"
            x: parent.width - width; y: (root.fieldHeight - height) / 2
            width: 30 * root.s; height: width
            enabled: root.active
            Accessible.name: qsTr("Cancelar autorización")
            background: Rectangle { radius: 12 * root.s; color: Qt.alpha(Theme.foreground, dismiss.hovered ? 0.09 : 0) }
            contentItem: MaterialIcon { iconName: "close"; interaction: dismiss.interaction; color: Theme.iconSecondary; font.pixelSize: 17 * root.s }
            onClicked: root.cancel()
            KeyNavigation.tab: password
            KeyNavigation.backtab: accounts.visible && accounts.enabled ? accounts : submit.enabled ? submit : password
        }
        RowLayout {
            x: 12 * root.s; y: root.fieldHeight + 3 * root.s
            width: parent.width - x; height: root.detailHeight
            spacing: 8 * root.s
            ComboBox {
                id: accounts
                objectName: "authAccounts"
                Layout.maximumWidth: 120 * root.s; Layout.preferredHeight: root.detailHeight
                visible: root.identities.length > 1 && !root.successState
                enabled: root.canRespond
                font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s
                palette.window: Theme.cardTop
                palette.base: Theme.background
                palette.text: Theme.foreground
                palette.buttonText: Theme.foreground
                palette.highlight: Qt.alpha(Theme.foreground, 0.14)
                palette.highlightedText: Theme.foreground
                model: root.identities; textRole: "displayName"; currentIndex: root.identityIndex
                Accessible.name: qsTr("Cuenta para autorizar")
                contentItem: Text { text: accounts.displayText; color: Theme.foreground; font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * root.s; elide: Text.ElideRight; rightPadding: 15 * root.s }
                background: Item {}
                indicator: MaterialIcon { x: accounts.width - width; anchors.verticalCenter: parent.verticalCenter; iconName: "expand_more"; font.pixelSize: 13 * root.s; color: Theme.iconSecondary }
                KeyNavigation.tab: dismiss
                KeyNavigation.backtab: submit.enabled ? submit : password
                onActivated: index => root.selectIdentity(index)
            }
            Text {
                Layout.fillWidth: true
                text: root.detail; elide: Text.ElideRight
                color: root.hasError || root.successState ? root.stateColor : root.capsLockOn ? Theme.foreground : Theme.iconSecondary
                font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * root.s
                textFormat: Text.PlainText
                Accessible.name: root.detail
                ToolTip.visible: detailHover.hovered
                ToolTip.text: root.detail
                HoverHandler { id: detailHover }
            }
        }
    }
}
