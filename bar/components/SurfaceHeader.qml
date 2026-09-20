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

    implicitHeight: 30 * s
    opacity: root.entered ? 1 : 0
    visible: opacity > 0.01
    transform: Translate {
        id: entryT
        y: root.entered ? 0 : 8 * s
        Behavior on y { Anim { type: Anim.EmphasizedIn } }
    }
    Behavior on opacity { Anim { type: Anim.EmphasizedIn } }

    Timer {
        interval: root.delay
        running: true
        repeat: false
        onTriggered: root.entered = true
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacingMd * s

        MaterialIcon {
            Layout.preferredWidth: root.iconName.length > 0 ? 22 * s : 0
            Layout.preferredHeight: 22 * s
            Layout.alignment: Qt.AlignVCenter
            iconName: root.iconName
            color: Theme.accent
            font.pixelSize: 20 * s
            visible: root.iconName.length > 0
            Accessible.ignored: true
        }

        ColumnLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter
            Text {
                text: root.title
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.hTitle * s
                font.weight: Font.Medium
                font.letterSpacing: -0.1 * s
            }
            Text {
                text: root.subtitle
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.hSmall * s
                font.letterSpacing: 0.15 * s
                visible: root.subtitle.length > 0
            }
        }

        Item { Layout.fillWidth: true }

        Loader {
            sourceComponent: root.trailing
            active: root.trailing !== null
        }
    }
}
