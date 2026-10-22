import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles:false
    Window {
        id:scene
        visible:true
        width:1040; height:720
        minimumWidth:1040; maximumWidth:1040
        minimumHeight:720; maximumHeight:720
        Rectangle {
            id:stage
            width:(IslandGeometry.wallpaperSurface.width-2*Theme.marginXl)*view.s
            height:640*view.s
            color:Theme.background
            WallpaperView {
                id:view
                anchors.fill:parent
                open:true
                mediaHas:true
                mediaTitle:"Una canción de prueba"
                mediaArtist:"Artista de prueba"
                mediaHasProgress:true
                mediaProgress:0.4
            }
        }
        TestCase {
            name:"WallpaperMediaHeader"
            when:scene.visible && Config.loaded
            function check(ok,message) {
                if(!ok) { console.error("FAIL:",message); Qt.exit(1) }
                verify(ok,message)
            }
            function test_header() {
                for(const scale of [1,0.8]) {
                    view.s=scale
                    for(const font of [1,1.5]) {
                        Config.update({appearance:{fontScale:font,reduceMotion:true}})
                        wait(250)
                        const media=findChild(view,"wallpaperHeaderMedia")
                        check(media && media.visible,"music visible at actual inset surface size")
                        check(media.width>32*scale,"metadata visible at standard surface width")
                        check(media.x>=0 && media.x+media.width<=view.width,"music within header")
                        const out=Quickshell.env("ISLA_TEST_OUTPUT")
                        if(out) grabImage(stage).save(out+"/wallpaper-media-"+scale+"-"+font+".png")
                        stage.width=640*scale; wait(100)
                        check(media.visible && media.width>=32*scale,"compact retains cover")
                        check(media.x>=0,"compact cover within header")
                        view.mediaHas=false; wait(50)
                        check(!media.visible,"no player hides summary")
                        view.mediaHas=true
                        stage.width=Qt.binding(()=>(IslandGeometry.wallpaperSurface.width-2*Theme.marginXl)*view.s)
                    }
                }
                console.log("PASS: wallpaper media header at actual margins, UI/font scales, narrow and no-player")
                Qt.quit()
            }
        }
    }
    Timer { interval:8000; running:true; onTriggered:Qt.exit(1) }
}
