import QtQuick
import Quickshell.Widgets
import "../Singletons"

// Keep the displayed image alive until its replacement has decoded. One fade
// finishes before accepting the latest queued URL, so rapid changes never flash.
ClippingRectangle {
    id: root
    property string source: ""
    readonly property string requestedSource: source ? String(Qt.resolvedUrl(source)) : ""
    property size sourceSize: Qt.size(256, 256)
    property int fillMode: Image.PreserveAspectCrop
    property bool transitionsEnabled: true
    property var transitionSource: null
    property bool motionVisible: visible
    property bool preloadAmbient: false
    property bool reducedMotion: Flags.reduceMotion
    property int duration: Motion.standard
    property int activeSlot: 0
    property bool initialized: false
    property real blend: 0
    readonly property int effectiveSlot: transitionSource ? transitionSource.activeSlot : activeSlot
    readonly property real effectiveBlend: transitionSource ? transitionSource.blend : blend
    readonly property string firstUrl: String(first.source)
    readonly property string secondUrl: String(second.source)
    readonly property var currentImage: effectiveSlot === 0 ? first : second
    readonly property var nextImage: effectiveSlot === 0 ? second : first
    readonly property bool ready: currentImage.status === Image.Ready
    readonly property bool loading: nextImage.status === Image.Loading
    readonly property bool transitioning: transitionSource ? transitionSource.transitioning : fade.running
    readonly property string displayedSource: ready ? String(currentImage.source) : ""
    color: "transparent"

    function clear() {
        fade.stop()
        blend = 0
        first.source = ""
        second.source = ""
    }
    function sync() {
        if (!initialized || transitionSource) return
        if (!source) { clear(); return }
        if (fade.running) return
        if (String(currentImage.source) === requestedSource && ready) {
            nextImage.source = ""
            return
        }
        nextImage.source = requestedSource
        accept(nextImage)
    }
    function accept(image) {
        if (!initialized || transitionSource || image !== nextImage || fade.running
            || String(image.source) !== requestedSource) return
        if (image.status === Image.Error) { clear(); return }
        if (image.status !== Image.Ready) return
        if (preloadAmbient && (ambientDecode.status !== Image.Ready
            || String(ambientDecode.source) !== String(image.source))) return
        if (!ready || !motionVisible || reducedMotion || !transitionsEnabled) {
            commit()
        } else {
            blend = 0
            fade.start()
        }
    }
    function commit() {
        fade.stop()
        activeSlot = 1 - activeSlot
        blend = 0
        nextImage.source = ""
        Qt.callLater(sync)
    }
    function settle() {
        if (fade.running) commit()
        sync()
    }
    onRequestedSourceChanged: sync()
    onMotionVisibleChanged: if (!motionVisible) settle()
    onTransitionSourceChanged: { fade.stop(); if (!transitionSource) sync() }
    onReducedMotionChanged: if (reducedMotion) settle()
    onTransitionsEnabledChanged: if (!transitionsEnabled) settle()
    Component.onCompleted: { initialized = true; sync() }

    Image {
        id: first
        anchors.fill: parent
        sourceSize: root.sourceSize
        fillMode: root.fillMode
        asynchronous: true
        cache: true
        smooth: true
        z: root.effectiveSlot === 0 ? 0 : 1
        opacity: root.effectiveSlot === 0 ? 1 : root.effectiveBlend
        onStatusChanged: root.accept(first)
    }
    Image {
        id: second
        anchors.fill: parent
        sourceSize: root.sourceSize
        fillMode: root.fillMode
        asynchronous: true
        cache: true
        smooth: true
        z: root.effectiveSlot === 1 ? 0 : 1
        opacity: root.effectiveSlot === 1 ? 1 : root.effectiveBlend
        onStatusChanged: root.accept(second)
    }
    // The media panel and its ambient image share a decode barrier and clock.
    Image {
        id: ambientDecode
        visible: false
        asynchronous: true
        sourceSize: Qt.size(256, 256)
        source: root.preloadAmbient ? root.nextImage.source : ""
        onStatusChanged: {
            if (status === Image.Error) root.clear()
            else root.accept(root.nextImage)
        }
    }
    Binding {
        target: first; property: "source"
        when: root.transitionSource !== null
        value: root.transitionSource ? root.transitionSource.firstUrl : ""
    }
    Binding {
        target: second; property: "source"
        when: root.transitionSource !== null
        value: root.transitionSource ? root.transitionSource.secondUrl : ""
    }
    NumberAnimation {
        id: fade
        target: root; property: "blend"; from: 0; to: 1
        duration: root.duration
        easing.type: Motion.easeStandard
        onFinished: root.commit()
    }
}
