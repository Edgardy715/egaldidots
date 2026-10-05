import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../Singletons"
import "../components"

/**
 * Isla · ClipboardSurface. Panel de historial de portapapeles usando cliphist.
 * - Muestra entradas de cliphist list (texto + imágenes)
 * - Click → copia al portapapeles (wl-copy) y cierra
 * - Búsqueda/filtro en tiempo real
 * - Navegación con teclado (↑/↓/Enter/Esc)
 * - Miniaturas asíncronas de las imágenes visibles
 */
PillSurface {
    id: root
    mTop: Theme.marginMd; mLeft: Theme.marginMd; mRight: Theme.marginMd; mBottom: Theme.marginMd

    property string query: ""
    property var entries: []
    property int selectedIndex: 0
    property bool loading: true
    property bool copying: false
    property bool clearing: false
    property bool clearPending: false
    property string errorMessage: ""
    property string previewDir: ""
    Component.onDestruction: if (previewDir.length) Quickshell.execDetached(["rm", "-rf", "--", previewDir])

    Process {
        command: ["mktemp", "-d", (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/isla-clipboard.XXXXXX"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.previewDir = text.trim() }
    }

    onOpenChanged: {
        if (open) {
            query = ""
            searchInput.text = ""
            selectedIndex = 0
            loadEntries()
            focusTimer.restart()
        } else {
            searchDebounce.stop()
        }
    }

    Timer {
        id: searchDebounce
        interval: 50; repeat: false
        onTriggered: {
            filterEntries()
        }
    }

    function loadEntries() {
        loading = true
        errorMessage = ""
        listProcess.running = true
    }

    Process {
        id: listProcess
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            id: listOutput
            onStreamFinished: root.showEntries(listOutput.text || "")
        }
        onExited: code => {
            if (code !== 0) {
                root.loading = false
                root.errorMessage = qsTr("No se pudo cargar el historial.")
            }
        }
    }

    function showEntries(output) {
        if (!open || closing) return
        var lines = output.split("\n")
        var parsed = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.length === 0) continue
            // cliphist format: "N\tcontent" or "N\t[binary data]"
            var parts = line.split("\t")
            if (parts.length >= 2) {
                var id = parts[0]
                var content = parts.slice(1).join("\t")
                var isImage = content.startsWith("[[ binary data ") && content.endsWith("]]")
                parsed.push({
                    id: id,
                    text: isImage ? "" : content,
                    isImage: isImage,
                    preview: isImage ? content : content.substring(0, 100)
                })
            }
        }
        entries = parsed
        loading = false
        filterEntries()
    }

    property var filteredEntries: []
    readonly property var selectedEntry: filteredEntries[selectedIndex] || null

    function filterEntries() {
        if (!query || query.trim().length === 0) {
            filteredEntries = entries
        } else {
            var lowerQuery = query.toLowerCase()
            filteredEntries = entries.filter(function(e) {
                return e.text.toLowerCase().indexOf(lowerQuery) >= 0
            })
        }
        selectedIndex = 0
        listView.currentIndex = 0
    }

    function copyEntry(entry) {
        if (copying || clearing || !/^\d+$/.test(entry.id)) return
        copying = true
        errorMessage = ""
        copyProcess.command = ["bash", "-o", "pipefail", "-c",
            'cliphist decode "$1" | wl-copy',
            "cliphist-copy", entry.id]
        copyProcess.running = true
    }

    Process {
        id: copyProcess
        onExited: code => {
            root.copying = false
            if (code === 0) root.requestClose()
            else root.errorMessage = qsTr("No se pudo copiar la entrada.")
        }
    }

    function clearHistory() {
        if (loading || copying || clearing || entries.length === 0) return
        clearing = true
        errorMessage = ""
        clearProcess.running = true
    }

    Process {
        id: clearProcess
        command: ["cliphist", "wipe"]
        onExited: code => {
            if (code === 0) {
                root.clearPending = true
                historyMotion.shown = false
            } else {
                root.clearing = false
                root.errorMessage = qsTr("No se pudo limpiar el historial.")
            }
        }
    }

    ContentMotion {
        id: historyMotion
        objectName: "clipboardHistoryMotion"
        onConcealed: {
            if (!root.clearPending) return
            root.clearPending = false
            root.entries = []
            root.query = ""
            searchInput.text = ""
            root.filterEntries()
            root.clearing = false
            shown = true
        }
    }

    function move(dir) {
        var n = filteredEntries.length
        if (n === 0) return
        var i = selectedIndex + dir
        if (i < 0) i = n - 1
        else if (i >= n) i = 0
        selectedIndex = i
        listView.currentIndex = i
    }

    // ── layout ────────────────────────────────────────────────
    Column {
        anchors.fill: parent
        spacing: Theme.spacingLg * root.s

        // ---- barra de búsqueda ----
        Rectangle {
            id: searchBox
            width: parent.width
            height: 44 * root.s
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.alpha(Theme.accent, Theme.alphaSoft) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.foreground, Theme.alphaGhost) }
            }
            border.color: searchInput.activeFocus ? Qt.alpha(Theme.accent, Theme.alphaIconSec) : Qt.alpha(Theme.foreground, Theme.alphaSoft)
            border.width: Theme.borderHairlineSoft
            Behavior on border.color { enabled: !Flags.reduceMotion; ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

            MaterialIcon {
                anchors.left: parent.left
                anchors.leftMargin: 16 * root.s
                anchors.verticalCenter: parent.verticalCenter
                iconName: Icons.iSearch
                color: Theme.foreground
                font.pixelSize: Theme.fontSizeTitle * root.s
            }

            IslaTextField {
                id: searchInput
                objectName: "clipboardSearch"
                anchors.fill: parent
                anchors.leftMargin: 42 * root.s
                anchors.rightMargin: clearButton.width + 22 * root.s
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                placeholderText: qsTr("Buscar en portapapeles…")
                motionActive: root.active && root.visible
                floating: false
                chrome: false
                Accessible.name: qsTr("Buscar en portapapeles")
                onTextChanged: {
                    root.query = text
                    searchDebounce.restart()
                }
                Keys.onUpPressed: function(event) { root.move(-1); event.accepted = true }
                Keys.onDownPressed: function(event) { root.move(1); event.accepted = true }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (filteredEntries.length > 0 && filteredEntries[selectedIndex]) {
                            root.copyEntry(filteredEntries[selectedIndex])
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        root.requestClose()
                        event.accepted = true
                    }
                }
            }
            Rectangle {
                id: clearButton
                anchors.right: parent.right
                anchors.rightMargin: 8 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: clearLabel.implicitWidth + 24 * root.s
                height: 30 * root.s
                radius: height / 2
                color: Qt.alpha(Theme.foreground, clearControl.containsMouse ? Theme.alphaChip : Theme.alphaFaint)
                opacity: clearControl.enabled ? 1 : 0.42
                Behavior on color { ColorAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
                Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                Behavior on width { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                AnimatedLabel {
                    id: clearLabel
                    scale: clearControl.motion.visualScale
                    anchors.centerIn: parent
                    value: root.clearing ? qsTr("Limpiando…") : qsTr("Limpiar todo")
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeLabel * root.s
                }
                MotionArea {
                    id: clearControl
                    objectName: "clipboardClearButton"
                    anchors.fill: parent
                    enabled: !root.loading && !root.copying && !root.clearing && root.entries.length > 0
                    accessibleName: qsTr("Limpiar todo el historial del portapapeles")
                    onClicked: root.clearHistory()
                }
            }
        }

        Item {
            id: selectedPreview
            opacity: historyMotion.progress
            scale: historyMotion.visualScale
            readonly property var dimensions: root.selectedEntry ? root.selectedEntry.preview.match(/(\d+)x(\d+)\s*\]\]$/) : null
            width: parent.width
            height: visible ? Math.min(150 * root.s, Math.max(48 * root.s,
                width * (dimensions ? Number(dimensions[2]) / Math.max(1, Number(dimensions[1])) : 0.25))) : 0
            visible: !!root.selectedEntry && root.selectedEntry.isImage
            Repeater {
                model: selectedPreview.visible ? [root.selectedEntry.id] : []
                delegate: Item {
                    id: previewEntry
                    required property var modelData
                    property string imageSource: ""
                    anchors.fill: parent
                    Process {
                        running: root.previewDir.length > 0
                        command: ["bash", "-o", "pipefail", "-c",
                            'cliphist decode "$1" | magick - -auto-orient -thumbnail 768x320 -strip "$2"',
                            "clipboard-preview", modelData, root.previewDir + "/" + modelData + "-preview.png"]
                        onExited: code => {
                            if (code === 0) previewEntry.imageSource = "file://" + root.previewDir + "/" + previewEntry.modelData + "-preview.png"
                        }
                    }
                    Image {
                        objectName: "clipboardSelectedPreview"
                        anchors.fill: parent
                        source: previewEntry.imageSource
                        sourceSize: Qt.size(768, 320)
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
                    }
                }
            }
        }

        // ---- loading indicator ----
        Item {
            id: loadingItem
            width: parent.width
            height: loading ? 60 * root.s : 0
            visible: loading
            opacity: loading ? 1 : 0
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
            Behavior on height { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph } }

            Text {
                anchors.centerIn: parent
                text: "Cargando historial…"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeBodyLg * root.s
            }
        }

        // ---- listado de entradas ----
        MotionList {
            id: listView
            scale: historyMotion.visualScale
            transform: Translate { y: historyMotion.offset * root.s }
            width: parent.width
            height: loading ? 0 : Math.max(0, parent.height - searchBox.height - parent.spacing - hintRow.height - parent.spacing
                - selectedPreview.height - (selectedPreview.visible ? parent.spacing : 0))
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: Theme.spacingSm * root.s
            visible: !loading && filteredEntries.length > 0
            opacity: (!loading && filteredEntries.length > 0) ? historyMotion.progress : 0
            Behavior on height { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }

            model: ScriptModel { values: root.filteredEntries }

            highlight: Rectangle {
                color: Qt.alpha(Theme.accent, Theme.alphaGlow)
                border.color: Qt.alpha(Theme.accent, Theme.alphaSelected)
                border.width: Theme.borderHairline
                radius: Theme.radiusLg * root.s
                Behavior on y { Anim { type: Anim.FastEffects } }
            }
            highlightMoveDuration: Motion.fast
            highlightResizeDuration: 0
            preferredHighlightBegin: 0
            preferredHighlightEnd: listView.height
            highlightRangeMode: ListView.ApplyRange

            delegate: Item {
                id: clipDelegate
                width: ListView.view ? ListView.view.width : 0
                height: modelData.isImage ? 80 * root.s : 56 * root.s

                Rectangle {
        scale: controlHit1.motion.visualScale
                    id: delegateBg
                    anchors.fill: parent
                    radius: Theme.radiusLg * root.s
                    color: ListView.isCurrentItem ? Qt.alpha(Theme.accent, Theme.alphaWash) : "transparent"
                    border.color: ListView.isCurrentItem ? Qt.alpha(Theme.accent, Theme.alphaStrong) : Qt.alpha(Theme.foreground, Theme.alphaFaint)
                    border.width: ListView.isCurrentItem ? 1.5 : 1
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12 * root.s
                        anchors.rightMargin: 12 * root.s
                        spacing: Theme.spacingXl * root.s

                        // Icono de tipo de entrada.
                        Item {
                            id: previewBox
                            property string thumbnailSource: ""
                            property bool previewFailed: false
                            readonly property bool onScreen: root.open && !root.closing
                                && clipDelegate.y + clipDelegate.height > listView.contentY
                                && clipDelegate.y < listView.contentY + listView.height
                            width: clipDelegate.height - 8 * root.s
                            height: clipDelegate.height - 8 * root.s
                            anchors.verticalCenter: parent.verticalCenter

                            Process {
                                running: modelData.isImage && previewBox.onScreen && root.previewDir.length > 0
                                    && !previewBox.thumbnailSource.length && !previewBox.previewFailed
                                command: ["bash", "-o", "pipefail", "-c",
                                    'cliphist decode "$1" | magick - -auto-orient -thumbnail 144x144 -strip "$2"',
                                    "clipboard-preview", modelData.id, root.previewDir + "/" + modelData.id + ".png"]
                                onExited: code => {
                                    if (code === 0) previewBox.thumbnailSource = "file://" + root.previewDir + "/" + modelData.id + ".png"
                                    else if (previewBox.onScreen) previewBox.previewFailed = true
                                }
                            }
                            Image {
                                id: thumbnail
                                objectName: "clipboardThumbnail"
                                anchors.fill: parent
                                anchors.margins: 4 * root.s
                                source: previewBox.thumbnailSource
                                asynchronous: true
                                sourceSize: Qt.size(144, 144)
                                fillMode: Image.PreserveAspectFit
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
                            }
                            MaterialIcon {
                                visible: thumbnail.status !== Image.Ready
                                interaction: controlHit1.motion
                                anchors.centerIn: parent
                                iconName: modelData.isImage ? "image" : "content_copy"
                                color: Qt.alpha(Theme.foreground, 0.65)
                                font.pixelSize: Theme.fontSizeDisplay * root.s
                            }
                        }

                        // Text content
                        Item {
                            width: Math.max(0, parent.width - (clipDelegate.height - 8 * root.s) - parent.spacing)
                            height: parent.height
                            anchors.verticalCenter: parent.verticalCenter

                            Column {
                                width: parent.width
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingXs * root.s

                                Text {
                                    objectName: "clipboardEntryLabel"
                                    textFormat: Text.PlainText
                                    width: parent.width
                                    transform: Translate { y: -Motion.labelTravel * controlHit1.motion.presence }
                                    text: modelData.isImage ? qsTr("Imagen") : modelData.preview
                                    color: Theme.foreground
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSizeBodyLg * root.s
                                    font.weight: modelData.isImage ? Font.DemiBold : Font.Medium
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                Text {
                                    width: parent.width
                                    textFormat: Text.PlainText
                                    transform: Translate { y: -Motion.labelTravel * controlHit1.motion.presence }
                                    visible: modelData.isImage
                                    text: modelData.isImage ? modelData.preview.slice(2, -2).trim() : ""
                                    color: Qt.alpha(Theme.foreground, 0.72)
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSizeSmall * root.s
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }
                            }
                        }
                    }
                }

                MotionArea {
        id: controlHit1
                    enabled: !root.copying && !root.clearing
                    accessibleName: modelData.isImage ? qsTr("Copiar imagen") : modelData.preview
                    anchors.fill: parent
                    hoverWash: false
                    onClicked: {
                        selectedIndex = index
                        listView.currentIndex = index
                        copyEntry(modelData)
                    }
                    onEntered: {
                        selectedIndex = index
                        listView.currentIndex = index
                    }
                }
            }
        }

        // ---- empty state ----
        Item {
            id: emptyItem
            width: parent.width
            height: visible ? 80 * root.s : 0
            readonly property bool presented: root.errorMessage.length > 0 || !root.loading && root.filteredEntries.length === 0
            visible: opacity > 0
            opacity: presented ? 1 : 0
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }

            Text {
                anchors.centerIn: parent
                text: root.errorMessage || (root.query.length > 0 ? qsTr("Sin coincidencias") : qsTr("El historial está vacío"))
                color: Qt.alpha(Theme.foreground, 0.72)
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeBodyLg * root.s
            }
        }

        // ---- hint de teclado ----
        Item {
            id: hintRow
            width: parent.width
            height: (!loading && filteredEntries.length > 0) ? (keycapRow.height + 1) : 0
            visible: !loading && filteredEntries.length > 0
            opacity: visible ? historyMotion.progress : 0
            clip: true
            Behavior on height {
                NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve }
            }
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Theme.sheen
            }

            RowLayout {
                id: keycapRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Theme.spacingMd * root.s

                HintKbd { glyph: "↑↓"; label: "navegar"; s: root.s }
                HintKbd { glyph: "↵"; label: "copiar"; s: root.s }
                Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }
                HintKbd { glyph: "esc"; label: "cerrar"; s: root.s }
            }
        }
    }

    // timer inicial para girar foco
    Timer {
        id: focusTimer
        interval: Motion.morph + 60
        repeat: false
        onTriggered: if (root.open) searchInput.forceActiveFocus()
    }
}
