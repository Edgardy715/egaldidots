import QtQuick
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible: true
        width: IslandGeometry.mediaSurface.width
        height: IslandGeometry.mediaSurface.height
        MediaView {
            id: media
            open: true
            musicPresentation: true
            playback: ({hasPlayer:true, isPlaying:true, albumDistinct:true, title:"Una canción con un título muy largo para comprobar la composición sin invadir los controles", artist:"Un artista con nombre largo", album:"Un álbum distinto", canSeek:true, canShuffle:true, canRepeat:true, canPrevious:true, canNext:true, canToggle:true, dragging:false, progress:0.25, displayPosition:30, remaining:90, repeatOne:false, shuffleEnabled:false, repeatEnabled:false, length:120, displayTime:"0:30", remainingTime:"1:30"})
        }
        Timer {
            id: checks
            interval: 150
            running: true
            repeat: true
            function named(item, name) {
                if (item.objectName === name) return item
                for (const child of item.children || []) {
                    const match = named(child, name)
                    if (match) return match
                }
                return null
            }
            property int step: -1
            property var fonts: [1, 1.2, 1.75]
            onTriggered: {
                try {
                    if (step >= 0 && step < fonts.length) {
                        const identity = named(media, "mediaIdentity")
                        const artwork = named(media, "mediaArtwork")
                        const seek = named(media, "mediaTimeline")
                        const controls = named(media, "mediaTransport")
                        const artBox = artwork.mapToItem(media, 0, 0)
                        const seekBox = seek.mapToItem(media, 0, 0)
                        const controlsBox = controls.mapToItem(media, 0, 0)
                        if (seekBox.x < artBox.x + artwork.width + 20 * media.s) throw new Error("seek overlaps artwork")
                        if (seek.width < media.width - artwork.width - 30 * media.s) throw new Error("seek does not fill control column")
                        if (seekBox.x + seek.width > media.width + 1) throw new Error("seek overflows column")
                        if (controlsBox.y + controls.height > media.height + 1 || controlsBox.x < 0 || controlsBox.x + controls.width > media.width + 1) throw new Error("controls overflow")
                        if (Math.abs(artwork.width - artwork.height) > 1) throw new Error("square artwork")
                    }
                    step++
                    if (step < fonts.length) Config.update({appearance:{fontScale:fonts[step], reduceMotion:true}})
                    else if (step === fonts.length) media.musicPresentation = false
                    else {
                        const artwork = named(media, "mediaArtwork")
                        if (Math.abs(artwork.height / artwork.width - 9 / 16) > 0.01) throw new Error("wide artwork")
                        console.log("PASS: column seek, artwork/control bounds, font scales and square/wide artwork")
                        Qt.quit()
                    }
                } catch (error) {
                    console.error("FAIL: media layout", error)
                    Qt.exit(1)
                }
            }
        }
    }
    Timer { interval: 5000; running: true; onTriggered: Qt.exit(1) }
}
