import QtQuick
import QtTest
import Quickshell
import "components"
import "windows"
import "Singletons"

ShellRoot {
    settings.watchFiles:false
    SurfaceRouter { id:router; focusedMonitorName:Quickshell.screens[0].name; reduceMotion:Flags.reduceMotion }
    IslandOverlay { id:overlay; modelData:Quickshell.screens[0]; router:router }
    TestCase {
        name:"MediaDockSurfaces"
        when:Config.loaded
        function check(ok,message) { if(!ok) { console.error("FAIL:",message); Qt.exit(1) }; verify(ok,message) }
        function test_routes() {
            const drop=findChild(overlay.contentItem,"islandMediaCompanion")
            check(drop !== null,"companion exists")
            drop.open=Qt.binding(()=>!overlay.layoutChanging && !overlay.compact && !overlay.mediaDocking
                && !overlay.launcherOpen && !overlay.mediaPanelOpen && !overlay.mediaPanelReturning)
            for(const reduced of [false,true]) {
                Config.update({appearance:{reduceMotion:reduced,barLayout:"split"}})
                tryVerify(()=>!overlay.compact && !overlay.layoutChanging,5000)
                for(const name of ["wallpaper","overview","launcher"]) {
                    tryVerify(()=>drop.phase !== "idle",5000)
                    router.toggleSurface("",name)
                    tryVerify(()=>overlay.surface===name && !overlay.mediaDocking,6000)
                    check(drop.phase==="idle","companion absorbed before "+name)
                    check(!drop.open,"companion stays absorbed in "+name)
                    router.close()
                    tryVerify(()=>!overlay.surfaceOpen,5000)
                    wait(600)
                }
            }
            console.log("PASS: wallpaper/overview/launcher absorb before opening and release on close, normal/reduced")
            Qt.quit()
        }
    }
    Timer { interval:30000; running:true; onTriggered:Qt.exit(1) }
}
