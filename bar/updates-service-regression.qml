import QtQuick
import QtTest
import Quickshell
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    property int exitCode: 0
    Timer { id: finish; interval: 150; onTriggered: Qt.exit(exitCode) }
    TestCase {
        when: Config.loaded
        function test_service() {
            try {
                SystemUpdates.initialize()
                wait(300)
                SystemUpdates.refresh()
                tryCompare(SystemUpdates,"busy",false,3000)
                compare(SystemUpdates.error,"")
                compare(SystemUpdates.count,3)
                const replay = Quickshell.env("ISLA_TEST_REPLAY") === "1"
                compare(Notifs.calls,replay ? 0 : 1)
                SystemUpdates.accept(SystemUpdates.result)
                compare(Notifs.calls,replay ? 0 : 1)
                if (!replay) {
                    let opened=0
                    SystemUpdates.openRequested.connect(() => opened++)
                    Notifs.actions[0].invoke()
                    compare(opened,1)
                    verify(SystemUpdates.portalRequested)
                }
                Config.update({updates:{notifications:false}})
                const changed=JSON.parse(JSON.stringify(SystemUpdates.result))
                changed.system.count=4
                SystemUpdates.accept(changed)
                compare(Notifs.calls,replay ? 0 : 1)
                SystemUpdates.install("shell")
                compare(SystemUpdates.busy,false) // Dirty working tree is rejected by service too.
                SystemUpdates.install("aur")
                compare(SystemUpdates.busy,false) // Source with a failed check cannot install.
                SystemUpdates.install("flatpak")
                compare(SystemUpdates.busy,false) // No updates, no terminal.
                SystemUpdates.install("system")
                compare(SystemUpdates.installSource,"system")
                tryVerify(() => SystemUpdates.progress.phase === "download",3000,"download phase streamed")
                verify(SystemUpdates.progress.cancellable)
                SystemUpdates.cancel()
                verify(SystemUpdates.cancelling)
                tryCompare(SystemUpdates,"busy",false,3000)
                compare(SystemUpdates.outcomes.system.result,"cancelled")
                compare(Notifs.calls,replay ? 0 : 1) // A cancel the person asked for is not announced.
                Config.update({updates:{notifications:true}})
                SystemUpdates.install("system")
                tryCompare(SystemUpdates,"busy",false,3000)
                compare(SystemUpdates.outcomes.system.result,"error")
                compare(SystemUpdates.outcomes.system.code,"partial")
                compare(Notifs.calls,replay ? 1 : 2) // Failures reach the person even with the portal closed.
                Config.update({updates:{notifications:false}})
                const previous=SystemUpdates.result
                SystemUpdates.refresh()
                tryCompare(SystemUpdates,"busy",false,3000)
                verify(SystemUpdates.error.length>0)
                compare(SystemUpdates.result,previous) // A failed recheck preserves known updates.
                SystemUpdates.refresh()
                tryCompare(SystemUpdates,"busy",false,3000)
                verify(SystemUpdates.error.startsWith("No se pudo consultar")) // Friendly copy, no trace.
                compare(SystemUpdates.result,previous)
                SystemUpdates.refresh()
                tryCompare(SystemUpdates,"busy",false,3000)
                compare(SystemUpdates.error,"")
                compare(SystemUpdates.count,3)
                SystemUpdates.install("invalid")
                compare(SystemUpdates.busy,false)
                console.log("PASS: Updates service, partial errors, dedupe, persistence, action and bridge")
                finish.start()
            } catch(error) { console.error("FAIL: Updates service",error,error.stack); exitCode=1; finish.start() }
        }
    }
}
