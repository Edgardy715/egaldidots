import QtQuick
import "../Singletons"

// Discrete metadata keeps its box and glyph shape while the latest value fades in.
Item {
    id: root
    property string value: ""
    property string displayed: ""
    property string previous: ""
    property real reveal: 1
    property bool initialized: false
    property bool animated: true
    property int reservedLines: 0
    property alias font: incoming.font
    property alias color: incoming.color
    property alias elide: incoming.elide
    property alias textFormat: incoming.textFormat
    property alias horizontalAlignment: incoming.horizontalAlignment
    property alias verticalAlignment: incoming.verticalAlignment
    property alias wrapMode: incoming.wrapMode
    property alias maximumLineCount: incoming.maximumLineCount
    property alias lineHeight: incoming.lineHeight
    readonly property string text: displayed
    implicitWidth: incoming.implicitWidth
    implicitHeight: reservedLines > 0
        ? Math.ceil(Math.ceil(Math.max(metrics.height, metrics.lineSpacing)) * incoming.lineHeight * reservedLines)
        : incoming.implicitHeight
    clip: true
    FontMetrics { id: metrics; font: incoming.font }

    function settle() {
        swap.stop()
        displayed = value
        previous = ""
        reveal = 1
    }
    function sync() {
        if (!initialized) return
        if (!visible || !animated || Flags.reduceMotion) { settle(); return }
        if (swap.running || value === displayed) return
        previous = displayed
        displayed = value
        reveal = 0
        swap.start()
    }
    onValueChanged: sync()
    onAnimatedChanged: if (!animated) settle()
    onVisibleChanged: if (!visible) settle()
    Component.onCompleted: { initialized = true; settle() }
    Connections {
        target: Flags
        function onReduceMotionChanged() { if (Flags.reduceMotion) root.settle() }
    }
    Text {
        anchors.fill: parent
        text: root.previous
        font: incoming.font
        color: incoming.color
        elide: incoming.elide
        textFormat: incoming.textFormat
        horizontalAlignment: incoming.horizontalAlignment
        verticalAlignment: incoming.verticalAlignment
        wrapMode: incoming.wrapMode
        maximumLineCount: incoming.maximumLineCount
        lineHeight: incoming.lineHeight
        opacity: 1 - root.reveal
        visible: opacity > 0
        Accessible.ignored: true
    }
    Text {
        id: incoming
        objectName: "crossfadeText"
        anchors.fill: parent
        text: root.displayed
        opacity: root.reveal
    }
    NumberAnimation {
        id: swap
        target: root; property: "reveal"; from: 0; to: 1
        duration: Motion.standardSmall
        easing.type: Motion.easeStandard
        onFinished: { root.previous = ""; root.sync() }
    }
}
