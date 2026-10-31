import QtQuick
import QtTest
import Quickshell
import "Singletons"
ShellRoot {
    settings.watchFiles: false
    property int exitCode: 0
    Timer { id: finish; interval: 150; onTriggered: Qt.exit(exitCode) }
    TestCase {
        when: Notifs.loaded
        function test_localNotice() {
            try {
                const replay=Quickshell.env("ISLA_TEST_REPLAY")==="1"
                if (!replay) {
                    Notifs.dnd=true
                    Notifs.postLocal("Hay actualizaciones", "Prueba", [{identifier:"updates",text:"Ver actualizaciones",invoke:function(){SystemUpdates.open()}}], "isla:updates")
                    verify(!Notifs.list[0].popup,"DND suppresses popup")
                    Notifs.dnd=false; Notifs.centerOpen=true
                    Notifs.postLocal("Otra consulta", "Prueba", [], "isla:test")
                    verify(!Notifs.list[0].popup,"open center suppresses popup")
                    wait(1400)
                } else {
                    compare(Notifs.count,2)
                    const notice=Notifs.list.find(n=>n.notificationId==="isla:updates")
                    verify(!!notice)
                    verify(!notice.popup,"restored notice never toasts")
                    verify(!SystemUpdates.portalRequested)
                    notice.actions[0].invoke()
                    verify(SystemUpdates.portalRequested,"restored local action opens updates")
                }
                console.log("PASS: Updates notice, real Notifs persistence, DND and restored action")
                finish.start()
            } catch(error) { console.error("FAIL: Updates notice",error); exitCode=1; finish.start() }
        }
    }
}
