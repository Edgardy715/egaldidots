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
    readonly property bool resultsVisible: view.resultsVisible
    readonly property int maxVisibleResults: view.maxVisibleResults
    readonly property var calcResult: controller.calcResult
    readonly property bool showCalculator: controller.showCalculator

    LauncherController {
        id: controller
        open: root.open
        closing: root.closing
        query: view.query
    }
    LauncherView {
        id: view
        anchors.fill: parent
        s: root.s
        open: root.open
        closing: root.closing
        searchResults: controller.searchResults
        calcResult: controller.calcResult
        showCalculator: controller.showCalculator
        onRequestClose: root.requestClose()
        onLaunchRequested: app => controller.launch(app)
        onCopyResultRequested: value => controller.copyResult(value)
    }
}
