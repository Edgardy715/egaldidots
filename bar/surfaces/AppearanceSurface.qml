import QtQuick
import QtQuick.Layouts
import "../"
import "../Singletons"
import "../components"

PillSurface {
    id: root
    signal requestPage(string name)

    mTop: Theme.marginLg
    mLeft: Theme.marginLg
    mRight: Theme.marginLg
    mBottom: Theme.marginLg

    property var draft: ({})
    property string message: ""
    property bool savePending: false
    readonly property var controls: [
        { key: "uiScale", label: qsTr("Escala de interfaz"), min: 0.75, max: 1.5 },
        { key: "fontScale", label: qsTr("Tamaño de texto"), min: 0.75, max: 1.75 },
        { key: "radiusScale", label: qsTr("Redondez"), min: 0.75, max: 1.5 },
        { key: "glassAlpha", label: qsTr("Opacidad del vidrio"), min: 0.15, max: 1 },
        { key: "motionScale", label: qsTr("Velocidad de movimiento"), min: 0.25, max: 2 }
    ]

    Component.onCompleted: draft = JSON.parse(JSON.stringify(Config.appearance))

    function setValue(key, value) {
        const next = Object.assign({}, draft)
        next[key] = typeof value === "number" ? Math.round(value * 100) / 100 : value
        draft = next
    }

    function save() {
        if (savePending) return
        const next = Object.assign({}, draft, { fontFamily: fontField.text.trim() })
        const result = Config.update({ appearance: next })
        if (!result.ok) {
            message = result.errors.join(" · ")
            return
        }
        if (!Config.save()) {
            message = Config.error || qsTr("No se pudieron guardar los ajustes")
            return
        }
        savePending = Config.saving
        if (!savePending) requestPage("utils")
    }

    Connections {
        target: Config
        function onSavingChanged() {
            if (!root.savePending || Config.saving) return
            root.savePending = false
            if (!Config.error && !Config.dirty) root.requestPage("utils")
            else root.message = Config.error || qsTr("No se pudieron guardar los ajustes")
        }
    }

    SurfaceHeader {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        title: qsTr("Apariencia")
        subtitle: qsTr("Personaliza Isla")
        iconName: "palette"
        s: root.s
        trailing: Component {
            CtrlBtn {
                size: 30
                s: root.s
                iconName: "arrow_back"
                accessibleName: qsTr("Volver a ajustes rápidos")
                onClicked: root.requestPage("utils")
            }
        }
    }

    Flickable {
        id: scroll
        anchors.top: header.bottom
        anchors.topMargin: 14 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: actions.top
        anchors.bottomMargin: 10 * root.s
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: scroll.width
            spacing: 11 * root.s

            Rectangle {
                width: parent.width
                height: 76 * root.s
                radius: Theme.radiusLg * root.s * (root.draft.radiusScale || 1)
                color: Qt.alpha(Theme.cardTop, root.draft.glassAlpha || 0.34)
                border.width: Theme.borderHairline
                border.color: Theme.border
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Vista previa de Isla")
                    color: Theme.foreground
                    font.family: root.draft.fontFamily || Theme.font
                    font.pixelSize: Theme.fontSizeBodyLg * (root.draft.fontScale || 1) * root.s
                }
            }

            Repeater {
                model: root.controls
                delegate: Column {
                    required property var modelData
                    width: content.width
                    spacing: 3 * root.s
                    Row {
                        width: parent.width
                        Text {
                            text: modelData.label
                            width: parent.width - valueText.width
                            color: Theme.foreground
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSizeCaption * root.s
                        }
                        Text {
                            id: valueText
                            text: Math.round((root.draft[modelData.key] || modelData.min) * 100) + "%"
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeCaption * root.s
                        }
                    }
                    Slider {
                        width: parent.width
                        height_: 7
                        knob: true
                        s: root.s
                        value: ((root.draft[modelData.key] || modelData.min) - modelData.min) / (modelData.max - modelData.min)
                        onSliderChanged: value => root.setValue(modelData.key, modelData.min + value * (modelData.max - modelData.min))
                    }
                }
            }

            Text {
                text: qsTr("Familia tipográfica")
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeCaption * root.s
            }
            IslaTextField {
                id: fontField
                objectName: "appearanceFont"
                motionActive: root.active && root.visible
                width: parent.width
                height: 42 * root.s
                placeholderText: qsTr("Nombre de la fuente")
                Component.onCompleted: text = Config.appearance.fontFamily
                onEditingFinished: root.setValue("fontFamily", text.trim())
            }

            RowLayout {
                width: parent.width
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Reducir movimiento")
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeCaption * root.s
                }
                Toggle {
                    checked: root.draft.reduceMotion === true
                    s: root.s
                    accessibleName: qsTr("Reducir movimiento")
                    onToggled: value => {
                        const next = Object.assign({}, root.draft)
                        next.reduceMotion = value
                        root.draft = next
                    }
                }
            }
        }
    }

    Column {
        id: actions
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 5 * root.s
        AnimatedLabel {
            width: parent.width
            visible: root.message.length > 0 || root.savePending
            value: root.savePending ? qsTr("Guardando…") : root.message
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeSmall * root.s
            elide: Text.ElideRight
        }
        RowLayout {
            width: parent.width
            spacing: Theme.spacingMd * root.s
            MotionButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 36 * root.s
                text: qsTr("Cancelar")
                onClicked: root.requestPage("utils")
                background: Rectangle { radius: Theme.radiusMd * root.s; color: Qt.alpha(Theme.foreground, Theme.alphaSoft) }
                contentItem: Text { text: parent.text; color: Theme.foreground; font.family: Theme.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            MotionButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 36 * root.s
                enabled: Config.loaded && !root.savePending
                text: qsTr("Guardar")
                onClicked: root.save()
                background: Rectangle { radius: Theme.radiusMd * root.s; color: Theme.accent }
                contentItem: Text { text: parent.text; color: Theme.background; font.family: Theme.font; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }
}
