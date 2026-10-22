import QtQuick
import "../Singletons"
import QtQuick.Controls.Basic
import "../components"
import "ModuleSelection.js" as ModuleSelection

Item {
    id: root
    required property var config
    property Item popupBounds: null
    property string section: "appearance"
    property string query: ""
    property var fieldKeys: []
    property var fieldSelection: ({ section: root.section, keys: root.fieldKeys, active: true })
    property bool showUnavailable: false
    property var drafts: ({})
    property var draftBases: ({})
    property var rowErrors: ({})
    readonly property bool hasDrafts: Object.keys(drafts).length > 0
    readonly property var conflicts: {
        const result = {}
        for (const id of Object.keys(drafts)) {
            const dot = id.indexOf(".")
            const sectionName = id.slice(0, dot)
            const key = id.slice(dot + 1)
            const current = effective[sectionName][key]
            if (current !== draftBases[id] && String(current) !== drafts[id])
                result[id] = qsTr("%1 cambió fuera de Edots. Edita el borrador, restablécelo o descártalo.").arg(config.schema.sections[sectionName][key].label)
        }
        return result
    }
    readonly property string validationError: Object.values(rowErrors).filter(Boolean).concat(Object.values(conflicts)).join(" · ")
    signal edited()
    property string pickerSection: ""
    property string pickerKey: ""
    readonly property bool pickerOpen: pathPicker.visible

    function fileUrl(path) {
        return "file://" + path.split("/").map(part => encodeURIComponent(part)).join("/")
    }

    function choosePath(sectionName, key) {
        if (!config.loaded || config.saving) return
        pickerSection = sectionName
        pickerKey = key
        const field = config.schema.sections[sectionName][key]
        const path = effective[sectionName][key]
        pathPicker.start(qsTr("Seleccionar %1").arg(field.label), path, field.picker === "folder",
            key === "userAvatar" ? "image" : key === "paletteFile" ? "json" : "all")
    }

    function acceptPath(url) {
        const text = String(url)
        if (!text.startsWith("file:///")) return false
        return updateField(pickerSection, pickerKey, decodeURIComponent(text.slice(7)))
    }

    EdotsPathPicker {
        id: pathPicker
        onPathChosen: value => root.acceptPath(value)
    }
    function closePicker() { pathPicker.close() }
    onVisibleChanged: if (!visible) closePicker()


    onFieldSelectionChanged: resetScroll()
    onQueryChanged: resetScroll()

    function resetScroll() {
        if (scroll && scroll.contentItem) scroll.contentItem.contentY = 0
    }

    readonly property var effective: {
        // Explicit dependencies keep snapshot() reactive after update/discard/reload.
        const appearance = config.appearance
        const modules = config.modules
        const profile = config.profile
        const paths = [config.userAvatar, config.paletteFile, config.wallpaperDir,
                       config.wallpaperCacheDir, config.wallpaperApplyScript]
        return config.snapshot().effective
    }
    readonly property var entries: {
        const selection = fieldSelection
        if (!selection.active) return []
        const fieldKeys = selection.keys
        const terms = normalize(query).trim().split(/\s+/).filter(Boolean)
        const sections = config.schema.sections
        const names = terms.length || fieldKeys.length ? Object.keys(sections) : [selection.section]
        const result = []
        for (const name of names) {
            const fields = sections[name] || {}
            for (const key of Object.keys(fields)) {
                const field = fields[key]
                const id = name + "." + key
                if (terms.length) {
                    const haystack = normalize(field.label + " " + field.description + " " + (field.optionLabels || []).join(" ") + " " + key + " " + name)
                    if (!terms.every(term => haystack.includes(term))) continue
                } else {
                    if (fieldKeys.length && fieldKeys.indexOf(id) === -1) continue
                    if (!showUnavailable && (field.availability === "inactive" || field.availability === "partial")) continue
                }
                result.push({ section: name, key: key, field: field })
            }
        }
        return result
    }

    function normalize(text) {
        return String(text).normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLocaleLowerCase()
    }

    function setError(id, message) {
        rowErrors = Object.assign({}, rowErrors, { [id]: message })
    }

    function setDraft(sectionName, key, text) {
        const id = sectionName + "." + key
        const next = Object.assign({}, drafts)
        const bases = Object.assign({}, draftBases)
        const current = effective[sectionName][key]
        const conflicted = !!conflicts[id]
        if (text === String(effective[sectionName][key])) {
            delete next[id]
            delete bases[id]
        } else {
            next[id] = text
            if (!Object.prototype.hasOwnProperty.call(bases, id) || conflicted) bases[id] = current
        }
        draftBases = bases
        drafts = next
        setError(id, "")
    }

    function finishField(sectionName, key) {
        const id = sectionName + "." + key
        const next = Object.assign({}, drafts)
        delete next[id]
        drafts = next
        const bases = Object.assign({}, draftBases)
        delete bases[id]
        draftBases = bases
        setError(id, "")
    }

    function clearValidation() {
        drafts = ({})
        draftBases = ({})
        rowErrors = ({})
    }

    function focusFirstError() {
        const id = Object.keys(conflicts).concat(Object.keys(rowErrors).filter(key => rowErrors[key]))[0]
        if (!id) return
        const entry = entries.findIndex(item => item.section + "." + item.key === id)
        if (entry < 0) { errorFieldRequested(id); return }
        const wrapper = rows.itemAt(entry)
        if (!wrapper) return
        scroll.contentItem.contentY = Math.max(0, Math.min(scroll.contentItem.contentHeight - scroll.height, wrapper.y))
        wrapper.focusEditor()
        const bottom = wrapper.mapToItem(scroll.contentItem, 0, wrapper.height).y
        scroll.contentItem.contentY = Math.max(0, Math.min(scroll.contentItem.contentHeight - scroll.height, scroll.contentItem.contentY + bottom - scroll.height + 12))
    }
    signal errorFieldRequested(string id)

    function commitDrafts() {
        if (Object.keys(conflicts).length) return false
        const ids = Object.keys(drafts)
        if (!ids.length) return !validationError
        const patch = {}
        let invalid = false
        for (const id of ids) {
            const dot = id.indexOf(".")
            const sectionName = id.slice(0, dot)
            const key = id.slice(dot + 1)
            const field = config.schema.sections[sectionName][key]
            const text = drafts[id].trim()
            if (field.type === "number" && (text === "" || !isFinite(Number(text)))) {
                setError(id, qsTr("%1: introduce un número válido.").arg(field.label))
                invalid = true
                continue
            }
            if (field.type === "string" && field.path
                    && !text.startsWith("/") && text !== "~" && !text.startsWith("~/")) {
                setError(id, qsTr("%1: usa una ruta absoluta o que empiece por ~/.").arg(field.label))
                invalid = true
                continue
            }
            if (field.type === "string" && (text.length < (field.minLength === undefined ? 1 : field.minLength) || text.includes("\u0000"))) {
                setError(id, qsTr("%1: introduce un texto válido.").arg(field.label))
                invalid = true
                continue
            }
            if (!patch[sectionName]) patch[sectionName] = {}
            patch[sectionName][key] = field.type === "number" ? Number(text) : text
        }
        if (invalid) return false
        const result = config.update(patch)
        if (!result.ok) {
            const message = result.errors.join(" · ")
            for (const id of ids) {
                if (result.errors.some(error => error.indexOf(id + " ") === 0)) setError(id, message)
            }
            if (!validationError) setError(ids[0], message)
            return false
        }
        clearValidation()
        edited()
        return true
    }

    function updateField(sectionName, key, value) {
        if (conflicts[sectionName + "." + key]) return false
        const patch = sectionName === "modules" ? ModuleSelection.patch(key, value) : { [sectionName]: { [key]: value } }
        const result = config.update(patch)
        if (result.ok) {
            finishField(sectionName, key)
            edited()
        } else setError(sectionName + "." + key, result.errors.join(" · "))
        return result.ok
    }

    function resetField(sectionName, key) {
        if (!config.loaded || config.saving) return false
        const fallback = config.schema.sections[sectionName][key].default
        if (conflicts[sectionName + "." + key]) finishField(sectionName, key)
        if (effective[sectionName][key] !== fallback) return updateField(sectionName, key, fallback)
        finishField(sectionName, key)
        return true
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: 14
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Column {
            width: root.width
            spacing: 0

            Repeater {
                id: rows
                model: root.entries
                StaggerItem {
                    id: rowEntry
                    required property var modelData
                    required property int index
                    width: root.width
                    function focusEditor() { return settingRow.focusEditor() }
                    staggerIndex: index
                    entered: root.visible
                    SettingRow {
                    id: settingRow
                    width: parent.width
                    readonly property var modelData: rowEntry.modelData
                    popupBounds: root.popupBounds
                    sectionLabel: root.query.trim() ? root.config.catalog.sectionOrder.find(item => item.id === modelData.section).label : ""
                    fieldKey: modelData.key
                    field: modelData.field
                    value: root.effective[modelData.section] ? root.effective[modelData.section][fieldKey] : undefined
                    draftText: root.drafts[modelData.section + "." + fieldKey]
                    validationMessage: root.conflicts[modelData.section + "." + fieldKey] || root.rowErrors[modelData.section + "." + fieldKey] || ""
                    reducedMotion: root.config.appearance.reduceMotion
                    editorEnabled: root.config.loaded && !root.config.saving
                    onBrowseRequested: root.choosePath(modelData.section, fieldKey)
                    onResetRequested: root.resetField(modelData.section, fieldKey)
                    onChangeRequested: value => root.updateField(modelData.section, fieldKey, value)
                    onDraftChanged: text => root.setDraft(modelData.section, fieldKey, text)
                    onAccepted: root.finishField(modelData.section, fieldKey)
                    onValidationFailed: message => root.setError(modelData.section + "." + fieldKey, message)
                    }
                }
            }

            Text {
                visible: root.entries.length === 0
                width: root.width
                topPadding: 28
                leftPadding: 28
                rightPadding: 28
                text: qsTr("No hay ajustes que coincidan con la búsqueda.")
                color: Qt.alpha(Theme.foreground, 0.72)
                font.family: Config.appearance.fontFamily
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }
        }
    }
}
