import QtQuick
import "../"
import "../Singletons"
import "../components"

PillSurface {
    id: root
    mTop: Theme.marginMd + 78
    mLeft: Theme.marginMd; mRight: Theme.marginMd; mBottom: 20
    property alias query: view.query
    readonly property var searchResults: controller.searchResults
    readonly property int resultsCount: view.resultsCount
    readonly property bool searching: controller.searching
    readonly property bool resultsVisible: view.resultsVisible
    readonly property bool emptyResultsVisible: view.emptyResultsVisible
    readonly property int maxVisibleResults: view.maxVisibleResults
    readonly property var calcResult: controller.calcResult
    readonly property bool showCalculator: controller.showCalculator

    LauncherController {
        id: controller
        open: root.open
        closing: root.closing
        query: view.query
    }
    // Origen del icono elegido en coordenadas de la ventana de la isla (null si no hay).
    property var launchHint: null
    LauncherView {
        id: view
        objectName: "launcherView"
        anchors.fill: parent
        s: root.s
        open: root.open
        closing: root.closing
        searchResults: controller.searchResults
        calcResult: controller.calcResult
        showCalculator: controller.showCalculator
        searching: controller.searching
        onRequestClose: root.requestClose()
        onLaunchOrigin: (x, y, size) => {
            const p = view.mapToItem(null, x, y)
            root.launchHint = { x: p.x, y: p.y, size: size }
        }
        // El comando se lanza primero y sin esperas; el vuelo sólo lo anuncia.
        onLaunchRequested: app => {
            controller.launch(app)
            Apps.announceLaunch(app, root.launchHint)
            root.launchHint = null
            root.approved()
        }
        onCopyResultRequested: value => controller.copyResult(value)
    }
}
