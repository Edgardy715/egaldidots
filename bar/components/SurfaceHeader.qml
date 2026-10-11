pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../Singletons"
import "../"

/**
 * Isla · SurfaceHeader. Header unificado de surfaces (reemplaza los ~7 headers
 * duplicados): título DemiBold + spacer + trailing (chip de contador, texto o
 * icono). Con entrada animada sutil (opacity + translate) cuando `entered`.
 *
 * Props:
 *   title    — texto principal
 *   subtitle — texto pequeño debajo (opcional)
 *   s        — escala del host
 *   entered  — gate de la animación de entrada (surfaces: se enciende post-morph)
 *   delay    — ms de retraso del stagger
 *   trailing — componente opcional (chip/icono) a la derecha
 */
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string iconName: ""
    property real s: 1
    property bool entered: true
    property int delay: 0
    property Component trailing: null

    implicitHeight: Math.max(32 * root.s, labels.implicitHeight)
    opacity: root.entered ? 1 : 0
    visible: opacity > 0.01
    transform: Translate {
        id: entryT
        y: root.entered ? 0 : 8 * root.s
        Behavior on y { enabled: !Flags.reduceMotion; Anim { type: Anim.EmphasizedIn } }
    }
    Behavior on opacity { enabled: !Flags.reduceMotion; Anim { type: Anim.EmphasizedIn } }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacingMd * root.s

        MaterialIcon {
            Layout.preferredWidth: root.iconName.length > 0 ? 22 * root.s : 0
            Layout.preferredHeight: 22 * root.s
            Layout.alignment: Qt.AlignVCenter
            iconName: root.iconName
            color: Theme.accent
            font.pixelSize: 20 * root.s
            visible: root.iconName.length > 0
            Accessible.ignored: true
        }

        ColumnLayout {
            id: labels
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: Theme.spacingXs * root.s
            Layout.alignment: Qt.AlignVCenter
            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeTitleLg * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: -0.1 * root.s
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: root.subtitle
                color: Theme.iconSecondary
                font.family: Theme.font
                font.pixelSize: Theme.hSmall * root.s
                font.letterSpacing: 0.15 * root.s
                visible: root.subtitle.length > 0
                elide: Text.ElideRight
            }
        }

        Loader {
            sourceComponent: root.trailing
            active: root.trailing !== null
        }
    }
}
