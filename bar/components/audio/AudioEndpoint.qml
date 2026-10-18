pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import "../../Singletons"
import ".."
import "../../settings"

Item {
    id: root
    required property var endpoint
    property string kind: "output"
    property real s: 1
    property var card: null
    property real maximum: 1
    property bool isDefault: false
    property var destinations: []
    property var levels: ({})
    property bool meterEnabled: false
    property Item popupBounds: null
    property bool expanded: false
    property bool renaming: false
    property bool channelsLinked: false
    readonly property string appIcon: stream && endpoint.icon ? Quickshell.iconPath(endpoint.icon, true) : ""
    readonly property var formatOptions: [
        {name:"pcm",label:"PCM"}, {name:"ac3-iec61937",label:"AC-3"}, {name:"eac3-iec61937",label:"E-AC-3"},
        {name:"dts-iec61937",label:"DTS"}, {name:"mpeg-iec61937",label:"MPEG"}, {name:"mpeg2-aac-iec61937",label:"AAC"},
        {name:"truehd-iec61937",label:"TrueHD"}, {name:"dtshd-iec61937",label:"DTS-HD"}
    ]
    readonly property bool stream: kind === "playback" || kind === "recording"
    readonly property bool input: kind === "input" || kind === "recording"
    readonly property var channels: endpoint.channels || []
    readonly property real volume: Number(endpoint.volume || 0)
    readonly property real displayVolume: master.displayVolume
    readonly property string title: stream ? endpoint.appName || endpoint.description : endpoint.description
    readonly property string meterSource: endpoint.meterSource || (input ? endpoint.name : endpoint.monitorSource) || ""
    signal requested(string action, var args)
    signal menuOpened(var menu)
    implicitHeight: body.implicitHeight + 36 * s
    function send(action, values) {
        root.requested(action, Object.assign({kind: root.kind, id: root.endpoint.id}, values || {}))
    }
    function changeChannel(index, value) {
        const values = root.channels.map((channel, i) => Math.min(1.5, root.channelsLinked || i === index ? value : channel.volume))
        root.send("setChannelVolumes", {volumes: values})
    }
    function commitRename() {
        const description = renameField.text.trim()
        if (!description.length) return
        if (description !== root.title) send("renameDevice", {description:description})
        renaming = false
    }
    function setMaster(value) {
        if (channelsLinked && channels.length > 1) send("setChannelVolumes", {volumes:channels.map(channel => value)})
        else send("setVolume", {volume:value})
    }
    function toggleFormat(name) {
        const formats = endpoint.formats || ["pcm"]
        const next = formats.includes(name) ? formats.filter(format => format !== name) : [...formats, name]
        if (next.length) send("setFormats", {formats:next})
    }
    function channelName(name) {
        const labels = {"front-left":qsTr("Frontal izquierdo"), "front-right":qsTr("Frontal derecho"), "front-center":qsTr("Central"), "rear-left":qsTr("Trasero izquierdo"), "rear-right":qsTr("Trasero derecho"), "side-left":qsTr("Lateral izquierdo"), "side-right":qsTr("Lateral derecho"), "lfe":qsTr("Subgrave"), "mono":qsTr("Mono")}
        return labels[name] || name
    }
    Rectangle {
        anchors.fill: parent
        radius: 16 * root.s
        color: Qt.alpha(Theme.foreground, root.isDefault ? Theme.alphaFaint : 0)
        Behavior on color { ColorAnimation { duration: Motion.standardSmall } }
    }
    ColumnLayout {
        id: body
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 18 * root.s
        spacing: 8 * root.s
        RowLayout {
            Layout.fillWidth: true
            spacing: 12 * root.s
            Rectangle {
                Layout.preferredWidth: 40 * root.s; Layout.preferredHeight: 40 * root.s
                radius: 12 * root.s
                color: Qt.alpha(root.isDefault ? Theme.accent : Theme.foreground, Theme.alphaSoft)
                Image {
                    id: applicationIcon
                    anchors.centerIn: parent
                    width: 24 * root.s; height: width
                    source: root.appIcon
                    sourceSize.width: 48; sourceSize.height: 48
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    visible: status === Image.Ready
                }
                MaterialIcon {
                    visible: applicationIcon.status !== Image.Ready
                    anchors.centerIn: parent
                    width: 21 * root.s; height: width
                    iconName: root.input ? "mic" : root.stream ? "music_note" : "headphones"
                    color: root.isDefault ? Theme.accent : Theme.iconSecondary
                    font.pixelSize: 21 * root.s
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.minimumWidth: 0
                spacing: 3 * root.s
                Text {
                    Layout.fillWidth: true
                    text: root.title
                    elide: Text.ElideRight
                    color: Theme.foreground; font.family: Theme.font
                    font.pixelSize: Theme.fontSizeBodyLg * root.s; font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: root.stream ? (root.endpoint.mediaName || (root.endpoint.corked ? qsTr("En pausa") : root.input ? qsTr("Grabación activa") : qsTr("Sesión de audio activa")))
                        : root.endpoint.monitor ? qsTr("Monitor de una salida") : root.isDefault ? qsTr("Dispositivo predeterminado") : qsTr("Disponible")
                    elide: Text.ElideRight
                    color: Theme.iconSecondary; font.family: Theme.font; font.pixelSize: Theme.fontSizeSmall * root.s
                }
            }
            AudioButton {
                objectName: "rename-" + root.kind + "-" + root.endpoint.id
                visible: !root.stream && root.endpoint.canRename !== false
                s: root.s; symbol: "edit"; selected: root.renaming
                enabled: root.endpoint.canRename !== false
                ToolTip.text: enabled ? qsTr("Cambiar nombre de %1").arg(root.title) : qsTr("El servidor de audio no admite renombrar dispositivos")
                ToolTip.visible: hovered
                onClicked: {
                    root.renaming = !root.renaming
                    if (root.renaming) {
                        renameField.text = root.title
                        Qt.callLater(() => { renameField.forceActiveFocus(); renameField.selectAll() })
                    }
                }
            }
            AudioButton {
                objectName: "default-" + root.kind + "-" + root.endpoint.id
                visible: !root.stream
                s: root.s
                symbol: root.isDefault ? "check" : "add"
                selected: root.isDefault
                ToolTip.text: root.isDefault ? qsTr("Dispositivo predeterminado") : qsTr("Usar como predeterminado")
                ToolTip.visible: hovered
                onClicked: root.send("setDefault")
            }
            AudioButton {
                objectName: "stop-" + root.kind + "-" + root.endpoint.id
                visible: root.stream
                s: root.s; symbol: "stop"
                ToolTip.text: root.input ? qsTr("Detener esta grabación") : qsTr("Detener esta reproducción")
                ToolTip.visible: hovered
                onClicked: root.send("killStream")
            }
            AudioButton {
                objectName: "mute-" + root.kind + "-" + root.endpoint.id
                s: root.s
                symbol: root.input ? (root.endpoint.mute ? "mic_off" : "mic") : (root.endpoint.mute ? "volume_off" : "volume_up")
                selected: !!root.endpoint.mute
                ToolTip.text: root.endpoint.mute ? qsTr("Activar %1").arg(root.title) : qsTr("Silenciar %1").arg(root.title)
                ToolTip.visible: hovered
                onClicked: root.send("setMute", {mute: !root.endpoint.mute})
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.renaming ? renameRow.implicitHeight : 0
            clip: true; enabled: root.renaming
            opacity: root.renaming ? 1 : 0
            Behavior on Layout.preferredHeight { enabled: root.visible && !Flags.reduceMotion; NumberAnimation { duration: Motion.standardSmall; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
            RowLayout {
                id: renameRow
                width: parent.width
                spacing: 8 * root.s
                EdotsTextField {
                    id: renameField
                    objectName: "renameField-" + root.kind + "-" + root.endpoint.id
                    Layout.fillWidth: true
                    maximumLength: 256
                    placeholderText: qsTr("Nombre del dispositivo")
                    Accessible.name: placeholderText
                    onAccepted: root.commitRename()
                }
                AudioButton {
                    s: root.s; symbol: "check"; text: qsTr("Guardar")
                    enabled: renameField.text.trim().length > 0
                    onClicked: root.commitRename()
                }
                AudioButton { s: root.s; symbol: "close"; ToolTip.text: qsTr("Cancelar nombre"); ToolTip.visible: hovered; onClicked: root.renaming = false }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 16 * root.s
            AudioFader {
                id: master
                objectName: "volume-" + root.kind + "-" + root.endpoint.id
                Layout.fillWidth: true
                s: root.s; volume: root.volume; maximum: Math.max(root.maximum, Math.min(1.5, root.volume))
                muted: !!root.endpoint.mute
                enabled: root.endpoint.hasVolume !== false
                label: qsTr("Volumen de %1").arg(root.title)
                onEdited: value => root.setMaster(value)
            }
            Text {
                Layout.preferredWidth: 54 * root.s
                horizontalAlignment: Text.AlignRight
                text: Math.round(root.displayVolume * 100) + "%"
                color: root.displayVolume > 1 ? Theme.error : root.endpoint.mute ? Theme.iconSecondary : Theme.foreground
                font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeBodyLg * root.s
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 3 * root.s
            radius: height / 2
            color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
            visible: root.meterEnabled && root.meterSource.length > 0
            Rectangle {
                width: parent.width * Math.min(1, root.levels[root.meterSource] || 0)
                height: parent.height; radius: parent.radius
                color: (root.levels[root.meterSource] || 0) > 0.98 ? Theme.error : Theme.accent
                Behavior on width { enabled: root.visible && !Flags.reduceMotion; NumberAnimation { duration: 32; easing.type: Easing.Linear } }
            }
            Accessible.name: qsTr("Nivel de señal de %1").arg(root.title)
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12 * root.s
            AudioChoice {
                objectName: "route-" + root.kind + "-" + root.endpoint.id
                Layout.fillWidth: true
                visible: root.stream || (root.endpoint.ports || []).length > 0
                s: root.s; popupBounds: root.popupBounds
                label: root.stream ? qsTr("Dispositivo de %1").arg(root.title) : qsTr("Puerto de %1").arg(root.title)
                options: root.stream ? root.destinations.map(device => ({name:device.id, description:device.description})) : root.endpoint.ports || []
                selectedValue: root.stream ? String(root.endpoint.device) : root.endpoint.activePort || ""
                onMenuOpened: menu => root.menuOpened(menu)
                onChosen: value => root.stream ? root.send("moveStream", {device:value}) : root.send("setPort", {port:value})
            }
            AudioButton {
                objectName: "channels-" + root.kind + "-" + root.endpoint.id
                visible: root.channels.length > 1 || !!root.endpoint.canSetFormats || !!root.card
                s: root.s; symbol: "tune"
                selected: root.expanded
                text: root.endpoint.canSetFormats || root.card ? qsTr("Detalles") : qsTr("Canales")
                Accessible.name: qsTr("Ajustar canales de %1").arg(root.title)
                onClicked: root.expanded = !root.expanded
            }
            Item { Layout.fillWidth: true; visible: !root.stream && !(root.endpoint.ports || []).length }
        }
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.expanded ? details.implicitHeight : 0
            clip: true
            opacity: root.expanded ? 1 : 0
            enabled: root.expanded
            Behavior on Layout.preferredHeight { enabled: !Flags.reduceMotion && root.visible; NumberAnimation { duration: Motion.standardSmall; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Flags.reduceMotion ? 0 : Motion.fast } }
            ColumnLayout {
                id: details
                width: parent.width
                spacing: 6 * root.s
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Volumen por canal")
                        color: Theme.iconSecondary; font.family: Theme.font; font.pixelSize: Theme.fontSizeSmall * root.s
                    }
                    AudioButton {
                        objectName: "link-" + root.kind + "-" + root.endpoint.id
                        s: root.s; text: qsTr("Vincular"); symbol: "link"; selected: root.channelsLinked
                        visible: root.channels.length > 1
                        Accessible.name: qsTr("Vincular canales de %1").arg(root.title)
                        onClicked: root.channelsLinked = !root.channelsLinked
                    }
                    AudioButton {
                        s: root.s; text: qsTr("Equilibrar")
                        Accessible.name: qsTr("Igualar los canales de %1").arg(root.title)
                        onClicked: root.send("setChannelVolumes", {volumes: root.channels.map(channel => Math.min(1.5, root.volume))})
                    }
                }
                Repeater {
                    model: root.channels
                    delegate: RowLayout {
                        id: channel
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Text {
                            Layout.preferredWidth: 120 * root.s
                            text: root.channelName(channel.modelData.name)
                            elide: Text.ElideRight
                            font.family: Theme.font; font.pixelSize: Theme.fontSizeSmall * root.s; color: Theme.iconSecondary
                        }
                        AudioFader {
                            id: channelFader
                            Layout.fillWidth: true
                            s: root.s; maximum: Math.max(root.maximum, Math.min(1.5, channel.modelData.volume))
                            volume: channel.modelData.volume
                            label: root.channelName(channel.modelData.name)
                            onEdited: value => root.changeChannel(channel.index, value)
                        }
                        Text {
                            Layout.preferredWidth: 48 * root.s
                            text: Math.round(channelFader.displayVolume * 100) + "%"
                            horizontalAlignment: Text.AlignRight
                            font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall * root.s; color: Theme.iconSecondary
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: !!root.endpoint.canSetFormats
                    text: qsTr("Formatos digitales · activa sólo los compatibles con tu receptor")
                    wrapMode: Text.WordWrap
                    font.family: Theme.font; font.pixelSize: Theme.fontSizeSmall * root.s; color: Theme.iconSecondary
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? implicitHeight : 0
                    visible: !!root.endpoint.canSetFormats
                    spacing: 6 * root.s
                    Repeater {
                        model: root.formatOptions
                        delegate: AudioButton {
                            required property var modelData
                            objectName: "format-" + modelData.name
                            s: root.s; text: modelData.label
                            selected: (root.endpoint.formats || []).includes(modelData.name)
                            enabled: !selected || (root.endpoint.formats || []).length > 1
                            Accessible.name: qsTr("Formato digital %1").arg(modelData.label)
                            onClicked: root.toggleFormat(modelData.name)
                        }
                    }
                }
                AudioButton {
                    objectName: "disable-" + root.kind + "-" + root.endpoint.id
                    visible: !root.stream && !!root.card
                    enabled: !!root.card && (root.input ? !!root.card.canToggleInput : !!root.card.canToggleOutput)
                    s: root.s; symbol: "power_settings_new"
                    text: root.input ? qsTr("Deshabilitar entrada") : qsTr("Deshabilitar salida")
                    ToolTip.text: qsTr("Podrás volver a activarla en Hardware")
                    ToolTip.visible: hovered
                    onClicked: root.requested("setDeviceEnabled", {id:root.card.id, direction:root.input ? "input" : "output", enabled:false})
                }
                Text {
                    text: root.displayVolume > 0 ? (60 * Math.log(root.displayVolume) / Math.LN10).toFixed(1) + " dB" : "−∞ dB"
                    font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSmall * root.s; color: Theme.iconSecondary
                }
            }
        }
    }
}
