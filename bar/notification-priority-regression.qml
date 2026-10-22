import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    id: root
    settings.watchFiles: false
    property QtObject normal: QtObject { property string summary: "normal"; property bool popup: true; property bool closed: false; property bool isCritical: false }
    property QtObject critical: QtObject { property string summary: "critical"; property bool popup: true; property bool closed: false; property bool isCritical: true }
    Component { id: notification; NotifData {} }
    NotificationChoreography {
        id: flow
        popup: Notifs.activePopup
        deferInformational: true
        collapseDuration: 10; expandDuration: 10; holdDuration: 1200; restoreDuration: 10
        onAdvanceRequested: notification => Notifs.advancePopup(notification)
    }
    TestCase {
        when: Notifs.loaded
        function check(ok, message) { if (!ok) throw new Error(message) }
        function test_priority() {
            try {
                Notifs.list = [normal]
                Notifs._maybePromote()
                wait(80)
                check(flow.activeNotif === normal && flow.notifState === "hold", "normal is displayed")
                Notifs.list = [normal, critical]
                Notifs._maybePromote()
                wait(150)
                check(!normal.popup, "only the displayed normal is consumed")
                check(critical.popup && Notifs.activePopup === critical, "critical is retained")
                check(flow.activeNotif === critical && flow.notifState === "hold", "critical is actually displayed")
                flow.blocked = true
                const closing = notification.createObject(root, {summary: "closing", popup: true})
                Notifs.list = [closing]
                Notifs.activePopup = closing
                flow.blocked = false
                wait(80)
                check(flow.activeNotif === closing, "closable notification is shown")
                closing.close()
                wait(1)
                Notifs.list = [critical]
                Notifs._maybePromote()
                wait(150)
                check(critical.popup && flow.activeNotif === critical, "destroyed identity cannot consume replacement")
                flow.blocked = true
                Notifs.list = []
                Notifs.activePopup = null
                console.log("PASS: critical replaces normal, including destruction during exit, without early consumption")
                Qt.quit()
            } catch (error) { console.error("FAIL: " + error); Qt.exit(1) }
        }
    }
}
