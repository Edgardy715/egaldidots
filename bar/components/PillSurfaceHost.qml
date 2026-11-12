import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../Singletons"

/** Aloja una surface dentro del vidrio y conserva su ciclo de vida. */
ClippingRectangle {
    id: root

    required property bool open
    required property string surface
    required property real scaleFactor
    required property real morphCloseness
    required property real morphRadius
    required property real surfaceRadius
    required property string screenName
    required property color bgColor
    property bool capsLockOn: false
    property real authContextWidth: 170 * scaleFactor
    property bool closing: false
    property bool gestureDriven: false
    property bool suspended: false
    property real reveal: 1
    // Fase 2 del cierre del launcher: la surface se retira (fundido, escala, desenfoque).
    property bool returning: false
    property bool largeSurface: false
    property var artworkTransition: null
    property string displayedSurface: ""
    property real swapOpacity: 1
    property real loadReveal: 0
    property real returnFade: returning ? 0 : 1
    Behavior on returnFade {
        enabled: !Flags.reduceMotion
        NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
    }
    // p: cuánto está presente el contenido entrante; q: cuánto el saliente (swap A->B).
    // The layout stays at its destination; expose it only once both axes have room.
    readonly property real gestureExposure: gestureDriven ? Math.max(0, Math.min(1,
        (Math.min(morphCloseness, width / Math.max(1, layoutWidth), height / Math.max(1, layoutHeight)) - 0.6) / 0.35)) : 1
    readonly property real matP: (gestureDriven ? gestureExposure : Math.max(0, Math.min(1, root.morphCloseness))) * root.loadReveal * root.returnFade
    readonly property real matQ: root.swapOpacity
    readonly property real contentScale: surfaceLoader.scale
    readonly property bool contentLayerActive: surfaceLoader.layer.enabled
    readonly property bool materializing: !Flags.reduceMotion && (matP < 0.999 || matQ < 0.999)

    // Layout hold: content is laid out once, at the size the glass is heading to, and the
    // glass reveals or clips it. Growing never reflows (the target is already the final size);
    // closing and swapping keep the last open layout. Shrinking while open (launcher results,
    // launcher close phases) still follows the glass, as designed. 0 = fill the glass.
    property real layoutTargetWidth: 0
    property real layoutTargetHeight: 0
    readonly property bool layoutTracking: open && displayedSurface === surface
    // A target below the glass is a shrink: follow the glass down until it arrives. The
    // spring's overshoot past a target never reflows the content (a full relayout per frame).
    property bool followGlassW: false
    property bool followGlassH: false
    onLayoutTargetWidthChanged: followGlassW = layoutTargetWidth > 0 && width > layoutTargetWidth + 0.5
    onLayoutTargetHeightChanged: followGlassH = layoutTargetHeight > 0 && height > layoutTargetHeight + 0.5
    onWidthChanged: if (followGlassW && width <= layoutTargetWidth + 0.5) followGlassW = false
    onHeightChanged: if (followGlassH && height <= layoutTargetHeight + 0.5) followGlassH = false
    readonly property real liveLayoutWidth: layoutTargetWidth <= 0 || !gestureDriven && followGlassW ? width : layoutTargetWidth
    readonly property real liveLayoutHeight: layoutTargetHeight <= 0 || !gestureDriven && followGlassH ? height : layoutTargetHeight
    property real heldLayoutWidth: 0
    property real heldLayoutHeight: 0
    onLiveLayoutWidthChanged: if (layoutTracking) heldLayoutWidth = liveLayoutWidth
    onLiveLayoutHeightChanged: if (layoutTracking) heldLayoutHeight = liveLayoutHeight
    onLayoutTrackingChanged: if (layoutTracking) {
        heldLayoutWidth = liveLayoutWidth
        heldLayoutHeight = liveLayoutHeight
    }
    readonly property real layoutWidth: layoutTracking || heldLayoutWidth <= 0 ? liveLayoutWidth : heldLayoutWidth
    readonly property real layoutHeight: layoutTracking || heldLayoutHeight <= 0 ? liveLayoutHeight : heldLayoutHeight

    signal requestClose()
    signal requestPage(string name)
    signal feedbackRequested(string kind)

    readonly property var loadedItem: surfaceLoader.status === Loader.Ready
        ? surfaceLoader.item : null

    anchors.fill: parent
    radius: root.surfaceRadius
    color: "transparent"
    enabled: root.open && !root.suspended
    opacity: root.suspended ? 0 : root.reveal * root.returnFade * root.swapOpacity * root.loadReveal * root.gestureExposure

    Behavior on loadReveal {
        enabled: !root.gestureDriven && surfaceLoader.status === Loader.Ready && !Flags.reduceMotion
        NumberAnimation { id: loadAnimation; duration: Motion.standardSmall; easing.type: Motion.easeStandard }
    }

    Behavior on swapOpacity {
        NumberAnimation {
            id: swapAnimation
            duration: Flags.reduceMotion ? 0 : Motion.crossfadeOut
            easing.type: Easing.InOutQuad

        }
    }

    Timer {
        id: swapTimer
        interval: Flags.reduceMotion ? 0 : Motion.crossfadeOut
        onTriggered: {
            if (root.surface.length > 0) root.displayedSurface = root.surface
            root.swapOpacity = 1
        }
    }

    onSurfaceChanged: {
        if (surface.length > 0 && displayedSurface.length > 0 && surface !== displayedSurface) {
            swapOpacity = 0
            if (Flags.reduceMotion) {
                displayedSurface = surface
                swapOpacity = 1
            } else if (!swapTimer.running) swapTimer.start()
        } else {
            // Cerrar con un swap pendiente: el contenido saliente ya se retiraba;
            // restaurarlo haría reaparecer la surface anterior mientras la pill
            // se contrae. Se conserva retirado hasta descargar o reabrir.
            const withdrawn = surface.length === 0 && swapTimer.running
            swapTimer.stop()
            if (!withdrawn) swapOpacity = 1
            if (surface.length > 0) displayedSurface = surface
            else if (morphCloseness <= 0.01) displayedSurface = ""
        }
    }
    onMorphClosenessChanged: {
        // Unload after geometry evaluation; loader teardown changes target height.
        if (!open && morphCloseness <= 0.01) Qt.callLater(() => {
            if (!root.open && root.morphCloseness <= 0.01) {
                root.displayedSurface = ""
                root.swapOpacity = 1
            }
        })
    }

    Connections {
        target: Flags
        function onReduceMotionChanged() {
            if (!Flags.reduceMotion) return
            swapTimer.stop()
            if (root.surface.length) root.displayedSurface = root.surface
            root.swapOpacity = 1
            root.loadReveal = surfaceLoader.status === Loader.Ready ? 1 : 0
            loadAnimation.complete()
            swapAnimation.complete()
        }
    }

    Loader {
        id: surfaceLoader
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.layoutWidth
        height: root.layoutHeight
        asynchronous: true
        transformOrigin: Item.Top
        scale: Flags.reduceMotion ? 1
            : (Motion.materializeScale + (1 - Motion.materializeScale) * root.matP)
              * (Motion.materializeRetireScale + (1 - Motion.materializeRetireScale) * root.matQ)
        transform: Translate {
            y: Flags.reduceMotion ? 0 : Motion.materializeTravel * root.scaleFactor * (1 - root.matP)
        }
        // La capa (y su desenfoque) sólo existe mientras el contenido se materializa o se retira.
        layer.enabled: root.materializing && surfaceLoader.status === Loader.Ready
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: root.largeSurface ? Motion.materializeBlurMaxLarge : Motion.materializeBlurMax
            blur: Math.min(1, (1 - root.matP) * Motion.materializeBlur + (1 - root.matQ) * Motion.materializeBlur)
        }
        active: root.displayedSurface.length > 0
        // La URL depende del nombre, no del orden de actualización de `open`.
        source: root.displayedSurface.length > 0
            ? Qt.resolvedUrl("../surfaces/" + root.displayedSurface.charAt(0).toUpperCase()
                             + root.displayedSurface.slice(1) + "Surface.qml")
            : ""

        onLoaded: {
            root.loadReveal = 1
            if ("artworkTransition" in item) item.artworkTransition = Qt.binding(() => root.artworkTransition)
            if ("contextWidth" in item) item.contextWidth = Qt.binding(() => root.authContextWidth)
            if ("capsLockOn" in item) item.capsLockOn = Qt.binding(() => root.capsLockOn)
            item.s = Qt.binding(() => root.scaleFactor)
            item.open = Qt.binding(() => root.displayedSurface.length > 0)
            item.closing = Qt.binding(() => root.closing || !root.open)
            item.morphCloseness = Qt.binding(() => root.morphCloseness)
            item.morphRadius = Qt.binding(() => root.morphRadius)
            item.screenName = Qt.binding(() => root.screenName)
            item.bgColor = Qt.binding(() => root.bgColor)
        }

        onStatusChanged: {
            if (status !== Loader.Ready) root.loadReveal = 0
            if (status === Loader.Error) {
                const failedSource = source
                // No mutar el estado del shell durante la evaluación del binding
                // que acaba de cambiar la URL. Comprobar también que sigue vigente.
                Qt.callLater(() => {
                    if (surfaceLoader.status !== Loader.Error
                            || surfaceLoader.source !== failedSource
                            || !root.open || !root.surface.length) return
                    console.warn("[PillSurfaceHost] failed to load '" + root.surface + "'")
                    root.requestClose()
                })
            }
        }
    }

    // La conexión acompaña al Loader: al cambiar o destruir una surface, Qt
    // desconecta el target anterior y conecta la siguiente sin estado manual.
    Connections {
        target: root.loadedItem
        ignoreUnknownSignals: true
        function onRequestClose() { root.requestClose() }
        function onRequestPage(name) { root.requestPage(name) }
        function onFeedbackRequested(kind) { if (root.open && !root.suspended) root.feedbackRequested(kind) }
    }
}
