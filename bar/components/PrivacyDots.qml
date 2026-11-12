import QtQuick
import "../Singletons"

/**
 * Isla · PrivacyDots. Indicadores de privacidad dentro del reposo de la pill,
 * con hueco propio tras la hora: una insignia circular con el glifo del
 * micrófono (naranja) o de la cámara (verde). Entran y salen con un muelle corto
 * y el hueco se abre con ellos, así nunca se pegan al reloj (el FrameAnimation de
 * SpringValue sólo corre mientras integra; en reposo no hay trabajo). Recibe datos
 * por propiedades; el nombre de la app sale al pasar el puntero y un clic pide
 * abrir Sonido.
 */
Item {
    id: root
    property real s: 1
    property bool micActive: false
    property bool camActive: false
    property string micApp: ""
    property string camApp: ""
    readonly property real badge: (plain ? 19 : 16) * s
    // plain: sólo el glifo, a la medida de los iconos de estado vecinos.
    property bool plain: false
    property real gap: 7 * s
    readonly property bool hovered: mic.hovered || cam.hovered
    readonly property string hoverText: mic.hovered && micActive ? I18n.tr("Micrófono: %1").arg(micApp)
        : cam.hovered && camActive ? I18n.tr("Cámara: %1").arg(camApp) : ""
    readonly property alias micDot: mic
    readonly property alias camDot: cam
    signal activated(string kind)

    implicitWidth: row.width
    implicitHeight: plain ? 26 * s : badge
    visible: mic.amount > 0.02 || cam.amount > 0.02 || micActive || camActive

    component Dot: Item {
        id: slot
        property string kind: "mic"
        property color tint: "#ff9f0a"
        property string glyph: Icons.iMic
        property bool on: false
        readonly property real amount: pop.value
        readonly property bool hovered: area.containsMouse
        // El hueco sigue al muelle sin rebasar: la pill crece y no vibra.
        width: Math.max(0, Math.min(1, amount)) * (root.badge + root.gap)
        height: root.badge
        Rectangle {
            objectName: slot.kind === "mic" ? "privacyMicShape" : "privacyCameraShape"
            x: root.gap
            anchors.verticalCenter: parent.verticalCenter
            width: root.badge
            height: root.badge
            radius: width / 2
            color: root.plain ? "transparent" : Qt.rgba(slot.tint.r, slot.tint.g, slot.tint.b, area.containsMouse ? 0.26 : 0.16)
            border.width: 0
            scale: slot.amount
            opacity: Math.min(1, slot.amount * 1.4)
            transformOrigin: Item.Center
            MaterialIcon {
                anchors.centerIn: parent
                iconName: slot.glyph
                color: slot.tint
                font.pixelSize: root.plain ? Theme.fontSizeBodyLg * root.s : 11 * root.s
            }
        }
        // Muelle corto con un ligero rebote al entrar.
        SpringValue {
            id: pop
            target: slot.on ? 1 : 0
            active: root.visible && (!Window.window || Window.window.visible)
            spring: Motion.strokeSpring.morph
            Component.onCompleted: snap()
        }
        MouseArea {
            id: area
            objectName: slot.kind === "mic" ? "privacyMicArea" : "privacyCameraArea"
            x: root.gap
            width: root.badge
            height: parent.height
            hoverEnabled: true
            enabled: slot.on
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activated(slot.kind)
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        Dot { id: mic; kind: "mic"; tint: "#ff9f0a"; glyph: Icons.iMic; on: root.micActive }
        Dot { id: cam; kind: "camera"; tint: "#30d158"; glyph: Icons.iCamera; on: root.camActive }
    }
}
