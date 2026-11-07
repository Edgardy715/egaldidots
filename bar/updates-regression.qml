import QtQuick
import QtTest
import Quickshell
import "Singletons"
import "settings"

ShellRoot {
    settings.watchFiles: false
    property int exitCode: 0
    Timer { id: finish; interval: 250; onTriggered: Qt.exit(exitCode) }
    QtObject {
        id: backend
        property bool busy: false
        property string operation: "check"
        property string error: ""
        property string feedback: ""
        property int refreshed: 0
        property string installed: ""
        property string installSource: ""
        property var progress: ({})
        property var outcomes: ({})
        property bool cancelling: false
        property int cancelled: 0
        readonly property int count: 4
        property var result: ({checkedAt:"2026-10-29T12:00:00Z", snapshots:true,
            system:{count:2,packages:["linux-cachyos 6.18 -> 6.19", "firefox 140 -> 141"]},
            aur:{count:1,packages:["example-app 1 -> 2"]},
            flatpak:{count:0,supported:false,error:""},
            shell:{count:1,dirty:true,blocked:"dirty",error:""}})
        function refresh() { refreshed++ }
        function install(source) { installed = source }
        function cancel() { cancelled++ }
        function installable(source) { const s = result[source]; return !!s && s.count > 0 && !s.error && !s.blocked }
    }
    Window {
        id: window
        visible: true; width: 1000; height: 700
        color: Theme.background
        Rectangle { anchors.fill: parent; color: Theme.background }
        EdotsWindow { id: editor; anchors.fill: parent; updatesController: backend }
        TestCase {
            when: Config.loaded && window.visible
            property bool finished: false
            function assert(ok, message) { if (!ok) throw new Error(message) }
            function capture(name) {
                window.contentItem.grabToImage(result => result.saveToFile(Quickshell.env("ISLA_TEST_OUTPUT") + "/" + name + ".png"))
                wait(300)
            }
            function test_updates() {
                if (finished) return
                finished = true
                try {
                    for (const scale of [1, 1.75]) {
                        Config.update({appearance:{fontScale:scale,reduceMotion:true}})
                        for (const size of [{w:1000,h:700},{w:640,h:560}]) {
                            window.width=size.w; window.height=size.h
                            editor.systemTab="updates"; editor.page=5; wait(350)
                            const page=findChild(editor,"updatesPage")
                            const scroll=findChild(editor,"updatesScroll")
                            const tab=findChild(editor,"settingsNav5")
                            assert(page.visible, "updates page shown")
                            assert(tab.width >= 44 && tab.height >= 44 && tab.mapToItem(editor,0,tab.height).y <= editor.height,"navigation fits")
                            assert(scroll.height>80,"usable scroll viewport: "+scroll.height)
                            assert(!findChild(editor,"updatesInstall-shell").enabled,"dirty Git protected")
                            assert(!findChild(editor,"updatesInstall-flatpak").enabled,"absent source disabled")
                            assert(findChild(editor,"updatesInstall-system").enabled,"available update enabled")
                            scroll.contentItem.contentY=0; wait(50)
                            capture("updates-"+size.w+"-font-"+scale)
                            scroll.contentItem.contentY=Math.max(0,scroll.contentItem.contentHeight-scroll.height); wait(100)
                            const preference=findChild(editor,"updatesSetting-enabled")
                            assert(preference.mapToItem(scroll,0,0).y < scroll.height,"preferences reachable")
                            capture("updates-bottom-"+size.w+"-font-"+scale)
                        }
                    }
                    Config.update({appearance:{fontScale:1}})
                    window.width=1000; window.height=700; wait(200)
                    const preference=findChild(editor,"updatesSetting-enabled")
                    mouseClick(findChild(preference,"settingToggle")); wait(50)
                    assert(!Config.updates.enabled,"preference edit delegated to Config")
                    Config.discard(); wait(50)
                    assert(Config.updates.enabled,"preference discarded")
                    findChild(editor,"updatesScroll").contentItem.contentY=0; wait(100)
                    mouseClick(findChild(editor,"updatesRefresh")); wait(50)
                    assert(backend.refreshed===1,"check action delegated")
                    mouseClick(findChild(editor,"updatesInstall-system")); wait(50)
                    assert(backend.installed==="system","install action delegated")
                    backend.busy=true; wait(50)
                    assert(!findChild(editor,"updatesRefresh").enabled && !findChild(editor,"updatesInstall-system").enabled,"busy controls disabled")
                    backend.busy=false; backend.error="Consulta fallida"; wait(50)
                    assert(findChild(editor,"updatesFeedback").text==="Consulta fallida","error visible")
                    editor.searchQuery="flatpak"; wait(150)
                    const hit=findChild(editor,"updatesSearchResult")
                    assert(hit.visible,"search discovers portal")
                    // The results slide in; click once they have landed, not mid-travel.
                    const pageMotion=findChild(editor,"settingsPageMotion"); assert(!!pageMotion,"page motion reachable")
                    tryVerify(() => !pageMotion.transitioning, 2000, "search results settled")
                    mouseClick(hit); wait(150)
                    assert(editor.page===5 && editor.systemTab==="updates" && !editor.searchQuery,"search opens portal")
                    backend.error=""; editor.systemTab="updates"; editor.page=5; editor.searchQuery=""
                    Config.update({appearance:{fontScale:1,reduceMotion:false}})
                    wait(650)
                    const scroll=findChild(editor,"updatesScroll")
                    scroll.contentItem.contentY=0
                    const disclosure=findChild(editor,"updatesPackages-system")
                    const packages=findChild(editor,"updatesPackageList-system")
                    mouseClick(disclosure); wait(70)
                    assert(packages.reveal>0 && packages.reveal<1,"package reveal has intermediate state")
                    capture("packages-opening")
                    tryCompare(packages,"reveal",1,1000)
                    mouseClick(disclosure); wait(55)
                    const partial=packages.reveal
                    assert(partial>0 && partial<1,"collapse has intermediate state")
                    mouseClick(disclosure)
                    assert(Math.abs(packages.reveal-partial)<0.15,"reversal preserves current geometry")
                    tryCompare(packages,"reveal",1,1000)
                    capture("packages-expanded")
                    mouseClick(disclosure); wait(40)
                    Config.update({appearance:{reduceMotion:true}}); wait(30)
                    assert(packages.reveal===0,"reduced motion settles in-flight disclosure")
                    mouseClick(disclosure); wait(20)
                    assert(packages.reveal===1,"reduced motion expands immediately")
                    Config.update({appearance:{reduceMotion:false}})
                    backend.busy=true; wait(100)
                    const spinner=findChild(editor,"updatesActivity")
                    assert(spinner.status==="busy" && spinner.animating,"activity runs during visible check")
                    capture("checking")
                    mouseClick(disclosure); wait(40)
                    window.visible=false; wait(50)
                    assert(!spinner.animating,"hidden window stops activity")
                    assert(packages.reveal===0,"hidden window settles disclosure")
                    window.visible=true; wait(150)
                    editor.page=0; wait(650)
                    assert(!spinner.animating,"hidden portal stops activity")
                    editor.systemTab="updates"; editor.page=5; wait(650)
                    Config.update({appearance:{reduceMotion:true}}); wait(30)
                    assert(!spinner.animating,"reduced motion stops activity")
                    assert(findChild(editor,"updatesMessage-shell").text.includes("cambios locales"),"paused Git explains itself")
                    assert(findChild(editor,"updatesState-shell").color!==Theme.error,"paused Git is not an error")
                    backend.operation="install"; backend.installSource="system"
                    backend.progress={event:"phase",source:"system",phase:"download",done:3,total:9,cancellable:true}; wait(30)
                    assert(findChild(editor,"updatesHeadline").text==="Descargando 3 de 9","install headline shows real progress")
                    assert(spinner.status==="progress" && spinner.progress>0.1 && spinner.progress<0.45,"determinate ring: "+spinner.progress)
                    const cancel=findChild(editor,"updatesCancel-system")
                    assert(cancel.visible && cancel.enabled && !findChild(editor,"updatesInstall-system").visible,"cancel replaces install")
                    mouseClick(cancel); wait(30)
                    assert(backend.cancelled===1,"cancel delegated")
                    capture("installing-download")
                    backend.progress={event:"phase",source:"system",phase:"install",done:1,total:9,cancellable:false}; wait(30)
                    assert(!cancel.enabled,"no cancel after commit")
                    assert(findChild(editor,"updatesMessage-system").text.includes("No apagues"),"commit warns about power")
                    capture("installing-commit")
                    backend.busy=false; backend.operation=""; backend.installSource=""; backend.progress={}
                    backend.outcomes={system:{result:"error",code:"partial",snapshot:"42",reboot:false}}; wait(30)
                    assert(findChild(editor,"updatesMessage-system").text.includes("punto de restauración 42"),"partial failure names the restore point")
                    assert(findChild(editor,"updatesInstall-system").text==="Reintentar","failure offers retry")
                    capture("install-partial")
                    backend.outcomes={system:{result:"cancelled",code:"cancelled"}}; wait(30)
                    assert(findChild(editor,"updatesMessage-system").text==="Actualización cancelada. No se ha cambiado nada.","friendly cancel")
                    backend.outcomes={system:{result:"success",reboot:true}}; wait(30)
                    assert(findChild(editor,"updatesMessage-system").text.includes("Reinicia"),"reboot hint after kernel update")
                    backend.outcomes={}
                    const failed=JSON.parse(JSON.stringify(backend.result))
                    failed.aur.error="network"; backend.result=failed; wait(30)
                    assert(findChild(editor,"updatesHeadline").text==="La consulta necesita atención","partial failure is not success")
                    assert(findChild(editor,"updatesMessage-aur").text.startsWith("Sin conexión"),"friendly check error")
                    capture("partial-error")
                    Config.update({appearance:{reduceMotion:false}})
                    editor.page=0; wait(35); editor.systemTab="updates"; editor.page=5; wait(40); editor.page=2; wait(25); editor.systemTab="updates"; editor.page=5; wait(650)
                    assert(findChild(editor,"updatesPage").visible,"rapid navigation ends at requested page")
                    Config.discard()
                    console.log("PASS: Updates UI, actions, protections, search and responsive layout")
                    finish.start()
                } catch(error) { console.error("FAIL: Updates UI",error); exitCode=1; finish.start() }
            }
        }
    }
}
