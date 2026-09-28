pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit

Singleton {
    id: root

    Component.onCompleted: console.log("[Auth] Polkit agent registered:", agent.isRegistered)

    readonly property bool active: agent.isActive
    readonly property bool presenting: active || sudoActive || polkitSuccess
    property int polkitFeedbackDuration: 750
    property int sudoFeedbackDuration: 1100
    property bool polkitSubmitting: false
    property bool polkitSuccess: false
    property bool polkitError: false
    property string polkitMessage: ""
    readonly property bool registered: agent.isRegistered
    readonly property var flow: agent.flow
    readonly property string sudoSocketPath: Quickshell.env("XDG_RUNTIME_DIR")
        + "/isla-sudo-askpass.sock"
    readonly property bool sudoActive: sudoRequestId.length > 0
    readonly property bool sudoCanRespond: sudoActive && sudoSocket !== null
        && sudoSocket.connected && !sudoResponseSent && !sudoHasSuccess
    readonly property bool sudoSubmitting: sudoResponseSent
    readonly property bool sudoError: sudoHasError
    readonly property bool sudoSuccess: sudoHasSuccess

    signal authenticationRequestStarted()
    signal sudoRequestStarted()

    property var sudoSocket: null
    property string sudoRequestId: ""
    property bool sudoTracked: false
    property string sudoPrompt: "Password:"
    property bool sudoResponseSent: false
    property bool sudoHasError: false
    property bool sudoHasSuccess: false

    function submit(value: string): bool {
        if (!value || !agent.flow || !agent.isActive || !agent.flow.isResponseRequired
                || root.polkitSubmitting || root.polkitSuccess) return false
        root.polkitError = false
        root.polkitMessage = ""
        root.polkitSubmitting = true
        agent.flow.submit(value)
        return true
    }

    function cancel(): void {
        polkitResultTimer.stop()
        root.polkitSubmitting = false
        root.polkitSuccess = false
        root.polkitError = false
        root.polkitMessage = ""
        if (agent.flow && agent.isActive)
            agent.flow.cancelAuthenticationRequest()
    }

    function beginSudoRequest(prompt: string, socket: var): void {
        if (!socket) return
        let request
        try { request = JSON.parse(prompt) } catch (_) { socket.connected = false; return }
        if (!request || typeof request !== "object" || Array.isArray(request)
                || typeof request.id !== "string" || request.id.length === 0
                || request.id.length > 128 || /[\r\n]/.test(request.id)
                || typeof request.prompt !== "string" || request.prompt.length > 4096
                || typeof request.tracked !== "boolean") {
            socket.connected = false
            return
        }
        if (root.sudoSocket === socket) return
        if (root.sudoSocket && root.sudoSocket.connected) {
            socket.connected = false
            return
        }
        sudoResultTimer.stop()
        root.sudoHasError = root.sudoRequestId === request.id && root.sudoResponseSent
        root.sudoRequestId = request.id
        root.sudoTracked = request.tracked === true
        root.sudoSocket = socket
        root.sudoPrompt = request.prompt
        root.sudoHasSuccess = false
        root.sudoResponseSent = false
        console.log("[Auth] sudo askpass request received")
        root.sudoRequestStarted()
    }

    function submitSudo(value: string): bool {
        if (!value || /[\r\n]/.test(value) || value === "__ISLA_CANCEL__"
                || root.sudoResponseSent || root.sudoHasSuccess
                || !root.sudoSocket || !root.sudoSocket.connected) return false
        root.sudoHasError = false
        root.sudoResponseSent = true
        root.sudoSocket.write(value + "\n")
        root.sudoSocket.flush()
        return true
    }

    function beginSudoRetry(): void {
        if (!root.sudoActive || root.sudoResponseSent || !root.sudoSocket
                || !root.sudoSocket.connected || root.sudoHasSuccess) return
        root.sudoHasError = false
        root.sudoHasSuccess = false
    }

    function cancelSudo(): void {
        sudoResultTimer.stop()
        const socket = root.sudoSocket
        root.sudoSocket = null
        root.sudoRequestId = ""
        root.sudoTracked = false
        root.sudoResponseSent = false
        root.sudoHasError = false
        root.sudoHasSuccess = false
        if (socket && socket.connected) {
            socket.write("__ISLA_CANCEL__\n")
            socket.flush()
            socket.connected = false
        }
    }

    function disconnectSudo(socket: var): void {
        if (root.sudoSocket !== socket) return
        root.sudoSocket = null
        if ((root.sudoHasSuccess || root.sudoHasError) && sudoResultTimer.running) return
        if (root.sudoResponseSent) {
            sudoResultTimer.interval = root.sudoTracked ? 120000 : root.sudoFeedbackDuration
            sudoResultTimer.restart()
        } else root.cancelSudo()
    }

    function reportSudoResult(requestId: string, exitCode: real): bool {
        if (!requestId || requestId !== root.sudoRequestId || !root.sudoTracked
                || !root.sudoResponseSent || !Number.isInteger(exitCode)
                || exitCode < 0 || exitCode > 255) return false
        root.sudoResponseSent = false
        root.sudoHasError = exitCode !== 0
        root.sudoHasSuccess = exitCode === 0
        sudoResultTimer.interval = root.sudoFeedbackDuration
        sudoResultTimer.restart()
        return true
    }

    Timer {
        id: sudoResultTimer
        interval: root.sudoFeedbackDuration
        repeat: false
        onTriggered: root.cancelSudo()
    }

    IpcHandler {
        target: "sudoAuth"
        function result(exitCode: string): bool {
            return false // Compatibility with older terminal sessions.
        }
        function validated(requestId: string, exitCode: string): bool {
            if (!/^(0|[1-9][0-9]{0,2})$/.test(exitCode)) return false
            return root.reportSudoResult(requestId, Number(exitCode))
        }
    }

    IpcHandler {
        target: "authDebug"
        function status(): string {
            return "registered=" + agent.isRegistered
                + " active=" + agent.isActive
                + " flow=" + (agent.flow !== null)
                + " sudo=" + root.sudoActive
                + " error=" + root.sudoError
                + " success=" + root.sudoSuccess
        }
    }

    SocketServer {
        // Give the listener a stable identity for resource handoff on reload.
        reloadableId: "islaSudoAskpass"
        active: true
        path: root.sudoSocketPath
        handler: Socket {
            id: client

            parser: SplitParser {
                splitMarker: "\n"
                onRead: message => root.beginSudoRequest(message, client)
            }

            onConnectedChanged: if (!connected) root.disconnectSudo(client)
        }
    }

    Timer {
        id: polkitResultTimer
        interval: root.polkitFeedbackDuration
        onTriggered: root.polkitSuccess = false
    }

    Connections {
        target: agent.flow
        function onAuthenticationSucceeded() {
            root.polkitSubmitting = false
            root.polkitError = false
            root.polkitSuccess = true
            polkitResultTimer.restart()
        }
        function onAuthenticationFailed() {
            root.polkitSubmitting = false
            root.polkitError = true
        }
        function onAuthenticationRequestCancelled() {
            root.polkitSubmitting = false
            root.polkitSuccess = false
        }
        function onSelectedIdentityChanged() {
            root.polkitSubmitting = false
            root.polkitError = false
            root.polkitMessage = ""
        }
        function onIsResponseRequiredChanged() {
            if (agent.flow && agent.flow.isResponseRequired)
                root.polkitSubmitting = false
        }
        function onSupplementaryMessageChanged() {
            if (agent.flow) root.polkitMessage = agent.flow.supplementaryMessage
        }
        function onSupplementaryIsErrorChanged() {
            if (agent.flow) root.polkitError = agent.flow.supplementaryIsError
        }
    }

    PolkitAgent {
        id: agent
        path: "/org/quickshell/IslaPolkitAgent"
    }

    Connections {
        target: agent
        function onAuthenticationRequestStarted() {
            root.authenticationRequestStarted()
        }
        function onFlowChanged() {
            if (!agent.flow) {
                root.polkitSubmitting = false
                return
            }
            polkitResultTimer.stop()
            root.polkitSubmitting = false
            root.polkitSuccess = false
            root.polkitError = false
            root.polkitMessage = ""
            root.authenticationRequestStarted()
        }
        function onIsRegisteredChanged() {
            console.log("[Auth] Polkit agent registered:", agent.isRegistered)
        }
    }
}
