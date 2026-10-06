import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    id: test
    settings.watchFiles: false
    property int toggles: 0
    property int actions: 0
    property int nativeCalls: 0
    property int locks: 0
    property int unlocks: 0
    property var fakeAction: ({ text: "Open", invoke: function() { test.nativeCalls++ } })
    property var fakeNotification: ({
        summary: "Fixture notification", body: "Test body", appName: "Fixture",
        appIcon: "", image: "", urgency: 1, isCritical: false, bodyIsRich: false,
        timeStr: "ahora", actions: [test.fakeAction]
    })
    Window {
        id: scene
        visible: true
        width: 420; height: 520
        color: Theme.background
        NotifsView {
            id: view
            anchors.fill: parent
            s: 1.25
            count: 1
            dnd: false
            notifications: [test.fakeNotification]
            onToggleDndRequested: test.toggles++
            onActionRequested: (notification, action) => test.actions++
            onNotificationLockRequested: (notification, owner) => test.locks++
            onNotificationUnlockRequested: (notification, owner) => test.unlocks++
            iconPaths: new Map()
        }
        Timer { interval: 50; running: checks.finished; onTriggered: Qt.quit() }
        TestCase {
            id: checks
            name: "NotifsView"
            when: scene.visible
            property bool finished: false
            function test_mocked_notification_state() {
                wait(200)
                compare(view.count, 1)
                compare(test.locks, 1)
                const toggle = findChild(view, "dndToggle")
                verify(toggle !== null)
                mouseClick(toggle, toggle.width / 2, toggle.height / 2)
                compare(test.toggles, 1)
                const action = findChild(view, "notificationAction")
                verify(action !== null)
                mouseClick(action, action.width / 2, action.height / 2)
                compare(test.actions, 1)
                compare(test.nativeCalls, 0)
                console.log("PASS: notification view renders injected data and emits DND/action signals without invoking native actions")
                finished = true
            }
        }
    }
}
