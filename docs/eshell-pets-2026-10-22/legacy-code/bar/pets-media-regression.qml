pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        title: "Eshell Pets Phase4 QA"
        width: 780; height: 510
        visible: true
        color: Theme.background
        property int toggles: 0
        QtObject {
            id: context
            property bool enabled: true
            property bool monitorActive: true
            property real size: 24
            property string profile: "balanced"
            property string character: "ghost"
            property string name: "Mimo"
            property bool mediaSurface: true
            property bool feedingEnabled: true
            property bool sleepEnabled: true
            property bool gazeEnabled: true
            property bool mediaReactions: true
        }
        QtObject {
            id: mockPlayback
            property bool hasPlayer: true
            property bool isPlaying: true
            property bool albumDistinct: false
            property string title: "A quiet afternoon"
            property string artist: "Isla fixture"
            property string album: ""
            property bool canSeek: true
            property bool canShuffle: true
            property bool canRepeat: true
            property bool canPrevious: true
            property bool canNext: true
            property bool canToggle: true
            property bool dragging: false
            property real dragFraction: 0
            property real progress: 0.25
            property real displayPosition: 60
            property real remaining: 180
            property bool repeatOne: false
            property bool shuffleEnabled: false
            property bool repeatEnabled: false
            property real length: 240
            property string displayTime: "1:00"
            property string remainingTime: "3:00"
        }
        MediaView {
            id: media
            open: true
            petPresented: true
            petContext: context
            petTrackKey: "fixture-track-a"
            playback: mockPlayback
            musicPresentation: true
            serviceLabel: "Fixture Music"
            lyricsSupported: true
            onTogglePlayingRequested: window.toggles++
        }
        Timer { id: finish; interval: 120; onTriggered: Qt.quit() }
        TestCase {
            name: "EshellPetsMedia"
            when: Config.loaded && window.visible
            function check(condition, message) { if (!condition) throw new Error(message) }
            function shot(name) {
                const dir = Quickshell.env("ISLA_TEST_OUTPUT")
                if (!dir) return
                window.contentItem.grabToImage(result => result.saveToFile(dir + "/media-" + name + ".png"))
                wait(100)
            }
            function test_mediaPet() {
                try {
                    Config.update({appearance: {reduceMotion: false, mediaTransitions: true}})
                    wait(250)
                    const host = findChild(media, "mediaPetHost")
                    const toggle = findChild(media, "mediaToggle")
                    check(host && host.item, "header pet loads")
                    check(!host.item.runtime.reacting, "initial player has no reaction")
                    check(!host.enabled && !host.activeFocusOnTab, "decorative host leaves keyboard order alone")
                    check(host.lookTarget.y > 0, "gaze targets artwork below header")
                    shot("playing")
                    toggle.forceActiveFocus()
                    keyClick(Qt.Key_Space)
                    check(window.toggles === 1, "existing keyboard transport activates")
                    mockPlayback.isPlaying = false
                    check(host.item.runtime.resting && !host.item.runtime.reacting, "pause is a static resting expression")
                    wait(300)
                    shot("paused")
                    mockPlayback.isPlaying = true
                    check(!host.item.runtime.resting && host.item.runtime.reacting, "resume gives finite reaction")
                    wait(700)
                    check(!host.item.runtime.reacting, "resume reaction settles")
                    mockPlayback.progress = 0.7
                    mockPlayback.displayPosition = 168
                    mockPlayback.displayTime = "2:48"
                    check(!host.item.runtime.reacting, "seek and progress do not notify pet")
                    for (let i = 0; i < 6; i++) { media.petTrackKey = "fixture-" + i; wait(16) }
                    check(host.item.runtime.reacting, "new track reacts")
                    shot("track")
                    wait(700)
                    check(!host.item.runtime.reacting && host.item.runtime.impulse === 0, "track burst settles")
                    Config.update({appearance: {reduceMotion: true}})
                    media.petTrackKey = "reduced-track"
                    check(!host.item.runtime.reacting && host.item.runtime.impulse === 0, "reduced motion stays still")
                    media.petPresented = false
                    check(!host.item && !host.active, "closing presentation destroys runtime")
                    mockPlayback.isPlaying = false
                    media.petTrackKey = "hidden-track"
                    media.petPresented = true
                    wait(50)
                    check(host.item && host.item.runtime.resting && !host.item.runtime.reacting, "reopening establishes current baseline")
                    context.monitorActive = false
                    check(!host.item, "inactive monitor unloads")
                    context.monitorActive = true
                    wait(30)
                    context.size = 48
                    check(!host.item, "oversized pet keeps header clear")
                    context.size = 32
                    wait(50)
                    check(host.item && host.fits, "maximum header size fits")
                    shot("size-32")
                    media.serviceLabel = "An intentionally long service name that needs all of the available header space and keeps expanding beyond the complete header, lyrics toggle, and player controls"
                    wait(50)
                    check(!host.item, "long service label takes precedence")
                    media.serviceLabel = "Fixture Music"
                    context.size = 24
                    media.s = 1.5
                    wait(150)
                    check(host.item && host.fits, "logical scale preserves safe region")
                    shot("scale-150")
                    media.s = 1
                    Config.update({appearance: {reduceMotion: false}})
                    const feed = findChild(media, "petFeedButton")
                    check(feed && feed.visible && feed.enabled && feed.Accessible.name.includes("Mimo"), "explicit named feed control")
                    for (const character of ["ghost", "blob", "octopus"]) {
                        context.character = character
                        check(host.item.character === character, "character changes in shared host")
                        feed.forceActiveFocus()
                        keyClick(Qt.Key_Space)
                        check(host.item.runtime.eating && host.item.runtime.petState === "eating", "keyboard feeding starts")
                        wait(120)
                        check(host.item.runtime.chew > 0, "finite chewing moves")
                        shot(character + "-eating")
                        wait(1600)
                        check(!host.item.runtime.eating && host.item.runtime.chew === 0, "meal settles")
                        shot(character + "-idle")
                        host.item.runtime.sleep()
                        wait(300)
                        shot(character + "-sleeping")
                        host.item.runtime.wake()
                    }
                    context.sleepEnabled = false
                    host.item.runtime.sleepDelay = 30
                    host.item.runtime.sleep()
                    wait(80)
                    check(!host.item.runtime.sleeping, "sleep opt-out blocks manual and automatic sleep")
                    context.gazeEnabled = false
                    check(host.item.runtime.lookX === 0 && host.item.runtime.lookY === 0, "gaze opt-out")
                    context.mediaReactions = false
                    media.petTrackKey = "opt-out-track"
                    check(!host.item.runtime.reacting, "media reactions opt-out")
                    host.feed()
                    check(host.item.runtime.eating, "feeding independent of reaction opt-out")
                    context.feedingEnabled = false
                    check(!feed.visible && !host.item.runtime.eating && host.item.runtime.chew === 0, "feeding opt-out cancels meal and control")
                    context.feedingEnabled = true
                    Config.update({appearance: {reduceMotion: true}})
                    host.feed()
                    check(host.item.runtime.eating && host.item.runtime.chew === 0, "reduced meal has static acknowledgment")
                    wait(1700)
                    check(!host.item.runtime.eating, "static acknowledgment ends")
                    Config.update({appearance: {reduceMotion: false}})
                    context.profile = "minimal"
                    host.feed()
                    check(host.item.runtime.eating && host.item.runtime.chew === 0, "minimal meal stays still")
                    context.mediaSurface = false
                    check(!host.item && !feed.visible, "surface opt-out destroys active meal")
                    context.mediaSurface = true
                    wait(30)
                    check(host.item && !host.item.runtime.eating, "return never replays meal")
                    context.enabled = false
                    check(!host.item && !media.petVisible, "disabled pet releases resources")
                    shot("disabled")
                    mockPlayback.hasPlayer = false
                    check(!host.item, "no player leaves empty state clear")
                    console.log("PASS: pets media baseline, playback, track, seek, keyboard, reduced, hidden, monitor, size and scale")
                    finish.start()
                } catch (error) { console.error("FAIL: pets media " + error); Qt.exit(1) }
            }
        }
    }
}
