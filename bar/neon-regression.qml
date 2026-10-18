import QtQuick
import Quickshell
import "components"
import "Singletons"
ShellRoot {
    settings.watchFiles: false
    Window {
        visible: true
        width: 900; height: 700
        color: "#15171d"
        Rectangle {
            color: "#15171d"
            id: scene
            anchors.fill: parent
            Column {
                x: 40; y: 32; spacing: 30
                Text { text: "Isla · luz y respuesta"; color: Theme.foreground; font.pixelSize: 24 }
                Row { spacing: 26
                    Slider { width: 170; value: 0.65; knob: true }
                    IconTile { iconName: "coffee"; active: true }
                }
                Row {
                    spacing: 26
                    BatteryIndicator { s: 1.6; level: 0.8 }
                    BatteryIndicator { s: 1.6; level: 0.6; charging: true }
                    BatteryIndicator { s: 1.6; level: 0.15 }
                    TopWorkspaceRail { style: "pacman"; count: 4; activeId: 2 }
                    TopWorkspaceRail { style: "capsules"; count: 4; activeId: 2 }
                }
                Row {
                    spacing: 28
                    Item { width: 340; height: 60
                        PillMaterial { mode: "rest"; materialAwake: true; morphRadius: 30 }
                        Row { anchors.centerIn: parent; spacing: 16
                            IslandMediaCover { diameter: 40; hasProgress: true; progress: 0.72; hovered: true }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "Música · progreso"; color: Theme.foreground; font.pixelSize: 16 }
                        }
                    }
                    TopWorkspaceRail { activeId: 2; count: 4 }
                }
                Row {
                    spacing: 28
                    GlassCard { width: 340; height: 140; glow: 0.65
                        Column { x: 20; y: 20; spacing: 16
                            Text { text: "Controles activos"; color: Theme.foreground; font.pixelSize: 18 }
                            Row { spacing: 28

                                Toggle { checked: true }
                                Toggle { checked: false }
                                Toggle { checked: true; enabled: false }
                            }
                            MotionButton { text: "Acción enfocada"; highlighted: true }
                        }
                    }
                    Item { width: 340; height: 140
                        PillMaterial { mode: "media"; surface: "media"; materialAwake: true; morphRadius: 24 }
                        Text { anchors.centerIn: parent; text: "Superficie expandida"; color: Theme.foreground; font.pixelSize: 18 }
                    }
                }
                Row { spacing: 28
                    Rectangle { width: 200; height: 48; radius: 12; color: Theme.cardBot
                        Text { anchors.centerIn: parent; text: "Foco de teclado"; color: Theme.foreground }
                        MotionArea { id: hit; anchors.fill: parent; accessibleName: "Prueba" }
                    }
                    OsdOverlay { id: osd; shown: true; value: 0.65; kind: "brightness"; glyph: "brightness_6" }
                    MaterialIcon { id: outline; width: 32; height: 32; iconName: "wifi"; color: Theme.accent; neonIntensity: 0 }
                }
            }
        }
    }
    Timer {
        interval: 900; running: true
        onTriggered: {
            hit.forceActiveFocus()
            if (outline.layer.enabled) { console.error("FAIL: zero intensity should hide neon"); Qt.exit(1); return }
            Config.update({appearance: {reduceMotion: true}})
            outline.neonIntensity = 1
            if (!outline.layer.enabled) { console.error("FAIL: static neon must remain visible"); Qt.exit(1); return }
            scene.grabToImage(result => {
                result.saveToFile("/tmp/isla-neon-preview.png")
                console.log("PASS: neon load, inactive gate, reduced motion and native render")
                Qt.quit()
            })
        }
    }
}
