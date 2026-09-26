import QtQuick
import Quickshell
import "Singletons"

// QT_QPA_PLATFORM=offscreen quickshell -p bar/motion-regression.qml
ShellRoot {
    Item {
        width: 1920; height: 1080
        Pill { id: pill; s: 1; screenName: "motion-regression" }
    }
    function check(ok, message) {
        if (!ok) { console.error("FAIL", message); Qt.exit(1) }
    }
    Timer { interval: 20; running: true; onTriggered: pill.surface = "calendar" }
    Timer { interval: 110; running: true; onTriggered: pill.surface = "mixer" }
    Timer { interval: 150; running: true; onTriggered: pill.surface = "" }
    Timer { interval: 200; running: true; onTriggered: pill.surface = "calendar" }
    Timer {
        interval: 1100; running: true
        onTriggered: {
            check(Math.abs(pill.width - pill.targetW) < 1 && Math.abs(pill.height - pill.targetH) < 1,
                  "interrupted morph must settle")
            check(pill.surfaceItem && pill.surfaceContentProgress > 0.99,
                  "reopened content must be present")
            pill.surface = "mixer"
        }
    }
    Timer {
        interval: 1750; running: true
        onTriggered: {
            let host = pill.surfaceItem
            while (host && host.displayedSurface === undefined) host = host.parent
            check(host && host.displayedSurface === "mixer", "surface swap must commit")
            check(host && host.swapOpacity > 0.99, "swap must reveal content")
            Config.update({ appearance: { reduceMotion: true } })
            pill.surface = ""
        }
    }
    Timer {
        interval: 1800; running: true
        onTriggered: {
            check(Math.abs(pill.width - pill.targetW) < 0.01 && Math.abs(pill.height - pill.targetH) < 0.01,
                  "reduced motion must resolve geometry directly")
            check(!pill.surfaceItem, "closed surface must unload")
            console.log("PASS: interrupted morph, content swap, reduced motion, unload")
            Qt.quit()
        }
    }
}
