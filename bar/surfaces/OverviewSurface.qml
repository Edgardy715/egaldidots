import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"
import "../Singletons"
import "../components"

/**
 * Isla · OverviewSurface. El overview morpha la PROPIA pill — no es una ventana
 * aparte: hereda PillSurface y vive dentro del cuerpo de vidrio de la pill (que
 * crece a surfaceSize["overview"] anclado top-centre, como el calendar). El body
 * de la pill YA es el glass (cardTop→cardBot + sheen + sombra), así que aquí sólo
 * va el contenido: header (tabs + reloj) + grilla de tiles con previews VIVOS.
 *
 * Comportamiento (nivel quickshell-overview / illogical-impulse):
 *   · Grilla 3×2 de workspaces con previews en vivo (ScreencopyView).
 *   · Navegación por teclado (shell.qml la enruta mientras el overlay tiene
 *     keyboardFocus Exclusive):
 *       Tab/→/↓/l/j = siguiente ws · Shift+Tab/←/↑/h/k = anterior
 *       j/k (vertical) mueven por FILAS · 1-9,0 = salto directo al ws N del grupo
 *       Enter/Space = ir al ws seleccionado · Esc = cerrar
 *   · Wheel sobre la grilla → desplaza el grupo visible (ventana deslizante).
 *   · Click tile = ir a ese ws · Click ventana = enfocarla · Click medio = cerrarla.
 *   · El hover de tabs/tiles selecciona (feedback visual acento).
 *
 * Data: WinMap (hyprctl polls) + DesktopEntries (fallback ícono/monograma).
 * Capturas vivas de ToplevelManager, `live` sólo mientras `open` ⇒ cero coste en
 * reposo. El morph (entrada/salida) lo maneja PillSurface (morphCloseness).
 */
