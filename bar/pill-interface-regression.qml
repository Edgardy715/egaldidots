import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        width: 680; height: 340
        color: Theme.background
        Item {
            id: materialBounds
            width: 300; height: 38
            PillMaterial { id: material }
        }
        SurfaceHeader {
            id: header
            width: 180; height: implicitHeight
            title: "Un título muy largo que debe quedar dentro de su cabecera"
            subtitle: "Información secundaria también extensa"
            entered: false
            trailing: Component { Item { implicitWidth: 40; implicitHeight: 30 } }
        }
        LauncherView { id: launcher; width: 620; height: 200; visible: false }
        IslandRestStatus { id: clockFixture; y: 290 }
        SignalSpy { id: calendarRequests; target: clockFixture; signalName: "requestCalendar" }
        SignalSpy { id: launches; target: launcher; signalName: "launchRequested" }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "PillInterface"
            when: scene.visible
            property bool finished: false
            function test_reading_states() {
                try {
                    Config.update({appearance: {glassAlpha: 0.34, reduceMotion: true}})
                    wait(100)
                    verify(!header.entered, "header must not overwrite its exposure input")
                    const clockHit = findChild(clockFixture, "clockCalendarHit")
                    verify(clockHit !== null)
                    verify(!clockHit.feedbackEnabled, "expanded clock hit area must not paint outside pill")
                    verify(clockHit.width > clockHit.parent.width, "large hit target retained")
                    mouseClick(clockHit, clockHit.width / 2, clockHit.height / 2, Qt.LeftButton)
                    compare(calendarRequests.count, 1)
                    clockHit.forceActiveFocus()
                    verify(clockHit.activeFocus)
                    fuzzyCompare(material.bodyAlpha, 0.439, 0.000001)
                    fuzzyCompare(findChild(material, "pillMaterialShadow").opacity, 0, 0.000001)
                    const depthLight = findChild(material, "pillMaterialDepthLight")
                    const depthShade = findChild(material, "pillMaterialDepthShade")
                    verify(depthLight.opacity > 0 && depthShade.opacity > 0, "default interior depth visible")
                    verify(Config.update({appearance: {materialDepth: 0}}).ok)
                    compare(depthLight.opacity, 0)
                    compare(depthShade.opacity, 0)
                    verify(Config.update({appearance: {materialDepth: 1}}).ok)
                    verify(depthLight.opacity > 0.2 && depthShade.opacity > 0.2, "depth intensity follows setting")
                    material.edgeExposure = 0
                    compare(depthLight.opacity, 0)
                    compare(depthShade.opacity, 0)
                    material.edgeExposure = 1
                    materialBounds.height = 96
                    fuzzyCompare(material.bodyAlpha, 0.604, 0.000001)
                    wait(400)
                    fuzzyCompare(findChild(material, "pillMaterialShadow").opacity, 0.32, 0.000001)
                    material.s = 2
                    materialBounds.height = 76
                    fuzzyCompare(material.bodyAlpha, 0.439, 0.000001)
                    materialBounds.height = 192
                    fuzzyCompare(material.bodyAlpha, 0.604, 0.000001)
                    Config.update({appearance: {glassAlpha: 1}})
                    compare(material.bodyAlpha, 1)
                    header.entered = true
                    wait(50)
                    const labels = header.children[0].children[1]
                    verify(labels.width > 0 && labels.x + labels.width <= header.width)
                    verify(header.implicitHeight >= labels.implicitHeight)
                    header.visible = false
                    launcher.visible = true
                    launcher.open = true
                    const input = findChild(launcher, "launcherSearch")
                    input.text = "ninguna-aplicacion"
                    launcher.searching = true
                    verify(!launcher.emptyResultsVisible)
                    launcher.searching = false
                    verify(launcher.emptyResultsVisible)
                    verify(findChild(launcher, "launcherEmptyResults").visible)
                    launcher.launchCurrent()
                    compare(launches.count, 0)
                    launcher.showCalculator = true
                    verify(!launcher.emptyResultsVisible)
                    launcher.showCalculator = false
                    input.text = ""
                    verify(!launcher.emptyResultsVisible)
                    launcher.closing = true
                    input.text = "sin-resultados"
                    verify(!launcher.emptyResultsVisible)
                    console.log("PASS: scaled reading material, opaque preference, header exposure/bounds and empty/search/calculator/closing states")
                    finished = true
                } catch (error) {
                    console.error("FAIL: pill interface", error)
                    failureTimer.start()
                }
            }
        }
    }
    Timer { id: failureTimer; interval: 50; onTriggered: Qt.exit(1) }
    Timer { interval: 5000; running: true; onTriggered: { console.error("FAIL: pill interface timeout"); Qt.exit(1) } }
}
