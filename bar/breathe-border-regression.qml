import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        visible: true; width: 200; height: 100
        Rectangle {
            id: stage
            anchors.fill: parent
            BreatheBorder { id: border }
        }
        TestCase {
            when: Config.loaded
            function test_visibilityAndMotion() {
                try {
                    Config.update({appearance: {reduceMotion: false, motionScale: 0.7}})
                    const animation = findChild(border, "breatheAnimation")
                    tryCompare(animation, "running", true)
                    stage.visible = false
                    compare(animation.running, false, "hidden calendar cells do no animation work")
                    stage.visible = true
                    compare(animation.running, true)
                    Config.update({appearance: {reduceMotion: true}})
                    compare(animation.running, false)
                    Config.update({appearance: {reduceMotion: false}})
                    compare(animation.running, true, "agile speed does not disable motion")
                    border.running = false
                    compare(animation.running, false)
                    console.log("PASS: breathing borders stop when hidden or reduced and honor agile motion")
                } catch (error) {
                    console.error("FAIL: breathing borders: " + error)
                    Qt.exit(1)
                }
            }
        }
    }
}
