import QtQuick
import "../components"

// Composition keeps desktop observation and commands outside the grid.
WorkspacesView {
    id: root
    WorkspaceModel {
        id: desktop
        screenName: root.screenName
        minimumCount: root.count
    }
    activeId: desktop.activeId
    workspaceData: desktop.occupied
    onWorkspaceRequested: id => desktop.activate(id)
}
