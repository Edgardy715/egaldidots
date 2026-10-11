import QtQuick
import "../"
import "../settings"

PillSurface {
    id: root

    readonly property bool pathPickerOpen: editor.pathPickerOpen
    property int profileRequest: 0
    onProfileRequestChanged: { if (profileRequest > 0) editor.showProfile() }
    Component.onCompleted: { if (profileRequest > 0) editor.showProfile() }

    function activate() { editor.activate() }

    EdotsWindow {
        id: editor
        anchors.fill: parent
        contentReady: root.active && root.morphCloseness > 0.9
        onRequestClose: root.requestClose()
    }
}
