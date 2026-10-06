import QtQuick

// Draft and asynchronous save state; the caller injects Config or a test double.
Item {
    id: root
    required property var config
    signal requestPage(string name)
    property var draft: ({})
    property string message: ""
    property bool savePending: false
    Component.onCompleted: draft = JSON.parse(JSON.stringify(root.config.appearance))

    function setValue(key, value) {
        const next = Object.assign({}, draft)
        next[key] = typeof value === "number" ? Math.round(value * 100) / 100 : value
        draft = next
    }

    function save(fontFamily) {
        if (savePending) return
        const next = Object.assign({}, draft, { fontFamily: fontFamily.trim() })
        const result = root.config.update({ appearance: next })
        if (!result.ok) {
            message = result.errors.join(" · ")
            return
        }
        if (!root.config.save()) {
            message = root.config.error || qsTr("No se pudieron guardar los ajustes")
            return
        }
        savePending = root.config.saving
        if (!savePending) requestPage("utils")
    }

    Connections {
        target: root.config
        function onSavingChanged() {
            if (!root.savePending || root.config.saving) return
            root.savePending = false
            if (!root.config.error && !root.config.dirty) root.requestPage("utils")
            else root.message = root.config.error || qsTr("No se pudieron guardar los ajustes")
        }
    }

}
