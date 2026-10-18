import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../Singletons"

FocusScope {
    id: root
    property real s: 1
    property var entry: null
    property var collections: []
    property bool busy: false
    property bool active: false
    property bool organizerPage: false
    property bool destinationChosen: false
    property string initialCollectionId: ""
    property string chosenCollectionId: ""
    property bool choosingCollection: false
    property int collectionIndex: 0
    property string fullText: ""
    property bool textLoading: false
    property bool textFailed: false
    property var previewSources: ({})
    property var previewFailures: ({})
    property string resultStatus: ""
    property string resultText: ""
    readonly property var destinations: collections.concat([{id: "", name: qsTr("Sin colección")}])
    readonly property bool savedHere: destinationChosen && !!entry && !!entry.saved && (entry.collectionId || "") === chosenCollectionId
    signal previewRequested(string entryId, bool full)
    signal copyRequested(var entry)
    signal saveRequested(var entry, string collectionId)
    signal removeRequested(var entry)
    signal moveRequested(var entry, string collectionId)
    signal backRequested()
    signal newCollectionRequested()

    function showCollections() {
        if (busy) return
        if (organizerPage) { focusDestination(); return }
        collectionIndex = destinationChosen ? Math.max(0, destinations.findIndex(c => c.id === chosenCollectionId)) : 0
        choosingCollection = true
        choices.forceActiveFocus()
        Qt.callLater(() => choices.positionViewAtIndex(collectionIndex, ListView.Contain))
    }
    function chooseCollection(index) {
        if (index < 0 || index >= destinations.length) return
        collectionIndex = index
        chosenCollectionId = destinations[index].id
        destinationChosen = true
        resultStatus = ""
        resultText = ""
        choosingCollection = false
        if (organizerPage) choices.forceActiveFocus()
        else destination.forceActiveFocus()
    }
    function focusDestination() {
        if (!organizerPage) { destination.forceActiveFocus(); return }
        Qt.callLater(function() {
            if (!root.active) return
            root.collectionIndex = root.destinationChosen ? Math.max(0, root.destinations.findIndex(c => c.id === root.chosenCollectionId)) : 0
            choices.forceActiveFocus()
            choices.positionViewAtIndex(root.collectionIndex, ListView.Contain)
        })
    }
    function activate(organize) {
        chosenCollectionId = entry && entry.saved ? (entry.collectionId || "") : initialCollectionId
        destinationChosen = !!entry && !!entry.saved || initialCollectionId.length > 0 || collections.length === 0
        collectionIndex = destinationChosen ? Math.max(0, destinations.findIndex(c => c.id === chosenCollectionId)) : 0
        choosingCollection = false
        resultStatus = ""
        resultText = ""
        previewScroll.contentItem.contentY = 0
        Qt.callLater(function() {
            if (!root.active) return
            if (organizerPage) choices.forceActiveFocus()
            else if (organize) destination.forceActiveFocus()
            else previewScroll.forceActiveFocus()
        })
    }
    ContentMotion { id: previewMotion; shown: root.active && !root.organizerPage }
    function ensurePreview() { if (active && !organizerPage && entry && entry.isImage) previewRequested(entry.id, true) }
    function commit() {
        if (!entry || busy || choosingCollection || savedHere || !destinationChosen) return
        resultStatus = ""
        resultText = ""
        if (entry.saved) moveRequested(entry, chosenCollectionId)
        else saveRequested(entry, chosenCollectionId)
    }
    onEntryChanged: ensurePreview()
    onCollectionsChanged: if (chosenCollectionId.length && !collections.some(c => c.id === chosenCollectionId)) chosenCollectionId = ""
    onBusyChanged: if (!busy) ensurePreview()
    onActiveChanged: ensurePreview()
    onOrganizerPageChanged: ensurePreview()
    Keys.onEscapePressed: event => { if (choosingCollection) { choosingCollection = false; focusDestination() } else backRequested(); event.accepted = true }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.organizerPage ? 8 * root.s : 10 * root.s
        RowLayout {
            id: header
            Layout.fillWidth: true
            Layout.preferredHeight: 42 * root.s
            ClipboardChip { s: root.s; text: qsTr("Volver"); visible: true; implicitHeight: 36 * root.s; onClicked: { if (root.choosingCollection) { root.choosingCollection = false; focusDestination() } else root.backRequested() } }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                AnimatedLabel {
                    Layout.fillWidth: true
                    value: root.organizerPage && root.resultStatus === "success" ? qsTr("Entrada guardada") : root.choosingCollection ? qsTr("Elegir colección") : root.organizerPage ? (root.entry && root.entry.saved ? qsTr("Mover a una colección") : qsTr("Guardar entrada")) : root.entry && root.entry.isImage ? qsTr("Imagen") : qsTr("Texto")
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeTitle * root.s
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: !!root.entry && !root.choosingCollection && !root.organizerPage
                    text: root.entry && root.entry.isImage ? qsTr("Imagen del portapapeles") : root.entry ? String(root.entry.text || "").replace(/\s+/g, " ") : ""
                    color: Theme.iconSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeSmall * root.s
                    elide: Text.ElideRight
                }
            }
            ClipboardChip {
                s: root.s
                text: qsTr("Copiar")
                objectName: "clipboardDetailCopy"
                visible: !root.organizerPage && !root.choosingCollection
                enabled: visible && !!root.entry && !root.busy
                implicitHeight: 36 * root.s
                selected: true
                onClicked: root.copyRequested(root.entry)
            }
        }
        RowLayout {
            id: entrySummary
            visible: root.organizerPage
            Layout.fillWidth: true
            Layout.preferredHeight: 66 * root.s
            spacing: 12 * root.s
            Rectangle {
                Layout.preferredWidth: 48 * root.s
                Layout.preferredHeight: 48 * root.s
                radius: 12 * root.s
                color: Qt.alpha(Theme.accent, Theme.alphaFaint)
                Image {
                    anchors.fill: parent; anchors.margins: 3 * root.s
                    source: root.entry ? root.previewSources[root.entry.id + "|thumb"] || "" : ""
                    sourceSize: Qt.size(144,144)
                    asynchronous: true; fillMode: Image.PreserveAspectFit
                    visible: !!root.entry && root.entry.isImage
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !!root.entry && !root.entry.isImage
                    iconName: "description"; color: Theme.accent
                    font.pixelSize: 24 * root.s
                    Accessible.ignored: true
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4 * root.s
                Text {
                    Layout.fillWidth: true
                    text: !root.entry ? "" : root.entry.isImage ? qsTr("Imagen copiada") : root.entry.preview
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.foreground; font.family: Theme.font
                    font.pixelSize: Theme.fontSizeBodyLg * root.s
                    font.weight: Font.Medium
                }
                Text {
                    text: qsTr("Elige dónde quieres conservarla")
                    color: Theme.iconSecondary; font.family: Theme.font
                    font.pixelSize: Theme.fontSizeBody * root.s
                }
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
        ScrollView {
            id: previewScroll
            objectName: "clipboardPreviewScroll"
            anchors.fill: parent
            visible: !root.organizerPage
            enabled: !root.choosingCollection && !root.organizerPage
            opacity: root.choosingCollection ? 0 : 1
            Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast } }
            clip: true
            contentWidth: availableWidth
            Keys.onUpPressed: event => { contentItem.contentY = Math.max(0, contentItem.contentY - 40 * root.s); event.accepted = true }
            Keys.onDownPressed: event => { contentItem.contentY = Math.min(Math.max(0, contentItem.contentHeight - contentItem.height), contentItem.contentY + 40 * root.s); event.accepted = true }
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.vertical.contentItem: Rectangle {
                implicitWidth: 4 * root.s
                radius: width / 2
                color: Qt.alpha(Theme.foreground, 0.35)
            }
            Item {
                width: previewScroll.availableWidth
                implicitHeight: root.entry && root.entry.isImage ? Math.max(120 * root.s, previewScroll.availableHeight) : Math.max(previewScroll.availableHeight, textPreview.implicitHeight + 12 * root.s)
                Image {
                    id: imagePreview
                    objectName: "clipboardSelectedPreview"
                    anchors.fill: parent
                    visible: !!root.entry && root.entry.isImage
                    source: root.entry ? root.previewSources[root.entry.id + "|full"] || "" : ""
                    sourceSize: Qt.size(768, 320)
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    scale: Flags.reduceMotion ? 1 : 0.96 + 0.04 * previewMotion.progress
                    opacity: status === Image.Ready ? previewMotion.progress : 0
                    Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.standard } }
                }
                TextEdit {
                    id: textPreview
                    objectName: "clipboardFullText"
                    width: parent.width - 12 * root.s
                    visible: !!root.entry && !root.entry.isImage
                    text: root.textLoading ? qsTr("Cargando texto…") : root.fullText
                    textFormat: TextEdit.PlainText
                    opacity: previewMotion.progress
                    transform: Translate { y: Flags.reduceMotion ? 0 : 6 * root.s * (1 - previewMotion.progress) }
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: Theme.foreground
                    selectionColor: Qt.alpha(Theme.accent, Theme.alphaSelected)
                    selectedTextColor: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeBodyLg * root.s
                    Accessible.name: qsTr("Contenido completo de la entrada")
                }
                Text {
                    anchors.centerIn: parent
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: !!root.entry && root.entry.isImage && (!!root.previewFailures[root.entry.id + "|full"] || imagePreview.status === Image.Error)
                    text: qsTr("No se pudo cargar la imagen. Puedes copiarla o volver a la lista.")
                    color: Theme.iconSecondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeBody * root.s
                }
            }
        }
        }
        RowLayout {
            id: feedback
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 22 * root.s : 0
            visible: root.busy || root.resultStatus.length > 0 || root.textFailed
            spacing: 6 * root.s
            ConfirmationIndicator {
                s: root.s
                Layout.preferredWidth: 20 * root.s
                Layout.preferredHeight: 20 * root.s
                visible: root.active && (root.busy || root.resultStatus.length > 0)
                status: root.busy ? "busy" : root.resultStatus
            }
            AnimatedLabel {
                Layout.fillWidth: true
                value: root.busy ? qsTr("Guardando…") : root.resultText.length ? root.resultText : root.textFailed ? qsTr("No se pudo leer todo el texto. Vuelve a abrir esta entrada.") : ""
                color: root.resultStatus === "error" || root.textFailed ? Theme.error : Theme.iconSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall * root.s
                elide: Text.ElideRight
                Accessible.role: Accessible.StaticText
            }
        }
        RowLayout {
            id: destinationRow
            visible: !root.organizerPage
            Layout.fillWidth: true
            Layout.preferredHeight: 42 * root.s
            spacing: 8 * root.s
            MotionButton {
                id: destination
                objectName: "clipboardDestination"
                Layout.fillWidth: true
                Layout.preferredHeight: 42 * root.s
                enabled: !root.busy && !root.choosingCollection
                Accessible.name: qsTr("Colección de destino")
                onClicked: root.showCollections()
                Keys.onDownPressed: root.showCollections()
                background: Rectangle {
                    radius: Theme.radiusSm * root.s
                    color: Qt.alpha(Theme.foreground, destination.hovered ? Theme.alphaSoft : Theme.alphaFaint)
                    border.width: destination.activeFocus ? Math.max(1, Theme.borderHairline * root.s) : 0
                    border.color: Theme.accent
                    Behavior on color { enabled: !Flags.reduceMotion; ColorAnimation { duration: Motion.hover } }
                }
                contentItem: RowLayout {
                    spacing: 8 * root.s
                    Text {
                        Layout.leftMargin: 12 * root.s
                        text: qsTr("En")
                        color: Theme.iconSecondary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeSmall * root.s
                    }
                    Text {
                        Layout.fillWidth: true
                        objectName: "clipboardDestinationLabel"
                        text: root.destinationChosen ? (root.destinations.find(c => c.id === root.chosenCollectionId) || root.destinations[0]).name : qsTr("Elegir colección")
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeBody * root.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    MaterialIcon {
                        Layout.rightMargin: 12 * root.s
                        iconName: "expand_more"
                        font.pixelSize: 18 * root.s
                        color: Theme.foreground
                        rotation: root.choosingCollection ? 180 : 0
                        Behavior on rotation { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                    }
                }
            }
            ClipboardChip {
                s: root.s
                text: qsTr("Nueva colección")
                objectName: "clipboardDetailNewCollection"
                visible: !root.choosingCollection
                enabled: visible && !root.busy
                implicitHeight: 42 * root.s
                onClicked: root.newCollectionRequested()
            }
        }
        RowLayout {
            id: footer
            Layout.fillWidth: true
            Layout.preferredHeight: 38 * root.s
            spacing: 8 * root.s
            ClipboardChip {
                s: root.s
                text: qsTr("Quitar de guardados")
                visible: !root.organizerPage && !!root.entry && !!root.entry.saved
                enabled: visible && !root.busy && !root.choosingCollection
                onClicked: root.removeRequested(root.entry)
            }
            ClipboardChip {
                objectName: "clipboardOrganizerNewCollection"
                s: root.s
                text: qsTr("Nueva colección")
                iconName: "add"
                visible: root.organizerPage
                enabled: !root.busy
                onClicked: root.newCollectionRequested()
            }
            Item { Layout.fillWidth: true }
            ClipboardChip {
                s: root.s
                text: qsTr("Cancelar")
                visible: root.organizerPage
                implicitHeight: 38 * root.s
                onClicked: root.backRequested()
            }
            ClipboardChip {
                objectName: "clipboardSaveButton"
                s: root.s
                text: root.savedHere ? qsTr("Guardado aquí") : !root.destinationChosen ? qsTr("Elige un destino") : root.chosenCollectionId.length ? qsTr("%1 en %2").arg(root.entry && root.entry.saved ? qsTr("Mover") : qsTr("Guardar")).arg((root.destinations.find(c => c.id === root.chosenCollectionId) || {}).name || "") : qsTr("Guardar sin colección")
                prominent: true
                Layout.maximumWidth: root.width * 0.58
                implicitHeight: 38 * root.s
                enabled: !!root.entry && !root.busy && !root.choosingCollection && !root.savedHere && root.destinationChosen
                onClicked: root.commit()
            }
        }
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: header.height + (root.organizerPage ? entrySummary.height + 24 * root.s : 4 * root.s)
        anchors.bottomMargin: footer.height + (feedback.visible ? feedback.height + 12 * root.s : 0) + 12 * root.s
        radius: Theme.radiusSm * root.s
        color: root.organizerPage ? "transparent" : Theme.background
        visible: opacity > 0
        enabled: root.organizerPage || root.choosingCollection
        opacity: root.organizerPage || root.choosingCollection ? 1 : 0
        Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast } }
        MotionList {
            id: choices
            anchors.fill: parent
            anchors.margins: 3 * root.s
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: root.collectionIndex
            model: root.destinations
            spacing: 4 * root.s
            Keys.onUpPressed: { root.collectionIndex = Math.max(0, root.collectionIndex - 1); positionViewAtIndex(root.collectionIndex, ListView.Contain) }
            Keys.onDownPressed: { root.collectionIndex = Math.min(count - 1, root.collectionIndex + 1); positionViewAtIndex(root.collectionIndex, ListView.Contain) }
            Keys.onReturnPressed: root.chooseCollection(root.collectionIndex)
            Keys.onEnterPressed: root.chooseCollection(root.collectionIndex)
            delegate: MotionButton {
                required property var modelData
                required property int index
                objectName: "clipboardDestinationOption" + index
                width: choices.width
                height: 48 * root.s
                highlighted: choices.activeFocus && index === root.collectionIndex
                Accessible.name: modelData.name
                onClicked: root.chooseCollection(index)
                background: Rectangle {
                    radius: Theme.radiusSm * root.s
                    color: Qt.alpha(root.destinationChosen && modelData.id === root.chosenCollectionId ? Theme.accent : Theme.foreground, root.destinationChosen && modelData.id === root.chosenCollectionId ? Theme.alphaSelected : parent.hovered || parent.highlighted ? Theme.alphaSoft : Theme.alphaFaint)
                    Behavior on color { enabled: !Flags.reduceMotion; ColorAnimation { duration: Motion.hover } }
                }
                contentItem: RowLayout {
                    spacing: 8 * root.s
                    MaterialIcon {
                        Layout.leftMargin: 12 * root.s
                        iconName: modelData.id.length ? "folder" : "bookmark"
                        color: Theme.accent; font.pixelSize: 20 * root.s
                        Accessible.ignored: true
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4 * root.s
                        text: modelData.name
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeBody * root.s
                        elide: Text.ElideRight
                    }
                    MaterialIcon {
                        Layout.rightMargin: 12 * root.s
                        iconName: "check"
                        font.pixelSize: 18 * root.s
                        color: Theme.accent
                        opacity: root.destinationChosen && modelData.id === root.chosenCollectionId ? 1 : 0
                        scale: opacity > 0 ? 1 : 0.7
                        Behavior on opacity { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast } }
                        Behavior on scale { enabled: !Flags.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                    }
                }
            }
        }
    }
}
