import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"
import "../Singletons"
import "../components"
/**
 * Isla · LauncherSurface. Center "Spotlight" morfeano desde la pill (igual que
 * notifs/calendar): la pill se colapsa en círculo → morph a rect 620×460
 * top-centre de la pantalla con un TextInput + lista de apps (AppItem delegates).
 *
 * Navegación:
 *   ↑/Ctrl-K/Ctrl-P   anterior
 *   ↓/Ctrl-J/Ctrl-N   siguiente
 *   Enter/Return       lanza el seleccionado + cierra
 *   Esc                cierra sin tocar nada
 *
 * Búsqueda: Apps.search(text) (fzf or fuzzysort, en apps service). Vacío → todos
 * ordenados por favourites→frecuencia→name. La pill centra el resultado en
 * pantalla con el anchor top-centre que el host fija en shell.qml.
 *
 * El foco de teclado lo pide este surface al abrir (WlrKeyboardFocus.Exclusive
 * en shell.qml via el booleano `kbFocusWanted` extendido para surface=launcher).
 * TextInput forceActiveFocus empuja todos los keystrokes a la caja.
 */
Item {
    id: root
    // La cabecera multimedia vive en el mismo Pill.qml; el contenido del
    // launcher empieza debajo de ella, dentro del mismo vidrio.
    focus: open && !closing
    activeFocusOnTab: true

    property real s: 1
    property bool open: false
    property bool closing: false
    readonly property bool active: open && !closing
    property string query: ""
    readonly property int maxQueryLength: 256
    // El campo recorta a maxQueryLength; llegar al tope es «consulta demasiado larga».
    readonly property bool queryTooLong: query.length >= maxQueryLength
    property var searchResults: []
    property var calcResult: null
    property bool showCalculator: false
    property bool searching: false
    readonly property int resultsCount: searchResults ? searchResults.length : 0
    readonly property bool resultsVisible: !closing && query.trim().length > 0 && resultsCount > 0
    readonly property bool emptyResultsVisible: !closing && !searching && !showCalculator
        && query.trim().length > 0 && resultsCount === 0
    readonly property int maxVisibleResults: 6
    signal requestClose()
    signal launchRequested(var app)
    // Origen del icono de la fila elegida (coordenadas de esta vista), emitido justo
    // antes de launchRequested; el vuelo de la app nace ahí.
    signal launchOrigin(real x, real y, real size)
    signal copyResultRequested(string value)

    onOpenChanged: {
        if (open) {
            query = ""
            searchInput.text = ""
            listView.currentIndex = 0
            focusTimer.restart()
        } else {
            focusTimer.stop()
            retryFocusTimer.stop()
        }
    }
    onClosingChanged: {
        if (closing) {
            focusTimer.stop()
            retryFocusTimer.stop()
        } else if (open) {
            // The host can reopen the retained surface without changing open.
            query = ""
            searchInput.text = ""
            listView.currentIndex = 0
            focusTimer.restart()
        }
    }

    // ── logical layout ────────────────────────────────────────────────
    // top: search input (barra de vidrio accent + icono)
    // bottom: listado scrollable (con highlight de selección acento)
    Column {
        anchors.fill: parent
        spacing: Theme.spacingLg * root.s

        // ---- barra de búsqueda ----
        Rectangle {
            id: searchBox
            width: parent.width
            height: 44 * root.s
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.alpha(Theme.accent, Theme.alphaSoft) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.foreground, Theme.alphaGhost) }
            }
            border.color: searchInput.activeFocus ? Qt.alpha(Theme.accent, Theme.alphaIconSec) : Qt.alpha(Theme.foreground, Theme.alphaSoft)
            border.width: Theme.borderHairlineSoft
            Behavior on border.color { enabled: root.active && !Flags.reduceMotion; ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

            // ícono lupa (Material Symbols)
            MaterialIcon {
                anchors.left: parent.left
                anchors.leftMargin: 16 * root.s
                anchors.verticalCenter: parent.verticalCenter
                iconName: Icons.iSearch
                color: Theme.foreground
                font.pixelSize: Theme.fontSizeTitle * root.s
            }

            // Campo y placeholder comparten el lenguaje de escritura de Isla.
            IslaTextField {
                id: searchInput
                objectName: "launcherSearch"
                anchors.fill: parent
                anchors.leftMargin: 42 * root.s
                anchors.rightMargin: 38 * root.s
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                placeholderText: I18n.tr("Buscar aplicaciones…")
                motionActive: root.active && root.visible
                floating: false
                chrome: false
                Accessible.name: I18n.tr("Buscar aplicaciones")
                maximumLength: root.maxQueryLength
                onTextChanged: {
                    // Controles bidi (U+202A-202E, U+2066-2069) reordenan el campo: fuera.
                    const clean = text.replace(/[\u202A-\u202E\u2066-\u2069]/g, "")
                    if (clean !== text) {
                        const caret = cursorPosition - (text.length - clean.length)
                        text = clean
                        cursorPosition = Math.max(0, caret)
                        return
                    }
                    root.query = text
                    listView.currentIndex = 0
                }
                Keys.onUpPressed: function(event) { root.move(-1); event.accepted = true }
                Keys.onDownPressed: function(event) { root.move(1); event.accepted = true }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.launchCurrent()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        root.requestClose()
                        event.accepted = true
                    } else if (event.modifiers & Qt.ControlModifier) {
                        if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                            root.move(-1); event.accepted = true
                        } else if (event.key === Qt.Key_J || event.key === Qt.Key_N || event.key === Qt.Key_M) {
                            root.move(1); event.accepted = true
                        }
                    }
                }
                onActiveFocusChanged: if (!activeFocus && root.active) focusTimer.restart()
            }

            // Stable clear target with an independently animated icon.
            Item {
                anchors.right: parent.right
                anchors.rightMargin: 14 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 24 * root.s; height: 28 * root.s
                opacity: searchInput.length > 0 ? 1 : 0
                visible: opacity > 0
                enabled: searchInput.length > 0
                scale: Flags.reduceMotion ? 1 : 0.9 + 0.1 * opacity
                Behavior on opacity {
                    enabled: root.active && !Flags.reduceMotion
                    NumberAnimation { duration: Motion.hover; easing.type: Motion.easeStandard }
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: Icons.iClose
                    color: Theme.iconSecondary
                    font.pixelSize: Theme.fontSizeBodyLg * root.s
                    hovered: clearHit.containsMouse
                    scale: clearHit.motion.visualScale
                }
                MotionArea {
                    id: clearHit
                    anchors.fill: parent
                    accessibleName: I18n.tr("Limpiar búsqueda")
                    onClicked: { searchInput.text = ""; searchInput.forceActiveFocus() }
                }
            }

        }

        Text {
            objectName: "launcherEmptyResults"
            width: parent.width
            height: root.emptyResultsVisible ? 34 * root.s : 0
            visible: root.emptyResultsVisible || opacity > 0.01
            opacity: root.emptyResultsVisible ? 1 : 0
            Behavior on height {
                enabled: !Flags.reduceMotion
                NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve }
            }
            Behavior on opacity {
                enabled: !Flags.reduceMotion
                Anim { type: Anim.DefaultEffects }
            }
            text: root.queryTooLong ? I18n.tr("Consulta demasiado larga. Acórtala para buscar.")
                                    : I18n.tr("Sin resultados. Prueba con otro nombre.")
            color: Theme.iconSecondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSizeBodyLg * root.s
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }

        // ---- calculator result (when math expression is detected) ----
        Item {
            id: calcResultArea
            width: parent.width
            height: root.showCalculator ? (44 * root.s) : 0
            visible: root.showCalculator || opacity > 0
            opacity: root.showCalculator ? 1 : 0
            clip: true
            Behavior on height {
                enabled: !Flags.reduceMotion
                NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve }
            }
            Behavior on opacity {
                enabled: !Flags.reduceMotion
                Anim { type: Anim.DefaultEffects }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusLg * root.s
                color: Qt.alpha(Theme.accent, Theme.alphaHair)
                border.color: Qt.alpha(Theme.accent, Theme.alphaMid)
                border.width: Theme.borderHairline

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 16 * root.s
                    anchors.rightMargin: 16 * root.s
                    spacing: Theme.spacingXl * root.s

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "="
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeTitleLg * root.s
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.calcResult || ""
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSizeTitleLg * root.s
                        font.weight: Font.Medium
                    }
                }
            }
        }

        // Separación sutil entre el campo y la lista; pertenece al contenido,
        // mientras el fondo y el borde siguen siendo los de PillMaterial.
        Rectangle {
            id: resultsDivider
            width: parent.width
            height: root.resultsVisible ? 1 * root.s : 0
            color: Theme.sheen
            opacity: root.resultsVisible ? 1 : 0
            Behavior on height {
                enabled: !Flags.reduceMotion
                NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve }
            }
            Behavior on opacity { enabled: !Flags.reduceMotion; Anim { type: Anim.DefaultEffects } }
        }

        // ---- listado de resultados ----
        // Sólo se muestra si hay query: el pill arranca con sólo searchBox (estilo
        // caelestia) y la lista aparece/mide 0 hasta que el user escribe. La
        // animación (opacity + scale y) se maneja via Behavior abajo.
        ListView {
            id: listView
            width: parent.width
            // Espacio restante de la pill: hereda su movimiento (PillMorphMotion)
            // sin segunda animación; antes un Behavior propio lo hacía ir detrás
            // de la masa y empujaba el hint fuera del borde al crecer.
            height: Math.max(0,
                parent.height - searchBox.height - parent.spacing
                - (root.showCalculator ? calcResultArea.height + parent.spacing : 0)
                - resultsDivider.height - parent.spacing - hintRow.height - parent.spacing)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: Theme.spacingSm * root.s
            // visible solo con query → anims opacity/scale del contenido
            visible: root.resultsVisible || opacity > 0
            opacity: root.resultsVisible ? 1 : 0
            Behavior on opacity {
                enabled: !Flags.reduceMotion
                Anim { type: Anim.DefaultEffects }
            }
            model: ScriptModel {
                values: root.searchResults
                onValuesChanged: listView.currentIndex = 0
            }
            // resaltado de selección (highlight que siguen al currentIndex)
            // One selection surface owns the row highlight and glides between
            // rows; SmoothedAnimation retargets on held arrow keys without
            // restarting, so fast navigation never stutters or double-paints.
            highlight: Rectangle {
                readonly property Item target: listView.currentItem
                width: listView.width
                y: target ? target.y : 0
                height: target ? target.height : 0
                opacity: target && target.revealed ? 1 : 0
                color: Qt.alpha(Theme.accent, Theme.alphaGlow)
                border.color: Qt.alpha(Theme.accent, Theme.alphaHair)
                border.width: Theme.borderHairlineSoft
                radius: Theme.radiusLg * root.s
                Behavior on y {
                    enabled: !Flags.reduceMotion && root.active
                    SmoothedAnimation { velocity: -1; duration: Motion.fast }
                }
                Behavior on opacity { Anim { type: Anim.FastEffects } }
                // Accent edge travels with the selection instead of popping per row.
                Rectangle {
                    x: 4 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2 * root.s
                    height: parent.height - 18 * root.s
                    radius: width / 2
                    color: Theme.accent
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 4; height: parent.height + 6 * root.s
                        radius: width / 2
                        color: Qt.alpha(Theme.accent, Theme.alphaWash)
                    }
                }
            }
            highlightFollowsCurrentItem: false
            preferredHighlightBegin: 0
            preferredHighlightEnd: listView.height
            highlightRangeMode: ListView.ApplyRange

            delegate: AppItem {
                enabled: root.active && !root.searching
                width: ListView.view ? ListView.view.width : 0
                s: root.s
                revealDelay: Math.min(220, ListView.index * 28) * Motion.mult
                onLaunched: {
                    root.reportOrigin(index)
                    root.launchRequested(modelData)
                    root.requestClose()
                }
            }
        }

        // ---- hint de teclado (footer tenue estilo macOS Spotlight) ----
        Item {
            id: hintRow
            width: parent.width
            height: root.resultsVisible ? (keycapRow.height + 1) : 0
            visible: root.resultsVisible || opacity > 0
            opacity: root.resultsVisible ? 1 : 0
            clip: true
            Behavior on height {
                enabled: !Flags.reduceMotion
                NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve }
            }
            Behavior on opacity {
                enabled: !Flags.reduceMotion
                Anim { type: Anim.DefaultEffects }
            }

            // separador del listado (line 1px @sheen) — ritmo visual
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Theme.sheen
            }

            RowLayout {
                id: keycapRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Theme.spacingMd * root.s

                // arrow + Enter a la izquierda (acciones del resultado seleccionado)
                HintKbd {
                    glyph: "↑↓"
                    label: "navegar"
                    s: root.s
                }
                HintKbd {
                    glyph: "↵"
                    label: "abrir"
                    s: root.s
                }
                // spacer flexible que empuja el ESC a la derecha
                Item { Layout.fillWidth: true; height: 1 }

                // ESC a la derecha (acción global)
                HintKbd {
                    glyph: "esc"
                    label: "cerrar"
                    s: root.s
                }
            }
        }
    }

    Keys.onEscapePressed: root.requestClose()

    // Acepta escritura al cargar; el foco no espera al asentamiento del vidrio.
    Timer {
        id: focusTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (!root.active) return
            searchInput.forceActiveFocus()
            if (!searchInput.activeFocus) retryFocusTimer.restart()
        }
    }
    Timer {
        id: retryFocusTimer
        interval: 80
        repeat: false
        onTriggered: if (root.active && !searchInput.activeFocus) {
            searchInput.forceActiveFocus()
            if (!searchInput.activeFocus) retryFocusTimer.restart()
        }
    }

    function move(dir) {
        var n = listView.count
        if (n === 0) return
        var i = listView.currentIndex + dir
        if (i < 0) i = n - 1
        else if (i >= n) i = 0
        listView.currentIndex = i
    }

    function launchCurrent() {
        if (!root.active) return
        if (root.showCalculator && root.calcResult) {
            root.copyResultRequested(root.calcResult)
            root.requestClose()
            return
        }
        // Sin consulta no hay elección del usuario: Enter no lanza la primera app.
        if (root.query.trim().length === 0) return
        if (root.searching) return
        // Results can arrive before ListView creates the selected delegate.
        const app = root.searchResults[Math.max(0, listView.currentIndex)]
        if (!app) return
        root.reportOrigin(listView.currentIndex)
        root.launchRequested(app)
        root.requestClose()
    }

    // Centro y tamaño del icono de una fila (mismo cálculo que AppItem: margen de 14 y
    // 7 · s, icono al 85 % del alto interior). Sólo informa; no cambia el lanzamiento.
    function reportOrigin(index) {
        const row = listView.itemAtIndex(Math.max(0, index))
        if (!row) return
        const size = (row.height - 14 * root.s) * 0.85
        const p = row.mapToItem(root, 14 * root.s + size / 2, row.height / 2)
        root.launchOrigin(p.x, p.y, size)
    }
}
