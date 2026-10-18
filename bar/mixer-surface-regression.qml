import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    id: test
    settings.watchFiles: false
    property var actions: []
    property var channels: [{name:"front-left",volume:0.42},{name:"front-right",volume:0.35}]
    property var output: ({id:"11",card:"31",name:"headset",description:"Corsair HS65 · Auriculares",volume:0.42,mute:false,channels:test.channels,ports:[{name:"analog",description:"Auriculares analógicos",available:true},{name:"hdmi",description:"HDMI desconectado",available:false}],activePort:"analog",monitorSource:"headset.monitor",canSetFormats:true,formats:["pcm"]})
    property var input: ({id:"12",card:"31",name:"microphone",description:"Corsair HS65 · Micrófono",volume:0.65,mute:false,channels:[{name:"mono",volume:0.65}],ports:[{name:"mic",description:"Micrófono de diadema",available:true}],activePort:"mic",monitor:false})
    Window {
        id: scene
        visible: true
        width: 820; height: 660
        color: Theme.background
        Rectangle { anchors.fill: parent; color: Theme.background }
        MixerView {
            id: view
            anchors.fill: parent; anchors.margins: 24
            ready: true
            defaultOutput: "headset"; defaultInput: "microphone"
            outputs: [test.output, {id:"13",name:"speakers",description:"Altavoces · Audio integrado",volume:0.3,mute:true,channels:test.channels,ports:[],monitorSource:"speakers.monitor"}]
            inputs: [test.input,{id:"14",name:"monitor",description:"Monitor de auriculares",volume:1,mute:false,channels:test.channels,monitor:true}]
            playback: [{id:"21",appName:"Firefox",mediaName:"Música · Canción de prueba",description:"Firefox",volume:0.38,mute:false,channels:test.channels,device:"11",meterSource:"playback:21"}, {id:"22",appName:"Reproductor",mediaName:"Lista de reproducción",description:"Reproductor",volume:0.8,mute:true,channels:test.channels,device:"13"}]
            recording: [{id:"23",appName:"Grabadora",mediaName:"Captura de micrófono",volume:0.75,mute:false,channels:test.channels,device:"12"}]
            cards: [{id:"31",outputEnabled:true,inputEnabled:true,canToggleOutput:true,canToggleInput:true,description:"Corsair HS65 SURROUND",activeProfile:"duplex",profiles:[{name:"duplex",description:"Estéreo analógico + entrada mono",available:true},{name:"off",description:"Apagado",available:true}],ports:[{name:"analog",description:"Auriculares",latencyOffset:0}]},{id:"32",description:"Audio integrado",activeProfile:"stereo",profiles:[{name:"stereo",description:"Salida estéreo analógica",available:true},{name:"off",description:"Apagado",available:true}],ports:[]}]
            levels: ({"headset.monitor":0.38,"microphone":0.52,"playback:21":0.25})
            onRequested: (action,args) => test.actions.push({action:action,args:args})
            onRefreshRequested: test.actions.push({action:"refresh"})
            onRequestClose: test.actions.push({action:"close"})
        }
        Shortcut { sequence: "Escape"; enabled: !view.popupOpen; onActivated: test.actions.push({action:"escape"}) }
        TestCase {
            id: checks
            name: "AudioSurface"
            when: scene.visible
            function check(ok,message) { if (!ok) { console.error("FAIL: audio", message); Qt.exit(1); throw new Error(message) } }
            function find(item,name) {
                if (item.objectName === name) return item
                for (const child of item.children || []) { const found=find(child,name); if(found) return found }
                return null
            }
            function until(predicate) {
                const deadline=Date.now()+4000
                while(!predicate() && Date.now()<deadline) wait(20)
                check(predicate(),"timeout")
            }
            function capture(name) {
                const dir=Quickshell.env("ISLA_AUDIO_SHOTS")
                if(!dir) return
                let saved=false
                scene.contentItem.grabToImage(image=>{saved=image.saveToFile(dir+"/"+name+".png")})
                until(()=>saved)
            }
            function test_journey() {
                Config.update({appearance:{reduceMotion:false}})
                wait(600)
                check(find(view,"volume-output-11")!==null,"output fader")
                check(view.meterSources.includes("headset.monitor"),"real output meter source")
                const row=find(view,"channels-output-11")
                mouseClick(row)
                wait(400)
                check(row.selected,"channels open")
                capture("01-output-channels")
                mouseClick(find(view,"disable-output-11"))
                check(test.actions[test.actions.length-1].action==="setDeviceEnabled" && test.actions[test.actions.length-1].args.direction==="output" && test.actions[test.actions.length-1].args.enabled===false,"disable endpoint direction")
                mouseClick(find(view,"format-ac3-iec61937"))
                check(test.actions[test.actions.length-1].action==="setFormats","digital format action")
                check(test.actions[test.actions.length-1].args.formats.includes("ac3-iec61937"),"digital format payload")
                mouseClick(find(view,"link-output-11"))
                check(find(view,"link-output-11").selected,"channel linking state")
                mouseClick(find(view,"link-output-11"))
                mouseClick(find(view,"rename-output-11")); wait(300)
                const rename=find(view,"renameField-output-11")
                rename.text="Mis auriculares"; rename.accepted()
                check(test.actions[test.actions.length-1].action==="renameDevice" && test.actions[test.actions.length-1].args.description==="Mis auriculares","device rename request")
                const oldFader=find(view,"volume-output-11")
                view.outputs=[Object.assign({},test.output,{volume:0.6}),view.outputs[1]]
                wait(100)
                check(find(view,"volume-output-11")===oldFader,"volume update preserves delegate/focus")
                check(oldFader.volume===0.6,"volume snapshot updates existing row")
                mouseClick(find(view,"mute-output-11"))
                check(test.actions[test.actions.length-1].action==="setMute","mute action")
                check(test.actions[test.actions.length-1].args.mute===true,"mute explicit state")
                oldFader.forceActiveFocus()
                keyClick(Qt.Key_Right)
                wait(50)
                check(test.actions[test.actions.length-1].action==="setVolume","keyboard volume")
                // Retain the user's drag while the server confirmation is in flight.
                mousePress(oldFader, oldFader.width * .25, oldFader.height / 2)
                mouseMove(oldFader, oldFader.width * .8, oldFader.height / 2)
                mouseRelease(oldFader, oldFader.width * .8, oldFader.height / 2)
                const pending=oldFader.displayVolume
                check(pending > .7 && oldFader.pending, "release retains pending volume")
                wait(150)
                check(Math.abs(oldFader.displayVolume-pending)<.001,"no snapback before confirmation")
                view.outputs=[Object.assign({},test.output,{volume:pending}),view.outputs[1]]
                wait(50)
                check(!oldFader.pending,"snapshot acknowledges pending volume")
                view.outputs=[Object.assign({},test.output,{volume:2}),view.outputs[1]]
                wait(50)
                mouseClick(oldFader, oldFader.width-1, oldFader.height/2)
                check(test.actions[test.actions.length-1].args.volume<=1.5,"preexisting 200 percent cannot emit outside backend range")
                view.outputs=[test.output,view.outputs[1]]
                oldFader.pending=false
                const choice=find(view,"route-output-11")
                choice.currentIndex=1; choice.activated(1)
                check(choice.currentIndex===0,"unconfirmed/rejected port preserves confirmed selection")
                choice.popup.open(); wait(250); capture("02-port-menu")
                const previousActions=test.actions.length
                check(view.popupOpen,"menu tracked by host")
                keyClick(Qt.Key_Escape); wait(400)
                check(!view.popupOpen,"Escape dismisses menu")
                check(test.actions.length===previousActions,"Escape does not dismiss parent while menu is open")
                view.page=1; wait(700)
                check(view.rows.length===1,"hide monitors by default")
                mouseClick(find(view,"audioMonitors")); check(view.rows.length===2,"show monitors")
                capture("03-input")
                view.page=2; wait(700)
                check(view.rows.length===2,"playback streams")
                mouseClick(find(view,"mute-playback-21"))
                check(test.actions[test.actions.length-1].args.kind==="playback","stream action kind")
                capture("04-applications")
                mouseClick(find(view,"stop-playback-21"))
                check(test.actions[test.actions.length-1].action==="killStream","stop selected stream")
                const search=find(view,"audioSearch")
                search.text="fire"; wait(150)
                check(view.rows.length===1,"search filters apps")
                search.text=""; view.captureApps=true; wait(200)
                check(view.rows.length===1 && view.kind==="recording","recording separate")
                capture("05-recording")
                view.page=3; wait(700)
                check(find(view,"profile-31")!==null,"hardware profile")
                mouseClick(find(view,"enable-output-31"))
                check(test.actions[test.actions.length-1].action==="setDeviceEnabled" && test.actions[test.actions.length-1].args.direction==="output","hardware direction switch")
                view.cards=[Object.assign({},view.cards[0],{outputEnabled:false,inputEnabled:false}),view.cards[1]]
                wait(100)
                check(!find(view,"enable-output-31").selected && !find(view,"enable-input-31").selected,"disabled hardware remains available to restore")
                mouseClick(find(view,"latencyDetails-31")); wait(300)
                const latency=find(view,"latency-31-analog")
                latency.text="1.250"; latency.textEdited(); latency.editingFinished()
                check(test.actions[test.actions.length-1].action==="setLatencyOffset" && test.actions[test.actions.length-1].args.offset===1250,"precise latency converts milliseconds to microseconds")
                capture("06-hardware")
                // Retarget while exiting; latest requested page wins.
                view.page=0; wait(40); view.page=1; wait(40); view.page=2; wait(700)
                check(view.kind==="playback","rapid tab retarget opens playback")
                view.captureApps=false
                view.playback=[]; wait(300); capture("07-empty")
                view.error="El dispositivo se desconectó. Actualiza para volver a intentarlo."; capture("08-error")
                view.error=""; view.playback=[{id:"21",appName:"Firefox",mediaName:"Música",volume:0.38,mute:false,channels:test.channels,device:"11"}]
                Config.update({appearance:{fontScale:1.75,reduceMotion:true}})
                view.page=0; wait(400)
                scene.width=660; scene.height=720
                wait(300); capture("09-large-text")
                check(view.kind==="output","reduced resolves destination")
                check(find(view,"audioClose").x>=0,"close remains visible")
                const many=[]
                for(let i=0;i<15;i++) many.push(Object.assign({},test.output,{id:String(100+i),name:"device"+i,monitorSource:"device"+i+".monitor"}))
                view.outputs=many; wait(150)
                const endpointList=find(view,"audioEndpointList")
                endpointList.positionViewAtIndex(14,ListView.Contain); wait(250)
                check(view.meterSources.includes("device14.monitor"),"scrolled device beyond row12 is metered")
                view.active=false; check(view.meterSources.length===0,"hidden stops meters")
                console.log("PASS: audio surface devices, channels, mute, native keyboard, stable delegates, routes, capture, search, profiles, retarget, reduced, large text and hidden metering")
                Qt.quit()
            }
        }
    }
}
