import QtQuick
import QtQuick.Layouts
import "../"
import "../Singletons"
import "../components"

/**
 * Isla · SessionSurface. Grid 2×2 de botones logout/shutdown/reboot/lock + un
 * bloque "confirm" opcional (clickear shutdown/reboot pide 2 clics; logout/lock
 * son directos). Inspira en caelestia/modules/session/Content.qml pero más
 * compacto (sin GIF, sin hibernate por defecto).
 *
 * v2: navegación por teclado COMPLETA (la v1 la prometía y no la tenía):
 *   · hjkl / flechas  → mover foco
 *   · Enter/Space      → activar el botón enfocado
 *   · Esc              → cerrar
 *   · 1-4              → acceso directo a cada botón
 *   Foco visual: wash + borde acento + lift (no sólo mouse).
 */
PillSurface {
    id: root
    mTop: Theme.marginSm; mLeft: Theme.marginSm; mRight: Theme.marginSm; mBottom: Theme.marginSm

    property string pending: ""        // "shutdown" / "reboot" / "" — 2 clics
    property int focused: 0            // 0=lock 1=logout 2=reboot 3=shutdown

    // el surface debe tomar activeFocus para recibir las teclas (los keys van
    // al item enfocado). El focus se roba post-morph, igual que el launcher.
    focus: root.open
    onOpenChanged: if (open) focusTimer.restart()
    Timer {
        id: focusTimer
        interval: Motion.morph + 40
        repeat: false
        onTriggered: if (root.open) root.forceActiveFocus()
    }

    // mapa botón → índice para teclas 1-4 y navegación
    function focusBtn(i: int): void {
        root.focused = ((i % 4) + 4) % 4
    }
    function moveFocus(dx: int, dy: int): void {
        var col = root.focused % 2
        var row = Math.floor(root.focused / 2)
        var nc = col + dx
        var nr = row + dy
        if (nc < 0) nc = 1
        else if (nc > 1) nc = 0
        if (nr < 0) nr = 1
        else if (nr > 1) nr = 0
        root.focused = nr * 2 + nc
    }
    function activate(i: int): void {
        switch (i) {
        case 0: lockBtn.activate(); break
        case 1: logoutBtn.activate(); break
        case 2: rebootBtn.activate(); break
        case 3: shutdownBtn.activate(); break
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingLg * s

        // header
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd * s

            Text {
                text: "Sesión"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeBodyLg * s
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.pending.length > 0
                    ? "Click otra vez " + root.pending.toUpperCase() + " para confirmar (~3s)"
                    : ""
                color: Theme.accent
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeLabel * s
                visible: root.pending.length > 0
                font.letterSpacing: 0.4
            }
        }

        // grid 2×2
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8 * s
            columnSpacing: 8 * s

            // ----- LOCK -----
            SessionButton {
                id: lockBtn
                glyph: "lock"
                label: "Lock"
                index: 0
                isFocused: root.focused === 0
                onActivated: Session.lock()
            }

            // ----- LOGOUT -----
            SessionButton {
                id: logoutBtn
                glyph: "logout"
                label: "Logout"
                danger: true
                index: 1
                isFocused: root.focused === 1
                onActivated: Session.logout()
            }

            // ----- REBOOT (con confirmación) -----
            SessionButton {
                id: rebootBtn
                glyph: "restart_alt"
                label: "Reboot"
                danger: true
                armed: root.pending === "reboot"
                index: 2
                isFocused: root.focused === 2
                onActivated: {
                    if (root.pending === "reboot") {
                        Session.reboot()
                        root.pending = ""
                    } else {
                        root.pending = "reboot"
                        confirmTimer.restart()
                    }
                }
            }

            // ----- SHUTDOWN (con confirmación) -----
            SessionButton {
                id: shutdownBtn
                glyph: "power_settings_new"
                label: "Shutdown"
                danger: true
                armed: root.pending === "shutdown"
                index: 3
                isFocused: root.focused === 3
                onActivated: {
                    if (root.pending === "shutdown") {
                        Session.shutdown()
                        root.pending = ""
                    } else {
                        root.pending = "shutdown"
                        confirmTimer.restart()
                    }
                }
            }
        }

        // texto help footer (ahora fiel a la realidad)
        Text {
            Layout.fillWidth: true
            text: "hjkl · navegar   ↵ · ejecutar   esc · cerrar"
            color: Theme.foreground
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeCaption * s
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.42
        }

        Item { Layout.fillHeight: true }
    }

    // timer para resetear estado confirmación (3s)
    Timer {
        id: confirmTimer
        interval: 3000
        repeat: false
        onTriggered: root.pending = ""
    }

    // ---- navegación por teclado (hjkl / arrows / 1-4 / enter / esc) ----
    Keys.onPressed: (event) => {
        var k = event.key
        if (k === Qt.Key_Escape) { root.requestClose(); event.accepted = true; return }
        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            root.activate(root.focused); event.accepted = true; return
        }
        // 1-4 atajos directos
        if (k >= Qt.Key_1 && k <= Qt.Key_4) { root.activate(k - Qt.Key_1); event.accepted = true; return }
        switch (k) {
        case Qt.Key_H: case Qt.Key_Left:  root.moveFocus(-1, 0); event.accepted = true; break
        case Qt.Key_L: case Qt.Key_Right: root.moveFocus(1, 0);  event.accepted = true; break
        case Qt.Key_K: case Qt.Key_Up:    root.moveFocus(0, -1); event.accepted = true; break
        case Qt.Key_J: case Qt.Key_Down:  root.moveFocus(0, 1);  event.accepted = true; break
        }
    }

    Keys.onEscapePressed: root.requestClose()

    // ---------- SESSION BUTTON (inline component) ----------
    component SessionButton: Rectangle {
        id: btn
        property string glyph: ""
        property string label: ""
        property bool danger: false
        property bool armed: false
        property int index: 0
        property bool isFocused: false
        signal activated()

        Layout.fillWidth: true
        Layout.preferredHeight: 56 * s
        radius: Theme.radiusXl * s
        color: armed
            ? Theme.accent
            : (isFocused
                ? Qt.alpha(Theme.accent, Theme.alphaWashStrong)
                : (danger ? Qt.rgba(Theme.accentStrong.r, Theme.accentStrong.g, Theme.accentStrong.b, 0.12) : Theme.cardBot))
        border.width: Theme.borderHairline
        border.color: isFocused
            ? Qt.alpha(Theme.accent, Theme.alphaCritical)
            : (ma.containsMouse ? Qt.alpha(Theme.foreground, Theme.alphaWashStrong) : Theme.border)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.spacingSm * s

            MaterialIcon {
                iconName: btn.glyph
                color: btn.armed ? "#000" : (btn.danger ? Theme.accentStrong : Theme.foreground)
                font.pixelSize: Theme.fontSizeDisplay * s
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: btn.label.toUpperCase()
                color: btn.armed ? "#000" : Theme.foreground
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel * s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
                Layout.alignment: Qt.AlignHCenter
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: { root.focused = btn.index; btn.activated() }
            onContainsMouseChanged: if (containsMouse) root.focused = btn.index
        }

        Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

        // sutil hover lift (también para el foco por teclado)
        scale: (ma.containsMouse || btn.isFocused) ? 1.03 : 1.0
        Behavior on scale {
            Anim { type: Anim.FastEffects }
        }
    }
}
