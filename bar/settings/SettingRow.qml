import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../components" as Components
import "../Singletons"

Item {
    id: root
    property bool motionReady: false
    Component.onCompleted: motionReady = true
    clip: true
    Behavior on implicitHeight {
        enabled: root.motionReady && !root.reducedMotion && root.visible
        NumberAnimation { duration: Motion.standardSmall; easing.type: Easing.OutCubic }
    }
    HoverHandler { id: rowHover }
    Rectangle {
        anchors.fill: parent; anchors.margins: 4; radius: 10; z: -1
        color: Theme.accent; opacity: rowHover.hovered ? 0.045 : 0
        Behavior on opacity { enabled: !root.reducedMotion && root.visible; NumberAnimation { duration: Motion.hover } }
    }
    required property string fieldKey
    required property var field
    required property var value
    property var draftText
    property string validationMessage: ""
    property string sectionLabel: ""
    property Item popupBounds: null
    property bool editorEnabled: true
    property bool reducedMotion: false
    signal changeRequested(var value)
    signal draftChanged(string text)
    signal accepted()
    signal validationFailed(string message)
    signal resetRequested()
    signal browseRequested()

    readonly property bool supported: field.availability !== "inactive" && field.availability !== "partial"
    readonly property bool editable: supported && editorEnabled
    readonly property bool modified: value !== field.default || draftText !== undefined
    readonly property bool ranged: field.type === "number" && field.minimum !== undefined && field.maximum !== undefined
    readonly property bool fontField: ["fontFamily", "fontMonoFamily", "fontDisplayFamily", "fontMediaFamily"].includes(fieldKey)
    property string localError: ""
    onDraftTextChanged: { if (draftText === undefined) localError = "" }

    function focusEditor() {
        if (!root.editable) return false
        if (fontPicker.visible) fontPicker.contentItem.forceActiveFocus()
        else if (textEditor.visible) textEditor.forceActiveFocus()
        else if (slider.visible) slider.forceActiveFocus()
        else if (toggle.visible) toggle.forceActiveFocus()
        else if (choiceRepeater.count > 0) choiceRepeater.itemAt(0).forceActiveFocus()
        else return false
        return true
    }

    function submitText(text) {
        const next = field.type === "number" ? Number(text.trim()) : text.trim()
        if (field.type === "number" && (text.trim() === "" || !isFinite(next)
            || (field.minimum !== undefined && next < field.minimum)
            || (field.maximum !== undefined && next > field.maximum))) {
            localError = qsTr("Introduce un número dentro del rango permitido.")
        } else if (field.type === "string" && (next.length < (field.minLength === undefined ? 1 : field.minLength)
                   || next.indexOf("\u0000") !== -1
                   || (field.path && next.charAt(0) !== "/" && next !== "~" && next.indexOf("~/") !== 0))) {
            localError = field.path ? qsTr("Usa una ruta absoluta o que empiece por ~/.")
                                    : qsTr("Introduce un texto válido.")
        } else {
            localError = ""
            if (next !== root.value) changeRequested(next)
            else accepted()
        }
        if (localError) validationFailed(qsTr("%1: %2").arg(field.label).arg(localError))
    }

    implicitHeight: content.implicitHeight + 33

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.topMargin: 16
        spacing: 7

        Text {
            visible: root.sectionLabel.length > 0
            Layout.fillWidth: true
            text: root.sectionLabel
            color: Theme.foreground
            font.family: Config.appearance.fontFamily
            font.pixelSize: Theme.fontSizeBody
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    Layout.fillWidth: true
                    text: root.field.label
                    color: root.editable ? Theme.foreground : Qt.alpha(Theme.foreground, 0.72)
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.fontSizeTitle
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }
                Text {
                    Layout.fillWidth: true
                    text: root.fontField ? qsTr("Elige una fuente instalada o escribe su nombre.") : root.field.description || ""
                    color: Qt.alpha(Theme.foreground, 0.72)
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    wrapMode: Text.WordWrap
                }
            }

            Switch {
                id: toggle
                visible: root.field.control === "toggle"
                enabled: root.editable
                checked: !!root.value
                focusPolicy: Qt.StrongFocus
                Accessible.name: root.field.label
                Accessible.description: root.field.description || ""
                onToggled: root.changeRequested(checked)
                implicitWidth: 64; implicitHeight: 44
                indicator: Rectangle {
                    x: 6; y: (toggle.height - height) / 2
                    implicitWidth: 52; implicitHeight: 30
                    radius: height / 2
                    scale: root.reducedMotion ? 1 : toggle.down ? 0.94 : toggle.hovered ? 1.04 : 1
                    Behavior on scale { enabled: root.visible && !root.reducedMotion; SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping } }
                    color: toggle.checked ? Theme.accent : Qt.alpha(Theme.foreground, 0.12)
                    opacity: toggle.enabled ? 1 : 0.45
                    border.width: 1
                    border.color: Qt.alpha(Theme.foreground, toggle.hovered ? 0.24 : 0.10)
                    Behavior on color { enabled: root.visible; ColorAnimation { duration: Motion.fast } }
                    Behavior on opacity { enabled: root.visible; NumberAnimation { duration: Motion.fast } }
                    Behavior on border.color { enabled: root.visible; ColorAnimation { duration: Motion.hover } }
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -3; radius: parent.radius + 3
                        color: "transparent"; border.width: 2; border.color: Theme.accent
                        opacity: toggle.activeFocus ? 0.35 : 0
                        Behavior on opacity { enabled: root.visible; NumberAnimation { duration: Motion.hover } }
                    }
                    Rectangle {
                        x: toggle.checked ? 26 : 4; y: 4
                        width: 22; height: 22; radius: 11
                        color: Theme.foreground
                        Behavior on x { enabled: root.visible && !root.reducedMotion; SpringAnimation { spring: Motion.controlSpring; damping: 0.5; epsilon: 0.01 } }
                        EdotsIcon {
                            anchors.centerIn: parent; iconName: "check"; font.pixelSize: Theme.fontSizeBody
                            color: Theme.background; selected: toggle.checked
                            controlHovered: toggle.hovered; controlPressed: toggle.down
                            Accessible.ignored: true
                            opacity: toggle.checked ? 1 : 0
                            visible: opacity > 0.01
                            Behavior on opacity { enabled: root.visible; NumberAnimation { duration: Motion.fast } }
                        }
                    }
                }
            }
        }

        RowLayout {
            visible: root.modified
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: qsTr("Personalizado")
                color: Theme.foreground
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.fontSizeBody
            }
            Item { Layout.fillWidth: true }
            EdotsButton {
                enabled: root.editable
                text: qsTr("Restablecer")
                symbol: "refresh"
                implicitHeight: Math.max(44, Theme.fontSizeBody * 1.5 + 16)
                font.pixelSize: Theme.fontSizeBody
                onClicked: root.resetRequested()
            }
        }

        Text {
            visible: !root.supported
            Layout.fillWidth: true
            text: root.field.availability === "partial" ? qsTr("Disponible parcialmente · edición desactivada")
                                                        : qsTr("Sin efecto actualmente · edición desactivada")
            color: Qt.alpha(Theme.foreground, 0.72)
            font.family: Config.appearance.fontFamily
            font.pixelSize: Theme.fontSizeBody
            wrapMode: Text.WordWrap
        }

        Flow {
            visible: root.field.control === "choice"
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                id: choiceRepeater
                model: root.field.options || []
                EdotsButton {
                    id: choice
                    required property string modelData
                    required property int index
                    objectName: "choice-" + modelData
                    text: root.field.optionLabels ? root.field.optionLabels[index] : modelData
                    checkable: false
                    checked: root.value === choice.modelData
                    accent: root.value === choice.modelData
                    enabled: root.editable
                    Accessible.name: root.field.label + ": " + text
                    Accessible.role: Accessible.RadioButton
                    Accessible.checkable: true
                    Accessible.checked: root.value === choice.modelData
                    Accessible.description: root.field.description || ""
                    onClicked: root.changeRequested(choice.modelData)
                }
            }
        }

        RowLayout {
            visible: root.field.type === "number" && root.ranged
            Layout.fillWidth: true
            spacing: 16
            Slider {
                id: slider
                implicitHeight: 44
                Layout.fillWidth: true
                enabled: root.editable
                from: root.field.minimum ?? 0
                to: root.field.maximum ?? 1
                value: Number(root.value)
                stepSize: 0.01
                focusPolicy: Qt.StrongFocus
                Accessible.name: root.field.label
                Accessible.description: root.field.description || ""
                onMoved: root.changeRequested(Math.round(value * 100) / 100)
                background: Rectangle {
                    x: slider.leftPadding
                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                    width: slider.availableWidth
                    height: slider.hovered || slider.pressed ? 7 : 5
                    radius: height / 2
                    Behavior on height { enabled: root.visible && !root.reducedMotion; NumberAnimation { duration: Motion.hover } }
                    color: Qt.alpha(Theme.foreground, 0.18)
                    Rectangle {
                        width: slider.visualPosition * parent.width
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent
                    }
                }
                handle: Rectangle {
                    x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                    scale: root.reducedMotion ? 1 : slider.pressed ? 1.22 : slider.hovered ? 1.12 : 1
                    Behavior on scale { enabled: !root.reducedMotion && root.visible; SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping } }
                    width: 20
                    height: 20
                    radius: 10
                    color: Theme.foreground
                    border.width: 1
                    border.color: Qt.alpha(Theme.background, 0.15)
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -4; radius: 14
                        color: "transparent"; border.width: 2; border.color: Theme.accent
                        opacity: slider.activeFocus ? 0.4 : 0
                        Behavior on opacity { enabled: root.visible; NumberAnimation { duration: Motion.hover } }
                    }
                    Rectangle {
                        anchors.centerIn: parent; width: 6; height: 6; radius: 3
                        color: Theme.background
                        opacity: slider.pressed ? 0.65 : slider.hovered ? 0.25 : 0
                        Behavior on opacity { enabled: root.visible; NumberAnimation { duration: Motion.hover } }
                    }
                }
            }
            Text {
                text: Number(root.value).toFixed(2)
                color: Theme.foreground
                font.family: Config.appearance.fontFamily
                font.pixelSize: Theme.fontSizeBodyLg
                Layout.preferredWidth: Math.max(42, implicitWidth)
                horizontalAlignment: Text.AlignRight
            }
        }

        RowLayout {
            visible: (root.field.control === "text" && !root.fontField) || root.field.control === "path" || (root.field.type === "number" && !root.ranged)
            Layout.fillWidth: true
            spacing: 8
        EdotsTextField {
            id: textEditor
            enabled: root.editable
            Layout.fillWidth: true
            text: root.draftText !== undefined ? root.draftText : root.value === undefined ? "" : String(root.value)
            invalid: !!(root.validationMessage || root.localError)
            Accessible.name: root.field.label
            Accessible.description: root.validationMessage || root.localError || root.field.description || ""
            inputMethodHints: root.field.type === "number" ? Qt.ImhFormattedNumbersOnly : Qt.ImhNone
            onTextEdited: { root.localError = ""; root.draftChanged(text) }
            onEditingFinished: root.submitText(text)
        }

            EdotsButton {
                objectName: "browsePath"
                visible: !!root.field.path
                enabled: root.editable
                text: qsTr("Elegir…")
                symbol: "folder_open"
                Accessible.name: qsTr("Seleccionar %1").arg(root.field.label)
                onClicked: root.browseRequested()
            }
        }

        EdotsComboBox {
            id: fontPicker
            visible: root.fontField
            enabled: root.editable
            Layout.fillWidth: true
            configuredText: root.draftText !== undefined ? root.draftText : root.value === undefined ? "" : String(root.value)
            popupBounds: root.popupBounds
            invalid: !!(root.validationMessage || root.localError)
            Accessible.name: root.field.label
            Accessible.description: root.validationMessage || root.localError || root.field.description || ""
            onActivated: index => root.submitText(textAt(index))
            onAccepted: root.submitText(editText)
            onTextEdited: text => { root.localError = ""; root.draftChanged(text) }
            onEditingFinished: text => root.submitText(text)
        }

        Text {
            objectName: "settingValidation"
            visible: root.validationMessage.length > 0 || root.localError.length > 0
            Layout.fillWidth: true
            text: root.validationMessage || root.localError
            color: Theme.error
            font.family: Config.appearance.fontFamily
            font.pixelSize: Theme.fontSizeBody
            wrapMode: Text.WordWrap
            Accessible.role: Accessible.StaticText
            Accessible.name: qsTr("%1: %2").arg(root.field.label).arg(text)
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        height: 1
        color: Theme.border
    }
}
