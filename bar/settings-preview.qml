import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"
import "settings"
ShellRoot {
    FloatingWindow { id: preview; title: "Edots · Preview"; implicitWidth: 1000; implicitHeight: 700; color: Theme.background
        EdotsWindow { id: window; anchors.fill: parent; onRequestClose: preview.visible = false }
    }
    IpcHandler {
        target: "edotsTest"
        function page(index: int): void { window.page = Math.max(0, Math.min(5, index)) }
        function size(w: int, h: int): void { preview.implicitWidth = w; preview.implicitHeight = h }
        function scene(index: int): void { window.previewScene = index }
        function search(text: string): void { window.searchQuery = text }
        function font(): string {
            function find(item) {
                if (item.objectName === "fontPicker" && item.visible) return item
                for (const child of item.children || []) { const found = find(child); if (found) return found }
                return null
            }
            const control = find(window)
            if (!control) return "missing"
            for (let item = control.parent; item; item = item.parent) {
                if (item.contentY !== undefined && item.contentItem) {
                    const bottom = control.mapToItem(item.contentItem, 0, control.height).y
                    item.contentY = Math.max(0, Math.min(item.contentHeight - item.height, bottom - item.height + 12))
                    break
                }
            }
            control.popup.open()
            return JSON.stringify({height: control.popup.height, count: control.count, value: control.editText})
        }
        function browse(key: string): bool {
            function find(item) {
                if (String(item).startsWith("SettingsPage_")) return item
                for (const child of item.children || []) { const found = find(child); if (found) return found }
                return null
            }
            const page = find(window)
            if (!page) return false
            page.choosePath("paths", key)
            return true
        }
        function state(): string { return JSON.stringify({page: window.page, entries: window.resultCount, error: window.validationError}) }
    }
}
