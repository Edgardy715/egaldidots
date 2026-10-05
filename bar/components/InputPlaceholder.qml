import QtQuick
import "../Singletons"

// One font rasterization: moving the hint never changes text metrics or layout.
Text {
    id: root
    required property var input
    property bool floating: false
    property bool motionActive: true
    readonly property bool raised: floating && (input.activeFocus || input.length > 0 || input.inputMethodComposing)
    readonly property bool shown: text.length > 0
        && (floating || (input.length === 0 && input.preeditText.length === 0))
    objectName: "inputPlaceholder"
    text: input.placeholderText
    color: Theme.iconSecondary
    font: input.font
    width: Math.max(0, input.width - input.leftPadding - input.rightPadding)
    x: input.leftPadding
    y: raised ? 3 : input.topPadding + (input.height - input.topPadding - input.bottomPadding - implicitHeight) / 2
    scale: raised ? 0.72 : 1
    transformOrigin: Item.TopLeft
    visible: shown
    elide: Text.ElideRight
    Accessible.ignored: true
    Behavior on y {
        enabled: root.motionActive && input.visible && !Flags.reduceMotion
        SmoothedAnimation { id: labelTravel; duration: Motion.standardSmall; velocity: -1 }
    }
    Behavior on scale {
        enabled: root.motionActive && input.visible && !Flags.reduceMotion
        SmoothedAnimation { id: labelScale; duration: Motion.standardSmall; velocity: -1 }
    }
    // Hide immediately on input, return softly when cleared. No overlap with text.
    function settleHint() { reveal.stop(); opacity = 1; labelTravel.complete(); labelScale.complete() }
    onShownChanged: {
        settleHint()
        if (shown && motionActive && input.visible && !Flags.reduceMotion) reveal.start()
    }
    onMotionActiveChanged: if (!motionActive) settleHint()
    Connections {
        target: root.input
        function onVisibleChanged() { if (!root.input.visible) root.settleHint() }
    }
    Connections {
        target: Flags
        function onReduceMotionChanged() { if (Flags.reduceMotion) root.settleHint() }
    }
    NumberAnimation {
        id: reveal
        target: root; property: "opacity"; from: 0; to: 1
        duration: Motion.fast; easing.type: Motion.easeStandard
    }
}
