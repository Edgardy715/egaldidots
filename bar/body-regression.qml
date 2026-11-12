import QtQuick
import QtTest
import Quickshell
import "body"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: win
        visible: true; width:640; height:360
        BodyEngine { id: engine; cx:320; cy:100; manualStep:true; breathe:false; active:false; reduceMotion:false }
        BodyShader {
            id: shader
            anchors.fill:parent
            pillCx:engine.pill.x; pillCy:engine.pill.y; pillHalfW:engine.pill.z; pillHalfH:engine.pill.w
            bulgeX:engine.bulge.x; bulgeY:engine.bulge.y; bulgeR:engine.bulge.z
            colA:Theme.accentSoft; colB:Theme.accentAlt; colC:Theme.accent; colBg:Theme.background
            night:engine.night; spec:engine.spec; warm:engine.warm; lightDir:engine.lightDir
        }
        TestCase {
            name:"Cuerpo"; when:win.visible
            property int completed:0
            function test_engine() {
                verify(!engine.frameRunning && !engine.timerRunning)
                engine.reduceMotion=true; engine.mood="dormida"
                compare(engine.pillHalfH,16); verify(!engine.needsFrames)
                verify(!engine.frameRunning && !engine.timerRunning)
                engine.reduceMotion=false; engine.mood="curiosa"
                for (let i=0;i<20;i++) engine.step(1/240)
                const x=engine.pillHalfW, v=engine.state.hw.v
                engine.mood="timida"; compare(engine.pillHalfW,x); compare(engine.state.hw.v,v)
                engine.step(1/240); verify(Math.abs(engine.pillHalfW-x)<1)
                const light=engine.lightDir.x
                engine.hour=2; compare(engine.lightDir.x,light)
                engine.step(1/240); verify(Math.abs(engine.lightDir.x-light)<.01)
                engine.reduceMotion=true; engine.hour=6
                compare(engine.warm,engine.lamps[2].t)
                completed++
            }
            function test_shader() {
                wait(200)
                if (shader.GraphicsInfo.api === GraphicsInfo.Software) {
                    console.warn("SKIP: renderizador software offscreen; compilación shader se verifica con RHI/Wayland")
                    compare(shader.status,ShaderEffect.Uncompiled)
                } else compare(shader.status,ShaderEffect.Compiled,shader.log)
                compare(shader.log,"")
                completed++
            }
            function test_idle() {
                engine.reduceMotion=false;engine.mood="curiosa";engine.breathe=true
                for (let i=0;i<2400;i++) engine.step(1/240)
                verify(!engine.needsFrames)
                engine.manualStep=false;engine.active=true
                verify(engine.timerRunning && !engine.frameRunning)
                const count=engine.advanceCount
                wait(1050)
                const ticks=engine.advanceCount-count
                console.info("Timer: "+ticks+" avances en 1050 ms")
                verify(ticks>=27 && ticks<=35,"Timer 33 ms: "+ticks)
                engine.active=false
                const stopped=engine.advanceCount
                wait(100);compare(engine.advanceCount,stopped)
                engine.active=true;engine.reduceMotion=true
                verify(!engine.frameRunning && !engine.timerRunning)
                completed++
            }
            function cleanupTestCase() {
                if(completed!==3) { console.error("FAIL: Cuerpo "+completed+"/3"); Qt.exit(1); return }
                console.info("PASS: Cuerpo shader, interrupción, luz, reduce, inactivo y Timer ≈30 fps")
                Qt.quit()
            }
        }
    }
}
