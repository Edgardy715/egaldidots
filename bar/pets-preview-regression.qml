import QtQuick
import Quickshell
import "Singletons"
import "pets" as Pets
import "settings" as Settings

ShellRoot {
    id: root
    settings.watchFiles: false
    property string draftPalette: "marea"
    property string draftScale: "normal"
    property bool reduced: false
    property int step: 0
    function check(ok, message) { if (!ok) { console.error("FAIL: " + message); Qt.exit(1) } }
    Window {
        width: 420; height: 240; visible: true
        color: "#283037"
        Item {
            id: mockPerch
            property string perchId: "bar"
            property string kind: "niche"
            property string mood: "idle"
            property real headroom: 60
            property real minX: 20
            property real maxX: 100
            property real restX: 60
            property real reveal: 1
            property real floorY: 70
            property real avoidFrom: -1
            property real avoidTo: -1
            property bool interactive: false
            width: 120; height: 80
        }
        Pets.PetActor {
            id: liveActor
            perch: mockPerch
            mischief: "never"
            sleepEnabled: false
        }
        Pets.PetSprite {
            id: liveSprite
            x: 20; y: 20
            source: Pets.PetPack.atlas
            frame: 6; frameCount: Pets.PetPack.data ? Pets.PetPack.data.frameCount : 1
        }
        Loader {
            id: previewLoader
            x: 100; y: 10; width: 300; height: 184
            active: true
            sourceComponent: Settings.PetPreview {
                palette: root.draftPalette
                petScale: root.draftScale
                reducedMotion: root.reduced
            }
        }
    }
    Timer {
        interval: 120; repeat: true; running: true
        onTriggered: {
            if (!Config.loaded || !Pets.PetPack.ready || (root.step < 5 && previewLoader.status !== Loader.Ready)) return
            const preview = previewLoader.item
            if (root.step === 0) {
                root.check(preview.ticking, "visible preview clock stopped")
                root.check(liveActor.shown, "live actor not visible")
                liveActor.play("dance")
                liveActor.step = 2
                liveActor.schedule()
                root.check(Config.update({pets: {enabled: true, palette: "coral"}}).ok, "palette update")
                root.step++
            } else if (root.step === 1) {
                if (Pets.PetPack.checkedPalette !== "coral") return
                root.check(String(liveSprite.source).endsWith("atlas-coral.png"), "live atlas did not change")
                root.check(liveSprite.frame === 6, "live animation frame reset")
                root.check(liveActor.anim === "dance" && liveActor.step === 2 && liveActor.animating,
                           "actor animation restarted on palette change")
                root.check(Pets.PetPack.ready, "package reloaded")
                root.draftPalette = "lavanda"
                root.draftScale = "large"
                root.step++
            } else if (root.step === 2) {
                root.check(preview.palette === "lavanda" && preview.px === 3, "draft palette or scale ignored")
                root.check(Config.pets.palette === "coral", "preview changed live palette")
                root.draftPalette = "matugen"
                root.step++
            } else if (root.step === 3) {
                root.check(preview.palette === "matugen", "Matugen preview unavailable")
                root.reduced = true
                root.step++
            } else if (root.step === 4) {
                root.check(!preview.ticking && preview.pose === "idle" && preview.frameIndex === 0, "reduced motion active")
                root.reduced = false
                previewLoader.active = false
                root.check(Config.save(), "config save")
                root.step++
            } else {
                root.check(previewLoader.item === null, "hidden preview still loaded")
                if (Config.saving || Config.dirty) return
                console.log("PASS: live atlas, draft preview, hidden and reduced motion")
                Qt.quit()
            }
        }
    }
}
