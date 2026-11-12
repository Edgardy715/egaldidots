import QtQuick
import Quickshell

Item {
    id: root
    width: 640; height: 240
    Loader {
        id: integration
        source: "file://" + Quickshell.env("ISLA_TEST_COMPONENT")
        anchors.fill: parent
        onStatusChanged: console.log("LOADER", status, source.toString())
    }
    property var fishItem: integration.item
    Timer {
        interval: 1000; running: true
        onTriggered: {
            if (!root.fishItem) { console.log("FAIL no component"); Qt.exit(2); return }
            if (Quickshell.env("ISLA_FISH_TEST_MODE") === "remove") root.fishItem.removeActionButton.clicked()
            else root.fishItem.installActionButton.clicked()
            verify.start()
        }
    }
    Timer { id: verify; interval: 500; onTriggered: { if (root.fishItem.busy) { interval = 100; restart(); return }; console.log("FISH_ACTION_DONE"); Qt.exit(root.fishItem.message.length ? 2 : 0) } }
    Timer { interval: 8000; running: true; onTriggered: { console.log("FAIL fixture timeout"); Qt.exit(3) } }
}
