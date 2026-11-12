import QtQuick
import Quickshell
import "Singletons"
import "components"

// Escenario aislado del vuelo de apps: pill, lanzador falso, LaunchFlight real y una
// ventana que nace en Hyprland simulada. No lanza apps ni toca Hyprland. Avanza el
// tiempo a mano (manualStep) y guarda fotogramas en ISLA_STAGE_OUT.
//   ISLA_CONFIG=$T/shell.json ISLA_STAGE_OUT=$T QT_QPA_PLATFORM=offscreen quickshell -p bar/launch-flight-stage.qml
// Offscreen sirve para revisar forma y trayectoria; no sustituye la QA en Wayland.
ShellRoot {
    id: stage
    settings.watchFiles: false

    readonly property string outDir: Quickshell.env("ISLA_STAGE_OUT") || "/tmp"
    readonly property int openAtMs: Number(Quickshell.env("ISLA_STAGE_OPEN") || 360)
    readonly property int endMs: 1400
    readonly property var shots: [0, 40, 80, 120, 160, 200, 240, 280, 320, 360, 400, 440, 480, 540, 620, 720, 840, 1000, 1200, 1399]
    property int nowMs: 0
    property bool windowOpened: false
    property int shotIndex: 0
    property bool finished: false

    Window {
        id: win
        width: 1280; height: 720
        visible: true
        color: "#202635"
        title: "Isla · vuelo de app · escenario"

        property var windows: ({})
        function lookup(address) { return win.windows[("" + address).replace(/^0x/, "")] || null }
        function current() { return "" }

        // Fondo de escritorio simulado.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#2b3550" }
                GradientStop { position: 1; color: "#12151d" }
            }
        }

        // Pill (cuerpo) en la posición de la barra.
        Rectangle {
            id: pillBody
            x: 490; y: 10; width: 300; height: 44; radius: 22
            color: Theme.cardBot
            border.width: 1; border.color: Qt.alpha(Theme.foreground, 0.12)
        }

        // Lanzador falso: panel con una fila de icono.
        Rectangle {
            id: launcherPanel
            x: 400; y: 250; width: 480; height: 360; radius: 26
            color: Qt.alpha(Theme.cardBot, 0.92)
            border.width: 1; border.color: Qt.alpha(Theme.foreground, 0.1)
            Rectangle {
                id: iconSlot
                x: 36; y: 36; width: 52; height: 52; radius: 14
                color: Qt.alpha(Theme.foreground, 0.08)
                Image {
                    anchors.centerIn: parent
                    width: 40; height: 40
                    source: "file:///usr/share/icons/hicolor/128x128/apps/firefox.png"
                    sourceSize: Qt.size(80, 80)
                }
            }
        }

        // Ventana real que aparece en Hyprland cuando la app abre.
        Rectangle {
            id: appWindow
            visible: stage.windowOpened
            x: 240; y: 120; width: 800; height: 500; radius: 10
            color: "#f2f4f8"
            border.width: 1; border.color: Qt.alpha("#000000", 0.2)
        }

        LaunchFlight {
            id: flight
            objectName: "stageFlight"
            anchors.fill: parent
            s: 1
            monitorName: "DP-1"
            bodyX: pillBody.x; bodyY: pillBody.y; bodyW: pillBody.width; bodyH: pillBody.height
            bodyRadius: pillBody.radius
            workArea: Qt.rect(0, 0, win.width, win.height)
            workspaceTarget: Qt.rect(0, 0, 0, 0)
            visibleWorkspaceId: 1
            readRounding: false
            windowRounding: 10
            manualStep: true
            geometryProvider: win.lookup
            activeAddressProvider: win.current
            z: 3
        }
    }

    function grab(tag) {
        win.contentItem.grabToImage(function (result) {
            result.saveToFile(stage.outDir + "/stage-" + tag + ".png")
        })
    }

    Component.onCompleted: {
        const iconX = iconSlot.mapToItem(win.contentItem, 0, 0).x
        const iconY = iconSlot.mapToItem(win.contentItem, 0, 0).y
        flight.begin({
            originX: iconX + iconSlot.width / 2,
            originY: iconY + iconSlot.height / 2,
            size: iconSlot.width,
            icon: "file:///usr/share/icons/hicolor/128x128/apps/firefox.png",
            candidates: ["firefox"],
            pid: 0
        })
    }

    // Reloj determinista: 16 ms por paso, ventana aparece en openAtMs.
    Timer {
        interval: 16
        running: !stage.finished
        repeat: true
        onTriggered: {
            stage.nowMs += 16
            if (!stage.windowOpened && stage.nowMs >= stage.openAtMs) {
                stage.windowOpened = true
                flight.ingestRaw("openwindow", "aaa,1,firefox,Firefox")
                win.windows = ({ "aaa": { address: "aaa", cls: "firefox", pid: 0,
                    x: appWindow.x, y: appWindow.y, w: appWindow.width, h: appWindow.height,
                    monitor: "DP-1", workspaceId: 1, floating: false } })
                flight.ingestWindow(win.windows["aaa"])
            }
            flight.step(0.016)
            if (stage.shotIndex < stage.shots.length && stage.nowMs >= stage.shots[stage.shotIndex]) {
                stage.grab(("" + stage.shots[stage.shotIndex]).padStart(4, "0") + "-" + flight.phase)
                stage.shotIndex += 1
            }
            if (stage.nowMs >= stage.endMs) stage.finished = true
        }
    }
}
