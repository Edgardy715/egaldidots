pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components"
import "windows"
import "Singletons"

// Native DP-1 harness, shifted below the user's bar; every surface is production code.
ShellRoot {
    id: root
    settings.watchFiles: false
    readonly property var display: Quickshell.screens.find(screen => screen.name === "DP-1") || Quickshell.screens[0]
    readonly property Item layer: overlay.petLayer
    readonly property Item actor: layer ? layer.actor : null
    property real clockOffset: 0
    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (const child of item.children || []) { const match = find(child, name); if (match) return match }
        return null
    }
    readonly property Item modules: find(overlay.contentItem, "islandModules")
    readonly property Item rail: modules ? modules.workspaceItem : null
    SurfaceRouter { id: router; focusedMonitorName: root.display.name; reduceMotion: Flags.reduceMotion }
    IslandOverlay { id: overlay; modelData: root.display; router: router; margins.top: 96 }
    property int landTarget: 0
    Connections {
        target: root.layer
        function onPhaseChanged() {
            if (!root.landTarget || root.layer.phase !== "land") return
            const id = root.landTarget
            root.landTarget = 0
            Qt.callLater(() => { if (root.rail) root.rail.activeId = id })
        }
    }
    IpcHandler {
        target: "petqa"
        function status(): string {
            const feet = root.actor ? root.actor.mapToItem(overlay.contentItem, root.actor.originX * root.actor.px, root.actor.footRow * root.actor.px) : Qt.point(0, 0)
            return JSON.stringify({loaded: Config.loaded, perch: root.layer ? root.layer.perchId : "", phase: root.layer ? root.layer.phase : "",
                flying: root.layer ? root.layer.flying : false, anim: root.actor ? root.actor.anim : "", px: root.actor ? root.actor.px : 0,
                holdingHome: root.layer ? root.layer.homeReturnPending : false,
                coding: root.layer ? root.layer.coding : false, animating: root.actor ? root.actor.animating : false,
                compact: overlay.compact, layoutChanging: overlay.layoutChanging, surface: overlay.surface,
                activeId: root.rail ? root.rail.activeId : 0, feet: [feet.x, feet.y + 96], music: Players.playing,
                opaqueTop: root.actor ? feet.y - root.actor.reachRows * root.actor.px : 0,
                opacity: root.actor ? root.actor.opacity : 0, shown: root.actor ? root.actor.shown : false,
                landArmed: root.landTarget !== 0})
        }
        function surface(name: string): bool { if (name) router.toggleSurface(root.display.name, name); else router.close(); return true }
        function workspace(id: int): bool { if (!root.rail) return false; root.rail.activeId = id; return true }
        // IPC latency cannot hit the 90 ms landing crouch, so the fixture retargets on it.
        function workspaceOnLand(id: int): bool { if (!root.rail) return false; root.landTarget = id; return true }
        function hover(id: int): bool { if (!root.rail) return false; root.rail.hoverId = id; return true }
        function event(kind: string): bool { if (!root.layer) return false; root.layer.notify(kind); return true }
        function sleepAfter(ms: int): bool { if (!root.actor) return false; root.actor.sleepAfterMs = ms; root.actor.armSleep(); return true }
        function gaze(): string {
            const seek = item => !item ? null : item.restCenterWidth !== undefined && item.pointerX !== undefined ? item
                : (item.children || []).reduce((found, child) => found || seek(child), null)
            const pill = seek(overlay.contentItem)
            const body = pill && root.actor ? root.actor.mapToItem(pill, root.actor.originX * root.actor.px, root.actor.hit[1] * root.actor.px) : Qt.point(0, 0)
            return JSON.stringify({dir: root.layer ? root.layer.pillDirection : "", hovered: pill ? pill.hovered : false,
                pointer: pill ? [pill.pointerX, pill.pointerY] : [], body: [body.x, body.y], pillW: pill ? pill.width : 0})
        }
        function pet(): bool { if (!root.actor) return false; root.actor.pet(); return true }
        function selectPlayer(needle: string): bool {
            const player = Players.list.find(player => player.dbusName.indexOf(needle) >= 0)
            if (!player) return false
            Players.manual = player
            return true
        }
        function advanceClock(seconds: int): bool {
            if (!root.actor) return false
            root.clockOffset += seconds * 1000
            root.actor.now = () => new Date(Date.now() + root.clockOffset)
            root.actor.think()
            return true
        }
        function focusApp(id: string): bool {
            const window = ToplevelManager.toplevels.values.find(window => window.appId.toLowerCase() === id.toLowerCase())
            if (!window) return false
            window.activate()
            return true
        }
        function quit(): bool { router.close(); Qt.callLater(Qt.quit); return true }
    }
}
