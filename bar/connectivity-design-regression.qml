import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    id: test
    settings.watchFiles: false
    property var actions: []
    property var home: ({ssid:"Casa · Estudio", active:true, isSecure:true, strength:88})
    property var guest: ({ssid:"Invitados", active:false, isSecure:false, strength:62})
    property var secure: ({ssid:"Una red protegida con un nombre extremadamente largo", active:false, isSecure:true, strength:41})
    property var headphones: ({deviceName:"Auriculares de estudio", name:"Auriculares de estudio", address:"AA:BB", connected:true, paired:true, bonded:true, pairing:false, state:0, batteryAvailable:true, battery:0.72})
    property var keyboard: ({deviceName:"Teclado inalámbrico", name:"Teclado inalámbrico", address:"CC:DD", connected:false, paired:true, bonded:true, pairing:false, state:0, batteryAvailable:false, battery:0})
    property var speaker: ({deviceName:"Altavoz del salón", name:"Altavoz del salón", address:"EE:FF", connected:false, paired:false, bonded:false, pairing:false, state:0, batteryAvailable:false, battery:0})
    Window {
        id: scene
        visible: true
        width: IslandGeometry.connectivitySurface.width
        height: IslandGeometry.connectivitySurface.height
        minimumWidth: IslandGeometry.connectivitySurface.width
        maximumWidth: IslandGeometry.connectivitySurface.width
        minimumHeight: IslandGeometry.connectivitySurface.height
        maximumHeight: IslandGeometry.connectivitySurface.height
        color: Theme.background
        Rectangle { anchors.fill: parent; color: Theme.background }
        ConnectivityView {
            id: view
            anchors.fill: parent
            anchors.margins: 24
            open: true
            wifiEnabled: true
            networks: [test.home, test.guest, test.secure]
            activeSsid: test.home.ssid
            btEnabled: true
            devices: [test.headphones, test.keyboard, test.speaker]
            onWifiToggleRequested: test.actions.push(["wifi-toggle"])
            onWifiScanRequested: test.actions.push(["wifi-scan"])
            onWifiDisconnectRequested: test.actions.push(["wifi-disconnect"])
            onNetworkRequested: network => test.actions.push(["network",network])
            onBluetoothToggleRequested: test.actions.push(["bt-toggle"])
            onBluetoothDiscoveryToggleRequested: test.actions.push(["bt-scan"])
            onBluetoothActionRequested: (device, action) => test.actions.push([action,device])
            onPasswordSubmitRequested: secret => test.actions.push(["password",secret])
            onPasswordCancelRequested: test.actions.push(["password-cancel"])
        }
        TestCase {
            id: checks
            name: "ConnectivityDesign"
            when: scene.visible && Config.loaded
            function named(name) {
                const found=findChild(view,name)
                if(!found) console.error("FAIL: missing",name)
                verify(found !== null,"missing " + name)
                return found
            }
            function expose(item) {
                const list=named("connectivityScroll")
                let ancestor=item.parent
                while(ancestor && ancestor !== list) ancestor=ancestor.parent
                if(ancestor === list) {
                    const pos=item.mapToItem(list,0,0)
                    if(pos.y < 0) list.contentY+=pos.y-8
                    else if(pos.y+item.height > list.height) list.contentY+=pos.y+item.height-list.height+8
                    wait(80)
                }
            }
            function click(name) {
                const item=named(name)
                expose(item)
                verify(item.enabled && item.visible,"control unavailable " + name)
                mouseClick(item,item.width/2,item.height/2)
            }
            function last(action) {
                const actual=test.actions.length ? test.actions[test.actions.length-1][0] : "none"
                if(actual !== action) console.error("FAIL: expected action",action,"got",actual)
                compare(actual,action)
            }
            function capture(name) {
                const out=Quickshell.env("ISLA_TEST_OUTPUT")
                if (!out) return
                grabImage(scene.contentItem).save(out+"/"+name+".png")
            }
            function test_redesign() {
                verify(Config.update({appearance:{fontScale:1,reduceMotion:false}}).ok)
                wait(650)
                capture("01-wifi")
                click("wifiToggle"); last("wifi-toggle")
                click("wifiScan"); last("wifi-scan")
                click("wifiDisconnect"); last("wifi-disconnect")
                click("network-Invitados"); last("network")
                compare(test.actions[test.actions.length-1][1],test.guest)
                view.wifiScanning=true
                capture("02-scanning")
                view.wifiScanning=false
                click("mode-bluetooth")
                wait(60); capture("03-switch")
                wait(600)
                capture("04-bluetooth")
                click("bluetoothToggle"); last("bt-toggle")
                click("bluetoothScan"); last("bt-scan")
                click("bluetooth-action-Auriculares de estudio"); last("disconnect")
                click("bluetooth-action-Teclado inalámbrico"); last("connect")
                click("bluetooth-action-Altavoz del salón"); last("pair")
                click("bluetooth-forget-Teclado inalámbrico"); last("forget")
                for (let i=0;i<4;i++) {
                    view.mode="wifi"; wait(40)
                    view.mode="bluetooth"; wait(40)
                }
                wait(600)
                compare(view.presentedMode,"bluetooth")
                compare(view.contentExposure,1)
                verify(named("bluetoothScan").enabled)
                view.btEnabled=false; wait(250); capture("05-disabled")
                // Scan is absent while the radio is disabled.
                verify(!view.radioEnabled)
                view.btEnabled=true; view.devices=[]; wait(200); capture("06-empty")
                view.devices=[test.headphones,test.keyboard,test.speaker]
                verify(Config.update({appearance:{fontScale:1.5}}).ok)
                wait(650); capture("07-large-text")
                const btAction=named("bluetooth-action-Auriculares de estudio")
                const pos=btAction.mapToItem(view,0,0)
                verify(pos.x >= 0 && pos.x+btAction.width <= view.width+1,"Bluetooth action bounds")
                named("mode-wifi").forceActiveFocus()
                let reached = false
                for (let step = 0; step < 18; step++) {
                    keyClick(Qt.Key_Tab)
                    wait(30)
                    const focus=scene.activeFocusItem
                    if (!focus || focus.objectName.indexOf("bluetooth-action-") !== 0) continue
                    const list=named("connectivityScroll")
                    const point=focus.mapToItem(list,0,0)
                    verify(point.y >= -1 && point.y+focus.height <= list.height+1,"Tab reveals Bluetooth action")
                    if (focus.objectName === "bluetooth-action-Altavoz del salón") { reached=true; break }
                }
                verify(reached,"Tab reaches last device without manual scroll")
                capture("07b-keyboard-last-device")
                for (let step=0; step<8; step++) {
                    keyClick(Qt.Key_Tab,Qt.ShiftModifier); wait(30)
                    const focus=scene.activeFocusItem
                    if (!focus || focus.objectName.indexOf("bluetooth-action-") !== 0) continue
                    const list=named("connectivityScroll")
                    const point=focus.mapToItem(list,0,0)
                    verify(point.y >= -1 && point.y+focus.height <= list.height+1,"Shift Tab reveals Bluetooth action")
                }
                btAction.forceActiveFocus()
                wait(150)
                verify(btAction.activeFocus,"Bluetooth action keyboard focus")
                keyClick(Qt.Key_Space); last("disconnect")
                view.mode="wifi"; wait(500)
                view.passwordNetwork=test.secure; view.showPasswordDialog=true
                wait(500); capture("08-password")
                const credentials=named("connectivityCredentials")
                verify(credentials.input.activeFocus)
                credentials.input.text="fixture-password"
                credentials.submit(); last("password")
                compare(credentials.input.text,"")
                view.passwordError=qsTr("Contraseña incorrecta. Inténtalo de nuevo.")
                wait(500); capture("09-password-error")
                view.passwordError=""; view.passwordConnecting=true
                wait(250); capture("10-password-busy")
                verify(!credentials.input.enabled || credentials.input.readOnly)
                view.passwordConnecting=false; view.passwordSucceeded=true
                wait(350); capture("11-password-success")
                view.showPasswordDialog=false
                verify(Config.update({appearance:{reduceMotion:true,fontScale:1}}).ok)
                view.mode="bluetooth"; wait(50)
                verify(named("bluetoothScan").enabled)
                view.open=false; wait(50); view.open=true; wait(100)
                capture("12-reduced-reopen")
                console.log("PASS: connectivity design actions, mode retargeting, disabled/empty, large type, credentials and reduced reopening")
                Qt.quit()
            }
        }
    }
    Timer { interval:25000; running:true; onTriggered:Qt.exit(1) }
}
