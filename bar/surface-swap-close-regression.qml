import QtQuick
import Quickshell
import "Singletons"
import "components"

// QT_QPA_PLATFORM=offscreen quickshell -p bar/surface-swap-close-regression.qml
// Cerrar mientras un swap de surface está pendiente no debe volver a mostrar la
// surface anterior (fantasma) mientras la pill se contrae.
ShellRoot {
    Item {
        width: 1920; height: 1080
        Pill { id: pill; s: 1; screenName: "surface-swap-close-regression" }
    }
    property var host: null
    property real closeOpacity: -1
    property real closeSwap: -1
    property real maxSwap: 0
    property real maxOpacity: 0
    function check(ok, message) {
        if (!ok) { console.error("FAIL", message); Qt.exit(1) }
    }
    function findHost() {
        let h = pill.surfaceItem
        while (h && h.displayedSurface === undefined) h = h.parent
        return h
    }
    Timer { interval: 20; running: true; onTriggered: pill.surface = "calendar" }
    Timer {
        interval: 900; running: true
        onTriggered: {
            host = findHost()
            check(host && host.displayedSurface === "calendar" && host.opacity > 0.99,
                  "calendar must be revealed before the swap")
            pill.surface = "mixer"
        }
    }
    Timer {
        interval: 960; running: true
        onTriggered: {
            check(host.displayedSurface === "calendar", "swap must still be pending")
            closeOpacity = host.opacity
            closeSwap = host.swapOpacity
            pill.surface = ""
            sampler.start()
        }
    }
    Timer {
        id: sampler
        interval: 16; repeat: true
        onTriggered: {
            if (!host || host.displayedSurface.length === 0) return
            maxSwap = Math.max(maxSwap, host.swapOpacity)
            maxOpacity = Math.max(maxOpacity, host.opacity)
        }
    }
    Timer {
        interval: 1300; running: true
        onTriggered: {
            sampler.stop()
            check(closeSwap < 0.99 && maxSwap <= closeSwap + 0.01,
                  "closing during a swap must keep content withdrawn (swap " + maxSwap.toFixed(3) + " > " + closeSwap.toFixed(3) + ")")
            check(maxOpacity <= closeOpacity + 0.01,
                  "content must not reappear while closing (" + maxOpacity.toFixed(3) + " > " + closeOpacity.toFixed(3) + ")")
            check(!pill.surfaceItem, "closed surface must unload")
            pill.surface = "calendar"
            reopen.start()
        }
    }
    Timer {
        id: reopen
        interval: 900
        onTriggered: {
            host = findHost()
            check(host && host.displayedSurface === "calendar" && host.swapOpacity > 0.99 && host.opacity > 0.99,
                  "reopening after an interrupted swap must reveal content")
            console.log("PASS: close during pending swap keeps content withdrawn; reopen reveals")
            Qt.exit(0)
        }
    }
}
