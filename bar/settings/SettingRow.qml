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
        NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard }
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
    // Controles compactos a la derecha de la etiqueta cuando hay anchura: la fila
    // se lee como «nombre → valor» y no como un formulario apilado.
    readonly property var options: field.options || []
    readonly property bool selectField: field.control === "choice" && options.length > 6
    readonly property bool chipField: field.control === "choice" && !selectField
    readonly property bool wide: width >= 600
    readonly property bool inlineControl: wide && ((chipField && options.length <= 3) || selectField || ranged)
    property string localError: ""
    onDraftTextChanged: { if (draftText === undefined) localError = "" }

    function focusEditor() {
        if (!root.editable) return false
        if (fontPicker.visible && fontPicker.status === Loader.Ready) fontPicker.item.contentItem.forceActiveFocus()
        else if (selectLoader.visible && selectLoader.status === Loader.Ready) selectLoader.item.forceActiveFocus()
        else if (textLoader.visible && textLoader.status === Loader.Ready) textLoader.item.editor.forceActiveFocus()
        else if (sliderLoader.visible && sliderLoader.status === Loader.Ready) sliderLoader.item.editor.forceActiveFocus()
        else if (toggleLoader.visible && toggleLoader.status === Loader.Ready) toggleLoader.item.forceActiveFocus()
        else if (choiceLoader.visible && choiceLoader.status === Loader.Ready && choiceLoader.item.choices.count > 0)
            choiceLoader.item.choices.itemAt(0).forceActiveFocus()
        else return false
        return true
    }

    function restoreDefault() {
        resetRequested()
        focusEditor()
    }

    function submitText(text) {
        const next = field.type === "number" ? Number(text.trim()) : text.trim()
        if (field.type === "number" && (text.trim() === "" || !isFinite(next)
            || (field.minimum !== undefined && next < field.minimum)
            || (field.maximum !== undefined && next > field.maximum))) {
            localError = I18n.tr("Introduce un número dentro del rango permitido.")
        } else if (field.type === "string" && (next.length < (field.minLength === undefined ? 1 : field.minLength)
                   || next.indexOf("\u0000") !== -1
                   || (field.path && next.charAt(0) !== "/" && next !== "~" && next.indexOf("~/") !== 0))) {
            localError = field.path ? I18n.tr("Usa una ruta absoluta o que empiece por ~/.")
                                    : I18n.tr("Introduce un texto válido.")
        } else {
            localError = ""
            if (next !== root.value) changeRequested(next)
            else accepted()
        }
        if (localError) validationFailed(I18n.tr("%1: %2").arg(I18n.tr(field.label)).arg(localError))
    }

    // Filas agrupadas: cada sección es una tarjeta continua; sólo la primera y
    // la última fila redondean sus esquinas y un filete interior las separa.
    property bool groupFirst: true
    property bool groupLast: true
    readonly property real cardRadius: 18
    readonly property real headerSpace: sectionLabel.length > 0 ? sectionHeader.implicitHeight + 10 : 0
    readonly property real groupGap: groupLast ? 28 : 0
    implicitHeight: headerSpace + content.implicitHeight + 32 + groupGap

    Text {
        id: sectionHeader
        visible: root.sectionLabel.length > 0
        anchors.left: parent.left
        anchors.leftMargin: 20
        text: root.sectionLabel
        color: Qt.alpha(Theme.foreground, 0.72)
        font.family: Config.appearance.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        font.letterSpacing: 0.3
    }

    Rectangle {
        id: card
        z: -1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: root.headerSpace
        anchors.bottomMargin: root.groupGap
        color: Qt.alpha(Theme.foreground, Theme.liquid ? 0.05 : 0.035)
        topLeftRadius: root.groupFirst ? root.cardRadius : 0
        topRightRadius: topLeftRadius
        bottomLeftRadius: root.groupLast ? root.cardRadius : 0
        bottomRightRadius: bottomLeftRadius
        border.width: Theme.liquid ? 0 : 1
        border.color: Qt.alpha(Theme.foreground, 0.05)
    }

    // Cabecera: etiqueta | restablecer | control en línea o interruptor.
    // Lo que no cabe en línea va debajo, a todo el ancho.
    ColumnLayout {
        id: content
        anchors.left: card.left
        anchors.right: card.right
        anchors.top: card.top
        anchors.leftMargin: 20
        anchors.rightMargin: 16
        anchors.topMargin: 16
        spacing: 10
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    // Marca de valor propio: una gota pequeña junto al título.
                    Rectangle {
                        Layout.preferredWidth: 7; Layout.preferredHeight: 7; radius: 3.5
            Layout.alignment: Qt.AlignVCenter
                        color: Theme.liquid ? Theme.stateFill : Theme.accent
                        visible: scale > 0.01
                        scale: root.modified ? 1 : 0
                        Behavior on scale { enabled: root.visible && !root.reducedMotion; SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping } }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: I18n.tr(root.field.label)
                        color: root.editable ? Theme.foreground : Qt.alpha(Theme.foreground, 0.72)
                        font.family: Config.appearance.fontFamily
                        font.pixelSize: Theme.fontSizeTitle
                        font.weight: Font.Medium
                        wrapMode: Text.WordWrap
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.fontField ? "" : I18n.tr(root.field.description || "")
                    color: Qt.alpha(Theme.foreground, 0.72)
                    font.family: Config.appearance.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }
            }

            Loader {
                active: root.modified
                visible: active
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: EdotsButton {
                    enabled: root.editable
                    flat: true
                    objectName: "settingReset"
                    symbol: "refresh"
                    implicitWidth: 40; implicitHeight: 40
                    Accessible.name: I18n.tr("Restablecer")
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: I18n.tr("Restablecer")
                    Accessible.description: I18n.tr("%1 tiene un valor personalizado").arg(I18n.tr(root.field.label))
                    onClicked: root.restoreDefault()
                    opacity: 0
                    Component.onCompleted: opacity = 1
                    Behavior on opacity { enabled: !root.reducedMotion; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                }
            }

            Loader {
                id: toggleLoader
                active: root.field.control === "toggle"
                visible: active
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: Switch {
                    id: toggle
                    objectName: "settingToggle"
                    enabled: root.editable
                    checked: !!root.value
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: root.field.label
                    Accessible.description: I18n.tr(root.field.description || "")
                    onToggled: root.changeRequested(checked)
                    implicitWidth: 64; implicitHeight: 44
                    indicator: Rectangle {
                        id: track
                        x: 6; y: (toggle.height - height) / 2
                        implicitWidth: 52; implicitHeight: 30
                        radius: height / 2
                        scale: root.reducedMotion ? 1 : toggle.down ? 0.94 : 1
                        Behavior on scale { enabled: root.visible && !root.reducedMotion; SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping } }
                        color: toggle.checked ? (Theme.liquid ? Theme.stateFill : Theme.accent) : Qt.alpha(Theme.foreground, 0.12)
                        gradient: Theme.liquid && toggle.checked ? trackVolume : null
                        property Gradient trackVolume: Gradient {
                            GradientStop { position: 0; color: Theme.stateFillLight }
                            GradientStop { position: 1; color: Theme.stateFill }
                        }
                        opacity: toggle.enabled ? 1 : 0.45
                        border.width: Theme.liquid ? 0 : 1
                        border.color: Qt.alpha(Theme.foreground, toggle.hovered ? 0.24 : 0.10)
                        Behavior on color { enabled: root.visible; ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                        Behavior on opacity { enabled: root.visible; NumberAnimation { duration: Motion.fast } }
                        Behavior on border.color { enabled: root.visible; ColorAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
                        Rectangle {
                            anchors.fill: parent; anchors.margins: -3; radius: parent.radius + 3
                            color: "transparent"; border.width: 2; border.color: Theme.accent
                            opacity: toggle.activeFocus ? 0.35 : 0
                            Behavior on opacity { enabled: root.visible; NumberAnimation { duration: Motion.hover } }
                        }
                        Rectangle {
                            id: knob
                            // Centro de masa del botón; con Superficies líquidas se
                            // alarga hacia su destino mientras viaja y se recoge al llegar.
                            readonly property real target: toggle.checked ? 26 : 4
                            property real travel: target
                            Behavior on travel { enabled: root.visible && !root.reducedMotion; SpringAnimation { spring: Motion.controlSpring; damping: 0.7; epsilon: 0.01 } }
                            readonly property real stretch: Theme.liquid ? Math.min(9, Math.abs(target - travel) * 0.8) : 0
                            x: target > travel ? travel : travel - stretch
                            y: 4
                            width: 22 + stretch; height: 22; radius: 11
                            color: toggle.checked ? (Theme.liquid ? Theme.stateContent : Theme.primaryContent) : Theme.foreground
                            Behavior on color { enabled: root.visible; ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                            EdotsIcon {
                                anchors.centerIn: parent; iconName: "check"; font.pixelSize: Theme.fontSizeBody
                                color: Theme.liquid ? Theme.stateFill : Theme.accent; selected: toggle.checked
                                controlHovered: toggle.hovered; controlPressed: toggle.down
                                Accessible.ignored: true
                                opacity: toggle.checked && knob.stretch < 2 ? 1 : 0
                                visible: opacity > 0.01
                                Behavior on opacity { enabled: root.visible; NumberAnimation { duration: Motion.fast } }
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: !root.supported
            Layout.fillWidth: true
            text: root.field.availability === "partial" ? I18n.tr("Disponible parcialmente · edición desactivada")
                                                        : I18n.tr("Sin efecto actualmente · edición desactivada")
            color: Qt.alpha(Theme.foreground, 0.72)
            font.family: Config.appearance.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }

        Loader {
            id: choiceLoader
            active: root.chipField
            visible: active
            // En línea pasa a la cabecera, tras el botón de restablecer.
            parent: root.inlineControl ? headerRow : content
            Layout.fillWidth: !root.inlineControl
            Layout.alignment: Qt.AlignVCenter
            // Control segmentado: la selección es una gota que viaja entre opciones.
            sourceComponent: Item {
                id: choiceGroup
                objectName: "settingChoices"
                property alias choices: choiceRepeater
                implicitHeight: choiceFlow.implicitHeight + 8
                implicitWidth: (root.inlineControl ? rowWidth : choiceFlow.implicitWidth) + 8
                readonly property int selectedIndex: (root.field.options || []).indexOf(root.value)
                // itemAt() no notifica: la revisión obliga a releerlo cuando el Repeater crea o retira chips.
                property int chipRevision: 0
                readonly property Item selectedChip: chipRevision >= 0 && selectedIndex >= 0 ? choiceRepeater.itemAt(selectedIndex) : null
                property bool placed: false
                // En línea el Flow no puede deducir su ancho del implícito (los apila en columna):
                // se le da la suma exacta de las opciones para que quepan en una fila.
                readonly property real rowWidth: {
                    let width = 0
                    for (let i = 0; chipRevision >= 0 && i < choiceRepeater.count; i++) {
                        const chip = choiceRepeater.itemAt(i)
                        if (chip) width += chip.implicitWidth + (i > 0 ? 4 : 0)
                    }
                    return width
                }
                Timer { interval: 60; running: true; onTriggered: choiceGroup.placed = true }
                Rectangle {
                    width: Math.min(parent.width, choiceFlow.childrenRect.width + 8)
                    height: parent.height
                    radius: 15
                    color: Qt.alpha(Theme.foreground, Theme.liquid ? 0.06 : 0.04)
                    opacity: root.editable ? 1 : 0.5
                }
                Components.LiquidSelection {
                    readonly property Item chip: choiceGroup.selectedChip
                    targetX: chip ? choiceFlow.x + chip.x : 0
                    targetY: chip ? choiceFlow.y + chip.y : 0
                    targetWidth: chip ? chip.width : 0
                    targetHeight: chip ? chip.height : 0
                    immediate: !choiceGroup.placed || !root.visible
                    radius: 11
                    color: Theme.stateFill
                    volume: true
                    opacity: chip ? (root.editable ? 1 : 0.5) : 0
                    Behavior on opacity { enabled: root.visible; NumberAnimation { duration: Motion.fast } }
                }
                Flow {
                    id: choiceFlow
                    x: 4; y: 4
                    width: root.inlineControl ? choiceGroup.rowWidth : parent.width - 8
                    spacing: 4
                    Repeater {
                        id: choiceRepeater
                        model: root.field.options || []
                        onItemAdded: choiceGroup.chipRevision++
                        onItemRemoved: choiceGroup.chipRevision++
                        Components.MotionButton {
                            id: choice
                            required property string modelData
                            required property int index
                            readonly property bool selected: root.value === choice.modelData
                            objectName: "choice-" + modelData
                            text: root.field.optionLabels ? I18n.tr(root.field.optionLabels[index]) : modelData
                            checkable: false
                            checked: selected
                            enabled: root.editable
                            implicitHeight: Math.max(36, Theme.fontSizeBodyLg * 1.5 + 14)
                            implicitWidth: choiceLabel.implicitWidth + 32
                            font.family: Config.appearance.fontFamily
                            font.pixelSize: Theme.fontSizeBodyLg
                            Accessible.name: I18n.tr(root.field.label) + ": " + text
                            Accessible.role: Accessible.RadioButton
                            Accessible.checkable: true
                            Accessible.checked: selected
                            Accessible.description: I18n.tr(root.field.description || "")
                            onClicked: root.changeRequested(choice.modelData)
                            background: Rectangle {
                                radius: 11
                                color: !choice.selected && choice.hovered ? Qt.alpha(Theme.foreground, 0.07) : "transparent"
                                border.width: choice.activeFocus ? 2 : 0
                                border.color: Theme.accent
                                Behavior on color { enabled: root.visible; ColorAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
                            }
                            contentItem: Text {
                                id: choiceLabel
                                text: choice.text
                                font: choice.font
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: choice.selected ? Theme.stateContent : Qt.alpha(Theme.foreground, 0.82)
                                Behavior on color { enabled: root.visible; ColorAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                            }
                        }
                    }
                }
            }
        }

        Loader {
            id: sliderLoader
            active: root.field.type === "number" && root.ranged
            visible: active
            // En línea pasa a la cabecera, tras el botón de restablecer.
            parent: root.inlineControl ? headerRow : content
            Layout.fillWidth: !root.inlineControl
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.inlineControl ? Math.min(300, root.width * 0.4) : -1
            sourceComponent: RowLayout {
                property alias editor: slider
                spacing: 14
                Slider {
                    id: slider
                    objectName: "settingSlider"
                    implicitHeight: 44
                    Layout.fillWidth: true
                    enabled: root.editable
                    from: root.field.minimum ?? 0
                    to: root.field.maximum ?? 1
                    value: Number(root.value)
                    stepSize: root.field.step ?? (root.field.integer ? 1 : 0.01)
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: root.field.label
                    Accessible.description: I18n.tr(root.field.description || "")
                    onMoved: root.changeRequested(root.field.integer ? Math.round(value) : Math.round(value * 100) / 100)
                    // Con Superficies líquidas el carril es un tubo grueso: el relleno
                    // nunca baja de una gota y el botón flota dentro de su extremo.
                    readonly property real trackHeight: Theme.liquid ? (pressed ? 30 : hovered ? 28 : 26) : (hovered || pressed ? 7 : 5)
                    readonly property real fillWidth: Theme.liquid ? Math.max(trackHeight, visualPosition * availableWidth) : visualPosition * availableWidth
                    background: Rectangle {
                        x: slider.leftPadding
                        y: slider.topPadding + slider.availableHeight / 2 - height / 2
                        width: slider.availableWidth
                        height: slider.trackHeight
                        radius: height / 2
                        Behavior on height { enabled: root.visible && !root.reducedMotion; NumberAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
                        color: Qt.alpha(Theme.foreground, Theme.liquid ? 0.09 : 0.18)
                        opacity: slider.enabled ? 1 : 0.5
                        Rectangle {
                            width: slider.fillWidth
                            height: parent.height
                            radius: parent.radius
                            color: Theme.liquid ? Theme.stateFill : Theme.accent
                            gradient: Theme.liquid ? fillVolume : null
                            property Gradient fillVolume: Gradient {
                                GradientStop { position: 0; color: Theme.stateFillLight }
                                GradientStop { position: 1; color: Theme.stateFill }
                            }
                            // Menisco: brillo fino en la superficie del líquido.
                            Rectangle {
                                visible: Theme.liquid
                                x: parent.radius * 0.6; y: 1
                                width: Math.max(0, parent.width - 2 * x); height: 1
                                color: Qt.alpha("#ffffff", 0.3)
                            }
                        }
                    }
                    handle: Rectangle {
                        readonly property real size: Theme.liquid ? slider.trackHeight - (slider.pressed ? 10 : 12) : 20
                        x: Theme.liquid ? slider.leftPadding + slider.fillWidth - slider.trackHeight / 2 - width / 2
                                        : slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                        y: slider.topPadding + slider.availableHeight / 2 - height / 2
                        scale: root.reducedMotion || Theme.liquid ? 1 : slider.pressed ? 1.22 : 1
                        Behavior on scale { enabled: !root.reducedMotion && root.visible; SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping } }
                        width: size
                        height: size
                        radius: size / 2
                        color: Theme.liquid ? Qt.alpha(Theme.stateContent, slider.pressed ? 0.9 : 0.72) : Theme.foreground
                        border.width: Theme.liquid ? 0 : 1
                        border.color: Qt.alpha(Theme.background, 0.15)
                        Rectangle {
                            anchors.fill: parent; anchors.margins: -4; radius: width / 2
                            color: "transparent"; border.width: 2; border.color: Theme.liquid ? Theme.stateContent : Theme.accent
                            opacity: slider.activeFocus ? 0.5 : 0
                            Behavior on opacity { enabled: root.visible; NumberAnimation { duration: Motion.hover } }
                        }
                        Rectangle {
                            anchors.centerIn: parent; width: 6; height: 6; radius: 3
                            color: Theme.liquid ? Theme.stateFill : Theme.background
                            opacity: slider.pressed ? 0.65 : slider.hovered ? 0.25 : 0
                            Behavior on opacity { enabled: root.visible; NumberAnimation { duration: Motion.hover } }
                        }
                    }
                }
                // Valor en una cápsula que crece al arrastrar.
                Rectangle {
                    Layout.preferredWidth: Math.max(56, valueText.implicitWidth + 22)
                    Layout.preferredHeight: 32
                    radius: 16
                    color: slider.pressed ? Theme.stateFill : Qt.alpha(Theme.foreground, 0.07)
                    scale: slider.pressed && !root.reducedMotion ? 1.08 : 1
                    Behavior on color { enabled: root.visible; ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                    Behavior on scale { enabled: root.visible && !root.reducedMotion; SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping } }
                    Text {
                        id: valueText
                        anchors.centerIn: parent
                        text: Number(slider.pressed ? slider.value : root.value).toFixed(root.field.integer ? 0 : 2) + (root.field.unit ? " " + root.field.unit : "")
                        color: slider.pressed ? Theme.stateContent : Theme.foreground
                        font.family: Config.appearance.fontFamily
                        font.features: Theme.fontNumeric
                        font.pixelSize: Theme.fontSizeBodyLg
                        font.weight: Font.Medium
                    }
                }
            }
        }

        Loader {
            id: textLoader
            active: (root.field.control === "text" && !root.fontField) || root.field.control === "path" || (root.field.type === "number" && !root.ranged)
            visible: active
            Layout.fillWidth: true
            sourceComponent: RowLayout {
                property alias editor: textEditor
                spacing: 8
                EdotsTextField {
                    id: textEditor
                    objectName: "settingTextEditor"
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
                    text: I18n.tr("Elegir…")
                    symbol: "folder_open"
                    Accessible.name: I18n.tr("Seleccionar %1").arg(I18n.tr(root.field.label))
                    onClicked: root.browseRequested()
                }
            }
        }

        Loader {
            id: fontPicker
            active: root.fontField
            visible: root.fontField
            Layout.fillWidth: true
            sourceComponent: EdotsComboBox {
                enabled: root.editable
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
        }

        // Más de seis opciones: un menú en lugar de un muro de chips.
        Loader {
            id: selectLoader
            active: root.selectField
            visible: active
            // En línea pasa a la cabecera, tras el botón de restablecer.
            parent: root.inlineControl ? headerRow : content
            Layout.fillWidth: !root.inlineControl
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.inlineControl ? 240 : -1
            sourceComponent: EdotsComboBox {
                objectName: "settingSelect"
                editable: false
                previewFonts: false
                enabled: root.editable
                popupBounds: root.popupBounds
                model: (root.field.optionLabels || root.options).map(label => I18n.tr(String(label)))
                readonly property int selectedIndex: root.options.indexOf(root.value)
                configuredText: selectedIndex >= 0 ? model[selectedIndex] : ""
                Accessible.name: I18n.tr(root.field.label)
                Accessible.description: I18n.tr(root.field.description || "")
                onActivated: index => { if (root.options[index] !== root.value) root.changeRequested(root.options[index]) }
            }
        }

        Text {
            objectName: "settingValidation"
            id: validation
            readonly property string message: root.validationMessage || root.localError
            property string held: ""
            onMessageChanged: if (message.length > 0) held = message
            Component.onCompleted: held = message
            // Fades (with a 3px rise on entry) instead of popping; text is held while fading out.
            opacity: message.length > 0 ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { enabled: root.visible; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
            transform: Translate { y: validation.message.length > 0 || Flags.reduceMotion ? 0 : 3
                Behavior on y { enabled: root.visible && !Flags.reduceMotion; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } } }
            Layout.fillWidth: true
            text: held
            color: Theme.error
            font.family: Config.appearance.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            Accessible.role: Accessible.StaticText
            Accessible.name: I18n.tr("%1: %2").arg(I18n.tr(root.field.label)).arg(text)
        }
    }

    // Filete interior entre filas del mismo grupo.
    Rectangle {
        visible: !root.groupLast
        anchors.left: card.left
        anchors.right: card.right
        anchors.bottom: card.bottom
        anchors.leftMargin: 20
        height: 1
        color: Qt.alpha(Theme.foreground, 0.07)
    }
}
