import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

ShellRoot {
    settings.watchFiles: false
    Window {
        id: stage
        property int targetWidth: 680
        property int targetHeight: 600
        width: targetWidth; height: targetHeight
        minimumWidth: targetWidth; maximumWidth: targetWidth
        minimumHeight: targetHeight; maximumHeight: targetHeight
        visible: true
        color: Theme.background
        Rectangle { anchors.fill: parent; color: Theme.background }
        ClipboardView {
            id: view
            anchors.fill: parent
            anchors.margins: 20
            open: true
            loading: false
            entries: [
                {id:"1", text:"Una idea importante que quieres conservar y poder encontrar rápidamente.", preview:"Una idea importante que quieres conservar y poder encontrar rápidamente.", isImage:false},
                {id:"2", text:"", preview:"[[ binary data png 640x320 ]]", isImage:true},
                {id:"3", text:"https://quickshell.org/docs", preview:"https://quickshell.org/docs", isImage:false},
                {id:"4", text:"Borrador de la propuesta", preview:"Borrador de la propuesta", isImage:false, saved:true, collectionId:"work"}
            ]
            filteredEntries: entries
            collections: [{id:"work", name:"Trabajo"}, {id:"ideas", name:"Ideas para más adelante"}]
            textSources: ({"1":"Una idea importante que quieres conservar y poder encontrar rápidamente.\n\nEl portapapeles tiene que acompañar el trabajo, sin añadir pasos innecesarios.", "3":"https://quickshell.org/docs"})
            previewSources: ({"2|full":Quickshell.env("ISLA_CLIPBOARD_IMAGE") || "", "2|thumb":Quickshell.env("ISLA_CLIPBOARD_IMAGE") || ""})
            onSectionRequested: id => section = id
        }
        TestCase {
            id: checks
            name:"ClipboardDesign"
            when: stage.visible
            property bool done: false
            function check(ok, message) { if (!ok) {console.error("FAIL: clipboard design",message); Qt.exit(1); throw Error(message)} }
            function find(item,name) {if(item.objectName===name)return item;for(const child of item.children){const found=find(child,name);if(found)return found}return null}
            function shot(name) {
                const out=Quickshell.env("ISLA_TEST_OUTPUT")
                if(!out)return
                var saved=false
                stage.contentItem.grabToImage(result=>{saved=result.saveToFile(out+"/"+name+".png")})
                tryVerify(()=>saved)
            }
            function test_states() {
                wait(700)
                view.chooseSection("saved")
                wait(30)
                view.chooseSection("history")
                wait(250)
                check(view.section==="history","section reversal cancels pending destination")
                view.chooseSection("saved")
                wait(350)
                check(view.section==="saved","section transition commits destination")
                view.section="history"
                Config.update({appearance:{fontScale:1.5}})
                stage.targetWidth=600
                wait(400)
                shot("large-type-list")
                view.openEntry(view.entries[1],true)
                tryCompare(view,"detailProgress",1,2000)
                const details=find(view,"clipboardDetails")
                check(details.organizerPage && details.height>300,"dedicated save page has room for destinations")
                shot("large-type-organizer")
                details.showCollections()
                wait(220)
                keyClick(Qt.Key_Escape)
                check(!view.showingDetails,"Escape leaves the dedicated save page")
                view.openEntry(view.entries[0],false)
                tryCompare(view,"detailProgress",1,2000)
                check(!details.destinationChosen && find(view,"clipboardDestinationLabel").text === "Elegir colección", "reader does not imply Sin colección without a choice")
                details.showCollections()
                check(details.collectionIndex === 0,"new destination picker starts at first collection")
                keyClick(Qt.Key_Escape)
                check(!details.choosingCollection,"Escape closes reader destination list")
                const dest=find(view,"clipboardDestination")
                check(dest.activeFocus,"Escape returns focus to destination")
                details.backRequested()
                Config.update({appearance:{fontScale:1}})
                stage.targetWidth=680
                view.collections=Array.from({length:12},(_,i)=>({id:"c"+i,name:"Colección "+(i+1)}))
                wait(300)
                const navigation=find(view,"clipboardSectionsScroll")
                const next=find(view,"clipboardCollectionsNext")
                check(next.visible && next.enabled,"overflow collections have operable disclosure")
                mouseClick(next,next.width/2,next.height/2)
                wait(50)
                check(navigation.contentX>0,"collection navigation moves progressively")
                wait(260)
                shot("many-collections")
                view.entries=[]
                wait(300)
                shot("empty-history")
                view.section="saved"
                wait(220)
                shot("empty-library")
                view.loading=true
                wait(180)
                shot("loading")
                view.loading=false
                view.entries=[{id:"1",text:"Una idea importante",preview:"Una idea importante",isImage:false}]
                view.collections=[{id:"work",name:"Trabajo"}]
                IslaPalette.colors=Object.assign({},IslaPalette.colors,{surface:"#f4f6f8",on_surface:"#1b1f24",primary:"#365e8e",on_primary:"#ffffff",on_surface_variant:"#343c46"})
                wait(300)
                shot("light-list")
                view.openEntry(view.entries[0],false)
                wait(350)
                shot("light-reader")
                Config.update({appearance:{reduceMotion:true}})
                details.backRequested()
                check(view.detailProgress===0,"reduced state closes directly")
                console.log("PASS: clipboard design large type, section cancellation, destination focus, collections, empty/loading and light theme")
                done=true
            }
        }
        Timer {interval:50;running:checks.done;onTriggered:Qt.quit()}
        Timer {interval:14000;running:true;onTriggered:{console.error("FAIL: clipboard design timeout");Qt.exit(1)}}
    }
}
