import QtQuick
import QtTest
import Quickshell
import "components"

ShellRoot {
    settings.watchFiles: false
    QtObject {
        id: fakeConfig
        property var appearance: ({fontFamily: "Test Font", fontScale: 1, uiScale: 1, radiusScale: 1, glassAlpha: 0.34, motionScale: 1})
        property bool saving: false
        property bool dirty: false
        property string error: ""
        property bool invalid: false
        property int saves: 0
        function update(patch) {
            if (invalid) return {ok: false, errors: ["invalid draft"]}
            appearance = patch.appearance
            dirty = true
            return {ok: true}
        }
        function save() { saves++; saving = true; return true }
    }
    AppearanceEditor { id: editor; config: fakeConfig }
    SignalSpy { id: page; target: editor; signalName: "requestPage" }
    Window {
        id: scene
        visible: true; width: 700; height: 540
        MediaView {
            id: media
            open: true
            playback: ({hasPlayer:true, isPlaying:false, albumDistinct:true, title:"Mock", artist:"Artist", album:"Album", canSeek:true, canShuffle:true, canRepeat:true, canPrevious:true, canNext:true, canToggle:true, dragging:false, progress:0.25, displayPosition:30, remaining:90, repeatOne:false, shuffleEnabled:false, repeatEnabled:false, length:120, displayTime:"0:30", remainingTime:"1:30"})
        }
        SignalSpy { id: toggle; target: media; signalName: "togglePlayingRequested" }
        SignalSpy { id: seek; target: media; signalName: "seekRequested" }
        OverviewView {
            id: overview
            visible: false
            open: true
            mon: ({id:1, activeWorkspace:{id:2}, width:1920, height:1080, scale:1, reserved:[0,0,0,0], x:0, y:0})
            windowsByWorkspace: ({2:[{address:"mock", at:[0,0], size:[800,600], class:"Test"}]})
        }
        SignalSpy { id: workspace; target: overview; signalName: "workspaceRequested" }
        AppearanceView {
            id: appearanceView
            visible: false
            open: true
            draft: editor.draft
            initialFontFamily: "Test Font"
            configLoaded: true
            onValueEdited: (key, value) => editor.setValue(key, value)
        }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "SurfaceDataContracts"
            when: scene.visible
            property bool finished: false
            function test_contracts() {
                try {
                wait(150)
                const play = findChild(media, "mediaToggle")
                mouseClick(play, play.width / 2, play.height / 2)
                compare(toggle.count, 1)
                const scrubber = findChild(media, "mediaSeek")
                scrubber.forceActiveFocus()
                keyClick(Qt.Key_Right)
                compare(seek.count, 1)
                compare(seek.signalArguments[0][0], 35)
                keyClick(Qt.Key_End)
                compare(seek.signalArguments[1][0], 120)
                media.visible = false
                overview.visible = true
                overview.goIndex(3)
                overview.commitSelection()
                compare(workspace.count, 1)
                compare(workspace.signalArguments[0][0], 3)
                overview.visible = false
                appearanceView.visible = true
                appearanceView.setValue("fontScale", 1.237)
                compare(editor.draft.fontScale, 1.24)
                compare(fakeConfig.appearance.fontScale, 1)
                fakeConfig.invalid = true
                editor.save("Mock Font")
                compare(editor.message, "invalid draft")
                compare(fakeConfig.saves, 0)
                fakeConfig.invalid = false
                editor.save(" Mock Font ")
                verify(editor.savePending)
                compare(fakeConfig.appearance.fontFamily, "Mock Font")
                editor.save("Ignored")
                compare(fakeConfig.saves, 1)
                fakeConfig.error = "write failed"
                fakeConfig.saving = false
                verify(!editor.savePending)
                compare(editor.message, "write failed")
                compare(page.count, 0)
                fakeConfig.error = ""
                editor.save("Mock Font")
                fakeConfig.dirty = false
                fakeConfig.saving = false
                compare(page.count, 1)
                compare(page.signalArguments[0][0], "utils")
                console.log("PASS: media signals/keyboard seek, overview injected previews/navigation, appearance draft/errors/asynchronous save without system writes")
                finished = true
                } catch (error) { console.error("FAIL: contracts", error); Qt.callLater(() => Qt.exit(1)) }
            }
        }
    }
    Timer { interval: 5000; running: true; onTriggered: { console.error("FAIL: contract timeout"); Qt.exit(1) } }
}
