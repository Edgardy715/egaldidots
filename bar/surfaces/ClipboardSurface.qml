import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"
import "../Singletons"
import "../components"

/**
 * Isla · ClipboardSurface. Panel de historial de portapapeles usando cliphist.
 * - Muestra entradas de cliphist list (texto + imágenes)
 * - Click → copia al portapapeles (wl-copy) y cierra
 * - Búsqueda/filtro en tiempo real
 * - Navegación con teclado (↑/↓/Enter/Esc)
 * - Preview de imágenes en miniatura
 */
PillSurface {
    id: root
    mTop: Theme.marginMd; mLeft: Theme.marginMd; mRight: Theme.marginMd; mBottom: Theme.marginMd

    property string query: ""
    property var entries: []
    property int selectedIndex: 0
    property bool loading: true

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
        // Use cliphist to get clipboard history
        var process = Quickshell.Process.create()
        process.start("cliphist", ["list"])
        process.waitForFinished(2000)
        var output = process.readAllStandardOutput()
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
                var isImage = content.startsWith("[") && content.endsWith("]")
                parsed.push({
                    id: id,
                    text: isImage ? "" : content,
                    isImage: isImage,
                    preview: isImage ? content : content.substring(0, 100)
                })
            }
        }
        entries = parsed
        filteredEntries = parsed
        loading = false
        listView.currentIndex = 0
    }

    property var filteredEntries: []

    function filterEntries() {
        if (!query || query.trim().length === 0) {
            filteredEntries = entries
        } else {
            var lowerQuery = query.toLowerCase()
            filteredEntries = entries.filter(function(e) {
                return e.text.toLowerCase().indexOf(lowerQuery) >= 0
            })
        }
        listView.currentIndex = 0
    }

    function copyEntry(entry) {
        // Use cliphist to decode and copy
        var process = Quickshell.Process.create()
        if (entry.isImage) {
            process.start("cliphist", ["decode", entry.id])
            process.waitForFinished(1000)
            var imgData = process.readAllStandardOutput()
            // Write to wl-copy
            var copyProc = Quickshell.Process.create()
            copyProc.start("wl-copy", ["--type", "image/png"])
            copyProc.write(imgData)
            copyProc.closeWriteChannel()
            copyProc.waitForFinished(1000)
        } else {
            process.start("cliphist", ["decode", entry.id])
            process.waitForFinished(1000)
            var text = process.readAllStandardOutput()
            Quickshell.execDetached(["wl-copy", text.trim()])
        }
        root.requestClose()
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
            Behavior on border.color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

            MaterialIcon {
                anchors.left: parent.left
                anchors.leftMargin: 16 * root.s
                anchors.verticalCenter: parent.verticalCenter
                iconName: Icons.iSearch
                color: Theme.foreground
                font.pixelSize: Theme.fontSizeTitle * root.s
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 42 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: "Buscar en portapapeles…"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                visible: searchInput.text.length === 0 && !searchInput.activeFocus
            }

            IslaTextField {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 42 * root.s
                anchors.rightMargin: 14 * root.s
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                floating: false
                chrome: false
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
        ListView {
            id: listView
            width: parent.width
            height: loading ? 0 : (parent.height - searchBox.height - parent.spacing - hintRow.height - parent.spacing)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: Theme.spacingSm * root.s
            visible: !loading && filteredEntries.length > 0
            opacity: (!loading && filteredEntries.length > 0) ? 1 : 0
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
            Behavior on height { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }

            model: root.filteredEntries

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

                        // Image preview or text icon
                        Item {
                            width: clipDelegate.height - 8 * root.s
                            height: clipDelegate.height - 8 * root.s
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                anchors.fill: parent
                                visible: modelData.isImage
                                source: "cliphist decode " + modelData.id + " |" // This won't work directly, need process
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            MaterialIcon {
                                interaction: controlHit1.motion
                                anchors.centerIn: parent
                                visible: !modelData.isImage
                                iconName: Icons.iContentCopy
                                color: Theme.dim
                                font.pixelSize: Theme.fontSizeDisplay * root.s
                            }
                        }

                        // Text content
                        Item {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: clipDelegate.height + 4 * root.s

                            Column {
                                anchors.fill: parent
                                spacing: Theme.spacingXs * root.s

                                Text {
                                    transform: Translate { y: -Motion.labelTravel * controlHit1.motion.presence }
                                    text: modelData.isImage ? "[Imagen]" : modelData.preview
                                    color: modelData.isImage ? Theme.accent : Theme.foreground
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSizeBodyLg * root.s
                                    font.weight: modelData.isImage ? Font.DemiBold : Font.Medium
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                }

                                Text {
                                    transform: Translate { y: -Motion.labelTravel * controlHit1.motion.presence }
                                    visible: !modelData.isImage && modelData.text.length > modelData.preview.length
                                    text: modelData.text.substring(0, 150) + (modelData.text.length > 150 ? "…" : "")
                                    color: Theme.dim
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
            height: (!loading && filteredEntries.length === 0 && query.length > 0) ? 80 * root.s : 0
            visible: !loading && filteredEntries.length === 0 && query.length > 0
            opacity: visible ? 1 : 0
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }

            Text {
                anchors.centerIn: parent
                text: "Sin coincidencias"
                color: Theme.dim
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
            opacity: visible ? 1 : 0
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
                Item { Layout.fillWidth: true; height: 1 }
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
