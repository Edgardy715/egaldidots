import QtQuick
import Quickshell.Bluetooth
import "../Singletons"

// Owns network/device services and credential workflow; the child is presentation only.
Item {
    id: root
    property real s: 1
    property bool open: false
    property string connectingToSsid: ""
    property var passwordNetwork: null
    property bool showPasswordDialog: false
    property bool passwordSucceeded: false
    property bool passwordConnecting: false
    property int passwordAttempt: 0
    property string passwordError: ""

    readonly property string activeSsid: Nmcli.active ? Nmcli.active.ssid : ""
    readonly property int connectingState: BluetoothDeviceState.Connecting
    readonly property int disconnectingState: BluetoothDeviceState.Disconnecting

    function cancelPassword() {
        if (passwordConnecting) return
        passwordAttempt++
        showPasswordDialog = false
        passwordNetwork = null
        passwordError = ""
        passwordSucceeded = false
        resetCredentialsEpoch++
        connectTimeout.stop()
        successHold.stop()
    }

    function submitPassword(secret) {
        if (!passwordNetwork || passwordConnecting || typeof secret !== "string" || secret.length < 8) return
        const attempt = ++passwordAttempt
        connectingToSsid = passwordNetwork.ssid
        passwordConnecting = true
        passwordError = ""
        connectTimeout.restart()
        Nmcli.connectWithPassword(passwordNetwork, secret, result => {
            if (attempt !== passwordAttempt || !showPasswordDialog) return
            connectTimeout.stop()
            passwordConnecting = false
            connectingToSsid = ""
            if (result && result.success) {
                passwordSucceeded = true
                passwordError = ""
                successHold.restart()
            } else if (result && result.needsPassword) {
                passwordError = qsTr("Contraseña incorrecta. Inténtalo de nuevo.")
            } else {
                passwordError = qsTr("No se pudo conectar. Comprueba la red.")
            }
        })
    }

    property int resetCredentialsEpoch: 0

    Timer {
        id: connectTimeout
        interval: 10000
        repeat: false
        onTriggered: {
            root.passwordConnecting = false
            root.connectingToSsid = ""
            root.passwordError = qsTr("La conexión tarda más de lo previsto.")
        }
    }
    Timer {
        id: successHold
        interval: Flags.reduceMotion ? 250 : Math.max(850, Motion.standard + Motion.fast)
        onTriggered: root.cancelPassword()
    }

    ConnectivityView {
        anchors.fill: parent
        s: root.s
        open: root.open
        wifiEnabled: Nmcli.wifiEnabled
        wifiScanning: Nmcli.scanning
        networks: Nmcli.networks
        activeSsid: root.activeSsid
        connectingToSsid: root.connectingToSsid
        btEnabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
        btDiscovering: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.discovering : false
        devices: [...Bluetooth.devices.values]
            .filter(d => d.connected || d.bonded || (d.deviceName && d.deviceName.length > 0))
            .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired)
                || (a.deviceName || a.name).localeCompare(b.deviceName || b.name))
        connectingState: root.connectingState
        disconnectingState: root.disconnectingState
        passwordNetwork: root.passwordNetwork
        showPasswordDialog: root.showPasswordDialog
        passwordSucceeded: root.passwordSucceeded
        passwordConnecting: root.passwordConnecting
        passwordError: root.passwordError
        resetCredentialsEpoch: root.resetCredentialsEpoch
        onWifiToggleRequested: Nmcli.toggleWifi()
        onWifiScanRequested: Nmcli.rescanWifi()
        onWifiDisconnectRequested: Nmcli.disconnectFromNetwork()
        onNetworkRequested: network => {
            if (network.active) {
                Nmcli.disconnectFromNetwork()
            } else if (!network.isSecure) {
                root.connectingToSsid = network.ssid
                Nmcli.handleConnect(network, null, null)
            } else {
                root.passwordNetwork = network
                root.passwordError = ""
                root.passwordSucceeded = false
                root.passwordAttempt++
                root.showPasswordDialog = true
            }
        }
        onBluetoothToggleRequested: {
            const adapter = Bluetooth.defaultAdapter
            if (adapter) adapter.enabled = !adapter.enabled
        }
        onBluetoothDiscoveryToggleRequested: {
            const adapter = Bluetooth.defaultAdapter
            if (adapter) adapter.discovering = !adapter.discovering
        }
        onBluetoothActionRequested: (device, action) => {
            if (!device) return
            if (action === "disconnect") device.disconnect()
            else if (action === "connect") device.connect()
            else if (action === "pair") device.pair()
            else if (action === "forget") device.forget()
        }
        onPasswordSubmitRequested: secret => root.submitPassword(secret)
        onPasswordCancelRequested: root.cancelPassword()
        onPasswordEdited: if (root.passwordError.length) root.passwordError = ""
    }
}
