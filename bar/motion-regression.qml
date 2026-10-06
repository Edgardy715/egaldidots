import QtQuick
import Quickshell
import "Singletons"
import "components"

// QT_QPA_PLATFORM=offscreen quickshell -p bar/motion-regression.qml
ShellRoot {
    Item {
        width: 1920; height: 1080
        Pill { id: pill; s: 1; screenName: "motion-regression" }
        StaggerItem { id: stagger; entered: false; staggerIndex: 5; Rectangle { implicitHeight: 20 } }
    }
    function check(ok, message) {
        if (!ok) { console.error("FAIL", message); Qt.exit(1) }
    }
    Timer {
        interval: 20; running: true
        onTriggered: {
            check(pill.wsReady, "first workspace action must be ready after construction")
            const epoch = pill.materialEpoch
            pill.hovered = true
            check(pill.materialEpoch === epoch, "hover must not start a decorative sweep")
            pill.hovered = false
            pill.surface = "calendar"
            check(pill.materialEpoch === epoch + 1, "opening a surface must awaken material")
        }
    }
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
            pill.awakenMaterial()
            reduceCheck.start()
        }
    }
    Timer {
        id: reduceCheck
        interval: 80
        onTriggered: {
            check(pill.materialPulse > 0, "material pulse must start")
            Config.update({ appearance: { reduceMotion: true } })
            check(pill.materialPulse === 0, "reduced motion must stop a running material pulse")
            stagger.entered = true
            pill.surface = ""
        }
    }
    Timer {
        interval: 1900; running: true
        onTriggered: {
            check(Math.abs(pill.width - pill.targetW) < 0.01 && Math.abs(pill.height - pill.targetH) < 0.01,
                  "reduced motion must resolve geometry directly")
            check(stagger.scale === 1, "reduced motion must skip staggered scale")
            check(!pill.surfaceItem, "closed surface must unload")
            console.log("PASS: interrupted morph, content swap, reduced motion, unload")
            Qt.quit()
        }
    }
}
