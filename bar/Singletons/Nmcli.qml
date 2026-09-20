pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Isla · Nmcli. Servicio de red WiFi inspirado en caelestia/services/Nmcli.qml
 * (QML puro, cero C++): envuelve `nmcli` via Quickshell.Io.Process para listar,
 * escanear, conectar/desconectar y olvidar redes. Un `nmcli monitor` mantiene el
 * estado fresco en tiempo real.
 *
 * API (Singleton):
 *   property list<AccessPoint> networks   — redes escaneadas
 *   readonly property AccessPoint active   — red activa o null
 *   property bool wifiEnabled             — toggle de radio
 *   readonly property bool scanning
 *   function rescanWifi() / getNetworks()
 *   function connectToNetwork(ssid, password, bssid, callback)
 *   function disconnectFromNetwork()
 *   function forgetNetwork(ssid)
 *   function hasSavedProfile(ssid)
 *   signal connectionFailed(ssid)
 */
Singleton {
    id: root

    property bool wifiEnabled: true
    readonly property bool scanning: rescanProc.running
    readonly property list<AccessPoint> networks: []
    readonly property AccessPoint active: networks.find(n => n.active) ?? null
    property list<string> savedConnectionSsids: []

    property var wifiConnectionQueue: []
    property int currentSsidQueryIndex: 0
    property var pendingConnection: null
    property list<var> activeProcesses: []

    readonly property alias connectionCheckTimer: connectionCheckTimer
    readonly property alias immediateCheckTimer: immediateCheckTimer

    signal connectionFailed(string ssid)

    // ── Detección de password en stderr ──────────────────────────────────────
    function detectPasswordRequired(error: string): bool {
        if (!error || error.length === 0) return false
        return (error.includes("Secrets were required")
             || error.includes("Secrets were required, but not provided")
             || error.includes("No secrets provided")
             || error.includes("802-11-wireless-security.psk")
             || error.includes("password for")
             || (error.includes("password") && !error.includes("Connection activated") && !error.includes("successfully"))
             || (error.includes("Secrets") && !error.includes("Connection activated") && !error.includes("successfully"))
             || (error.includes("802.11") && !error.includes("Connection activated") && !error.includes("successfully")))
            && !error.includes("Connection activated") && !error.includes("successfully")
    }

    function isConnectionCommand(command: list<string>): bool {
        if (!command || command.length === 0) return false
        return command.includes("wifi") || command.includes("connection")
    }

    // ── Parsing de output ────────────────────────────────────────────────────
    function parseNetworkOutput(output: string): list<var> {
        if (!output || output.length === 0) return []

        const PLACEHOLDER = "STRINGWHICHHOPEFULLYWONTBEUSED"
        const rep = new RegExp("\\\\:", "g")
        const rep2 = new RegExp(PLACEHOLDER, "g")

        const allNetworks = output.trim().split("\n").filter(line => line && line.length > 0).map(n => {
            const net = n.replace(rep, PLACEHOLDER).split(":")
            return {
                active: net[0] === "yes",
                strength: parseInt(net[1] || "0", 10) || 0,
                frequency: parseInt(net[2] || "0", 10) || 0,
                ssid: (net[3]?.replace(rep2, ":") ?? "").trim(),
                bssid: (net[4]?.replace(rep2, ":") ?? "").trim(),
                security: (net[5] ?? "").trim()
            }
        }).filter(n => n.ssid && n.ssid.length > 0)

        return allNetworks
    }

    function deduplicateNetworks(networks: list<var>): list<var> {
        if (!networks || networks.length === 0) return []

        const networkMap = new Map()
        for (const network of networks) {
            const existing = networkMap.get(network.ssid)
            if (!existing) {
                networkMap.set(network.ssid, network)
            } else {
                if (network.active && !existing.active) {
                    networkMap.set(network.ssid, network)
                } else if (!network.active && !existing.active) {
                    if (network.strength > existing.strength) {
                        networkMap.set(network.ssid, network)
                    }
                }
            }
        }
        return Array.from(networkMap.values())
    }

    // ── Ejecución de comandos ────────────────────────────────────────────────
    function executeCommand(args: list<string>, callback: var): void {
        const proc = commandProc.createObject(root)
        proc.cmdArgs = ["nmcli", ...args]
        proc.callback = callback

        activeProcesses.push(proc)

        proc.processFinished.connect(() => {
            const index = activeProcesses.indexOf(proc)
            if (index >= 0) activeProcesses.splice(index, 1)
        })

        Qt.callLater(() => { proc.exec(proc.cmdArgs) })
    }

    // ── Redes ────────────────────────────────────────────────────────────────
    function getNetworks(callback: var): void {
        executeCommand(["-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "d", "w"], result => {
            if (!result.success) { if (callback) callback([]); return }

            const allNetworks = parseNetworkOutput(result.output)
            const networks = deduplicateNetworks(allNetworks)
            const rNetworks = root.networks

            const newMap = new Map()
            for (const n of networks)
                newMap.set(`${n.frequency}:${n.ssid}:${n.bssid}`, n)

            for (let i = rNetworks.length - 1; i >= 0; i--) {
                const rn = rNetworks[i]
                const key = `${rn.frequency}:${rn.ssid}:${rn.bssid}`
                if (!newMap.has(key)) {
                    rNetworks.splice(i, 1)
                    rn.destroy()
                }
            }

            const existingMap = new Map()
            for (const rn of rNetworks)
                existingMap.set(`${rn.frequency}:${rn.ssid}:${rn.bssid}`, rn)

            for (const [key, network] of newMap) {
                const match = existingMap.get(key)
                if (match) match.lastIpcObject = network
                else rNetworks.push(apComp.createObject(root, { lastIpcObject: network }))
            }

            if (callback) callback(root.networks)
            checkPendingConnection()
        })
    }

    function rescanWifi(): void {
        rescanProc.running = true
    }

    // ── Radio toggle ─────────────────────────────────────────────────────────
    function enableWifi(enabled: bool, callback: var): void {
        const cmd = enabled ? "on" : "off"
        executeCommand(["radio", "wifi", cmd], result => {
            if (result.success) {
                getWifiStatus(status => { root.wifiEnabled = status })
            }
            if (callback) callback(result)
        })
    }

    function toggleWifi(callback: var): void {
        enableWifi(!root.wifiEnabled, callback)
    }

    function getWifiStatus(callback: var): void {
        executeCommand(["radio", "wifi"], result => {
            if (result.success) {
                root.wifiEnabled = result.output.trim() === "enabled"
                if (callback) callback(root.wifiEnabled)
            } else {
                if (callback) callback(root.wifiEnabled)
            }
        })
    }

    // ── Conectar / desconectar ───────────────────────────────────────────────
    function connectToNetwork(ssid: string, password: string, bssid: string, callback: var, retryCount: int): void {
        const hasBssid = bssid !== undefined && bssid !== null && bssid.length > 0
        const retries = retryCount !== undefined ? retryCount : 0
        const maxRetries = 2

        // Con contraseña explícita: resultado directo (sin monitoreo de pendingConnection)
        if (password && password.length > 0 && hasBssid) {
            root.pendingConnection = null
            connectionCheckTimer.stop()
            immediateCheckTimer.stop()
            immediateCheckTimer.checkCount = 0
            createConnectionWithPassword(ssid, bssid.toUpperCase(), password, callback)
            return
        }

        if (callback) {
            root.pendingConnection = {
                ssid: ssid,
                bssid: hasBssid ? bssid : "",
                callback: callback,
                retryCount: retries
            }
            connectionCheckTimer.start()
            immediateCheckTimer.checkCount = 0
            immediateCheckTimer.start()
        }

        let cmd = ["device", "wifi", "connect", ssid]
        if (password && password.length > 0) cmd.push("password", password)

        executeCommand(cmd, result => {
            if (result.needsPassword && callback) { if (callback) callback(result); return }
            if (!result.success && root.pendingConnection && retries < maxRetries) {
                Qt.callLater(() => {
                    connectToNetwork(ssid, password, bssid, callback, retries + 1)
                }, 1000)
            }
        })
    }

    function connectToNetworkWithPasswordCheck(ssid: string, isSecure: bool, callback: var, bssid: string): void {
        if (isSecure) {
            const hasBssid = bssid !== undefined && bssid !== null && bssid.length > 0
            connectWireless(ssid, "", bssid, result => {
                if (result.success) {
                    if (callback) callback({ success: true, usedSavedPassword: true, output: result.output, error: "", exitCode: 0 })
                } else if (result.needsPassword) {
                    if (callback) callback({ success: false, needsPassword: true, output: result.output, error: result.error, exitCode: result.exitCode })
                } else {
                    if (callback) callback(result)
                }
            })
        } else {
            connectWireless(ssid, "", bssid, callback)
        }
    }

    function connectWireless(ssid: string, password: string, bssid: string, callback: var): void {
        const hasBssid = bssid !== undefined && bssid !== null && bssid.length > 0

        if (callback) {
            root.pendingConnection = { ssid: ssid, bssid: hasBssid ? bssid : "", callback: callback, retryCount: 0 }
            connectionCheckTimer.start()
            immediateCheckTimer.checkCount = 0
            immediateCheckTimer.start()
        }

        let cmd = ["device", "wifi", "connect", ssid]
        if (password && password.length > 0) cmd.push("password", password)

        executeCommand(cmd, result => {
            if (result.needsPassword && callback) { if (callback) callback(result); return }
            if (!result.success && root.pendingConnection) { /* los timers gestionan el estado */ }
        })
    }

    function createConnectionWithPassword(ssid: string, bssidUpper: string, password: string, callback: var): void {
        checkAndDeleteConnection(ssid, () => {
            const cmd = ["connection", "add", "type", "wifi", "con-name", ssid, "ifname", "*",
                         "ssid", ssid, "802-11-wireless.bssid", bssidUpper,
                         "802-11-wireless-security.key-mgmt", "wpa-psk",
                         "802-11-wireless-security.psk", password]
            executeCommand(cmd, result => {
                if (result.success) {
                    loadSavedConnections(() => {})
                    activateConnection(ssid, callback)
                } else {
                    const dup = result.error && (result.error.includes("another connection with the name") || result.error.includes("Reference the connection by its uuid"))
                    if (dup || (result.exitCode > 0 && result.exitCode < 10)) {
                        loadSavedConnections(() => {})
                        activateConnection(ssid, callback)
                    } else {
                        const fallbackCmd = ["device", "wifi", "connect", ssid, "password", password]
                        executeCommand(fallbackCmd, fallbackResult => {
                            if (callback) callback(fallbackResult)
                        })
                    }
                }
            })
        })
    }

    function checkAndDeleteConnection(ssid: string, callback: var): void {
        executeCommand(["connection", "show", ssid], result => {
            if (result.success) {
                executeCommand(["connection", "delete", ssid], deleteResult => {
                    Qt.callLater(() => { if (callback) callback() }, 300)
                })
            } else {
                if (callback) callback()
            }
        })
    }

    function activateConnection(connectionName: string, callback: var): void {
        executeCommand(["connection", "up", connectionName], result => {
            if (callback) callback(result)
        })
    }

    function disconnectFromNetwork(): void {
        if (active && active.ssid) {
            executeCommand(["connection", "down", active.ssid], result => {
                if (result.success) getNetworks(() => {})
            })
        } else {
            executeCommand(["device", "disconnect", "wifi"], result => {
                if (result.success) getNetworks(() => {})
            })
        }
    }

    function disconnect(interfaceName: string, callback: var): void {
        executeCommand(["device", "disconnect", interfaceName || "wifi"], result => {
            if (callback) callback(result.success ? result.output : "")
        })
    }

    function forgetNetwork(ssid: string, callback: var): void {
        if (!ssid || ssid.length === 0) {
            if (callback) callback({ success: false, output: "", error: "No SSID specified", exitCode: -1 })
            return
        }
        const connectionName = savedConnectionSsids.find(conn => conn && conn.toLowerCase().trim() === ssid.toLowerCase().trim()) || ssid
        executeCommand(["connection", "delete", connectionName], result => {
            if (result.success) {
                Qt.callLater(() => { loadSavedConnections(() => {}) }, 500)
            }
            if (callback) callback(result)
        })
    }

    // ── Conexiones guardadas ─────────────────────────────────────────────────
    function loadSavedConnections(callback: var): void {
        executeCommand(["-t", "-f", "NAME,TYPE", "connection", "show"], result => {
            if (!result.success) {
                root.savedConnectionSsids = []
                if (callback) callback([])
                return
            }
            const lines = result.output.trim().split("\n").filter(line => line.length > 0)
            const wifiConnections = []
            for (const line of lines) {
                const parts = line.split(":")
                if (parts.length >= 2 && parts[1] === "802-11-wireless") wifiConnections.push(parts[0])
            }

            if (wifiConnections.length > 0) {
                root.wifiConnectionQueue = wifiConnections
                root.currentSsidQueryIndex = 0
                root.savedConnectionSsids = []
                queryNextSsid(callback)
            } else {
                root.savedConnectionSsids = []
                root.wifiConnectionQueue = []
                if (callback) callback(root.savedConnectionSsids)
            }
        })
    }

    function queryNextSsid(callback: var): void {
        if (root.currentSsidQueryIndex < root.wifiConnectionQueue.length) {
            const connectionName = root.wifiConnectionQueue[root.currentSsidQueryIndex]
            root.currentSsidQueryIndex++
            executeCommand(["-t", "-f", "802-11-wireless.ssid", "connection", "show", connectionName], result => {
                if (result.success) {
                    const out = result.output.trim()
                    const idx = out.indexOf(":")
                    if (idx >= 0) {
                        const ssid = out.slice(idx + 1).trim()
                        if (ssid.length > 0 && !root.savedConnectionSsids.some(s => s && s.toLowerCase() === ssid.toLowerCase())) {
                            const newList = root.savedConnectionSsids.slice()
                            newList.push(ssid)
                            root.savedConnectionSsids = newList
                        }
                    }
                }
                queryNextSsid(callback)
            })
        } else {
            root.wifiConnectionQueue = []
            root.currentSsidQueryIndex = 0
            if (callback) callback(root.savedConnectionSsids)
        }
    }

    function hasSavedProfile(ssid: string): bool {
        if (!ssid || ssid.length === 0) return false
        const ssidLower = ssid.toLowerCase().trim()

        if (root.active && root.active.ssid) {
            const activeLower = root.active.ssid.toLowerCase().trim()
            if (activeLower === ssidLower) return true
        }

        return root.savedConnectionSsids.some(saved => saved && saved.toLowerCase().trim() === ssidLower)
    }

    // ── Orquestación de conexión (fusionado desde NetworkConnection.qml) ─────
    // Flujo completo: desconexión previa si hace falta, perfil guardado, y
    // solicitud de password cuando la red es segura. Reemplaza el singleton
    // intermedio que antes orquestaba estas llamadas.
    function handleConnect(network, session, onPasswordNeeded): void {
        if (!network) return

        if (root.active && root.active.ssid !== network.ssid) {
            root.disconnectFromNetwork()
            Qt.callLater(() => {
                root._connectFlow(network, session, onPasswordNeeded)
            })
        } else {
            root._connectFlow(network, session, onPasswordNeeded)
        }
    }

    function _connectFlow(network, session, onPasswordNeeded): void {
        if (!network) return

        if (network.isSecure) {
            const hasSavedProfile = root.hasSavedProfile(network.ssid)

            if (hasSavedProfile) {
                root.connectToNetwork(network.ssid, "", network.bssid, null)
            } else {
                root.connectToNetworkWithPasswordCheck(network.ssid, network.isSecure, result => {
                    if (result.needsPassword) {
                        if (root.pendingConnection) {
                            root.connectionCheckTimer.stop()
                            root.immediateCheckTimer.stop()
                            root.immediateCheckTimer.checkCount = 0
                            root.pendingConnection = null
                        }

                        if (session && session.network) {
                            session.network.showPasswordDialog = true
                            session.network.pendingNetwork = network
                        } else if (onPasswordNeeded) {
                            onPasswordNeeded(network)
                        }
                    }
                }, network.bssid)
            }
        } else {
            root.connectToNetwork(network.ssid, "", network.bssid, null)
        }
    }

    function connectWithPassword(network, password, onResult): void {
        if (!network) return
        root.connectToNetwork(network.ssid, password || "", network.bssid || "", onResult || null)
    }

    // ── Estado pendiente / monitoreo de conexión ─────────────────────────────
    function checkPendingConnection(): void {
        if (root.pendingConnection) {
            Qt.callLater(() => {
                const connected = root.active && root.active.ssid === root.pendingConnection.ssid
                if (connected) {
                    connectionCheckTimer.stop()
                    immediateCheckTimer.stop()
                    immediateCheckTimer.checkCount = 0
                    if (root.pendingConnection.callback) {
                        root.pendingConnection.callback({ success: true, output: "Connected", error: "", exitCode: 0 })
                    }
                    root.pendingConnection = null
                } else {
                    if (!immediateCheckTimer.running) immediateCheckTimer.start()
                }
            })
        }
    }

    function handlePasswordRequired(proc: var, error: string, output: string, exitCode: int): bool {
        if (!proc || !error || error.length === 0) return false
        if (!isConnectionCommand(proc.cmdArgs) || !root.pendingConnection || !root.pendingConnection.callback) return false

        const needsPassword = detectPasswordRequired(error)
        if (needsPassword && !proc.callbackCalled && root.pendingConnection) {
            connectionCheckTimer.stop()
            immediateCheckTimer.stop()
            immediateCheckTimer.checkCount = 0
            const pending = root.pendingConnection
            root.pendingConnection = null
            proc.callbackCalled = true
            const result = { success: false, output: output || "", error: error, exitCode: exitCode, needsPassword: true }
            if (pending.callback) pending.callback(result)
            if (proc.callback && proc.callback !== pending.callback) proc.callback(result)
            return true
        }
        return false
    }

    // ── Init ─────────────────────────────────────────────────────────────────
    Component.onCompleted: {
        getWifiStatus(() => {})
        getNetworks(() => {})
        loadSavedConnections(() => {})
    }

    // ── Componentes y procesos ───────────────────────────────────────────────
    Component {
        id: commandProc
        CommandProcess {}
    }

    Component {
        id: apComp
        AccessPoint {}
    }

    Timer {
        id: connectionCheckTimer
        interval: 4000
        onTriggered: {
            if (root.pendingConnection) {
                const connected = root.active && root.active.ssid === root.pendingConnection.ssid
                if (!connected && root.pendingConnection.callback) {
                    const pending = root.pendingConnection
                    const failedSsid = pending.ssid
                    root.pendingConnection = null
                    immediateCheckTimer.stop()
                    immediateCheckTimer.checkCount = 0
                    root.connectionFailed(failedSsid)
                    pending.callback({ success: false, output: "", error: "Connection timeout", exitCode: -1, needsPassword: false })
                } else if (connected) {
                    root.pendingConnection = null
                    immediateCheckTimer.stop()
                    immediateCheckTimer.checkCount = 0
                }
            }
        }
    }

    Timer {
        id: immediateCheckTimer
        property int checkCount: 0
        interval: 500
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            if (root.pendingConnection) {
                checkCount++
                const connected = root.active && root.active.ssid === root.pendingConnection.ssid
                if (connected) {
                    connectionCheckTimer.stop()
                    immediateCheckTimer.stop()
                    immediateCheckTimer.checkCount = 0
                    if (root.pendingConnection.callback) {
                        root.pendingConnection.callback({ success: true, output: "Connected", error: "", exitCode: 0 })
                    }
                    root.pendingConnection = null
                } else if (checkCount >= 6) {
                    immediateCheckTimer.stop()
                    immediateCheckTimer.checkCount = 0
                }
            } else {
                immediateCheckTimer.stop()
                immediateCheckTimer.checkCount = 0
            }
        }
    }

    Process {
        id: rescanProc
        command: ["nmcli", "dev", "wifi", "list", "--rescan", "yes"]
        onExited: root.getNetworks() // qmllint disable signal-handler-parameters
    }

    Process {
        id: monitorProc
        running: true
        command: ["nmcli", "monitor"]
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: SplitParser {
            onRead: root.getNetworks(() => {})
        }
        onExited: monitorRestartTimer.start() // qmllint disable signal-handler-parameters
    }

    Timer {
        id: monitorRestartTimer
        interval: 2000
        onTriggered: monitorProc.running = true
    }

    component CommandProcess: Process {
        id: proc

        property var callback: null
        property list<string> cmdArgs: []
        property bool callbackCalled: false
        property int exitCode: 0

        signal processFinished

        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })

        stdout: StdioCollector {
            id: stdoutCollector
        }

        stderr: StdioCollector {
            id: stderrCollector
            onStreamFinished: {
                const error = text.trim()
                if (error && error.length > 0) {
                    const output = (stdoutCollector && stdoutCollector.text) ? stdoutCollector.text : ""
                    root.handlePasswordRequired(proc, error, output, -1)
                }
            }
        }

        onExited: code => { // qmllint disable signal-handler-parameters
            exitCode = code

            Qt.callLater(() => {
                if (callbackCalled) { processFinished(); return }

                if (proc.callback) {
                    const output = (stdoutCollector && stdoutCollector.text) ? stdoutCollector.text : ""
                    const error = (stderrCollector && stderrCollector.text) ? stderrCollector.text : ""
                    const success = exitCode === 0
                    const cmdIsConnection = root.isConnectionCommand(proc.cmdArgs)

                    if (root.handlePasswordRequired(proc, error, output, exitCode)) {
                        processFinished()
                        return
                    }

                    const needsPassword = cmdIsConnection && root.detectPasswordRequired(error)

                    if (!success && cmdIsConnection && root.pendingConnection) {
                        const failedSsid = root.pendingConnection.ssid
                        root.connectionFailed(failedSsid)
                    }

                    callbackCalled = true
                    callback({ success: success, output: output, error: error, exitCode: proc.exitCode, needsPassword: needsPassword || false })
                    processFinished()
                } else {
                    processFinished()
                }
            })
        }
    }

    component AccessPoint: QtObject {
        required property var lastIpcObject
        readonly property string ssid: lastIpcObject.ssid
        readonly property string bssid: lastIpcObject.bssid
        readonly property int strength: lastIpcObject.strength
        readonly property int frequency: lastIpcObject.frequency
        readonly property bool active: lastIpcObject.active
        readonly property string security: lastIpcObject.security
        readonly property bool isSecure: security.length > 0
    }
}
