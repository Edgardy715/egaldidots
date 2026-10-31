import QtQuick
import QtTest
import Quickshell
import "body"
import "Singletons"

ShellRoot {
    settings.watchFiles:false
    Window {
        id:win
        width:640;height:360;visible:true
        BodyEngine { id:engine;cx:320;cy:90;dropArea:Qt.size(640,360);manualStep:true;active:false;breathe:false;reduceMotion:false;mood:"curiosa" }
        BodyShader {
            id:shader
            anchors.fill:parent
            pill:engine.pill;bulge:engine.bulge
            drop0:engine.drop0;drop1:engine.drop1;drop2:engine.drop2;drop3:engine.drop3
            colA:Theme.accentSoft;colB:Theme.accentAlt;colC:Theme.accent;colBg:Theme.background
            glow:engine.glow;lightDir:engine.lightDir
        }
        TestCase {
            name:"BodyDrop";when:win.visible
            property bool passed:false
            function advance(seconds) {for(let i=0;i<Math.ceil(seconds*240);i++)engine.step(1/240)}
            function test_cycle() {
                verify(!engine.frameRunning && !engine.timerRunning)
                engine.dropCommand("release");compare(engine.dropMode,"out");compare(engine.drop0.w,1)
                advance(.05)
                const x=engine.drop0.x,y=engine.drop0.y,v=engine.dropState.hy.v
                engine.dropCommand("callBack");compare(engine.drop0.x,x);compare(engine.drop0.y,y);compare(engine.dropState.hy.v,v)
                engine.step(1/60);verify(Math.hypot(engine.drop0.x-x,engine.drop0.y-y)<2)
                advance(3);compare(engine.dropMode,"home");compare(engine.drop0.w,0)
                engine.itemPos=Qt.point(420,200);engine.itemDragging=true;advance(3)
                compare(engine.dropMode,"out");verify(!engine.dropHasItem)
                engine.itemDragging=false;advance(3)
                verify(engine.dropHasItem);advance(4);compare(engine.dropMode,"home")
                verify(engine.pillHalfW>124);verify(engine.dropLabel)
                engine.reduceMotion=true;compare(engine.pillHalfW,132);verify(!engine.needsFrames)
                engine.dropCommand("deliver");engine.step(0);compare(engine.dropMode,"out");verify(!engine.dropHasItem)
                engine.dropCommand("callBack");engine.step(0);compare(engine.dropMode,"home")
                engine.reduceMotion=false;advance(8)
                verify(!engine.frameRunning && !engine.timerRunning);verify(!engine.needsFrames)
                engine.dropCommand("release");advance(.3);wait(200)
                if(shader.GraphicsInfo.api===GraphicsInfo.Software) console.warn("SKIP: shader en software; validar OpenGL/Wayland")
                else compare(shader.status,ShaderEffect.Compiled,shader.log)
                compare(shader.log,"");passed=true
            }
            function cleanupTestCase() {
                if(!passed){console.error("FAIL: gota QML");Qt.exit(1);return}
                console.info("PASS: gota QML, estados, interrupción, archivo, entrega, reduce, reposo y shader")
                Qt.quit()
            }
        }
    }
}
