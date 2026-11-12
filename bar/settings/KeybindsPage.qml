import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../Singletons"
import "../components"
import "../kit"
import "KeyCapture.js" as KeyCapture
import "KeyboardMap.js" as KeyboardMap

// Keybind manager: searchable list (master) + inspector/editor (detail).
// Every write goes through the controller (HyprlandBinds → hypr-binds.py),
// which validates, backs up, applies live and rolls back on failure.
RowLayout {
    id: root
    objectName: "keybindsPage"
    property var binds: null
    readonly property bool reducedMotion: Flags.reduceMotion
    spacing: 18

    property string query: ""
    property string filter: "all"
    property string selectedId: ""
    property bool drafting: false
    // Recorder: "" idle · "listen" waiting for keys · "review" candidate captured.
    property string recState: ""
    property var liveMods: []
    property string candidate: ""
    property string pendingSelectKey: ""

    readonly property var allRows: binds ? binds.binds.concat(binds.external || []) : []
    readonly property var rows: {
        const out = []
        for (const b of allRows) {
            if (filter === "custom" && !b.custom) continue
            if (filter === "modified" && !(b.overridden || !b.enabled)) continue
            if (filter === "conflicts" && !(b.conflicts && b.conflicts.length)) continue
            if (filter === "external" && !b.external) continue
            if (KeyboardMap.matches(b, query)) out.push(b)
        }
        return out
    }
    readonly property var selected: {
        if (drafting) return null
        for (const b of allRows) if (b.id === selectedId) return b
        return null
    }
    readonly property bool editable: !!selected && !selected.external
    readonly property bool remappable: editable && KeyCapture.editable(selected)
    readonly property bool busy: !!binds && binds.busy

    // Draft / custom edit fields.
    property string editLabel: ""
    property string editCmd: ""
    readonly property string shownKey: recState === "review" || drafting ? candidate : selected ? selected.key : ""
    readonly property bool customDirty: !!selected && !!selected.custom
        && (editLabel.trim() !== selected.label || editCmd.trim() !== (selected.cmd || ""))

    function select(id) {
        cancelRecording()
        drafting = false
        selectedId = id
        const b = allRows.find(r => r.id === id)
        editLabel = b ? b.label : ""
        editCmd = b ? (b.cmd || "") : ""
        list.positionOn(id)
    }
    function startDraft() {
        cancelRecording()
        drafting = true
        selectedId = ""
        editLabel = ""; editCmd = ""; candidate = ""
        Qt.callLater(() => labelField.forceActiveFocus())
    }

    // Same signature on the main map (submap "") with another bind = clash.
    function clashes(keys, exceptId) {
        const want = KeyboardMap.split(keys)
        return allRows.filter(b => b.id !== exceptId && b.enabled && !b.submap
            && KeyboardMap.split(b.key).key === want.key && KeyboardMap.sameMods(KeyboardMap.split(b.key).mods, want.mods))
            .map(b => b.label)
    }
    readonly property var candidateClashes: candidate ? clashes(candidate, drafting ? "" : selectedId) : []
    readonly property bool candidateBare: {
        const p = KeyboardMap.split(candidate)
        // Same rule as hypr-binds.py parse_keys: only F-keys, Print, media and mouse go bare.
        return !!candidate && p.mods.length === 0 && !/^(f\d{1,2}|print|xf86\w+|mouse.*)$/.test(p.key)
    }

    function startRecording() {
        if (!binds) return
        candidate = ""; liveMods = []
        recState = "listen"
        binds.beginCapture()
        sink.forceActiveFocus()
    }
    function cancelRecording() {
        const was = recState !== ""
        recState = ""; candidate = ""; liveMods = []
        if (binds && binds.capturing) binds.endCapture()
        return was
    }
    function confirmRecording() {
        const keys = candidate
        if (!keys || candidateClashes.length || candidateBare) return
        if (drafting) { recState = ""; return }   // key kept as candidate until "Crear"
        recState = ""; candidate = ""
        if (selected.custom) binds.edit(selected.id, editLabel.trim() || selected.label, keys, editCmd.trim() || selected.cmd)
        else binds.setKey(selected.id, keys)
    }
    function createDraft() {
        if (!candidate || !editLabel.trim() || !editCmd.trim() || candidateClashes.length || candidateBare) return
        pendingSelectKey = candidate
        binds.add(editLabel.trim(), candidate, editCmd.trim())
    }

    onAllRowsChanged: {
        if (pendingSelectKey) {
            const made = allRows.find(r => r.custom && r.key === pendingSelectKey)
            if (made) { pendingSelectKey = ""; candidate = ""; select(made.id) }
        }
        if (!drafting && selectedId && !allRows.some(r => r.id === selectedId)) selectedId = ""
        if (!drafting && !selectedId && rows.length) select(rows[0].id)
        else if (selected) { if (!customDirty) { editLabel = selected.label; editCmd = selected.cmd || "" } }
    }
    // Watchdog or another caller ended the capture: real binds fire again, so stop listening.
    Connections {
        target: root.binds
        function onCapturingChanged() { if (!root.binds.capturing && root.recState === "listen") root.cancelRecording() }
    }
    onVisibleChanged: if (!visible) cancelRecording(); else consumeFocusRequest()
    Component.onDestruction: cancelRecording()
    Component.onCompleted: consumeFocusRequest()
    Connections {
        target: root.binds
        ignoreUnknownSignals: true
        function onFocusIdChanged() { root.consumeFocusRequest() }
    }
    function consumeFocusRequest() {
        // Only once shown: Crucible must see focusId first to switch here.
        if (!visible || !binds || !binds.focusId) return
        const id = binds.focusId
        if (!allRows.some(r => r.id === id)) return
        binds.focusId = ""
        query = ""; filter = "all"
        select(id)
    }

    // ---------------- Master: search, filters, list ----------------
    ColumnLayout {
        // Fixed share: children fill this column, so without an explicit
        // fillWidth:false the column would claim the whole row.
        readonly property real share: Math.round(Math.max(280, Math.min(420, root.width * 0.46)))
        Layout.fillWidth: false
        Layout.preferredWidth: share; Layout.maximumWidth: share; Layout.minimumWidth: share
        Layout.fillHeight: true
        spacing: 10
        EdotsTextField {
            id: searchField
            objectName: "keybindsSearch"
            Layout.fillWidth: true
            placeholderText: I18n.tr("Buscar acción, tecla o comando")
            text: root.query
            onTextEdited: root.query = text
            Accessible.name: I18n.tr("Buscar atajos")
            Keys.onDownPressed: list.forceActiveFocus()
        }
        IslaSegmented {
            objectName: "keybindsFilter"
            Layout.fillWidth: true
            options: ["all", "custom", "modified", "conflicts", "external"]
            optionLabels: [I18n.tr("Todos"), I18n.tr("Propios"), I18n.tr("Cambiados"),
                root.binds && root.binds.conflictCount ? I18n.tr("Choques · %1").arg(root.binds.conflictCount) : I18n.tr("Choques"),
                I18n.tr("Externos")]
            current: root.filter
            Accessible.name: I18n.tr("Filtrar atajos")
            onChosen: value => root.filter = value
        }
        ListView {
            id: list
            objectName: "keybindsList"
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            model: root.rows
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: true
            activeFocusOnTab: true
            currentIndex: root.rows.findIndex(r => r.id === root.selectedId)
            highlightFollowsCurrentItem: true
            highlightMoveDuration: root.reducedMotion ? 0 : Motion.fast
            highlightResizeDuration: root.reducedMotion ? 0 : Motion.fast
            highlight: Rectangle {
                radius: Theme.radiusLg
                color: Qt.alpha(Theme.accent, list.activeFocus ? Theme.alphaSubtle : Theme.alphaWash)
            }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            section.property: "group"
            section.delegate: Text {
                required property string section
                width: ListView.view.width
                topPadding: 10; bottomPadding: 4; leftPadding: 10
                text: section
                color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.6
                Accessible.role: Accessible.Heading; Accessible.name: section
            }
            Keys.onUpPressed: event => { if (currentIndex <= 0) searchField.forceActiveFocus(); else root.select(root.rows[currentIndex - 1].id) }
            Keys.onDownPressed: if (currentIndex < count - 1) root.select(root.rows[currentIndex + 1].id)
            function positionOn(id) {
                const i = root.rows.findIndex(r => r.id === id)
                if (i >= 0) positionViewAtIndex(i, ListView.Contain)
            }
            delegate: AbstractButton {
                id: row
                required property var modelData
                required property int index
                objectName: "keybindRow-" + modelData.id
                width: ListView.view.width
                implicitHeight: Math.max(44, Theme.fontSizeBody * 2 + 18)
                focusPolicy: Qt.NoFocus
                hoverEnabled: true
                onClicked: { root.select(modelData.id); list.forceActiveFocus() }
                Accessible.role: Accessible.ListItem
                Accessible.name: modelData.label + " · " + KeyboardMap.readable(modelData.key).join(" ")
                    + (modelData.enabled ? "" : " · " + I18n.tr("desactivado"))
                    + (modelData.conflicts && modelData.conflicts.length ? " · " + I18n.tr("en conflicto") : "")
                background: Rectangle {
                    radius: Theme.radiusLg
                    color: row.hovered && root.selectedId !== row.modelData.id ? Qt.alpha(Theme.foreground, Theme.alphaFaint) : "transparent"
                    Behavior on color { enabled: !root.reducedMotion; ColorAnimation { duration: Motion.hover } }
                }
                contentItem: RowLayout {
                    spacing: 8
                    // Status: conflict, modified, custom, external, disabled.
                    Rectangle {
                        Layout.preferredWidth: 6; Layout.preferredHeight: 6; radius: 3
                        Layout.leftMargin: 4
                        readonly property bool clash: !!row.modelData.conflicts && row.modelData.conflicts.length > 0
                        color: clash ? Theme.error : row.modelData.overridden || row.modelData.custom ? Theme.accent : "transparent"
                        border.width: row.modelData.external ? 1 : 0
                        border.color: Qt.alpha(Theme.foreground, 0.5)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.label
                        color: row.modelData.enabled ? Theme.foreground : Qt.alpha(Theme.foreground, Theme.alphaDisabled)
                        font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                        font.strikeout: !row.modelData.enabled
                        elide: Text.ElideRight
                    }
                    Row {
                        spacing: 3
                        Layout.rightMargin: 6
                        Repeater {
                            model: KeyboardMap.readable(row.modelData.key)
                            Keycap { required property string modelData; text: modelData; size: Theme.fontSizeSmall; muted: !row.modelData.enabled }
                        }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: !root.binds || !root.binds.loaded ? I18n.tr("Cargando atajos…")
                    : root.query ? I18n.tr("Ningún atajo coincide con «%1».").arg(root.query) : I18n.tr("Nada en este filtro.")
                color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            EdotsButton {
                objectName: "keybindsNew"
                text: I18n.tr("Nuevo"); symbol: "add"
                enabled: !root.busy
                onClicked: root.startDraft()
            }
            Item { Layout.fillWidth: true }
            EdotsButton {
                objectName: "keybindsUndo"
                flat: true
                symbol: "undo"
                enabled: !root.busy && !!root.binds && root.binds.canUndo
                Accessible.name: I18n.tr("Deshacer el último cambio de atajos")
                ToolTip.visible: hovered; ToolTip.delay: 500; ToolTip.text: Accessible.name
                onClicked: root.binds.undo()
            }
            EdotsButton {
                objectName: "hyprlandBindsResetAll"
                flat: true
                symbol: "restart_alt"
                enabled: !root.busy
                Accessible.name: I18n.tr("Restaurar todos los atajos de Azog; los personalizados se conservan")
                ToolTip.visible: hovered; ToolTip.delay: 500; ToolTip.text: Accessible.name
                onClicked: root.binds.resetAll()
            }
        }
    }

    // ---------------- Detail: inspector + editor ----------------
    Rectangle {
        Layout.fillWidth: true; Layout.fillHeight: true
        radius: Theme.radiusXxl + 4
        color: Qt.alpha(Theme.foreground, Theme.liquid ? 0.05 : 0.035)
        border.width: 1; border.color: Qt.alpha(Theme.foreground, Theme.alphaHair)

        Text {
            anchors.centerIn: parent
            visible: !root.selected && !root.drafting
            text: I18n.tr("Elige un atajo para ver su detalle")
            color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
            font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
        }

        // Scrolls only when the window is too short for the whole inspector.
        Flickable {
          id: detailScroll
          anchors.fill: parent; anchors.margins: 20
          visible: !!root.selected || root.drafting
          clip: true
          contentWidth: width
          contentHeight: detail.height
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
          ColumnLayout {
            id: detail
            objectName: "keybindDetail"
            width: detailScroll.width
            height: Math.max(implicitHeight, detailScroll.height)
            spacing: 14
            // Small, interruptible settle when the inspected bind changes.
            readonly property string identity: root.drafting ? "draft" : root.selectedId
            onIdentityChanged: if (!root.reducedMotion && visible) settle.restart()
            ParallelAnimation {
                id: settle
                NumberAnimation { target: detail; property: "opacity"; from: 0.35; to: 1; duration: Motion.standardSmall; easing.type: Motion.easeStandard }
                NumberAnimation { target: shift; property: "y"; from: 6; to: 0; duration: Motion.standardSmall; easing.type: Motion.easeStandard }
            }
            transform: Translate { id: shift }

            // Header: title/source, with the on/off switch beside it
            RowLayout {
              Layout.fillWidth: true; spacing: 12
              ColumnLayout {
                Layout.fillWidth: true; spacing: 3
                Text {
                    objectName: "keybindDetailTitle"
                    Layout.fillWidth: true
                    text: root.drafting ? I18n.tr("Nuevo atajo") : root.selected ? root.selected.label : ""
                    color: Theme.foreground
                    font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeHead; font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Accessible.role: Accessible.Heading; Accessible.name: text
                }
                Text {
                    objectName: "keybindSource"
                    Layout.fillWidth: true
                    text: root.drafting ? I18n.tr("Se guardará en tu capa de Azog (binds.user.json)")
                        : root.selected ? (root.selected.group + " · " + KeyboardMap.source(root.selected)) : ""
                    color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                    font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                    elide: Text.ElideRight
                }
              }
                IslaSwitch {
                    Layout.alignment: Qt.AlignTop
                    objectName: "hyprlandBindToggle"
                    visible: root.editable
                    reducedMotion: root.reducedMotion
                    checked: !!root.selected && root.selected.enabled
                    enabled: !root.busy && root.recState === ""
                    Accessible.name: I18n.tr("Atajo activo")
                    onToggled: {
                        const on = checked
                        // Show the backend's answer, not the click.
                        checked = Qt.binding(() => !!root.selected && root.selected.enabled)
                        on ? root.binds.enable(root.selected.id) : root.binds.disable(root.selected.id)
                    }
                }
            }

            // Recorder / keycaps
            Rectangle {
                id: recorder
                objectName: "keybindRecorder"
                Layout.fillWidth: true
                Layout.preferredHeight: 92
                radius: Theme.radiusXxl
                readonly property bool listening: root.recState === "listen"
                color: listening ? Qt.alpha(Theme.accent, Theme.alphaWash) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                border.width: listening ? 2 : 1
                border.color: listening ? Theme.accent : Qt.alpha(Theme.foreground, Theme.alphaHair)
                Behavior on color { enabled: !root.reducedMotion; ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                Behavior on border.color { enabled: !root.reducedMotion; ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                Row {
                    id: caps
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -8
                    spacing: 6
                    readonly property var shown: recorder.listening
                        ? root.liveMods.map(m => KeyboardMap.MOD_LABEL[m])
                        : KeyboardMap.readable(root.shownKey)
                    Repeater {
                        model: caps.shown
                        Keycap {
                            required property string modelData
                            text: modelData
                            size: Theme.fontSizeBodyLg + 2
                            emphasis: root.recState !== ""
                            muted: !!root.selected && !root.selected.enabled && root.recState === ""
                        }
                    }
                }
                Text {
                    objectName: "hyprlandBindCapturePrompt"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                    visible: recorder.listening || caps.shown.length === 0 || root.recState === "review"
                    text: recorder.listening ? (root.liveMods.length ? I18n.tr("…y ahora la tecla") : I18n.tr("Pulsa la combinación · Esc cancela"))
                        : root.recState === "review" ? (root.candidateBare ? I18n.tr("Añade un modificador: sola, esta tecla dejaría de escribir")
                            : root.candidateClashes.length ? I18n.tr("Ya la usa: %1").arg(root.candidateClashes.join(", "))
                            : I18n.tr("¿Guardar esta combinación?"))
                        : root.drafting ? I18n.tr("Sin combinación todavía") : I18n.tr("Sin combinación")
                    color: root.recState === "review" && (root.candidateBare || root.candidateClashes.length) ? Theme.error
                        : recorder.listening ? Theme.accent : Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                    font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeSmall
                    Accessible.role: Accessible.StaticText; Accessible.name: text
                }
                // Key sink: owns focus only while listening.
                Item {
                    id: sink
                    objectName: "keybindKeySink"
                    focus: recorder.listening
                    Keys.onPressed: event => {
                        event.accepted = true
                        if (event.key === Qt.Key_Escape) { root.cancelRecording(); return }
                        const keys = KeyCapture.fromEvent(event.key, event.modifiers, event.nativeScanCode)
                        // Modifiers alone: show them as held keycaps and keep listening.
                        if (keys === "") { root.liveMods = KeyCapture.mods(event.modifiers, event.key); return }
                        root.candidate = keys
                        root.recState = "review"
                        root.liveMods = []
                        if (root.binds) root.binds.endCapture()
                        // A disabled button can't hold focus; Escape must not reach the window.
                        const next = saveKey.enabled ? saveKey : retryKey
                        next.forceActiveFocus()
                    }
                    Keys.onReleased: event => {
                        event.accepted = true
                        // Qt still reports the released modifier; drop it.
                        const gone = KeyCapture.mods(0, event.key)
                        root.liveMods = KeyCapture.mods(event.modifiers).filter(m => gone.indexOf(m) < 0)
                    }
                    // Losing focus (click elsewhere, window change) never leaves the compositor captured.
                    onActiveFocusChanged: if (!activeFocus && root.recState === "listen") root.cancelRecording()
                }
            }

            // Recorder actions
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                EdotsButton {
                    id: recordButton
                    objectName: "hyprlandBindChange"
                    visible: root.recState !== "review"
                    text: root.recState === "listen" ? I18n.tr("Cancelar") : I18n.tr("Grabar combinación")
                    symbol: root.recState === "listen" ? "close" : "keyboard"
                    enabled: !root.busy && (root.drafting || root.remappable)
                    Accessible.name: root.recState === "listen" ? I18n.tr("Cancelar grabación")
                        : I18n.tr("Grabar combinación para %1").arg(root.drafting ? I18n.tr("el nuevo atajo") : root.selected ? root.selected.label : "")
                    onClicked: root.recState === "listen" ? root.cancelRecording() : root.startRecording()
                }
                EdotsButton {
                    id: saveKey
                    objectName: "keybindConfirm"
                    visible: root.recState === "review"
                    accent: true
                    text: root.drafting ? I18n.tr("Usar") : I18n.tr("Guardar"); symbol: "check"
                    enabled: !root.busy && !root.candidateBare && root.candidateClashes.length === 0
                    onClicked: root.confirmRecording()
                    Keys.onReturnPressed: root.confirmRecording()
                    Keys.onEscapePressed: event => { root.cancelRecording(); recordButton.forceActiveFocus() }
                }
                EdotsButton {
                    id: retryKey
                    objectName: "keybindRetry"
                    visible: root.recState === "review"
                    flat: true
                    symbol: "replay"
                    Accessible.name: I18n.tr("Grabar otra vez")
                    ToolTip.visible: hovered; ToolTip.delay: 500; ToolTip.text: Accessible.name
                    onClicked: root.startRecording()
                    Keys.onEscapePressed: { root.cancelRecording(); recordButton.forceActiveFocus() }
                }
                EdotsButton {
                    objectName: "keybindCancel"
                    visible: root.recState === "review"
                    flat: true
                    text: I18n.tr("Cancelar")
                    onClicked: root.cancelRecording()
                }
            }

            // Fields: name + command (custom/draft editable; others read-only)
            GridLayout {
                Layout.fillWidth: true
                columns: 2; columnSpacing: 12; rowSpacing: 8
                readonly property bool own: root.drafting || (!!root.selected && !!root.selected.custom)
                Text {
                    visible: parent.own
                    text: I18n.tr("Nombre"); color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                    font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                }
                EdotsTextField {
                    id: labelField
                    objectName: "keybindLabelField"
                    visible: parent.own
                    Layout.fillWidth: true
                    placeholderText: I18n.tr("Ej. Abrir notas")
                    maximumLength: 60
                    text: root.editLabel
                    onTextEdited: root.editLabel = text
                    Accessible.name: I18n.tr("Nombre del atajo")
                }
                Text {
                    text: I18n.tr("Acción"); color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                    font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                    Layout.alignment: Qt.AlignTop; Layout.topMargin: parent.own ? 12 : 0
                }
                EdotsTextField {
                    objectName: "keybindCommandField"
                    visible: parent.own
                    Layout.fillWidth: true
                    placeholderText: I18n.tr("Comando, p. ej. kitty -e nvim")
                    text: root.editCmd
                    onTextEdited: root.editCmd = text
                    font.family: "monospace"
                    Accessible.name: I18n.tr("Comando que ejecuta el atajo")
                }
                Text {
                    objectName: "keybindAction"
                    visible: !parent.own
                    Layout.fillWidth: true
                    readonly property var b: root.selected
                    text: !b ? "" : b.cmd ? b.cmd
                        : b.dispatcher === "lua" ? I18n.tr("Función Lua de la configuración")
                        : b.dispatcher ? I18n.tr("Acción del compositor · %1").arg(b.dispatcher) : I18n.tr("Acción interna")
                    color: Theme.foreground
                    font.family: b && b.cmd ? "monospace" : Config.appearance.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    wrapMode: Text.WrapAnywhere; maximumLineCount: 3; elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }

            // Flags & conflicts
            Flow {
                Layout.fillWidth: true; spacing: 6
                visible: !!root.selected && ((root.selected.flags || []).length > 0 || !!root.selected.submap || !!root.selected.pending)
                Repeater {
                    model: root.selected ? (root.selected.flags || []).map(f => ({
                        locked: I18n.tr("Funciona con pantalla bloqueada"), repeat: I18n.tr("Se repite al mantener"),
                        repeating: I18n.tr("Se repite al mantener"), mouse: I18n.tr("Ratón"), release: I18n.tr("Al soltar"),
                        non_consuming: I18n.tr("No consume la tecla"), submap_universal: I18n.tr("Activo en todos los submapas")
                    }[f] || f)).concat(root.selected.submap ? [I18n.tr("Submapa %1").arg(root.selected.submap)] : [])
                        .concat(root.selected.pending ? [I18n.tr("Pendiente de aplicar")] : []) : []
                    Rectangle {
                        required property string modelData
                        implicitWidth: flagText.implicitWidth + 16; implicitHeight: flagText.implicitHeight + 8
                        radius: height / 2
                        color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
                        Text {
                            id: flagText; anchors.centerIn: parent
                            text: parent.modelData
                            color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                            font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
            }
            Text {
                objectName: "keybindConflicts"
                Layout.fillWidth: true
                visible: !!root.selected && (root.selected.conflicts || []).length > 0
                text: root.selected ? I18n.tr("Choca con: %1. Solo funcionará uno; cambia la combinación de alguno.").arg((root.selected.conflicts || []).join(", ")) : ""
                color: Theme.error
                font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                wrapMode: Text.WordWrap
            }
            Text {
                objectName: "keybindReadOnly"
                Layout.fillWidth: true
                visible: !!root.selected && !!root.selected.external
                text: I18n.tr("Viene de tu configuración de Hyprland, fuera de Azog. Se muestra para que veas los choques, pero se edita en hyprland.lua.")
                color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }

            // Footer actions
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                EdotsButton {
                    objectName: "keybindCreate"
                    visible: root.drafting
                    accent: true
                    text: I18n.tr("Crear atajo"); symbol: "add"
                    enabled: !root.busy && root.recState === "" && !!root.candidate && !!root.editLabel.trim() && !!root.editCmd.trim()
                        && root.candidateClashes.length === 0 && !root.candidateBare
                    onClicked: root.createDraft()
                }
                EdotsButton {
                    objectName: "keybindDiscardDraft"
                    visible: root.drafting
                    flat: true
                    text: I18n.tr("Descartar")
                    onClicked: { root.drafting = false; root.candidate = ""; root.cancelRecording(); if (root.rows.length) root.select(root.rows[0].id) }
                }
                EdotsButton {
                    objectName: "keybindSaveCustom"
                    visible: root.customDirty
                    accent: true
                    text: I18n.tr("Guardar cambios"); symbol: "check"
                    enabled: !root.busy && !!root.editLabel.trim() && !!root.editCmd.trim()
                    onClicked: root.binds.edit(root.selected.id, root.editLabel.trim(), root.selected.key, root.editCmd.trim())
                }
                Item { Layout.fillWidth: true }
                EdotsButton {
                    objectName: "hyprlandBindReset"
                    visible: !!root.selected && !root.selected.custom && !root.selected.external && (root.selected.overridden || !root.selected.enabled)
                    flat: true
                    text: I18n.tr("Predeterminado"); symbol: "restart_alt"
                    enabled: !root.busy
                    Accessible.name: I18n.tr("Restaurar %1 a %2").arg(root.selected ? root.selected.label : "").arg(root.selected ? root.selected.default : "")
                    onClicked: root.binds.reset(root.selected.id)
                }
                EdotsButton {
                    objectName: "keybindRemove"
                    visible: !!root.selected && !!root.selected.custom
                    flat: true
                    text: I18n.tr("Eliminar"); symbol: "delete"
                    enabled: !root.busy
                    Accessible.name: I18n.tr("Eliminar el atajo %1 (se puede deshacer)").arg(root.selected ? root.selected.label : "")
                    onClicked: root.binds.remove(root.selected.id)
                }
            }
            Text {
                objectName: "hyprlandBindsStatus"
                Layout.fillWidth: true
                visible: text.length > 0
                text: !root.binds ? "" : root.binds.error || (root.binds.busy ? I18n.tr("Aplicando…") : root.binds.feedback)
                color: root.binds && root.binds.error ? Theme.error : Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                wrapMode: Text.WordWrap
                Accessible.role: Accessible.StaticText; Accessible.name: text
            }
          }
        }
    }
}
