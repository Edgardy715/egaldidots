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
PillSurface {
    id: root
    // La cabecera multimedia vive en el mismo Pill.qml; el contenido del
    // launcher empieza debajo de ella, dentro del mismo vidrio.
    mTop: Theme.marginMd + 94
    mLeft: Theme.marginMd; mRight: Theme.marginMd; mBottom: 20
    focus: open && !closing
    activeFocusOnTab: true

    property string query: ""
    // resultados cacheados (no se recalculan en cada keystroke — debounce 80ms).
    // Aliminar el "Object or context destroyed during incubation" y el tear
    // al escribir rápido. AppItem ya cargó su modelData al synth el delegate.
    //
    // Patrón caelestia: si la query está vacía, NO mostrar resultados — sólo la
    // searchBox. La lista (y el hint) están ocultos y la pill mide
    // search-height only. Cuando el user escribe, los resultados aparecen con
    // anim (opacity/scale) desde searchBox-expanded hacia abajo.
    property var searchResults: []
    readonly property int resultsCount: searchResults ? searchResults.length : 0
    readonly property bool resultsVisible: !closing && query.trim().length > 0 && resultsCount > 0
    readonly property int maxVisibleResults: 6
    property string lastQuery: "\u0000"   // fuerza refresh inicial

    // Calculator state
    property var calcResult: null
    property bool showCalculator: false

    // Evaluates a math expression safely
    function evaluateMath(expr) {
        try {
            // Replace common math functions/operators
            var jsExpr = expr
                .replace(/π|pi/gi, "Math.PI")
                .replace(/e\b/gi, "Math.E")
                .replace(/sqrt\(/gi, "Math.sqrt(")
                .replace(/sin\(/gi, "Math.sin(")
                .replace(/cos\(/gi, "Math.cos(")
                .replace(/tan\(/gi, "Math.tan(")
                .replace(/asin\(/gi, "Math.asin(")
                .replace(/acos\(/gi, "Math.acos(")
                .replace(/atan\(/gi, "Math.atan(")
                .replace(/log\(/gi, "Math.log(")
                .replace(/ln\(/gi, "Math.log(")
                .replace(/exp\(/gi, "Math.exp(")
                .replace(/abs\(/gi, "Math.abs(")
                .replace(/floor\(/gi, "Math.floor(")
                .replace(/ceil\(/gi, "Math.ceil(")
                .replace(/round\(/gi, "Math.round(")
                .replace(/\^/g, "**")
                .replace(/×/g, "*")
                .replace(/÷/g, "/");

            // Basic validation - only allow safe characters
            if (!/^[0-9+\-*/().,\s\w%]+$/.test(jsExpr)) {
                return null;
            }

            // Evaluate
            var result = eval(jsExpr);
            if (isFinite(result) && !isNaN(result)) {
                // Format nicely
                if (Number.isInteger(result)) {
                    return String(result);
                } else {
                    return Number(result.toFixed(10)).toString(); // Remove trailing zeros
                }
            }
        } catch (e) {
            // Ignore errors
        }
        return null;
    }

    onQueryChanged: {
        searchDebounce.restart()
        
        // Check for calculator mode
        var trimmed = query.trim()
        if (trimmed.length > 0) {
            var result = evaluateMath(trimmed)
            calcResult = result
            showCalculator = result !== null
        } else {
            calcResult = null
            showCalculator = false
        }
    }

    onOpenChanged: {
        if (open) {
            query = ""
            searchInput.text = ""
            searchResults = []   // vacío inicial: sólo searchBox visible
            lastQuery = ""
            listView.currentIndex = 0
            // focus robado en el next tick (espera el morph + Exclusive grab)
            focusTimer.restart()
        } else {
            // cancelar debounce pendiente: si el user hita Enter mientras
            // todavía no se disparó (80ms), el PesadoTriggered post-hook
            // reescribe searchResults sobre un surface muerto → mientras no
            // causa nada ahora, es sano cancelar y evitar churn del model.
            searchDebounce.stop()
            focusTimer.stop()
            retryFocusTimer.stop()
        }
    }

    onClosingChanged: if (closing) {
        searchDebounce.stop()
        focusTimer.stop()
        retryFocusTimer.stop()
    }

    // debounce: la búsqueda (fzf sobre todos los .desktop) es costosa en el 1er
    // keystroke de un string nuevo; si el user pega (colar) texto rápido, molesta
    // el evento de layout. Esperar 80ms sin tecla para actually filtrar.
    Timer {
        id: searchDebounce
        interval: 80; repeat: false
        onTriggered: {
            if (root.lastQuery === root.query) return
            root.lastQuery = root.query
            root.searchResults = Apps.search(root.query)
            listView.currentIndex = 0
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
            Behavior on border.color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

            // ícono lupa (Material Symbols)
            MaterialIcon {
                anchors.left: parent.left
                anchors.leftMargin: 16 * root.s
                anchors.verticalCenter: parent.verticalCenter
                iconName: Icons.iSearch
                color: Theme.foreground
                font.pixelSize: Theme.fontSizeTitle * root.s
            }

            // placeholder text (cuando input vacío)
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 42 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: "Buscar aplicaciones…"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                visible: searchInput.text.length === 0 && !searchInput.activeFocus
            }

            // input text con animaciones de escritura (cursor + placeholder)
            IslaTextField {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 42 * root.s
                anchors.rightMargin: 38 * root.s
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                floating: false
                chrome: false
                onTextChanged: {
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
                onActiveFocusChanged: if (!activeFocus && root.open) focusTimer.restart()
            }

            // clear ✖ a la derecha
            MaterialIcon {
                anchors.right: parent.right
                anchors.rightMargin: 14 * root.s
                anchors.verticalCenter: parent.verticalCenter
                iconName: Icons.iClose
                color: Theme.dim
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                visible: searchInput.text.length > 0
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { searchInput.text = ""; searchInput.forceActiveFocus() }
                }
            }
        }

        // ---- calculator result (when math expression is detected) ----
        Item {
            id: calcResultArea
            width: parent.width
            height: root.showCalculator ? (44 * root.s) : 0
            visible: root.showCalculator
            opacity: root.showCalculator ? 1 : 0
            clip: true
            Behavior on height {
                NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve }
            }
            Behavior on opacity {
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
                NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve }
            }
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        }

        // ---- listado de resultados ----
        // Sólo se muestra si hay query: el pill arranca con sólo searchBox (estilo
        // caelestia) y la lista aparece/mide 0 hasta que el user escribe. La
        // animación (opacity + scale y) se maneja via Behavior abajo.
        ListView {
            id: listView
            width: parent.width
            height: root.resultsVisible ? Math.max(0,
                parent.height - searchBox.height - parent.spacing
                - (root.showCalculator ? calcResultArea.height + parent.spacing : 0)
                - resultsDivider.height - parent.spacing - hintRow.height - parent.spacing)
                : 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: Theme.spacingSm * root.s
            // visible solo con query → anims opacity/scale del contenido
            visible: root.resultsVisible
            opacity: root.resultsVisible ? 1 : 0
            Behavior on opacity {
                Anim { type: Anim.DefaultEffects }
            }
            Behavior on height {
                NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve }
            }
            // ScriptModel evita el churn de destruir/recrear todos los delegates
            // cada keystroke (warning "Object or context destroyed during
            // incubation" + robo de foco). Usa diff de values en vez de reemplazo
            // bruto. values evalúa Apps.search(searchInput.text) lazy.
            model: ScriptModel {
                values: root.searchResults
                onValuesChanged: listView.currentIndex = 0
            }
            // resaltado de selección (highlight que siguen al currentIndex)
            highlight: Rectangle {
                color: Qt.alpha(Theme.accent, Theme.alphaWash)
                border.color: Qt.alpha(Theme.accent, Theme.alphaHair)
                border.width: Theme.borderHairlineSoft
                radius: Theme.radiusLg * root.s
                Behavior on y { Anim { type: Anim.FastEffects } }
            }
            highlightMoveDuration: Motion.fast
            highlightResizeDuration: 0
            preferredHighlightBegin: 0
            preferredHighlightEnd: listView.height
            highlightRangeMode: ListView.ApplyRange

            delegate: AppItem {
                width: ListView.view ? ListView.view.width : 0
                s: root.s
                revealDelay: Math.min(220, ListView.index * 28) * Motion.mult
                onLaunched: {
                    Apps.launch(modelData)
                    root.requestClose()
                }
            }
        }

        // ---- hint de teclado (footer tenue estilo macOS Spotlight) ----
        Item {
            id: hintRow
            width: parent.width
            height: root.resultsVisible ? (keycapRow.height + 1) : 0
            visible: root.resultsVisible
            opacity: root.resultsVisible ? 1 : 0
            clip: true
            Behavior on height {
                NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve }
            }
            Behavior on opacity {
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

    // Espera el morph y vuelve a intentarlo mientras la capa adquiere el foco.
    Timer {
        id: focusTimer
        interval: Motion.morph + 60
        repeat: false
        onTriggered: {
            if (!root.open) return
            searchInput.forceActiveFocus()
            if (!searchInput.activeFocus) retryFocusTimer.restart()
        }
    }
    Timer {
        id: retryFocusTimer
        interval: 80
        repeat: false
        onTriggered: if (root.open && !searchInput.activeFocus) {
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
        if (root.showCalculator && root.calcResult) {
            // Copy calculator result to clipboard
            Quickshell.execDetached(["wl-copy", root.calcResult])
            root.requestClose()
            return
        }
        if (listView.count === 0) return
        var item = listView.currentItem
        if (item && item.modelData) {
            Apps.launch(item.modelData)
        }
        root.requestClose()
    }
}
