import QtQuick
import "../Singletons"

// Native model transitions retain removed delegates and animate only live rows.
ListView {
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
