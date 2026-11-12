import QtQuick
import "../Singletons"
import "BodySprings.js" as Springs
import "BodyBrain.js" as Brain
import "BodyLight.js" as Light
import "BodyDropBrain.js" as Drop

Item {
    id: engine
    property real cx: 0
    property real cy: 0
    property real baseW: 220
    property real baseH: 38
    property string mood: "auto"
    property real hour: 12
    property bool music: false
    // -1 usa el reloj musical de la demo; 0..1 recibe una envolvente externa.
    property real beatEnvelope: -1
    property point pointer: Qt.point(-1,-1)
    property bool active: true
    property bool reduceMotion: Flags.reduceMotion
    property bool breathe: true
    property real maxBreathAmplitude: -1
    property bool manualStep: false
    property bool sleepWhenStill: false
    // La demo ensancha el núcleo para la etiqueta; en la pill la gota acoplada la sustituye.
    property bool storedWidens: true
    property point dropTarget: Qt.point(-1,-1)
    property point itemPos: Qt.point(-1,-1)
    property bool itemDragging: false
    property size dropArea: Qt.size(width,height)
    property var dropState: Drop.create({cx:cx,cy:cy,baseH:baseH})
    property var dropResult: ({mode:"home",stored:false,label:false,drop0:[0,0,0,0],drop1:[0,0,0,0],drop2:[0,0,0,0],drop3:[0,0,0,0]})
    readonly property string dropMode: dropResult.mode
    readonly property bool dropHasItem: dropResult.stored
    readonly property bool dropLabel: dropResult.label
    readonly property vector4d drop0: vector(dropResult.drop0)
    readonly property vector4d drop1: vector(dropResult.drop1)
    readonly property vector4d drop2: vector(dropResult.drop2)
    readonly property vector4d drop3: vector(dropResult.drop3)
    property point releasedItem: Qt.point(-1,-1)
    signal itemReleased(point position)
    function vector(a) { return Qt.vector4d(a[0],a[1],a[2],a[3]) }
    function dropGeometry() { return {cx:cx,cy:cy,baseH:baseH,width:dropArea.width,height:dropArea.height} }
    function dropCommand(name) {
        if (!ready) return
        const g=dropGeometry()
        if(name==="release") Drop.release(dropState,time,g,state)
        else if(name==="callBack") Drop.callBack(dropState)
        else if(name==="deliver") Drop.deliver(dropState,time,g,state,
            dropTarget.x<0?null:{x:dropTarget.x,y:dropTarget.y})
        else {
            const m=/^swallow\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)$/.exec(name)
            if(!m) return
            dropState.chip={x:Number(m[1]),y:Number(m[2])};dropState.armed=true
            if(dropState.mode==="home" && !dropState.stored) Drop.release(dropState,time,g,state)
        }
        refresh()
    }
    readonly property vector4d pill: Qt.vector4d(result.pill[0],result.pill[1],result.pill[2],result.pill[3])
    readonly property vector4d bulge: Qt.vector4d(result.bulge[0],result.bulge[1],result.bulge[2],result.bulge[3]||0)
    readonly property real pillHalfW: pill.z
    readonly property real pillHalfH: pill.w
    readonly property real glow: result.glow
    readonly property real night: lamps[3].x
    readonly property real spec: lamps[4].x
    readonly property real warm: lamps[2].x
    readonly property vector2d lightDir: {
        const length=Math.hypot(lamps[0].x,lamps[1].x) || 1
        return Qt.vector2d(lamps[0].x/length,lamps[1].x/length)
    }
    readonly property string currentMood: result.mood
    property bool needsFrames: false
    readonly property bool frameRunning: frames.running
    readonly property bool timerRunning: idle.running
    property int advanceCount: 0
    property real time: 0
    property var state: Brain.create({baseW:baseW,baseH:baseH})
    property var lamps: [Springs.create(0,5,1),Springs.create(-1,5,1),
        Springs.create(0,4,1),Springs.create(0,4,1),Springs.create(.8,4,1)]
    property var result: ({pill:[cx,cy,baseW/2,baseH/2],bulge:[cx,cy,0,0],glow:0,mood:"curiosa"})
    property bool ready: false
    property double lastClock: Date.now()

    function refresh() {
        // Manual fixtures may update a stopped engine. Hidden production bodies
        // must also ignore refreshes caused by layout and pointer bindings.
        if (!ready || (!active && !manualStep)) return
        Brain.setGeometry(state,{cx:cx,cy:cy,baseW:baseW,baseH:baseH})
        step(0)
        lastClock=Date.now()
    }
    function pointerMoved(p) {
        Brain.pointerMoved(state,p,time)
        Drop.pointerMoved(dropState,p,time)
        refresh()
    }
    function tapped(p) {
        const hit=Brain.tapped(state,p,time)
        refresh()
        return hit
    }
    function step(dt) {
        dt=Math.max(0,Math.min(.05,dt))
        time+=dt
        const opts={reduce:reduceMotion,breathe:breathe,music:music,beatEnvelope:beatEnvelope,maxBreathAmplitude:maxBreathAmplitude,calmHover:sleepWhenStill}
        // Brain calcula destinos; cuerpo y satélite se integran juntos una sola vez.
        Brain.update(state,0,time,opts)
        const dropOpts={geometry:dropGeometry(),reduce:reduceMotion,itemDragging:itemDragging,widen:storedWidens}
        Drop.prepare(dropState,time,dropOpts,state)
        const springs=state.all.concat(dropState.all)
        if(reduceMotion) Springs.snap(springs); else Springs.stepAll(springs,dt)
        const r=Brain.update(state,0,time,opts)
        const d=Drop.finish(dropState,time,dropOpts,state)
        if(dropState.stored && dropState.mode==="home") {
            if(storedWidens) state.hw.t=132*baseH/38
            state.glow.t=.12
            if(reduceMotion) {
                state.hw.x=state.hw.t;state.hw.v=0;state.glow.x=.12;state.glow.v=0
                r.pill[2]=state.hw.x;r.glow=state.glow.x
            }
        }
        r.bulge[2]*=d.bulge<.001?0:d.bulge
        const k=baseH/38
        r.needsFrames=!reduceMotion && (!state.all.every(s => {
            const breathing=breathe && (s===state.hw || s===state.hh)
            return Math.abs(s.x-s.t)<(breathing?3.5*k:.02) && Math.abs(s.v)<(breathing?6*k:.2)
        }) || r.mood==="contenta" || (sleepWhenStill ? music && beatEnvelope < 0
            : state.fA.t!==0 || Math.abs(state.fA.x)>.00001 || music))
        dropResult=d
        if(d.spit) { releasedItem=Qt.point(d.spit.x,d.spit.y);itemReleased(releasedItem) }
        const l=Light.light(hour), target=[l.L[0],l.L[1],l.warm,Math.max(r.night,l.night),Math.min(r.spec,l.spec)]
        for (let i=0;i<lamps.length;++i) lamps[i].t=target[i]
        if (reduceMotion) Springs.snap(lamps); else Springs.stepAll(lamps,dt)
        // Publica las mutaciones JS una sola vez por cuadro.
        lamps=lamps.slice()
        result=r
        // Lamps settle at visible precision: 0.004 is below one 8-bit level in every term they
        // feed (rim light, night dimming). Tighter, a minute's light catch-up kept the engine
        // drawing unchanged frames for a second after each wake.
        needsFrames=!reduceMotion && (r.needsFrames || d.needsFrames || !Springs.settled(lamps,.004,.02))
        advanceCount++
    }
    function advance(dt) { step(dt); lastClock=Date.now() }
    onDropAreaChanged: refresh()
    onItemPosChanged: if(ready && itemPos.x>=0 && itemPos.y>=0) {
        dropState.chip={x:itemPos.x,y:itemPos.y}
        if(itemDragging && !dropState.stored) {
            dropState.armed=true
            if(dropState.mode==="home") Drop.release(dropState,time,dropGeometry(),state)
        }
        refresh()
    }
    onItemDraggingChanged: if(ready) {
        dropState.chip={x:itemPos.x,y:itemPos.y}
        if(itemDragging && !dropState.stored) {
            dropState.armed=true
            if(dropState.mode==="home") Drop.release(dropState,time,dropGeometry(),state)
        }
        refresh()
    }
    onCxChanged: refresh()
    onCyChanged: refresh()
    onBaseWChanged: refresh()
    onBaseHChanged: refresh()
    onMoodChanged: if (ready) { Brain.setMood(state,mood,time); refresh() }
    onHourChanged: refresh()
    onMusicChanged: refresh()
    onBeatEnvelopeChanged: refresh()
    onBreatheChanged: refresh()
    onReduceMotionChanged: refresh()
    onActiveChanged: { lastClock=Date.now(); if (active) refresh() }
    onPointerChanged: if (ready) pointerMoved(pointer.x<0 && pointer.y<0?null:pointer)
    Component.onCompleted: {
        ready=true
        Brain.setMood(state,mood,time)
        Brain.pointerMoved(state,pointer.x<0 && pointer.y<0?null:pointer,time)
        refresh()
    }
    FrameAnimation {
        id: frames
        running: engine.active && engine.needsFrames && !engine.reduceMotion && !engine.manualStep
        onTriggered: engine.advance(frameTime)
    }
    Timer {
        id: idle
        interval: 33
        repeat: true
        running: engine.active && !engine.needsFrames && engine.breathe && !engine.reduceMotion && !engine.manualStep
        onTriggered: engine.advance((Date.now()-engine.lastClock)/1000)
    }
    // El sueño mantiene un plazo finito también sin respiración.
    Timer {
        interval: Math.max(1,Math.ceil((9.001-(engine.time-engine.state.lastMove))*1000))
        running: engine.active && !engine.reduceMotion && !engine.manualStep && !engine.breathe
            && !engine.needsFrames && engine.mood === "auto" && engine.currentMood !== "dormida"
        onTriggered: { engine.time=Math.max(engine.time,engine.state.lastMove+9.001); engine.refresh() }
    }
}
