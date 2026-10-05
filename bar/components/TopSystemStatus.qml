import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "../"
import "../Singletons"

Item {
    id: root
    required property string screenName
    property real s: 1
    property real availableWidth: 360
    signal requestSurface(string name)

    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === screenName) || null
    readonly property var workspace: monitor ? monitor.activeWorkspace : null
    readonly property var window: {
        const active = Hyprland.activeToplevel
        if (active && active.workspace === workspace) return active
        if (!workspace) return null
        const address = workspace.lastIpcObject ? workspace.lastIpcObject.lastwindow : ""
        return Hyprland.toplevels.values.find(t => t.address === address) || null
    }
    readonly property string appClass: window && window.lastIpcObject ? (window.lastIpcObject.class || "") : ""
    readonly property string appName: {
        const entry = appClass ? DesktopEntries.heuristicLookup(appClass) : null
        if (entry && entry.name) return entry.name
        const source = appClass.split(".")
        const name = (source.length > 2 ? source[source.length - 1] : appClass)
            .replace(/\.desktop$/i, "").replace(/[-_]+/g, " ").trim()
        if (name) return name.replace(/\b\w/g, c => c.toUpperCase())
        return window ? (window.title || qsTr("Ventana")) : ""
    }
    readonly property string appIcon: {
        if (!appClass) return ""
        const entry = DesktopEntries.heuristicLookup(appClass)
        const icon = entry && entry.icon ? entry.icon : appClass.toLowerCase()
        return Quickshell.iconPath(icon, true) ? Quickshell.iconPath(icon) : ""
    }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery && battery.ready && battery.isLaptopBattery && battery.isPresent
    readonly property real batteryLevel: hasBattery ? battery.percentage : 0
    readonly property bool batteryCharging: hasBattery && (battery.state === UPowerDeviceState.Charging
        || battery.state === UPowerDeviceState.FullyCharged && !UPower.onBattery)
    readonly property bool batteryPaused: hasBattery && battery.state === UPowerDeviceState.PendingCharge
    readonly property string batteryStateText: batteryCharging ? qsTr("Cargando")
        : batteryPaused ? qsTr("Carga en espera")
        : batteryLevel <= 0.2 ? qsTr("Batería baja") : qsTr("En uso")
    readonly property real contentWidth: window ? Math.min(availableWidth, (hasBattery ? 233 : 205) * s)
        : (hasBattery ? 105 : 69) * s
    width: contentWidth
    height: 38 * s
    visible: availableWidth >= 142 * s

    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    PillMaterial { s: root.s; morphRadius: root.height / 2; mode: "status" }

    Row {
        id: status
        anchors.right: parent.right
        anchors.rightMargin: 11 * root.s
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9 * root.s

        Item {
            width: 19 * root.s; height: 26 * root.s
            MaterialIcon {
                anchors.centerIn: parent
                iconName: Icons.getVolumeIcon(root.audio ? root.audio.volume : 0, root.audio ? root.audio.muted : true)
                color: Theme.iconSecondary
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                interaction: volumeHit.motion
            }
            MotionArea {
                id: volumeHit
                anchors.fill: parent
                feedbackEnabled: false
                accessibleName: qsTr("Abrir mezclador de volumen")
                onClicked: root.requestSurface("mixer")
            }
        }
        Item {
            width: 19 * root.s; height: 26 * root.s
            MaterialIcon {
                anchors.centerIn: parent
                iconName: Nmcli.wifiEnabled && Nmcli.active ? Icons.iWifi : Icons.iWifiOff
                color: Nmcli.wifiEnabled && Nmcli.active ? Theme.iconSecondary : Theme.iconMuted
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                interaction: wifiHit.motion
            }
            MotionArea {
                id: wifiHit
                anchors.fill: parent
                feedbackEnabled: false
                accessibleName: qsTr("Abrir conectividad")
                onClicked: root.requestSurface("connectivity")
            }
        }
        Item {
            width: 27 * root.s; height: 26 * root.s
            visible: root.hasBattery
            BatteryIndicator {
                anchors.centerIn: parent
                s: root.s
                level: root.batteryLevel
                charging: root.batteryCharging
                chargePaused: root.batteryPaused
            }
            MotionArea {
                id: batteryHit
                anchors.fill: parent
                feedbackEnabled: false
                accessibleName: qsTr("Batería %1 %, %2. Abrir energía").arg(Math.round(root.batteryLevel * 100))
                    .arg(root.batteryStateText)
                onClicked: root.requestSurface("utils")
            }
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.bottom
                anchors.topMargin: 7 * root.s
                width: batteryTip.implicitWidth + 18 * root.s
                height: 25 * root.s
                radius: height / 2
                color: Qt.alpha(Theme.cardTop, 0.96)
                border.width: Theme.borderHairline
                border.color: Theme.border
                opacity: batteryHit.containsMouse || batteryHit.activeFocus ? 1 : 0
                visible: opacity > 0.01
                z: 10
                Behavior on opacity { Anim { type: Anim.FastEffects } }
                Text {
                    id: batteryTip
                    anchors.centerIn: parent
                    text: qsTr("%1 % · %2").arg(Math.round(root.batteryLevel * 100)).arg(root.batteryStateText)
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeLabel * root.s
                }
            }
        }
    }

    Rectangle {
        id: separator
        anchors.right: status.left
        anchors.rightMargin: 11 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.borderHairline
        height: 15 * root.s
        color: Theme.hair
        visible: root.window !== null
    }

    Item {
        anchors.left: parent.left
        anchors.leftMargin: 11 * root.s
        anchors.right: separator.left
        anchors.rightMargin: 10 * root.s
        anchors.verticalCenter: parent.verticalCenter
        height: 28 * root.s
        visible: root.window !== null
        clip: true
        Row {
            anchors.fill: parent
            spacing: 7 * root.s
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 19 * root.s; height: width
                source: root.appIcon
                visible: source.toString().length > 0
                fillMode: Image.PreserveAspectFit
            }
            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.appIcon
                iconName: /terminal|kitty|alacritty|foot|wezterm|konsole/i.test(root.appClass) ? Icons.iTerminal : "apps"
                color: Theme.iconSecondary
                font.pixelSize: Theme.fontSizeBodyLg * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - 26 * root.s)
                text: root.appName
                elide: Text.ElideRight
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall * root.s
            }
        }
    }
}
