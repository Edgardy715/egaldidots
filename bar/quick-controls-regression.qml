import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    id: test
    settings.watchFiles: false
    property var actions: []

    Window {
        id: scene
        visible: true
        width: 560
        height: 620
        color: Theme.background

        QuickControlsView {
            id: view
            anchors.fill: parent
            s: 1.25
            contentReady: true
            showBrightness: true
            brightnessPercent: 47.3
            brightnessLastWriteOk: false
            keepAwakeEnabled: false
            keepAwakeElapsedTime: "--:--"
            activeProfile: "balanced"
            onRequestPage: (name) => test.actions.push(["page", name])
            onKeepAwakeToggleRequested: test.actions.push(["awake"])
            onBrightnessSetPercent: (percent) => test.actions.push(["brightness", percent])
            onBrightnessStepRequested: (amount) => test.actions.push(["step", amount])
            onProfileSelected: (profile) => test.actions.push(["profile", profile])
        }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }

        TestCase {
            id: checks
            name: "QuickControlsView"
            when: scene.visible
            property bool finished: false
            function action(kind) {
                for (let i = 0; i < test.actions.length; i++)
                    if (test.actions[i][0] === kind) return test.actions[i]
                return null
            }

            function test_mocked_controls() {
                wait(400)
                compare(findChild(view, "brightnessPercent").text, "47%")
                verify(findChild(view, "brightnessWriteError").visible)
                compare(findChild(view, "powerProfileSummary").text, "Equilibrio · recomendado")

                const brightnessDown = findChild(view, "brightnessDecrease")
                mouseClick(brightnessDown, brightnessDown.width / 2, brightnessDown.height / 2)
                compare(action("step")[1], -10)

                const slider = findChild(view, "brightnessSlider")
                mouseClick(slider, slider.width * 0.8, slider.height / 2)
                verify(action("brightness")[1] > 50 && action("brightness")[1] < 100)

                const toggle = findChild(view, "keepAwakeToggle")
                mouseClick(toggle, toggle.width / 2, toggle.height / 2)
                verify(action("awake") !== null)

                const performance = findChild(view, "profile-performance")
                mouseClick(performance, performance.width / 2, performance.height / 2)
                compare(action("profile")[1], "performance")

                const appearance = findChild(view, "appearanceAction")
                mouseClick(appearance, appearance.width / 2, appearance.height / 2)
                compare(action("page")[1], "appearance")
                console.log("PASS: mocked quick controls render service state and emit brightness, keep-awake, profile and navigation actions")
                finished = true
            }
        }
    }
}
