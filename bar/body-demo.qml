import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Singletons"
import "body"

ShellRoot {
    settings.watchFiles: false
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: window
            required property var modelData
            readonly property real u: Math.max(.58,Math.min(1.18,modelData.height/1080*Flags.uiScale))
            property bool localHour: true
            property bool captureMode: false
            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors { top:true; left:true; right:true }
            implicitHeight: 360*u
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell.body-demo"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            mask: Region { item: stage }
            function now() { const d=new Date(); engine.hour=d.getHours()+d.getMinutes()/60 }
            Component.onCompleted: now()
            Timer { interval:60000; repeat:true; running:window.localHour; onTriggered:window.now() }
            IpcHandler {
                target: "body-"+window.modelData.name
                function scene(m: string, h: real, sound: bool, attention: bool): string {
                    if (Quickshell.env("ISLA_BODY_TEST") !== "1") return "Modo de prueba desactivado"
                    window.localHour=false;window.captureMode=true
                    engine.mood=m; engine.hour=h; engine.music=sound
                    engine.pointer=attention?Qt.point(engine.cx+150*window.u,engine.cy):Qt.point(-1,-1)
                    return "ok"
                }
                function status(): string {
                    return JSON.stringify({shader:bodyShader.status,log:bodyShader.log,
                        dropMode:engine.dropMode,stored:engine.dropHasItem,label:engine.dropLabel,
                        drop:[engine.drop0.x,engine.drop0.y,engine.drop0.z,engine.drop0.w],res:engine.drop2.w,
                        mood:engine.currentMood,frames:engine.frameRunning,timer:engine.timerRunning,
                        count:engine.advanceCount,pill:[engine.pill.x,engine.pill.y,engine.pill.z,engine.pill.w]})
                }
                function drop(command: string): void {
                    if(Quickshell.env("ISLA_BODY_TEST")==="1") engine.dropCommand(command)
                }
                function close(): void { Qt.quit() }
            }
            Item {
                id: stage
                anchors.fill: parent
                focus: true
                BodyEngine {
                    id: engine
                    cx: stage.width/2; cy: 90*window.u
                    baseW:220*window.u; baseH:38*window.u
                    active:window.visible
                    dropArea:Qt.size(stage.width,stage.height)
                    itemPos:Qt.point(chip.x+chip.width/2,chip.y+chip.height/2)
                    itemDragging:chipDrag.active
                    onItemReleased: position => {
                        chip.x=position.x-chip.width/2;chip.y=position.y-chip.height/2
                    }
                }
                BodyShader {
                    id: bodyShader
                    anchors.fill:parent
                    designScale:window.u
                    time:engine.time
                    pillCx:engine.pill.x; pillCy:engine.pill.y
                    pillHalfW:engine.pill.z; pillHalfH:engine.pill.w
                    drop0:engine.drop0;drop1:engine.drop1;drop2:engine.drop2;drop3:engine.drop3
                    bulgeX:engine.bulge.x; bulgeY:engine.bulge.y; bulgeR:engine.bulge.z; bulgeWeight:engine.bulge.w
                    glow:engine.glow; night:engine.night; spec:engine.spec
                    warm:engine.warm; lightDir:engine.lightDir
                    colA:Theme.accentSoft; colB:Theme.accentAlt; colC:Theme.accent; colBg:Theme.background
                    screenSize:Qt.size(window.modelData.width,window.modelData.height)
                    wallOrigin:Qt.vector2d(0,0)
                    wallpaperSource:Wallpapers.current ? "file://"+Wallpapers.current : ""
                }
                HoverHandler {
                    onPointChanged: if(!window.captureMode) engine.pointer=point.position
                    onHoveredChanged: if (!window.captureMode && !hovered) engine.pointer=Qt.point(-1,-1)
                }
                TapHandler { onTapped: (eventPoint) => { stage.forceActiveFocus(); engine.tapped(eventPoint.position) } }
                Keys.onPressed: event => {
                    const moods=["auto","curiosa","timida","dormida","contenta"]
                    if (event.key>=Qt.Key_1 && event.key<=Qt.Key_5) engine.mood=moods[event.key-Qt.Key_1]
                    else if (event.key===Qt.Key_Left || event.key===Qt.Key_Right) {
                        window.localHour=false
                        engine.hour=(engine.hour+(event.key===Qt.Key_Right?.5:23.5))%24
                    } else if (event.key===Qt.Key_N) { window.localHour=true; window.now() }
                    else if (event.key===Qt.Key_G) engine.dropCommand(engine.dropMode==="home" || engine.dropMode==="return"?"release":"callBack")
                    else if (event.key===Qt.Key_D) engine.dropCommand("deliver")
                    else if (event.key===Qt.Key_M) engine.music=!engine.music
                    else if (event.key===Qt.Key_B) engine.breathe=!engine.breathe
                    else if (event.key===Qt.Key_R) engine.reduceMotion=!engine.reduceMotion
                    else if (event.key===Qt.Key_Escape) Qt.quit()
                    else return
                    event.accepted=true
                }
                Text {
                    x:engine.cx-width/2; y:engine.cy-height/2
                    visible:engine.dropLabel
                    text:I18n.tr("▧  captura.png")
                    color:Theme.foreground;font.pixelSize:12*window.u
                }
                Rectangle {
                    id:chip
                    x:stage.width/2+180*window.u;y:185*window.u
                    width:132*window.u;height:36*window.u;radius:10*window.u
                    visible:opacity>.001 || !engine.dropHasItem
                    opacity:engine.dropHasItem?0:1
                    scale:engine.dropHasItem?.12:1
                    Behavior on opacity { NumberAnimation { duration:engine.reduceMotion?0:340 } }
                    Behavior on scale { NumberAnimation { duration:engine.reduceMotion?0:340 } }
                    color:Theme.background;border.color:Theme.accentSoft
                    Text { anchors.centerIn:parent;text:I18n.tr("▧  captura.png");color:Theme.foreground;font.pixelSize:13*window.u }
                    DragHandler {
                        id:chipDrag
                        xAxis.minimum:24*window.u;xAxis.maximum:stage.width-chip.width-24*window.u
                        yAxis.minimum:24*window.u;yAxis.maximum:stage.height-chip.height-24*window.u
                        onActiveChanged:if(active)stage.forceActiveFocus()
                    }
                }
                Row {
                    x:20*window.u;y:305*window.u;spacing:8*window.u
                    Button {
                        text:engine.dropMode==="home"?I18n.tr("Soltar la gota · G"):I18n.tr("Llamar / cambiar rumbo · G")
                        onClicked:{stage.forceActiveFocus();engine.dropCommand(engine.dropMode==="home" || engine.dropMode==="return"?"release":"callBack")}
                    }
                    Button { text:I18n.tr("Devolver archivo · D");enabled:engine.dropHasItem && engine.dropMode==="home"
                        onClicked:{stage.forceActiveFocus();engine.dropCommand("deliver")} }
                }
                Text {
                    x:20*window.u; y:260*window.u
                    color:Theme.foreground
                    font.pixelSize:12*window.u
                    text: I18n.tr("%1 · %2:%3 · %4\n1–5 ánimo · ← → hora · N ahora · M música · B respiración · R reducir · G gota · D devolver · Esc cerrar")
                        .arg(engine.currentMood==="timida"?I18n.tr("tímida"):engine.currentMood)
                        .arg(String(Math.floor(engine.hour)).padStart(2,"0"))
                        .arg(String(Math.floor(engine.hour%1*60)).padStart(2,"0"))
                        .arg(({home:I18n.tr("En casa"),out:I18n.tr("Explorando"),return:I18n.tr("Regresando"),deliver:I18n.tr("Entregando")})[engine.dropMode])
                }
            }
        }
    }
}
