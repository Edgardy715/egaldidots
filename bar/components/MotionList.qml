import QtQuick
import "../Singletons"

// Native model transitions retain removed delegates and animate only live rows.
ListView {
    id: list
    // Keyboard travel glides to the row instead of jumping; the target comes
    // from ListView itself so delegate sizes and spacing stay authoritative.
    // Pass `fromY` when currentIndex is bound: ListView repositions on the index
    // change before this runs, so the glide must start from the earlier offset.
    function revealIndex(i, fromY) {
        if (i < 0 || i >= count) return
        if (Flags.reduceMotion || !visible) { scrollGlide.stop(); positionViewAtIndex(i, ListView.Contain); return }
        const from = fromY === undefined ? contentY : fromY
        scrollGlide.stop()
        positionViewAtIndex(i, ListView.Contain)
        const to = contentY
        contentY = from
        if (Math.abs(to - from) < 0.5) return
        scrollGlide.to = to
        scrollGlide.restart()
    }
    NumberAnimation {
        id: scrollGlide
        target: list; property: "contentY"
        duration: Motion.standardSmall
        easing.type: Motion.easeStandard
    }
    add: Transition {
        enabled: !Flags.reduceMotion
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.standardSmall; easing.type: Motion.easeStandard }
            NumberAnimation { property: "scale"; from: 0.975; to: 1; duration: Motion.standardSmall; easing.type: Motion.easeStandard }
        }
    }
    remove: Transition {
        enabled: !Flags.reduceMotion
        ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: Motion.fast; easing.type: Motion.easeStandard }
            NumberAnimation { property: "scale"; to: 0.975; duration: Motion.fast; easing.type: Motion.easeStandard }
        }
    }
    displaced: Transition {
        enabled: !Flags.reduceMotion
        NumberAnimation { properties: "x,y"; duration: Motion.standardSmall; easing.type: Motion.easeStandard }
    }
}
