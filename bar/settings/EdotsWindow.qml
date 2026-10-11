import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import "../Singletons"
import "../components"

FocusScope {
    id: root
    implicitWidth: 1000; implicitHeight: 700
    property bool contentReady: true
    readonly property bool pathPickerOpen: settingsPage.pickerOpen
    signal requestClose()
    function activate() {
        if (contentReady && visible && enabled && !activeFocus) body.forceActiveFocus()
    }
    function showProfile() { activate(); root.page = 4; search.text = "" }
    onContentReadyChanged: { if (contentReady) activate(); else settingsPage.closePicker() }
    property alias previewScene: studio.scene
    property alias searchQuery: search.text
    readonly property int resultCount: settingsPage.entries.length
    readonly property string validationError: settingsPage.validationError
    property bool showPreview: false
    property int page: 0
    readonly property bool compactNavigation: width < 760 || Config.appearance.fontScale > 1.35
    readonly property bool richComposition: height >= 680 && width >= 800 && Config.appearance.fontScale <= 1.35
    property bool savePending: false
    property string feedback: ""
    readonly property var sections: ["appearance", "modules", "appearance", "appearance", "profile", "paths"]
    readonly property var pageFields: [
        ["appearance.workspaceStyle", "appearance.glassAlpha", "appearance.uiScale", "appearance.topGap", "appearance.appGap", "appearance.spacingScale", "appearance.radiusScale", "appearance.time12h"],
        root.richComposition ? [] : ["appearance.barLayout"].concat(Object.keys(Config.schema.sections.modules).map(key => "modules." + key)),
        ["appearance.motionScale", "appearance.reduceMotion", "modules.animateChanges"],
        ["appearance.fontFamily", "appearance.fontMonoFamily", "appearance.fontDisplayFamily", "appearance.fontMediaFamily", "appearance.fontScale"],
        ["profile.displayName", "paths.userAvatar"],
        ["paths.walColorsFile", "paths.wallpaperDir", "paths.wallpaperCacheDir", "paths.wallpaperApplyScript", "appearance.pillBlur", "appearance.clockSeconds", "appearance.showGlyphs"]
    ]
    readonly property var symbols: ["palette", "dashboard", "animation", "text_fields", "person", "settings"]
    readonly property var titles: [qsTr("Apariencia"), qsTr("Composición"), qsTr("Movimiento"), qsTr("Tipografía"), qsTr("Tu perfil"), qsTr("Avanzado")]
    readonly property var subtitles: [qsTr("Dale a Isla tu forma de sentir el escritorio."), qsTr("Elige qué te acompaña. La Isla permanece en el centro."), qsTr("Ajusta el ritmo. Prueba la respuesta antes de guardar."), qsTr("Una lectura cómoda, con tu propia personalidad."), qsTr("Los pequeños detalles que hacen tuyo este espacio."), qsTr("Archivos y carpetas que utiliza tu shell.")]
    onPageChanged: if (contentReady && visible && enabled) body.forceActiveFocus()
    EdotsPageMotion {
        id: pageMotion
        requestedPage: root.page
        reduced: Config.appearance.reduceMotion
        active: root.visible && root.contentReady
    }
    function saveChanges() {
        body.forceActiveFocus()
        feedback = ""
        if (!settingsPage.commitDrafts()) { settingsPage.focusFirstError(); return }
        savePending = Config.dirty
        if (!Config.save()) { feedback = qsTr("No se pudo iniciar el guardado."); savePending = false }
    }
    Connections {
        target: Config
        function onSavingChanged() {
            if (root.savePending && !Config.saving) {
                root.feedback = Config.error || qsTr("Cambios guardados")
                root.savePending = false
            }
        }
    }
    // Keep fading controls inert without their disabled visual treatment.
    Shortcut { sequence: "Tab"; enabled: root.visible && root.contentReady && !root.pathPickerOpen && pageMotion.transitioning; onActivated: body.forceActiveFocus() }
    Shortcut { sequence: "Shift+Tab"; enabled: root.visible && root.contentReady && !root.pathPickerOpen && pageMotion.transitioning; onActivated: body.forceActiveFocus() }
    MouseArea {
        x: body.x + pageContent.x
        y: body.y + pageContent.y + pageMotion.travel
        width: pageContent.width; height: pageContent.height
        z: 100
        visible: pageMotion.transitioning && pageMotion.exposure < 0.9
        acceptedButtons: Qt.AllButtons
        onWheel: event => event.accepted = true
    }
    Shortcut { sequence: "Ctrl+S"; enabled: root.visible && root.contentReady && !root.pathPickerOpen; onActivated: root.saveChanges() }
    Shortcut { sequence: "Ctrl+F"; enabled: root.visible && root.contentReady && !root.pathPickerOpen; onActivated: search.forceActiveFocus() }
    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.margins: root.width < 760 || root.height < 620 ? 16 : 32
        spacing: root.height < 620 ? 10 : 16
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            TopUserStatus {
                objectName: "settingsUserAvatar"
                Layout.preferredWidth: 44; Layout.preferredHeight: 44
                avatarSource: Config.userAvatarUrl
                userName: Config.profile.displayName || Config.home.split("/").pop()
                Accessible.name: qsTr("Editar tu perfil")
                onClicked: root.showProfile()
            }
            Image {
                visible: root.width >= 820 && Config.appearance.fontScale <= 1.35
                Accessible.ignored: true
                source: "assets/edots.png"; sourceSize: Qt.size(96, 96)
                Layout.preferredWidth: 44; Layout.preferredHeight: 44
                scale: Config.appearance.reduceMotion ? 1 : brandHover.hovered ? 1.12 : 1
                rotation: Config.appearance.reduceMotion ? 0 : brandHover.hovered ? -8 : 0
                Behavior on scale { enabled: root.visible && root.contentReady && !Config.appearance.reduceMotion; SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping } }
                Behavior on rotation { enabled: root.visible && root.contentReady && !Config.appearance.reduceMotion; NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }
                HoverHandler { id: brandHover }
            }
            Column {
                spacing: 2
                Text { text: "Edots"; color: Theme.foreground; font.family: Config.appearance.fontDisplayFamily; font.pixelSize: 24 * Math.min(1.35, Config.appearance.fontScale); font.weight: Font.DemiBold }
                Text { visible: root.width >= 760; text: qsTr("Tu Isla, a tu manera"); color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontFamily; font.pixelSize: Math.max(12, Theme.fontSizeBody) }
            }
            Item { Layout.fillWidth: true }
            EdotsTextField {
                id: search; objectName: "settingsSearch"; Layout.preferredWidth: Math.min(320, body.width * 0.42); implicitHeight: Math.max(44, Theme.fontSizeBodyLg + 24)
                Accessible.name: qsTr("Buscar en todos los ajustes")
                Accessible.description: qsTr("Ctrl+F para buscar. Escape borra la búsqueda.")
                placeholderText: root.width < 760 ? qsTr("Buscar ajustes") : qsTr("Buscar ajustes  ·  Ctrl+F"); color: Theme.foreground; placeholderTextColor: "transparent"
                font.family: Config.appearance.fontFamily; font.pixelSize: Math.max(12, Theme.fontSizeBody)
                selectByMouse: true; leftPadding: 15
                selectionColor: Theme.accent; selectedTextColor: Theme.background
                Keys.onEscapePressed: { text = ""; body.forceActiveFocus() }
                cornerRadius: height / 2
            }
            EdotsButton { text: ""; symbol: "close"; implicitWidth: 44; Accessible.name: qsTr("Volver a Isla"); onClicked: root.requestClose() }
        }
        Item {
            Layout.fillWidth: true; implicitHeight: root.compactNavigation ? 96 : 64
            Rectangle { anchors.fill: parent; radius: 20; color: Qt.alpha(Theme.foreground, 0.035) }
            Rectangle {
                id: navigationLens
                x: (root.page % navigation.columns) * (parent.width / navigation.columns) + 4
                y: Math.floor(root.page / navigation.columns) * (parent.height / (root.compactNavigation ? 2 : 1)) + 4
                width: parent.width / navigation.columns - 8; height: parent.height / (root.compactNavigation ? 2 : 1) - 8; radius: 16
                color: Qt.alpha(Theme.accent, 0.17); border.width: 1; border.color: Qt.alpha(Theme.accent, 0.24)
                Behavior on x { enabled: !Config.appearance.reduceMotion && root.visible; SmoothedAnimation { duration: Motion.emphasized; velocity: -1 } }
                Behavior on y { enabled: !Config.appearance.reduceMotion && root.visible; SmoothedAnimation { duration: Motion.emphasized; velocity: -1 } }
            }
            Grid {
                id: navigation
                anchors.fill: parent
                columns: root.compactNavigation ? 3 : 6
                Repeater {
                    model: root.titles
                    MotionButton {
                        id: nav
                        required property int index
                        required property string modelData
                        objectName: "settingsNav" + index
                        width: parent.width / navigation.columns; height: parent.height / (root.compactNavigation ? 2 : 1)
                        onClicked: { body.forceActiveFocus(); root.page = index; search.text = "" }
                        background: Rectangle {
                            anchors.fill: parent; anchors.margins: 4; radius: 16
                            color: nav.hovered ? Qt.alpha(Theme.foreground, 0.06) : "transparent"
                            border.width: nav.activeFocus ? 1 : 0; border.color: Theme.accent
                            Behavior on color { ColorAnimation { duration: Motion.hover } }
                        }
                        contentItem: Column {
                            spacing: 5
                            EdotsIcon { visible: !root.compactNavigation; Accessible.ignored: true; anchors.horizontalCenter: parent.horizontalCenter; iconName: root.symbols[nav.index]; font.pixelSize: 19; color: root.page === nav.index ? Theme.accent : Theme.foreground; interaction: nav.interaction; selected: root.page === nav.index }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: nav.modelData; color: root.page === nav.index ? Theme.foreground : Qt.alpha(Theme.foreground, 0.75); font.family: Config.appearance.fontFamily; font.pixelSize: Math.max(12, Theme.fontSizeBody); Behavior on color { ColorAnimation { duration: Motion.fast } } }
                        }
                        Accessible.name: modelData
                        Accessible.role: Accessible.PageTab
                        Accessible.selected: root.page === index
                    }
                }
            }
        }
        ColumnLayout {
            id: pageContent
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: root.height < 620 ? 8 : 16
            opacity: pageMotion.exposure
            transform: Translate { y: pageMotion.travel }
        Column {
            Layout.fillWidth: true; spacing: 7
            Text { text: search.text ? qsTr("Resultados de búsqueda") : root.titles[pageMotion.displayedPage]; color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: 24 * Math.min(1.35, Config.appearance.fontScale); font.weight: Font.DemiBold }
            Text { visible: root.height >= 620; width: parent.width; text: search.text ? qsTr("%1 ajustes encontrados en toda la configuración.").arg(settingsPage.entries.length) : root.subtitles[pageMotion.displayedPage]; color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontFamily; font.pixelSize: Math.max(13, Theme.fontSizeBodyLg); wrapMode: Text.WordWrap }
        }
        EdotsButton {
            visible: search.text.length > 0 && settingsPage.entries.length === 0
            text: qsTr("Limpiar búsqueda")
            onClicked: { search.text = ""; search.forceActiveFocus() }
        }
        ModuleComposer {
            Layout.fillWidth: true; visible: !search.text && pageMotion.displayedPage === 1 && root.richComposition
            config: Config
            onEditFailed: message => root.feedback = message
            onEdited: root.feedback = ""
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 104; radius: 14; color: Qt.alpha(Theme.foreground, 0.035)
            visible: !search.text && pageMotion.displayedPage === 3 && root.height >= 680
            Column {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 22 } spacing: 7
                Text { text: qsTr("Un escritorio que habla tu idioma."); color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: 21 * Math.min(1.4, Config.appearance.fontScale); width: parent.width; elide: Text.ElideRight }
                Text { text: "Aa Bb Cc · 0123456789"; color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontMonoFamily; font.pixelSize: 13 }
            }
        }
        RowLayout {
            Layout.fillWidth: true; visible: !search.text && pageMotion.displayedPage === 4 && root.height >= 620
            spacing: 16
            UserAvatar {
                objectName: "profileUserAvatar"
                Layout.preferredWidth: 80; Layout.preferredHeight: 80
                source: Config.userAvatarUrl
                name: Config.profile.displayName || Config.home.split("/").pop()
                fontFamily: Config.appearance.fontFamily
            }
            Column {
                Layout.fillWidth: true; spacing: 5
                Text { text: Config.profile.displayName || qsTr("Tu espacio personal"); color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: 20; width: parent.width; elide: Text.ElideRight }
                Text { text: qsTr("Así te presenta Isla en la sesión."); color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontFamily; font.pixelSize: Math.max(12, Theme.fontSizeBody) }
            }
        }
        RowLayout {
            Layout.fillWidth: true; visible: !search.text && pageMotion.displayedPage === 5
            Text { text: qsTr("Opciones limitadas o sin efecto"); color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontFamily; font.pixelSize: Math.max(12, Theme.fontSizeBody); Layout.fillWidth: true }
            EdotsButton { text: settingsPage.showUnavailable ? qsTr("Ocultar") : qsTr("Mostrar"); onClicked: settingsPage.showUnavailable = !settingsPage.showUnavailable }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 24
        SettingsPage {
            id: settingsPage; visible: search.text.length > 0 || pageMotion.displayedPage !== 1 || !root.richComposition
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 260
            popupBounds: root
            config: Config; section: root.sections[pageMotion.displayedPage]; fieldKeys: root.pageFields[pageMotion.displayedPage]; query: search.text
            onEdited: root.feedback = ""
            onErrorFieldRequested: id => {
                const dot = id.indexOf(".")
                search.text = Config.schema.sections[id.slice(0, dot)][id.slice(dot + 1)].label
                Qt.callLater(() => settingsPage.focusFirstError())
            }
        }
            ColumnLayout {
                visible: !search.text && pageMotion.displayedPage === 2 && root.width >= 900 && root.height >= 660 && Config.appearance.fontScale <= 1.35
                Layout.preferredWidth: root.width < 900 ? 270 : 330
                Layout.maximumWidth: root.width < 900 ? 270 : 330
                Layout.fillHeight: true; spacing: 16
        IslandStudio { id: studio; Layout.fillWidth: true; Layout.preferredHeight: 260 }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Repeater {
                model: [{label: qsTr("Ágil"), scale: 0.7}, {label: qsTr("Natural"), scale: 1}, {label: qsTr("Pausado"), scale: 1.4}]
                EdotsButton {
                    required property var modelData
                    text: modelData.label
                    accent: Math.abs(Config.appearance.motionScale - modelData.scale) < 0.01
                    enabled: Config.loaded && !Config.saving
                    onClicked: { const result = Config.update({appearance: {motionScale: modelData.scale}}); if (!result.ok) root.feedback = result.errors.join(" · ") }
                }
            }
            Item { Layout.fillWidth: true }
        }

                Item { Layout.fillHeight: true }
            }
        }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 8
            Text {
                objectName: "settingsStatus"
                Layout.fillWidth: true
                text: Config.saving ? qsTr("Guardando…") : Config.error || (settingsPage.validationError ? qsTr("No se guardaron los cambios. Revisa los ajustes marcados.")
                    : (Config.dirty || settingsPage.hasDrafts) ? qsTr("Vista previa activa · Guarda para conservar los cambios")
                    : root.feedback || qsTr("Todos los cambios están guardados"))
                color: Config.error || settingsPage.validationError ? Theme.error : Theme.foreground
                font.family: Config.appearance.fontFamily
                font.pixelSize: Math.max(12, Theme.fontSizeBody)
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                EdotsButton { visible: Config.error.length > 0; text: qsTr("Recargar"); onClicked: { settingsPage.clearValidation(); Config.reload() } }
                EdotsButton { visible: settingsPage.validationError.length > 0; text: qsTr("Revisar ajuste"); onClicked: settingsPage.focusFirstError() }
                Item { Layout.fillWidth: true }
                EdotsButton { text: qsTr("Descartar"); enabled: (Config.dirty || settingsPage.hasDrafts || settingsPage.validationError.length > 0) && !Config.saving; onClicked: { body.forceActiveFocus(); Config.discard(); settingsPage.clearValidation(); root.feedback = qsTr("Cambios descartados") } }
                EdotsButton { objectName: "settingsSave"; text: qsTr("Guardar"); symbol: "check"; accent: true; enabled: Config.loaded && !Config.saving && !Config.error && (Config.dirty || settingsPage.hasDrafts); onClicked: root.saveChanges() }
            }
        }
    }
}
