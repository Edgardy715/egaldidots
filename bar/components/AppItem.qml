import QtQuick
import Quickshell
import Quickshell.Widgets
import "../Singletons"
import "../"

/**
 * Isla · AppItem. Delegate del LauncherSurface. Molde caelestia AppItem.qml
 * adaptado a la Isla: icon (IconImage) + name + comment, con highlight/press
 * heredado del ListView (sin separar StateLayer para no añadir dependencias).
 *
 * Item de 64px (escalado por s del surface), fills width del listado. Mostrar
 * icono "favorite" a la derecha si el app.id matchea la lista favouriteApps.
 * Click = Apps.launch(modelData) + cierra el surface.
 */
Item {
    id: root
    required property var modelData
    required property int index
    property real s: 1
    property int revealDelay: 0
    property bool revealed: false
    property bool pressed: false
    readonly property int resultIndex: index + 1
    readonly property bool selected: ListView.isCurrentItem
    signal launched()
    implicitHeight: 72 * s
    implicitWidth: parent ? parent.width : 0

    Component.onCompleted: revealTimer.start()
    onModelDataChanged: {
        revealed = false
        revealTimer.restart()
    }

    Timer {
        id: revealTimer
        interval: root.revealDelay
        repeat: false
        onTriggered: root.revealed = true
    }

    opacity: root.revealed ? 1 : 0
    scale: root.revealed ? (root.pressed ? 0.985 : 1) : 0.97
    transformOrigin: Item.Center
    Behavior on opacity { Anim { type: Anim.EmphasizedIn } }
    Behavior on scale { Anim { type: Anim.FastEffects } }

    transform: Translate {
        y: root.revealed ? 0 : 8 * root.s
        Behavior on y { Anim { type: Anim.EmphasizedIn } }
    }

    // se marca willingly porque al colapsar (close-on-launch) el contenido
    // puede disparar delegates sin padre; el opacidad y el hit-test están OK
    // con MouseArea dentro. Click → Apps.launch.
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: root.pressed = true
        onReleased: root.pressed = false
        onCanceled: root.pressed = false
        onClicked: root.launched()
    }

    // wash de hover (nivel caelestia): relleno acento tenue que respira
    // + translate del contenido 2px al hover (micro-interacción)
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg * root.s
        color: root.selected
            ? Qt.alpha(Theme.accent, Theme.alphaGlow)
            : (hoverArea.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaWash) : "transparent")
        Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.borderHairline * root.s
        radius: width / 2
        color: Theme.accent
        opacity: root.selected ? 1 : 0
        scale: root.selected ? 1 : 0.4
        Behavior on opacity { Anim { type: Anim.FastEffects } }
        Behavior on scale { Anim { type: Anim.FastEffects } }
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: 14 * root.s
        anchors.rightMargin: 14 * root.s
        anchors.topMargin: 7 * root.s
        anchors.bottomMargin: 7 * root.s
        transform: Translate {
            id: microT
            x: hoverArea.containsMouse ? 2 * root.s : 0
            Behavior on x { Anim { type: Anim.FastEffects } }
        }
        clip: false

        IconImage {
            id: icon
            asynchronous: true
            // Si modelData es null (delegate en incubación) o la app no
            // tiene Icon= (entry.icon === ""), source queda vacío.
            source: Quickshell.iconPath(root.modelData ? root.modelData.icon : "", "app-no-icon")
            implicitSize: parent.height * 0.85
            anchors.verticalCenter: parent.verticalCenter
            scale: root.selected || hoverArea.containsMouse ? 1.06 : 1
            Behavior on scale { Anim { type: Anim.FastEffects } }
        }
        Item {
            anchors.left: icon.right
            anchors.leftMargin: 12 * root.s
            anchors.right: parent.right
            anchors.rightMargin: (indexBadge.visible ? indexBadge.width + 8 * root.s : 0)
                + favouriteIcon.width
            anchors.verticalCenter: icon.verticalCenter

            implicitWidth: parent.width - icon.width - favouriteIcon.width
            implicitHeight: nameTxt.implicitHeight + commentTxt.implicitHeight + 2 * root.s

            Text {
                id: nameTxt
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                text: root.modelData ? root.modelData.name : ""
                color: root.selected ? Theme.foreground : Theme.iconSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeBodyLg * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Text {
                id: commentTxt
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: nameTxt.bottom
                anchors.topMargin: 1 * root.s
                text: root.modelData
                    ? (root.modelData.comment || root.modelData.genericName || "")
                    : ""
                color: root.selected ? Qt.alpha(Theme.foreground, Theme.alphaIconSec) : Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall * root.s
                elide: Text.ElideRight
            }
        }

        // favourite star (derecha), si el app.id matchea favouriteApps
        Loader {
            id: favouriteIcon
            asynchronous: true
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: indexBadge.visible ? indexBadge.left : parent.right
            anchors.rightMargin: indexBadge.visible ? 8 * root.s : 0
            active: !!(root.modelData && Apps._matchesAny(root.modelData.id, Apps.favouriteApps))
            sourceComponent: MaterialIcon {
                iconName: Icons.iStar
                color: Theme.accent
                font.pixelSize: Theme.fontSizeTitle * root.s
            }
        }

        Rectangle {
            id: indexBadge
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 28 * root.s
            height: 28 * root.s
            radius: 8 * root.s
            visible: !!root.modelData && root.resultIndex >= 1 && root.resultIndex <= 9
            color: root.selected
                ? Qt.alpha(Theme.foreground, Theme.alphaIconOnAcc)
                : Qt.alpha(Theme.foreground, Theme.alphaGhost)
            border.width: Theme.borderHairline
            border.color: root.selected
                ? Qt.alpha(Theme.foreground, Theme.alphaSoft)
                : Qt.alpha(Theme.foreground, Theme.alphaHair)
            opacity: root.selected ? 0.9 : 0.72
            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Motion.fast } }

            Text {
                anchors.centerIn: parent
                text: String(root.resultIndex)
                color: root.selected ? Theme.foreground : Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall * root.s
                font.weight: Font.DemiBold
            }
        }
    }
}
