import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    id: test
    settings.watchFiles: false
    property var actions: []
    property var fakeNetwork: ({ ssid: "Fixture Open", active: false, isSecure: false, strength: 75 })
    property var fakeDevice: ({
        deviceName: "Fixture Headphones", name: "Fixture Headphones", address: "AA:BB",
        connected: false, paired: true, pairing: false, state: 0,
        batteryAvailable: false, battery: 0
    })

    Window {
        id: scene
        visible: true
        width: 620; height: 680
        color: Theme.background
        ConnectivityView {
            id: view
            anchors.fill: parent
            s: 1.15
            open: true
            wifiEnabled: true
            networks: [test.fakeNetwork]
            btEnabled: true
            devices: [test.fakeDevice]
            connectingState: 1
            disconnectingState: 2
            onWifiToggleRequested: test.actions.push(["wifi-toggle"])
            onNetworkRequested: network => test.actions.push(["network", network])
            onBluetoothActionRequested: (device, action) => test.actions.push(["bluetooth", device, action])
        }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "ConnectivityView"
            when: scene.visible
            property bool finished: false
            function test_mocked_connectivity_actions() {
                wait(250)
                const wifi = findChild(view, "wifiToggle")
                verify(wifi !== null)
                mouseClick(wifi, wifi.width / 2, wifi.height / 2)
                compare(test.actions[0][0], "wifi-toggle")

                const network = findChild(view, "network-Fixture Open")
                verify(network !== null)
                mouseClick(network, network.width / 2, network.height / 2)
                compare(test.actions[1][0], "network")
                compare(test.actions[1][1], test.fakeNetwork)

                view.mode = "bluetooth"
                wait(150)
                const device = findChild(view, "bluetooth-action-Fixture Headphones")
                verify(device !== null)
                mouseClick(device, device.width / 2, device.height / 2)
                compare(test.actions[2][0], "bluetooth")
                compare(test.actions[2][1], test.fakeDevice)
                compare(test.actions[2][2], "connect")
                console.log("PASS: connectivity view emits mocked Wi-Fi and Bluetooth actions without service changes")
                finished = true
            }
        }
    }
}
