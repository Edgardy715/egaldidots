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
    property bool closing: false
    property bool suspended: false
    property real reveal: 1

    signal requestClose()

    readonly property var loadedItem: surfaceLoader.status === Loader.Ready
        ? surfaceLoader.item : null

    anchors.fill: parent
    radius: root.surfaceRadius
    color: "transparent"
    enabled: root.open && !root.suspended
    opacity: root.open && !root.suspended ? root.reveal : 0

    Behavior on opacity {
        enabled: !root.suspended
        NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
    }

    Loader {
        id: surfaceLoader
        anchors.fill: parent
        active: root.open && root.surface.length > 0
        // La URL depende del nombre, no del orden de actualización de `open`.
        source: root.surface.length > 0
            ? Qt.resolvedUrl("../surfaces/" + root.surface.charAt(0).toUpperCase()
                             + root.surface.slice(1) + "Surface.qml")
            : ""

        onLoaded: {
            item.s = Qt.binding(() => root.scaleFactor)
            item.open = Qt.binding(() => root.open)
            item.closing = Qt.binding(() => root.closing)
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
