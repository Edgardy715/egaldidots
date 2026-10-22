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
    NotificationChoreography {
        id: flow
        deferInformational: true
        collapseDuration: 20; expandDuration: 20; holdDuration: 25; restoreDuration: 40
    }
    Timer { interval: 30; running: true; onTriggered: {
        function check(ok, message) { if (!ok) { console.error("FAIL: " + message); Qt.exit(1) } }
        flow.surfaceOpen = true
        flow.popup = normal
        check(flow.notifState === "idle" && !flow.surfaceNotifSuspended, "normal preserves editing")
        flow.surfaceOpen = false
        check(flow.notifAnimating, "deferred popup resumes on close")
        flow.blocked = true
        flow.popup = null
        flow.surfaceOpen = true
        flow.blocked = false
        flow.popup = critical
        check(flow.notifAnimating && flow.surfaceNotifSuspended, "critical interrupts")
        flow.blocked = true
        flow.popup = normal
        check(!flow.notifAnimating, "auth keeps priority")
        flow.blocked = false
        check(!flow.notifAnimating, "normal stays deferred after auth")
        flow.popup = null
        flow.surfaceOpen = false
        check(!flow.notifAnimating, "expired deferred popup is not replayed")
        Notifs.list = [normal, critical]
        Notifs.activePopup = normal
        Notifs._maybePromote()
        check(Notifs.activePopup === critical, "critical bypasses normal in queue")
        Notifs.list = [normal]
        Notifs.activePopup = critical
        critical.popup = false
        Notifs._maybePromote()
        check(Notifs.activePopup === normal, "expired active releases queue")
        Notifs.list = []
        Notifs._maybePromote()
        check(Notifs.activePopup === null, "empty queue clears active")
        console.log("PASS: informational deferral, critical priority, auth, expiry and queue promotion")
        Qt.quit()
    } }
}
