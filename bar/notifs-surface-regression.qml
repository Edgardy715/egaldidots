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
    property int closes: 0
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
            onCloseRequested: notification => test.closes++
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
                const close = findChild(view, "notificationClose")
                verify(close !== null)
                const card = findChild(view, "historyCard")
                verify(card !== null)
                const start = card.mapToItem(view, card.width * 0.3, card.height / 2)
                mousePress(view, start.x, start.y)
                for (let i = 1; i <= 8; i++) mouseMove(view, start.x + i * 8, start.y, 40)
                verify(card.swipeX > 20, "card follows the pointer horizontally")
                mouseRelease(view, start.x + 64, start.y, Qt.LeftButton, Qt.NoModifier, 40)
                tryCompare(card, "swipeX", 0, 1500)
                compare(test.closes, 0)
                mouseClick(close, close.width / 2, close.height / 2)
                tryCompare(test, "closes", 1, 1500)
                console.log("PASS: history card springs back from a short swipe and closes from its button")
                finished = true
            }
        }
    }
}
