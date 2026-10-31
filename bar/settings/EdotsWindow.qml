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
    readonly property int resultCount: settingsPage.entries.length + (hyprlandSearchMatch ? 1 : 0) + (updatesSearchMatch ? 1 : 0)
    readonly property string validationError: settingsPage.validationError
    property bool showPreview: false
    property int page: 0
    property var hyprlandController: HyprlandSettings
    property var updatesController: SystemUpdates
    readonly property bool updatesActive: !searchShown && pageMotion.displayedPage === 8
    function showUpdates() { root.page = 8; search.text = ""; SystemUpdates.portalRequested = false }
    Connections { target: SystemUpdates; function onOpenRequested() { root.showUpdates() } }
    Component.onCompleted: { if (SystemUpdates.portalRequested) root.showUpdates() }
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
    readonly property bool hyprlandActive: !searchShown && pageMotion.displayedPage === 6
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
    readonly property var sections: ["appearance", "modules", "appearance", "appearance", "profile", "paths", "appearance", "companion", "updates"]
    readonly property var pageFields: [
        ["appearance.workspaceStyle", "appearance.liquidSurfaces", "appearance.stateIntensity", "appearance.glassAlpha", "appearance.reduceTransparency", "appearance.materialDepth", "appearance.menuSelectionAnchor", "appearance.uiScale", "appearance.topGap", "appearance.appGap", "appearance.spacingScale", "appearance.radiusScale", "appearance.time12h"],
        ["appearance.barLayout"].concat(Object.keys(Config.schema.sections.modules).map(key => "modules." + key)),
        ["appearance.motionScale", "appearance.reduceMotion", "appearance.mediaTransitions", "modules.animateChanges"],
        ["appearance.fontFamily", "appearance.fontMonoFamily", "appearance.fontDisplayFamily", "appearance.fontMediaFamily", "appearance.fontScale"],
        ["profile.displayName", "paths.userAvatar"],
        ["paths.paletteFile", "paths.wallpaperDir", "paths.wallpaperCacheDir", "paths.wallpaperApplyScript", "appearance.pillBlur", "appearance.clockSeconds", "appearance.showGlyphs"],
        [],
        ["appearance.personality", "appearance.bodyBreath", "appearance.bodyMessenger"].concat(Object.keys(Config.schema.sections.companion).map(key => "companion." + key)),
        Object.keys(Config.schema.sections.updates).map(key => "updates." + key)
    ]
    readonly property var symbols: ["palette", "dashboard", "animation", "text_fields", "person", "settings", "view_carousel", "sentiment_satisfied", "system_update"]
    readonly property var titles: [qsTr("Apariencia"), qsTr("Composición"), qsTr("Movimiento"), qsTr("Tipografía"), qsTr("Tu perfil"), qsTr("Avanzado"), qsTr("Hyprland"), qsTr("Cuerpo"), qsTr("Actualizaciones")]
    readonly property var subtitles: [qsTr("Dale a Isla tu forma de sentir el escritorio."), qsTr("Elige qué te acompaña. La Isla permanece en el centro."), qsTr("Ajusta el ritmo. Prueba la respuesta antes de guardar."), qsTr("Una lectura cómoda, con tu propia personalidad."), qsTr("Los pequeños detalles que hacen tuyo este espacio."), qsTr("Archivos y carpetas que utiliza tu shell."), qsTr("Elige cómo se organizan y se mueven tus ventanas."), qsTr("Ajusta la luz, las reacciones y la gota de archivos del cuerpo de vidrio líquido."), qsTr("El sistema, tus aplicaciones e Isla en un solo lugar.")]
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
        if (!Config.save()) { feedback = qsTr("No se pudo iniciar el guardado."); savePending = false; saveConfirmation = "error" }
    }
    Connections {
        target: Config
        function onDirtyChanged() { if (Config.dirty && !Config.saving) root.saveConfirmation = "" }
        function onSavingChanged() {
            if (root.savePending && !Config.saving) {
                root.saveConfirmation = Config.error ? "error" : "success"
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
    GridLayout {
        id: body
        anchors.fill: parent
        anchors.margins: root.width < 760 || root.height < 620 ? 16 : 28
        columns: 2
        columnSpacing: root.sideRail ? 28 : 12
        rowSpacing: root.height < 620 ? 10 : 16
        RowLayout {
            id: brand
            Layout.row: 0; Layout.column: 0
            Layout.preferredWidth: root.sideRail ? root.railWidth : implicitWidth
            Layout.maximumWidth: root.sideRail ? root.railWidth : Number.POSITIVE_INFINITY
            spacing: 12
            TopUserStatus {
                objectName: "settingsUserAvatar"
                Layout.preferredWidth: 44; Layout.preferredHeight: 44
                avatarSource: Config.userAvatarUrl
                userName: Config.profile.displayName || Config.home.split("/").pop()
                Accessible.name: qsTr("Editar tu perfil")
                onClicked: root.showProfile()
            }
            Column {
                Layout.fillWidth: true
                spacing: 1
                Text { text: "Edots"; color: Theme.foreground; font.family: Config.appearance.fontDisplayFamily; font.pixelSize: 22 * Math.min(1.35, Config.appearance.fontScale); font.weight: Font.DemiBold }
                Text { visible: root.width >= 760; width: parent.width; elide: Text.ElideRight; text: qsTr("Tu Isla, a tu manera"); color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontFamily; font.pixelSize: Math.max(12, Theme.fontSizeBody) }
            }
        }
        RowLayout {
            Layout.row: 0; Layout.column: 1
            Layout.fillWidth: true; spacing: 10
            Item { Layout.fillWidth: true }
            EdotsTextField {
                id: search; objectName: "settingsSearch"; Layout.preferredWidth: Math.min(340, root.contentWidth * 0.55); implicitHeight: Math.max(44, Theme.fontSizeBodyLg + 24)
                Accessible.name: qsTr("Buscar en todos los ajustes")
                Accessible.description: qsTr("Ctrl+F para buscar. Escape borra la búsqueda.")
                placeholderText: root.width < 760 ? qsTr("Buscar ajustes") : qsTr("Buscar ajustes  ·  Ctrl+F"); color: Theme.foreground; placeholderTextColor: "transparent"
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
            EdotsButton { text: ""; symbol: "close"; implicitWidth: 44; Accessible.name: qsTr("Volver a Isla"); onClicked: root.requestClose() }
        }
        Item {
            id: navigationFrame
            Layout.row: 1; Layout.column: 0
            Layout.columnSpan: root.sideRail ? 1 : 2
            Layout.rowSpan: root.sideRail ? 2 : 1
            Layout.fillWidth: !root.sideRail
            Layout.fillHeight: root.sideRail
            Layout.preferredWidth: root.sideRail ? root.railWidth : -1
            Layout.maximumWidth: root.sideRail ? root.railWidth : Number.POSITIVE_INFINITY
            implicitHeight: root.sideRail ? navigation.implicitHeight : root.compactNavigation ? root.navigationRows * 48 : 64
            readonly property real cellHeight: root.sideRail ? 46 : height / root.navigationRows
            Rectangle { visible: !root.sideRail; anchors.fill: parent; radius: 20; color: Qt.alpha(Theme.foreground, 0.035) }
            // La selección es una gota: el borde que va delante llega antes y el
            // de atrás lo sigue, de modo que se estira entre secciones.
            LiquidSelection {
                id: navigationLens
                objectName: "settingsNavSelection"
                readonly property real cellWidth: navigationFrame.width / navigation.columns
                targetX: (root.page % navigation.columns) * cellWidth + (root.sideRail ? 0 : 4)
                targetY: Math.floor(root.page / navigation.columns) * navigationFrame.cellHeight + (root.sideRail ? 0 : 4)
                targetWidth: cellWidth - (root.sideRail ? 0 : 8)
                targetHeight: navigationFrame.cellHeight - (root.sideRail ? 0 : 8)
                immediate: !root.visible || !root.contentReady
                radius: root.sideRail ? 14 : 16
                color: Theme.liquid ? Theme.stateFill : Qt.alpha(Theme.accent, 0.17)
                volume: true
                border.width: Theme.liquid ? 0 : 1; border.color: Qt.alpha(Theme.accent, 0.24)
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
                        readonly property bool current: root.page === index
                        readonly property color ink: current && Theme.liquid ? Theme.stateContent : current ? Theme.foreground : Qt.alpha(Theme.foreground, 0.75)
                        objectName: "settingsNav" + index
                        width: navigationFrame.width / navigation.columns; height: navigationFrame.cellHeight
                        onClicked: { body.forceActiveFocus(); root.page = index; search.text = "" }
                        Keys.onUpPressed: if (root.sideRail && index > 0) { root.page = index - 1; navigation.children[index - 1].forceActiveFocus() }
                        Keys.onDownPressed: if (root.sideRail && index < root.titles.length - 1) { root.page = index + 1; navigation.children[index + 1].forceActiveFocus() }
                        background: Rectangle {
                            anchors.fill: parent; anchors.margins: root.sideRail ? 0 : 4; radius: root.sideRail ? 14 : 16
                            color: nav.hovered && !nav.current ? Qt.alpha(Theme.foreground, 0.06) : "transparent"
                            border.width: nav.activeFocus ? 2 : 0; border.color: nav.current && Theme.liquid ? Theme.stateContent : Theme.accent
                            Behavior on color { ColorAnimation { duration: Motion.hover; easing.type: Motion.easeStandard } }
                        }
                        contentItem: Item {
                            Row {
                                visible: root.sideRail
                                anchors.verticalCenter: parent.verticalCenter
                                x: 14; spacing: 12
                                EdotsIcon { Accessible.ignored: true; anchors.verticalCenter: parent.verticalCenter; iconName: root.symbols[nav.index]; font.pixelSize: 19; color: nav.current && !Theme.liquid ? Theme.accent : nav.ink; interaction: nav.interaction; selected: nav.current; Behavior on color { ColorAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } } }
                                Text { anchors.verticalCenter: parent.verticalCenter; width: nav.width - 59; elide: Text.ElideRight; text: nav.modelData; color: nav.ink; font.family: Config.appearance.fontFamily; font.pixelSize: Math.max(13, Theme.fontSizeBodyLg); font.weight: nav.current ? Font.DemiBold : Font.Normal; Behavior on color { ColorAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } } }
                            }
                            Column {
                                visible: !root.sideRail
                                anchors.centerIn: parent
                                spacing: 5
                                EdotsIcon { visible: !root.compactNavigation; Accessible.ignored: true; anchors.horizontalCenter: parent.horizontalCenter; iconName: root.symbols[nav.index]; font.pixelSize: 19; color: nav.current && !Theme.liquid ? Theme.accent : nav.ink; interaction: nav.interaction; selected: nav.current }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; width: nav.width - 16; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: nav.modelData; color: nav.ink; font.family: Config.appearance.fontFamily; font.pixelSize: Math.max(12, Theme.fontSizeBody); Behavior on color { ColorAnimation { duration: Motion.standardSmall; easing.type: Motion.easeStandard } } }
                            }
                        }
                        Accessible.name: modelData
                        Accessible.role: Accessible.PageTab
                        Accessible.selected: current
                    }
                }
            }
            Image {
                visible: root.sideRail && navigationFrame.height >= navigation.height + 64
                Accessible.ignored: true
                anchors.left: parent.left; anchors.leftMargin: 10; anchors.bottom: parent.bottom
                source: "assets/edots.png"; sourceSize: Qt.size(96, 96)
                width: 40; height: 40
                opacity: brandHover.hovered ? 1 : 0.7
                scale: Config.appearance.reduceMotion ? 1 : brandHover.hovered ? 1.12 : 1
                rotation: Config.appearance.reduceMotion ? 0 : brandHover.hovered ? -8 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.hover } }
                Behavior on scale { enabled: root.visible && root.contentReady && !Config.appearance.reduceMotion; SpringAnimation { spring: Motion.controlSpring; damping: Motion.controlDamping } }
                Behavior on rotation { enabled: root.visible && root.contentReady && !Config.appearance.reduceMotion; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                HoverHandler { id: brandHover }
            }
        }
        ColumnLayout {
            id: pageContent
            Layout.row: root.sideRail ? 1 : 2
            Layout.column: root.sideRail ? 1 : 0
            Layout.columnSpan: root.sideRail ? 1 : 2
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: root.height < 620 ? 8 : 16
            opacity: pageMotion.exposure
            transform: Translate { y: pageMotion.travel }
        RowLayout {
            Layout.fillWidth: true; spacing: 14
            // Icono de la página sobre una gota de estado, como en Ajustes rápidos.
            Rectangle {
                visible: root.height >= 620
                Layout.preferredWidth: 44; Layout.preferredHeight: 44; Layout.alignment: Qt.AlignTop
                radius: 14
                color: Theme.liquid ? Theme.stateFill : Qt.alpha(Theme.accent, 0.17)
                gradient: Theme.liquid ? badgeVolume : null
                property Gradient badgeVolume: Gradient {
                    GradientStop { position: 0; color: Theme.stateFillLight }
                    GradientStop { position: 1; color: Theme.stateFill }
                }
                EdotsIcon {
                    anchors.centerIn: parent; Accessible.ignored: true
                    iconName: root.searchShown ? "search" : root.symbols[pageMotion.displayedPage]
                    font.pixelSize: 22; selected: true
                    color: Theme.liquid ? Theme.stateContent : Theme.accent
                }
            }
            Column {
                Layout.fillWidth: true; spacing: 3
                Text { width: parent.width; elide: Text.ElideRight; text: root.searchShown ? qsTr("Resultados de búsqueda") : root.titles[pageMotion.displayedPage]; color: Theme.foreground; font.family: Config.appearance.fontDisplayFamily; font.pixelSize: 26 * Math.min(1.35, Config.appearance.fontScale); font.weight: Font.DemiBold }
                Text { visible: root.height >= 620; width: parent.width; text: root.searchShown ? qsTr("%1 resultados en toda la configuración.").arg(root.resultCount) : root.subtitles[pageMotion.displayedPage]; color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontFamily; font.pixelSize: Math.max(13, Theme.fontSizeBodyLg); wrapMode: Text.WordWrap }
            }
        }
        EdotsButton {
            visible: root.searchShown && root.resultCount === 0
            text: qsTr("Limpiar búsqueda")
            onClicked: { search.text = ""; search.forceActiveFocus() }
        }
        EdotsButton {
            objectName: "hyprlandSearchResult"
            visible: root.hyprlandSearchMatch
            text: qsTr("Hyprland · Flujo y animaciones"); symbol: "view_carousel"
            onClicked: { root.page = 6; search.text = ""; body.forceActiveFocus() }
        }
        EdotsButton {
            objectName: "updatesSearchResult"
            visible: root.updatesSearchMatch
            text: qsTr("Actualizaciones · Sistema, aplicaciones e Isla"); symbol: "system_update"
            onClicked: root.showUpdates()
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
                Text { text: qsTr("Un escritorio que habla tu idioma."); color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: 21 * Math.min(1.4, Config.appearance.fontScale); width: parent.width; elide: Text.ElideRight }
                Text { text: "Aa Bb Cc · 0123456789"; color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontMonoFamily; font.pixelSize: 13 }
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
                Text { text: Config.profile.displayName || qsTr("Tu espacio personal"); color: Theme.foreground; font.family: Config.appearance.fontFamily; font.pixelSize: 20; width: parent.width; elide: Text.ElideRight }
                Text { text: qsTr("Así te presenta Isla en la sesión."); color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontFamily; font.pixelSize: Math.max(12, Theme.fontSizeBody) }
            }
        }
        RowLayout {
            Layout.fillWidth: true; visible: !root.searchShown && pageMotion.displayedPage === 5
            Text { text: qsTr("Opciones limitadas o sin efecto"); color: Qt.alpha(Theme.foreground, 0.72); font.family: Config.appearance.fontFamily; font.pixelSize: Math.max(12, Theme.fontSizeBody); Layout.fillWidth: true }
            EdotsButton { text: settingsPage.showUnavailable ? qsTr("Ocultar") : qsTr("Mostrar"); onClicked: settingsPage.showUnavailable = !settingsPage.showUnavailable }
        }
        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 24
        SettingsPage {
            id: settingsPage; visible: !root.hyprlandActive && !root.updatesActive && (root.searchShown || pageMotion.displayedPage !== 1 || !root.richComposition)
            // Update the form atomically: empty keys otherwise briefly build a whole section.
            fieldSelection: {
                const page = pageMotion.displayedPage
                return { active: root.searchShown || (page !== 6 && page !== 8 && (page !== 1 || !root.richComposition)),
                         section: root.sections[page], keys: root.pageFields[page] }
            }
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 260
            popupBounds: root
            config: Config; query: root.searchShown ? (search.text || root.heldQuery) : ""
            onEdited: root.feedback = ""
            onErrorFieldRequested: id => {
                const dot = id.indexOf(".")
                search.text = Config.schema.sections[id.slice(0, dot)][id.slice(dot + 1)].label
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
        Item {
            id: footer
            visible: !root.hyprlandActive
            Layout.row: root.sideRail ? 2 : 3
            Layout.column: root.sideRail ? 1 : 0
            Layout.columnSpan: root.sideRail ? 1 : 2
            Layout.fillWidth: true
            implicitHeight: footerGrid.implicitHeight + 20
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
                text: Config.saving ? qsTr("Guardando…") : Config.error || (settingsPage.validationError ? qsTr("No se guardaron los cambios. Revisa los ajustes marcados.")
                    : (Config.dirty || settingsPage.hasDrafts) ? qsTr("Vista previa activa · Guarda para conservar los cambios")
                    : root.hyprlandController.dirty ? qsTr("Hyprland tiene una vista previa pendiente. Guárdala o reviértela en su sección.")
                    : root.feedback || qsTr("Todos los cambios están guardados"))
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
                EdotsButton { visible: Config.error.length > 0; text: qsTr("Recargar"); onClicked: { settingsPage.clearValidation(); Config.reload() } }
                EdotsButton { visible: settingsPage.validationError.length > 0; text: qsTr("Revisar ajuste"); onClicked: settingsPage.focusFirstError() }
                EdotsButton { visible: root.hyprlandController.dirty; text: qsTr("Ver Hyprland"); onClicked: { root.page = 6; search.text = "" } }
                Item { visible: !footer.inline; Layout.fillWidth: true }
                ConfirmationIndicator {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    status: root.saveConfirmation
                    Accessible.ignored: false
                    Accessible.role: Accessible.AlertMessage
                    Accessible.name: status === "success" ? qsTr("Cambios guardados") : status === "error" ? qsTr("No se guardaron los cambios") : qsTr("Guardando")
                }
                EdotsButton { text: qsTr("Descartar"); onFill: footerFill.covered; enabled: (Config.dirty || settingsPage.hasDrafts || settingsPage.validationError.length > 0) && !Config.saving; onClicked: { body.forceActiveFocus(); Config.discard(); settingsPage.clearValidation(); root.saveConfirmation = ""; root.feedback = qsTr("Cambios descartados") } }
                EdotsButton { id: saveButton; objectName: "settingsSave"; text: qsTr("Guardar"); symbol: "check"; accent: true; onFill: footerFill.covered; enabled: Config.loaded && !Config.saving && !Config.error && (Config.dirty || settingsPage.hasDrafts); onClicked: root.saveChanges() }
            }
            }
        }
    }
}
