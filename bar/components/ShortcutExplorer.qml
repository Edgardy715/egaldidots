pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../Singletons"
import "../kit"
import "../settings"
import "../settings/KeyboardMap.js" as KeyboardMap
import "../settings/KeyCapture.js" as KeyCapture

// Shortcut explorer: a keyboard of the active layout showing which keys do
// something with the chosen modifiers. Holding modifiers previews that set live.
// Read-only: editing happens in Crucible (editRequested → manager).
Item {
    id: root
    objectName: "shortcutExplorer"
    property var binds: null
    property real s: 1
    property bool open: false
    property bool closing: false
    readonly property bool active: open && !closing
    readonly property bool reducedMotion: Flags.reduceMotion
    signal requestClose()
    signal editRequested(string id)

    property string query: ""
    property var chosenMods: ["SUPER"]
    property var heldMods: []
    property string selectedKey: ""
    property string hoveredKey: ""
    property int resultIndex: 0

    readonly property var allBinds: binds ? (binds.binds || []).concat(binds.external || []) : []
    readonly property var mods: heldMods.length ? heldMods : chosenMods
    readonly property string layout: binds ? (binds.layout || "") : ""
    readonly property var board: KeyboardMap.rows(layout)
    readonly property var keyIndex: KeyboardMap.index(allBinds, mods)
    readonly property string focusKey: hoveredKey || selectedKey
    readonly property var focusBinds: focusKey && keyIndex[focusKey] ? keyIndex[focusKey] : []
    readonly property var results: query.trim() ? allBinds.filter(b => KeyboardMap.matches(b, query)) : []
    // Sets of modifiers actually in use, most populated first.
    readonly property var modSets: {
        const seen = {}
        for (const b of allBinds) {
            if (!b.enabled || b.submap) continue
            const p = KeyboardMap.split(b.key)
            if (!p.key || /^mouse/.test(p.key)) continue
            const id = p.mods.join("+")
            seen[id] = (seen[id] || 0) + 1
        }
        return Object.keys(seen).sort((a, b) => seen[b] - seen[a] || a.length - b.length).slice(0, 6)
            .map(id => ({id: id, count: seen[id]}))
    }
    // Binds the board cannot show (mouse, media keys, submaps): reachable by search.
    // Letters/digits on an unknown layout are counted apart: they exist, just unlabeled.
    readonly property var offBoardCounts: {
        const keys = {}
        for (const row of board) for (const k of row.main.concat(row.nav)) if (k.sym) keys[k.sym] = true
        let other = 0, unlabeled = 0
        for (const b of allBinds) {
            if (!b.enabled) continue
            const key = KeyboardMap.split(b.key).key
            if (!b.submap && keys[key]) continue
            if (!b.submap && /^[a-z0-9]$/.test(key)) unlabeled++
            else other++
        }
        return {other: other, unlabeled: unlabeled}
    }
    readonly property int offBoard: offBoardCounts.other
    readonly property int unlabeled: offBoardCounts.unlabeled

    function modsLabel(list) { return list.length ? list.map(m => KeyboardMap.MOD_LABEL[m]).join(" + ") : I18n.tr("Sin modificador") }
    function reset() {
        query = ""; chosenMods = ["SUPER"]; heldMods = []; selectedKey = ""; hoveredKey = ""; resultIndex = 0
        if (binds) { binds.load(); if (binds.refreshLayout) binds.refreshLayout() }
        focusTimer.restart()
    }
    function pick(b) {
        if (!b) return
        const p = KeyboardMap.split(b.key)
        if (!b.submap) { chosenMods = p.mods; selectedKey = p.key }
        query = ""
        if (b.submap || !selectedKey) editRequested(b.id)   // nothing to show on the board: open it
        search.forceActiveFocus()
    }
    function toggleMod(m) {
        const next = chosenMods.indexOf(m) >= 0 ? chosenMods.filter(x => x !== m) : chosenMods.concat([m])
        chosenMods = KeyboardMap.MODS.filter(x => next.indexOf(x) >= 0)
    }

    onQueryChanged: { resultIndex = 0; if (search.text !== query) search.text = query }
    onOpenChanged: if (open) reset(); else { heldMods = []; focusTimer.stop() }
    onClosingChanged: if (closing) heldMods = []
    Timer { id: focusTimer; interval: 1; onTriggered: if (root.active) search.forceActiveFocus() }

    // Held modifiers preview their set; any non-modifier key just passes on.
    Keys.onPressed: event => {
        const held = KeyCapture.mods(event.modifiers, event.key)
        if (KeyCapture.fromEvent(event.key, event.modifiers, event.nativeScanCode) === "") heldMods = held
    }
    Keys.onReleased: event => {
        const gone = KeyCapture.mods(0, event.key)
        heldMods = KeyCapture.mods(event.modifiers).filter(m => gone.indexOf(m) < 0)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12 * root.s

        // Header: title, layout, search
        RowLayout {
            Layout.fillWidth: true
            spacing: 12 * root.s
            ColumnLayout {
                spacing: 2 * root.s
                Text {
                    text: I18n.tr("Atajos")
                    color: Theme.foreground
                    font.family: Theme.font; font.pixelSize: Theme.fontSizeHead * root.s; font.weight: Font.DemiBold
                    Accessible.role: Accessible.Heading; Accessible.name: text
                }
                Text {
                    objectName: "shortcutsLayout"
                    text: root.layout === "us" ? I18n.tr("Teclado %1 · ANSI").arg(root.binds.keymapName)
                        : root.layout === "es" ? I18n.tr("Teclado %1 · ISO").arg(root.binds.keymapName)
                        : root.binds && root.binds.keymapName ? I18n.tr("Distribución «%1» sin mapa: letras en blanco").arg(root.binds.keymapName)
                        : I18n.tr("Distribución desconocida: letras en blanco")
                    color: root.layout ? Qt.alpha(Theme.foreground, Theme.alphaIconSec) : Theme.accent
                    font.family: Theme.font; font.pixelSize: Theme.fontSizeSmall * root.s
                }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 300 * root.s
                Layout.preferredHeight: 40 * root.s
                radius: 12 * root.s
                color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
                border.width: search.activeFocus ? 1.5 : 1
                border.color: search.activeFocus ? Qt.alpha(Theme.accent, Theme.alphaIconSec) : Qt.alpha(Theme.foreground, Theme.alphaHair)
                MaterialIcon {
                    anchors.left: parent.left; anchors.leftMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: Icons.iSearch
                    color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                    font.pixelSize: Theme.fontSizeBodyLg * root.s
                }
                IslaTextField {
                    id: search
                    objectName: "shortcutsSearch"
                    anchors.fill: parent
                    anchors.leftMargin: 36 * root.s; anchors.rightMargin: 12 * root.s
                    font.pixelSize: Theme.fontSizeBody * root.s
                    placeholderText: I18n.tr("Buscar acción, tecla o comando")
                    floating: false; chrome: false
                    motionActive: root.active
                    onTextEdited: root.query = text
                    Accessible.name: I18n.tr("Buscar atajos")
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            // First Escape clears the search; the next one closes.
                            if (root.query) root.query = ""; else root.requestClose()
                            event.accepted = true
                        } else if (root.query && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) {
                            const n = root.results.length
                            if (n) root.resultIndex = (root.resultIndex + (event.key === Qt.Key_Down ? 1 : n - 1)) % n
                            event.accepted = true
                        } else if (root.query && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                            root.pick(root.results[root.resultIndex])
                            event.accepted = true
                        }
                    }
                }
            }
        }

        // Modifier sets in use
        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * root.s
            IslaSegmented {
                objectName: "shortcutsMods"
                Layout.fillWidth: true
                inline: true
                options: root.modSets.map(m => m.id)
                optionLabels: root.modSets.map(m => root.modsLabel(m.id ? m.id.split("+") : []) + " · " + m.count)
                current: root.mods.join("+")
                Accessible.name: I18n.tr("Modificadores")
                onChosen: value => { root.chosenMods = value ? value.split("+") : []; root.selectedKey = "" }
            }
        }

        // Board or search results (cross-fade, interruptible)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                id: boardArea
                anchors.fill: parent
                opacity: root.query ? 0 : 1
                visible: opacity > 0
                Behavior on opacity { enabled: !root.reducedMotion; NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                // 15u main block + 0.5u gap + 3u navigation cluster.
                readonly property real u: Math.floor(Math.min(width / 18.6, height / 6.4))
                Column {
                    id: boardColumn
                    anchors.centerIn: parent
                    spacing: 0
                    Repeater {
                        model: root.board
                        Row {
                            id: boardRow
                            required property var modelData
                            required property int index
                            height: boardArea.u * (modelData.top ? 1.25 : 1)
                            Row {
                                height: boardRow.height
                                Repeater {
                                    model: boardRow.modelData.main
                                    delegate: keyDelegate
                                }
                            }
                            Item { width: boardArea.u * 0.5; height: 1 }
                            Row {
                                height: boardRow.height
                                Repeater {
                                    model: boardRow.modelData.nav
                                    delegate: keyDelegate
                                }
                            }
                        }
                    }
                }
            }

            ListView {
                id: resultList
                objectName: "shortcutsResults"
                anchors.fill: parent
                opacity: root.query ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { enabled: !root.reducedMotion; NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                clip: true
                model: root.results
                currentIndex: root.resultIndex
                spacing: 2 * root.s
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: root.reducedMotion ? 0 : Motion.fast
                highlight: Rectangle { radius: Theme.radiusLg; color: Qt.alpha(Theme.accent, Theme.alphaWash) }
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: AbstractButton {
                    id: result
                    required property var modelData
                    required property int index
                    objectName: "shortcutResult-" + modelData.id
                    width: ListView.view.width
                    implicitHeight: 44 * root.s
                    hoverEnabled: true
                    focusPolicy: Qt.NoFocus
                    onClicked: root.pick(modelData)
                    onHoveredChanged: if (hovered) root.resultIndex = index
                    Accessible.role: Accessible.ListItem
                    Accessible.name: modelData.label + " · " + KeyboardMap.readable(modelData.key).join(" ")
                    background: Item {}
                    contentItem: RowLayout {
                        spacing: 10 * root.s
                        Text {
                            Layout.leftMargin: 12 * root.s
                            Layout.fillWidth: true
                            text: result.modelData.label
                            color: result.modelData.enabled ? Theme.foreground : Qt.alpha(Theme.foreground, Theme.alphaDisabled)
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s
                            elide: Text.ElideRight
                        }
                        Text {
                            text: result.modelData.submap ? I18n.tr("Submapa %1").arg(result.modelData.submap) : result.modelData.group
                            color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeSmall * root.s
                        }
                        Row {
                            Layout.rightMargin: 12 * root.s
                            spacing: 3 * root.s
                            Repeater {
                                model: KeyboardMap.readable(result.modelData.key)
                                Keycap { required property string modelData; text: modelData; s: root.s; size: Theme.fontSizeSmall * root.s; reducedMotion: true }
                            }
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: resultList.count === 0
                    text: I18n.tr("Ningún atajo coincide con «%1».").arg(root.query)
                    color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                    font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s
                }
            }
        }

        // Inspector
        Rectangle {
            id: inspector
            objectName: "shortcutsInspector"
            Layout.fillWidth: true
            Layout.preferredHeight: 92 * root.s
            radius: Theme.radiusXxl * root.s
            color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
            border.width: 1; border.color: Qt.alpha(Theme.foreground, Theme.alphaHair)
            readonly property var b: root.focusBinds.length ? root.focusBinds[0] : null

            Text {
                anchors.fill: parent; anchors.margins: 16 * root.s
                visible: !inspector.b
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                text: root.focusKey ? I18n.tr("%1 + %2 está libre.").arg(root.modsLabel(root.mods)).arg(root.focusKey.toUpperCase())
                    : root.unlabeled ? I18n.tr("Distribución de teclado desconocida: %1 atajos con letras o números no se dibujan para no indicar una tecla equivocada. Búscalos por nombre.").arg(root.unlabeled)
                    : root.offBoard ? I18n.tr("Pasa por una tecla iluminada o mantén modificadores para verlos. %1 atajos no caben en el teclado (ratón, multimedia, submapas): búscalos.").arg(root.offBoard)
                    : I18n.tr("Pasa por una tecla iluminada o mantén modificadores para verlos.")
                color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s
            }
            RowLayout {
                anchors.fill: parent; anchors.margins: 16 * root.s
                visible: !!inspector.b
                spacing: 14 * root.s
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4 * root.s
                    RowLayout {
                        spacing: 8 * root.s
                        Text {
                            objectName: "shortcutsInspectorTitle"
                            text: inspector.b ? inspector.b.label : ""
                            color: Theme.foreground
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg * root.s; font.weight: Font.DemiBold
                        }
                        Row {
                            spacing: 3 * root.s
                            Repeater {
                                model: inspector.b ? KeyboardMap.readable(inspector.b.key) : []
                                Keycap { required property string modelData; text: modelData; s: root.s; size: Theme.fontSizeSmall * root.s; emphasis: true; reducedMotion: root.reducedMotion }
                            }
                        }
                        Text {
                            visible: root.focusBinds.length > 1
                            text: I18n.tr("Choca con %1 más").arg(root.focusBinds.length - 1)
                            color: Theme.error
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeSmall * root.s
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: !inspector.b ? "" : KeyboardMap.source(inspector.b) + " · "
                            + (inspector.b.cmd ? inspector.b.cmd : inspector.b.dispatcher === "lua" ? I18n.tr("función Lua") : inspector.b.dispatcher || I18n.tr("acción interna"))
                        color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                        font.family: Theme.font; font.pixelSize: Theme.fontSizeSmall * root.s
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                }
                EdotsButton {
                    objectName: "shortcutsEdit"
                    visible: !!inspector.b && !inspector.b.external
                    text: I18n.tr("Editar")
                    symbol: "edit"
                    flat: true
                    focusPolicy: Qt.NoFocus
                    Accessible.name: I18n.tr("Editar en Crucible")
                    onClicked: root.editRequested(inspector.b.id)
                }
            }
        }
    }

    Component {
        id: keyDelegate
        Item {
            id: key
            required property var modelData
            readonly property string mod: modelData.gap ? "" : KeyboardMap.modOf(modelData)
            readonly property bool bound: !modelData.gap && !mod && !!modelData.sym && !!root.keyIndex[modelData.sym]
            readonly property bool modOn: !!mod && root.mods.indexOf(mod) >= 0
            readonly property bool picked: !!modelData.sym && root.focusKey === modelData.sym
            // ISO Enter: the lower half (no label) joins the upper one.
            readonly property bool enterTail: modelData.sym === "return" && modelData.label === ""
            width: boardArea.u * modelData.w
            height: parent ? parent.height : boardArea.u
            Rectangle {
                visible: !key.modelData.gap
                objectName: "shortcutKey-" + (key.mod ? "@" + key.mod : key.modelData.sym)
                x: 2; width: parent.width - 4
                y: key.enterTail ? -6 * root.s : 2
                height: parent.height - 4 + (key.enterTail ? 4 + 6 * root.s : 0)
                radius: 6 * root.s
                color: key.modOn ? Qt.alpha(Theme.accent, Theme.alphaSelected)
                    : key.bound ? Qt.alpha(Theme.accent, key.picked ? 0.42 : Theme.alphaWashStrong)
                    : key.modelData.blank ? Qt.alpha(Theme.foreground, 0.025)
                    : Qt.alpha(Theme.foreground, key.picked ? Theme.alphaSubtle : Theme.alphaFaint)
                border.width: key.picked || key.modOn ? 1.5 : 1
                border.color: key.picked || key.modOn ? Theme.accent : Qt.alpha(Theme.foreground, Theme.alphaHair)
                Behavior on color { enabled: !root.reducedMotion; ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                Text {
                    anchors.left: parent.left; anchors.top: parent.top
                    anchors.leftMargin: 6 * root.s; anchors.topMargin: 4 * root.s
                    width: parent.width - 8 * root.s
                    text: key.modelData.label || ""
                    color: key.bound || key.modOn ? Theme.foreground : Qt.alpha(Theme.foreground, key.modelData.blank ? 0.2 : 0.55)
                    font.family: Theme.font
                    font.pixelSize: Math.max(9, (key.modelData.label && key.modelData.label.length > 3 ? 0.24 : 0.32) * boardArea.u)
                    font.weight: key.bound ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }
                Rectangle {
                    visible: key.bound
                    anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 5 * root.s
                    width: 5 * root.s; height: width; radius: width / 2
                    color: root.keyIndex[key.modelData.sym] && root.keyIndex[key.modelData.sym].length > 1 ? Theme.error : Theme.accent
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: if (!key.mod) root.hoveredKey = key.modelData.sym
                    onExited: if (root.hoveredKey === key.modelData.sym) root.hoveredKey = ""
                    onClicked: {
                        if (key.mod) root.toggleMod(key.mod)
                        else if (key.modelData.sym) root.selectedKey = root.selectedKey === key.modelData.sym ? "" : key.modelData.sym
                        search.forceActiveFocus()
                    }
                }
                Accessible.role: Accessible.Button
                Accessible.name: (key.modelData.label || I18n.tr("tecla")) + (key.bound ? " · " + root.keyIndex[key.modelData.sym].map(b => b.label).join(", ") : "")
            }
        }
    }
}
