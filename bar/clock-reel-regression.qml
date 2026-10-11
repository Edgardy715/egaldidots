import QtQuick
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    id: test
    property int step: 0
    property real clockWidth: 0
    function check(ok, message) { if (!ok) { console.error("FAIL: " + message); Qt.exit(1) } }
    function capture(name) {
        const directory = Quickshell.env("ISLA_CLOCK_CAPTURE_DIR")
        if (directory) status.grabToImage(result => result.saveToFile(directory + "/" + name + ".png"), Qt.size(status.width * 3, status.height * 3))
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children) { const match = find(child, name); if (match) return match }
        return null
    }
    Window {
        visible: true; width: 300; height: 60; color: Theme.background
        IslandRestStatus { id: status; now: new Date(2026, 9, 9, 11, 59); anchors.centerIn: parent }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            const hours = test.find(status, "clockHours")
            const minutes = test.find(status, "clockMinutes")
            switch (test.step++) {
            case 0:
                test.clockWidth = status.width
                test.check(hours.shown === "11" && minutes.shown === "59" && !minutes.animating, "initial clock is settled")
                test.capture("01-before")
                status.now = new Date(2026, 9, 9, 12, 0)
                break
            case 1:
                test.check(hours.animating && minutes.animating && minutes.travel > 0 && minutes.travel < 1, "hour and minute roll together downward")
                test.capture("02-downward")
                status.now = new Date(2026, 9, 9, 12, 1)
                test.check(minutes.incoming === "00", "rapid changes preserve in-flight destination")
                break
            case 13:
                test.check(hours.shown === "12" && minutes.shown === "01" && !minutes.animating, "queued latest minute settles")
                test.check(Math.abs(status.width - test.clockWidth) < 0.01, "clock width stable at rollover")
                test.capture("03-settled")
                status.now = new Date(2026, 9, 9, 13, 1)
                break
            case 14:
                test.check(hours.animating && !minutes.animating, "unchanged minutes remain still")
                test.check(Config.update({appearance: {reduceMotion: true}}).ok, "temporary reduced motion setting")
                break
            case 15:
                test.check(!hours.animating && hours.shown === "1", "reduced motion snaps to current hour")
                Config.update({appearance: {reduceMotion: false}})
                status.visible = false
                status.now = new Date(2026, 9, 9, 0, 0)
                break
            case 16:
                test.check(hours.shown === "12" && minutes.shown === "00" && !minutes.animating, "hidden clock updates without animation")
                status.visible = true
                break
            case 17:
                test.check(!minutes.animating, "revealing clock does not replay stale changes")
                console.log("PASS: clock downward rollover, queued interruption, stable width, unchanged minutes, reduced motion and hidden updates")
                Qt.quit()
            }
        }
    }
}
