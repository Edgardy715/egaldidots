import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import "../Singletons"
import "../components"

Popup {
    id: root
    objectName: "edotsPathPicker"
    parent: Overlay.overlay
    popupType: Popup.Item
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    width: Math.min(1000, parent ? parent.width - 48 : 900)
    height: Math.min(700, parent ? parent.height - 48 : 620)
    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? (parent.height - height) / 2 : 0
    padding: width < 700 ? 16 : 24
    property string title: ""
    property bool folderMode: false
    property string filterKind: "all"
    property url folder: "file:///"
    property url selectedUrl: ""
    property string selectedName: ""
    property bool selectedIsImage: false
    property bool selectedIsDirectory: false
    property url initialSelection: ""
    readonly property alias entryCount: files.count
    readonly property int modelStatus: files.status
    signal pathChosen(url value)

    function toUrl(path) { return "file://" + path.split("/").map(part => encodeURIComponent(part)).join("/") }
    function pathText(url) { return decodeURIComponent(String(url).slice(7)) }
    function navigate(url) {
        folder = url
        selectedUrl = ""; selectedName = ""; selectedIsImage = false; selectedIsDirectory = false
        grid.currentIndex = -1
        location.text = pathText(url)
    }
    function start(titleText, path, mode, kind) {
        title = titleText; folderMode = mode; filterKind = kind
        navigate(toUrl(mode ? path : path.slice(0, path.lastIndexOf("/")) || "/"))
        initialSelection = mode ? "" : toUrl(path)
        open()
        Qt.callLater(restoreSelection)
    }
    function restoreSelection() {
        if (!String(initialSelection) || files.status !== FolderListModel.Ready) return
        const index = files.indexOf(initialSelection)
        initialSelection = ""
        if (index >= 0) { grid.currentIndex = index; selectEntry(index, false); grid.positionViewAtIndex(index, GridView.Contain) }
    }
    function selectEntry(index, activate) {
        if (index < 0 || index >= files.count) return
        const url = files.get(index, "fileUrl")
        selectedIsDirectory = files.isFolder(index)
        if (selectedIsDirectory && activate) { navigate(url); return }
        selectedUrl = url
        selectedName = files.get(index, "fileName")
        selectedIsImage = !selectedIsDirectory && /\.(png|jpe?g|webp|svg|gif|bmp|avif)$/i.test(selectedName)
        if (activate) confirm()
    }
    function confirm() {
        const value = folderMode && !selectedIsDirectory ? folder : selectedUrl
        if (!String(value) || (!folderMode && selectedIsDirectory)) return
        pathChosen(value)
        close()
    }
    FolderListModel {
        id: files
        objectName: "pickerEntries"
        folder: root.visible ? root.folder : ""
        showFiles: !root.folderMode
        showDirsFirst: true
        showDotAndDotDot: false
        showOnlyReadable: true
        caseSensitive: false
        nameFilters: root.filterKind === "image" ? ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg", "*.gif", "*.bmp", "*.avif", "*.PNG", "*.JPG", "*.JPEG"]
            : root.filterKind === "json" ? ["*.json"] : ["*"]
        sortField: FolderListModel.Name
        sortCaseSensitive: false
        onStatusChanged: if (status === FolderListModel.Ready) root.restoreSelection()
    }
    background: Rectangle {
        radius: 24
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Qt.alpha(Theme.foreground, 0.18)
    }
    Overlay.modal: Rectangle { color: Qt.alpha(Theme.background, 0.65) }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Flags.reduceMotion ? 0 : Motion.fast }
            NumberAnimation { property: "scale"; from: Flags.reduceMotion ? 1 : 0.97; to: 1; duration: Flags.reduceMotion ? 0 : Motion.emphasized; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Flags.reduceMotion ? 0 : Motion.fast } }
    contentItem: ColumnLayout {
        spacing: 18
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.title; color: Theme.foreground; font.family: Theme.font; font.pixelSize: Theme.fontSizeHero; font.weight: Font.DemiBold }
                Text { visible: root.height >= 600; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.folderMode ? qsTr("Abre una carpeta y confirma tu elección.") : qsTr("Explora, revisa y elige tu archivo."); color: Qt.alpha(Theme.foreground, 0.72); font.family: Theme.font; font.pixelSize: Theme.fontSizeBody }
            }
            Item { Layout.fillWidth: true }
            EdotsButton { text: ""; symbol: "close"; implicitWidth: 44; Accessible.name: qsTr("Cancelar selección"); onClicked: root.close() }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            EdotsButton { text: ""; symbol: "arrow_upward"; implicitWidth: 44; enabled: String(root.folder) !== "file:///"; Accessible.name: qsTr("Carpeta superior"); onClicked: root.navigate(files.parentFolder) }
            EdotsTextField {
                id: location
                objectName: "pickerLocation"
                Layout.fillWidth: true
                Accessible.name: qsTr("Carpeta actual")
                onAccepted: {
                    const path = text.trim().replace(/^~(?=\/|$)/, Config.home)
                    if (path.startsWith("/")) { invalid = false; root.navigate(root.toUrl(path)) }
                    else invalid = true
                }
            }
            EdotsButton { text: ""; symbol: "visibility"; implicitWidth: 44; checkable: true; checked: files.showHidden; Accessible.name: qsTr("Mostrar archivos ocultos"); onClicked: files.showHidden = checked }
        }
        Text {
            Layout.fillWidth: true
            visible: location.invalid
            text: qsTr("Usa una ruta absoluta o que empiece por ~/.")
            color: Theme.error; font.family: Theme.font; font.pixelSize: Theme.fontSizeBody
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 18
            ColumnLayout {
                visible: root.width >= 700
                Layout.minimumWidth: Math.max(136, Theme.fontSizeBodyLg * 10); Layout.maximumWidth: Layout.minimumWidth; Layout.preferredWidth: Layout.minimumWidth; Layout.alignment: Qt.AlignTop; spacing: 8
                Repeater {
                    model: [{label: qsTr("Inicio"), path: Config.home, icon: "home"}, {label: qsTr("Imágenes"), path: Config.home + "/Imágenes", icon: "image"}, {label: qsTr("Descargas"), path: Config.home + "/Descargas", icon: "download"}, {label: qsTr("Wallpapers"), path: Config.wallpaperDir, icon: "wallpaper"}]
                    EdotsButton {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData.label; symbol: modelData.icon
                        accent: root.pathText(root.folder) === modelData.path
                        onClicked: root.navigate(root.toUrl(modelData.path))
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 180
                color: Qt.alpha(Theme.foreground, 0.025); radius: 16
                GridView {
                    id: grid
                    objectName: "pickerGrid"
                    anchors.fill: parent; anchors.margins: 10
                    clip: true
                    cellWidth: width / Math.max(1, Math.floor(width / 132))
                    cellHeight: 132
                    model: files
                    currentIndex: -1
                    onCurrentIndexChanged: if (currentIndex >= 0) root.selectEntry(currentIndex, false)
                    keyNavigationEnabled: true
                    ScrollBar.vertical: ScrollBar { }
                    Keys.onReturnPressed: root.selectEntry(currentIndex, true)
                    delegate: MotionButton {
                        id: entry
                        required property int index
                        required property string fileName
                        required property url fileUrl
                        required property bool fileIsDir
                        readonly property bool imageFile: !fileIsDir && /\.(png|jpe?g|webp|svg|gif|bmp|avif)$/i.test(fileName)
                        width: grid.cellWidth - 6; height: grid.cellHeight - 6
                        padding: 8
                        Accessible.name: fileName
                        onClicked: grid.currentIndex = index
                        onDoubleClicked: root.selectEntry(index, true)
                        background: Rectangle {
                            radius: 12
                            color: Qt.alpha(Theme.foreground, entry.hovered ? 0.075 : grid.currentIndex === entry.index ? 0.055 : 0)
                            border.width: 1
                            border.color: grid.currentIndex === entry.index || entry.activeFocus ? Theme.accent : "transparent"
                            Behavior on color { ColorAnimation { duration: Motion.hover } }
                        }
                        contentItem: ColumnLayout {
                            spacing: 8
                            Item {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                Image { id: thumb; anchors.fill: parent; source: entry.imageFile ? entry.fileUrl : ""; sourceSize: Qt.size(150, 150); fillMode: Image.PreserveAspectFit; asynchronous: true; opacity: status === Image.Ready ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } } }
                                EdotsIcon { anchors.centerIn: parent; visible: !entry.imageFile || thumb.status !== Image.Ready; iconName: entry.fileIsDir ? "folder" : "description"; color: entry.fileIsDir ? Theme.accent : Theme.foreground; font.pixelSize: 38; interaction: entry.interaction }
                            }
                            Text { Layout.fillWidth: true; text: entry.fileName; color: Theme.foreground; font.family: Theme.font; font.pixelSize: Theme.fontSizeBody; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle }
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent; width: parent.width - 32
                    visible: files.count === 0
                    text: files.status === FolderListModel.Loading ? qsTr("Cargando…") : qsTr("Carpeta vacía o no disponible.\nElige otra ubicación.")
                    color: Qt.alpha(Theme.foreground, 0.72); font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                }
            }
            ColumnLayout {
                visible: root.width >= 820 && Config.appearance.fontScale <= 1.35
                Layout.minimumWidth: root.width < 850 ? 180 : 230
                Layout.maximumWidth: root.width < 850 ? 180 : 230
                Layout.preferredWidth: root.width < 850 ? 180 : 230
                Layout.fillHeight: true; spacing: 12
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    radius: 16; color: Qt.alpha(Theme.foreground, 0.035)
                    Image {
                        id: preview
                        objectName: "pickerPreview"
                        anchors.fill: parent; anchors.margins: 14
                        source: root.visible && root.selectedIsImage ? root.selectedUrl : ""
                        sourceSize: Qt.size(640, 640)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
                    }
                    Column {
                        anchors.centerIn: parent; spacing: 12; width: parent.width - 32
                        visible: preview.status !== Image.Ready
                        EdotsIcon { anchors.horizontalCenter: parent.horizontalCenter; iconName: root.folderMode ? "folder" : root.selectedIsDirectory ? "folder" : root.selectedIsImage ? "image" : "description"; color: Theme.accent; font.pixelSize: 44 }
                        Text { width: parent.width; text: root.selectedIsImage ? (preview.status === Image.Error ? qsTr("No se puede mostrar esta imagen") : qsTr("Cargando imagen…")) : root.selectedName || qsTr("Vista previa"); color: Qt.alpha(Theme.foreground, 0.72); font.family: Theme.font; font.pixelSize: Theme.fontSizeBody; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap }
                    }
                }
                Text { Layout.fillWidth: true; text: root.selectedName || (root.folderMode ? root.pathText(root.folder).split("/").pop() || "/" : (root.filterKind === "image" ? qsTr("Selecciona una imagen") : qsTr("Selecciona un archivo"))); color: Theme.foreground; font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg; wrapMode: Text.Wrap }
                Text { Layout.fillWidth: true; visible: preview.status === Image.Ready; text: qsTr("Vista previa de la imagen"); color: Qt.alpha(Theme.foreground, 0.72); font.family: Theme.font; font.pixelSize: Theme.fontSizeBody }
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 10
            Text { visible: root.width >= 720; text: qsTr("%1 elementos").arg(files.count); color: Qt.alpha(Theme.foreground, 0.72); font.family: Theme.font; font.pixelSize: Theme.fontSizeBody }
            Item { Layout.fillWidth: true }
            EdotsButton { text: qsTr("Cancelar"); onClicked: root.close() }
            EdotsButton { objectName: "confirmPath"; text: root.folderMode ? qsTr("Elegir carpeta") : qsTr("Usar archivo"); symbol: "check"; accent: true; enabled: root.folderMode ? files.status === FolderListModel.Ready : String(root.selectedUrl).length > 0 && !root.selectedIsDirectory; onClicked: root.confirm() }
        }
    }
}
