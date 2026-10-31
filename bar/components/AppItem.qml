import QtQuick
import Quickshell
import Quickshell.Widgets
import "../Singletons"
import "../"

/** Delegate de la lista del launcher con icono, nombre, descripción y favorito.
 * Basado en caelestia AppItem.qml.
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

    // Rows reveal once when created; a reused delegate keeps its place while
    // the query narrows, so typing never re-fades the whole list.
    Component.onCompleted: revealTimer.start()

    Timer {
        id: revealTimer
        interval: root.revealDelay
        repeat: false
        onTriggered: root.revealed = true
    }

    opacity: root.revealed ? 1 : 0
    Behavior on opacity { Anim { type: Anim.EmphasizedIn } }

    // se marca willingly porque al colapsar (close-on-launch) el contenido
    // puede disparar delegates sin padre; el opacidad y el hit-test están OK
    // con MouseArea dentro. Click → Apps.launch.
    MotionArea {
        id: hoverArea
        enabled: root.revealed
        accessibleName: root.modelData ? root.modelData.name : ""
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: root.pressed = true
        onReleased: root.pressed = false
        onCanceled: root.pressed = false
        onClicked: root.launched()
    }

    Item {
        anchors.fill: parent
        scale: root.revealed ? hoverArea.motion.visualScale : 0.97
        transform: Translate {
            y: root.revealed || Flags.reduceMotion ? 0 : 8 * root.s
            Behavior on y { Anim { type: Anim.EmphasizedIn } }
        }

        // wash de hover (nivel caelestia): relleno acento tenue que respira
        // + translate del contenido 2px al hover (micro-interacción)
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusLg * root.s
            // Selection is painted by the list's sliding highlight; rows own hover only.
            color: !root.selected && hoverArea.containsMouse ? Qt.alpha(Theme.accent, Theme.alphaWash) : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
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
                scale: root.selected || hoverArea.containsMouse ? 1.025 : 1
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
                    color: Theme.iconSecondary
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
                Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                Text {
                    anchors.centerIn: parent
                    text: String(root.resultIndex)
                    color: root.selected ? Theme.background : Theme.iconSecondary
                    Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeSmall * root.s
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
