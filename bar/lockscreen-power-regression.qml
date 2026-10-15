import QtQuick
import Quickshell
import "lockscreen"
import "Singletons"

ShellRoot {
    id: test
    property int step: 0
    property int powers: 0
    property var menu: null
    property bool sawIntermediate: false
    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.exit(1) }
    }
    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        const nodes = item.data || item.children || []
        for (const child of nodes) {
            const found = find(child, name)
            if (found) return found
        }
        if (item.contentItem) return find(item.contentItem, name)
        return null
    }
    function capture(name) {
        const directory = Quickshell.env("ISLA_LOCK_CAPTURE_DIR")
        if (directory) window.contentItem.grabToImage(result => result.saveToFile(directory + "/" + name + ".png"))
    }
    Window {
        id: window
        visible: true; width: 1000; height: 900
        title: "Isla · Energía (prueba segura)"
        LockSurface {
            id: surface
            anchors.fill: parent
            username: "Vista previa"; avatarSource: ""; secured: true
            onPowerRequested: action => test.powers++
        }
    }
    FrameAnimation {
        running: !!test.menu && test.menu.visible
        onTriggered: if (test.menu.reveal > 0.01 && test.menu.reveal < 0.99) test.sawIntermediate = true
    }
    Timer {
        interval: 120; repeat: true; running: true
        onTriggered: {
            switch (test.step++) {
            case 0:
                surface.activateInput("")
                test.menu = test.find(surface, "lockPowerMenu")
                test.check(!!test.menu, "menu available")
                test.menu.open()
                break
            case 1: test.capture("01-opening"); break
            case 4:
                test.check(test.menu.opened && test.menu.reveal > 0.99, "menu settled")
                test.check(test.sawIntermediate, "native animated entrance")
                test.capture("02-open")
                break
            case 5:
                test.find(test.menu, "lockPowerOption_reboot").clicked()
                test.check(test.powers === 0 && surface.pendingPower === "reboot", "restart guarded")
                break
            case 7: test.capture("03-confirmation"); break
            case 8: test.menu.close(); break
            case 9: test.menu.open(); break
            case 13:
                test.check(test.menu.opened && test.menu.reveal > 0.99, "close/reopen interruption settles")
                test.menu.close()
                break
            case 16:
                test.check(!test.menu.visible && surface.pendingPower === "", "close clears confirmation")
                test.check(test.find(surface, "lockPassword").activeFocus, "password focus restored")
                test.check(Config.update({appearance: {reduceMotion: true, fontScale: 1.75}}).ok, "temporary reduced motion and large text")
                test.menu.open()
                break
            case 18:
                test.check(test.menu.opened && test.menu.reveal === 1, "reduced motion settles")
                test.capture("04-large-text")
                break
            case 19:
                test.find(test.menu, "lockPowerOption_poweroff").clicked()
                test.check(test.powers === 0, "shutdown guarded")
                test.find(test.menu, "lockPowerOption_poweroff").clicked()
                test.check(test.powers === 1, "confirmed shutdown emits only fixture signal")
                break
            case 20:
                test.menu.open()
                surface.authenticated = true
                break
            case 22:
                test.check(!test.menu.visible, "authentication closes menu")
                console.log("PASS: power entrance, interruption, focus, confirmation, large text and reduced motion")
                Qt.quit()
            }
        }
    }
}
