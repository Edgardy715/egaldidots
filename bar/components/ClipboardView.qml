import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"
import "../Singletons"
import "."

FocusScope {
    id: root
    objectName: "clipboardView"
    property real s: 1
    property bool open: false
    property bool closing: false
    readonly property bool active: open && !closing
    property string query: ""
    property var entries: []
    property var filteredEntries: []
    property real pointerX: -1
    property real pointerY: -1
    property int selectedIndex: 0
    readonly property var selectedEntry: filteredEntries[selectedIndex] || null
    property bool loading: true
    property bool copying: false
    property bool clearing: false
    property string errorMessage: ""
    property var collections: []
    property string section: "history"
    property bool libraryBusy: false
    enabled: active
    property bool showingDetails: false
    property bool organizingOnly: false
    property var detailEntry: null
    property var textSources: ({})
    property var textFailures: ({})
    property real detailProgress: 0
    readonly property real listExposure: Math.max(0, 1 - detailProgress / 0.35)
    readonly property real readerExposure: Math.max(0, Math.min(1, (detailProgress - 0.35) / 0.65))
    Behavior on detailProgress {
        enabled: !Flags.reduceMotion
        SmoothedAnimation { id: detailTravel; duration: Motion.morph; velocity: -1; reversingMode: SmoothedAnimation.Eased }
    }
    Connections {
        target: Flags
        function onReduceMotionChanged() {
            if (Flags.reduceMotion) {
                root.detailProgress = root.showingDetails ? 1 : 0
            }
        }
    }
    signal textRequested(string entryId)
    property bool editingCollection: false
    property bool submittingCollection: false
    property string submittedName: ""
    property string editingCollectionId: ""
    signal sectionRequested(string sectionId)
    signal saveRequested(var entry, string collectionId)
    signal removeSavedRequested(var entry)
    signal moveRequested(var entry, string collectionId)
    signal createCollectionRequested(string name)
    signal renameCollectionRequested(string collectionId, string name)
    signal deleteCollectionRequested(string collectionId)
    property string previewDir: ""
    property var previewSources: ({})
    property var previewFailures: ({})
    signal requestClose()
    signal copyRequested(var entry)
    signal clearRequested()
    signal refreshRequested()
    signal historyConcealed()
    signal previewRequested(string entryId, bool selectedPreview)

    property string pendingSection: ""
    function chooseSection(id) {
        if (!active) return
        if (id === section) { pendingSection = ""; sectionMotion.shown = true; return }
        pendingSection = id
        sectionMotion.shown = false
    }
    ContentMotion {
        id: sectionMotion
        onConcealed: {
            if (root.pendingSection.length) {
                const destination = root.pendingSection
                root.pendingSection = ""
                root.sectionRequested(destination)
            }
            shown = true
        }
    }
    function openEntry(entry, organize) {
        if (!entry) return
        detailEntry = Object.assign({}, entry)
        organizingOnly = organize
        focusTimer.stop()
        if (!organize && !entry.isImage && !entry.saved) textRequested(entry.id)
        showingDetails = true
        details.activate(organize)
    }
    function restoreFocus() {
        if (showingDetails) details.focusDestination()
        else searchInput.forceActiveFocus()
    }
    function closeDetails() {
        showingDetails = false
        searchInput.forceActiveFocus()
    }
    function libraryResult(action, success, id) {
        if (!showingDetails || !detailEntry) return
        if (success && action === "remove") {
            closeDetails()
            return
        }
        if (success && action === "create" && id.length) {
            details.chosenCollectionId = id
            details.destinationChosen = true
            details.choosingCollection = false
        }
        if (success && (action === "save" || action === "move" || action === "remove")) {
            details.resultStatus = "success"
            const destination = details.destinations.find(c => c.id === details.chosenCollectionId)
            details.resultText = action === "remove" ? qsTr("Entrada retirada de Guardados") : qsTr("Guardado en %1").arg(destination ? destination.name : qsTr("Sin colección"))
        } else if (!success) {
            details.resultStatus = "error"
            details.resultText = qsTr("No se pudo guardar. Puedes reintentarlo.")
        }
    }
    onShowingDetailsChanged: {
        detailProgress = showingDetails ? 1 : 0
        if (showingDetails && !detailEntry && selectedEntry) openEntry(selectedEntry, false)
        else if (!showingDetails) searchInput.forceActiveFocus()
    }
    function copyEntry(entry) { copyRequested(entry) }
    function clearHistory() { clearRequested() }
    property string selectionId: ""
    onSelectedIndexChanged: selectionId = filteredEntries[selectedIndex] ? filteredEntries[selectedIndex].id : ""
    function resetSelection() { selectedIndex = 0; selectionId = filteredEntries[selectedIndex] ? filteredEntries[selectedIndex].id : "" }
    function editCollection(id) {
        submittingCollection = false
        editingCollectionId = id
        collectionName.text = ""
        for (const collection of collections)
            if (collection.id === id) collectionName.text = collection.name
        editingCollection = true
        collectionName.forceActiveFocus()
    }
    function finishCollectionEdit() {
        if (!collectionName.text.trim().length || libraryBusy) return
        submittedName = collectionName.text.trim()
        submittingCollection = true
        if (editingCollectionId.length) renameCollectionRequested(editingCollectionId, submittedName)
        else createCollectionRequested(submittedName)
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (editingCollection) { editingCollection = false; restoreFocus() }
            else if (showingDetails) closeDetails()
            else root.requestClose()
            event.accepted = true
        } else if (!editingCollection && !showingDetails && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
            move(event.key === Qt.Key_Up ? -1 : 1)
            event.accepted = true
        }
    }
    function resetQuery() { query = ""; searchInput.text = ""; resetSelection() }
    function concealHistory() { historyMotion.shown = false }
    function move(dir) {
        var n = filteredEntries.length
        if (!n) return
        var i = selectedIndex + dir
        if (i < 0) i = n - 1
        else if (i >= n) i = 0
        selectedIndex = i
        listView.positionViewAtIndex(i, ListView.Contain)
    }
    onFilteredEntriesChanged: {
        const previous = selectionId
        var found = -1
        for (var i = 0; i < filteredEntries.length; ++i) if (filteredEntries[i].id === previous) found = i
        selectedIndex = found >= 0 ? found : 0
        selectionId = filteredEntries[selectedIndex] ? filteredEntries[selectedIndex].id : ""
        if (detailEntry) {
            const updated = filteredEntries.find(e => e.id === detailEntry.id)
            if (updated) detailEntry = Object.assign({}, updated)
        }
    }
    onCollectionsChanged: {
        if (!submittingCollection) return
        const saved = collections.some(c => c.name === submittedName && (!editingCollectionId.length || c.id === editingCollectionId))
        if (saved) {
            submittingCollection = false
            editingCollection = false
            if (showingDetails) {
                const created = collections.find(c => c.name === submittedName)
                if (created) { details.chosenCollectionId = created.id; details.destinationChosen = true }
                details.choosingCollection = false
                details.focusDestination()
            } else searchInput.forceActiveFocus()
        }
    }
    onErrorMessageChanged: if (errorMessage.length) submittingCollection = false
    onClosingChanged: {
        if (closing) focusTimer.stop()
        else if (open) focusTimer.restart()
    }
    onOpenChanged: {
        if (open) {
            editingCollection = false
            showingDetails = false
            detailEntry = null
            resetQuery()
            focusTimer.restart()
        } else {
            pendingSection = ""
            sectionMotion.shown = true
        }
    }
    ContentMotion {
        id: historyMotion
        objectName: "clipboardHistoryMotion"
        onConcealed: {
            root.historyConcealed()
            shown = true
        }
    }

    // ── layout ────────────────────────────────────────────────
    Column {
        anchors.fill: parent
        spacing: 12 * root.s

        RowLayout {
            id: surfaceHeading
            width: parent.width
            height: Math.max(52, 34 * Flags.fontScale + 8) * root.s
            spacing: 12 * root.s
            Column {
                Layout.fillWidth: true
                spacing: 3 * root.s
                Text {
                    text: qsTr("Portapapeles")
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: 22 * Flags.fontScale * root.s
                    font.weight: Font.DemiBold
                }
                AnimatedLabel {
                    value: root.showingDetails ? (root.organizingOnly ? qsTr("Conserva lo que importa") : qsTr("Contenido completo")) : root.section === "history" ? qsTr("Listo para volver a copiar") : qsTr("Tu biblioteca, siempre a mano")
                    color: Theme.iconSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeBody * root.s
                }
            }
            ClipboardChip {
                text: qsTr("Colección")
                iconName: "add"
                helpText: qsTr("Crear una colección")
                s: root.s
                enabled: !root.libraryBusy && !root.editingCollection && !root.showingDetails
                onClicked: root.editCollection("")
            }
            ClipboardChip {
                objectName: "clipboardClearButton"
                iconName: root.clearing ? "hourglass_empty" : "delete_sweep"
                helpText: qsTr("Limpiar historial; conservar guardados")
                s: root.s
                enabled: !root.loading && !root.copying && !root.clearing && !root.libraryBusy && root.entries.length > 0 && !root.showingDetails
                onClicked: root.clearHistory()
            }
        }

        // ---- barra de búsqueda ----
        Rectangle {
            id: searchBox
            enabled: !root.editingCollection && !root.showingDetails
            width: parent.width
            height: 44 * root.s
            opacity: root.listExposure
            radius: Theme.radiusLg * root.s
            color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
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
                anchors.rightMargin: 50 * root.s
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                placeholderText: qsTr("Buscar en portapapeles…")
                motionActive: root.active && root.visible
                floating: false
                chrome: false
                Accessible.name: qsTr("Buscar en portapapeles")
                onTextChanged: {
                    root.query = text
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
                        if (root.showingDetails) root.showingDetails = false
                        else root.requestClose()
                        event.accepted = true
                    }
                }
            }
            ClipboardChip {
                anchors.right: parent.right
                anchors.rightMargin: 5 * root.s
                anchors.verticalCenter: parent.verticalCenter
                iconName: "close"
                helpText: qsTr("Borrar búsqueda")
                s: root.s
                visible: opacity > 0
                opacity: root.query.length ? 1 : 0
                enabled: root.query.length > 0
                Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
                onClicked: { root.resetQuery(); searchInput.forceActiveFocus() }
            }
        }

        RowLayout {
            id: sectionRow
            enabled: !root.editingCollection && !root.showingDetails
            width: parent.width
            height: 38 * root.s
            opacity: root.listExposure
            spacing: 8 * root.s
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                id: sectionsScroll
                objectName: "clipboardSectionsScroll"
                contentWidth: sectionButtons.width
                function scrollBy(direction) {
                    scrollMotion.stop()
                    scrollMotion.to = Math.max(0, Math.min(contentWidth - width, contentX + direction * width * 0.6))
                    scrollMotion.start()
                }
                NumberAnimation {
                    id: scrollMotion
                    target: sectionsScroll; property: "contentX"
                    duration: Flags.reduceMotion ? 0 : Motion.standardSmall
                    easing.type: Easing.OutCubic
                }
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Row {
                    id: sectionButtons
                    spacing: 6 * root.s
                    Repeater {
                        model: [{id: "history", name: qsTr("Recientes"), icon: "history"}, {id: "saved", name: qsTr("Guardados"), icon: "bookmark"}].concat(root.collections)
                        delegate: ClipboardChip {
                            required property var modelData
                            s: root.s
                            text: modelData.name
                            iconName: modelData.icon || "folder"
                            selected: root.section === modelData.id
                            enabled: !root.libraryBusy && !root.clearing
                            onClicked: { root.chooseSection(modelData.id); searchInput.forceActiveFocus() }
                        }
                    }
                }
            }
            ClipboardChip {
                iconName: "chevron_left"
                helpText: qsTr("Colecciones anteriores")
                s: root.s
                visible: sectionsScroll.contentWidth > sectionsScroll.width
                enabled: sectionsScroll.contentX > 1
                onClicked: sectionsScroll.scrollBy(-1)
            }
            ClipboardChip {
                iconName: "chevron_right"
                objectName: "clipboardCollectionsNext"
                helpText: qsTr("Más colecciones")
                s: root.s
                visible: sectionsScroll.contentWidth > sectionsScroll.width
                enabled: sectionsScroll.contentX < sectionsScroll.contentWidth - sectionsScroll.width - 1
                onClicked: sectionsScroll.scrollBy(1)
            }
            ClipboardChip {
                s: root.s
                text: qsTr("Editar")
                visible: root.section !== "history" && root.section !== "saved"
                enabled: !root.libraryBusy
                onClicked: root.editCollection(root.section)
            }
        }

        Item {
            id: body
            clip: true
            width: parent.width
            height: Math.max(0, parent.height - surfaceHeading.height - searchBox.height - sectionRow.height - hintRow.height - 4 * parent.spacing)

        Item {
            id: loadingItem
            width: parent.width
            height: parent.height
            visible: opacity > 0
            opacity: root.loading ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
            Accessible.role: Accessible.StaticText
            Accessible.name: qsTr("Cargando entradas del portapapeles")
            Column {
                width: parent.width
                spacing: 8 * root.s
                Repeater {
                    model: 3
                    delegate: Item {
                        required property int index
                        width: parent.width
                        height: 72 * root.s
                        Rectangle {
                            x: 12 * root.s; y: 12 * root.s
                            width: 48 * root.s; height: width
                            radius: 12 * root.s
                            color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
                        }
                        Rectangle {
                            x: 74 * root.s; y: 19 * root.s
                            width: parent.width * (index === 1 ? 0.42 : 0.56); height: 10 * root.s
                            radius: height / 2
                            color: Qt.alpha(Theme.foreground, Theme.alphaSoft)
                        }
                        Rectangle {
                            x: 74 * root.s; y: 42 * root.s
                            width: 76 * root.s; height: 7 * root.s
                            radius: height / 2
                            color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
                        }
                    }
                }
            }
        }

        // ---- listado de entradas ----
        MotionList {
            id: listView
            enabled: !root.editingCollection && !root.showingDetails
            scale: historyMotion.visualScale
            transform: Translate { y: historyMotion.offset * root.s }
            objectName: "clipboardList"
            width: parent.width
            height: parent.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: Theme.spacingSm * root.s
            visible: !loading && filteredEntries.length > 0
            opacity: (!loading && filteredEntries.length > 0) ? historyMotion.progress * root.listExposure * sectionMotion.progress : 0


            MouseArea {
                parent: listView
                anchors.fill: parent
                z: 10
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                onWheel: wheel => wheel.accepted = false
                onPositionChanged: mouse => {
                    const position = mapToGlobal(mouse.x, mouse.y)
                    const pointerX = Math.round(position.x)
                    const pointerY = Math.round(position.y)
                    const changed = pointerX !== root.pointerX || pointerY !== root.pointerY
                    root.pointerX = pointerX
                    root.pointerY = pointerY
                    if (!containsMouse || !changed || listView.moving) return
                    const index = listView.indexAt(mouse.x + listView.contentX, mouse.y + listView.contentY)
                    if (index >= 0) root.selectedIndex = index
                }
            }

            model: ScriptModel { values: root.filteredEntries }

            currentIndex: -1
            highlightRangeMode: ListView.NoHighlightRange

            delegate: ClipboardEntryRow {
                id: clipDelegate
                required property var modelData
                required property int index
                width: listView.width
                s: root.s
                entry: modelData
                selected: index === root.selectedIndex
                busy: root.copying || root.clearing || root.libraryBusy
                imageSource: root.previewSources[modelData.id + "|thumb"] || ""
                collectionName: (root.collections.find(c => c.id === modelData.collectionId) || {}).name || ""
                onScreen: root.active && !root.showingDetails && y + height > listView.contentY && y < listView.contentY + listView.height
                onThumbnailRequested: id => root.previewRequested(id, false)
                onCopyRequested: entry => { root.selectedIndex = index; root.copyRequested(entry) }
                onPreviewRequested: entry => { root.selectedIndex = index; root.openEntry(entry, false) }
                onOrganizeRequested: entry => { root.selectedIndex = index; root.openEntry(entry, true) }
            }
        }

        Item {
            id: emptyItem
            width: parent.width
            height: parent.height
            readonly property bool presented: !root.showingDetails && !root.loading && root.filteredEntries.length === 0
            visible: emptyMotion.progress > 0
            enabled: presented
            opacity: emptyMotion.progress
            scale: emptyMotion.visualScale
            transform: Translate { y: emptyMotion.offset * root.s }
            ContentMotion { id: emptyMotion; shown: emptyItem.presented }
            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - 24 * root.s, 360 * root.s)
                spacing: 12 * root.s
                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    iconName: root.query.length ? "search" : root.section === "history" ? "content_paste" : "bookmark"
                    font.pixelSize: 38 * root.s
                    color: Theme.accent
                    Accessible.ignored: true
                }
                Text {
                    width: parent.width
                    text: root.query.length ? qsTr("Sin coincidencias") : root.section === "history" ? qsTr("Todo empieza con una copia") : qsTr("Un lugar para lo que quieres conservar")
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeTitle * root.s
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: root.query.length ? qsTr("Prueba con otro texto o vuelve a ver todas las entradas.") : root.section === "history" ? qsTr("Copia texto, un enlace o una imagen y aparecerá aquí.") : qsTr("Usa Guardar en una entrada reciente y elige su colección.")
                    color: Theme.iconSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeBody * root.s
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                ClipboardChip {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.query.length ? qsTr("Borrar búsqueda") : root.section === "history" ? qsTr("Actualizar") : qsTr("Ver recientes")
                    iconName: root.query.length ? "close" : root.section === "history" ? "refresh" : "history"
                    s: root.s
                    onClicked: {
                        if (root.query.length) { root.resetQuery(); searchInput.forceActiveFocus() }
                        else if (root.section === "history") root.refreshRequested()
                        else root.chooseSection("history")
                    }
                }
            }
        }

        ClipboardDetails {
            id: details
            objectName: "clipboardDetails"
            parent: root
            z: 11
            x: 0
            y: surfaceHeading.height + 12 * root.s
            width: root.width
            height: root.height - surfaceHeading.height - hintRow.height - 24 * root.s
            organizerPage: root.organizingOnly
            visible: root.detailProgress > 0
            opacity: root.readerExposure
            transform: Translate { y: Flags.reduceMotion ? 0 : 24 * root.s * (1 - root.detailProgress) }
            enabled: root.showingDetails && !root.editingCollection
            s: root.s
            entry: root.detailEntry
            collections: root.collections
            busy: root.libraryBusy || root.copying || root.clearing
            initialCollectionId: root.section === "history" || root.section === "saved" ? "" : root.section
            fullText: !root.detailEntry ? "" : root.textSources[root.detailEntry.id] !== undefined ? root.textSources[root.detailEntry.id] : root.detailEntry.text
            textLoading: !!root.detailEntry && !root.detailEntry.isImage && !root.detailEntry.saved && root.textSources[root.detailEntry.id] === undefined && !root.textFailures[root.detailEntry.id]
            textFailed: !root.organizingOnly && !!root.detailEntry && !root.detailEntry.isImage && !!root.textFailures[root.detailEntry.id]
            previewSources: root.previewSources
            previewFailures: root.previewFailures
            active: root.active && root.showingDetails
            onBackRequested: root.closeDetails()
            onNewCollectionRequested: root.editCollection("")
            onPreviewRequested: (id, full) => root.previewRequested(id, full)
            onCopyRequested: entry => root.copyRequested(entry)
            onSaveRequested: (entry, collectionId) => root.saveRequested(entry, collectionId)
            onRemoveRequested: entry => root.removeSavedRequested(entry)
            onMoveRequested: (entry, collectionId) => root.moveRequested(entry, collectionId)
        }

        Rectangle {
            parent: root
            z: 20
            x: 0; y: surfaceHeading.height + 12 * root.s
            width: root.width; height: root.height - y - hintRow.height
            radius: Theme.radiusLg * root.s
            color: Theme.background
            visible: opacity > 0
            enabled: root.editingCollection
            opacity: root.editingCollection ? 1 : 0
            scale: root.editingCollection ? 1 : 0.97
            Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast } }
            Behavior on scale { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
            Column {
                anchors.fill: parent
                anchors.margins: 16 * root.s
                spacing: 16 * root.s
                Text {
                    text: root.editingCollectionId.length ? qsTr("Editar colección") : qsTr("Nueva colección")
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: 20 * Flags.fontScale * root.s
                    font.weight: Font.DemiBold
                }
                IslaTextField {
                    id: collectionName
                    objectName: "clipboardCollectionName"
                    width: parent.width
                    height: 44 * root.s
                    floating: false
                    placeholderText: qsTr("Nombre de la colección")
                    Accessible.name: placeholderText
                    maximumLength: 64
                    Keys.onReturnPressed: root.finishCollectionEdit()
                    Keys.onEnterPressed: root.finishCollectionEdit()
                }
                Row {
                    spacing: 8 * root.s
                    ClipboardChip { s: root.s; text: qsTr("Guardar"); prominent: true; enabled: collectionName.text.trim().length > 0 && !root.libraryBusy; onClicked: root.finishCollectionEdit() }
                    ClipboardChip { s: root.s; text: qsTr("Cancelar"); onClicked: { root.editingCollection = false; restoreFocus() } }
                    ClipboardChip {
                        s: root.s; text: qsTr("Eliminar colección"); visible: root.editingCollectionId.length > 0
                        enabled: !root.libraryBusy
                        onClicked: { root.deleteCollectionRequested(root.editingCollectionId); root.editingCollection = false; restoreFocus() }
                    }
                }
                AnimatedLabel {
                    width: parent.width
                    value: root.errorMessage && collectionName.text.trim() === root.submittedName ? root.errorMessage : root.editingCollectionId.length ? qsTr("Al eliminar una colección, su contenido permanece en Guardados.") : qsTr("Elige un nombre para reunir texto, enlaces e imágenes.")
                    wrapMode: Text.WordWrap
                    color: Theme.iconSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeSmall * root.s
                }
            }
        }
        }

        // ---- hint de teclado ----
        Item {
            id: hintRow
            width: parent.width
            height: 30 * root.s
            visible: true
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

            ContentMotion { id: errorMotion; shown: root.errorMessage.length > 0 }
            Text {
                anchors.fill: parent
                opacity: errorMotion.progress
                transform: Translate { y: errorMotion.offset * root.s }
                verticalAlignment: Text.AlignVCenter
                text: root.errorMessage
                visible: errorMotion.progress > 0
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall * root.s
                wrapMode: Text.WordWrap
                Accessible.role: Accessible.AlertMessage
            }

            RowLayout {
                id: keycapRow
                visible: opacity > 0
                opacity: 1 - errorMotion.progress
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Theme.spacingMd * root.s

                AnimatedLabel {
                    value: root.filteredEntries.length === 1 ? qsTr("1 elemento") : qsTr("%1 elementos").arg(root.filteredEntries.length)
                    color: Theme.iconSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeSmall * root.s
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.showingDetails ? qsTr("Esc · volver") : qsTr("Clic o Enter · copiar")
                    color: Theme.iconSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeSmall * root.s
                }
            }
        }
    }

    // timer inicial para girar foco
    Timer {
        id: focusTimer
        interval: Motion.morph + 60
        repeat: false
        onTriggered: if (root.active && !root.editingCollection && !root.showingDetails) searchInput.forceActiveFocus()
    }
}
