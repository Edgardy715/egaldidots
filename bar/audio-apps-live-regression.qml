import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "components"

ShellRoot {
    settings.watchFiles: false
    AudioController { id: audio; active: true; meterSources: view.meterSources }
    Window {
        id: scene
        visible: true; width: 800; height: 660
        Rectangle { anchors.fill: parent; color: Theme.background }
        MixerView {
            id: view
            anchors.fill: parent; anchors.margins: 24
            page: 2
            ready: audio.ready; error: audio.error
            outputs: audio.outputs; inputs: audio.inputs; playback: audio.playback; recording: audio.recording; cards: audio.cards
            defaultOutput: audio.defaultOutput; defaultInput: audio.defaultInput
            levels: audio.levels
            // This read-only fixture never forwards actions to the real audio server.
        }
        TestCase {
            name: "LiveAudioApplications"
            when: scene.visible
            function until(predicate) {
                const deadline=Date.now()+6000
                while(!predicate() && Date.now()<deadline) wait(20)
                if(!predicate()) { console.error("FAIL: live audio apps",audio.error); Qt.exit(1); throw new Error(audio.error) }
            }
            function capture(name) {
                const directory=Quickshell.env("ISLA_AUDIO_SHOTS")
                if(!directory) return
                let saved=false
                scene.contentItem.grabToImage(image=>{ saved=image.saveToFile(directory+"/"+name+".png") })
                until(()=>saved)
            }
            function test_live_names() {
                until(()=>audio.ready && view.rows.length > 0)
                const expected=(Quickshell.env("ISLA_AUDIO_EXPECT_APPS") || "").split(",").filter(Boolean)
                for(const name of expected) until(()=>view.rows.some(row=>row.appName===name))
                wait(800)
                verify(view.kind==="playback")
                capture("01-live-applications")
                view.page=3; wait(700)
                capture("02-live-hardware")
                view.page=2; wait(700)
                verify(view.kind==="playback")
                compare(view.rows.length,audio.playback.length)
                Config.update({appearance:{fontScale:1.75,reduceMotion:true}})
                scene.width=660; scene.height=740
                wait(400); capture("03-live-apps-large-text")
                audio.active=false
                console.log("PASS: live app identity and view",JSON.stringify(expected),"hardware controls, return to playback and large text")
                Qt.quit()
            }
        }
    }
}
