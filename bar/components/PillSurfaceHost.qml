import QtQuick
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
    property bool suspended: false
    property real reveal: 1
    property string displayedSurface: ""
    property real swapOpacity: 1

    signal requestClose()

    readonly property var loadedItem: surfaceLoader.status === Loader.Ready
        ? surfaceLoader.item : null

    anchors.fill: parent
    radius: root.surfaceRadius
    color: "transparent"
    enabled: root.open && !root.suspended
    opacity: root.suspended ? 0 : root.reveal * root.swapOpacity

    Behavior on swapOpacity {
        NumberAnimation {
            duration: Flags.reduceMotion ? 0 : Motion.fast
            easing.type: Easing.InOutQuad

        }
    }

    Timer {
        id: swapTimer
        interval: Flags.reduceMotion ? 0 : Motion.fast
        onTriggered: {
            if (root.surface.length > 0) root.displayedSurface = root.surface
            root.swapOpacity = 1
        }
    }

    onSurfaceChanged: {
        if (surface.length > 0 && displayedSurface.length > 0 && surface !== displayedSurface) {
            swapOpacity = 0
            swapTimer.restart()
        } else {
            swapTimer.stop()
            swapOpacity = 1
            if (surface.length > 0) displayedSurface = surface
            else if (morphCloseness <= 0.01) displayedSurface = ""
        }
    }
    onMorphClosenessChanged: {
        if (!open && morphCloseness <= 0.01) displayedSurface = ""
    }

    Loader {
        id: surfaceLoader
        anchors.fill: parent
        active: root.displayedSurface.length > 0
        // La URL depende del nombre, no del orden de actualización de `open`.
        source: root.displayedSurface.length > 0
            ? Qt.resolvedUrl("../surfaces/" + root.displayedSurface.charAt(0).toUpperCase()
                             + root.displayedSurface.slice(1) + "Surface.qml")
            : ""

        onLoaded: {
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

        onStatusChanged: if (status === Loader.Error) {
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

    // La conexión acompaña al Loader: al cambiar o destruir una surface, Qt
    // desconecta el target anterior y conecta la siguiente sin estado manual.
    Connections {
        target: root.loadedItem
        ignoreUnknownSignals: true
        function onRequestClose() { root.requestClose() }
    }
}
