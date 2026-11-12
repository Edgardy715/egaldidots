pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "components"
import "surfaces"
import "components/RubberBand.js" as RubberBand

ShellRoot {
    id: test
    settings.watchFiles: false
    property bool done: false
    property var policyDrop: null
    property bool policyFrozenOnOpen: false
    OverlayInputPolicy {
        id: policy
        monitorName: "test"; focusedMonitorName: "test"
        surface: router.openSurface
        pointerPull: test.policyDrop ? test.policyDrop.gestureCandidate : pill.pullGesture.candidate
    }
    Timer { interval: 20; running: test.done; onTriggered: Qt.quit() }
    SurfaceRouter { id: router; focusedMonitorName: "test" }
    Component {
        id: motionFactory
        PillMorphMotion { restW: 150; coreH: 38; targetW: 380; targetH: 72; targetRadius: 24; notifAnimating: true; manualStep: true }
    }
    Component {
        id: notifGestureFactory
        PillPullGesture {
            mode: "notification"
            manualStep: true
            plannedW: 380; plannedH: 540; plannedRadius: 24
            rubberBand: (v, l) => RubberBand.rubberBand(v, l, 0.55)
            property string action: ""
            onNotificationFinished: value => {
                action = value
                if (value === "dismiss") { motion.notifAnimating = false; motion.targetW = 150; motion.targetH = 38 }
            }
            onSettled: (name, opened) => {
                if (opened) { motion.notifAnimating = false; motion.surfaceOpen = true; motion.targetW = 380; motion.targetH = 540 }
            }
        }
    }
    Component { id: mediaFactory; FluidMediaCompanion { gestureDismissable: true; body: body; manualStep: true; gestureTrack: "one"; gesturePlayer: null; width: 1000; height: 800; gesturesEnabled: true; open: !dismissedUntilTrackChange
        onRequestOpen: name => { if (!router.openFromDrop("test", name)) return
            test.policyFrozenOnOpen = policy.pointerPull && !policy.kbFocusWanted && policy.maskMode === "pill"
            expanded = true } } }
    Component { id: protectedFactory; FluidRecordingCompanion { body: body; manualStep: true; width: 1000; height: 800; gesturesEnabled: true; onRequestOpen: name => { if (!router.openFromDrop("test", name)) return
        test.policyFrozenOnOpen = policy.pointerPull && !policy.kbFocusWanted && policy.maskMode === "pill"
        expanded = true } } }
    Window {
        id: scene
        width: 1000; height: 800; visible: true
        Item { id: body; x: 350; y: 10; width: 150; height: 38 }
        Pill {
            id: pill
            x: 100; y: 100
            notificationsEnabled: true
            pullMotion.manualStep: true
            onPullSettled: (name, opened) => surface = opened ? name : ""
        }
        TestCase {
            name: "DropGestures"
            when: scene.visible && Config.loaded && Notifs.loaded
            function check(ok, message) { if (!ok) { console.error("FAIL:", message); Qt.exit(1); throw new Error(message) } }
            function near(a, b, message, epsilon) { check(Math.abs(a - b) <= (epsilon || 0.01), message + " actual=" + a + " expected=" + b) }
            function cleanupTestCase() { test.done = true }
            function pair() {
                const m = motionFactory.createObject(scene.contentItem)
                m.springW = 380; m.springH = 72
                const g = notifGestureFactory.createObject(test, {motion: m})
                return {m: m, g: g}
            }
            function remove(p) { p.g.destroy(); p.m.destroy() }
            function seed(d) {
                d.wPos = 42; d.hPos = 38; d.captureExtra = 0; d.captureV = 0; d.captureTarget = 0
                d.xPos = d.capX + (d.capRadius + 19) - 21
                d.yPos = d.capY - 19
                d.targetX = d.xPos; d.targetY = d.yPos; d.targetW = 42; d.targetH = 38
                d.vx = 0; d.vy = 0; d.vw = 0; d.vh = 0
                d.phase = "companion"; d.concealed = false; d.bond = true
            }
            function test_notification_contract() {
                Config.update({appearance: {reduceMotion: false, motionScale: 1, notificationDrop: false}, gestures: {enabled: true}})
                let p = pair(), g = p.g, m = p.m
                g.press(0, 0, 0, false, ""); g.move(0, -10, 100)
                near(m.height, 62, "notification up tracks height 1:1")
                g.release(250); check(g.action === "return", "slow short up returns")
                m.step(1/120); m.step(2); near(m.height, 72, "notification spring returns to height", 0.2); remove(p)
                p = pair(); g = p.g; m = p.m
                g.press(0, 0, 0, false, ""); g.move(0, -15, 100); g.release(250)
                check(g.action === "dismiss", "up beyond 40 percent dismisses")
                m.step(1/120); m.step(2); near(m.height, 38, "dismiss spring reaches rest", 0.2); remove(p)
                p = pair(); g = p.g; m = p.m
                g.press(0, 0, 0, false, ""); g.move(0, -8, 10); g.release(10)
                check(g.action === "dismiss" && g.velocityH < -350, "short upward fling dismisses")
                const v = m.velH, h = m.height; m.step(1/120); near((m.height-h)*120, v, "notification inherits release velocity", Math.abs(v)*0.1); remove(p)
                for (const sign of [-1, 1]) {
                    p = pair(); g = p.g; m = p.m
                    g.press(0,0,0,false,""); g.move(sign*100,0,500)
                    near(g.contentOffset,sign*100,"horizontal content follows hand")
                    g.release(700); check(g.action === "return", "short horizontal returns")
                    near(g.contentOffset,sign*100,"horizontal release does not snap")
                    g.stepContent(1/120); g.stepContent(2); near(g.contentOffset,0,"horizontal spring returns",0.2)
                    remove(p)
                    p = pair(); g = p.g; m = p.m
                    g.press(0,0,0,false,""); g.move(sign*180,0,500); g.release(700)
                    check(g.action === "" && m.grabbed,"container waits for outgoing text")
                    for(let i=0;i<300 && !g.action;i++)g.stepContent(1/120)
                    check(g.action === "dismiss" && Math.abs(g.contentOffset)>=m.width*0.65,"horizontal text leaves before collapse in both directions")
                    for(let i=0;i<300 && g.contentMotion.integrating;i++)g.stepContent(1/120)
                    check(!g.contentMotion.integrating,"outgoing text spring stops at rest");remove(p)
                }
                p=pair();g=p.g;m=p.m
                g.press(0,0,0,false,"");g.move(0,300,500)
                near(m.height,372,"notification down grows 1:1");g.release(700)
                check(g.action === "open" && m.surfaceOpen,"down opens notifs");m.step(1/120); m.step(2);near(m.height,540,"notifs settles",0.2);remove(p)
            }
            function test_drops() {
                let d=mediaFactory.createObject(scene.contentItem);seed(d)
                d.gesturePress(0,0,0);d.gestureMove(8,0,20);near(d.xPos-d.gestureX,8,"media outward 1:1")
                d.gestureMove(10,0,40);check(d.bond && d.stretch<1.30,"bond holds below break")
                d.gestureRelease(40,false);check(!d.dismissedUntilTrackChange,"below break returns")
                const v=d.vx,x=d.xPos;check(v>0,"return has measured velocity");d.advanceMotion(1/120);near((d.xPos-x)*120,v,"drop velocity inherited within 10 percent",Math.abs(v)*0.1)
                // Interrupt a running spring without changing its position.
                const caught=d.xPos;d.gesturePress(0,0,100);near(d.xPos,caught,"catch position continuous");d.gestureRelease(110,true)
                seed(d);d.gesturePress(0,0,0);d.gestureMove(30,0,100);check(!d.bond && d.stretch>=1.30,"break at 1.30")
                d.gestureRelease(200,false);check(d.dismissedUntilTrackChange && d.phase==="residual","media hides with residual")
                for(let i=0;i<500;i++)d.advanceMotion(1/120)
                near(d.wPos,6,"microdrop settles");check(d.settled,"residual rests silently");check(!d.bond && !d.joined && !d.active,"dismissed residue leaves no neck on the pill")
                d.gestureTrack="two";check(!d.dismissedUntilTrackChange,"next track restores media")
                seed(d);d.gesturePress(0,0,0);d.gestureMove(30,0,100);d.gestureRelease(200,false)
                d.gesturePlayer={name:"next"};check(!d.dismissedUntilTrackChange,"next player restores media")
                // Hysteresis uses actual geometry, with no new thresholds.
                seed(d);d.bond=false;d.xPos=d.capX+1.03*(d.capRadius+d.dropRadius)-d.wPos/2;d.updateBond();check(!d.bond,"unjoined above 1.02")
                d.xPos=d.capX+1.01*(d.capRadius+d.dropRadius)-d.wPos/2;d.updateBond();check(d.bond,"joins below 1.02")
                d.xPos=d.capX+1.29*(d.capRadius+d.dropRadius)-d.wPos/2;d.updateBond();check(d.bond,"joined below 1.30")
                d.destroy()
                for(const name of ["media","recording","focus","session"]) {
                    d=name==="media" ? mediaFactory.createObject(scene.contentItem)
                        : protectedFactory.createObject(scene.contentItem,{surfaceName:name,focusActive:name==="focus"})
                    test.policyDrop=d;seed(d)
                    if(name!=="media") {
                        d.gesturePress(0,0,0);d.gestureMove(-1000,0,100)
                        check(d.xPos-d.gestureX>0 && d.xPos-d.gestureX<14,"protected left drop rubber L14")
                        d.gestureRelease(200,false);check(!d.gestureDismissed && !d.concealed,"protected drop never hides")
                    }
                    seed(d);d.gesturePress(0,0,0);d.gestureMove(0,25,100);d.gestureRelease(200,false)
                    check(router.openSurface===name && d.phase==="brotando","down opens route through bud "+name)
                    check(test.policyFrozenOnOpen,"opening holds keyboard focus and mask through release")
                    check(policy.kbFocusWanted && policy.maskMode==="full","focus and mask settle after release")
                    let phases=[d.phase];for(let i=0;i<500;i++){d.advanceMotion(1/120);if(phases[phases.length-1]!==d.phase)phases.push(d.phase)}
                    check(phases.join(",")==="brotando,media","bud phase sequence "+name)
                    check(d.settled,"card rests");test.policyDrop=null;d.destroy();router.close()
                }
                router.present("test","auth")
                d=protectedFactory.createObject(scene.contentItem);seed(d)
                d.gesturePress(0,0,0);d.gestureMove(0,25,100)
                check(!d.gestureRelease(200,false) && router.openSurface==="auth" && d.phase==="companion","denied route returns drop without orphan card")
                d.destroy();router.close()
            }
            function test_pointer_click_hover_drag() {
                Config.update({appearance:{reduceMotion:false},gestures:{enabled:true}})
                const d=mediaFactory.createObject(scene.contentItem);seed(d)
                let clicks=0;d.requestToggle.connect(()=>clicks++)
                const x=d.visualX+d.wPos/2,y=d.yPos+d.hPos/2
                mouseMove(scene.contentItem,x,y,20);wait(20)
                check(d.hovered,"real hover still reaches compact drop")
                mouseClick(scene.contentItem,x,y,Qt.LeftButton,Qt.NoModifier,20)
                check(clicks===1 && !d.gestureCandidate,"real click remains unchanged")
                seed(d)
                mousePress(scene.contentItem,x,y,Qt.LeftButton,Qt.NoModifier,20)
                check(d.gestureCandidate,"real pointer press catches drop")
                mouseMove(scene.contentItem,x+8,y,30);mouseMove(scene.contentItem,x+10,y,30)
                check(d.gestureActive,"real pointer drag takes over click")
                near(d.xPos-d.gestureX,10,"real pointer drag follows stable scene coordinates")
                mouseRelease(scene.contentItem,x+10,y,Qt.LeftButton,Qt.NoModifier,20)
                check(!d.gestureCandidate && clicks===1,"drag release suppresses click")
                for(let i=0;i<500;i++)d.advanceMotion(1/120)
                d.manualStep=false;wait(30)
                check(d.settled && !d.motionRunning,"drop stops frame clock at rest")
                d.destroy()
            }
            function test_reduced_and_disabled() {
                Config.update({appearance:{reduceMotion:true}})
                let d=mediaFactory.createObject(scene.contentItem);seed(d)
                const x=d.xPos;d.gesturePress(0,0,0);d.gestureMove(40,0,100);near(d.xPos,x,"reduced has no stretch")
                d.gestureRelease(200,false);check(d.dismissedUntilTrackChange && d.phase==="idle" && d.concealed,"reduced discard has no residue");d.destroy()
                d=protectedFactory.createObject(scene.contentItem);seed(d);d.gesturePress(0,0,0);d.gestureMove(-1000,0,100);d.gestureRelease(200,false);check(!d.gestureDismissed,"reduced protected remains")
                d.gesturesEnabled=false;check(!d.gesturePress(0,0,0),"disabled drop rejects press");d.destroy()
                let p=pair();p.g.reduceMotion=true;p.g.press(0,0,0,false,"");p.g.move(0,-20,100);near(p.m.height,72,"reduced notification stays until release");p.g.release(200);check(p.g.action==="dismiss","reduced notification resolves");remove(p)
                p=pair();p.g.reduceMotion=true;p.g.press(0,0,0,false,"");p.g.move(180,0,500);near(p.g.contentOffset,0,"reduced horizontal has no travel");p.g.release(700);check(p.g.action==="dismiss" && !p.g.pendingNotificationAction,"reduced horizontal dismisses immediately");remove(p)
                p=pair();p.g.reduceMotion=true;p.g.press(0,0,0,false,"");p.g.move(0,300,500);near(p.m.height,72,"reduced down waits until release");p.g.release(700);check(p.g.action==="open" && p.m.surfaceOpen,"reduced down opens destination");remove(p)
                p=pair();p.g.enabled=false;check(!p.g.press(0,0,0,false,""),"disabled notification rejects press");remove(p)
                Config.update({appearance:{reduceMotion:false}})
                for(const setting of ["reduceMotion","enabled"]) {
                    p=pair();p.g.press(0,0,0,false,"");p.g.move(180,0,500);p.g.release(700)
                    check(p.g.pendingNotificationAction==="dismiss","horizontal discard is in flight")
                    if(setting==="reduceMotion")p.g.reduceMotion=true;else p.g.enabled=false
                    check(p.g.action==="dismiss" && !p.g.pendingNotificationAction && !p.m.grabbed,"setting change resolves pending discard "+setting)
                    remove(p)
                }
            }
            function test_expiration_and_real_pill() {
                Config.update({appearance:{notificationDrop:false,reduceMotion:false}})
                Notifs.clearAll();Notifs.postLocal("gesture timing","body",[],"gesture-test")
                const n=Notifs.list[0];n.lock(test);n.expireTimeout=5000
                tryVerify(()=>pill.activeNotif===n && pill.notifState==="hold",3000)
                // Timer was already running before press: pause both expiration
                // and choreography, including a hold longer than the timeout.
                n.expireTimeout=400;n.expireTimer.restart();wait(70)
                pill.pullGesture.press(0,0,Date.now(),false,"")
                check(!n.expireTimer.running,"expiration stops on press");const interval=n._expirationRemaining
                wait(450);check(n.popup && pill.notifState==="hold","expiration and hold paused")
                pill.pullGesture.move(0,-8,Date.now());wait(150);pill.pullGesture.release(Date.now())
                check(!n.closed && n.expireTimer.running,"short release resumes expiry")
                check(n.expireTimer.interval<=interval+2 && n.expireTimer.interval>0,"remaining expiry preserved")
                wait(n.expireTimer.interval+60);check(!n.popup,"remaining expiry actually fires")
                n.unlock(test);n.close()
                console.log("PASS: expiration pause/resume and live Pill notification wiring")
            }
            function test_real_notification_routes() {
                Config.update({appearance:{notificationDrop:false,reduceMotion:false}})
                for(const direction of ["up","horizontal","down"]) {
                    pill.surface="";Notifs.clearAll();Notifs.postLocal("touched "+direction,"",[],"route-"+direction)
                    const n=Notifs.list[0];n.lock(test);n.expireTimeout=5000
                    tryVerify(()=>pill.activeNotif===n && pill.notifState==="hold",3000)
                    // Start at the held target, without relying on a wall-clock animation.
                    pill.pullMotion.springW=pill.targetW;pill.pullMotion.springH=pill.targetH
                    const g=pill.pullGesture,m=pill.pullMotion;g.manualStep=true
                    near(g.contentOffset,0,"new notification clears preceding horizontal displacement")
                    if(direction==="horizontal") {
                        const x=pill.x+pill.width/2,y=pill.y+pill.height/2
                        mousePress(scene.contentItem,x,y,Qt.LeftButton,Qt.NoModifier,20)
                        check(g.candidate,"real notification pointer press catches")
                        mouseMove(scene.contentItem,x+8,y,30);mouseMove(scene.contentItem,x+180,y,400)
                        near(g.contentOffset,152+RubberBand.rubberBand(28,40,0.55),"real notification pointer follows horizontal hand")
                        mouseRelease(scene.contentItem,x+180,y,Qt.LeftButton,Qt.NoModifier,200)
                        for(let i=0;i<300 && g.pendingNotificationAction;i++)g.stepContent(1/120)
                        check(n.closed,"real pointer dismiss closes Notifs entry")
                    } else if(direction==="down") {
                        g.press(0,0,0,false,"")
                        Notifs.postLocal("newer queued","",[],"newer")
                        g.move(0,300,500);g.release(700)
                        check(pill.surface==="notifs" && Notifs.list[0]===n && !n.popup && !n.closed,"real down promotes touched notification and opens center")
                    } else {
                        g.press(0,0,0,false,"");g.move(0,-20,500);g.release(700)
                        check(n.closed,"real dismiss closes Notifs entry "+direction)
                    }
                    m.step(1/120);m.step(2);wait(1)
                    check(!m.integrating && !m.grabbed,"real notification spring settles "+direction)
                    check(!pill.notificationResolving,"notification queue unblocks after settling")
                    n.unlock(test);pill.surface="";Notifs.clearAll();wait(1)
                }
            }
            function test_zz_finish() { console.log("PASS: notification gestures, drop tracking/hysteresis/velocity/residue/reset, protected drops, bud phases, reduced motion, disabled and silent rest") }
        }
    }
}
