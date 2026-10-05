import QtQuick
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    Window {
        visible: true
        width: 320
        height: 50
        TopWorkspaceRail {
            id: rail
            screenName: "motion-test"
            availableWidth: 300
        }
    }

    readonly property var lens: rail.children.find(item => item.objectName === "workspaceLens")
    property real startX: 0

    function check(ok, message) {
        if (!ok) { console.error("FAIL:", message); Qt.exit(1); throw new Error(message) }
    }

    Timer {
        interval: 60; running: true
        onTriggered: {
            check(rail.navWidth - 44 * rail.s >= 20 * rail.s
                  && lens.height > 38 && lens.x >= 0 && lens.x + lens.width <= rail.width,
                  "independent button gap and active orb must fit the rail")
            startX = lens.x
            rail.hoverId = 5
        }
    }
    Timer {
        interval: 120; running: true
        onTriggered: {
            check(lens.x > startX + 8 && lens.x < lens.targetX - 8,
                  "lens must travel through intermediate positions")
            check(lens.stretch > 0 && lens.travel > 0.5,
                  "moving orb must deform and conceal labels under its path")
            rail.hoverId = 2
        }
    }
    Timer {
        interval: 500; running: true
        onTriggered: {
            check(Math.abs(lens.x - lens.targetX) < 1, "retarget must settle at workspace 2")
            rail.hoverId = 0
        }
    }
    Timer {
        interval: 850; running: true
        onTriggered: {
            check(Math.abs(lens.x - lens.targetX) < 1 && lens.velocityX === 0
                  && lens.stretch === 0 && lens.travel === 0,
                  "lens must return to active workspace and stop")
            rail.hoverId = 5
        }
    }
    Timer {
        interval: 890; running: true
        onTriggered: rail.visible = false
    }
    Timer {
        interval: 920; running: true
        onTriggered: {
            check(rail.hoverId === 0 && lens.x === lens.targetX && lens.velocityX === 0,
                  "hiding mid-flight must settle and clear hover")
            rail.visible = true
            rail.hoverId = 5
        }
    }
    Timer {
        interval: 950; running: true
        onTriggered: Config.update({ appearance: { reduceMotion: true } })
    }
    Timer {
        interval: 980; running: true
        onTriggered: {
            check(lens.x === lens.targetX && lens.velocityX === 0,
                  "reduced motion must resolve the lens immediately")
            rail.visible = false
        }
    }
    Timer {
        interval: 1030; running: true
        onTriggered: {
            check(rail.hoverId === 0 && lens.x === lens.targetX,
                  "reduced-motion hide must clear hover and settle the lens")
            console.log("PASS: workspace lens follows, retargets, stops, reduces motion and hides")
            Qt.quit()
        }
    }
}
