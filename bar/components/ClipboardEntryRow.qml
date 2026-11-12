import QtQuick
import "../Singletons"

Item {
    id: root
    required property var entry
    property real s: 1
    property bool selected: false
    property bool busy: false
    property string imageSource: ""
    property string collectionName: ""
    property bool onScreen: false
    readonly property bool isLink: !entry.isImage && /^https?:\/\//i.test(entry.text)
    property real selectionProgress: selected ? 1 : 0
    Behavior on selectionProgress { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.hover; velocity: -1 } }
    signal copyRequested(var entry)
    signal previewRequested(var entry)
    signal organizeRequested(var entry)
    signal thumbnailRequested(string entryId)
    // Las acciones aparecen al apuntar o seleccionar la fila: cinco pares de
    // botones idénticos competían con el contenido. Su hueco queda reservado
    // para que el texto no se reacomode al revelarlas.
    HoverHandler { id: rowHover }
    property real actionsShown: rowHover.hovered || selected || previewChip.activeFocus || saveChip.activeFocus ? 1 : 0
    Behavior on actionsShown { SmoothedAnimation { duration: Flags.reduceMotion ? 0 : Motion.hover; velocity: -1 } }
    height: Math.max(72 * s, (Theme.fontSizeBodyLg * 2 + Theme.fontSizeSmall + 22) * s)
    objectName: "clipboardRow"
    onOnScreenChanged: if (onScreen && entry.isImage) thumbnailRequested(entry.id)
    Component.onCompleted: if (onScreen && entry.isImage) thumbnailRequested(entry.id)

    Rectangle {
        anchors.fill: parent
        scale: copyArea.motion.visualScale
        radius: Theme.radiusLg * root.s
        color: Qt.alpha(Theme.accent, Theme.alphaWash * root.selectionProgress + 0.035 * copyArea.motion.presence)
        border.color: Qt.alpha(Theme.accent, 0.22 * root.selectionProgress)
        border.width: Theme.borderHairline
    }
    Rectangle {
        id: thumbnail
        x: 12 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: 48 * root.s
        height: width
        radius: 12 * root.s
        color: Qt.alpha(root.entry.isImage ? Theme.foreground : Theme.accent, Theme.alphaFaint + 0.045 * root.selectionProgress)
        scale: copyArea.motion.visualScale * (Flags.reduceMotion ? 1 : 1 + 0.035 * root.selectionProgress)
        Image {
            anchors.fill: parent
            anchors.margins: 3 * root.s
            source: root.imageSource
            sourceSize: Qt.size(144, 144)
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            objectName: "clipboardThumbnail"
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.standardSmall } }
        }
        MaterialIcon {
            anchors.centerIn: parent
            visible: !root.entry.isImage || !root.imageSource.length
            iconName: root.entry.isImage ? "image" : root.isLink ? "link" : "description"
            interaction: copyArea.motion
            color: Theme.accent
            font.pixelSize: 23 * root.s
            Accessible.ignored: true
        }
    }
    Column {
        x: 74 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, actions.x - x - 14 * root.s)
        spacing: 6 * root.s
        Text {
            width: parent.width
            objectName: "clipboardEntryLabel"
            text: root.entry.isImage ? I18n.tr("Imagen copiada") : root.entry.preview.replace(/\s+/g, " ").replace(/[\u202A-\u202E\u2066-\u2069]/g, "")
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeBodyLg * root.s
            font.weight: Font.Medium
        }
        AnimatedLabel {
            width: parent.width
            value: root.entry.saved ? (root.collectionName.length ? I18n.tr("En %1").arg(root.collectionName) : I18n.tr("Guardado")) : root.entry.isImage ? I18n.tr("Imagen") : root.isLink ? I18n.tr("Enlace") : I18n.tr("Texto")
            color: root.entry.saved ? Theme.accent : Theme.iconSecondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeSmall * root.s
            elide: Text.ElideRight
        }
    }
    MotionArea {
        id: copyArea
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: actions.left
        enabled: !root.busy
        hoverWash: false
        accessibleName: I18n.tr("Copiar %1").arg(root.entry.isImage ? I18n.tr("imagen") : root.entry.preview.replace(/[\u202A-\u202E\u2066-\u2069]/g, ""))
        onClicked: root.copyRequested(root.entry)
    }
    Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: 12 * root.s
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8 * root.s
        opacity: root.actionsShown
        transform: Translate { x: 6 * root.s * (1 - root.actionsShown) }
        ClipboardChip {
            id: previewChip
            objectName: "clipboardRowPreview"
            s: root.s
            iconName: "visibility"
            helpText: I18n.tr("Ver contenido completo")
            enabled: !root.busy
            onClicked: root.previewRequested(root.entry)
        }
        ClipboardChip {
            id: saveChip
            objectName: "clipboardRowSave"
            s: root.s
            text: root.entry.saved ? I18n.tr("Organizar") : I18n.tr("Guardar")
            iconName: root.entry.saved ? "check" : "add"
            morphIcon: true
            selected: !!root.entry.saved
            enabled: !root.busy
            onClicked: root.organizeRequested(root.entry)
        }
    }
}
