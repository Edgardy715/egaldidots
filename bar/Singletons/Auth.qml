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
    readonly property bool registered: agent.isRegistered
    readonly property var flow: agent.flow
    readonly property string sudoSocketPath: Quickshell.env("XDG_RUNTIME_DIR")
        + "/isla-sudo-askpass.sock"
    readonly property bool sudoActive: sudoRequestId.length > 0
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

    function submit(value: string): void {
        if (!value || !agent.flow || !agent.isActive) return
        agent.flow.submit(value)
    }

    function cancel(): void {
        if (agent.flow && agent.isActive)
            agent.flow.cancelAuthenticationRequest()
    }

    function beginSudoRequest(prompt: string, socket: var): void {
        if (!socket) return
        let request
        try { request = JSON.parse(prompt) } catch (_) { socket.connected = false; return }
        if (root.sudoSocket && root.sudoSocket.connected && root.sudoSocket !== socket) {
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

    function submitSudo(value: string): void {
        if (!value || root.sudoResponseSent || !root.sudoSocket || !root.sudoSocket.connected) return
        root.sudoHasError = false
        root.sudoSocket.write(value + "\n")
        root.sudoSocket.flush()
        root.sudoResponseSent = true
    }

    function beginSudoRetry(): void {
        if (!root.sudoActive) return
        root.sudoHasError = false
        root.sudoHasSuccess = false
    }

    function cancelSudo(): void {
        if (root.sudoSocket && root.sudoSocket.connected) {
            root.sudoSocket.write("__ISLA_CANCEL__\n")
            root.sudoSocket.flush()
            root.sudoSocket.connected = false
        }
        root.sudoSocket = null
        root.sudoRequestId = ""
        root.sudoResponseSent = false
        root.sudoHasError = false
        root.sudoHasSuccess = false
    }

    function reportSudoResult(requestId: string, exitCode: int): bool {
        if (requestId !== root.sudoRequestId || !root.sudoTracked) return false
        root.sudoResponseSent = false
        root.sudoHasError = exitCode !== 0
        root.sudoHasSuccess = exitCode === 0
        sudoResultTimer.restart()
        return true
    }

    Timer {
        id: sudoResultTimer
        interval: 1100
        repeat: false
        onTriggered: root.cancelSudo()
    }

    IpcHandler {
        target: "sudoAuth"
        function result(exitCode: string): bool {
            return false // Compatibility with older terminal sessions.
        }
        function validated(requestId: string, exitCode: string): bool {
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
        active: true
        path: root.sudoSocketPath
        handler: Socket {
            id: client

            parser: SplitParser {
                splitMarker: "\n"
                onRead: message => root.beginSudoRequest(message, client)
            }

            onConnectedChanged: {
                if (!connected && root.sudoSocket === client) {
                    if (root.sudoResponseSent) {
                        if (!root.sudoTracked) sudoResultTimer.restart()
                    }
                    else root.cancelSudo()
                }
            }
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
            if (agent.flow) root.authenticationRequestStarted()
        }
        function onIsRegisteredChanged() {
            console.log("[Auth] Polkit agent registered:", agent.isRegistered)
        }
    }
}
