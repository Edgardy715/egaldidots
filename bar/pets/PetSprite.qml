import QtQuick
import "../Singletons"

/**
 * One atlas frame at an integer pixel scale. The strip is a single texture;
 * changing frame only moves it behind a clip, so animating never reloads or
 * re-decodes the image.
 */
Item {
    id: root

    property url source
    property int frame: 0
    property int frameCount: 1
    property int frameWidth: 20
    property int frameHeight: 20
    property int px: 2
    property bool mirrored: false
    property string palette: Config.pets.palette
    property bool missingVariant: false
    onSourceChanged: missingVariant = false

    width: frameWidth * px
    height: frameHeight * px
    clip: true

    Image {
        id: strip
        // A mirrored strip runs right to left, so frame i sits at the far end.
        x: -(root.mirrored ? root.frameCount - 1 - root.frame : root.frame) * root.width
        width: root.frameCount * root.width
        height: root.height
        source: root.missingVariant ? String(root.source).replace(/atlas-[^/]+\.png$/, "atlas.png") : root.source
        onStatusChanged: if (status === Image.Error && String(root.source).indexOf("/atlas-") !== -1) root.missingVariant = true
        sourceSize.width: root.frameCount * root.frameWidth
        sourceSize.height: root.frameHeight
        fillMode: Image.Stretch
        mirror: root.mirrored
        smooth: false
        mipmap: false
        asynchronous: false
        cache: true
    }
    Loader {
        active: root.palette === "matugen"
        sourceComponent: ShaderEffect {
            x: strip.x; width: strip.width; height: strip.height
            property var source: ShaderEffectSource { sourceItem: strip; hideSource: true; live: false }
            property color bodyColor: Theme.accent
            property color shadeColor: Theme.accentContainer
            property color lightColor: IslaPalette.colors.primary_fixed
            property color leafColor: Theme.accentAlt
            property color leafShadeColor: Theme.tertiaryContainer
            property color blushColor: Theme.error
            property color sparkColor: IslaPalette.colors.tertiary_fixed
            fragmentShader: Qt.resolvedUrl("shaders/pet_palette.frag.qsb")
        }
    }
}
