import QtQuick

// Services are supplied by composition; this policy owns only a finite reaction.
QtObject {
    id: root
    property bool active: false
    property bool systemEnabled: true
    property bool focusEnabled: true
    property bool nightEnabled: true
    property bool focused: false
    property bool idle: false
    property real hour: 12
    property string reaction: ""
    readonly property string mood: reaction || (idle || (nightEnabled && (hour >= 23 || hour < 6))
        ? "dormida" : focusEnabled && focused ? "timida" : "curiosa")
    function react(kind) {
        if (!active || !systemEnabled) return
        reaction = kind === "attention" || kind === "error" ? "curiosa" : "contenta"
        hold.restart()
    }
    onActiveChanged: if (!active) { hold.stop(); reaction = "" }
    onSystemEnabledChanged: if (!systemEnabled) { hold.stop(); reaction = "" }
    readonly property Timer hold: Timer {
        interval: 1600
        onTriggered: root.reaction = ""
    }
}
