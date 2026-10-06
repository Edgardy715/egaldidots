import QtQuick
import Quickshell
import Quickshell.Io
import "../Singletons"

Item {
    id: root
    property real s: 1
    property bool contentReady: false
    property bool showBrightness: Brightness.available
    property real brightnessPercent: Brightness.percent
    property bool brightnessLastWriteOk: Brightness.lastWriteOk
    property bool keepAwakeEnabled: KeepAwake.enabled
    property string keepAwakeElapsedTime: KeepAwake.elapsedTime
    property string activeProfile: "balanced"
    readonly property var profiles: ["performance", "balanced", "power-saver"]

    signal requestPage(string name)

    function setProfile(profile) {
        if (root.profiles.indexOf(profile) < 0) return
        root.activeProfile = profile
        Quickshell.execDetached(["powerprofilesctl", "set", profile])
    }

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
        profiles: root.profiles
        onRequestPage: (name) => root.requestPage(name)
        onKeepAwakeToggleRequested: KeepAwake.toggle()
        onBrightnessSetPercent: (percent) => Brightness.setPercent(percent)
        onBrightnessStepRequested: (amount) => Brightness.stepPercent(amount)
        onProfileSelected: (profile) => root.setProfile(profile)
    }

    Component.onCompleted: profileReader.running = true
    Process {
        id: profileReader
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                var profile = (text || "").trim().toLowerCase()
                if (profile.length > 0) root.activeProfile = profile
            }
        }
    }
}
