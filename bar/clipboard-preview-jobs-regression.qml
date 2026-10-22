import QtQuick
import QtTest
import Quickshell
import "components"

ShellRoot {
    settings.watchFiles: false
    ClipboardController { id: controller }
    TestCase {
        name: "ClipboardPreviewJobs"
        when: true
        function test_simultaneousCompletion() {
            try {
                const jobs = findChild(controller, "clipboardPreviewJobs")
                tryVerify(() => controller.previewDir.length > 0)
                const directory = controller.previewDir
                controller.previewDir = ""
                const first = "s-11111111111111111111111111111111"
                const second = "s-22222222222222222222222222222222"
                controller.requestPreview(first, false)
                controller.requestPreview(second, false)
                compare(jobs.count, 2)
                controller.setPreview(first, false, "file:///fixture-first.png", false)
                controller.setPreview(second, false, "file:///fixture-second.png", false)
                controller.previewDir = directory
                tryCompare(jobs, "count", 0)
                compare(controller.previewSources[first + "|thumb"], "file:///fixture-first.png")
                compare(controller.previewSources[second + "|thumb"], "file:///fixture-second.png")
                controller.requestPreview(first, false)
                controller.requestPreview(second, false)
                compare(jobs.count, 0, "cached previews are not regenerated")
                controller.previewDir = ""
                controller.requestPreview(second, true)
                controller.setPreview(second, true, "", true)
                controller.previewDir = directory
                tryCompare(jobs, "count", 0)
                verify(controller.previewFailures[second + "|full"])
                console.log("PASS: concurrent clipboard previews release all jobs and retain cache")
            } catch (error) {
                console.error("FAIL: clipboard preview jobs: " + error)
                Qt.exit(1)
            }
        }
    }
}
