pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import "../Singletons"

Item {
    id: root
    property real s: 1
    property bool open: false
    property string mode: "wifi"
    property bool wifiEnabled: false
    property bool wifiScanning: false
    property var networks: []
    property string activeSsid: ""
    property string connectingToSsid: ""
    property bool btEnabled: false
    property bool btDiscovering: false
    property var devices: []
    property int connectingState: 1
    property int disconnectingState: 2
    property var passwordNetwork: null
    property bool showPasswordDialog: false
    property bool passwordSucceeded: false
    property bool passwordConnecting: false
    property string passwordError: ""
    property int resetCredentialsEpoch: 0
    signal wifiToggleRequested()
    signal wifiScanRequested()
    signal wifiDisconnectRequested()
    signal networkRequested(var network)
    signal bluetoothToggleRequested()
    signal bluetoothDiscoveryToggleRequested()
    signal bluetoothActionRequested(var device, string action)
    signal passwordSubmitRequested(string secret)
    signal passwordCancelRequested()
    signal passwordEdited()

    property string presentedMode: "wifi"
    property real contentExposure: 1
    readonly property bool wifiPage: presentedMode === "wifi"
    readonly property bool radioEnabled: wifiPage ? wifiEnabled : btEnabled
    readonly property bool scanning: wifiPage ? wifiScanning : btDiscovering
    readonly property var availableNetworks: [...networks].filter(n => !n.active)
        .sort((a, b) => b.strength - a.strength)
    readonly property var connectedNetwork: networks.find(n => n.active) || null
    readonly property var visibleDevices: [...devices]
        .filter(d => d.connected || d.bonded || (d.deviceName && d.deviceName.length > 0))
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired)
            || (a.deviceName || a.name).localeCompare(b.deviceName || b.name))
    readonly property int connectedDevices: visibleDevices.filter(d => d.connected).length
    readonly property bool motionActive: open && visible && !Flags.reduceMotion && !showPasswordDialog

    function revealFocusedControl() {
        const item = root.Window.window ? root.Window.window.activeFocusItem : null
        if (!item || !root.open || root.showPasswordDialog) return
        let ancestor = item.parent
        while (ancestor && ancestor !== networkList.contentItem) ancestor = ancestor.parent
        if (!ancestor) return
        const top = item.mapToItem(networkList.contentItem, 0, 0).y
        const bottom = top + item.height
        const padding = 8 * root.s
        let target = networkList.contentY
        if (top < target + padding) target = top - padding
        else if (bottom > target + networkList.height - padding) target = bottom - networkList.height + padding
        networkList.contentY = Math.max(0, Math.min(target, Math.max(0, networkList.contentHeight - networkList.height)))
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() { root.revealFocusedControl() }
    }

    function settleMode() {
        exchange.stop()
        contentFade.stop()
        presentedMode = mode
        contentExposure = 1
        networkList.contentY = 0
    }
    function changeMode() {
        if (!motionActive) { settleMode(); return }
        contentFade.stop()
        if (mode === presentedMode) {
            exchange.stop()
            contentFade.to = 1
        } else {
            contentFade.to = 0
            exchange.restart()
        }
        contentFade.start()
    }
    onModeChanged: changeMode()
    onMotionActiveChanged: if (!motionActive) settleMode()
    onResetCredentialsEpochChanged: credentials.reset()
    Component.onCompleted: settleMode()

    NumberAnimation {
        id: contentFade
        target: root
        property: "contentExposure"
        duration: Motion.fast * 0.65
        easing.type: Motion.easeStandard
    }
    Timer {
        id: exchange
        interval: Motion.fast * 0.65
        onTriggered: {
            root.contentExposure = 0
            root.presentedMode = root.mode
            networkList.contentY = 0
            contentFade.to = 1
            contentFade.start()
        }
    }

    component Label: Text {
        color: Theme.foreground
        font.family: Theme.font
        font.pixelSize: Theme.fontSizeBodyLg * root.s
        elide: Text.ElideRight
    }
    component Action: MotionButton {
        id: action
        property bool accented: false
        implicitHeight: 36 * root.s
        implicitWidth: Math.max(36 * root.s, actionLabel.implicitWidth + Theme.spacingXl * 2 * root.s)
        padding: Theme.spacingMd * root.s
        background: Rectangle {
            radius: height / 2
            color: action.accented ? Qt.alpha(Theme.accent, Theme.alphaGlow)
                : Qt.alpha(Theme.foreground, action.hovered ? Theme.alphaWash : Theme.alphaFaint)
            border.width: action.activeFocus ? Theme.borderHairline : 0
            border.color: Theme.accent
        }
        contentItem: Label {
            id: actionLabel
            text: action.text
            color: action.enabled ? (action.accented ? Theme.accent : Theme.foreground) : Theme.iconSecondary
            font.pixelSize: Theme.fontSizeSmall * root.s
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    component StatusIcon: Rectangle {
        id: badge
        property string iconName: Icons.iWifi
        property bool highlighted: false
        property bool busy: false
        implicitWidth: 42 * root.s
        implicitHeight: 42 * root.s
        radius: Theme.radiusXxl * root.s
        color: Qt.alpha(badge.highlighted ? Theme.accent : Theme.foreground,
            badge.highlighted ? Theme.alphaGlow : Theme.alphaFaint)
        MaterialIcon {
            anchors.centerIn: parent
            iconName: badge.busy ? Icons.iRefresh : badge.iconName
            color: badge.highlighted || badge.busy ? Theme.accent : Theme.iconSecondary
            font.pixelSize: Theme.fontSizeDisplayLg * root.s
            RotationAnimator on rotation {
                from: 0; to: 360
                duration: 1000
                loops: Animation.Infinite
                running: badge.busy && root.motionActive && badge.visible
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => { wheel.accepted = true }
    }
    ColumnLayout {
        id: page
        anchors.fill: parent
        spacing: Theme.spacingXxl * root.s
        visible: opacity > 0
        enabled: !root.showPasswordDialog && root.open
        opacity: root.showPasswordDialog ? 0 : 1
        Behavior on opacity { enabled: root.motionActive; NumberAnimation { duration: Motion.fast } }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36 * root.s
            Label {
                Layout.fillWidth: true
                text: qsTr("Conectividad")
                font.family: Theme.fontMedia
                font.pixelSize: Theme.fontSizeHero * root.s
                font.weight: Font.Medium
            }
            MaterialIcon {
                iconName: "settings_input_antenna"
                color: Theme.iconSecondary
                font.pixelSize: Theme.fontSizeDisplayLg * root.s
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 66 * root.s
            radius: Theme.radiusFull * root.s
            color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
            Rectangle {
                x: root.mode === "wifi" ? 4 * root.s : parent.width / 2
                y: 4 * root.s
                width: parent.width / 2 - 4 * root.s
                height: parent.height - 8 * root.s
                radius: Theme.radiusXxl * root.s
                color: Qt.alpha(Theme.foreground, Theme.alphaSoft)
                Behavior on x { enabled: root.motionActive; SmoothedAnimation { duration: Motion.standard; velocity: -1 } }
            }
            RowLayout {
                anchors.fill: parent
                spacing: 0
                Repeater {
                    model: ["wifi", "bluetooth"]
                    delegate: Item {
                        id: modeButton
                        required property string modelData
                        readonly property bool wifi: modelData === "wifi"
                        readonly property bool radioOn: wifi ? root.wifiEnabled : root.btEnabled
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.spacingMd * root.s
                            MaterialIcon {
                                iconName: modeButton.wifi ? Icons.iWifi : Icons.iBluetooth
                                color: root.mode === modeButton.modelData ? Theme.accent : Theme.iconSecondary
                                font.pixelSize: Theme.fontSizeDisplayLg * root.s
                            }
                            Column {
                                spacing: Theme.spacingXs * root.s
                                Label {
                                    text: modeButton.wifi ? qsTr("Wi-Fi") : qsTr("Bluetooth")
                                    font.weight: root.mode === modeButton.modelData ? Font.DemiBold : Font.Normal
                                }
                                Label {
                                    text: !modeButton.radioOn ? qsTr("Desactivado")
                                        : modeButton.wifi ? (root.activeSsid || root.connectedNetwork ? qsTr("Conectado") : qsTr("Activado"))
                                        : root.connectedDevices ? qsTr("%1 conectado(s)").arg(root.connectedDevices) : qsTr("Activado")
                                    color: Theme.iconSecondary
                                    font.pixelSize: Theme.fontSizeSmall * root.s
                                }
                            }
                        }
                        MotionArea {
                            objectName: "mode-" + modeButton.modelData
                            anchors.fill: parent
                            accessibleName: modeButton.wifi ? qsTr("Mostrar Wi-Fi") : qsTr("Mostrar Bluetooth")
                            hoverWash: false
                            onClicked: root.mode = modeButton.modelData
                        }
                    }
                }
            }
        }
        Flickable {
            id: networkList
            objectName: "connectivityScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                implicitWidth: 4 * root.s
                contentItem: Rectangle {
                    implicitWidth: 4 * root.s
                    radius: width / 2
                    color: Qt.alpha(Theme.iconSecondary, Theme.alphaStrong)
                }
                background: null
            }
            opacity: root.contentExposure
            enabled: !exchange.running
            transform: Translate { y: Flags.reduceMotion ? 0 : (1 - root.contentExposure) * 6 * root.s }
            ColumnLayout {
                id: body
                width: networkList.width
                spacing: Theme.spacingXxl * root.s
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40 * root.s
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs * root.s
                        Label {
                            text: root.radioEnabled ? qsTr("Activado") : qsTr("Desactivado")
                            font.pixelSize: Theme.fontSizeTitle * root.s
                            font.weight: Font.DemiBold
                        }
                        Label {
                            Layout.fillWidth: true
                            text: root.wifiPage ? qsTr("Conexión inalámbrica") : qsTr("Audio y dispositivos cercanos")
                            color: Theme.iconSecondary
                            font.pixelSize: Theme.fontSizeSmall * root.s
                        }
                    }
                    Toggle {
                        objectName: root.wifiPage ? "wifiToggle" : "bluetoothToggle"
                        s: root.s
                        accessibleName: root.wifiPage ? qsTr("Wi-Fi") : qsTr("Bluetooth")
                        checked: root.radioEnabled
                        onToggled: root.wifiPage ? root.wifiToggleRequested() : root.bluetoothToggleRequested()
                    }
                }
                Rectangle {
                    id: connectedHero
                    objectName: "wifiConnectedState"
                    visible: root.wifiPage && root.wifiEnabled && (root.connectedNetwork !== null || root.activeSsid.length > 0)
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(92 * root.s, connectedInfo.implicitHeight + Theme.spacingXxl * 2 * root.s)
                    radius: Theme.radiusXxl * root.s
                    color: Qt.alpha(Theme.accent, Theme.alphaHair)
                    MotionArea {
                        objectName: "network-" + (root.connectedNetwork ? root.connectedNetwork.ssid : root.activeSsid)
                        anchors.fill: parent
                        enabled: root.connectedNetwork !== null
                        accessibleName: qsTr("Desconectar de %1").arg(root.activeSsid)
                        hoverWash: false
                        onClicked: root.networkRequested(root.connectedNetwork)
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXl * root.s
                        spacing: Theme.spacingXl * root.s
                        StatusIcon { highlighted: true; iconName: Icons.iWifi }
                        ColumnLayout {
                            id: connectedInfo
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm * root.s
                            Label {
                                Layout.fillWidth: true
                                text: root.activeSsid || (root.connectedNetwork ? root.connectedNetwork.ssid : "")
                                font.family: Theme.fontMedia
                                font.pixelSize: Theme.fontSizeTitleLg * root.s
                                font.weight: Font.Medium
                            }
                            Label {
                                Layout.fillWidth: true
                                text: !root.connectedNetwork ? qsTr("Conectado")
                                    : root.connectedNetwork.isSecure ? qsTr("Conectado · Red protegida") : qsTr("Conectado · Red abierta")
                                color: Theme.iconSecondary
                                font.pixelSize: Theme.fontSizeSmall * root.s
                            }
                        }
                        Action {
                            objectName: "wifiDisconnect"
                            text: qsTr("Desconectar")
                            onClicked: root.wifiDisconnectRequested()
                        }
                    }
                }
                RowLayout {
                    visible: root.radioEnabled
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        text: root.wifiPage ? qsTr("Redes disponibles") : qsTr("Mis dispositivos y cercanos")
                        color: Theme.iconSecondary
                        font.pixelSize: Theme.fontSizeBody * root.s
                        font.weight: Font.Medium
                    }
                    Action {
                        objectName: root.wifiPage ? "wifiScan" : "bluetoothScan"
                        text: root.scanning ? (root.wifiPage ? qsTr("Buscando…") : qsTr("Detener")) : qsTr("Buscar")
                        accented: root.scanning
                        enabled: root.radioEnabled && (!root.wifiPage || !root.wifiScanning)
                        onClicked: root.wifiPage ? root.wifiScanRequested() : root.bluetoothDiscoveryToggleRequested()
                    }
                }
                Column {
                    Layout.fillWidth: true
                    visible: root.wifiPage && root.wifiEnabled
                    spacing: Theme.spacingSm * root.s
                    Repeater {
                        model: root.availableNetworks
                        delegate: Item {
                            id: networkRow
                            required property var modelData
                            readonly property bool busy: root.connectingToSsid === modelData.ssid
                            width: body.width
                            height: 66 * root.s
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusXl * root.s
                                color: Qt.alpha(Theme.foreground, networkArea.containsMouse ? Theme.alphaHair : Theme.alphaTransparent)
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingMd * root.s
                                anchors.rightMargin: Theme.spacingMd * root.s
                                spacing: Theme.spacingXl * root.s
                                StatusIcon { iconName: Icons.iWifi; busy: networkRow.busy }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingSm * root.s
                                    Label {
                                        Layout.fillWidth: true
                                        text: networkRow.modelData.ssid
                                        font.weight: Font.Medium
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: networkRow.busy ? qsTr("Conectando…")
                                            : (networkRow.modelData.isSecure ? qsTr("Protegida") : qsTr("Abierta"))
                                            + " · " + qsTr("Señal %1%").arg(networkRow.modelData.strength)
                                        color: Theme.iconSecondary
                                        font.pixelSize: Theme.fontSizeSmall * root.s
                                    }
                                }
                                MaterialIcon {
                                    iconName: networkRow.modelData.isSecure ? Icons.iLock : "chevron_right"
                                    color: Theme.iconSecondary
                                    font.pixelSize: Theme.fontSizeHead * root.s
                                }
                            }
                            MotionArea {
                                id: networkArea
                                objectName: "network-" + networkRow.modelData.ssid
                                anchors.fill: parent
                                accessibleName: qsTr("Conectar a %1").arg(networkRow.modelData.ssid)
                                enabled: !networkRow.busy
                                hoverWash: false
                                onClicked: root.networkRequested(networkRow.modelData)
                            }
                        }
                    }
                }
                Column {
                    Layout.fillWidth: true
                    visible: !root.wifiPage && root.btEnabled
                    spacing: Theme.spacingMd * root.s
                    Repeater {
                        model: root.visibleDevices
                        delegate: Rectangle {
                            id: deviceRow
                            required property var modelData
                            readonly property bool busy: modelData.state === root.connectingState
                                || modelData.state === root.disconnectingState || modelData.pairing
                            readonly property string displayName: modelData.deviceName ||
                                (modelData.name && modelData.name !== modelData.address
                                    && modelData.name !== (modelData.address || "").replace(/:/g, "-").toUpperCase()
                                    ? modelData.name : qsTr("Dispositivo desconocido"))
                            width: body.width
                            height: deviceContent.implicitHeight + Theme.spacingXl * 2 * root.s
                            radius: Theme.radiusXxl * root.s
                            color: modelData.connected ? Qt.alpha(Theme.accent, Theme.alphaHair) : Qt.alpha(Theme.foreground, Theme.alphaGhost)
                            ColumnLayout {
                                id: deviceContent
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.spacingXl * root.s
                                spacing: Theme.spacingMd * root.s
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingXl * root.s
                                    StatusIcon {
                                        iconName: Icons.iBluetooth
                                        highlighted: deviceRow.modelData.connected
                                        busy: deviceRow.busy
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingSm * root.s
                                        Label {
                                            Layout.fillWidth: true
                                            text: deviceRow.displayName
                                            font.weight: Font.Medium
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            text: {
                                                const d = deviceRow.modelData
                                                if (d.pairing) return qsTr("Vinculando…")
                                                if (d.state === root.connectingState) return qsTr("Conectando…")
                                                if (d.state === root.disconnectingState) return qsTr("Desconectando…")
                                                if (d.connected) return d.batteryAvailable
                                                    ? qsTr("Conectado · %1%").arg(Math.round(d.battery * 100)) : qsTr("Conectado")
                                                const status = d.paired ? qsTr("Vinculado") : qsTr("Disponible")
                                                return !d.deviceName ? status + " · " + (d.address || "") : status
                                            }
                                            color: deviceRow.modelData.connected ? Theme.accent : Theme.iconSecondary
                                            font.pixelSize: Theme.fontSizeSmall * root.s
                                        }
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 42 * root.s + Theme.spacingXl * root.s
                                    spacing: Theme.spacingMd * root.s
                                    Action {
                                        objectName: "bluetooth-action-" + deviceRow.displayName
                                        text: deviceRow.busy ? qsTr("Espera…") : deviceRow.modelData.connected ? qsTr("Desconectar")
                                            : deviceRow.modelData.paired ? qsTr("Conectar") : qsTr("Vincular")
                                        enabled: !deviceRow.busy
                                        Accessible.name: deviceRow.modelData.connected ? qsTr("Desconectar %1").arg(deviceRow.displayName)
                                            : deviceRow.modelData.paired ? qsTr("Conectar %1").arg(deviceRow.displayName)
                                            : qsTr("Vincular %1").arg(deviceRow.displayName)
                                        accented: !deviceRow.modelData.connected
                                        onClicked: root.bluetoothActionRequested(deviceRow.modelData,
                                            deviceRow.modelData.connected ? "disconnect" : deviceRow.modelData.paired ? "connect" : "pair")
                                    }
                                    Action {
                                        objectName: "bluetooth-forget-" + deviceRow.displayName
                                        visible: deviceRow.modelData.paired
                                        text: qsTr("Olvidar")
                                        enabled: !deviceRow.busy
                                        Accessible.name: qsTr("Olvidar %1").arg(deviceRow.displayName)
                                        onClicked: root.bluetoothActionRequested(deviceRow.modelData, "forget")
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                            }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacingXxl * root.s
                    visible: !root.radioEnabled || (root.wifiPage ? root.availableNetworks.length === 0 : root.visibleDevices.length === 0)
                    spacing: Theme.spacingXl * root.s
                    StatusIcon {
                        Layout.alignment: Qt.AlignHCenter
                        iconName: root.radioEnabled ? (root.wifiPage ? Icons.iWifi : Icons.iBluetooth)
                            : (root.wifiPage ? Icons.iWifiOff : Icons.iBluetoothOff)
                        busy: root.radioEnabled && root.scanning
                    }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: !root.radioEnabled ? (root.wifiPage ? qsTr("Wi-Fi desactivado") : qsTr("Bluetooth desactivado"))
                            : root.scanning ? qsTr("Buscando cerca de ti…")
                            : root.wifiPage ? qsTr("No hay más redes disponibles") : qsTr("Sin dispositivos disponibles")
                        font.pixelSize: Theme.fontSizeTitle * root.s
                        font.weight: Font.Medium
                    }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: !root.radioEnabled ? qsTr("Activa la conexión con el interruptor superior.")
                            : root.wifiPage ? qsTr("Las redes cercanas aparecerán aquí.")
                            : qsTr("Pon el dispositivo en modo de vinculación y pulsa Buscar.")
                        color: Theme.iconSecondary
                        font.pixelSize: Theme.fontSizeBody * root.s
                    }
                }
                Item { Layout.preferredHeight: Theme.spacingMd * root.s }
            }
        }
    }
    WifiCredentials {
        id: credentials
        objectName: "connectivityCredentials"
        anchors.fill: parent
        s: root.s
        ssid: root.passwordNetwork ? root.passwordNetwork.ssid : ""
        active: root.showPasswordDialog && root.open
        busy: root.passwordConnecting
        succeeded: root.passwordSucceeded
        errorText: root.passwordError
        visible: opacity > 0
        enabled: root.showPasswordDialog && !root.passwordSucceeded && root.open
        opacity: root.showPasswordDialog ? 1 : 0
        Behavior on opacity { enabled: root.open && !Flags.reduceMotion; NumberAnimation { duration: Motion.fast } }
        onSubmitted: secret => root.passwordSubmitRequested(secret)
        onCancelled: root.passwordCancelRequested()
        onEdited: root.passwordEdited()
    }
}
