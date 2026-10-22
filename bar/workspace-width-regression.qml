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
        width:680; height:130
        minimumWidth:680; maximumWidth:680
        minimumHeight:130; maximumHeight:130
        Rectangle { anchors.fill:parent; color:Theme.background }
        TopWorkspaceRail { id:rail; x:24; y:24; availableWidth:600 }
        TestCase {
            name:"WorkspaceWidth"
            when:scene.visible && Config.loaded
            function check(ok,message) { if(!ok) { console.error("FAIL:",message); Qt.exit(1) }; verify(ok,message) }
            function settle() { tryVerify(()=>Math.abs(rail.width-rail.targetWidth)<0.01,2000) }
            function capture(name) {
                const out=Quickshell.env("ISLA_TEST_OUTPUT")
                if(out) grabImage(scene.contentItem).save(out+"/"+name+".png")
            }
            function test_growth() {
                Config.update({appearance:{reduceMotion:false}})
                const lens=findChild(rail,"workspaceLens")
                for(const integrated of [false,true]) {
                    rail.integrated=integrated; rail.count=5; rail.activeId=5
                    settle(); wait(400)
                    const start=rail.width
                    capture("rail-"+integrated+"-start")
                    rail.count=6; rail.activeId=6
                    check(Math.abs(rail.width-start)<1,"growth starts from current width")
                    wait(70)
                    check(rail.width>start && rail.width<rail.targetWidth,"growth has intermediate width")
                    check(lens.x+lens.width<=rail.width+1,"selection stays inside expanding rail")
                    capture("rail-"+integrated+"-mid")
                    settle(); wait(400)
                    capture("rail-"+integrated+"-end")
                    rail.count=9; rail.activeId=9; wait(60)
                    const current=rail.width
                    rail.count=5; rail.activeId=5
                    check(Math.abs(rail.width-current)<1,"reverse preserves current width")
                    wait(40); rail.count=8; rail.activeId=8
                    settle()
                    rail.count=5; rail.activeId=5; wait(60)
                    Config.update({appearance:{reduceMotion:true}})
                    check(Math.abs(rail.width-rail.targetWidth)<0.01,"reduced finishes in-flight resize")
                    rail.count=7; rail.activeId=7
                    check(Math.abs(rail.width-rail.targetWidth)<0.01,"reduced resize is immediate")
                    Config.update({appearance:{reduceMotion:false}})
                    rail.count=5; rail.activeId=5; wait(50)
                    rail.visible=false
                    check(Math.abs(rail.width-rail.targetWidth)<0.01,"hidden resize settles")
                    rail.visible=Qt.binding(()=>rail.fits)
                    rail.animateChanges=false; rail.count=6
                    check(Math.abs(rail.width-rail.targetWidth)<0.01,"disabled animation snaps")
                    rail.animateChanges=true
                }
                console.log("PASS: workspace rail 5-to-6 growth, lens bounds, reversal, compact/split, reduced, hidden and disabled")
                Qt.quit()
            }
        }
    }
    Timer { interval:18000; running:true; onTriggered:Qt.exit(1) }
}
