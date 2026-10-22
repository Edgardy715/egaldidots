import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: scene
        visible:true
        width:900; height:760
        minimumWidth:900; maximumWidth:900
        minimumHeight:760; maximumHeight:760
        Rectangle { anchors.fill:parent; color:Theme.background }
        Pill {
            id:pill
            x:(scene.width-width)/2; y:24
            notificationsEnabled:false
            screenName:"connectivity-fixture"
        }
        TestCase {
            name:"ConnectivityHost"
            when:scene.visible && Config.loaded
            function shot(name) {
                const dir=Quickshell.env("ISLA_TEST_OUTPUT")
                if(dir) grabImage(scene.contentItem).save(dir+"/"+name+".png")
            }
            function test_host() {
                for(const reduced of [false,true]) {
                    verify(Config.update({appearance:{reduceMotion:reduced}}).ok)
                    for(const compact of [false,true]) {
                        pill.restHeight=compact ? IslandGeometry.compactRestHeight : IslandGeometry.restHeight
                        pill.surface="connectivity"
                        tryVerify(()=>pill.surfaceItem && pill.surfaceItem.open,4000)
                        wait(650)
                        console.log("HOST",pill.width,pill.height,pill.targetW,pill.targetH)
                        verify(pill.surfaceItem !== null)
                        verify(pill.surfaceItem.open)
                        verify(Math.abs(pill.width-IslandGeometry.connectivitySurface.width)<1)
                        verify(Math.abs(pill.height-IslandGeometry.connectivitySurface.height)<1)
                        shot("host-"+(compact ? "compact" : "split")+(reduced ? "-reduced" : ""))
                        pill.surface=""; wait(90)
                        pill.surface="connectivity"; wait(650)
                        verify(pill.surfaceItem && pill.surfaceItem.open)
                        pill.surface=""; wait(700)
                        tryVerify(()=>!pill.surfaceItem,3000)
                    }
                }
                console.log("PASS: connectivity host geometry, split/compact, interrupted reopen, unload and reduced motion")
                Qt.quit()
            }
        }
    }
    Timer { interval:20000; running:true; onTriggered:Qt.exit(1) }
}
