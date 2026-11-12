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
        // A burst arrives newest-first in list; toasts still play in arrival order.
        const first = Qt.createQmlObject('import QtQml; QtObject { property bool popup: true; property bool closed: false; property bool isCritical: false }', root)
        const second = Qt.createQmlObject('import QtQml; QtObject { property bool popup: true; property bool closed: false; property bool isCritical: false }', root)
        const third = Qt.createQmlObject('import QtQml; QtObject { property bool popup: true; property bool closed: false; property bool isCritical: false }', root)
        Notifs.list = [third, second, first]
        Notifs._maybePromote()
        check(Notifs.activePopup === first, "burst starts with the oldest")
        Notifs.advancePopup(first)
        check(Notifs.activePopup === second, "burst continues in arrival order")
        // Two criticals in one burst: the older one goes first.
        const crit1 = Qt.createQmlObject('import QtQml; QtObject { property bool popup: true; property bool closed: false; property bool isCritical: true }', root)
        const crit2 = Qt.createQmlObject('import QtQml; QtObject { property bool popup: true; property bool closed: false; property bool isCritical: true }', root)
        const normalBefore = Qt.createQmlObject('import QtQml; QtObject { property bool popup: true; property bool closed: false; property bool isCritical: false }', root)
        Notifs.list = [crit2, crit1, normalBefore]
        Notifs.activePopup = normalBefore
        Notifs._maybePromote()
        check(Notifs.activePopup === crit1, "older critical wins over newer critical")
        Notifs.advancePopup(crit1)
        check(Notifs.activePopup === crit2, "second critical follows")
        Notifs.list = []
        Notifs._maybePromote()
        console.log("PASS: informational deferral, critical priority, auth, expiry, queue promotion and burst order")
        Qt.quit()
    } }
}
