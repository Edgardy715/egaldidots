pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import "../Singletons"
import "../settings"
import "audio"

Item {
    id: root
    property real s: 1
    property bool active: true
    property bool ready: false
    property bool busy: false
    property string error: ""
    property var outputs: []
    property var inputs: []
    property var playback: []
    property var recording: []
    property var cards: []
    property string defaultOutput: ""
    property string defaultInput: ""
    property var levels: ({})
    property var activePopup: null
    readonly property bool popupOpen: !!activePopup && activePopup.visible
    function trackMenu(menu) {
        if (activePopup && activePopup !== menu) activePopup.close()
        activePopup = menu
    }
    onPageChanged: if (activePopup) activePopup.close()
    onActiveChanged: {
        if (!active && activePopup) activePopup.close()
        if (active) { captureApps = false; search.text = "" }
        updateMeters()
    }
    property int page: 0
    property bool captureApps: false
    onCaptureAppsChanged: { search.text = ""; Qt.callLater(() => list.positionViewAtBeginning()) }
    property bool showMonitors: false
    property bool amplified: false
    readonly property real maximum: amplified ? 1.5 : 1
    readonly property var tabLabels: [qsTr("Salida"), qsTr("Entrada"), qsTr("Aplicaciones"), qsTr("Hardware")]
    readonly property var tabSymbols: ["volume_up", "mic", "apps", "tune"]
    readonly property string kind: pages.displayedPage === 0 ? "output" : pages.displayedPage === 1 ? "input" : captureApps ? "recording" : "playback"
    readonly property var rows: pages.displayedPage === 0 ? [...outputs].sort((a,b) => Number(b.name === defaultOutput) - Number(a.name === defaultOutput) || outputs.indexOf(a) - outputs.indexOf(b)) : pages.displayedPage === 1 ? inputs.filter(row => showMonitors || !row.monitor).sort((a,b) => Number(b.name === defaultInput) - Number(a.name === defaultInput) || inputs.indexOf(a) - inputs.indexOf(b))
        : pages.displayedPage === 3 ? cards : (captureApps ? recording : playback).filter(row => (row.appName + " " + row.mediaName).toLowerCase().includes(search.text.toLowerCase()))
    property var meterSources: []
    function updateMeters() {
        let sources = []
        if (active && ready && pages.displayedPage !== 3) {
            const top = list.contentY
            const bottom = top + list.height
            sources = rows.filter((row, index) => {
                const item = list.itemAtIndex(index)
                return item && item.y + item.height > top && item.y < bottom
            }).map(row => row.meterSource || (kind === "input" ? row.name : row.monitorSource) || "").filter(name => name.length > 0).slice(0,12)
        }
        if (JSON.stringify(sources) !== JSON.stringify(meterSources)) meterSources = sources
    }
    onRowsChanged: Qt.callLater(updateMeters)
    onReadyChanged: Qt.callLater(updateMeters)
    Component.onCompleted: Qt.callLater(updateMeters)
    signal requested(string action, var args)
    signal refreshRequested()
    signal requestClose()

    EdotsPageMotion {
        id: pages
        requestedPage: root.page
        active: root.active
        reduced: Flags.reduceMotion
        onDisplayedPageChanged: {
            if (displayedPage === 2) root.captureApps = false
            Qt.callLater(() => list.positionViewAtBeginning())
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 16 * root.s
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true; Layout.minimumWidth: 0
                spacing: 4 * root.s
                Text {
                    text: qsTr("Sonido")
                    color: Theme.foreground; font.family: Theme.font
                    font.pixelSize: Theme.fontSizeHero * root.s; font.weight: Font.DemiBold
                }
                AnimatedLabel {
                    Layout.fillWidth: true
                    value: !root.ready ? qsTr("Conectando con el audio…") : (root.outputs.length === 1 ? qsTr("1 salida") : qsTr("%1 salidas").arg(root.outputs.length)) + " · " + (root.inputs.filter(row => !row.monitor).length === 1 ? qsTr("1 entrada") : qsTr("%1 entradas").arg(root.inputs.filter(row => !row.monitor).length))
                    color: Theme.iconSecondary; font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s
                    elide: Text.ElideRight
                }
            }
            AudioButton {
                objectName: "audioRefresh"
                s: root.s; symbol: "refresh"
                ToolTip.text: qsTr("Actualizar dispositivos"); ToolTip.visible: hovered
                onClicked: root.refreshRequested()
            }
            AudioButton {
                objectName: "audioClose"
                s: root.s; symbol: "close"
                ToolTip.text: qsTr("Cerrar sonido"); ToolTip.visible: hovered
                onClicked: root.requestClose()
            }
        }
        Item {
            id: tabs
            Layout.fillWidth: true
            Layout.preferredHeight: 44 * root.s
            Rectangle {
                anchors.fill: parent; radius: 13 * root.s
                color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
            }
            Rectangle {
                x: root.page * tabs.width / 4 + 4 * root.s
                y: 4 * root.s
                width: tabs.width / 4 - 8 * root.s; height: tabs.height - 8 * root.s
                radius: 10 * root.s
                color: Qt.alpha(Theme.accent, Theme.alphaChip)
                Behavior on x { enabled: !Flags.reduceMotion && root.active; SmoothedAnimation { duration: Motion.standardSmall; velocity: -1 } }
            }
            Row {
                anchors.fill: parent
                Repeater {
                    model: root.tabLabels
                    delegate: AudioButton {
                        id: tab
                        required property int index
                        required property string modelData
                        objectName: "audioTab-" + index
                        s: root.s
                        width: tabs.width / 4; height: tabs.height
                        text: root.width > 540 * root.s * Math.max(1, Flags.fontScale) ? modelData : ""
                        symbol: root.tabSymbols[index]
                        selected: root.page === index
                        Accessible.name: modelData
                        ToolTip.text: modelData
                        ToolTip.visible: hovered && text.length === 0
                        Accessible.role: Accessible.PageTab
                        Accessible.onPressAction: root.page = index
                        background: Rectangle { color: "transparent"; radius: 10 * root.s; border.width: tab.activeFocus ? 2 : 0; border.color: Theme.accent }
                        onClicked: root.page = index
                        Keys.onLeftPressed: root.page = Math.max(0, root.page - 1)
                        Keys.onRightPressed: root.page = Math.min(3, root.page + 1)
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.error.length > 0
            spacing: 12 * root.s
            MaterialIcon { Layout.preferredWidth: 20 * root.s; Layout.preferredHeight: 20 * root.s; iconName: "error"; font.pixelSize: 20 * root.s; color: Theme.error }
            Text {
                objectName: "audioError"
                Layout.fillWidth: true
                text: root.error
                maximumLineCount: 3; wrapMode: Text.WordWrap; elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s; color: Theme.error
                Accessible.role: Accessible.AlertMessage
            }
            AudioButton { s: root.s; text: qsTr("Reintentar"); onClicked: root.refreshRequested() }
        }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            ColumnLayout {
                anchors.fill: parent
                opacity: pages.exposure
                transform: Translate { x: Flags.reduceMotion ? 0 : pages.travel * root.s }
                enabled: root.active && root.ready && !pages.transitioning
                spacing: 10 * root.s
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        visible: pages.displayedPage !== 2
                        text: pages.displayedPage === 0 ? qsTr("Dónde quieres escuchar") : pages.displayedPage === 1 ? qsTr("Qué quieres capturar") : pages.displayedPage === 2 ? qsTr("Cada aplicación, a tu manera") : qsTr("Perfiles y conexiones")
                        font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg * root.s; font.weight: Font.Medium; color: Theme.foreground
                        elide: Text.ElideRight
                    }
                    AudioButton {
                        objectName: "audioMonitors"
                        visible: pages.displayedPage === 1
                        s: root.s; text: qsTr("Monitores"); symbol: "speaker"; selected: root.showMonitors
                        onClicked: root.showMonitors = !root.showMonitors
                    }
                    AudioButton {
                        objectName: "audioPlayback"
                        Layout.fillWidth: true
                        visible: pages.displayedPage === 2
                        s: root.s; text: qsTr("Reproducción · %1").arg(root.playback.length); selected: !root.captureApps
                        onClicked: root.captureApps = false
                    }
                    AudioButton {
                        objectName: "audioRecording"
                        Layout.fillWidth: true
                        visible: pages.displayedPage === 2
                        s: root.s; text: qsTr("Grabación · %1").arg(root.recording.length); selected: root.captureApps
                        onClicked: root.captureApps = true
                    }
                }
                EdotsTextField {
                    id: search
                    objectName: "audioSearch"
                    Layout.fillWidth: true
                    visible: pages.displayedPage === 2
                    placeholderText: qsTr("Buscar aplicaciones")
                    onTextChanged: Qt.callLater(() => list.positionViewAtBeginning())
                }
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    MotionList {
                        id: list
                        objectName: "audioEndpointList"
                        anchors.fill: parent
                        clip: true
                        spacing: 4 * root.s
                        boundsBehavior: Flickable.StopAtBounds
                        onContentYChanged: Qt.callLater(root.updateMeters)
                        onContentHeightChanged: Qt.callLater(root.updateMeters)
                        onHeightChanged: Qt.callLater(root.updateMeters)
                        model: ScriptModel { values: root.rows.map(row => row.id) }
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        onModelChanged: positionViewAtBeginning()
                        delegate: Loader {
                            id: rowLoader
                            required property string modelData
                            onLoaded: Qt.callLater(root.updateMeters)
                            onHeightChanged: Qt.callLater(root.updateMeters)
                            onYChanged: Qt.callLater(root.updateMeters)
                            readonly property var record: root.rows.find(row => row.id === modelData) || ({id:modelData,description:"",channels:[]})
                            width: list.width - 10 * root.s
                            height: item ? item.implicitHeight : 0
                            sourceComponent: pages.displayedPage === 3 ? hardwareComponent : endpointComponent
                            Component {
                                id: endpointComponent
                                AudioEndpoint {
                                    endpoint: rowLoader.record
                                    kind: root.kind
                                    s: root.s; maximum: root.maximum
                                    popupBounds: root
                                    card: root.cards.find(card => card.id === endpoint.card) || null
                                    levels: root.levels
                                    meterEnabled: root.meterSources.includes(meterSource)
                                    isDefault: root.kind === "output" ? endpoint.name === root.defaultOutput : root.kind === "input" && endpoint.name === root.defaultInput
                                    destinations: root.kind === "recording" ? root.inputs : root.outputs
                                    onMenuOpened: menu => root.trackMenu(menu)
                                    onRequested: (action, args) => root.requested(action, args)
                                }
                            }
                            Component {
                                id: hardwareComponent
                                AudioHardware {
                                    card: rowLoader.record
                                    s: root.s; popupBounds: root
                                    onMenuOpened: menu => root.trackMenu(menu)
                                    onRequested: (action, args) => root.requested(action, args)
                                }
                            }
                        }
                    }
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, 340 * root.s)
                        spacing: 12 * root.s
                        visible: root.rows.length === 0
                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 32 * root.s; Layout.preferredHeight: 32 * root.s
                            iconName: root.ready ? root.tabSymbols[pages.displayedPage] : "sync"
                            font.pixelSize: 32 * root.s; color: Theme.iconSecondary
                        }
                        Text {
                            Layout.fillWidth: true
                            text: !root.ready ? qsTr("Esperando al servidor de audio") : pages.displayedPage === 2 ? search.text ? qsTr("No hay aplicaciones que coincidan") : root.captureApps ? qsTr("Ninguna aplicación está grabando") : qsTr("Ninguna aplicación está reproduciendo") : qsTr("No hay dispositivos disponibles")
                            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeBodyLg * root.s; color: Theme.foreground
                        }
                        Text {
                            Layout.fillWidth: true
                            text: pages.displayedPage === 2 ? qsTr("Los controles aparecen cuando una aplicación abre un stream de audio.") : qsTr("Conecta un dispositivo o revisa su perfil en Hardware.")
                            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeBody * root.s; color: Theme.iconSecondary
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12 * root.s
            AudioButton {
                objectName: "audioAmplification"
                s: root.s; text: qsTr("Hasta 150 %"); symbol: "volume_up"; selected: root.amplified
                visible: root.page !== 3
                onClicked: root.amplified = !root.amplified
            }
            Text {
                Layout.fillWidth: true
                text: root.busy ? qsTr("Aplicando cambios…") : root.page === 3 ? qsTr("El perfil define las entradas y salidas disponibles.") : root.amplified ? qsTr("Por encima del 100 % puede haber distorsión.") : qsTr("Los cambios se aplican al instante.")
                elide: Text.ElideRight
                font.family: Theme.font; font.pixelSize: Theme.fontSizeSmall * root.s; color: Theme.iconSecondary
            }
            Text { text: "Esc"; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall * root.s; color: Theme.iconSecondary }
        }
    }
}
