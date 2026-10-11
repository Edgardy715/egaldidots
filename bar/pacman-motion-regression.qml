import QtQuick
import Quickshell
import "components"
import "Singletons"
ShellRoot {
    id: test
    property int step: 0
    property bool sawChew: false
    property real widestMouth: 18
    property real narrowestMouth: 18
    property bool capturedOpen: false
    property bool capturedClosed: false
    function capture(name) {
        const directory = Quickshell.env("ISLA_PACMAN_CAPTURE_DIR")
        if (directory) rail.grabToImage(result => result.saveToFile(directory + "/" + name + ".png"), Qt.size(rail.width * 3, rail.height * 3))
    }
    function check(ok, message) { if (!ok) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message) } }
    Window {
        visible: true; width: 400; height: 100; color: Theme.background
        TopWorkspaceRail { id: rail; style: "pacman"; anchors.centerIn: parent }
    }
    readonly property var pacman: rail.children.find(item => item.objectName === "workspacePacman")
    Connections { target: test.pacman; function onMouthAngleChanged() { if (test.pacman.chewing) { test.widestMouth = Math.max(test.widestMouth, test.pacman.mouthAngle); test.narrowestMouth = Math.min(test.narrowestMouth, test.pacman.mouthAngle) } if (Math.abs(test.pacman.mouthAngle - 18) > 3) test.sawChew = true; if (!test.capturedOpen && test.pacman.mouthAngle > 29) { test.capturedOpen = true; test.capture("open") } if (!test.capturedClosed && test.pacman.mouthAngle < 7) { test.capturedClosed = true; test.capture("closed") } } }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            switch (test.step++) {
            case 0: test.check(!pacman.chewing, "rest has no mouth animation"); rail.activeId = 5; break
            case 1: test.check(pacman.chewing && !pacman.facingLeft && test.sawChew, "mouth moves while eating to right"); rail.activeId = 1; break
            case 3: test.check(pacman.facingLeft, "mouth turns toward interrupted left target"); break
            case 9: test.check(test.widestMouth > 40 && test.narrowestMouth < 8, "bite remains visibly wide and closes during travel"); test.check(!pacman.chewing && pacman.mouthAngle === 18, "mouth settles without idle loop"); rail.activeId = 5; break
            case 10: Config.update({appearance: {reduceMotion: true}}); break
            case 11: test.check(!pacman.chewing && pacman.mouthAngle === 18, "reduced motion stops chewing"); Config.update({appearance: {reduceMotion: false}}); rail.activeId = 1; rail.visible = false; break
            case 12: test.check(!pacman.chewing, "hidden rail stops chewing"); console.log("PASS: Pac-Man mouth movement, direction, retarget, settle, reduced motion and hide"); Qt.quit()
            }
        }
    }
}
