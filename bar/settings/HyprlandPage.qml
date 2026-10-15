import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../Singletons"

ColumnLayout {
    id: root
    required property var controller
    readonly property bool editable: controller.available && !controller.busy && !controller.persistenceError
    readonly property var animationGroups: [
        {key: "windowsIn", label: qsTr("Entrada de ventanas"), description: qsTr("Cómo aparecen las ventanas que abres.")},
        {key: "windowsOut", label: qsTr("Salida de ventanas"), description: qsTr("Cómo desaparecen las ventanas que cierras.")},
        {key: "workspaces", label: qsTr("Cambio de espacio"), description: qsTr("La transición entre tus espacios de trabajo.")}
    ]
    readonly property string searchTerms: qsTr("Hyprland flujo ventanas scrolling columnas dwindle mosaico master principal animaciones entrada apertura salida cierre workspace espacios duración estilo")
    spacing: 12
    onVisibleChanged: if (visible) controller.initialize()
    Component.onCompleted: if (visible) controller.initialize()

    function field(type, label, value, extra) {
        return Object.assign({type: type, label: label, default: value}, extra || {})
    }
    function changeAnimation(leaf, key, value) {
        controller.update({[leaf]: {[key]: value}})
    }
    function styles(leaf, current) {
        const choices = leaf === "workspaces"
            ? ["slide", "slidevert", "fade", "slidefade", "slidefadevert"]
            : ["popin 94%", "popin 97%", "popin", "slide", "gnomed"]
        if (current && !choices.includes(current)) choices.unshift(current)
        return choices
    }
    function styleLabel(style) {
        const labels = {"slide": qsTr("Deslizar"), "slidevert": qsTr("Vertical"),
            "fade": qsTr("Fundido"), "slidefade": qsTr("Deslizar + fundido"),
            "slidefadevert": qsTr("Vertical + fundido"), "popin": qsTr("Zoom"),
            "popin 94%": qsTr("Zoom suave"), "popin 97%": qsTr("Zoom mínimo"),
            "gnomed": qsTr("Desde el borde")}
        return labels[style] || style || qsTr("Heredado")
    }
    function saveChanges() { controller.save() }

    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: controller.available ? qsTr("Conectado · Hyprland %1").arg(controller.version) : qsTr("Hyprland no está disponible")
            font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
            color: Theme.foreground; wrapMode: Text.WordWrap
        }
        EdotsButton {
            objectName: "hyprlandRefresh"
            text: qsTr("Actualizar"); symbol: "refresh"
            enabled: !controller.busy && !controller.dirty
            Accessible.description: qsTr("Leer la configuración actual del compositor")
            onClicked: controller.refresh()
        }
    }
    ScrollView {
        id: scroll
        objectName: "hyprlandScroll"
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ColumnLayout {
            width: scroll.availableWidth
            spacing: 16
            Text {
                Layout.fillWidth: true
                text: qsTr("Los cambios se prueban en la sesión. Abre una ventana o cambia de espacio para verlos. Guarda para conservarlos al iniciar Isla.")
                color: Qt.alpha(Theme.foreground, 0.72)
                font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                wrapMode: Text.WordWrap
            }
            SettingRow {
                objectName: "hyprlandLayout"
                Layout.fillWidth: true
                fieldKey: "layout"
                value: root.controller.values.layout || ""
                field: root.field("string", qsTr("Flujo de ventanas"), value, {
                    control: "choice", options: ["scrolling", "dwindle", "master"],
                    optionLabels: [qsTr("Columnas"), qsTr("Mosaico"), qsTr("Principal")],
                    description: qsTr("Columnas: desplazamiento horizontal. Mosaico: divisiones automáticas. Principal: una ventana protagonista y las demás al lado.")})
                editorEnabled: root.editable
                reducedMotion: Config.appearance.reduceMotion
                onChangeRequested: value => root.controller.update({layout: value})
            }
            Text {
                Layout.fillWidth: true
                visible: root.controller.available && root.controller.workspacesChildrenOverridden
                text: qsTr("Tu configuración tiene transiciones propias para entrar o salir de un espacio. Pueden prevalecer sobre el estilo general de cambio de espacio.")
                color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                visible: root.controller.available && root.controller.animationsEnabled === false
                text: qsTr("Las animaciones están desactivadas en tu configuración general de Hyprland. Estos ajustes se verán cuando las actives allí.")
                color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                wrapMode: Text.WordWrap
            }
            Repeater {
                model: root.animationGroups
                ColumnLayout {
                    id: group
                    required property var modelData
                    readonly property var animation: root.controller.values[modelData.key] || {enabled: false, speed: 1, style: ""}
                    readonly property bool canEdit: root.editable && !!root.controller.editableLeaves[modelData.key]
                    Layout.fillWidth: true
                    spacing: 0
                    SettingRow {
                        objectName: "hyprland-" + group.modelData.key + "-enabled"
                        Layout.fillWidth: true
                        fieldKey: "enabled"
                        value: group.animation.enabled
                        field: root.field("boolean", group.modelData.label, value, {
                            control: "toggle", description: group.canEdit || !root.controller.available
                                ? group.modelData.description : qsTr("Heredada de otra animación. Conserva su configuración desde el archivo de Hyprland.")})
                        editorEnabled: group.canEdit
                        reducedMotion: Config.appearance.reduceMotion
                        onChangeRequested: value => root.changeAnimation(group.modelData.key, "enabled", value)
                    }
                    SettingRow {
                        objectName: "hyprland-" + group.modelData.key + "-style"
                        Layout.fillWidth: true
                        fieldKey: "style"
                        value: group.animation.style
                        field: root.field("string", qsTr("Estilo"), value, {
                            control: "choice", options: root.styles(group.modelData.key, value),
                            optionLabels: root.styles(group.modelData.key, value).map(root.styleLabel)})
                        editorEnabled: group.canEdit && group.animation.enabled
                        reducedMotion: Config.appearance.reduceMotion
                        onChangeRequested: value => root.changeAnimation(group.modelData.key, "style", value)
                    }
                    SettingRow {
                        objectName: "hyprland-" + group.modelData.key + "-duration"
                        Layout.fillWidth: true
                        fieldKey: "duration"
                        value: Math.round(group.animation.speed * 100)
                        field: root.field("number", qsTr("Duración · ms"), value, {
                            minimum: 10, maximum: Math.max(1500, value),
                            description: root.controller.springLeaves[group.modelData.key]
                                ? qsTr("Esta animación usa un resorte físico. Su duración la define la curva, que se conserva.")
                                : qsTr("Menos tiempo hace el movimiento más ágil. Conserva la curva actual de tu configuración.")})
                        editorEnabled: group.canEdit && group.animation.enabled && !root.controller.springLeaves[group.modelData.key]
                        reducedMotion: Config.appearance.reduceMotion
                        onChangeRequested: value => root.changeAnimation(group.modelData.key, "speed", Math.round(value) / 100)
                    }
                }
            }
        }
    }
    Text {
        objectName: "hyprlandStatus"
        Layout.fillWidth: true
        visible: controller.error.length > 0 || controller.busy || controller.dirty || controller.feedback.length > 0
        text: controller.error || (controller.busy ? qsTr("Aplicando…")
            : controller.dirty ? qsTr("Vista previa activa · Guarda para usarla en próximos inicios de Isla.")
            : controller.feedback)
        color: controller.error ? Theme.error : Theme.foreground
        font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
        wrapMode: Text.WordWrap
        Accessible.role: Accessible.StaticText; Accessible.name: text
    }
    RowLayout {
        Layout.fillWidth: true
        EdotsButton {
            objectName: "hyprlandRecover"
            visible: !!root.controller.persistenceError
            text: qsTr("Usar sesión actual")
            enabled: root.controller.available && !root.controller.busy
            Accessible.description: qsTr("Reemplazar el archivo guardado inválido por los ajustes actuales. Se conserva una copia del archivo anterior.")
            onClicked: root.controller.resetSaved()
        }
        Item { Layout.fillWidth: true }
        EdotsButton {
            objectName: "hyprlandDiscard"
            text: qsTr("Revertir")
            enabled: root.editable && root.controller.dirty
            onClicked: root.controller.discard()
        }
        EdotsButton {
            objectName: "hyprlandSave"
            text: qsTr("Guardar"); symbol: "check"; accent: true
            enabled: root.editable && root.controller.dirty && !root.controller.error
            onClicked: root.saveChanges()
        }
    }
}
