import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import "../"
import "../Singletons"
import "../components"

/** Compact workspace strip with live previews and keyboard navigation. */
PillSurface {
    id: root
    mTop: 24
    mLeft: 26
    mRight: 26
    mBottom: 20

    // ---- monitor (el de esta surface, inyectado por el host) ----
    readonly property var mon: {
        var ms = WinMap.monitors
        for (var i = 0; i < ms.length; i++)
            if (ms[i].name === root.screenName) return ms[i]
        return ms.length ? ms[0] : null
    }
    readonly property int monId: mon ? mon.id : -1
    readonly property int activeId: mon && mon.activeWorkspace ? mon.activeWorkspace.id : 1

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
    readonly property int cols: 4
    readonly property int rows: 1
    readonly property int groupSize: cols * rows
    // mutable: la wheel del grupo lo desplaza (ventana deslizante sobre ws)
    property int groupBase: Math.floor((activeId - 1) / groupSize) * groupSize + 1
    readonly property var visibleIds: {
        var out = []
        for (var i = 0; i < root.groupSize; i++) out.push(root.groupBase + i)
        return out
    }

    readonly property real gap: 18 * s
    readonly property real tileW: Math.max(1, (root.width - 3 * gap) / 4)
    readonly property real tileH: Math.max(1, Math.min(tileW / screenAspect, root.height - 148 * s))

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
    property bool selectionTouched: false
    property bool _keyNav: false
    function _keyMove() { root._keyNav = true; root.selectionTouched = true }
    function _mouseMove() { root._keyNav = false; root.selectionTouched = true }
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
        if (root.rows === 1) { root.shiftGroup(deltaRows); return }
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
    onActiveIdChanged: if (root.open && !root.selectionTouched) {
        root.groupBase = Math.floor((root.activeId - 1) / root.groupSize) * root.groupSize + 1
        root._selIndexWs = root.activeId
    }

    onOpenChanged: {
        if (root.open) {
            root.selectionTouched = false
            root.groupBase = Math.floor((root.activeId - 1) / root.groupSize) * root.groupSize + 1
            root._selIndexWs = root.activeId
            root._keyNav = true
        } else {
            root._selIndexWs = -1
            root._keyNav = false
        }
    }

    function goWorkspace(id) {
        // Esta instalación expone los dispatchers mediante la API Lua de
        // hyprctl; la sintaxis antigua `dispatch workspace N` se interpreta
        // como Lua inválido y no cambia nada.
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + id + " })"])
        root.requestClose()
    }

    Column {
        anchors.fill: parent
        spacing: 18 * root.s
        Item {
            width: parent.width
            height: 46 * root.s
            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * root.s
                Text {
                    text: qsTr("Tus escritorios")
                    font.family: Theme.fontDisplay
                    font.pixelSize: 19 * root.s
                    font.weight: Font.DemiBold
                    color: Theme.foreground
                }
                Text {
                    text: qsTr("Espacios %1–%2").arg(root.groupBase).arg(root.groupBase + root.groupSize - 1)
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    color: Theme.iconSecondary
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * root.s
                visible: Players.has
                IslandMediaSummary {
                    s: root.s
                    coverDiameter: 34 * root.s
                    textWidth: 220 * root.s
                    spacing: 10 * root.s
                    metadataSpacing: 3 * root.s
                    titlePixelSize: 12.5 * root.s
                    artistPixelSize: 11 * root.s
                    artUrl: Players.artUrl
                    hasProgress: Players.active && Players.active.length > 0
                    progress: hasProgress ? Math.max(0, Math.min(1,
                        Players.active.position / Players.active.length)) : 0
                    title: Players.title
                    artist: Players.artist
                }
            }
        }
        Row {
            spacing: root.gap
            Repeater {
                model: root.visibleIds
                delegate: Item {
                    id: tile
                    required property int modelData
                    readonly property int wsId: modelData
                    readonly property bool selected: root.selWs === wsId
                    readonly property bool activeWorkspace: root.activeId === wsId
                    readonly property var windows: WinMap.windowsOn(wsId, root.monId)
                    width: root.tileW
                    height: root.tileH + 36 * root.s
                    RectangularGlow {
                        anchors.fill: desktop
                        anchors.margins: -2 * root.s
                        cornerRadius: desktop.radius + 2 * root.s
                        glowRadius: 8 * root.s
                        spread: 0.08
                        color: Theme.accent
                        opacity: tile.selected ? 0.24 : 0
                        visible: root.open && root.visible && opacity > 0.01
                        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                    }
                    ClippingRectangle {
                        id: desktop
                        objectName: "workspacePreview"
                        width: parent.width
                        height: root.tileH
                        radius: 12 * root.s
                        color: Theme.cardBot
                        border.width: tile.selected ? 2 * root.s : Theme.borderHairline
                        border.color: tile.selected ? Theme.accent : Qt.alpha(Theme.foreground, 0.16)
                        contentInsideBorder: true
                        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                        Image {
                            anchors.fill: parent
                            source: Wallpapers.current ? "file://" + encodeURI(Wallpapers.current) : ""
                            sourceSize: Qt.size(480, 270)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: tile.windows.length ? 0.55 : 0.8
                        }
                        Repeater {
                            model: tile.windows
                            delegate: Rectangle {
                                id: windowPreview
                                required property var modelData
                                readonly property var capturedToplevel: WinMap.toplevelByAddress[modelData.address] || null
                                x: ((modelData.at[0] || 0) - root.baseX) / root.usableW * desktop.width
                                y: ((modelData.at[1] || 0) - root.baseY) / root.usableH * desktop.height
                                width: Math.max(8 * root.s, modelData.size[0] / root.usableW * desktop.width)
                                height: Math.max(8 * root.s, modelData.size[1] / root.usableH * desktop.height)
                                radius: 4 * root.s
                                color: Theme.cardTop
                                border.color: Qt.alpha(Theme.foreground, 0.2)
                                clip: true
                                ScreencopyView {
                                    anchors.fill: parent
                                    captureSource: root.open ? windowPreview.capturedToplevel : null
                                    live: root.open && root.visible && windowPreview.capturedToplevel !== null
                                    visible: windowPreview.capturedToplevel !== null
                                }
                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - 6 * root.s
                                    text: windowPreview.modelData.class || ""
                                    font.family: Theme.font
                                    font.pixelSize: 10 * root.s
                                    color: Theme.foreground
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    visible: windowPreview.capturedToplevel === null
                                }
                            }
                        }
                        MotionArea {
                            anchors.fill: parent
                            accessibleName: qsTr("Ir al escritorio %1").arg(tile.wsId)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: { root._mouseMove(); root._hoverSelect(tile.wsId) }
                            onClicked: root.goWorkspace(tile.wsId)
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 3 * root.s
                        anchors.top: desktop.bottom
                        anchors.topMargin: 11 * root.s
                        text: tile.windows.length ? String(tile.windows.length) : qsTr("Vacío")
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        color: Theme.iconSecondary
                    }
                    Row {
                        anchors.top: desktop.bottom
                        anchors.topMargin: 10 * root.s
                        anchors.left: parent.left
                        anchors.leftMargin: 3 * root.s
                        spacing: 6 * root.s
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 4 * root.s; height: width; radius: width / 2
                            color: Theme.accent
                            visible: tile.activeWorkspace
                        }
                        Text {
                            text: qsTr("Escritorio %1").arg(tile.wsId)
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            font.weight: tile.selected ? Font.DemiBold : Font.Normal
                            color: tile.selected ? Theme.foreground : Theme.iconSecondary
                        }
                    }
                }
            }
        }
        Item {
            width: parent.width
            height: 30 * root.s
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("← →  elegir     ↵  abrir     esc  cerrar")
                color: Theme.iconSecondary
                font.family: Theme.font
                font.pixelSize: 11 * root.s
            }
            Row {
                anchors.right: parent.right
                spacing: 6 * root.s
                Repeater {
                    model: ["chevron_left", "chevron_right", "close"]
                    Rectangle {
                        required property string modelData
                        required property int index
                        width: 30 * root.s; height: width
                        radius: 9 * root.s
                        color: buttonMouse.containsMouse ? Qt.alpha(Theme.foreground, 0.13) : Qt.alpha(Theme.foreground, 0.06)

                        MotionArea {
                            id: buttonMouse
                            accessibleName: index === 2 ? qsTr("Cerrar") : index === 0 ? qsTr("Grupo anterior") : qsTr("Grupo siguiente")
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: index === 2 ? root.requestClose() : root.shiftGroup(index === 0 ? -1 : 1)
                        }

                        MaterialIcon {
                            compressWithControl: true
                            interaction: buttonMouse.motion
                            hovered: buttonMouse.containsMouse
                            anchors.centerIn: parent
                            iconName: modelData
                            font.pixelSize: 18 * root.s
                            color: Theme.foreground
                        }

                    }
                }
            }
        }
    }
}
