pragma ComponentBehavior: Bound
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
    property bool showApps: true
    property bool showAudio: true
    property bool showNetwork: true
    property bool showBattery: true
    property bool animateChanges: true
    signal requestSurface(string name)

    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === screenName) || null
    readonly property var workspace: monitor ? monitor.activeWorkspace : null
    property var windows: appModule.active ? Hyprland.toplevels.values.filter(t => t.workspace === root.workspace) : []
    readonly property var apps: [...new Set(windows.map(t => t.lastIpcObject
        ? (t.lastIpcObject.class || "") : "").filter(c => c.length > 0))].sort()
    readonly property var appEntries: {
        const entries = ({})
        for (const app of apps) {
            const entry = DesktopEntries.heuristicLookup(app)
            entries[app] = { name: entry && entry.name ? entry.name : app,
                icon: entry && entry.icon ? entry.icon : app.toLowerCase() }
        }
        return entries
    }
    readonly property TopAppStrip appStrip: appModule.status === Loader.Ready ? (appModule.item as TopAppStrip) : null
    readonly property bool nameShown: appStrip && appStrip.nameShown
    readonly property real nameWidth: appStrip ? appStrip.nameWidth : 0
    readonly property int controlCount: Number(audioModule.active) + Number(networkModule.active) + Number(batteryModule.active)
    readonly property real controlsWidth: ((audioModule.active ? 19 : 0) + (networkModule.active ? 19 : 0)
        + (batteryModule.active ? 27 : 0) + Math.max(0, controlCount - 1) * 7) * s
    readonly property real statusWidth: controlCount > 0 ? controlsWidth + 22 * s : 18 * s
    readonly property real appsWidth: appModule.active && apps.length
        ? (apps.length * 26 + (status.width > 0 ? 17 : 0)) * s + (nameShown ? nameWidth : 0) : 0
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
    readonly property real minimumWidth: (22 + (showAudio ? 19 : 0) + (showNetwork ? 19 : 0)
        + (showBattery && hasBattery ? 27 : 0)
        + Math.max(0, (Number(showAudio) + Number(showNetwork) + Number(showBattery && hasBattery) - 1)) * 7
        + (showApps && apps.length ? 43 : 0)) * s
    readonly property bool hasContent: showAudio || showNetwork || showBattery && hasBattery || showApps && apps.length > 0
    readonly property bool fits: availableWidth >= minimumWidth && hasContent
    readonly property real contentWidth: Math.min(availableWidth, statusWidth + appsWidth)
    width: contentWidth
    Behavior on width {
        enabled: root.visible && root.animateChanges && !Flags.reduceMotion
        SmoothedAnimation { velocity: -1; duration: Motion.morph }
    }
    height: 38 * s
    visible: fits

    PwObjectTracker { objects: root.showAudio && root.sink ? [root.sink] : [] }

    PillMaterial { s: root.s; morphRadius: root.height / 2; mode: "status" }

    Row {
        id: status
        width: root.controlsWidth
        anchors.right: parent.right
        anchors.rightMargin: 11 * root.s
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7 * root.s

        OptionalModule {
            s: root.s
            id: audioModule
            visible: active
            presented: root.width - root.controlsWidth - 11 * root.s + audioModule.x >= 9 * root.s
            objectName: "statusAudioModule"
            requested: root.showAudio
            animateChanges: root.animateChanges
            sourceComponent: TopAudioStatus {
                s: root.s
                volume: root.audio ? root.audio.volume : 0
                muted: root.audio ? root.audio.muted : true
                onActivated: root.requestSurface("mixer")
            }
        }
        OptionalModule {
            s: root.s
            id: networkModule
            visible: active
            presented: root.width - root.controlsWidth - 11 * root.s + networkModule.x >= 9 * root.s
            objectName: "statusNetworkModule"
            requested: root.showNetwork
            animateChanges: root.animateChanges
            sourceComponent: TopNetworkStatus {
                s: root.s
                connected: Nmcli.wifiEnabled && !!Nmcli.active
                onActivated: root.requestSurface("connectivity")
            }
        }
        OptionalModule {
            s: root.s
            id: batteryModule
            visible: active
            presented: root.width - root.controlsWidth - 11 * root.s + batteryModule.x >= 9 * root.s
            objectName: "statusBatteryModule"
            requested: root.showBattery && root.hasBattery
            animateChanges: root.animateChanges
            sourceComponent: TopBatteryStatus {
                s: root.s
                level: root.batteryLevel
                charging: root.batteryCharging
                chargePaused: root.batteryPaused
                stateText: root.batteryStateText
                onActivated: root.requestSurface("utils")
            }
        }
    }

    Rectangle {
        id: separator
        visible: x >= 9 * root.s
        anchors.right: status.left
        anchors.rightMargin: 11 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.borderHairline
        height: 15 * root.s
        color: Theme.hair
        opacity: appModule.exposure * (root.apps.length && status.width > 0 ? 1 : 0)
        Behavior on opacity { Anim { type: Anim.FastEffects } }
    }

    OptionalModule {
        id: appModule
        x: 9 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, (status.width > 0 ? separator.x - 7 * root.s : root.width - 9 * root.s) - x)
        requested: root.showApps
        s: root.s
        animateChanges: root.animateChanges
        sourceComponent: TopAppStrip {
            s: root.s
            apps: root.apps
            appEntries: root.appEntries
            animateChanges: root.animateChanges
        }
    }
}
