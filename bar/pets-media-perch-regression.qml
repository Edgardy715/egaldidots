import QtQuick
import Quickshell
import "components"
import "pets"
import "Singletons"

// A track with a length but no seek hides the timeline: the pet must not perch on it.
ShellRoot {
    id: root
    settings.watchFiles: false
    readonly property var track: ({hasPlayer:true,isPlaying:true,title:"Pista",artist:"Isla",album:"",albumDistinct:false,shuffleEnabled:false,repeatEnabled:false,repeatOne:false,canSeek:true,canShuffle:false,canRepeat:false,canPrevious:false,canNext:false,canToggle:true,dragging:false,progress:0.3,displayPosition:6,length:30,displayTime:"0:06",remainingTime:"0:24"})
    Window {
        id: scene
        visible: true
        width: IslandGeometry.mediaSurface.width
        height: IslandGeometry.mediaSurface.height
        PetLayer { id: pet; monitorActive: true }
        MediaView {
            id: media
            open: true
            petContext: pet
            petPresented: true
            playback: root.track
        }
    }
    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (const child of item.children || []) { const match = find(child, name); if (match) return match }
        return null
    }
    property int step: 0
    property real started: Date.now()
    function fail(reason, perch) {
        console.error("FAIL: " + reason + " " + JSON.stringify({step: step, available: perch ? perch.available : null,
            eligible: media.petEligible, canSeek: media.playback.canSeek}))
        Qt.exit(1)
    }
    Timer {
        interval: 20; repeat: true; running: true
        onTriggered: {
            if (!Config.loaded) return
            const perch = root.find(media, "mediaPetPerch")
            if (Date.now() - root.started > 4000) { root.fail("timeout", perch); return }
            if (root.step === 0) {
                Config.update({pets: {enabled: true, mediaSurface: true}})
                root.step = 1; root.started = Date.now()
            } else if (root.step === 1 && perch && perch.available) {
                media.playback = Object.assign({}, root.track, {canSeek: false})
                root.step = 2; root.started = Date.now()
            } else if (root.step === 2 && Date.now() - root.started > 100) {
                if (perch.available) { root.fail("perch available on a hidden timeline", perch); return }
                console.log("PASS: media perch follows timeline visibility")
                Qt.quit()
            }
        }
    }
}
