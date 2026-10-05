import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../"
import "../components"
import "../Singletons"

/**
 * Isla · ConnectivitySurface. Panel de Wi-Fi + Bluetooth.
 * Wi-Fi y Bluetooth comparten el servicio existente; cada radio ocupa una
 * vista enfocada dentro de la misma superficie de la pill.
 */
PillSurface {
    id: root
    mTop: Theme.marginLg; mLeft: Theme.marginLg; mRight: Theme.marginLg; mBottom: Theme.marginMd
    clip: true
    property string mode: "wifi"

    // ── Estado de conexión WiFi ─────────────────────────────────────────────
    property string connectingToSsid: ""
    property var passwordNetwork: null
    property bool showPasswordDialog: false
    property bool passwordSucceeded: false
    property int passwordAttempt: 0
    readonly property string activeSsid: Nmcli.active ? Nmcli.active.ssid : ""

    function connectTo(network) {
        if (network.active) {
            Nmcli.disconnectFromNetwork()
            return
        }
        if (!network.isSecure) {
            root.connectingToSsid = network.ssid
            Nmcli.handleConnect(network, null, null)
            return
        }
        root.passwordAttempt++
        root.passwordNetwork = network
        root.passwordError = ""
        root.passwordSucceeded = false
        root.showPasswordDialog = true
    }

    function cancelPassword() {
        if (root.passwordConnecting) return
        root.passwordAttempt++
        root.showPasswordDialog = false
        root.passwordNetwork = null
        root.passwordError = ""
        root.passwordSucceeded = false
        credentials.reset()
        connectTimeout.stop()
        successHold.stop()
    }

    function submitPassword(secret) {
        if (!root.passwordNetwork || root.passwordConnecting || typeof secret !== "string" || secret.length < 8) return
        const attempt = ++root.passwordAttempt
        root.connectingToSsid = root.passwordNetwork.ssid
        root.passwordConnecting = true
        root.passwordError = ""
        connectTimeout.restart()
        Nmcli.connectWithPassword(root.passwordNetwork, secret, result => {
            if (attempt !== root.passwordAttempt || !root.showPasswordDialog) return
            connectTimeout.stop()
            root.passwordConnecting = false
            root.connectingToSsid = ""
            if (result && result.success) {
                root.passwordSucceeded = true
                root.passwordError = ""
                successHold.restart()
            } else if (result && result.needsPassword) {
                root.passwordError = qsTr("Contraseña incorrecta. Inténtalo de nuevo.")
            } else {
                root.passwordError = qsTr("No se pudo conectar. Comprueba la red.")
            }
        })
    }

    property bool passwordConnecting: false

    // seguridad: nunca dejar el spinner infinito si el callback no vuelve
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
    Timer { id: successHold; interval: Flags.reduceMotion ? 250 : Math.max(850, Motion.standard + Motion.fast); onTriggered: root.cancelPassword() }
    property string passwordError: ""

    // evita que la rueda llegue al control de volumen de la pill
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {}
    }

    Flickable {
        id: networkList
        anchors.fill: parent
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        enabled: !root.showPasswordDialog
        opacity: root.showPasswordDialog ? 0 : 1
        visible: opacity > 0.01
        Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast } }

        ColumnLayout {
            id: col
            width: parent.width
            spacing: Theme.spacingLg * s

            // ── Header con animación de entrada ─────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 62 * s
                opacity: root.open ? 1 : 0
                Behavior on opacity { Anim { type: Anim.DefaultEffects } }

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingLg * s

                    Item {
                        width: 46 * s; height: 46 * s
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusXl * s
                            gradient: Gradient {
                                GradientStop { position: 0; color: Qt.alpha(Theme.accent, Theme.alphaEmphasis) }
                                GradientStop { position: 1; color: Qt.alpha(Theme.accent, Theme.alphaGhost) }
                            }
                            border.width: Theme.borderHairline
                            border.color: Qt.alpha(Theme.accent, Theme.alphaMid)
                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: root.mode === "wifi" ? Icons.iWifi : Icons.iBluetooth
                                color: Theme.accent
                                font.pixelSize: Theme.fontSizeTitleLg * s
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: Theme.spacingXxs * s
                        Layout.fillWidth: true
                        AnimatedLabel {
                            value: root.mode === "wifi" ? qsTr("Wi-Fi") : qsTr("Bluetooth")
                            color: Theme.foreground
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeTitle * s; font.weight: Font.DemiBold
                        }
                        AnimatedLabel {
                            value: root.mode === "wifi"
                                ? (Nmcli.wifiEnabled ? (root.activeSsid || qsTr("Busca una red para conectarte")) : qsTr("Desactivado"))
                                : (btCard.btEnabled ? qsTr("Dispositivos disponibles") : qsTr("Desactivado"))
                            color: Theme.iconSecondary
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * s
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40 * s
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusLg * s
                    color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
                }
                Rectangle {
                    x: root.mode === "wifi" ? 3 * s : parent.width / 2
                    y: 3 * s
                    width: parent.width / 2 - 3 * s
                    height: parent.height - 6 * s
                    radius: Theme.radiusMd * s
                    color: Qt.alpha(Theme.foreground, Theme.alphaSoft)
                    Behavior on x { enabled: !Flags.reduceMotion; SmoothedAnimation { duration: Motion.morph; velocity: -1 } }
                }
                RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    Repeater {
                        model: [{ key: "wifi", label: "Wi-Fi" }, { key: "bluetooth", label: "Bluetooth" }]
                        delegate: Item {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: root.mode === modelData.key ? Theme.foreground : Theme.iconSecondary
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSizeBody * s
                                font.weight: root.mode === modelData.key ? Font.DemiBold : Font.Normal
                            }
                            MotionArea {
                                anchors.fill: parent
                                accessibleName: qsTr("Mostrar %1").arg(modelData.label)
                                hoverWash: false
                                onClicked: root.mode = modelData.key
                            }
                        }
                    }
                }
            }

            // ════════════════════ WI-FI ════════════════════
            Rectangle {
                id: wifiCard
                visible: root.mode === "wifi"
                Layout.fillWidth: true
                radius: Theme.radiusXxl * s
                color: "transparent"
                implicitHeight: wifiCol.implicitHeight + 20 * s

                ColumnLayout {
                    id: wifiCol
                    anchors.fill: parent
                    anchors.margins: 12 * s
                    spacing: Theme.spacingMd * s

                    // ── Fila de cabecera WiFi ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingLg * s

                        // toggle animado estilo iOS (componente unificado)
                        Toggle {
                            accessibleName: qsTr("Wi-Fi")
                            checked: Nmcli.wifiEnabled
                            onToggled: Nmcli.toggleWifi()
                        }

                        AnimatedLabel {
                            value: Nmcli.wifiEnabled ? qsTr("Redes disponibles") : qsTr("Wi-Fi desactivado")
                            color: Nmcli.wifiEnabled ? Theme.foreground : Theme.iconMuted
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg * s; font.weight: Font.DemiBold
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: Nmcli.scanning ? qsTr("Buscando…") : ""
                            color: Theme.iconSecondary
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * s
                            visible: text.length > 0
                        }

                        // botón de scan circular animado
                        Item {
                            width: 26 * s; height: 26 * s
                            opacity: Nmcli.wifiEnabled ? 1 : 0.3
                            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                            Rectangle {
        scale: scanWifiHover.motion.visualScale
                                anchors.fill: parent; radius: Theme.radiusXl * s
                                color: scanWifiHover.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaWash) : "transparent"
                                border.width: Theme.borderHairline; border.color: Qt.alpha(Theme.border, Theme.alphaIconSec)
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                            }
                            MaterialIcon {
                                interaction: scanWifiHover.motion
                                anchors.centerIn: parent
                                iconName: Icons.iRefresh
                                hovered: scanWifiHover.containsMouse
                                scale: scanWifiHover.motion.visualScale
                                color: Nmcli.scanning ? Theme.accent : Theme.foreground
                                font.pixelSize: Theme.fontSizeTitle * s
                                RotationAnimator on rotation {
                                    from: 0; to: 360
                                    duration: 900
                                    loops: Animation.Infinite
                                    running: Nmcli.scanning && root.open && !Flags.reduceMotion
                                }
                            }
                            MotionArea {
                                id: scanWifiHover
                                anchors.fill: parent
                                accessibleName: qsTr("Buscar redes Wi-Fi")
                                hoverWash: false
                                onClicked: Nmcli.rescanWifi()
                            }
                        }
                    }

                    // ── Lista de redes ──
                    MotionList {
                        id: wifiRows
                        Layout.fillWidth: true
                        Layout.preferredHeight: count * 44 * root.s + Math.max(0, count - 1) * spacing
                        spacing: Theme.spacingLg * root.s
                        interactive: false
                        clip: true
                        visible: Nmcli.wifiEnabled
                        model: ScriptModel {
                            values: [...Nmcli.networks].sort((a, b) => {
                                if (a.active !== b.active) return b.active - a.active
                                return b.strength - a.strength
                            }).slice(0, 8)
                        }

                        delegate: Item {
                            id: netRow
                            required property Nmcli.AccessPoint modelData
                            required property int index
                            readonly property bool isConnecting: root.connectingToSsid === modelData.ssid
                            width: wifiRows.width
                            height: 44 * root.s

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusXl * s
                                color: {
                                    if (modelData.active) return Qt.alpha(Theme.accent, Theme.alphaGlow)
                                    return netRowHover.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaHair) : Qt.alpha(Theme.cardTop, Theme.alphaCritical)
                                }
                                border.width: modelData.active ? Theme.borderHairline : 0
                                border.color: Qt.alpha(Theme.accent, Theme.alphaStrong)
                                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                                Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                            }

                            RowLayout {
                                anchors.fill: parent; anchors.margins: 10 * s
                                spacing: Theme.spacingLg * s

                                // barras de señal dibujadas
                                Item {
                                    width: 18 * s; height: 16 * s
                                    id: signalBars
                                    property int level: Math.round(modelData.strength / 25) // 0-4
                                    property bool active: modelData.active
                                    Repeater {
                                        model: 4
                                        delegate: Rectangle {
                                            readonly property int barIdx: index
                                            width: 2.5 * s
                                            height: (4 - barIdx) * 3 * s + 4 * s
                                            radius: 1.5 * s
                                            x: barIdx * 4.5 * s
                                            y: parent.height - height
                                            color: {
                                                if (signalBars.active) return Theme.accent
                                                if (barIdx < signalBars.level) return Theme.foreground
                                                return Qt.alpha(Theme.foreground, Theme.alphaSubtle)
                                            }
                                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                                            Behavior on height { Anim { type: Anim.FastEffects } }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    spacing: Theme.spacingXxs * s
                                    Layout.fillWidth: true
                                    Text {
                                        scale: netRowHover.motion.visualScale
                                        transform: Translate { y: -Motion.labelTravel * netRowHover.motion.presence }
                                        text: modelData.ssid
                                        color: modelData.active ? Theme.accent : Theme.foreground
                                        font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * s
                                        font.weight: modelData.active ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        scale: netRowHover.motion.visualScale
                                        transform: Translate { y: -Motion.labelTravel * netRowHover.motion.presence }
                                        text: modelData.active
                                            ? "Conectado"
                                            : (modelData.isSecure ? "Protegida · WPA" : "Abierta")
                                        visible: modelData.active || modelData.isSecure
                                        color: modelData.active ? Theme.accent : Theme.iconSecondary
                                        font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * s
                                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                                    }
                                }

                                // icono candado
                                MaterialIcon {
                                    compressWithControl: true
                                    interaction: netRowHover.motion
                                    iconName: Icons.iLock
                                    visible: modelData.isSecure && !modelData.active
                                    color: Theme.iconMuted
                                    font.pixelSize: Theme.fontSizeLabel * s
                                }

                                // spinner de conexión
                                Item {
                                    width: 18 * s; height: 18 * s
                                    visible: isConnecting
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 14 * s; height: 14 * s; radius: Theme.radiusSm * s
                                        color: "transparent"
                                        border.width: Theme.borderEmphasis * s
                                        border.color: Theme.accent
                                        NumberAnimation on rotation {
                                            from: 0; to: 360
                                            duration: 700
                                            loops: Animation.Infinite
                                            running: isConnecting && root.open && !Flags.reduceMotion
                                        }
                                    }
                                }

                                // botón de desconexión / estado conectado
                                Item {
                                    width: 24 * s; height: 24 * s
                                    visible: modelData.active
                                    Rectangle {
        scale: disconnectWifiHover.motion.visualScale
                                        anchors.fill: parent; radius: Theme.radiusXl * s
                                        color: Qt.alpha(Theme.accent, Theme.alphaGlow)
                                        MaterialIcon {
                                            interaction: disconnectWifiHover.motion
                                            anchors.centerIn: parent
                                            iconName: Icons.iClose
                                            hovered: disconnectWifiHover.containsMouse
                                            color: Theme.accent
                                            font.pixelSize: Theme.fontSizeSmall * s
                                        }
                                    }
                                    MotionArea {
                                        id: disconnectWifiHover
                                        anchors.fill: parent
                                        accessibleName: qsTr("Desconectar de %1").arg(modelData.ssid)
                                        hoverWash: false
                                        onClicked: Nmcli.disconnectFromNetwork()
                                    }
                                }
                            }

                            MotionArea {
                                id: netRowHover
                                accessibleName: qsTr("Conectar a %1").arg(modelData.ssid)
                                focusOnTab: false
                                anchors.fill: parent
                                hoverWash: false
                                onClicked: root.connectTo(modelData)
                            }
                        }
                    }

                    // estado vacío
                    Text {
                        Layout.fillWidth: true
                        readonly property bool presented: Nmcli.wifiEnabled && Nmcli.networks.length === 0 && !Nmcli.scanning
                        visible: opacity > 0
                        text: "Sin redes disponibles"
                        color: Theme.iconSecondary
                        font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * s
                        horizontalAlignment: Text.AlignHCenter
                        opacity: presented ? 0.7 : 0
                        Behavior on opacity { NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                    }

                    // hint cuando wifi apagado
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34 * s
                        radius: Theme.radiusLg * s
                        visible: !Nmcli.wifiEnabled
                        color: Qt.alpha(Theme.cardBot, Theme.alphaCritical)
                        border.width: Theme.borderHairline; border.color: Qt.alpha(Theme.border, Theme.alphaCritical)
                        RowLayout {
                            anchors.centerIn: parent; spacing: Theme.spacingMd * s
                            MaterialIcon { iconName: Icons.iWifiOff; font.pixelSize: Theme.fontSizeBodyLg * s; color: Theme.iconMuted }
                            Text {
                                text: "Activa el Wi-Fi para ver redes"
                                color: Theme.iconSecondary
                                font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * s
                            }
                        }
                    }
                }
            }

            // ════════════════════ BLUETOOTH ════════════════════
            Rectangle {
                id: btCard
                visible: root.mode === "bluetooth"
                Layout.fillWidth: true
                radius: Theme.radiusXxl * s
                color: "transparent"
                implicitHeight: btCol.implicitHeight + 20 * s

                readonly property bool btEnabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
                readonly property bool btDiscovering: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.discovering : false
                readonly property var btDevices: Bluetooth.devices.values

                ColumnLayout {
                    id: btCol
                    anchors.fill: parent
                    anchors.margins: 12 * s
                    spacing: Theme.spacingMd * s

                    // ── Cabecera Bluetooth ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingLg * s

                        // toggle animado estilo iOS (componente unificado)
                        Toggle {
                            accessibleName: qsTr("Bluetooth")
                            checked: btCard.btEnabled
                            onToggled: {
                                const a = Bluetooth.defaultAdapter
                                if (a) a.enabled = !a.enabled
                            }
                        }

                        Text {
                            text: "Bluetooth"
                            color: btCard.btEnabled ? Theme.foreground : Theme.iconMuted
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg * s; font.weight: Font.DemiBold
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }

                        Item { Layout.fillWidth: true }

                        // botón de scan animado
                        Item {
                            width: 26 * s; height: 26 * s
                            opacity: btCard.btEnabled ? 1 : 0.3
                            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                            Rectangle {
        scale: scanBtHover.motion.visualScale
                                anchors.fill: parent; radius: Theme.radiusXl * s
                                color: scanBtHover.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaWash) : "transparent"
                                border.width: Theme.borderHairline; border.color: Qt.alpha(Theme.border, Theme.alphaIconSec)
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                            }
                            MaterialIcon {
                                interaction: scanBtHover.motion
                                anchors.centerIn: parent
                                iconName: Icons.iRefresh
                                hovered: scanBtHover.containsMouse
                                scale: scanBtHover.motion.visualScale
                                color: btCard.btDiscovering ? Theme.accent : Theme.foreground
                                font.pixelSize: Theme.fontSizeTitle * s
                                RotationAnimator on rotation {
                                    from: 0; to: 360
                                    duration: 900
                                    loops: Animation.Infinite
                                    running: btCard.btDiscovering && root.open && !Flags.reduceMotion
                                }
                            }
                            MotionArea {
                                id: scanBtHover
                                anchors.fill: parent
                                accessibleName: qsTr("Buscar dispositivos Bluetooth")
                                hoverWash: false
                                onClicked: {
                                    const a = Bluetooth.defaultAdapter
                                    if (a) a.discovering = !a.discovering
                                }
                            }
                        }
                    }

                    // ── Dispositivos ──
                    MotionList {
                        id: btRows
                        Layout.fillWidth: true
                        Layout.preferredHeight: count * 44 * root.s + Math.max(0, count - 1) * spacing
                        spacing: Theme.spacingLg * root.s
                        interactive: false
                        clip: true
                        visible: btCard.btEnabled
                        model: ScriptModel {
                            // `name` lee el Alias de BlueZ, que para un dispositivo sin
                            // nombre resuelto vale la MAC → NO sirve para detectar si hay
                            // nombre real. `deviceName` es el Name real (vacío = anónimo).
                            // Oculta anuncios BLE anónimos (sin Name resolvible y sin
                            // emparejar): sólo ruido de MAC, no un dispositivo real.
                            values: [...Bluetooth.devices.values]
                                .filter(d => d.connected || d.bonded || (d.deviceName && d.deviceName.length > 0))
                                .sort((a, b) =>
                                    (b.connected - a.connected)
                                    || (b.paired - a.paired)
                                    || (a.deviceName || a.name).localeCompare(b.deviceName || b.name)
                                ) // qmllint disable unresolved-type
                        }

                        delegate: Item {
                            required property BluetoothDevice modelData
                            required property int index
                            width: btRows.width
                            height: 44 * root.s

                            // estado transitorio: connecting/disconnecting/pairing
                            readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting
                                || modelData.state === BluetoothDeviceState.Disconnecting
                                || modelData.pairing
                            readonly property int statusIdx: modelData.state
                                                            // qmllint disable unresolved-type
                            // nombre mostrable: nombre real → alias (sólo si no es la MAC) → "Desconocido".
                            // Nunca se muestra la MAC como título (eso es lo que veíamos mal):
                            // `name` (Alias de BlueZ) cae a la MAC cuando no hay nombre real,
                            // y `deviceName` es el Name real (vacío = anónimo).
                            readonly property string displayName: {
                                if (modelData.deviceName && modelData.deviceName.length > 0)
                                    return modelData.deviceName
                                if (modelData.name && modelData.name.length > 0
                                        && modelData.name !== modelData.address
                                        && modelData.name !== modelData.address.replace(/:/g, "-").toUpperCase())
                                    return modelData.name
                                return "Dispositivo desconocido"
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusXl * s
                                color: modelData.connected
                                    ? Qt.alpha(Theme.accent, Theme.alphaGlow)
                                    : (btRowHover.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaHair) : Qt.alpha(Theme.cardTop, Theme.alphaCritical))
                                border.width: Theme.borderHairline
                                border.color: modelData.connected ? Qt.alpha(Theme.accent, Theme.alphaStrong) : Qt.alpha(Theme.border, Theme.alphaCritical)
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                                Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                            }

                            RowLayout {
                                anchors.fill: parent; anchors.margins: 10 * s
                                spacing: Theme.spacingLg * s

                                // icono dispositivo animado
                                Item {
                                    width: 30 * s; height: 30 * s
                                    Rectangle {
                                        anchors.fill: parent; radius: Theme.radiusMd * s
                                        color: modelData.connected ? Qt.alpha(Theme.accent, Theme.alphaSubtle) : Qt.alpha(Theme.foreground, Theme.alphaHair)
                                        border.width: Theme.borderHairline
                                        border.color: modelData.connected ? Qt.alpha(Theme.accent, Theme.alphaMid) : Qt.alpha(Theme.border, Theme.alphaCritical)
                                        MaterialIcon {
                                            interaction: btRowHover.motion
                                            anchors.centerIn: parent
                                            iconName: Icons.iBluetooth
                                            color: modelData.connected ? Theme.accent : Theme.foreground
                                            font.pixelSize: Theme.fontSizeBodyLg * s
                                            scale: modelData.connected ? 1.1 : 1
                                            opacity: busy ? 0 : 1
                                            Behavior on scale { Anim { type: Anim.FastEffects } }
                                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                                            Behavior on opacity { Anim { type: Anim.FastEffects } }
                                        }
                                        // spinner mientras conecta/vincula (mismos ejes que el scan de Wi-Fi)
                                        MaterialIcon {
                                            compressWithControl: true
                                            interaction: btRowHover.motion
                                            anchors.centerIn: parent
                                            iconName: Icons.iRefresh
                                            color: modelData.connected ? Theme.accent : Theme.accent
                                            font.pixelSize: Theme.fontSizeBodyLg * s
                                            visible: busy
                                            RotationAnimator on rotation {
                                                from: 0; to: 360
                                                duration: 900
                                                loops: Animation.Infinite
                                                running: busy && root.open && !Flags.reduceMotion
                                            }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    spacing: Theme.spacingXxs * s
                                    Layout.fillWidth: true
                                    Text {
                                        scale: btRowHover.motion.visualScale
                                        transform: Translate { y: -Motion.labelTravel * btRowHover.motion.presence }
                                        text: displayName
                                        color: modelData.connected ? Theme.accent : Theme.foreground
                                        font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * s; font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                                    }
                                    Text {
                                        scale: btRowHover.motion.visualScale
                                        transform: Translate { y: -Motion.labelTravel * btRowHover.motion.presence }
                                        text: {
                                            if (modelData.pairing) return "Vinculando…"
                                            if (modelData.state === BluetoothDeviceState.Connecting) return "Conectando…"
                                            if (modelData.state === BluetoothDeviceState.Disconnecting) return "Desconectando…"
                                            if (modelData.connected) {
                                                var base = "Conectado"
                                                if (modelData.batteryAvailable)
                                                    base += " · " + Math.round(modelData.battery * 100) + "%"
                                                return base
                                            }
                                            var state = modelData.paired ? "Vinculado" : "Disponible"
                                            // sin nombre real → acompaña la MAC como referencia (nunca como título)
                                            if (!modelData.deviceName || modelData.deviceName.length === 0)
                                                return state + " · " + (modelData.address || "")
                                            return state
                                        }
                                        color: modelData.connected ? Theme.accent : Theme.iconSecondary
                                        font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * s
                                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                                    }
                                }

                                // botón de acción
                                Item {
                                    width: (modelData.connected ? 78 : (modelData.paired ? 66 : 56)) * s
                                    height: 26 * s
                                    Behavior on width { Anim { type: Anim.FastSpatial } }
                                    Rectangle {
                                        anchors.fill: parent; radius: Theme.radiusXl * s
                                        opacity: busy ? 0.55 : 1
                                        color: {
                                            if (modelData.connected) return Qt.alpha(Theme.accentStrong, Theme.alphaGlow)
                                            if (modelData.paired) return Qt.alpha(Theme.accent, Theme.alphaGlow)
                                            return Qt.alpha(Theme.foreground, Theme.alphaHair)
                                        }
                                        border.width: Theme.borderHairline
                                        border.color: {
                                            if (modelData.connected) return Qt.alpha(Theme.accentStrong, Theme.alphaMid)
                                            if (modelData.paired) return Qt.alpha(Theme.accent, Theme.alphaMid)
                                            return Qt.alpha(Theme.border, Theme.alphaCritical)
                                        }
                                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                                        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: {
                                                if (busy) return "…"
                                                if (modelData.connected) return "Desconectar"
                                                if (modelData.paired) return "Conectar"
                                                return "Vincular"
                                            }
                                            color: modelData.connected ? Theme.accentStrong : Theme.accent
                                            font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * s; font.weight: Font.Medium
                                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                                        }
                                    }
                                    MotionArea {
                                        anchors.fill: parent
                                        enabled: !busy
                                        accessibleName: modelData.connected ? qsTr("Desconectar %1").arg(displayName)
                                            : modelData.paired ? qsTr("Conectar %1").arg(displayName)
                                            : qsTr("Vincular %1").arg(displayName)
                                        hoverWash: false
                                        onClicked: {
                                            if (modelData.connected)         modelData.disconnect()
                                            else if (modelData.paired)       modelData.connect()
                                            else                              modelData.pair()
                                        }
                                    }
                                }

                                // botón "olvidar" (sólo vinculados); aparece a la izquierda
                                Item {
                                    width: (modelData.paired && !busy ? 26 : 0) * s
                                    height: 26 * s
                                    clip: true
                                    visible: width > 0
                                    Behavior on width { Anim { type: Anim.FastSpatial } }
                                    Rectangle {
        scale: btForgetHover.motion.visualScale
                                        anchors.fill: parent; radius: Theme.radiusXl * s
                                        color: btForgetHover.containsMouse
                                            ? Qt.alpha(Theme.accentStrong, Theme.alphaGlow)
                                            : "transparent"
                                        border.width: Theme.borderHairline
                                        border.color: Qt.alpha(Theme.border, Theme.alphaCritical)
                                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                                        MaterialIcon {
                                            interaction: btForgetHover.motion
                                            anchors.centerIn: parent
                                            iconName: "delete"
                                            hovered: btForgetHover.containsMouse
                                            color: Theme.iconSecondary
                                            font.pixelSize: Theme.fontSizeBody * s
                                        }
                                    }
                                    MotionArea {
                                        id: btForgetHover
                                        anchors.fill: parent
                                        accessibleName: qsTr("Olvidar %1").arg(displayName)
                                        hoverWash: false
                                        onClicked: modelData.forget()
                                    }
                                }
                            }
                            MotionArea {
                                id: btRowHover
                                accessibleName: qsTr("Vincular %1").arg(displayName)
                                focusOnTab: false
                                anchors.fill: parent
                                visible: !modelData.connected && !modelData.paired
                                hoverWash: false
                                onClicked: modelData.pair()
                            }
                        }
                    }

                    // hint cuando bt apagado
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34 * s
                        radius: Theme.radiusLg * s
                        visible: !btCard.btEnabled
                        color: Qt.alpha(Theme.cardBot, Theme.alphaCritical)
                        border.width: Theme.borderHairline; border.color: Qt.alpha(Theme.border, Theme.alphaCritical)
                        RowLayout {
                            anchors.centerIn: parent; spacing: Theme.spacingMd * s
                            MaterialIcon { iconName: Icons.iBluetoothOff; font.pixelSize: Theme.fontSizeBodyLg * s; color: Theme.iconMuted }
                            Text {
                                text: "Activa el Bluetooth para ver dispositivos"
                                color: Theme.iconSecondary
                                font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * s
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 2 * s }
        }
    }

    // La lista cede el mismo vidrio a la credencial; no aparece un segundo modal.
    WifiCredentials {
        id: credentials
        anchors.fill: parent
        s: root.s
        ssid: root.passwordNetwork ? root.passwordNetwork.ssid : ""
        active: root.showPasswordDialog
        busy: root.passwordConnecting
        succeeded: root.passwordSucceeded
        errorText: root.passwordError
        visible: opacity > 0.01
        enabled: root.showPasswordDialog && !root.passwordSucceeded
        opacity: root.showPasswordDialog ? 1 : 0
        transform: Translate {
            y: root.showPasswordDialog ? 0 : 14 * root.s
            Behavior on y { enabled: !Flags.reduceMotion; SmoothedAnimation { duration: Motion.morph; velocity: -1 } }
        }
        z: 2
        Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast } }
        onSubmitted: secret => root.submitPassword(secret)
        onCancelled: root.cancelPassword()
        onEdited: if (root.passwordError.length) root.passwordError = ""
    }
}
