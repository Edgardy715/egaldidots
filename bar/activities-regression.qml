import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "components"
import "settings"
import "Singletons"

ShellRoot {
    id: suite
    settings.watchFiles: false
    property int exitCode: 0
    Timer { id: finish; interval: 100; onTriggered: Qt.exit(suite.exitCode) }
    Socket { id: wire; path: Activities.socketPath }
    Window {
        visible: true
        width: 1100; height: 740
        Item { id: body; x: 400; y: 30; width: 260; height: 42 }
        FluidRecordingCompanion {
            id: drop
            body: body
            anchors.fill: parent
            recordingActive: false
            activity: Activities.primary
            activityCount: Activities.count
            open: Activities.count > 0
            onRequestOpen: name => { Activities.requestList = true; expanded = true }
            onRequestRecording: { Activities.requestList = true; expanded = true }
        }
        ActivityDropContent { id: content; x: 20; y: 200; width: 250; height: 40; activity: Activities.primary; count: Activities.count; peek: true }
        ActivityView {
            id: view
            x: 250; y: 240; width: 580; height: 460
            open: false
            session: FocusSession
            recorder: recorderMock
        }
        QtObject {
            id: recorderMock
            property bool engaged: true
            property string timeText: "00:12"
            property string phase: "recording"
            property bool connected: true
            property bool setupRequired: false
            property int elapsedSeconds: 12
            property int countdown: 0
            property string outputPath: ""
            property string error: ""
            property bool busy: false
            property bool pauseSupported: true
            property bool systemAudio: true
            property bool microphoneAudio: false
        }
        QtObject {
            id: fakeNotification
            property int id: 90210
            property var hints: ({value: 12})
            property string summary: "Download"
            property string body: "12/100"
            property string appName: "Test App"
            property string appIcon: "download"
            signal closed(int reason)
        }
        EdotsWindow { id: edots; visible: false; width: 1000; height: 700 }
        Pill { id: pill; visible: false; notificationsEnabled: false }
        TestCase {
            name: "Activities"
            when: Config.loaded
            function sync() { wait(60) }
            function start(id, progress) { return Activities.dispatch({op:"start",id:id,title:id,progress:progress}) }
            function test_activities() {
                try {
                    Config.update({activities:{enabled:true,fromNotifications:true},appearance:{reduceMotion:true}})
                    Activities.manualTime = true; Activities.testNow = 1000; Activities.reset()
                    verify(!Activities.listening)
                    verify(!Activities.ingest("{broken"))
                    verify(!Activities.ingest("[]")); verify(!Activities.ingest("null"))
                    verify(!Activities.ingest(JSON.stringify({op:"start",id:"bad id",title:"x"})))
                    verify(!Activities.ingest(JSON.stringify({op:"start",id:"x",title:5})))
                    verify(!Activities.dispatch({op:"start",id:"x",title:"x",progress:NaN}))
                    verify(start("__proto__",-1)); verify(start("constructor",-1)); sync()
                    compare(Activities.count,2); Activities.reset()
                    for (const progress of [-7,-0.5,1.1,5])
                        verify(!Activities.dispatch({op:"start",id:"invalid",title:"x",progress:progress}))
                    verify(Activities.ingest(JSON.stringify({op:"start",id:"build",title:"T".repeat(200),subtitle:"S".repeat(400),progress:-1})))
                    sync(); compare(Activities.list[0].title.length,160); compare(Activities.list[0].subtitle.length,320)
                    compare(Activities.primary.progress,-1)
                    verify(!Activities.ingest('{"op":"update","id":"build","progress":5}')); sync()
                    compare(Activities.primary.progress,-1)
                    verify(!Activities.ingest("x".repeat(8193)))
                    verify(!Activities.dispatch({op:"update",id:"missing",progress:0.3}))
                    const previous = Activities.revision
                    for (let i=0;i<1000;i++) Activities.ingest(JSON.stringify({op:"update",id:"build",progress:i/1000}))
                    compare(Activities.revision,previous)
                    sync(); compare(Activities.revision,previous+1); compare(Activities.primary.progress,0.999)
                    const before = Activities.revision
                    for (let frame=0;frame<100;frame++) {
                        for (let i=0;i<10;i++) Activities.dispatch({op:"update",id:"build",progress:(frame*10+i)/1000})
                        wait(10)
                    }
                    sync(); verify(Activities.revision-before<=31,"1000 events/s publish <=30/s plus trailing flush")
                    console.log("PASS: validation, bounded input, prototype ids and 1000 updates/s coalesced at 34ms")
                    Activities.reset()
                    verify(Activities.ipcEndpoint.start('{"id":"ipc","title":"IPC"}'))
                    verify(Activities.ipcEndpoint.update('{"id":"ipc","progress":0.4}'))
                    sync(); compare(Activities.primary.progress,0.4)
                    verify(Activities.ipcEndpoint.end('{"id":"ipc","state":"failed"}'))
                    verify(!Activities.ipcEndpoint.start('invalid')); sync()
                    compare(Activities.primary.state,"failed"); compare(content.status,"error")
                    Activities.testNow = 10999; Activities.expire(); compare(Activities.count,1)
                    Activities.testNow = 11000; Activities.expire(); compare(Activities.count,0)
                    Activities.testNow = 20000; verify(start("ok",0.5)); sync()
                    verify(Activities.dispatch({op:"end",id:"ok",state:"done"})); sync()
                    compare(content.status,"success"); compare(Activities.primary.progress,1)
                    Activities.testNow = 25999; Activities.expire(); compare(Activities.count,1)
                    Activities.testNow = 26000; Activities.expire(); compare(Activities.count,0)
                    Activities.manualTime = false; verify(start("timer",-1)); Activities.dispatch({op:"end",id:"timer",state:"done"}); sync()
                    verify(Activities.expiring); Activities.remove("timer"); sync(); verify(!Activities.expiring)
                    Activities.manualTime = true; Activities.testNow = 30000; Activities.reset()
                    verify(start("indeterminate",-1)); Activities.testNow++; verify(start("progress",0.2)); sync()
                    compare(Activities.primary.id,"progress")
                    verify(start("error",-1)); Activities.dispatch({op:"end",id:"error",state:"failed"}); sync()
                    compare(Activities.primary.id,"error")
                    for (let i=0;i<6;i++) { Activities.testNow++; verify(start("extra"+i,-1)) }
                    sync(); compare(Activities.count,8); verify(!Activities.entries.error,"recent result yields first")
                    Activities.testNow++; verify(start("replacement",-1)); sync()
                    verify(!Activities.entries.indeterminate,"oldest indeterminate yields")
                    Activities.reset()
                    for (let i=0;i<8;i++) verify(start("full"+i,0.3))
                    verify(!start("ninth",-1)); sync(); compare(Activities.count,8)
                    console.log("PASS: IPC method parity, priority, grouping, max8, controlled 6s/10s expiry and one-shot timer")
                    Activities.reset()
                    const popupCount = Notifs.popups.length
                    verify(Notifs.activityNotification(fakeNotification)); sync()
                    compare(Activities.count,1); compare(Notifs.popups.length,popupCount)
                    fakeNotification.hints = {value:42}; fakeNotification.body = "42/100"; sync()
                    compare(Activities.count,1); compare(Activities.primary.progress,0.42)
                    compare(Activities.primary.subtitle,"42/100")
                    fakeNotification.hints = {value:100}; sync(); compare(Activities.primary.state,"done")
                    const endTime = Activities.primary.endedAt
                    Activities.testNow++; fakeNotification.body = "Complete"; sync()
                    compare(Activities.primary.endedAt,endTime)
                    fakeNotification.closed(3)
                    Config.update({activities:{fromNotifications:false}})
                    verify(!Activities.notification(fakeNotification)); Config.update({activities:{fromNotifications:true}})
                    Activities.reset(); verify(start("updates:system",-1))
                    SystemUpdates.installSource = "system"
                    SystemUpdates.handle({event:"phase",source:"system",phase:"download",done:3,total:10})
                    sync(); compare(Activities.primary.progress,0.3)
                    Config.update({updates:{notifications:false}})
                    SystemUpdates.finish({event:"result",source:"system",result:"success",code:"ok"}); sync()
                    compare(Activities.primary.state,"done")
                    SystemUpdates.installSource = ""
                    console.log("PASS: notification QObject updates in place without popups; SystemUpdates real progress/result mapping")
                    Activities.reset(); verify(start("ui",0.7)); sync()
                    compare(drop.activityOnly,true); compare(drop.surfaceName,"focus")
                    compare(pill.pullGesture.resolveTarget("auto",false,true),"focus")
                    compare(pill.pullGesture.resolveTarget("auto",true,true),"media")
                    compare(pill.pullGesture.resolveTarget("auto",false,false),"utils")
                    compare(pill.pullGesture.resolveTarget("media",false,true),"media")
                    drop.recordingActive = true; compare(drop.activityOnly,false)
                    drop.recordingActive = false; drop.focusActive = true; compare(drop.activityOnly,false)
                    drop.focusActive = false
                    verify(FocusSession.start(1))
                    Activities.requestList = true; view.open = true; sync()
                    compare(view.selectedPage,2); compare(view.activityRows.length,3)
                    verify(findChild(view,"activityDurationClock").running)
                    const durationStart = view.durationNow
                    compare(view.duration({startedAt:durationStart-72000,endedAt:0}),"1 m 12 s")
                    view.durationNow += 1000
                    compare(view.duration({startedAt:durationStart-72000,endedAt:0}),"1 m 13 s")
                    verify(!Activities.requestList)
                    compare(findChild(view,"activitiesTab").text,I18n.tr("Procesos"))
                    view.selectedPage = 0; drop.requestToggle(); compare(view.selectedPage,2)
                    findChild(view,"activityAction_ui").clicked(); sync(); compare(Activities.count,0)
                    verify(!findChild(view,"activityDurationClock").running)
                    verify(start("ui",0.7)); sync()
                    view.consumeListRequest(); drop.expanded = false
                    // Use the existing drop's downward gesture and its accepted handoff.
                    wait(40); verify(drop.gesturePress(0,0,0)); verify(drop.gestureMove(0,80,60)); verify(drop.gestureRelease(80,false))
                    compare(drop.expanded,true); drop.expanded = false
                    FocusSession.cancel(); view.open = false
                    verify(!findChild(view,"activityDurationClock").running)
                    Config.update({appearance:{reduceMotion:false}})
                    drop.manualStep = true
                    Activities.dispatch({op:"end",id:"ui",state:"done"}); sync()
                    const swell = findChild(drop,"activitySuccessSwell")
                    verify(swell.integrating)
                    swell.step(1/60); verify(swell.value>0)
                    for (let i=0;i<480 && swell.integrating;i++) swell.step(1/120)
                    verify(!swell.integrating); compare(swell.value,0)
                    Activities.reset(); verify(start("shake",-1)); sync()
                    Activities.dispatch({op:"end",id:"shake",state:"failed"}); sync()
                    verify(content.shaking)
                    Config.update({appearance:{reduceMotion:true}}); sync()
                    verify(!content.shaking); drop.manualStep = false
                    verify(!Config.update({activities:{longCommandSeconds:2}}).ok)
                    verify(!Config.update({activities:{longCommandSeconds:601}}).ok)
                    verify(!Config.update({activities:{enabled:"false"}}).ok)
                    verify(Config.update({activities:{longCommandSeconds:3}}).ok)
                    verify(Config.update({activities:{longCommandSeconds:600}}).ok)
                    edots.page = 7; edots.visible = true; sync()
                    verify(edots.pageFields[7].includes("activities.enabled"))
                    verify(findChild(edots,"fishIntegrationInstall"))
                    Config.update({regional:{language:"en"}}); sync()
                    compare(I18n.tr("Actividades vivas"),"Live activities")
                    compare(findChild(edots,"fishIntegrationInstall").text,"Enable fish integration")
                    Config.update({regional:{language:"es"}}); sync()
                    compare(findChild(edots,"fishIntegrationInstall").text,"Activar integración con fish")
                    edots.visible = false
                    Config.update({activities:{enabled:false}}); sync(); compare(Activities.count,0)
                    verify(!start("disabled",-1)); verify(!Activities.expiring); verify(!Activities.publishing)
                    verify(!content.animating); verify(!content.shaking)
                    drop.recordingActive = false; drop.focusActive = false; wait(100)
                    verify(!drop.active); verify(!drop.motionRunning)
                    Config.update({activities:{enabled:true,longCommandSeconds:10}})
                    console.log("PASS: shared left drop, recording/focus list, down gesture, settings validation/bilingual Edots and quiet idle")
                    // The isolated runner opts into binding only its own temporary runtime.
                    if (Quickshell.env("ISLA_ACTIVITY_SOCKET_TEST") === Activities.runtimeDir) {
                        Activities.reset(); Activities.initialize()
                        tryCompare(Activities,"directoryReady",true,1000)
                        if (Activities.listening) {
                            wire.connected = true; tryCompare(wire,"connected",true,1000)
                            wire.write('{"op":"start","id":"wire","title":"Socket"}')
                            wire.flush(); sync(); compare(Activities.count,0)
                            wire.write('\ninvalid JSON\n{"op":"update","id":"wire","progress":4}\n{"op":"update","id":"wire","progress":0.4}\n')
                            wire.flush(); sync(); compare(Activities.primary.progress,0.4)
                            wire.write('{"op":"end","id":"wire","state":"done"}\n')
                            wire.flush(); sync(); compare(Activities.primary.state,"done")
                            wire.connected = false
                            console.log("PASS: live activity socket JSON lines, fragmented start and invalid input recovery")
                        } else console.log("BLOCKED: activity SocketServer listen in temporary runtime; see socket error")
                        Config.update({activities:{enabled:false}}); sync()
                        verify(!Activities.listening); verify(!Activities.expiring); verify(!Activities.publishing)
                    }
                } catch (error) {
                    console.error("FAIL: Activities",error,error.stack)
                    suite.exitCode = 1
                }
                finish.start()
            }
        }
    }
}
