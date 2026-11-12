import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../Singletons"

ColumnLayout {
    id: root
    required property var controller
    // Plugin manager, connected from composition (EdotsWindow).
    property var plugins: null
    readonly property bool editable: controller.available && !controller.busy && !controller.persistenceError
    readonly property var animationGroups: [
        {key: "windowsIn", label: I18n.tr("Entrada de ventanas"), description: I18n.tr("Cómo aparecen las ventanas que abres.")},
        {key: "windowsOut", label: I18n.tr("Salida de ventanas"), description: I18n.tr("Cómo desaparecen las ventanas que cierras.")},
        {key: "workspaces", label: I18n.tr("Cambio de espacio"), description: I18n.tr("La transición entre tus espacios de trabajo.")}
    ]
    readonly property string searchTerms: I18n.tr("Hyprland flujo ventanas scrolling columnas dwindle mosaico master principal animaciones entrada apertura salida cierre workspace espacios duración estilo plugins")
    spacing: 12
    function loadPlugins() { if (plugins && !plugins.busy) plugins.status() }
    function stateLabel(state) {
        const labels = {"loaded": I18n.tr("Cargado"), "paused": I18n.tr("Pausado"),
            "incompatible": I18n.tr("Incompatible"), "missing": I18n.tr("No instalado")}
        return labels[state] || state
    }
    onVisibleChanged: if (visible) { controller.initialize(); loadPlugins() }
    Component.onCompleted: if (visible) { controller.initialize(); loadPlugins() }

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
        const labels = {"slide": I18n.tr("Deslizar"), "slidevert": I18n.tr("Vertical"),
            "fade": I18n.tr("Fundido"), "slidefade": I18n.tr("Deslizar + fundido"),
            "slidefadevert": I18n.tr("Vertical + fundido"), "popin": I18n.tr("Zoom"),
            "popin 94%": I18n.tr("Zoom suave"), "popin 97%": I18n.tr("Zoom mínimo"),
            "gnomed": I18n.tr("Desde el borde")}
        return labels[style] || style || I18n.tr("Heredado")
    }
    function saveChanges() { controller.save() }

    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: controller.available ? I18n.tr("Conectado · Hyprland %1").arg(controller.version) : I18n.tr("Hyprland no está disponible")
            font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
            color: Theme.foreground; wrapMode: Text.WordWrap
        }
        EdotsButton {
            objectName: "hyprlandRefresh"
            text: I18n.tr("Actualizar"); symbol: "refresh"
            enabled: !controller.busy && !controller.dirty
            Accessible.description: I18n.tr("Leer la configuración actual del compositor")
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
                text: I18n.tr("Los cambios se prueban en la sesión. Abre una ventana o cambia de espacio para verlos. Guarda para conservarlos al iniciar Azog.")
                color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                wrapMode: Text.WordWrap
            }
            SettingRow {
                objectName: "hyprlandLayout"
                Layout.fillWidth: true
                fieldKey: "layout"
                value: root.controller.values.layout || ""
                field: root.field("string", I18n.tr("Flujo de ventanas"), value, {
                    control: "choice", options: ["scrolling", "dwindle", "master"],
                    optionLabels: [I18n.tr("Columnas"), I18n.tr("Mosaico"), I18n.tr("Principal")],
                    description: I18n.tr("Columnas: desplazamiento horizontal. Mosaico: divisiones automáticas. Principal: una ventana protagonista y las demás al lado.")})
                editorEnabled: root.editable
                reducedMotion: Config.appearance.reduceMotion
                onChangeRequested: value => root.controller.update({layout: value})
            }
            Text {
                Layout.fillWidth: true
                visible: root.controller.available && root.controller.workspacesChildrenOverridden
                text: I18n.tr("Tu configuración tiene transiciones propias para entrar o salir de un espacio. Pueden prevalecer sobre el estilo general de cambio de espacio.")
                color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                visible: root.controller.available && root.controller.animationsEnabled === false
                text: I18n.tr("Las animaciones están desactivadas en tu configuración general de Hyprland. Estos ajustes se verán cuando las actives allí.")
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
                                ? group.modelData.description : I18n.tr("Heredada de otra animación. Conserva su configuración desde el archivo de Hyprland.")})
                        editorEnabled: group.canEdit
                        reducedMotion: Config.appearance.reduceMotion
                        onChangeRequested: value => root.changeAnimation(group.modelData.key, "enabled", value)
                    }
                    SettingRow {
                        objectName: "hyprland-" + group.modelData.key + "-style"
                        Layout.fillWidth: true
                        fieldKey: "style"
                        value: group.animation.style
                        field: root.field("string", I18n.tr("Estilo"), value, {
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
                        field: root.field("number", I18n.tr("Duración · ms"), value, {
                            minimum: 10, maximum: Math.max(1500, value),
                            description: root.controller.springLeaves[group.modelData.key]
                                ? I18n.tr("Esta animación usa un resorte físico. Su duración la define la curva, que se conserva.")
                                : I18n.tr("Menos tiempo hace el movimiento más ágil. Conserva la curva actual de tu configuración.")})
                        editorEnabled: group.canEdit && group.animation.enabled && !root.controller.springLeaves[group.modelData.key]
                        reducedMotion: Config.appearance.reduceMotion
                        onChangeRequested: value => root.changeAnimation(group.modelData.key, "speed", Math.round(value) / 100)
                    }
                }
            }
            // ── Plugins ──────────────────────────────────────────────────────
            ColumnLayout {
                id: pluginSection
                objectName: "hyprlandPlugins"
                Layout.fillWidth: true
                visible: !!root.plugins && (root.plugins.plugins.length > 0 || root.plugins.error.length > 0)
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: I18n.tr("Plugins · Hyprland %1").arg(root.plugins ? root.plugins.hyprlandVersion : "")
                        color: Theme.foreground; font.family: Config.appearance.fontFamily
                        font.pixelSize: Theme.fontSizeBodyLg; font.weight: Font.DemiBold
                        Accessible.role: Accessible.Heading; Accessible.name: text
                    }
                    EdotsButton {
                        objectName: "hyprlandPluginsCheck"
                        text: root.plugins && root.plugins.busy && root.plugins.updatingId === ""
                            ? I18n.tr("Comprobando…") : I18n.tr("Comprobar")
                        symbol: "refresh"
                        enabled: !!root.plugins && !root.plugins.busy
                        Accessible.description: I18n.tr("Buscar versiones nuevas de los plugins compatibles con tu Hyprland")
                        onClicked: root.plugins.check()
                    }
                }
                Text {
                    objectName: "hyprlandPluginsStale"
                    Layout.fillWidth: true
                    visible: !!root.plugins && root.plugins.staleCount > 0
                    text: I18n.tr("Hyprland se actualizó y algunos plugins quedaron obsoletos. Actualízalos para que vuelvan a cargar.")
                    color: Theme.error; font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.StaticText; Accessible.name: text
                }
                Repeater {
                    model: root.plugins ? root.plugins.plugins : []
                    RowLayout {
                        id: pluginRow
                        required property var modelData
                        readonly property bool updating: !!root.plugins && root.plugins.updatingId === modelData.id
                        objectName: "hyprlandPlugin-" + modelData.id
                        Layout.fillWidth: true
                        spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: pluginRow.modelData.name + (pluginRow.modelData.version ? " · " + pluginRow.modelData.version : "")
                                color: Theme.foreground; font.family: Config.appearance.fontFamily
                                font.pixelSize: Theme.fontSizeBody; elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: {
                                    const m = pluginRow.modelData
                                    const parts = [root.stateLabel(m.state)]
                                    if (m.updateAvailable && m.latest) parts.push(I18n.tr("Disponible %1").arg(m.latest))
                                    else if (m.latest) parts.push(I18n.tr("Al día"))
                                    if (m.message) parts.push(m.message)
                                    return parts.join(" · ")
                                }
                                color: pluginRow.modelData.state === "incompatible" ? Theme.error : Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                                font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                                wrapMode: Text.WordWrap
                            }
                        }
                        EdotsButton {
                            objectName: "hyprlandPluginUpdate-" + pluginRow.modelData.id
                            visible: !!pluginRow.modelData.updateAvailable
                            text: pluginRow.updating ? I18n.tr("Actualizando…") : I18n.tr("Actualizar")
                            symbol: "download"
                            enabled: !!root.plugins && !root.plugins.busy
                            Accessible.name: I18n.tr("Actualizar %1").arg(pluginRow.modelData.name)
                            onClicked: root.plugins.update(pluginRow.modelData.id)
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: !!root.plugins && (root.plugins.error.length > 0 || root.plugins.feedback.length > 0)
                    text: root.plugins ? (root.plugins.error || root.plugins.feedback) : ""
                    color: root.plugins && root.plugins.error ? Theme.error : Theme.foreground
                    font.family: Config.appearance.fontFamily; font.pixelSize: Theme.fontSizeBody
                    wrapMode: Text.WordWrap
                    Accessible.role: Accessible.StaticText; Accessible.name: text
                }
            }
        }
    }
    Text {
        objectName: "hyprlandStatus"
        Layout.fillWidth: true
        readonly property string current: controller.error || (controller.busy ? I18n.tr("Aplicando…")
            : controller.dirty ? I18n.tr("Vista previa activa · Guarda para usarla en próximos inicios de Azog.")
            : controller.feedback)
        // Keep the last message while it fades out instead of blanking first.
        property string retained: ""
        onCurrentChanged: if (current.length > 0) retained = current
        Component.onCompleted: retained = current
        text: current.length > 0 ? current : retained
        opacity: current.length > 0 ? 1 : 0
        visible: opacity > 0.01
        transform: Translate { y: Flags.reduceMotion ? 0 : 4 * (1 - opacity) }
        Behavior on opacity { NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
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
            text: I18n.tr("Usar sesión actual")
            enabled: root.controller.available && !root.controller.busy
            Accessible.description: I18n.tr("Reemplazar el archivo guardado inválido por los ajustes actuales. Se conserva una copia del archivo anterior.")
            onClicked: root.controller.resetSaved()
        }
        Item { Layout.fillWidth: true }
        EdotsButton {
            objectName: "hyprlandDiscard"
            text: I18n.tr("Revertir")
            enabled: root.editable && root.controller.dirty
            onClicked: root.controller.discard()
        }
        EdotsButton {
            objectName: "hyprlandSave"
            text: I18n.tr("Guardar"); symbol: "check"; accent: true
            enabled: root.editable && root.controller.dirty && !root.controller.error
            onClicked: root.saveChanges()
        }
    }
}
