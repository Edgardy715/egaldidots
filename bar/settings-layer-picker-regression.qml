import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "components"
import "windows"

ShellRoot {
    id: root
    settings.watchFiles: false
    SurfaceRouter { id: navigation; focusedMonitorName: Quickshell.screens[0].name }
    IslandOverlay { id: overlay; router: navigation; modelData: Quickshell.screens[0] }
    Timer { interval: 200; running: true; onTriggered: navigation.present(Quickshell.screens[0].name, "settings") }
        function findPage(item): var {
            if (typeof item.choosePath === "function") return item
            for (const child of item.children || []) { const found = findPage(child); if (found) return found }
            return null
        }
    TestCase {
        id: interaction
        when: false
        function previewImage(path) {
            const page = root.findPage(overlay.contentItem)
            const picker = findChild(page, "edotsPathPicker")
            const model = findChild(picker, "pickerEntries")
            const grid = findChild(picker, "pickerGrid")
            const index = model.indexOf(page.fileUrl(path))
            if (index < 0) return false
            grid.positionViewAtIndex(index, GridView.Center)
            wait(150)
            const entry = grid.itemAtIndex(index)
            if (!entry) return false
            mouseClick(entry, entry.width / 2, entry.height / 2)
            wait(200)
            const preview = findChild(picker, "pickerPreview")
            return preview.status === Image.Ready
        }
    }
    IpcHandler {
        target: "pickerLayerTest"
        function open(key: string): bool {
            const page = root.findPage(overlay.contentItem)
            if (!page) return false
            page.choosePath("paths", key)
            return true
        }
        function preview(path: string): bool { return interaction.previewImage(path) }
        function state(): string {
            return JSON.stringify({picker: overlay.settingsPickerOpen, settings: overlay.settingsOpen,
                focus: overlay.kbFocusWanted})
        }
        function quit(): void { Qt.quit() }
    }
}
