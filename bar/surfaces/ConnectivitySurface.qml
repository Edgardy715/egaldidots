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
 * Comportamiento replicado de caelestia (QML puro) con diseño nativo Isla:
 * tarjetas de vidrio, toggles animados, barras de señal dibujadas, filas con
 * entrada escalonada (stagger) y diálogo de password con morph.
 */
PillSurface {
    id: root
    mTop: Theme.marginLg; mLeft: Theme.marginLg; mRight: Theme.marginLg; mBottom: Theme.marginMd
    clip: true

    // ── Estado de conexión WiFi ─────────────────────────────────────────────
    property string connectingToSsid: ""
    property var passwordNetwork: null
    property bool showPasswordDialog: false
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
        root.passwordNetwork = network
        root.showPasswordDialog = true
        root.passwordField = ""
        root.passwordError = ""
    }

    function submitPassword() {
        if (!root.passwordNetwork || root.passwordField.length === 0) return
        root.connectingToSsid = root.passwordNetwork.ssid
        root.passwordConnecting = true
        root.passwordError = ""
        const password = root.passwordField
        root.passwordField = ""
        connectTimeout.restart()
        Nmcli.connectWithPassword(root.passwordNetwork, password, result => {
            connectTimeout.stop()
            root.passwordConnecting = false
            root.connectingToSsid = ""
            if (result && result.success) {
                root.showPasswordDialog = false
                root.passwordError = ""
            } else if (result && result.needsPassword) {
                root.passwordError = "Contraseña incorrecta"
            } else if (result && result.error) {
                root.passwordError = "Error: " + result.error
            } else {
                root.passwordError = "No se pudo conectar"
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
            root.passwordError = "Tiempo de conexión agotado"
        }
    }

    property string passwordField: ""
    property string passwordError: ""

    // evita que la rueda llegue al control de volumen de la pill
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {}
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: Theme.spacingXl * s

            // ── Header con animación de entrada ─────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 46 * s
                opacity: 0
                scale: 0.92
                Component.onCompleted: {
                    opacity = 1
                    scale = 1
                }
                Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                Behavior on scale { Anim { type: Anim.Morph } }

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingLg * s

                    // logo animado
                    Item {
                        width: 34 * s; height: 34 * s
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusLg * s
                            gradient: Gradient {
                                GradientStop { position: 0; color: Qt.alpha(Theme.accent, Theme.alphaEmphasis) }
                                GradientStop { position: 1; color: Qt.alpha(Theme.accent, Theme.alphaGhost) }
                            }
                            border.width: Theme.borderHairline
                            border.color: Qt.alpha(Theme.accent, Theme.alphaMid)
                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: Icons.iWifi
                                color: root.activeSsid.length > 0 ? Theme.accent : Theme.foreground
                                font.pixelSize: Theme.fontSizeHead * s
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: Theme.spacingXxs * s
                        Layout.fillWidth: true
                        Text {
                            text: "Conectividad"
                            color: Theme.foreground
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeTitle * s; font.weight: Font.DemiBold
                        }
                        Text {
                            text: root.activeSsid.length > 0
                                ? "Wi-Fi: " + root.activeSsid
                                : "Sin conexión Wi-Fi"
                            color: root.activeSsid.length > 0 ? Theme.accent : Theme.iconSecondary
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * s
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // indicador de conexión activa
                    Rectangle {
                        width: 8 * s; height: 8 * s; radius: Theme.radiusXs * s
                        color: root.activeSsid.length > 0 ? Theme.accent : Qt.rgba(1,1,1,0.12)
                        scale: root.activeSsid.length > 0 ? 1 : 0.6
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Behavior on scale { Anim { type: Anim.FastEffects } }
                    }
                }
            }

            // ════════════════════ WI-FI ════════════════════
            Rectangle {
                Layout.fillWidth: true
                radius: Theme.radiusXxl * s
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(Theme.cardTop.r, Theme.cardTop.g, Theme.cardTop.b, 0.6) }
                    GradientStop { position: 1; color: Qt.rgba(Theme.cardBot.r, Theme.cardBot.g, Theme.cardBot.b, 0.45) }
                }
                border.width: Theme.borderHairline; border.color: Theme.border
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

                        Text {
                            text: "Wi-Fi"
                            color: Nmcli.wifiEnabled ? Theme.foreground : Theme.iconMuted
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg * s; font.weight: Font.DemiBold
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: Nmcli.scanning ? "escanneando…" : (Nmcli.active ? Nmcli.active.ssid : "")
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
                    Repeater {
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
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44 * s

                            // entrada escalonada (stagger por índice)
                            opacity: 0
                            scale: 0.9
                            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                            Behavior on scale { Anim { type: Anim.Morph } }
                            Component.onCompleted: {
                                entryDelay.interval = Math.max(0, index * 45)
                                entryDelay.start()
                            }
                            Timer {
                                id: entryDelay
                                interval: 0
                                repeat: false
                                onTriggered: {
                                    netRow.opacity = 1
                                    netRow.scale = 1
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusXl * s
                                color: {
                                    if (modelData.active) return Qt.alpha(Theme.accent, Theme.alphaGlow)
                                    return netRowHover.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaHair) : Qt.alpha(Theme.cardTop, Theme.alphaCritical)
                                }
                                border.width: modelData.active ? 1 : 1
                                border.color: modelData.active ? Qt.alpha(Theme.accent, Theme.alphaStrong) : Qt.alpha(Theme.border, Theme.alphaCritical)
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
                        visible: Nmcli.wifiEnabled && Nmcli.networks.length === 0 && !Nmcli.scanning
                        text: "Sin redes disponibles"
                        color: Theme.iconSecondary
                        font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * s
                        horizontalAlignment: Text.AlignHCenter
                        opacity: 0
                        NumberAnimation on opacity { from: 0; to: 0.7; duration: Motion.morph }
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
                Layout.fillWidth: true
                radius: Theme.radiusXxl * s
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(Theme.cardTop.r, Theme.cardTop.g, Theme.cardTop.b, 0.6) }
                    GradientStop { position: 1; color: Qt.rgba(Theme.cardBot.r, Theme.cardBot.g, Theme.cardBot.b, 0.45) }
                }
                border.width: Theme.borderHairline; border.color: Theme.border
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
                    Repeater {
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
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44 * s

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

                            // entrada escalonada
                            opacity: 0
                            scale: 0.9
                            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                            Behavior on scale { Anim { type: Anim.Morph } }
                            Component.onCompleted: {
                                btEntryDelay.interval = Math.max(0, index * 45)
                                btEntryDelay.start()
                            }
                            Timer {
                                id: btEntryDelay
                                interval: 0
                                repeat: false
                                onTriggered: {
                                    parent.opacity = 1
                                    parent.scale = 1
                                }
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

    // ════════════════════ DIÁLOGO DE PASSWORD ════════════════════
    FocusScope {
        id: pwDialog
        anchors.fill: parent
        visible: root.showPasswordDialog
        activeFocusOnTab: true
        focus: visible
        z: 100

        onVisibleChanged: {
            if (visible) {
                root.passwordField = ""
                root.passwordError = ""
                pwCard.scale = 0.8
                pwCard.opacity = 0
                pwScaleAnim.start()
                pwOpacityAnim.start()
                passwordFocusTimer.restart()
            } else {
                passwordFocusTimer.stop()
            }
        }

        onActiveFocusChanged: {
            if (visible && !activeFocus)
                passwordFocusTimer.restart()
        }

        Timer {
            id: passwordFocusTimer
            interval: 50
            repeat: true
            onTriggered: {
                if (pwDialog.visible) {
                    pwDialog.forceActiveFocus()
                    if (pwDialog.activeFocus) passwordFocusTimer.stop()
                } else passwordFocusTimer.stop()
            }
        }

        // backdrop
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
            opacity: 0
            NumberAnimation on opacity {
                id: backdropAnim
                from: 0; to: 0.35
                duration: Motion.morph
                easing.type: Easing.OutCubic
                running: pwDialog.visible
            }
            MotionArea {
                anchors.fill: parent
                hoverWash: false
                onClicked: {
                    root.showPasswordDialog = false
                    root.passwordField = ""
                    root.passwordError = ""
                    root.passwordConnecting = false
                    root.connectingToSsid = ""
                    connectTimeout.stop()
                }
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.submitPassword()
                event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
                if (event.modifiers & Qt.ControlModifier) root.passwordField = ""
                else root.passwordField = root.passwordField.slice(0, -1)
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                root.showPasswordDialog = false
                root.passwordField = ""
                root.passwordError = ""
                root.passwordConnecting = false
                root.connectingToSsid = ""
                connectTimeout.stop()
                event.accepted = true
            } else if (event.text && event.text.length > 0 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                root.passwordField += event.text
                event.accepted = true
            }
        }

        // tarjeta del diálogo con morph
        Rectangle {
            id: pwCard
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.9, 340 * s)
            radius: Theme.radiusFull * s
            color: Qt.rgba(Theme.cardBot.r, Theme.cardBot.g, Theme.cardBot.b, 0.95)
            border.width: Theme.borderHairline; border.color: Qt.alpha(Theme.accent, Theme.alphaEmphasis)
            implicitHeight: pwCol.implicitHeight + 20 * s

            scale: 0.8
            opacity: 0
            transformOrigin: Item.Center
            NumberAnimation on scale { id: pwScaleAnim; from: 0.8; to: 1; duration: Motion.morph; easing.bezierCurve: Motion.bounceCurve }
            NumberAnimation on opacity { id: pwOpacityAnim; from: 0; to: 1; duration: Motion.standard; easing.type: Easing.OutCubic }

            // brillo superior (catch-light)
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1 * s
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.7
                height: 1 * s
                radius: Theme.radiusXs * s
                color: Theme.sheen
            }

            ColumnLayout {
                id: pwCol
                anchors.fill: parent; anchors.margins: 14 * s
                spacing: Theme.spacingLg * s

                // icono + título
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMd * s
                    Item {
                        width: 32 * s; height: 32 * s
                        Rectangle {
                            anchors.fill: parent; radius: Theme.radiusMd * s
                            color: Qt.alpha(Theme.accent, Theme.alphaGlow)
                            MaterialIcon {
                                anchors.centerIn: parent
                                iconName: Icons.iLock
                                color: Theme.accent
                                font.pixelSize: Theme.fontSizeTitle * s
                            }
                        }
                    }
                    ColumnLayout {
                        spacing: Theme.spacingXxs * s
                        Layout.fillWidth: true
                        Text {
                            text: "Contraseña de red"
                            color: Theme.foreground
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg * s; font.weight: Font.DemiBold
                        }
                        Text {
                            text: root.passwordNetwork ? root.passwordNetwork.ssid : ""
                            color: Theme.accent
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * s
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                // campo de password con animación de formas (patrón lockscreen caelestia)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40 * s
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusLg * s
                        color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
                        border.width: pwDialog.activeFocus ? 1 : 1
                        border.color: pwDialog.activeFocus ? Qt.alpha(Theme.accent, Theme.alphaCritical) : Qt.alpha(Theme.border, Theme.alphaIconSec)
                        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                    }

                    // formas geométricas aleatorias → círculo (lockscreen caelestia)
                    ShapePasswordInput {
                        anchors.centerIn: parent
                        password: root.passwordField
                        s: root.s
                    }

                    // placeholder cuando vacío
                    Text {
                        anchors.centerIn: parent
                        text: "Escribe la contraseña y pulsa Enter"
                        visible: root.passwordField.length === 0
                        color: Theme.iconSecondary
                        font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * s
                        opacity: 0.8
                    }

                    // cursor parpadeante
                    Rectangle {
                        visible: root.passwordField.length > 0
                        width: 1.5 * s
                        height: 16 * s
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                        x: {
                            // sigue el último dot
                            var last = (root.passwordField.length - 1) * (12 + 5) + 12
                            var center = parent.width / 2
                            return Math.min(center + last / 2 + 2 * s, parent.width - 8 * s)
                        }
                        opacity: 0
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { from: 0; to: 1; duration: 400 }
                            NumberAnimation { from: 1; to: 0; duration: 400 }
                        }
                    }
                }

                // estado conectando (spinner)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20 * s
                    visible: root.passwordConnecting
                    spacing: Theme.spacingMd * s
                    Item {
                        width: 14 * s; height: 14 * s
                        Rectangle {
                            anchors.centerIn: parent
                            width: 12 * s; height: 12 * s; radius: Theme.radiusSm * s
                            color: "transparent"
                            border.width: Theme.borderEmphasis * s
                            border.color: Theme.accent
                            NumberAnimation on rotation {
                                from: 0; to: 360
                                duration: 700
                                loops: Animation.Infinite
                            }
                        }
                    }
                    Text {
                        text: "Conectando a " + (root.passwordNetwork ? root.passwordNetwork.ssid : "")
                        color: Theme.accent
                        font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * s
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // error
                Text {
                    Layout.fillWidth: true
                    visible: root.passwordError.length > 0
                    text: root.passwordError
                    color: Theme.accentStrong
                    font.family: Theme.font; font.pixelSize: Theme.fontSizeCaption * s
                    wrapMode: Text.WordWrap
                    opacity: 0
                    NumberAnimation on opacity { from: 0; to: 1; duration: Motion.fast }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMd * s

                    // botón cancelar
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32 * s
                        Rectangle {
        scale: cancelHover.motion.visualScale
                            anchors.fill: parent; radius: Theme.radiusLg * s
                            color: cancelHover.containsMouse ? Qt.alpha(Theme.accentStrong, Theme.alphaWashStrong) : Qt.alpha(Theme.accentStrong, Theme.alphaSoft)
                            border.width: Theme.borderHairline; border.color: Qt.alpha(Theme.accentStrong, Theme.alphaEmphasis)
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                            Text {
                                transform: Translate { y: -Motion.labelTravel * cancelHover.motion.presence }
                                anchors.centerIn: parent
                                text: "Cancelar"
                                color: Theme.accentStrong
                                font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * s; font.weight: Font.Medium
                            }
                        }
                        MotionArea {
                            id: cancelHover
                            anchors.fill: parent
                            accessibleName: qsTr("Cancelar")
                            hoverWash: false
                            onClicked: {
                                root.showPasswordDialog = false
                                root.passwordField = ""
                                root.passwordError = ""
                                root.passwordConnecting = false
                                root.connectingToSsid = ""
                                connectTimeout.stop()
                            }
                        }
                    }

                    // botón conectar
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32 * s
                        Rectangle {
        scale: connectHover.motion.visualScale
                            anchors.fill: parent; radius: Theme.radiusLg * s
                            color: root.passwordField.length > 0 && !root.passwordConnecting
                                ? (connectHover.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
                                : Qt.alpha(Theme.accent, Theme.alphaMid)
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                            Text {
                                transform: Translate { y: -Motion.labelTravel * connectHover.motion.presence }
                                anchors.centerIn: parent
                                text: root.passwordConnecting ? "…" : "Conectar"
                                color: root.passwordField.length > 0 && !root.passwordConnecting ? "#000" : Qt.alpha(Theme.foreground, Theme.alphaStrong)
                                font.family: Theme.font; font.pixelSize: Theme.fontSizeLabel * s; font.weight: Font.DemiBold
                            }
                        }
                        MotionArea {
                            id: connectHover
                            anchors.fill: parent
                            enabled: !root.passwordConnecting
                            accessibleName: qsTr("Conectar a %1").arg(root.connectingToSsid)
                            hoverWash: false
                            onClicked: root.submitPassword()
                        }
                    }
                }
            }
        }
    }
}
