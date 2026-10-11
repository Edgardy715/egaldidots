pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../"
import "../Singletons"
import "LyricsData.js" as LyricsData

ColumnLayout {
    id: root
    property real s: 1
    property string title: ""
    property string artist: ""
    property string status: "idle"
    property bool synced: false
    property var lines: []
    property real position: 0
    property bool following: true
    readonly property int lineIndex: synced ? LyricsData.indexAt(lines, position) : -1
    signal retryRequested()
    signal closeRequested()
    spacing: 8 * s
    onLinesChanged: { following = true; lyrics.positionViewAtBeginning() }
    onVisibleChanged: if (visible) lyrics.forceActiveFocus()
    Keys.onEscapePressed: root.closeRequested()

    RowLayout {
        Layout.fillWidth: true
        spacing: 12 * root.s
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 3 * root.s
            Text {
                Layout.fillWidth: true
                text: root.title
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: Theme.fontMedia
                font.pixelSize: Theme.fontSizeTitleLg * root.s
                font.weight: Font.DemiBold
                color: Theme.foreground
            }
            Text {
                Layout.fillWidth: true
                text: root.synced ? qsTr("Letra sincronizada · LRCLIB") : qsTr("Letras · LRCLIB")
                color: Theme.iconSecondary
                font.family: Theme.fontMedia
                font.pixelSize: Theme.fontSizeSmall * root.s
                elide: Text.ElideRight
            }
        }
        CtrlBtn {
            visible: root.synced && root.status === "ready"
            iconName: "my_location"
            accessibleName: qsTr("Seguir la reproducción")
            active: root.following
            size: 32; s: root.s
            onClicked: { root.following = true; lyrics.positionViewAtIndex(Math.max(0, root.lineIndex), ListView.Center) }
        }
        CtrlBtn { iconName: "close"; accessibleName: qsTr("Volver a la portada"); size: 32; s: root.s; onClicked: root.closeRequested() }
    }
    ListView {
        id: lyrics
        objectName: "mediaLyricsList"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        visible: root.status === "ready"
        clip: true
        spacing: 10 * root.s
        model: root.lines
        activeFocusOnTab: true
        currentIndex: root.following ? root.lineIndex : -1
        preferredHighlightBegin: height * 0.32
        preferredHighlightEnd: height * 0.68
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: Flags.reduceMotion ? 0 : Motion.standardSmall
        onDraggingChanged: if (dragging) root.following = false
        Keys.onUpPressed: { root.following = false; contentY = Math.max(0, contentY - 50 * root.s) }
        Keys.onDownPressed: { root.following = false; contentY = Math.min(Math.max(0, contentHeight - height), contentY + 50 * root.s) }
        WheelHandler { onWheel: event => { root.following = false; event.accepted = false } }
        delegate: Text {
            required property var modelData
            required property int index
            width: lyrics.width
            text: modelData.text
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            font.family: Theme.fontMedia
            font.pixelSize: 20 * Flags.fontScale * root.s
            font.weight: root.synced && index === root.lineIndex ? Font.DemiBold : Font.Medium
            color: root.synced && index === root.lineIndex ? Theme.foreground : Theme.iconSecondary
            Behavior on color { enabled: !Flags.reduceMotion; ColorAnimation { duration: Motion.fast } }
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.status !== "ready"
        spacing: 10 * root.s
        Item { Layout.fillHeight: true }
        Text {
            Layout.fillWidth: true
            text: root.status === "loading" ? qsTr("Buscando letras…")
                : root.status === "instrumental" ? qsTr("Esta pista es instrumental.")
                : root.status === "error" ? qsTr("No se pudieron cargar las letras.")
                : root.status === "metadata" ? qsTr("Falta el título o el artista de la canción.")
                : qsTr("No hay letras disponibles para esta canción.")
            font.family: Theme.fontMedia
            font.pixelSize: Theme.fontSizeBodyLg * root.s
            color: Theme.iconSecondary
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
        CtrlBtn { Layout.alignment: Qt.AlignHCenter; visible: root.status === "error" || root.status === "empty"; iconName: "refresh"; accessibleName: qsTr("Reintentar letras"); s: root.s; onClicked: root.retryRequested() }
        Item { Layout.fillHeight: true }
    }
}
