import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "components"
ShellRoot {
    settings.watchFiles: false
    Window {
        id: window
        visible: true; width: 800; height: 700
        color: Theme.background
        SessionView { id: session; width: 660; height: 470; open: true; onActionRequested: checks.actions++ }
        MotionButton {
            id: control
            x: 30; y: 520; width: 60; height: 60
            contentItem: MaterialIcon { id: icon; iconName: "wifi"; hovered: false; interaction: control.interaction }
        }
        MotionButton { id: next; x: 110; y: 520; width: 60; height: 60; text: "Tab" }
        TestCase {
            id: checks
            when: Config.loaded && window.visible
            property bool finished: false
            property int actions: 0
            function assert(ok, message) { if (!ok) throw new Error(message) }
            function symbol(item) { return findChild(item,"animatedSymbol") }
            function test_keyboard() {
                try {
                    Config.update({appearance:{reduceMotion:false}})
                    wait(700)
                    session.forceActiveFocus()
                    for (let n = 0; n < 4; n++) {
                        keyClick(Qt.Key_Right)
                        const tile = findChild(session,"sessionAction" + session.focused)
                        if (tile) {
                            const gesture = symbol(findChild(session,"sessionIcon" + session.focused))
                            assert(tile.highlighted && tile.interaction.engaged, "arrow selection engages motion")
                            assert(gesture.hovered && gesture.animating, "arrow plays icon gesture")
                        }
                        wait(50)
                    }
                    assert(actions === 0, "navigation never executes power actions")
                    control.forceActiveFocus()
                    assert(symbol(icon).hovered && symbol(icon).animating, "explicit hover override keeps keyboard gesture")
                    keyClick(Qt.Key_Tab)
                    assert(next.activeFocus, "Tab advances focus")
                    keyClick(Qt.Key_Tab, Qt.ShiftModifier)
                    assert(control.activeFocus && symbol(icon).hovered && symbol(icon).animating, "Shift Tab replays gesture")
                    Config.update({appearance:{reduceMotion:true}})
                    wait(30)
                    assert(!symbol(icon).animating, "reduced motion stops gesture")
                    session.forceActiveFocus(); keyClick(Qt.Key_Right)
                    const selected = findChild(session,"sessionIcon" + session.focused)
                    if (selected) assert(!symbol(selected).animating, "reduced power navigation stays still")
                    assert(actions === 0, "no power actions")
                    console.log("PASS: arrow selection, Tab/Shift Tab icon gestures, hover override, reduced motion and no power actions")
                } catch(error) { console.error("FAIL: keyboard icons",error.message) }
                finished = true
            }
        }
        Timer { interval: 100; running: checks.finished; onTriggered: Qt.quit() }
    }
}
