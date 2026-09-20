import QtQuick
import QtQuick.Layouts
import "../Singletons"

/**
 * Isla · HintKbd. Mini-keycap estilo mostrado en el footer del launcher: un
 * rectángulo redondeado con el glyph (↑↓ ↵ esc etc) y un label tenue ("abrir",
 * "navegar"). Mismo tono que el footer de macOS Spotlight / windows power toys.
 * Color: dim (foreground oscuro) para el keycap, dim+0.7 para el label — así
 * no compite con el searchBox/listView.
 */
Item {
    id: root
    property string glyph: ""
    property string label: ""
    property real s: 1
    implicitHeight: Math.max(keycap.height, labelTxt.height)
    implicitWidth: keycap.width + (label.length ? keycap.anchors.rightMargin + labelTxt.width : 0)

    Rectangle {
        id: keycap
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(20 * root.s, glyphTxt.implicitWidth + 10 * root.s)
        height: 18 * root.s
        radius: Theme.radiusXs * root.s
        color: Qt.alpha(Theme.foreground, Theme.alphaFaint)
        border.color: Qt.alpha(Theme.foreground, Theme.alphaGlow)
        border.width: Theme.borderHairline

        Text {
            id: glyphTxt
            anchors.centerIn: parent
            text: root.glyph
            color: Theme.dim
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall * root.s
            font.capitalization: Font.AllUppercase
        }
    }

    Text {
        id: labelTxt
        anchors.left: keycap.right
        anchors.leftMargin: 4 * root.s
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fontSizeSmall * root.s
        opacity: 0.85
    }
}
