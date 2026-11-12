import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import "../Singletons"
import "../components"
import "../kit"

FocusScope {
    id: root
    implicitWidth: 1000; implicitHeight: 700
    property bool contentReady: true
    readonly property bool escapeClearsSearch: search.activeFocus && search.text.length > 0
    readonly property bool pathPickerOpen: settingsPage.pickerOpen
    signal requestClose()
    function activate() {
        if (contentReady && visible && enabled && !activeFocus) body.forceActiveFocus()
    }
    function showProfile() { activate(); root.page = 4; search.text = "" }
    onContentReadyChanged: { if (contentReady) activate(); else settingsPage.closePicker() }
    property alias previewScene: studio.scene
    property alias searchQuery: search.text
    readonly property int resultCount: settingsPage.entries.length + (hyprlandSearchMatch ? 1 : 0) + (updatesSearchMatch ? 1 : 0) + (shortcutsSearchMatch ? 1 : 0)
    readonly property string validationError: settingsPage.validationError
    property bool showPreview: false
    property int page: 0
    property var hyprlandController: HyprlandSettings
    property var updatesController: SystemUpdates
    property var pluginsController: HyprlandPlugins
    property var bindsController: HyprlandBinds
    // Atajos tiene página propia; Sistema, la última, agrupa ajustes generales, Hyprland y Actualizaciones en pestañas.
    readonly property int shortcutsPage: 6
    readonly property int systemPage: 7
    property string systemTab: "general"
    function showSystem(tab) { root.page = systemPage; root.systemTab = tab; search.text = "" }
    function showShortcuts() { root.page = shortcutsPage; search.text = "" }
    readonly property bool updatesActive: !searchShown && pageMotion.displayedPage === systemPage && systemTab === "updates"
    function showUpdates() { showSystem("updates"); SystemUpdates.portalRequested = false }
    Connections { target: SystemUpdates; function onOpenRequested() { root.showUpdates() } }
    Component.onCompleted: {
        if (SystemUpdates.portalRequested) root.showUpdates()
        else if (bindsController && bindsController.focusId) showShortcuts()
    }
    readonly property bool searchShown: pageMotion.displayedSearching
    property string heldQuery: ""
    onSearchQueryChanged: if (searchQuery.length > 0) heldQuery = searchQuery
    property bool pendingErrorFocus: false
    Connections {
        target: pageMotion
        function onRequestedSearchingChanged() { if (!pageMotion.requestedSearching) root.pendingErrorFocus = false }
    }
    onSearchShownChanged: if (searchShown && pendingErrorFocus) {
        pendingErrorFocus = false
        Qt.callLater(() => settingsPage.focusFirstError())
    }
    readonly property bool hyprlandActive: !searchShown && pageMotion.displayedPage === systemPage && systemTab === "hyprland"
    readonly property bool shortcutsActive: !searchShown && pageMotion.displayedPage === shortcutsPage
    onShortcutsActiveChanged: if (shortcutsActive && bindsController && !bindsController.busy) bindsController.load()
    readonly property bool shortcutsSearchMatch: {
        const terms = settingsPage.normalize(search.text).trim().split(/\s+/).filter(Boolean)
        const haystack = settingsPage.normalize(I18n.tr("atajos teclas teclado combinación combinaciones keybinds shortcuts"))
        return terms.length > 0 && terms.every(term => haystack.includes(term))
    }
    // Explorer → manager hand-off: open on the bind the explorer was showing.
    Connections {
        target: root.bindsController
        ignoreUnknownSignals: true
        function onFocusIdChanged() { if (root.bindsController.focusId) root.showShortcuts() }
    }
    readonly property bool hyprlandSearchMatch: {
        const terms = settingsPage.normalize(search.text).trim().split(/\s+/).filter(Boolean)
        const haystack = settingsPage.normalize(hyprlandPage.searchTerms)
        return terms.length > 0 && terms.every(term => haystack.includes(term))
    }
    readonly property bool updatesSearchMatch: {
        const terms = settingsPage.normalize(search.text).trim().split(/\s+/).filter(Boolean)
        const haystack = settingsPage.normalize(updatesPage.searchTerms)
        return terms.length > 0 && terms.every(term => haystack.includes(term))
    }
    readonly property bool compactNavigation: width < 760 || Config.appearance.fontScale > 1.35
    // Con espacio, la navegación es una barra lateral y la página ocupa el resto.
    readonly property bool sideRail: width >= 860 && Config.appearance.fontScale <= 1.35
    readonly property real railWidth: 196
    readonly property real contentWidth: body.width - (sideRail ? railWidth + body.columnSpacing : 0)
    // Vista previa sin guardar: la barra inferior se llena desde Guardar.
    readonly property bool pendingPreview: (Config.dirty || settingsPage.hasDrafts || Config.saving)
        && !Config.error && !settingsPage.validationError
    readonly property int navigationRows: Math.ceil(root.titles.length / (root.compactNavigation ? 4 : root.titles.length))
    readonly property bool richComposition: height >= 680 && width >= 800 && Config.appearance.fontScale <= 1.35
    property string saveConfirmation: ""
    property bool savePending: false
    property string feedback: ""
    readonly property var sections: ["appearance", "modules", "appearance", "appearance", "paths", "companion", "", "activities"]
    // "#Etiqueta" abre un grupo dentro de la página (ver SettingsPage.entries).
    readonly property var pageFields: [
        ["#Barra", "appearance.workspaceStyle",
         "#Material", "appearance.liquidSurfaces", "appearance.glassAlpha", "appearance.materialDepth", "appearance.stateIntensity", "appearance.reduceTransparency",
         "#Tamaño y espacio", "appearance.uiScale", "appearance.spacingScale", "appearance.radiusScale", "appearance.topGap", "appearance.appGap"],
        ["appearance.barLayout"].concat(Object.keys(Config.schema.sections.modules).map(key => "modules." + key)),
        ["appearance.motionScale", "appearance.reduceMotion", "appearance.mediaTransitions", "modules.animateChanges",
         "#Gestos", "gestures.enabled", "gestures.pullTarget",
         "#Lanzamiento", "motion.appLaunchFlight"],
        ["#Tamaño", "appearance.fontScale",
         "#Familias", "appearance.fontFamily", "appearance.fontMonoFamily", "appearance.fontDisplayFamily", "appearance.fontMediaFamily",
         "#Idioma y región", "regional.language", "regional.region", "regional.timeZone",
         "#Formato", "appearance.time12h"],
        ["#Perfil", "profile.displayName", "paths.userAvatar",
         "#Archivos", "paths.paletteFile", "paths.wallpaperDir", "paths.wallpaperCacheDir", "paths.wallpaperApplyScript"],
        ["#Amalgam", "appearance.personality", "appearance.waterBody", "appearance.waterReactsToMusic", "appearance.bodyBreath", "appearance.bodyMessenger", "appearance.notificationDrop",
         "#Reacciones"].concat(Object.keys(Config.schema.sections.companion).map(key => "companion." + key)),
        [],
        ["#Rendimiento", "appearance.ambientFps", "appearance.clockSeconds",
         "#Actividades", "activities.enabled", "activities.longCommandSeconds", "activities.fromNotifications",
         "#Dispositivos", "devices.enabled", "devices.bluetooth", "devices.power", "devices.storage", "devices.privacyDots"]
    ]
    readonly property var symbols: ["palette", "dashboard", "animation", "text_fields", "person", "sentiment_satisfied", "keyboard", "settings"]
    readonly property var titles: [I18n.tr("Apariencia"), I18n.tr("Composición"), I18n.tr("Movimiento"), I18n.tr("Texto"), I18n.tr("Perfil y archivos"), I18n.tr("Amalgam"), I18n.tr("Atajos"), I18n.tr("Sistema")]
    onPageChanged: if (contentReady && visible && enabled) body.forceActiveFocus()
    EdotsPageMotion {
        id: pageMotion
        objectName: "settingsPageMotion"
        requestedPage: root.page
        requestedSearching: search.text.length > 0
        reduced: Config.appearance.reduceMotion
        active: root.visible && root.contentReady
    }
    function saveChanges() {
        body.forceActiveFocus()
        if (hyprlandActive) { hyprlandPage.saveChanges(); return }
        feedback = ""
        saveConfirmation = ""
        if (!settingsPage.commitDrafts()) { saveConfirmation = "error"; settingsPage.focusFirstError(); return }
        savePending = Config.dirty
        if (savePending) saveConfirmation = "busy"
        if (!Config.save()) { feedback = I18n.tr("No se pudo iniciar el guardado."); savePending = false; saveConfirmation = "error" }
    }
    Connections {
        target: Config
        function onDirtyChanged() { if (Config.dirty && !Config.saving) root.saveConfirmation = "" }
        function onSavingChanged() {
            if (root.savePending && !Config.saving) {
                root.saveConfirmation = Config.error ? "error" : "success"
                root.feedback = Config.error || I18n.tr("Cambios guardados")
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
    GridLayout {
        id: body
        anchors.fill: parent
        anchors.margins: root.width < 760 || root.height < 620 ? 16 : 28
        columns: 2
        columnSpacing: root.sideRail ? 28 : 12
        // Las filas llevan su propio margen superior para que la barra de guardado
        // pueda plegarse sin dejar un hueco fijo.
        rowSpacing: 0
        readonly property real rowGap: root.height < 620 ? 10 : 16
        RowLayout {
            id: brand
            Layout.row: 0; Layout.column: 0
            Layout.preferredWidth: root.sideRail ? root.railWidth : implicitWidth
            Layout.maximumWidth: root.sideRail ? root.railWidth : Number.POSITIVE_INFINITY
            spacing: 12
            TopUserStatus {
                objectName: "settingsUserAvatar"
                Layout.preferredWidth: 36; Layout.preferredHeight: 36
                avatarSource: Config.userAvatarUrl
                userName: Config.profile.displayName || Config.home.split("/").pop()
                Accessible.name: I18n.tr("Editar tu perfil")
                onClicked: root.showProfile()
            }
            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: "Crucible"; color: Theme.foreground; font.family: Config.appearance.fontDisplayFamily; font.pixelSize: 19 * Math.min(1.35, Config.appearance.fontScale); font.weight: Font.DemiBold }
        }
        RowLayout {
            Layout.row: 0; Layout.column: 1
            Layout.fillWidth: true; spacing: 10
            Item { Layout.fillWidth: true }
            EdotsTextField {
                id: search; objectName: "settingsSearch"; Layout.preferredWidth: Math.min(340, root.contentWidth * 0.55); implicitHeight: Math.max(44, Theme.fontSizeBodyLg + 24)
                Accessible.name: I18n.tr("Buscar en todos los ajustes")
                Accessible.description: I18n.tr("Ctrl+F para buscar. Escape borra la búsqueda.")
                placeholderText: root.width < 760 ? I18n.tr("Buscar ajustes") : I18n.tr("Buscar ajustes  ·  Ctrl+F"); color: Theme.foreground; placeholderTextColor: "transparent"
                font.family: Config.appearance.fontFamily; font.pixelSize: Math.max(12, Theme.fontSizeBody)
                selectByMouse: true; leftPadding: 40
                selectionColor: Theme.accent; selectedTextColor: Theme.primaryContent
                Keys.onEscapePressed: event => {
                    if (text.length > 0) { text = ""; body.forceActiveFocus() }
                    else event.accepted = false
                }
                cornerRadius: height / 2
                EdotsIcon {
                    anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    iconName: "search"; font.pixelSize: Theme.fontSizeTitle; Accessible.ignored: true
                    color: search.activeFocus ? Theme.accent : Qt.alpha(Theme.foreground, 0.6)
                    selected: search.activeFocus
                }
            }
            EdotsButton { text: ""; symbol: "close"; flat: true; implicitWidth: 44; Accessible.name: I18n.tr("Volver a Azog"); onClicked: root.requestClose() }
        }
        Item {
            id: navigationFrame
            Layout.row: 1; Layout.column: 0
            Layout.topMargin: body.rowGap
            Layout.columnSpan: root.sideRail ? 1 : 2
            // Sin barra de guardado no hay segunda fila: si el carril la abarcara,
            // el layout repartiría su altura y recortaría la página.
            Layout.rowSpan: root.sideRail && footer.visible ? 2 : 1
            Layout.fillWidth: !root.sideRail
            Layout.fillHeight: root.sideRail
            Layout.preferredWidth: root.sideRail ? root.railWidth : -1
            Layout.maximumWidth: root.sideRail ? root.railWidth : Number.POSITIVE_INFINITY
            implicitHeight: root.sideRail ? navigation.implicitHeight : root.compactNavigation ? root.navigationRows * 48 : 64
            readonly property real cellHeight: root.sideRail ? 46 : height / root.navigationRows
            Rectangle { visible: !root.sideRail; anchors.fill: parent; radius: 20; color: Qt.alpha(Theme.foreground, Theme.alphaGhost) }
            // La selección es una gota: el borde que va delante llega antes y el
            // de atrás lo sigue, de modo que se estira entre secciones.
            LiquidSelection {
                id: navigationLens
                opacity: root.searchShown ? 0 : 1
                Behavior on opacity { enabled: root.visible; NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                objectName: "settingsNavSelection"
                readonly property real cellWidth: navigationFrame.width / navigation.columns
                targetX: (root.page % navigation.columns) * cellWidth + (root.sideRail ? 0 : 4)
                targetY: Math.floor(root.page / navigation.columns) * navigationFrame.cellHeight + (root.sideRail ? 0 : 4)
                targetWidth: cellWidth - (root.sideRail ? 0 : 8)
                targetHeight: navigationFrame.cellHeight - (root.sideRail ? 0 : 8)
                immediate: !root.visible || !root.contentReady
                radius: root.sideRail ? 14 : 16
                color: Qt.alpha(Theme.accent, Theme.alphaSubtle)
                volume: true
                border.width: 1; border.color: Qt.alpha(Theme.accent, Theme.alphaEmphasis)
            }
            Grid {
                id: navigation
                width: parent.width
                height: root.sideRail ? implicitHeight : parent.height
                columns: root.sideRail ? 1 : root.compactNavigation ? 4 : root.titles.length
                Repeater {
                    model: root.titles
                    MotionButton {
                        id: nav
                        required property int index
                        required property string modelData
                        readonly property bool current: root.page === index && !root.searchShown
                        readonly property color ink: current ? Theme.foreground : Qt.alpha(Theme.foreground, 0.75)
                        objectName: "settingsNav" + index
                        width: navigationFrame.width / navigation.columns; height: navigationFrame.cellHeight
                        onClicked: { body.forceActiveFocus(); root.page = index; search.text = "" }
                        Keys.onUpPressed: if (root.sideRail && index > 0) { root.page = index - 1; navigation.children[index - 1].forceActiveFocus() }
                        Keys.onDownPressed: if (root.sideRail && index < root.titles.length - 1) { root.page = index + 1; navigation.children[index + 1].forceActiveFocus() }
                        background: Rectangle {
                            anchors.fill: parent; anchors.margins: root.sideRail ? 0 : 4; radius: root.sideRail ? 14 : 16
                            color: nav.hovered && !nav.current ? Qt.alpha(Theme.foreground, Theme.alphaFaint) : "transparent"
                            border.width: nav.activeFocus ? 2 : 0; border.color: Theme.accent
                            Behavior on color { ColorAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
                        }
                        contentItem: Item {
                            Row {
                                visible: root.sideRail
                                anchors.verticalCenter: parent.verticalCenter
                                x: 14; spacing: 12
                                EdotsIcon { Accessible.ignored: true; anchors.verticalCenter: parent.verticalCenter; iconName: root.symbols[nav.index]; font.pixelSize: 19; color: nav.current ? Theme.accent : nav.ink; interaction: nav.interaction; selected: nav.current; Behavior on color { ColorAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } } }
                                Text { anchors.verticalCenter: parent.verticalCenter; width: nav.width - 59; elide: Text.ElideRight; text: nav.modelData; color: nav.ink; font.family: Config.appearance.fontFamily; font.pixelSize: Math.max(13, Theme.fontSizeBodyLg); font.weight: nav.current ? Font.DemiBold : Font.Normal; Behavior on color { ColorAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } } }
                            }
                            Column {
                                visible: !root.sideRail
                                anchors.centerIn: parent
                                spacing: 5
                                EdotsIcon { visible: !root.compactNavigation; Accessible.ignored: true; anchors.horizontalCenter: parent.horizontalCenter; iconName: root.symbols[nav.index]; font.pixelSize: 19; color: nav.current ? Theme.accent : nav.ink; interaction: nav.interaction; selected: nav.current }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; width: nav.width - 16; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: nav.modelData; color: nav.ink; font.family: Config.appearance.fontFamily; font.pixelSize: Math.max(12, Theme.fontSizeBody); Behavior on color { ColorAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } } }
                            }
                        }
                        Accessible.name: modelData
                        Accessible.role: Accessible.PageTab
                        Accessible.selected: current
                    }
                }
            }
        }
        ColumnLayout {
            id: pageContent
            Layout.topMargin: body.rowGap
            Layout.row: root.sideRail ? 1 : 2
            Layout.column: root.sideRail ? 1 : 0
            Layout.columnSpan: root.sideRail ? 1 : 2
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: root.height < 620 ? 8 : 16
            opacity: pageMotion.exposure
            transform: Translate { y: pageMotion.travel }
        RowLayout {
            Layout.fillWidth: true; spacing: 14
            // Page changes already ride pageMotion; only the search count/title swap fades here.
            AnimatedLabel {
                Layout.fillWidth: true; elide: Text.ElideRight
                animated: root.searchShown
                value: root.searchShown ? (root.resultCount === 1 ? I18n.tr("1 resultado") : I18n.tr("%1 resultados").arg(root.resultCount)) : root.titles[pageMotion.displayedPage]
                color: Theme.foreground; font.family: Config.appearance.fontDisplayFamily
                font.pixelSize: 22 * Math.min(1.35, Config.appearance.fontScale); font.weight: Font.DemiBold
            }
        }
        EdotsButton {
            visible: root.searchShown && root.resultCount === 0
            text: I18n.tr("Limpiar búsqueda")
            onClicked: { search.text = ""; search.forceActiveFocus() }
        }
        EdotsButton {
            objectName: "hyprlandSearchResult"
            visible: root.hyprlandSearchMatch
            text: I18n.tr("Hyprland · Flujo y animaciones"); symbol: "view_carousel"
            onClicked: { root.showSystem("hyprland"); body.forceActiveFocus() }
        }
        EdotsButton {
            objectName: "shortcutsSearchResult"
            visible: root.shortcutsSearchMatch
            text: I18n.tr("Atajos · Combinaciones de teclado"); symbol: "keyboard"
            onClicked: { root.showShortcuts(); body.forceActiveFocus() }
        }
        EdotsButton {
            objectName: "updatesSearchResult"
            visible: root.updatesSearchMatch
            text: I18n.tr("Actualizaciones · Sistema, aplicaciones y Azog"); symbol: "system_update"
            onClicked: root.showUpdates()
        }
        IslaSegmented {
            objectName: "systemTabs"
            visible: !root.searchShown && pageMotion.displayedPage === root.systemPage
            inline: true
            options: ["general", "hyprland", "updates"]
            optionLabels: [I18n.tr("General"), I18n.tr("Hyprland"), I18n.tr("Actualizaciones")]
            current: root.systemTab
            Accessible.name: I18n.tr("Secciones de Sistema")
            onChosen: value => { root.systemTab = value; body.forceActiveFocus() }
        }
        ModuleComposer {
            Layout.fillWidth: true; visible: !root.searchShown && pageMotion.displayedPage === 1 && root.richComposition
            config: Config
            onEditFailed: message => root.feedback = message
            onEdited: root.feedback = ""
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 104; radius: 18; color: Qt.alpha(Theme.foreground, Theme.liquid ? 0.05 : 0.035)
            visible: !root.searchShown && pageMotion.displayedPage === 3 && root.height >= 680
            Column {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 22 } spacing: 7
                Text { text: I18n.tr("Un escritorio que habla tu idioma."); color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: 21 * Math.min(1.4, Config.appearance.fontScale); width: parent.width; elide: Text.ElideRight }
                Text { text: "Aa Bb Cc · 0123456789"; color: Qt.alpha(Theme.foreground, Theme.alphaIconSec); font.family: Config.appearance.fontMonoFamily; font.pixelSize: 13 }
            }
        }
        RowLayout {
            Layout.fillWidth: true; visible: !root.searchShown && pageMotion.displayedPage === 4 && root.height >= 620
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
                Text { text: Config.profile.displayName || I18n.tr("Tu espacio personal"); color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: 20; width: parent.width; elide: Text.ElideRight }
                Text { text: I18n.tr("Así te presenta Azog en la sesión."); color: Qt.alpha(Theme.foreground, Theme.alphaIconSec); font.family: Config.appearance.fontFamily; font.pixelSize: Math.max(12, Theme.fontSizeBody) }
            }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 24
        SettingsPage {
            id: settingsPage; visible: !root.hyprlandActive && !root.updatesActive && !root.shortcutsActive && (root.searchShown || pageMotion.displayedPage !== 1 || !root.richComposition)
            // Update the form atomically: empty keys otherwise briefly build a whole section.
            fieldSelection: {
                const page = pageMotion.displayedPage
                return { active: root.searchShown || (page !== root.shortcutsPage && (page !== root.systemPage || root.systemTab === "general") && (page !== 1 || !root.richComposition)),
                         section: root.sections[page], keys: root.pageFields[page], title: root.titles[page] }
            }
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 260
            popupBounds: root
            offerUnavailable: pageMotion.displayedPage === root.systemPage && root.systemTab === "general"
            showFishIntegration: pageMotion.displayedPage === root.systemPage && root.systemTab === "general" && !root.searchShown
            emptyAllowed: root.resultCount === 0
            config: Config; query: root.searchShown ? (search.text || root.heldQuery) : ""
            onEdited: root.feedback = ""
            onErrorFieldRequested: id => {
                const dot = id.indexOf(".")
                search.text = I18n.tr(Config.schema.sections[id.slice(0, dot)][id.slice(dot + 1)].label)
                // Results swap in at the page transition's midpoint; focus once they exist.
                if (root.searchShown) Qt.callLater(() => settingsPage.focusFirstError())
                else root.pendingErrorFocus = true
            }
        }
            UpdatesPage {
                id: updatesPage
                objectName: "updatesPage"
                visible: root.updatesActive
                Layout.fillWidth: true; Layout.fillHeight: true
                controller: root.updatesController
            }
            HyprlandPage {
                id: hyprlandPage
                objectName: "hyprlandPage"
                visible: root.hyprlandActive
                Layout.fillWidth: true; Layout.fillHeight: true
                controller: root.hyprlandController
                plugins: root.pluginsController
            }
            KeybindsPage {
                id: keybindsPage
                visible: root.shortcutsActive
                Layout.fillWidth: true; Layout.fillHeight: true
                binds: root.bindsController
            }
            ColumnLayout {
                visible: !root.searchShown && pageMotion.displayedPage === 2 && root.contentWidth >= 660 && root.height >= 660 && Config.appearance.fontScale <= 1.35
                Layout.preferredWidth: root.contentWidth < 820 ? 270 : 330
                Layout.maximumWidth: root.contentWidth < 820 ? 270 : 330
                Layout.fillHeight: true; spacing: 16
        IslandStudio { id: studio; Layout.fillWidth: true; Layout.preferredHeight: 260 }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Repeater {
                model: [{label: I18n.tr("Ágil"), scale: 0.7}, {label: I18n.tr("Natural"), scale: 1}, {label: I18n.tr("Pausado"), scale: 1.4}]
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
        Item {
            id: footer
            // Sólo aparece cuando hay algo que guardar, revisar o confirmar; en reposo
            // la página llega hasta abajo sin una barra de botones apagados.
            readonly property bool needed: Config.saving || Config.dirty || settingsPage.hasDrafts || Config.error.length > 0
                || settingsPage.validationError.length > 0 || root.hyprlandController.dirty || root.saveConfirmation !== ""
            property real reveal: needed ? 1 : 0
            Behavior on reveal { enabled: root.visible && root.contentReady && !Config.appearance.reduceMotion; NumberAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
            visible: !root.hyprlandActive && reveal > 0.001
            opacity: reveal
            clip: true
            Layout.row: root.sideRail ? 2 : 3
            Layout.column: root.sideRail ? 1 : 0
            Layout.columnSpan: root.sideRail ? 1 : 2
            Layout.fillWidth: true
            Layout.topMargin: body.rowGap * reveal
            Layout.preferredHeight: implicitHeight * reveal
            implicitHeight: footerGrid.implicitHeight + 20
            Timer {
                interval: 2200
                running: root.saveConfirmation === "success"
                onTriggered: { root.saveConfirmation = ""; root.feedback = "" }
            }
            readonly property bool inline: root.contentWidth >= 700
            Rectangle { anchors.fill: parent; radius: 20; color: Qt.alpha(Theme.foreground, Theme.liquid ? 0.05 : 0.035) }
            // Cambios pendientes: el líquido brota del botón Guardar y llena la
            // barra; al guardar o descartar se recoge en él.
            LiquidFill {
                id: footerFill
                objectName: "settingsSaveFill"
                active: root.pendingPreview
                originX: footerGrid.x + footerButtons.x + saveButton.x + (saveButton.width - saveButton.height) / 2
                originY: footerGrid.y + footerButtons.y + saveButton.y
                originSize: saveButton.height
                cornerRadius: 20
            }
            GridLayout {
                id: footerGrid
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 18; anchors.rightMargin: 10
                columns: footer.inline ? 2 : 1
                columnSpacing: 12; rowSpacing: 6
            Text {
                objectName: "settingsStatus"
                Layout.fillWidth: true
                text: Config.saving ? I18n.tr("Guardando…") : Config.error || (settingsPage.validationError ? I18n.tr("No se guardaron los cambios. Revisa los ajustes marcados.")
                    : (Config.dirty || settingsPage.hasDrafts) ? I18n.tr("Vista previa activa · Guarda para conservar los cambios")
                    : root.hyprlandController.dirty ? I18n.tr("Hyprland tiene una vista previa pendiente. Guárdala o reviértela en su sección.")
                    : root.feedback || I18n.tr("Todos los cambios están guardados"))
                color: Config.error || settingsPage.validationError ? Theme.error : footerFill.covered ? Theme.stateContent : Theme.foreground
                Behavior on color { ColorAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } }
                font.family: Config.appearance.fontFamily
                font.pixelSize: Math.max(12, Theme.fontSizeBody)
                font.weight: footerFill.covered ? Font.Medium : Font.Normal
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }
            RowLayout {
                id: footerButtons
                Layout.fillWidth: !footer.inline
                spacing: 8
                EdotsButton { visible: Config.error.length > 0; text: I18n.tr("Recargar"); onClicked: { settingsPage.clearValidation(); Config.reload() } }
                EdotsButton { visible: settingsPage.validationError.length > 0; text: I18n.tr("Revisar ajuste"); onClicked: settingsPage.focusFirstError() }
                EdotsButton { visible: root.hyprlandController.dirty; text: I18n.tr("Ver Hyprland"); onClicked: root.showSystem("hyprland") }
                Item { visible: !footer.inline; Layout.fillWidth: true }
                ConfirmationIndicator {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    status: root.saveConfirmation
                    Accessible.ignored: false
                    Accessible.role: Accessible.AlertMessage
                    Accessible.name: status === "success" ? I18n.tr("Cambios guardados") : status === "error" ? I18n.tr("No se guardaron los cambios") : I18n.tr("Guardando")
                }
                EdotsButton { text: I18n.tr("Descartar"); onFill: footerFill.covered; enabled: (Config.dirty || settingsPage.hasDrafts || settingsPage.validationError.length > 0) && !Config.saving; onClicked: { body.forceActiveFocus(); Config.discard(); settingsPage.clearValidation(); root.saveConfirmation = ""; root.feedback = I18n.tr("Cambios descartados") } }
                EdotsButton { id: saveButton; objectName: "settingsSave"; text: I18n.tr("Guardar"); symbol: "check"; accent: true; onFill: footerFill.covered; enabled: Config.loaded && !Config.saving && !Config.error && (Config.dirty || settingsPage.hasDrafts); onClicked: root.saveChanges() }
            }
            }
        }
    }
}
