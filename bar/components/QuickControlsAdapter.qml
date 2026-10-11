import QtQuick
import Quickshell
import Quickshell.Io
import "../Singletons"

Item {
    id: root
    property real s: 1
    property bool contentReady: false
    property bool open: parent && "open" in parent ? parent.open : visible
    property bool showBrightness: Brightness.available
    property real brightnessPercent: Brightness.percent
    property bool brightnessLastWriteOk: Brightness.lastWriteOk
    property bool keepAwakeEnabled: KeepAwake.enabled
    property string keepAwakeElapsedTime: KeepAwake.elapsedTime
    property string activeProfile: ""
    property string profileError: ""
    property bool profileReadFailed: false
    property string pendingProfile: ""
    property bool profileSetFailed: false
    readonly property bool profileBusy: profileReader.running || profileWriter.running || pendingProfile.length > 0
    readonly property var profiles: ["performance", "balanced", "power-saver"]

    signal requestPage(string name)

    function setProfile(profile) {
        if (root.profiles.indexOf(profile) < 0 || root.profileBusy) return
        root.pendingProfile = profile
        root.profileError = ""
        root.profileReadFailed = false
        profileWriter.command = ["powerprofilesctl", "set", profile]
        profileWriter.running = true
    }

    function refreshProfile() {
        if (!root.profileBusy) profileReader.running = true
    }

    onOpenChanged: if (open) refreshProfile()

    QuickControlsView {
        anchors.fill: parent
        s: root.s
        contentReady: root.contentReady
        showBrightness: root.showBrightness
        brightnessPercent: root.brightnessPercent
        brightnessLastWriteOk: root.brightnessLastWriteOk
        keepAwakeEnabled: root.keepAwakeEnabled
        keepAwakeElapsedTime: root.keepAwakeElapsedTime
        activeProfile: root.activeProfile
        profileBusy: root.profileBusy
        profileError: root.profileError
        profiles: root.profiles
        onRequestPage: (name) => root.requestPage(name)
        onKeepAwakeToggleRequested: KeepAwake.toggle()
        onBrightnessSetPercent: (percent) => Brightness.setPercent(percent)
        onBrightnessStepRequested: (amount) => Brightness.stepPercent(amount)
        onProfileSelected: (profile) => root.setProfile(profile)
    }

    Component.onCompleted: refreshProfile()
    Timer {
        interval: 3000
        repeat: true
        running: root.open
        onTriggered: root.refreshProfile()
    }
    Process {
        id: profileWriter
        onExited: code => {
            root.profileSetFailed = code !== 0
            profileReader.running = true
        }
    }
    Process {
        id: profileReader
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector { id: profileOutput }
        onExited: code => Qt.callLater(() => {
            const profile = (profileOutput.text || "").trim().toLowerCase()
            const valid = code === 0 && root.profiles.indexOf(profile) >= 0
            if (valid) root.activeProfile = profile
            if (root.pendingProfile.length) {
                root.profileError = root.profileSetFailed ? qsTr("No se pudo aplicar el perfil.")
                    : !valid || profile !== root.pendingProfile ? qsTr("No se pudo confirmar el perfil.") : ""
                root.pendingProfile = ""
            } else if (!valid) {
                root.profileError = qsTr("No se pudo leer el perfil.")
                root.profileReadFailed = true
            } else if (root.profileReadFailed) {
                root.profileError = ""
                root.profileReadFailed = false
            }
        })
    }
}