PillSurface {
    id: root
    mTop: Theme.marginLg
    mLeft: Theme.marginLg
    mRight: Theme.marginLg
    mBottom: Theme.marginLg

    // ---- monitor (el de esta surface, inyectado por el host) ----
    readonly property var mon: {
        var ms = WinMap.monitors
        for (var i = 0; i < ms.length; i++)
            if (ms[i].name === root.screenName) return ms[i]
        return ms.length ? ms[0] : null
    }
    readonly property int monId: mon ? mon.id : -1
    readonly property int activeId: WinMap.activeWorkspace ? (WinMap.activeWorkspace.id || 1) : 1

    // ---- estado de carga: espera a que WinMap traiga datos (async) ----
    // Los procesos hyprctl (clients/monitors/workspaces) tardan ~100ms. Mantenemos
    // una señal mínima de carga para que el usuario perciba que "está llegando".
    readonly property bool loading: !WinMap.ready
    Timer {
        interval: 600
        repeat: false
        running: root.open && root.loading
        onTriggered: if (WinMap.ready) root._onDataReady()
    }
    function _onDataReady() {
        // no-op: la selección es por workspace, no depende de flatWins
    }
    readonly property real usableW: mon ? Math.max(2, mon.width / mon.scale - (mon.reserved[0] || 0) - (mon.reserved[2] || 0)) : root.width
    readonly property real usableH: mon ? Math.max(2, mon.height / mon.scale - (mon.reserved[1] || 0) - (mon.reserved[3] || 0)) : root.height
    readonly property real baseX: mon ? mon.x + (mon.reserved[0] || 0) : 0
    readonly property real baseY: mon ? mon.y + (mon.reserved[1] || 0) : 0
    readonly property real screenAspect: root.usableW / root.usableH

    // ---- layout ----
    readonly property int cols: 3
    readonly property int rows: 2
    readonly property int groupSize: cols * rows
    // mutable: la wheel del grupo lo desplaza (ventana deslizante sobre ws)
    property int groupBase: Math.floor((activeId - 1) / groupSize) * groupSize + 1
    readonly property var visibleIds: {
        var out = []
        for (var i = 0; i < root.groupSize; i++) out.push(root.groupBase + i)
        return out
    }

    readonly property real gap: 12 * s
    readonly property real tabRowH: 40 * s
    readonly property real hdrGap: 14 * s

    // tiles screen-aspect dentro del área del body; si no caben, encogen.
    readonly property real availW: root.width
    readonly property real availH: root.height - root.tabRowH - root.hdrGap
    readonly property real rawTileW: (availW - (cols - 1) * gap) / cols
    readonly property real rawTileH: rawTileW / screenAspect
    readonly property bool overflow: (rows * rawTileH + (rows - 1) * gap) > availH
    readonly property real tileH: overflow
        ? (availH - (rows - 1) * gap) / rows
        : rawTileH
    readonly property real tileW: tileH * screenAspect

    // ---- navegación por teclado ----
    // El overview selecciona WORKSPACES (los tabs de arriba + tiles), no ventanas:
    //   Tab/→/↓ = siguiente ws, Shift+Tab/←/↑ = anterior, Enter/Space = ir a ese ws.
    // Las previews de ventanas dan contexto, pero la acción es cambiar de workspace.
    // (El viejo comportamiento enfocaba una VENTANA y fallaba cuando flatWins estaba
    // vacío por la carga async de WinMap — por eso "Enter no llevaba a la pestaña".)
    readonly property int selWs: {
        var i = root.visibleIds.indexOf(root._selIndexWs)
        return i >= 0 ? root._selIndexWs : root.activeId
    }
    property int _selIndexWs: -1
    // "último input manda": el hover del mouse NO debe pisar la selección que el
    // usuario hace con el teclado (bug: mouse sobre el tile activo → Enter iba al ws 2).
    // keyNav=true tras usar teclado; un movimiento REAL del mouse lo desactiva.
    property bool _keyNav: false
    function _keyMove() { root._keyNav = true }
    function _mouseMove() { root._keyNav = false }
    function _hoverSelect(wsId) {
        if (root._keyNav) return
        root._selIndexWs = wsId
    }
    readonly property int _selWsIndex: {
        var i = root.visibleIds.indexOf(root.selWs)
        return i >= 0 ? i : 0
    }
    function cycle(delta) {
        root._keyMove()
        var n = root.visibleIds.length
        if (n === 0) return
        // arranca desde el ws activo (o el previamente seleccionado)
        var start = root._selIndexWs >= 0 ? root._selIndexWs : root.activeId
        var i = root.visibleIds.indexOf(start)
        if (i < 0) i = delta > 0 ? -1 : 0
        var ni = ((i + delta) % n + n) % n
        root._selIndexWs = root.visibleIds[ni]
    }
    /** Movimiento por FILAS (j/k): cambia de fila manteniendo la columna. */
    function cycleRow(deltaRows) {
        root._keyMove()
        var n = root.visibleIds.length
        if (n === 0) return
        var start = root._selIndexWs >= 0 ? root._selIndexWs : root.activeId
        var i = root.visibleIds.indexOf(start)
        if (i < 0) i = 0
        var col = i % root.cols
        var row = Math.floor(i / root.cols)
        var nr = ((row + deltaRows) % root.rows + root.rows) % root.rows
        var ni = nr * root.cols + col
        root._selIndexWs = root.visibleIds[ni]
    }
    /** Salto directo: 1-9 → workspace de la posición N del grupo (0 → posición 10). */
    function goIndex(num) {
        root._keyMove()
        if (num === 0) num = 10
        var idx = num - 1
        if (idx >= 0 && idx < root.visibleIds.length)
            root._selIndexWs = root.visibleIds[idx]
    }
    /** Wheel: desplaza el GRUPO visible (ventana deslizante sobre todos los ws). */
    function shiftGroup(delta) {
        root._keyMove()
        var span = Math.max(1, root.visibleIds.length)
        var cur = root._selIndexWs >= 0 ? root._selIndexWs : root.activeId
        var groupIdx = Math.floor((cur - 1) / span)
        var next = Math.max(0, groupIdx + delta)
        var base = next * span + 1
        var ids = []
        for (var i = 0; i < span; i++) ids.push(base + i)
        root.groupBase = base
        root._selIndexWs = base
    }
    function commitSelection() {
        // Leer el índice directamente al confirmar. `selWs` es una propiedad
        // derivada y durante el mismo evento de teclado puede conservar su valor
        // anterior un frame; eso hacía que Enter reabriera el workspace activo.
        var i = root.visibleIds.indexOf(root._selIndexWs)
        var target = i >= 0 ? root._selIndexWs : root.activeId
        if (target > 0) root.goWorkspace(target)
        else root.requestClose()
    }
    onOpenChanged: {
        if (root.open) {
            root._selIndexWs = root.activeId
            root._keyNav = true
        } else {
            root._selIndexWs = -1
            root._keyNav = false
        }
    }

    // ---- reloj visible siempre (header) ----
    property date now: new Date()
    Timer { interval: 1000; repeat: true; running: root.open; onTriggered: root.now = new Date() }

    // ---- helpers ----
    function occupied(id) { return WinMap.winCount(id) > 0 }

    function goWorkspace(id) {
        // Esta instalación expone los dispatchers mediante la API Lua de
        // hyprctl; la sintaxis antigua `dispatch workspace N` se interpreta
        // como Lua inválido y no cambia nada.
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + id + " })"])
        root.requestClose()
    }    function focusWindow(addr) {
        root.requestClose()
        Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + addr])
    }
    function closeWindow(addr) {
        Quickshell.execDetached(["hyprctl", "dispatch", "closewindow", "address:" + addr])
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.hdrGap

        // ---- header: tabs (centro) + reloj (dr) ----
        Item {
            id: tabRow
            Layout.fillWidth: true
            Layout.preferredHeight: root.tabRowH

            QtObject {
                id: tabSpotManager
                function tabIndex(id) {
                    var i = root.visibleIds.indexOf(id)
                    return i >= 0 ? i : 0
                }
                function tabW(id) { return root.occupied(id) ? 40 * s : 34 * s }
                function tabGap() { return 9 * s }
                function tabX(id) {
                    var idx = tabIndex(id)
                    var x = 0
                    for (var i = 0; i < idx; i++) x += tabW(visibleIds[i]) + tabGap()
                    return x
                }
            }

            // ancho de la fila de tabs para centrarla ignorando el reloj
            readonly property real tabsW: {
                var ids = root.visibleIds
                var w = 0
                for (var i = 0; i < ids.length; i++)
                    w += tabSpotManager.tabW(ids[i]) + (i < ids.length - 1 ? tabSpotManager.tabGap() : 0)
                return w
            }

            // spotlight acento que se desliza y respira sobre el ws seleccionado
            // (keyboard nav): por defecto el activo, se mueve con Tab/flechas.
            Rectangle {
                id: tabSpot
                height: 34 * s
                width: 46 * s
                radius: height / 2
                y: (tabRow.height - height) / 2
                x: (tabRow.width - tabRow.tabsW) / 2 + tabSpotManager.tabX(root.selWs) - (width - tabSpotManager.tabW(root.selWs)) / 2
                color: Qt.alpha(Theme.accent, Theme.alphaGlow)
                border.color: Qt.alpha(Theme.accent, Theme.alphaCritical)
                border.width: Theme.borderHairline
                visible: root.visibleIds.indexOf(root.selWs) >= 0
                Behavior on x {
                    Anim { type: Anim.Glide }
                }
                transformOrigin: Item.Center
                SequentialAnimation on scale {
                    running: root.open && root.visibleIds.indexOf(root.selWs) >= 0
                    loops: Animation.Infinite
                    Anim { from: 1.0; to: 1.05; duration: Motion.breathe; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.easeOut }
                    Anim { from: 1.05; to: 1.0; duration: Motion.breathe; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.easeOut }
                    PauseAnimation { duration: Math.round(700 * Motion.mult) }
                }
            }

            Flow {
                id: tabsFlow
                anchors.verticalCenter: parent.verticalCenter
                x: (parent.width - tabRow.tabsW) / 2
                spacing: tabSpotManager.tabGap()

                Repeater {
                    model: root.visibleIds
                    delegate: Rectangle {
                        id: tab
                        required property int modelData
                        readonly property int wsId: modelData
                        readonly property bool active: activeId === wsId
                        readonly property bool sel: root.selWs === wsId
                        readonly property bool occ: root.occupied(wsId)
                        width: tabSpotManager.tabW(wsId)
                        height: 34 * s
                        radius: height / 2
                        color: active
                            ? Qt.alpha(Theme.accent, Theme.alphaIconOnAcc)
                            : (sel ? Qt.alpha(Theme.accent, Theme.alphaSelected)
                                   : (occ ? Qt.alpha(Theme.foreground, Theme.alphaSoft) : Qt.alpha(Theme.foreground, Theme.alphaGhost)))
                        border.width: Theme.borderHairline
                        border.color: active ? Qt.alpha(Theme.accent, 1.0)
                            : (sel ? Qt.alpha(Theme.accent, Theme.alphaIconSec)
                                   : (occ ? Qt.alpha(Theme.foreground, Theme.alphaSubtle) : Qt.alpha(Theme.foreground, Theme.alphaSoft)))
                        scale: (active || sel) ? 1.0 : (ma.containsMouse ? 1.08 : 1.0)
                        transformOrigin: Item.Center
                        Behavior on scale { Anim { type: Anim.FastEffects } }
                        Behavior on color { ColorAnimation { duration: Motion.standard } }
                        Behavior on border.color { ColorAnimation { duration: Motion.standard } }

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingMd * s
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: wsId
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSizeBodyLg * s
                                font.weight: Font.DemiBold
                                color: tab.active ? Theme.background : (tab.occ ? Theme.foreground : Theme.dim)
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !tab.active && tab.occ
                                width: 5 * s; height: 5 * s; radius: width / 2
                                color: Qt.alpha(Theme.accent, Theme.alphaIconOnAcc)
                                SequentialAnimation on opacity {
                                    running: tab.occ && !tab.active
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0.5; to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                                    NumberAnimation { from: 1.0; to: 0.5; duration: 1000; easing.type: Easing.InOutSine }
                                }
                            }
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // hover selecciona (feedback visual); click navega a ese ws
                            onContainsMouseChanged: if (containsMouse) root._hoverSelect(wsId)
                            onMouseXChanged: root._mouseMove()
                            onMouseYChanged: root._mouseMove()
                            onClicked: root.goWorkspace(wsId)
                        }
                    }
                }
            }

            // reloj compacto a la derecha del header (siempre visible)
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Flags.time12h
                      ? Qt.formatDateTime(root.now, "h:mm") + " "
                      + Qt.formatDateTime(root.now, "ap").toUpperCase()
                      : Qt.formatDateTime(root.now, "HH:mm")
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSizeBodyLg * s
                font.weight: Font.DemiBold
                color: Theme.foreground
                opacity: 0.85
            }
        }

        // ---- grilla de tiles (centrada verticalmente, screen-aspect) ----
        Grid {
            id: tileGrid
            Layout.fillWidth: true
            Layout.preferredHeight: root.rows * root.tileH + (root.rows - 1) * root.gap
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            columns: root.cols
            rows: root.rows
            spacing: root.gap
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            Repeater {
                model: root.visibleIds
                delegate: StaggerItem {
                    id: tile
                    required property int modelData
                    readonly property int wsId: modelData
                    readonly property bool active: activeId === wsId
                    readonly property bool sel: root.selWs === wsId
                    readonly property var wins: WinMap.windowsOn(wsId, root.monId)
                    readonly property bool hasWins: wins.length > 0
                    width: root.tileW
                    height: root.tileH
                    entered: root.open
                    staggerIndex: Math.max(0, root.visibleIds.indexOf(tile.wsId))
                    s: root.s

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusXl * s
                        clip: true
                        color: tile.active
                            ? Qt.alpha(Theme.accent, Theme.alphaFaint)
                            : Qt.alpha(Theme.cardBot, Flags.glassAlpha * 0.5)
                        border.width: (tile.active || tile.sel) ? 2 : 1
                        border.color: tile.active
                            ? Qt.alpha(Theme.accent, Theme.alphaIconOnAcc)
                            : (tile.sel ? Qt.alpha(Theme.accent, Theme.alphaIconSec) : Qt.alpha(Theme.foreground, Theme.alphaWash))
                        Behavior on color { ColorAnimation { duration: Motion.standard } }
                        Behavior on border.color { ColorAnimation { duration: Motion.standard } }
                        Behavior on border.width { Anim { type: Anim.FastEffects } }

                        // glow pulsante en el tile activo (doble capa)
                        Rectangle {
                            visible: tile.active
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: Theme.borderEmphasis
                            border.color: Qt.alpha(Theme.accent, Theme.alphaTransparent)
                            SequentialAnimation on border.color {
                                running: root.open && tile.active
                                loops: Animation.Infinite
                                ColorAnimation { from: Qt.alpha(Theme.accent, Theme.alphaGhost); to: Qt.alpha(Theme.accent, Theme.alphaChip); duration: 2000; easing.type: Easing.InOutSine }
                                ColorAnimation { from: Qt.alpha(Theme.accent, Theme.alphaChip); to: Qt.alpha(Theme.accent, Theme.alphaGhost); duration: 2000; easing.type: Easing.InOutSine }
                                PauseAnimation { duration: Math.round(400 * Motion.mult) }
                            }
                        }
                        Rectangle {
                            visible: tile.active
                            anchors.fill: parent
                            anchors.margins: -4
                            radius: parent.radius + 4
                            color: "transparent"
                            border.width: Theme.borderHairlineSoft
                            border.color: Qt.alpha(Theme.accent, Theme.alphaTransparent)
                            SequentialAnimation on border.color {
                                running: root.open && tile.active
                                loops: Animation.Infinite
                                ColorAnimation { from: Qt.alpha(Theme.accent, Theme.alphaTransparent); to: Qt.alpha(Theme.accent, Theme.alphaHair); duration: 2000; easing.type: Easing.InOutSine }
                                ColorAnimation { from: Qt.alpha(Theme.accent, Theme.alphaHair); to: Qt.alpha(Theme.accent, Theme.alphaTransparent); duration: 2000; easing.type: Easing.InOutSine }
                                PauseAnimation { duration: Math.round(400 * Motion.mult) }
                            }
                        }

                        // badge del nº de workspace (esquina sup-izq, siempre visible)
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: 8 * s
                            width: 22 * s
                            height: 22 * s
                            radius: width / 2
                            color: tile.active
                                ? Theme.accent
                                : (tile.sel ? Qt.alpha(Theme.accent, Theme.alphaSelected) : Qt.alpha(Theme.cardTop, Theme.alphaIconSec))
                            border.width: Theme.borderHairline
                            border.color: tile.active ? Qt.alpha(Theme.accent, 1.0)
                                : (tile.sel ? Qt.alpha(Theme.accent, Theme.alphaIconSec) : Qt.alpha(Theme.foreground, Theme.alphaWash))
                            scale: tile.sel && !tile.active ? 1.1 : 1.0
                            Behavior on scale { Anim { type: Anim.FastEffects } }
                            Behavior on color { ColorAnimation { duration: Motion.standard } }
                            Behavior on border.color { ColorAnimation { duration: Motion.standard } }
                            Text {
                                anchors.centerIn: parent
                                text: tile.wsId
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSizeBody * s
                                font.weight: Font.DemiBold
                                color: tile.active ? Theme.background : (tile.sel ? Theme.accent : Qt.alpha(Theme.foreground, Theme.alphaIconSec))
                            }
                        }

                        // ws vacío: nº grande atenuado
                        Text {
                            anchors.centerIn: parent
                            visible: !tile.hasWins
                            text: tile.wsId
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSizePreview * s
                            font.weight: Font.DemiBold
                            color: Qt.alpha(Theme.foreground, tile.active ? 0.30 : 0.16)
                        }

                        // ---- previews vivos ----
                        Repeater {
                            model: tile.wins
                            delegate: Item {
                                id: preview
                                required property var modelData
                                readonly property var win: modelData
                                // el "seleccionado" ahora es el WORKSPACE (tile.sel):
                                // todas las previews del tile seleccionado se resaltan.
                                readonly property bool selected: tile.sel
                                readonly property var toplevel: WinMap.toplevelByAddress[win.address] || null
                                readonly property bool hasCapture: preview.toplevel !== null && preview.toplevel !== undefined
                                readonly property bool doCapture: root.open && preview.hasCapture
                                readonly property string icName: {
                                    var e = DesktopEntries.heuristicLookup(win.class || "")
                                    return e ? ("" + e.icon) : ""
                                }
                                readonly property bool hasIcon: icName.length > 0
                                readonly property string iconPath: hasIcon ? Quickshell.iconPath(icName, "image-missing") : ""
                                readonly property string monogram: win.class ? win.class.charAt(0).toUpperCase() : "?"

                                x: ((win.at[0] || 0) - root.baseX) / root.usableW * tile.width
                                y: ((win.at[1] || 0) - root.baseY) / root.usableH * tile.height
                                width: Math.max(8 * s, (win.size[0] || 0) / root.usableW * tile.width)
                                height: Math.max(8 * s, (win.size[1] || 0) / root.usableH * tile.height)
                                clip: true
                                z: (win.fullscreen || 0) > 0 ? 20 : ((win.floating ? 10 : 0) + (selected ? 15 : 1))

                                // highlight de selección — escala leve + glow acento
                                transformOrigin: Item.Center
                                scale: selected ? 1.03 : 1.0
                                Behavior on scale { Anim { type: Anim.FastEffects } }
                                // previews del ws NO seleccionado se atenúan (resalta el activo/selecto)
                                opacity: root.selWs === tile.wsId || tile.active ? 1 : 0.55
                                Behavior on opacity { Anim { type: Anim.FastEffects } }

                                Rectangle {
                                    id: previewBox
                                    anchors.fill: parent
                                    radius: Theme.radiusXs * s
                                    color: Qt.alpha(Theme.cardTop, Theme.alphaCritical)
                                    border.width: selected ? 2 : 1
                                    border.color: selected
                                        ? Theme.accent
                                        : Qt.alpha(Theme.foreground, ph.containsMouse ? 0.40 : 0.14)
                                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                                    Behavior on border.width { Anim { type: Anim.FastEffects } }

                                    // glow pulsante del seleccionado (doble capa)
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -3 * s
                                        radius: parent.radius + 3 * s
                                        color: "transparent"
                                        border.width: Theme.borderEmphasis
                                        border.color: Qt.alpha(Theme.accent, Theme.alphaTransparent)
                                        visible: preview.selected
                                        z: -1
                                        SequentialAnimation on border.color {
                                            running: preview.selected
                                            loops: Animation.Infinite
                                            ColorAnimation { from: Qt.alpha(Theme.accent, Theme.alphaWash); to: Qt.alpha(Theme.accent, Theme.alphaCritical); duration: 1000; easing.type: Easing.InOutSine }
                                            ColorAnimation { from: Qt.alpha(Theme.accent, Theme.alphaCritical); to: Qt.alpha(Theme.accent, Theme.alphaWash); duration: 1000; easing.type: Easing.InOutSine }
                                        }
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -6 * s
                                        radius: parent.radius + 6 * s
                                        color: "transparent"
                                        border.width: Theme.borderHairlineSoft
                                        border.color: Qt.alpha(Theme.accent, Theme.alphaTransparent)
                                        visible: preview.selected
                                        z: -2
                                        SequentialAnimation on border.color {
                                            running: preview.selected
                                            loops: Animation.Infinite
                                            ColorAnimation { from: Qt.alpha(Theme.accent, Theme.alphaTransparent); to: Qt.alpha(Theme.accent, Theme.alphaWash); duration: 1000; easing.type: Easing.InOutSine }
                                            ColorAnimation { from: Qt.alpha(Theme.accent, Theme.alphaWash); to: Qt.alpha(Theme.accent, Theme.alphaTransparent); duration: 1000; easing.type: Easing.InOutSine }
                                        }
                                    }

                                    ScreencopyView {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        visible: preview.doCapture
                                        captureSource: preview.doCapture ? preview.toplevel : null
                                        live: preview.doCapture
                                        layer.enabled: true
                                        layer.smooth: true
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        visible: !preview.doCapture
                                        spacing: Theme.spacingSm * s

                                        Image {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            source: preview.iconPath
                                            width: Math.min(preview.width * 0.34, 30 * s)
                                            height: width
                                            sourceSize: Qt.size(Math.max(1, Math.round(width)), Math.max(1, Math.round(width)))
                                            visible: preview.hasIcon && status === Image.Ready
                                            fillMode: Image.PreserveAspectFit
                                        }
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            visible: !preview.hasIcon && preview.width > 30 * s
                                            width: Math.min(preview.width * 0.34, 30 * s)
                                            height: width
                                            radius: width / 2
                                            color: Qt.alpha(Theme.accent, Theme.alphaGlow)
                                            border.width: Theme.borderHairline
                                            border.color: Qt.alpha(Theme.accent, Theme.alphaSelected)
                                            Text {
                                                anchors.centerIn: parent
                                                text: preview.monogram
                                                font.family: Theme.font
                                                font.pixelSize: parent.height * 0.5
                                                font.weight: Font.DemiBold
                                                color: Theme.accent
                                            }
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: (win.title || win.class || "").slice(0, 18)
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSizeCaption * s
                                            color: Qt.alpha(Theme.foreground, Theme.alphaIconSec)
                                            elide: Text.ElideRight
                                            width: preview.width - 6 * s
                                            horizontalAlignment: Text.AlignHCenter
                                            visible: preview.width > 40 * s
                                        }
                                    }

                                    // botón cerrar (×) — visible al hover
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 2 * s
                                        width: 16 * s
                                        height: 16 * s
                                        radius: width / 2
                                        color: Qt.alpha("#cc0000", closeBtn.containsMouse ? 0.9 : 0.6)
                                        visible: ph.containsMouse && preview.width > 30 * s
                                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "×"
                                            color: "#ffffff"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeBody * s
                                            font.weight: Font.Bold
                                        }
                                        MouseArea {
                                            id: closeBtn
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.closeWindow(preview.win.address)
                                        }
                                    }
                                }

                                // tooltip con título completo al hover
                                Rectangle {
                                    id: tooltip
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottomMargin: -18 * s
                                    width: tooltipText.implicitWidth + 8 * s
                                    height: 16 * s
                                    radius: height / 2
                                    color: Qt.alpha(Theme.cardTop, Theme.alphaIconOnAcc)
                                    border.color: Theme.border
                                    border.width: Theme.borderHairline
                                    visible: ph.containsMouse && preview.width > 30 * s && (win.title || win.class || "").length > 18
                                    opacity: ph.containsMouse ? 1 : 0
                                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                                    Text {
                                        id: tooltipText
                                        anchors.centerIn: parent
                                        text: win.title || win.class || ""
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSizeCaption * s
                                        color: Theme.foreground
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: ph
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                    cursorShape: Qt.PointingHandCursor
                                    onMouseXChanged: root._mouseMove()
                                    onMouseYChanged: root._mouseMove()
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.MiddleButton)
                                            root.closeWindow(preview.win.address)
                                        else
                                            root.focusWindow(preview.win.address)
                                    }
                                    z: 99
                                }
                            }
                        }

                        MouseArea {
                            // El fondo de un tile no puede quedar bajo sus
                            // elementos visuales: en ese caso el hover nunca
                            // llegaba al selector y el click parecía muerto.
                            anchors.fill: parent
                            z: 10
                            acceptedButtons: Qt.LeftButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: if (containsMouse) root._hoverSelect(tile.wsId)
                            onClicked: root.goWorkspace(tile.wsId)
                        }
                    }
                }
            }
        }
    }
}
