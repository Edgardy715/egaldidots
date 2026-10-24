pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * The active pet package, read once per shell from its built atlas.json.
 * Packages are data only (see tools/petpack.py); the id is checked again here
 * so a hand-edited config can never turn into a path outside packs/.
 */
Singleton {
    id: root

    readonly property string packId: /^[a-z][a-z0-9_-]{0,31}$/.test(Config.pets.pack) ? Config.pets.pack : "mimo"
    readonly property string dir: Quickshell.shellDir + "/pets/packs/" + packId
    readonly property url atlas: checkedPalette === Config.pets.palette ? atlasFor(Config.pets.palette) : "file://" + dir + "/atlas.png"
    property string checkedPalette: ""
    property var data: null
    readonly property bool ready: data !== null

    function atlasFor(palette) {
        return "file://" + dir + "/" + (data && data.paletteVariants && data.paletteVariants.indexOf(palette) !== -1
            ? "atlas-" + palette + ".png" : "atlas.png")
    }

    function animation(name) {
        if (!data) return null
        return data.animations[name] || data.animations.idle
    }

    FileView {
        path: root.dir + "/atlas.json"
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(text())
                root.data = parsed.format === 1 && parsed.animations && parsed.animations.idle ? parsed : null
            } catch (error) {
                root.data = null
            }
            if (!root.data) console.warn("[Isla pets] invalid package " + root.packId)
        }
        onLoadFailed: {
            root.data = null
            console.warn("[Isla pets] package " + root.packId + " is not built")
        }
    }
    FileView {
        path: Config.pets.enabled && root.data && root.data.paletteVariants
              && root.data.paletteVariants.indexOf(Config.pets.palette) !== -1
              ? root.dir + "/atlas-" + Config.pets.palette + ".png" : ""
        printErrors: false
        onLoaded: root.checkedPalette = Config.pets.palette
        onLoadFailed: root.checkedPalette = ""
    }
}
