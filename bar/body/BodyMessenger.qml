import QtQuick
import QtQuick.Controls
import Quickshell
import "../Singletons"
import "../components"
import "BodyDropBrain.js" as Drop
import "BodyFile.js" as File

// Per-screen composition owns the engine, its clock, and Recording.saved wiring.
Item {
    id: root
    required property var engine
    required property var bodyShader
    property Item visualParent: root
    property Item hitParent: root
    property point bodyOrigin: Qt.point(0, 0)
    property bool acceptFiles: true
    property bool reduceMotion: false
    property string filePath: ""
    property string phase: ""
    readonly property string fileName: File.name(filePath)
    readonly property bool available: enabled && visible && width > 0 && height > 0
    readonly property bool hasFile: filePath.length > 0
    readonly property bool presentationActive: available && (hasFile || phase === "returning")
    readonly property bool shaderActive: presentationActive && phase !== "stored"
    readonly property alias hitItem: hit
    readonly property alias shader: glass
    readonly property bool acceptsClick: presentationActive && hasFile && phase === "stored"
    // Resting place of a stored file, in engine coordinates; PillBody draws it.
    readonly property real dockRadius: 13 * engine.baseH / 38
    readonly property vector3d dock: Qt.vector3d(
        bodyShader.pill.x + Math.min(80 * engine.baseH / 38, bodyShader.pill.z - dockRadius),
        bodyShader.pill.y + bodyShader.pill.w + 8 * engine.baseH / 38 + dockRadius, dockRadius)
    readonly property bool docked: acceptsClick
    readonly property bool dockHovered: hover.hovered && acceptsClick
    readonly property bool dockPressed: tap.pressed && acceptsClick
    // Once stored, hiding the body must not replay the pickup when it returns.
    property bool wasStored: false
    // Growth of the drawn droplet (PillBody); the glyph waits for the glass.
    property real dockProgress: 1
    readonly property string fileIcon: /\.(mp4|mkv|webm|mov|avi)$/i.test(fileName) ? "movie" : "image"
    signal fileDelivered(string path, point position)

    function offerFile(path) {
        const local = File.localPath(path)
        if (!acceptFiles || !local || hasFile || phase === "returning") return false
        filePath = local
        if (available) collect()
        return true
    }
    function resetDrop() {
        engine.dropState = Drop.create(engine.dropGeometry())
        engine.refresh()
    }
    function storeImmediately() {
        resetDrop()
        engine.dropState.stored = true
        phase = "stored"
        wasStored = true
        engine.refresh()
    }
    function collect() {
        if (!available || !hasFile) return
        if (reduceMotion) { storeImmediately(); return }
        resetDrop()
        phase = "collecting"
        const k = engine.baseH / 38
        const x = Math.max(0, Math.min(width - bodyOrigin.x - 24*k, engine.cx + 80*k))
        const y = Math.max(0, Math.min(height - bodyOrigin.y - 24*k, engine.cy + 130*k))
        engine.dropCommand("swallow(" + x + "," + y + ")")
    }
    function activate() {
        if (!acceptsClick) return false
        phase = "delivering"
        if (reduceMotion) {
            completeDelivery(Qt.point(engine.cx, engine.cy))
        } else {
            const k = engine.baseH / 38
            // Leave from the docked droplet, not from inside the pill.
            const st = engine.dropState
            st.hx.x = dock.x; st.hy.x = dock.y; st.hr.x = dock.z
            st.hx.v = st.hy.v = st.hr.v = 0
            engine.dropTarget = Qt.point(
                Math.max(0, Math.min(width - bodyOrigin.x - 54*k, engine.cx + 100*k)),
                Math.max(0, Math.min(height - bodyOrigin.y - 54*k, engine.cy + 180*k)))
            engine.dropCommand("deliver")
        }
        return true
    }
    function completeDelivery(position) {
        if (phase !== "delivering" || !hasFile || !available) return
        const path = filePath
        filePath = ""
        wasStored = false
        phase = "returning"
        // The saved file stays in place; only an explicit activation can open it.
        Quickshell.execDetached(File.openArguments(path))
        fileDelivered(path, Qt.point(position.x + bodyOrigin.x, position.y + bodyOrigin.y))
        if (reduceMotion) { resetDrop(); phase = "" }
        else engine.dropCommand("callBack")
    }
    function suspend() {
        phase = ""
        resetDrop()
    }
    onAvailableChanged: {
        if (!engine) return
        if (!available) suspend()
        else if (hasFile && wasStored) storeImmediately()
        else if (hasFile) collect()
    }
    onReduceMotionChanged: {
        if (reduceMotion && available) {
            if (phase === "delivering") completeDelivery(Qt.point(engine.cx, engine.cy))
            else if (hasFile) storeImmediately()
            else { resetDrop(); phase = "" }
        }
    }
    Component.onDestruction: if (engine) resetDrop()

    Binding {
        target: root.engine
        property: "dropArea"
        value: Qt.size(Math.max(1, root.width - root.bodyOrigin.x),
            Math.max(1, root.height - root.bodyOrigin.y))
        when: root.available
        restoreMode: Binding.RestoreBindingOrValue
    }

    Connections {
        target: root.engine
        function onDropModeChanged() {
            if (root.engine.dropMode !== "home") return
            if (root.phase === "collecting" && root.engine.dropHasItem) {
                root.phase = "stored"
                root.wasStored = true
            }
            else if (root.phase === "returning") root.phase = ""
        }
        function onItemReleased(position) { root.completeDelivery(position) }
    }

    BodyShader {
        id: glass
        parent: root.visualParent
        anchors.fill: parent
        visible: root.shaderActive
        outsideOpacity: 0
        designScale: root.bodyShader.designScale
        time: root.engine.time
        pill: Qt.vector4d(root.bodyShader.pill.x + root.bodyOrigin.x,
            root.bodyShader.pill.y + root.bodyOrigin.y, root.bodyShader.pill.z, root.bodyShader.pill.w)
        bulge: Qt.vector4d(root.engine.bulge.x + root.bodyOrigin.x,
            root.engine.bulge.y + root.bodyOrigin.y, root.engine.bulge.z, root.engine.bulge.w)
        drop0: Qt.vector4d(root.engine.drop0.x + root.bodyOrigin.x,
            root.engine.drop0.y + root.bodyOrigin.y, root.engine.drop0.z, root.engine.drop0.w)
        drop1: Qt.vector4d(root.engine.drop1.x + root.bodyOrigin.x,
            root.engine.drop1.y + root.bodyOrigin.y, root.engine.drop1.z, root.engine.drop1.w)
        drop2: Qt.vector4d(root.engine.drop2.x + root.bodyOrigin.x,
            root.engine.drop2.y + root.bodyOrigin.y, root.engine.drop2.z, root.engine.drop2.w)
        glow: root.engine.glow
        night: root.engine.night
        spec: root.engine.spec
        warm: root.engine.warm
        lightDir: root.engine.lightDir
        colA: root.bodyShader.colA
        colB: root.bodyShader.colB
        colC: root.bodyShader.colC
        colBg: root.bodyShader.colBg
        colBase: root.bodyShader.colBase
        colTop: root.bodyShader.colTop
        fillAlpha: root.bodyShader.fillAlpha
        pillRadius: root.bodyShader.pillRadius
        wallpaperSource: root.bodyShader.wallpaperSource
        screenSize: Qt.size(root.width, root.height)
        wallOrigin: Qt.vector2d(0, 0)
    }

    Item {
        id: hit
        parent: root.hitParent
        z: 6
        readonly property real radius: root.engine.dropMode === "home"
            ? 13 * root.engine.baseH / 38 : root.engine.drop0.z
        x: root.bodyOrigin.x + (root.engine.dropMode === "home" ? root.dock.x : root.engine.drop0.x) - radius
        y: root.bodyOrigin.y + (root.engine.dropMode === "home" ? root.dock.y : root.engine.drop0.y) - radius
        width: 2 * radius
        height: width
        visible: root.presentationActive
        enabled: root.acceptsClick
        activeFocusOnTab: enabled
        Accessible.role: Accessible.Button
        Accessible.name: I18n.tr("Abrir %1").arg(root.fileName)
        Accessible.onPressAction: root.activate()
        Keys.onReturnPressed: root.activate()
        Keys.onEnterPressed: root.activate()
        Keys.onSpacePressed: root.activate()
        HoverHandler { id: hover }
        ToolTip.visible: hover.hovered && root.acceptsClick
        ToolTip.text: root.fileName
        TapHandler { id: tap; enabled: root.acceptsClick; onTapped: root.activate() }
        // The droplet itself is glass drawn by PillBody; only the glyph lives here.
        MaterialIcon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.dockPressed ? 0.5 * root.engine.baseH / 38 : 0
            iconName: root.fileIcon
            font.pixelSize: 14 * root.engine.baseH / 38
            color: root.dockHovered ? root.bodyShader.colC : Qt.alpha(root.bodyShader.colC, 0.86)
            scale: root.dockHovered && !root.dockPressed ? 1.08 : 1
            opacity: root.engine.dropMode === "home" && root.acceptsClick
                ? Math.max(0, Math.min(1, (root.dockProgress - 0.55) / 0.4)) : 0
            visible: opacity > 0.01
            Behavior on scale {
                enabled: !root.reduceMotion
                NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
            }
            Accessible.ignored: true
        }
    }
}
