import QtQuick
import "AnimatedIconData.js" as IconData
import "../Singletons"

// Shared icon facade: native animated Lucide paths, font fallback for custom glyphs.
Item {
    id: root

    // Existing Material names select the shared Lucide catalog.
    property string iconName: ""
    // Font fallback compatibility; Lucide strokes remain outline.
    property real fill: 0
    Behavior on fill { enabled: root.ready && root.visible; NumberAnimation { id: fillAnimation; duration: Motion.iconSwap; easing.type: Easing.OutCubic } }

    property bool transport: false
    // A control supplies the gesture; decorative icons remain still.
    property var interaction: null
    property bool compressWithControl: false
    property bool hovered: interaction ? interaction.engaged : false
    property bool pressed: interaction ? interaction.pressed : false
    property bool animateChanges: true
    property bool ready: false
    Component.onCompleted: { displayedIcon = iconName; ready = true }
    property string displayedIcon: ""
    property string outgoingIcon: ""
    property real swapProgress: 1
    readonly property bool reduced: Flags.reduceMotion
    onReducedChanged: if (reduced) swap.complete()
    onVisibleChanged: if (!visible) { swap.complete(); fillAnimation.complete() }
    readonly property real travelX: ["arrow_forward", "arrow_forward_ios", "chevron_right", "skip_next", "logout", "open_in_new"].indexOf(iconName) >= 0 ? Motion.iconTravel
        : ["arrow_back", "arrow_back_ios", "chevron_left", "skip_previous"].indexOf(iconName) >= 0 ? -Motion.iconTravel : 0
    readonly property real travelY: ["expand_more", "keyboard_arrow_down"].indexOf(iconName) >= 0 ? Motion.iconTravel
        : ["expand_less", "keyboard_arrow_up"].indexOf(iconName) >= 0 ? -Motion.iconTravel
        : ["lock", "lock_open", "dark_mode", "power_settings_new"].indexOf(iconName) >= 0 ? -Motion.iconLift : 0
    readonly property real turn: iconName === "settings" ? 12
        : ["refresh", "restart_alt", "sync", "cached"].indexOf(iconName) >= 0 ? 22
        : iconName === "close" ? -8 : iconName === "dark_mode" ? -12
        : iconName === "delete" ? -6 : 0
    readonly property real hoverGain: iconName === "power_settings_new" ? Motion.iconEmphasisStrong
        : ["play_arrow", "pause", "wifi", "wifi_off", "bluetooth", "bluetooth_disabled", "lock", "lock_open", "add", "remove"].indexOf(iconName) >= 0 ? Motion.iconEmphasis : Motion.iconEmphasisSubtle
    property real emphasis: hovered && !Flags.reduceMotion && !pressed ? 1 : 0
    Behavior on emphasis { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.hover; easing.type: Easing.OutCubic } }
    onIconNameChanged: {
        if (!ready || displayedIcon === iconName) return
        outgoingIcon = swapProgress < 0.5 && outgoingIcon.length > 0 ? outgoingIcon : displayedIcon
        displayedIcon = iconName
        swap.restart()
    }
    property font font
    property color color: Theme.foreground
    property int horizontalAlignment: Text.AlignHCenter
    property int verticalAlignment: Text.AlignVCenter
    readonly property bool vectorIcon: IconData.parts(displayedIcon).length > 0
    readonly property bool outgoingVector: IconData.parts(outgoingIcon).length > 0
    implicitWidth: vectorIcon ? font.pixelSize : Math.max(current.implicitWidth, old.implicitWidth)
    implicitHeight: vectorIcon ? font.pixelSize : Math.max(current.implicitHeight, old.implicitHeight)
    transform: [
        Translate { x: root.vectorIcon ? 0 : root.travelX * root.emphasis; y: root.vectorIcon ? 0 : root.travelY * root.emphasis },
        Rotation { origin.x: root.width / 2; origin.y: root.height / 2; angle: root.vectorIcon ? 0 : root.turn * root.emphasis },
        Scale {
            origin.x: root.width / 2; origin.y: root.height / 2
            xScale: (1 + (root.vectorIcon ? 0 : root.hoverGain * root.emphasis)) * (root.compressWithControl && root.interaction ? root.interaction.visualScale : 1)
            yScale: xScale
        }
    ]
    NumberAnimation {
        id: swap
        target: root; property: "swapProgress"
        from: 0; to: 1
        duration: root.animateChanges && root.visible ? Motion.iconSwap : 0
        easing.type: Easing.OutCubic
        onFinished: root.outgoingIcon = ""
    }
    Text {
        id: old
        anchors.fill: parent
        visible: !root.outgoingVector
        text: root.outgoingIcon
        font: root.font; color: root.color
        horizontalAlignment: root.horizontalAlignment; verticalAlignment: root.verticalAlignment
        opacity: 1 - root.swapProgress
        scale: 1 - 0.12 * root.swapProgress
        transform: Translate { y: -Motion.iconTravel * root.swapProgress }
        Accessible.ignored: true
    }
    Text {
        id: current
        anchors.fill: parent
        visible: !root.vectorIcon
        text: root.displayedIcon
        font: root.font; color: root.color
        horizontalAlignment: root.horizontalAlignment; verticalAlignment: root.verticalAlignment
        opacity: root.swapProgress
        scale: 0.88 + 0.12 * root.swapProgress
        transform: Translate { y: Motion.iconTravel * (1 - root.swapProgress) }
        Accessible.ignored: true
    }
    AnimatedSymbol {
        id: vector
        objectName: "animatedSymbol"
        anchors.centerIn: parent
        width: root.font.pixelSize; height: width
        iconName: root.displayedIcon
        color: root.color
        visible: root.vectorIcon
        hovered: root.hovered
        pressed: root.pressed
        reveal: root.swapProgress
    }
    AnimatedSymbol {
        anchors.centerIn: parent
        width: root.font.pixelSize; height: width
        iconName: root.outgoingIcon
        color: root.color
        visible: root.outgoingVector && root.swapProgress < 1
        opacity: 1 - root.swapProgress
    }
    font.pixelSize: Theme.fontSizeBodyLg
    font.family: "Material Symbols Rounded"
    font.weight: Font.Normal
    font.letterSpacing: 0
    // axes variables (Qt 6.4+): ROND (0-100) + FILL (0-1) + GRAD. opsz NO se
    // fija aquí (loop con pixelSize); la fuente usa opsz auto del render.
    font.variableAxes: ({
        "ROND": 55,
        "FILL": root.fill,
        "GRAD": 0
    })
}
