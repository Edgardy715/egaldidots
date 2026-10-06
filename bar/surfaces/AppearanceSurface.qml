import QtQuick
import "../components"
import "../Singletons"

AppearanceView {
    id: root
    AppearanceEditor {
        id: editor
        config: Config
        onRequestPage: name => root.requestPage(name)
    }
    draft: editor.draft
    message: editor.message
    savePending: editor.savePending
    configLoaded: Config.loaded
    initialFontFamily: Config.appearance.fontFamily
    onValueEdited: (key, value) => editor.setValue(key, value)
    onSaveRequested: fontFamily => editor.save(fontFamily)
}
