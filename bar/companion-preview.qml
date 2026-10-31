import QtQuick
import Quickshell
import "Singletons"
import "components"

// Every expression and moment of the island's companion, enlarged.
//   qs -p bar/companion-preview.qml          ISLA_COMPANION_SCALE=1 shows real size.
ShellRoot {
    settings.watchFiles: false
    Window {
        id: win
        width: 980; height: 900
        visible: true
        title: "Isla · compañero · PROTOTIPO"
        color: Theme.surface
        readonly property real k: Number(Quickshell.env("ISLA_COMPANION_SCALE") || 3)

        component Card: Rectangle {
            id: card
            property string pose: ""
            property bool physical: false
            property string caption
            property alias face: face
            property string mood: "rest"
            property bool asleep: false
            property bool sleepy: false
            property bool engaged: false
            property real lookX: 0
            width: 210; height: 130
            radius: 16
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.cardTop }
                GradientStop { position: 1; color: Theme.cardBot }
            }
            border.width: 1; border.color: Theme.border
            IslandCompanion {
                id: face
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -10
                s: win.k
                visible: !card.physical
                mood: card.mood
                asleep: card.asleep
                sleepy: card.sleepy
                engaged: card.engaged
                lookX: card.lookX
            }
            IslandActivityChip {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -10
                visible: card.physical
                s: win.k
                coreH: 38 * s
            }
            MotionArea {
                visible: !card.physical
                anchors.fill: parent
                accessibleName: card.caption + qsTr(": reproducir gesto")
                feedbackEnabled: false
                onClicked: card.pose ? face.play(card.pose) : face.interact()
            }
            Timer { interval: 800; running: card.pose.length > 0; onTriggered: face.play(card.pose) }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                text: card.caption
                color: Qt.alpha(Theme.foreground, 0.7)
                font.family: Flags.fontFamily; font.pixelSize: 12
            }
        }
        component Btn: MotionButton {
            id: btn
            property string label
            signal tapped()
            implicitWidth: t.implicitWidth + 24; implicitHeight: 34
            onClicked: tapped()
            background: Rectangle { radius: 12; color: Qt.alpha(Theme.foreground, btn.hovered ? 0.12 : 0.07); border.width: btn.activeFocus ? 1 : 0; border.color: Theme.accent }
            contentItem: Text { id: t; text: btn.label; color: Theme.foreground; font.family: Flags.fontFamily; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        }
        Text {
            x: 20; y: 22
            text: "PROTOTIPO — no es la implementación final"
            color: Theme.foreground; font.family: Flags.fontFamily; font.pixelSize: 23; font.weight: Font.DemiBold
        }
        Text {
            x: 20; y: 59
            text: "Tranquilo, atento, un poco curioso. Clic: jugar · rozar la cara en la barra: acariciar."
            color: Qt.alpha(Theme.foreground, 0.76); font.family: Flags.fontFamily; font.pixelSize: 13
        }

        Grid {
            id: grid
            x: 20; y: 100
            columns: 4; spacing: 18
            Card { id: rest; caption: "reposo" }
            Card { caption: "te mira (hover)"; engaged: true; lookX: 0.8 }
            Card { caption: "enfoque en curso"; mood: "working" }
            Card { caption: "enfoque en pausa"; mood: "paused" }
            Card { caption: "atención"; mood: "attention" }
            Card { caption: "confirmado / terminado"; mood: "finished" }
            Card { caption: "de noche"; sleepy: true }
            Card { caption: "dormido (te fuiste)"; asleep: true }
            Card { caption: "guiño · confirmación"; pose: "wink" }
            Card { caption: "curiosidad · clic"; pose: "curious" }
            Card { caption: "mirada traviesa · clic"; pose: "roll" }
            Card { caption: "contener estornudo · cuarto clic"; pose: "holdSneeze" }
            Card { caption: "luciérnaga · quinto clic"; pose: "firefly" }
            Card { caption: "bostezo · noche / ausencia"; pose: "doze" }
            Card { caption: "contento · clics repetidos"; pose: "squint" }
            Card { id: wake; caption: "estirarse · volver"; asleep: true; Timer { interval: 800; running: true; onTriggered: wake.asleep = false } }
            Card { caption: "rozar lento / rápido · probar"; physical: true }
        }
        Row {
            x: 20; anchors.bottom: parent.bottom; anchors.bottomMargin: 18
            spacing: 8
            Btn { label: "Asentir (confirmación)"; onTapped: rest.face.nod() }
            Btn { label: "Celebrar (sesión completada)"; onTapped: rest.face.celebrate() }
            Btn { label: "Empieza la música"; onTapped: { rest.face.listening = false; rest.face.listening = true } }
            Btn { label: "Jugar (clic)"; onTapped: rest.face.interact() }
            Btn { label: "Dormir / volver"; onTapped: rest.asleep = !rest.asleep }
        }
        // ISLA_COMPANION_TOUR=1 plays the moments on the first card for captures.
        SequentialAnimation {
            id: tour
            PauseAnimation { duration: 600 }
            ScriptAction { script: rest.face.nod() }
            PauseAnimation { duration: 900 }
            ScriptAction { script: rest.face.celebrate() }
            PauseAnimation { duration: 1400 }
            ScriptAction { script: rest.face.listening = true }
            PauseAnimation { duration: 2200 }
            ScriptAction { script: rest.face.pat() }
            PauseAnimation { duration: 1800 }
            ScriptAction { script: rest.asleep = true }
            PauseAnimation { duration: 1400 }
            ScriptAction { script: rest.asleep = false }
        }
        // A finite native capture tour; production never starts this fixture.
        SequentialAnimation {
            id: interactionTour
            PauseAnimation { duration: 800 }
            ScriptAction { script: rest.face.approachPointer(true) }
            PauseAnimation { duration: 1050 }
            ScriptAction { script: console.log("COMPANION_CAPTURE curiosity") }
            PauseAnimation { duration: 400 }
            ScriptAction { script: rest.face.stroke(120, 1, 0.7) }
            PauseAnimation { duration: 100 }
            ScriptAction { script: rest.face.stroke(120, -1, -0.7) }
            PauseAnimation { duration: 100 }
            ScriptAction { script: rest.face.stroke(120, 1, 0.7) }
            PauseAnimation { duration: 100 }
            ScriptAction { script: console.log("COMPANION_CAPTURE stroke") }
            PauseAnimation { duration: 350 }
            ScriptAction { script: rest.face.pat() }
            PauseAnimation { duration: 350 }
            ScriptAction { script: console.log("COMPANION_CAPTURE affection") }
            PauseAnimation { duration: 1700 }
            ScriptAction { script: rest.face.approachPointer(false) }
            PauseAnimation { duration: 900 }
            ScriptAction { script: rest.face.approachPointer(true) }
            PauseAnimation { duration: 200 }
            ScriptAction { script: console.log("COMPANION_CAPTURE return") }
            PauseAnimation { duration: 1700 }
            ScriptAction { script: rest.face.wakeAfter(90000) }
            PauseAnimation { duration: 220 }
            ScriptAction { script: console.log("COMPANION_CAPTURE stretch") }
            PauseAnimation { duration: 1000 }
            ScriptAction { script: rest.face.play("doze") }
            PauseAnimation { duration: 450 }
            ScriptAction { script: console.log("COMPANION_CAPTURE doze") }
            PauseAnimation { duration: 2200 }
            ScriptAction { script: console.log("COMPANION_CAPTURE rest") }
        }
        Component.onCompleted: {
            if (Quickshell.env("ISLA_COMPANION_TOUR") === "1") tour.start()
            else if (Quickshell.env("ISLA_COMPANION_TOUR") === "2") interactionTour.start()
        }
    }
}
