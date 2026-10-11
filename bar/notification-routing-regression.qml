import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        visible: true
        width: 1000; height: 700
        Pill { id: pill; screenName: "notification-route-test"; notificationsEnabled: false }
        TestCase {
            name: "NotificationRouteOwnership"
            when: Config.loaded
            function test_loaderCannotOverwriteRoute() {
                Config.update({appearance: {reduceMotion: false}})
                Notifs.centerOpen = true
                pill.surface = "notifs"
                tryVerify(() => pill.surfaceItem !== null, 3000)
                pill.surface = "mixer"
                wait(700)
                verify(Notifs.centerOpen, "old panel destruction cannot overwrite current owner")
                Notifs.centerOpen = false
                pill.surface = "notifs"
                wait(20)
                pill.surface = ""
                wait(700)
                verify(!Notifs.centerOpen, "late panel load cannot resurrect closed route")
                console.log("PASS: notification center state survives stale loader construction/destruction")
            }
        }
    }
}
